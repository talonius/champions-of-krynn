{ The spell-selection menus (cast, memorize, scribe, learn), the range and duration calculators, the per-target resolve
  core, the noncombat cast pipeline, the per-spell dispatch table and the spell and breath handlers. }
{$O+,F+}
unit Magic;
interface
uses Types, Crt, GDConsts, GDVars, Border, TextRend, SoundDrv, FxEngine, CharHlp, ClassCal,
  MenuCore, Pathing, CbtMap, Debug, C_Keys, C_Class, C_Race, C_Stat, C_Terr, C_Status, C_Ifc, C_Effect, C_Cond, C_Spell;

{ Runs the spell menu that GenerateSpellList built, then frees the list.
  @param(sel The menu: 1 Cast, 2 Memorize (rows 5 to 15, redrawn when GDVars.bonusFlag is set), 3 Scribe, or 4 Learn,
    which has no Exit.)
  @param(idx The highlighted line, kept between calls; below 0 forces a redraw.)
  @returns(The chosen spell, or 0 for Exit or Escape. For Scribe, GDVars.curScroll is set to the chosen spell's
  scroll.) }
function SpellSelection(sel: Byte; var idx: Integer): Byte;

{ Builds the spell menu list for the current character, with a heading before each spell level.
  @param(menuType 0 its memorized spells it can cast, 5 those still being memorized, 1 the spells it knows and can cast
    that are not memorized (SpellKnown), 4 the spells of its robe order it may learn (a slot of that level, not yet
    known), 2 the current scroll's spells, 3 all its scrolls' spells, 6 its scrolls' spells marked for scribing.)
  @returns(True when the list is not empty.) }
function GenerateSpellList(menuType: Byte): Boolean;

{ Computes a spell's range.
  @param(s The spell.)
  @returns(Its base plus its per-level range times the caster level (an item casts at level 6); a spell with an area
    gets at least 1, and 255 becomes 1.) }
function CalcSpellRange(s: Byte): Byte;

{ Picks the targets of a spell cast outside combat; it is installed as the cast-target handler outside combat. Target
  mode 1 targets the caster, 2 asks for one party member (remembered for the next cast; giving up clears the targets and
  the cast) and 4 targets each creature in the list; any other mode gives up the cast.
  @param(spell The spell.)
  @param(b Unused.)
  @param(cast Receives True when targets were picked.) }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Casts spell for the current character. Outside combat a combat-only spell can only be lost ("Lose it?"), and a
  combat-only item can only be used up without effect ("Use it?", which sets sel); effect 74 makes half the casts fail
  ("miscasts"); with ai nonzero a cast that no item makes is announced. The target picker (GDVars.castTargetMenu)
  chooses the targets; in combat the caster turns toward the target cell, the spell's sound plays and a bolt is drawn.
  Then the spell is used up (unless an item casts it) and its handler in GDVars.spellDispatch runs. A canceled pick in
  combat asks whether to abort (b nonzero skips the question), which loses the spell.
  @param(spell The spell to cast.)
  @param(b Nonzero for a computer-controlled caster; the target picker gets it too.)
  @param(ai Nonzero to announce the cast.)
  @param(sel Set by the target picker when targets were chosen, or by a Yes to "Use it?".) }
procedure CastSpell(spell, b, ai: Byte; var sel: Boolean);

{ Tells whether an item is readable.
  @param(it The item, or nil.)
  @returns(True for a scroll: item type 39 or 40.) }
function ItemReadable(it: Pointer): Boolean;

{ Removes a spell from a scroll: the scroll's spell-count name part drops by one, and the scroll goes when none are left
  (name id below 100).
  @param(cr The character carrying the scroll.)
  @param(it The scroll.)
  @param(sp The spell to remove; bit 7 of the scroll's entries is ignored, and the last matching entry is cleared.) }
procedure RemoveSpellFromScroll(cr, it: Pointer; sp: Byte);

{ Reports a cast: in combat "Casts a Spell" and the spell's name on row 23; outside combat the caster's name, the given
  text and the spell's name in the text window, then a pause.
  @param(cr The caster.)
  @param(s Printed after the caster's name outside combat.)
  @param(id The spell cast.) }
procedure PrintCastSpellMsg(cr: Pointer; s: Types.TStr40; id: Byte);

{ Casts Remove Curse: lifts Bestow Curse from the target ("is un-cursed"), or else un-equips its first cursed item and,
  when that item's special effect is above $7F, removes that effect through the override handler and recalculates the
  target's abilities ("has an item un-cursed"). }
procedure SpellRemoveCurse;

{ Installs the spell handlers (GDVars.spellDispatch, with GDVars.castTargetMenu the outside-combat target picker) and
  the monster ability handlers in the effect table, resets the effect lock, the item-use flag and the last target, and
  sets the inventory-redraw flag. }
procedure InitSpellFns;

{ Calls the priming entries of CharHlp, ClassCal, FxEngine, MenuCore and the trace overlay, so the overlay manager loads
  them; the other overlays this unit uses are not primed. }
procedure PrimeMagic;

implementation

function SpellKnown(cr: Types.PCharRecord; spell: Byte): Boolean; forward;

function ClassCanCastSpell(cr: Types.PCharRecord; spell: Byte): Boolean; forward;

procedure AddScrollSpellLine(spell: Byte); forward;

procedure AddSpellToList(spell: Byte); forward;

procedure AddScrollSpells(forScribe: Boolean); forward;

procedure AddAllScrollSpells(forScribe: Boolean); forward;

function CalcSpellDuration(spell: Byte): Word; forward;

procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40); forward;

procedure CollectConeTargets(ox, oy, tx, ty: ShortInt; rays, reach: Byte); forward;

procedure PrimeMagic;
begin
  CharHlp.PrimeCharHlp;
  ClassCal.PrimeClassCal;
  FxEngine.PrimeFxEngine;
  MenuCore.PrimeMenuCore;
  Debug.PrimeDebug;
end;

{ Tells whether a spell of cast class 2 is among a character's memorized spells (entries 1 to 57, bit 7 ignored). Note:
  despite the name, it checks the memorized spells, and a spell of any other cast class is never found.
  @param(cr The character.)
  @param(spell The spell; bit 7 is ignored.)
  @returns(True when the spell is memorized.) }
function SpellKnown(cr: Types.PCharRecord; spell: Byte): Boolean;
var
  i: Byte;
  found: Boolean;
begin
  spell := spell and $7F;
  SpellKnown := False;
  if GDConsts.spellTbl[spell].castClass = 2 then begin
    i := 1;
    found := False;
    while (not found) and (i <= 57) do begin
      if (cr^.memorized[i] and $7F) = spell then found := True;
      Inc(i)
    end;
    SpellKnown := found
  end
end;

{ Tells whether a character's classes let it cast a spell; earlier-class levels count where EarlierClassActive allows.
  Cast classes 0 and 2 need Wisdom above 8 and either a cleric level or more than 5 knight levels; class 1 Wisdom above
  8 and more than 6 ranger levels; class 3 Intelligence above 8 and either a race other than human, no armor
  (equipped[2]), being outside combat, more than 8 ranger levels, or more than 8 earlier ranger levels with magic-user
  levels; class 4 never. Note: class 3 does not ask for a magic-user level otherwise.
  @param(cr The character.)
  @param(spell The spell; bit 7 is ignored.)
  @returns(True when the character can cast the spell.) }
function ClassCanCastSpell(cr: Types.PCharRecord; spell: Byte): Boolean;
begin
  spell := spell and $7F;
  ClassCanCastSpell := False;
  case GDConsts.spellTbl[spell].castClass of
    0, 2: ClassCanCastSpell := Boolean(cr^.stats[C_Stat.WISDOM].cur > 8) and
      ((cr^.classLevels[C_Class.CLERIC] > 0) or
       (ClassCal.EarlierClassActive(cr) and (cr^.classLevels2[C_Class.CLERIC] > 0)) or
       (cr^.classLevels[C_Class.KNIGHT] > 5) or
       ((cr^.classLevels2[C_Class.KNIGHT] > 5) and ClassCal.EarlierClassActive(cr)));
    1: ClassCanCastSpell := Boolean(cr^.stats[C_Stat.WISDOM].cur > 8) and
      ((cr^.classLevels[C_Class.RANGER] > 6) or
       (ClassCal.EarlierClassActive(cr) and (cr^.classLevels2[C_Class.RANGER] > 6)));
    3: ClassCanCastSpell := (cr^.stats[C_Stat.INTELLIGENCE].cur > 8) and
      ((cr^.race <> C_Race.HUMAN) or (cr^.equipped[2] = nil) or (GDVars.interfaceState <> C_Ifc.IN_COMBAT) or
       (cr^.classLevels[C_Class.RANGER] > 8) or
       (ClassCal.EarlierClassActive(cr) and (cr^.classLevels2[C_Class.RANGER] > 8) and
        ((cr^.classLevels[C_Class.MAGE] > 0) or
         (ClassCal.EarlierClassActive(cr) and (cr^.classLevels2[C_Class.MAGE] > 0)))));
    4: ClassCanCastSpell := False
  end
end;

function SpellSelection(sel: Byte; var idx: Integer): Byte;
var
  item: Types.PItemRec;
  scan: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  count: Byte;
  bottomRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
begin
  case sel of
    1: title := 'Cast';
    2: title := 'Memorize';
    3: title := 'Scribe';
    4: title := 'Learn';
  else
    title := ''
  end;
  redraw := False;
  if sel in [1..4] then
    prompt := 'Choose Spell: '
  else
    prompt := '';
  if sel = 2 then begin
    bottomRow := 15;
    redraw := Boolean(GDVars.bonusFlag)
  end else
    bottomRow := 22;
  if sel = 4 then
    addExit := False
  else
    addExit := True;
  if idx < 0 then begin
    redraw := True;
    idx := 0
  end;
  if (sel = 4) or (sel = 1) then redraw := True;
  item := nil;
  repeat
    ch := MenuCore.MenuVertical(prompt, title, LightMagenta, LightGreen, White, 1, 5, 38, bottomRow, GDVars.spellList,
                                addExit, redraw, idx, item)
  until ch in [C_Keys.NONE, C_Keys.ENTER, 'C', 'E', 'L', 'M', 'S'];
  scan := GDVars.spellList;
  count := 0;
  while scan <> item do begin
    if scan^.inUse = 0 then Inc(count);
    scan := scan^.next
  end;
  if ch in [C_Keys.NONE, 'E'] then
    SpellSelection := 0
  else
    SpellSelection := GDVars.spellIds[count];
  if sel = 3 then GDVars.curScroll := GDVars.scrollPtrs[count];
  MenuCore.FreeStringList(GDVars.spellList)
end;

{ Appends a spell to the scroll spell list (and its id list), with a level heading when its level differs from the last
  spell's.
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddScrollSpellLine(spell: Byte);
var
  item: Types.PItemRec;
  count: ShortInt;
  lastLevel: ShortInt;
begin
  item := GDVars.spellList;
  if GDVars.spellList = nil then begin
    GetMem(item, SizeOf(Types.TCharacterListNode));
    GDVars.spellList := item;
    lastLevel := 0;
    count := 0
  end else begin
    count := 1;
    while item^.next <> nil do begin
      if item^.inUse = 0 then Inc(count);
      item := item^.next
    end;
    lastLevel := GDConsts.spellTbl[GDVars.spellIds[count - 1]].level;
    GetMem(item^.next, SizeOf(Types.TCharacterListNode));
    item := item^.next
  end;
  item^.next := nil;
  if GDConsts.spellTbl[spell and $7F].level <> lastLevel then begin
    item^.name := GDConsts.levelNameTable[GDConsts.spellTbl[spell and $7F].level];
    item^.inUse := 1;
    GetMem(item^.next, SizeOf(Types.TCharacterListNode));
    item := item^.next;
    item^.next := nil
  end;
  if spell > $7F then
    item^.name := ' *'
  else
    item^.name := '  ';
  item^.name := item^.name + GDConsts.spellNames[spell and $7F];
  item^.inUse := 0;
  GDVars.spellIds[count] := spell and $7F
end;

{ Adds a spell to the menu list (and its id list), before the first spell of a higher level; a repeat of the same spell
  is merged into a count "(n)".
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddSpellToList(spell: Byte);
var
  carry: Byte;
  tmp: Byte;
  item: Types.PItemRec;
  scan: Types.PItemRec;
  newNode: Types.PItemRec;
  count: ShortInt;
  k: Byte;
  found: Boolean;
  newLevel: ShortInt;
begin
  item := GDVars.spellList;
  found := False;
  newLevel := GDConsts.spellTbl[spell and $7F].level;
  if GDVars.spellList = nil then begin
    FillChar(GDVars.spellCounts, SizeOf(GDVars.spellCounts), 0);
    GetMem(item, SizeOf(Types.TCharacterListNode));
    item^.next := nil;
    GDVars.spellList := item;
    count := 0;
    GDVars.spellCounts[count] := 1
  end else begin
    count := 0;
    while (item <> nil) and not found do begin
      if item^.inUse = 0 then begin
        if not ((GDConsts.spellTbl[GDVars.spellIds[count]].level > newLevel) or (GDVars.spellIds[count] = (spell and
            $7F))) then begin
          Inc(count);
          item := item^.next
        end else
          found := True
      end else begin
        item := item^.next;
        Inc(count)
      end
    end;
    if GDVars.spellIds[count] <> (spell and $7F) then begin
      scan := GDVars.spellList;
      if scan <> item then begin
        while scan^.next <> item do scan := scan^.next;
        GetMem(newNode, SizeOf(Types.TCharacterListNode));
        newNode^.next := scan^.next;
        scan^.next := newNode;
        item := newNode
      end else begin
        GetMem(newNode, SizeOf(Types.TCharacterListNode));
        newNode^.next := item;
        GDVars.spellList := newNode;
        item := newNode
      end;
      carry := 1;
      for k := count to 57 do begin
        tmp := GDVars.spellCounts[k];
        GDVars.spellCounts[k] := carry;
        carry := tmp
      end
    end else
      Inc(GDVars.spellCounts[count])
  end;
  if spell > $7F then
    item^.name := ' *'
  else
    item^.name := '  ';
  item^.name := item^.name + GDConsts.spellNames[spell and $7F];
  item^.inUse := 0;
  if GDVars.spellCounts[count] > 1 then
    item^.name := item^.name + ' (' + CharHlp.Uint8Str(GDVars.spellCounts[count]) + ')';
  if GDVars.spellIds[count] <> (spell and $7F) then begin
    carry := GDVars.spellIds[count];
    GDVars.spellIds[count] := spell and $7F;
    for k := count + 1 to 57 do begin
      tmp := GDVars.spellIds[k];
      GDVars.spellIds[k] := carry;
      carry := tmp
    end
  end
end;

{ Adds the current scroll's spells to the list (with forScribe only those marked for scribing), recording the scroll for
  each. The scroll is identified first when the character has Read Magic (effect 16) or is a cleric reading a scroll of
  slot 12; an unidentified scroll adds nothing.
  @param(forScribe Selects the spells marked for scribing.) }
procedure AddScrollSpells(forScribe: Boolean);
var
  i: Byte;
  eff: Pointer;
begin
  if CharHlp.HasEffect(GDVars.curChar, 16, eff) or
      (((GDVars.curChar^.classLevels[C_Class.CLERIC] > 0) or
        (GDVars.curChar^.classLevels2[C_Class.CLERIC] > GDVars.curChar^.dualClassThreshold)) and
      (GDVars.baseItems[GDVars.curScroll^.itemType].slot = 12)) then
    GDVars.curScroll^.unidMask := GDVars.curScroll^.unidMask and $F8;
  if (GDVars.curScroll^.unidMask and $07) = 0 then
    for i := 1 to 3 do begin
      if (forScribe and (GDVars.curScroll^.spells[i] > $80)) or
          ((not forScribe) and (GDVars.curScroll^.spells[i] > 0)) then begin
        Magic.AddScrollSpellLine(GDVars.curScroll^.spells[i]);
        GDVars.scrollPtrs[GDVars.scrollCount] := GDVars.curScroll;
        Inc(GDVars.scrollCount)
      end
    end
end;

{ Adds the spells of the current character's readable scrolls that suit its robe order (bit $20 of a scroll's
  identification mask for order 1, $10 for order 2), through AddScrollSpells.
  @param(forScribe Passed on to AddScrollSpells.) }
procedure AddAllScrollSpells(forScribe: Boolean);
var
  i: Byte;
begin
  for i := 0 to 48 do GDVars.scrollPtrs[i] := nil;
  GDVars.scrollCount := 0;
  GDVars.curScroll := GDVars.curChar^.itemsAddr;
  while GDVars.curScroll <> nil do begin
    if Magic.ItemReadable(GDVars.curScroll) then
      if ((GDVars.curChar^.robeOrder = 1) and ((GDVars.curScroll^.unidMask and $20) <> 0)) or
          ((GDVars.curChar^.robeOrder = 2) and ((GDVars.curScroll^.unidMask and $10) <> 0)) then
        Magic.AddScrollSpells(forScribe);
    GDVars.curScroll := Types.PItemRec(GDVars.curScroll)^.next
  end
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  i: Byte;
  candidate: Byte;
  item: Types.PItemRec;
  newNode: Types.PItemRec;
  prevLevel: ShortInt;
  level: ShortInt;
  doBuild: Boolean;
  classIdx: Byte;
begin
  doBuild := True;
  GenerateSpellList := False;
  GDVars.spellList := nil;
  for i := 0 to 57 do GDVars.spellIds[i] := 0;
  case menuType of
    0: for i := 0 to 57 do
         if (GDVars.curChar^.memorized[i] > 0) and
             Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorized[i] and $7F) and
             (GDVars.curChar^.memorized[i] < $80) then
           Magic.AddSpellToList(GDVars.curChar^.memorized[i]);
    5: for i := 0 to 57 do
         if (GDVars.curChar^.memorized[i] > $7F) and
             Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorized[i] and $7F) then
           Magic.AddSpellToList(GDVars.curChar^.memorized[i]);
    1: for i := 1 to 107 do
         if (GDVars.curChar^.spellsKnown[i] <> 0) and Magic.ClassCanCastSpell(GDVars.curChar, i) and
             not Magic.SpellKnown(GDVars.curChar, i) then
           Magic.AddSpellToList(i);
    2: begin Magic.AddScrollSpells(False); doBuild := False end;
    3: begin Magic.AddAllScrollSpells(False); doBuild := False end;
    6: begin Magic.AddAllScrollSpells(True); doBuild := False end;
    4: begin
         if GDVars.curChar^.robeOrder = 1 then classIdx := 2 else classIdx := 3;
         for level := 1 to 4 do
           if GDVars.curChar^.slots[3, level] > 0 then begin
             i := 1;
             candidate := 255;
             while (i <= 10) and (candidate <> 0) do begin
               candidate := GDConsts.knownSpellTable[classIdx, level, i];
               if candidate <> 0 then
                 if GDVars.curChar^.spellsKnown[candidate] = 0 then
                   Magic.AddSpellToList(candidate);
               Inc(i)
             end
           end
       end
  end;
  if GDVars.spellList <> nil then begin
    if doBuild then begin
      i := 0;
      level := GDConsts.spellTbl[GDVars.spellIds[i]].level;
      GetMem(newNode, SizeOf(Types.TCharacterListNode));
      newNode^.next := GDVars.spellList;
      GDVars.spellList := newNode;
      GDVars.spellList^.name := GDConsts.levelNameTable[GDConsts.spellTbl[GDVars.spellIds[i]].level];
      GDVars.spellList^.inUse := 1;
      item := GDVars.spellList;
      repeat
        prevLevel := level;
        if GDVars.spellIds[i] <> 0 then level := GDConsts.spellTbl[GDVars.spellIds[i]].level;
        if prevLevel < level then begin
          GetMem(newNode, SizeOf(Types.TCharacterListNode));
          newNode^.next := item^.next;
          item^.next := newNode;
          item := item^.next;
          item^.name := GDConsts.levelNameTable[level];
          item^.inUse := 1
        end;
        Inc(i);
        item := item^.next
      until item = nil
    end;
    GenerateSpellList := True
  end
end;

function CalcSpellRange(s: Byte): Byte;
var
  spellRange: Byte;
begin
  if GDVars.usingItemFlag = 0 then
    spellRange := GDConsts.spellTbl[s].rangeBase + GDConsts.spellTbl[s].rangePerLevel * CharHlp.GetCasterLevel(s)
  else
    spellRange := GDConsts.spellTbl[s].rangePerLevel * 6 + GDConsts.spellTbl[s].rangeBase;
  if (spellRange = 0) and (GDConsts.spellTbl[s].area <> 0) then spellRange := 1;
  if spellRange = 255 then spellRange := 1;
  CalcSpellRange := spellRange
end;

{ Computes a spell's duration.
  @param(spell The spell.)
  @returns(3780 for spell 26, 1d6 * 10 for 40, 5d4 for 57 and 61, 1d4 * 10 + 40 for 59, 2d10 * 10 in combat or (1d10 +
    10) * 10 outside for 63, 1440 for 67, otherwise its base plus its per-level duration times the caster level.) }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    26: d := 3780;
    40: d := FxEngine.RollDice(1, 6) * 10;
    57, 61: d := FxEngine.RollDice(5, 4);
    59: d := FxEngine.RollDice(1, 4) * 10 + 40;
    63: if GDVars.interfaceState = C_Ifc.IN_COMBAT then
           d := FxEngine.RollDice(2, 10) * 10
         else
           d := (FxEngine.RollDice(1, 10) + 10) * 10;
    67: d := 1440;
  else
    d := GDConsts.spellTbl[spell].durBase + GDConsts.spellTbl[spell].durPerLevel * CharHlp.GetCasterLevel(spell)
  end;
  CalcSpellDuration := d
end;

{ Applies a spell to each target. The save is rolled only when the spell has a saving throw. A spell of fixed range 255
  needs an attack roll as well; a miss counts as saved and zeroes the damage for this and each later target. The damage
  is dealt with the save reducing it, and the spell's effect, if any, is added. With no targets it returns at once,
  leaving the element mask set.
  @param(spell The spell.)
  @param(eff The effect's strength; 0 for the casting level.)
  @param(onRemove True to call the effect's handler when it is removed.)
  @param(damage The damage; 0 for none.)
  @param(elem The damage's element mask.)
  @param(msg Printed after each target's name when the effect takes hold.) }
procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
  saved: Boolean;
begin
  if damage = 0 then GDVars.elementMask := 0 else GDVars.elementMask := elem;
  if GDVars.spellTargetCount = 0 then Exit;
  if eff = 0 then effLevel := CharHlp.GetCasterLevel(spell)
  else effLevel := eff;
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      if GDConsts.spellTbl[spell].saveEffect = 0 then saved := False
      else saved := FxEngine.RollSavingThrow(GDVars.spellTargets[i], GDConsts.spellTbl[spell].saveType, 0);
      if GDConsts.spellTbl[GDVars.currentSpell].rangeBase = 255 then begin
        CharHlp.RecalcStats(GDVars.spellTargets[i]);
        FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, GDVars.spellTargets[i]);
        if not FxEngine.AttackRoll(GDVars.curChar, GDVars.spellTargets[i],
                                   GDVars.spellTargets[i]^.acCur[0]) then begin
          damage := 0;
          saved := True
        end
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(GDVars.spellTargets[i], damage, GDConsts.spellTbl[spell].saveEffect, saved);
      if GDConsts.spellTbl[spell].effect > 0 then
        FxEngine.AddEffectWithMessage(GDVars.spellTargets[i], GDConsts.spellTbl[spell].effect,
                                      Magic.CalcSpellDuration(spell), effLevel, Byte(onRemove),
                                      GDConsts.spellTbl[spell].saveEffect, Byte(saved), msg)
    end;
  GDVars.elementMask := 0
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  target: Pointer;
begin
  if GDVars.lastTarget = nil then GDVars.lastTarget := Types.PCharRecord(GDVars.curChar);
  GDVars.spellTargets[1] := Types.PCharRecord(GDVars.curChar);
  GDVars.spellTargetCount := 1;
  cast := True;
  case GDConsts.spellTbl[spell].targeting of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         CharHlp.SelectChar('Cast Spell on whom', True, True, GDVars.lastTarget);
         if GDVars.lastTarget = nil then begin
           GDVars.spellTargets[1] := nil;
           GDVars.spellTargetCount := 0;
           cast := False
         end else GDVars.spellTargets[1] := GDVars.lastTarget
       end;
    4: begin
         GDVars.spellTargets[GDVars.spellTargetCount] := GDVars.partyHead;
         while GDVars.spellTargets[GDVars.spellTargetCount]^.next <> nil do begin
           GDVars.spellTargets[GDVars.spellTargetCount + 1] :=
             GDVars.spellTargets[GDVars.spellTargetCount]^.next;
           Inc(GDVars.spellTargetCount)
         end
       end else cast := False
  end
end;

procedure CastSpell(spell, b, ai: Byte; var sel: Boolean);
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  x: ShortInt;
  y: ShortInt;
  k: Byte;
  mr: Byte;
  p: Types.PCharRecord;
  buf: array[0..3] of Byte;
begin
  p := GDVars.curChar;
  ok := True;
  if (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (GDConsts.spellTbl[spell].targeting = 0) then begin
    if GDVars.usingItemFlag = 0 then begin
      TextRend.displayString(1, 19, LightGreen, Black, GDConsts.spellNames[spell]);
      TextRend.displayString(1, 20, LightGreen, Black, 'can''t be cast here...');
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, LightGreen, White) = 'Y' then
        CharHlp.RemoveSpell(p, spell)
    end else begin
      TextRend.displayString(1, 19, LightGreen, Black, 'That Item');
      TextRend.displayString(1, 20, LightGreen, Black, 'is a combat-only item...');
      if MenuCore.YesNoMenu('Use it? ', LightMagenta, LightGreen, White) = 'Y' then sel := True
    end;
    ai := 0;
    ok := False
  end;
  if CharHlp.HasEffect(p, 74, buf) then begin
    mr := FxEngine.RollDice(1, 2);
    if mr = 1 then begin
      Magic.PrintCastSpellMsg(p, 'miscasts', spell);
      ai := 0;
      ok := False
    end
  end;
  if ai <> 0 then
    if GDVars.usingItemFlag = 0 then Magic.PrintCastSpellMsg(p, 'casts', spell);
  while ok do begin
    GDVars.castTargetMenu(spell, Boolean(b), sel);
    if sel then begin
      ok := False;
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        CharHlp.BuildIconFacings(18);
        x := CbtMap.CombatCellX(Types.PCharRecord(p));
        y := CbtMap.CombatCellY(Types.PCharRecord(p));
        k := 0;
        while not Pathing.IsDirToward(x, y, GDVars.targetX, GDVars.targetY, k) do Inc(k);
        GDVars.gfxEnabled := 1;
        CbtMap.SetCreatureFacing(Types.PCharRecord(p), k, 1, 0);
        case spell of
          47: SoundDrv.SoundCommand(GDConsts.soundIds[7]);
          51: SoundDrv.SoundCommand(GDConsts.soundIds[4]);
        else
          SoundDrv.SoundCommand(GDConsts.defaultSpellSound)
        end;
        CharHlp.CombatAnimateMovingIcon(x, y, GDVars.targetX, GDVars.targetY, 4, 30);
        if CbtMap.CombatIconVisible(Types.PCharRecord(p), 0) then begin
          CbtMap.SetCreatureFacing(p, p^.combatAddr^.facing, 1, 1);
          CbtMap.SetCreatureFacing(p, p^.combatAddr^.facing, 0, 0)
        end
      end;
      FxEngine.RemoveInvisibility(p);
      if GDVars.usingItemFlag = 0 then CharHlp.RemoveSpell(p, spell);
      GDVars.currentSpell := spell;
      GDVars.spellDispatch[GDVars.currentSpell];
      GDVars.currentSpell := 0;
      GDVars.multiTarget := 0
    end else begin
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then ok := False
      else if (b <> 0) or (MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White) = 'Y') then
      begin
        CharHlp.PrintBottomLine('Spell Aborted');
        if GDVars.usingItemFlag = 0 then CharHlp.RemoveSpell(p, spell);
        ok := False
      end
    end
  end;
  CharHlp.ClearMessageWindow;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then Border.ClearBox(0, 23, 39, 23)
end;

{ Fills the spell targets with the creatures, other than the caster, on a line from the origin through the aimed cell,
  extended to the cone's length and cut short by walls, and with two or three rays on one or two more lines to cells
  beside its end; 255 rays take instead the creatures within 3 cells of the line's end. Note: once a creature has been
  met twice on the main line, no later creature on it is added; and the area list of 255 rays overwrites the line's list
  without ending it, so creatures past its length stay.
  @param(ox The column of the cone's origin.)
  @param(oy The row of the cone's origin.)
  @param(tx The column of the aimed cell.)
  @param(ty The row of the aimed cell.)
  @param(rays The number of lines (1, 2 or 3), or 255 for an area at the end.)
  @param(reach The cone's length in cells.) }
procedure CollectConeTargets(ox, oy, tx, ty: ShortInt; rays, reach: Byte);
var
  side2X: ShortInt;
  side2Y: ShortInt;
  side1X: ShortInt;
  side1Y: ShortInt;
  req: Types.TPathState;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  walkOk: Boolean;
  i: Byte;
  n: Byte;
  lastDirIdx: Byte;
  dirs: array[0..49] of Byte;
  list: array[0..30] of Byte;
  terrIdx: Byte;
  listCount: Byte;
  destIdx: Byte;
  centerDir: Byte;
  walkDist: Word;
  found: Boolean;

  { Starts the line walk req from (sx, sy) to (ex, ey). }
  procedure SetLine(sx, sy, ex, ey: ShortInt);
  begin
    req.startX := sx; req.startY := sy; req.endX := ex; req.endY := ey;
    Pathing.PathFind(req)
  end;

  { Keeps (cx, cy) inside the 50x25 arena. }
  procedure ClampCell(var cx, cy: ShortInt);
  begin
    if cx > 49 then cx := 49 else if cx < 0 then cx := 0;
    if cy > 24 then cy := 24 else if cy < 0 then cy := 0
  end;

  { Adds each creature on the rest of the walked line to the list, once. }
  procedure CollectAlong;
  var
    j: Byte;
    cfound: Boolean;
  begin
    repeat
      done := not Pathing.NextPathStep(req);
      if not done then begin
        CbtMap.GetArenaContents(ShortInt(req.currentX), ShortInt(req.currentY), list[0], terrIdx);
        j := 1; cfound := False;
        if list[0] > 0 then
          repeat
            if list[j] = list[0] then cfound := True
            else if list[j] = 0 then
            begin list[j] := list[0]; cfound := True end
            else Inc(j)
          until cfound
      end
    until done
  end;

begin
  n := 0;
  SetLine(ox, oy, tx, ty);
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin dirs[n] := req.lastDirection; Inc(n) end
  until done;
  lastDirIdx := n - 1;
  n := 0;
  reach := reach shl 1;
  i := req.distance;
  done := False;
  while (i < reach) and not done do begin
    if (tx < 49) and (tx > 0) and (ty < 24) and (ty > 0) then begin
      case dirs[n] of
        0, 2, 4, 6: Inc(i, 2);
        1, 3, 5, 7: Inc(i, 3)
      end;
      Inc(tx, GDConsts.dirDeltaX[dirs[n]]);
      Inc(ty, GDConsts.dirDeltaY[dirs[n]]);
      if n = lastDirIdx then n := 0 else Inc(n)
    end else done := True
  end;
  ClampCell(tx, ty);
  walkOk := Pathing.WalkLine(ox, oy, tx, ty, walkDist, GDVars.arena);
  SetLine(ox, oy, tx, ty);
  FillChar(list[1], SizeOf(list) - 1, 0);
  listCount := 1;
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin
      CbtMap.GetArenaContents(ShortInt(req.currentX), ShortInt(req.currentY), list[0], terrIdx);
      if list[0] > 0 then begin
        if listCount > 1 then begin
          for GDVars.scratchIndex := 1 to listCount - 1 do
            if list[GDVars.scratchIndex] = list[0] then found := True
        end else found := False;
        if not found then
        begin list[listCount] := list[0]; Inc(listCount) end;
        centerDir := req.lastDirection
      end
    end
  until done;
  if (rays > 1) and (rays <> 255) then begin
    side2X := tx + GDConsts.sideRayStepX1[centerDir];
    side2Y := ty + GDConsts.sideRayStepY1[centerDir];
    ClampCell(side2X, side2Y);
    side1X := tx + GDConsts.sideRayStepX2[centerDir];
    side1Y := ty + GDConsts.sideRayStepY2[centerDir];
    ClampCell(side1X, side1Y);
    SetLine(ox, oy, side1X, side1Y);
    CollectAlong;
    if rays > 2 then
    begin SetLine(ox, oy, side2X, side2Y); CollectAlong end
  end;
  if rays = 255 then begin
    Pathing.BuildTargetList(tx, ty, 3, 255, 1, GDVars.arena);
    for GDVars.scratchIndex := 1 to GDVars.targetCount do
      list[GDVars.scratchIndex] := GDVars.targetList[GDVars.scratchIndex].creatureIndex
  end;
  listCount := 1;
  destIdx := 1;
  GDVars.spellTargetCount := 0;
  if list[1] <> 0 then
    repeat
      if GDVars.creatureArr[list[listCount]] <> Types.PCharRecord(GDVars.curChar) then begin
        Inc(GDVars.spellTargetCount);
        GDVars.spellTargets[destIdx] := GDVars.creatureArr[list[listCount]];
        Inc(destIdx)
      end;
      Inc(listCount)
    until list[listCount] = 0
end;

procedure ApplyEffectToTargets(saveMod: ShortInt; msg: Types.TStr40); forward;

procedure CastOneSide(hostFlag: Byte; msg: Types.TStr40); forward;

{ Applies the current spell's effect, at caster-level strength, to each target from the last to the first, drawing a
  bolt to all but the last listed, with a save at saveMod. Monsters always save against spells 23 and 49, and for spells
  79 and 81 the last target always saves.
  @param(saveMod The saving-throw modifier.)
  @param(msg Reports the effect on each target.) }
procedure ApplyEffectToTargets(saveMod: ShortInt; msg: Types.TStr40);
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  i: Byte;
  saveNegates: Boolean;
begin
  for i := GDVars.spellTargetCount downto 1 do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      if i < GDVars.spellTargetCount then begin
        SoundDrv.SoundCommand(GDConsts.defaultSpellSound);
        CharHlp.BuildIconFacings(18);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(GDVars.curChar)),
                                        CbtMap.CombatCellY(Types.PCharRecord(GDVars.curChar)),
                                        CbtMap.CombatCellX(Types.PCharRecord(tgt)),
                                        CbtMap.CombatCellY(Types.PCharRecord(tgt)), 4, 30)
      end;
      if ((GDVars.currentSpell = 79) or (GDVars.currentSpell = 81)) and (i = GDVars.spellTargetCount) then begin
        saved := True;
        saveNegates := True
      end else begin
        saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellTbl[GDVars.currentSpell].saveType, saveMod);
        saveNegates := Boolean(GDConsts.spellTbl[GDVars.currentSpell].saveEffect)
      end;
      if (Byte(tgt^.race) = C_Race.MONSTER) and
          ((GDVars.currentSpell = 23) or (GDVars.currentSpell = 49)) then saved := True;
      FxEngine.AddEffectWithMessage(tgt, GDConsts.spellTbl[GDVars.currentSpell].effect,
                                    Magic.CalcSpellDuration(GDVars.currentSpell),
                                    CharHlp.GetCasterLevel(GDVars.currentSpell), 0, Byte(saveNegates), Byte(saved),
                                    msg)
    end
end;

{ Applies the current spell to the targets on side hostFlag (for spells 1 and 105 in combat, not those with an enemy
  next to them), reporting msg.
  @param(hostFlag The side that keeps the spell.)
  @param(msg Reports the effect on each target.) }
procedure CastOneSide(hostFlag: Byte; msg: Types.TStr40);
var
  i: Byte;
begin
  GDVars.multiTarget := 1;
  for i := 1 to GDVars.spellTargetCount do
    if (Byte(GDVars.spellTargets[i]^.hostile) <> hostFlag) or
        (((GDVars.currentSpell = 1) or (GDVars.currentSpell = 105)) and
         (GDVars.interfaceState = C_Ifc.IN_COMBAT) and
         (CharHlp.CountTargets(GDVars.spellTargets[i], 1) > 0)) then
      GDVars.spellTargets[i] := nil;
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, msg)
end;

{ Spells 1 and 105 (Bless) on the caster's side. }
procedure SpellBless;
begin
  Magic.CastOneSide(Byte(Types.PCharRecord(GDVars.curChar)^.hostile), 'is Blessed')
end;

{ Casts Curse on the caster's enemies. }
procedure SpellCurse;
begin
  Magic.CastOneSide(CharHlp.EnemyTeam(GDVars.curChar), 'is Cursed')
end;

{ Casts Cure Light Wounds: heals the target 1d8, or 2d8 when the caster's deity is 4. }
procedure SpellCureLightWounds;
var
  bonus: Byte;
begin
  if GDVars.spellTargetCount = 0 then begin
  end else begin
    if Byte(GDVars.curChar^.deity) = 4 then bonus := FxEngine.RollDice(1, 8)
    else bonus := 0;
    if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], bonus + FxEngine.RollDice(1, 8), False) then
      CharHlp.AnnounceHealStatus(GDVars.spellTargets[1])
  end
end;

{ Casts Cause Light Wounds: 1d8 magic damage. }
procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, FxEngine.RollDamageDice(1, 8), 8, '')
end;

{ Applies a detection spell's effect to the targets. }
procedure SpellDetection;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is affected')
end;

{ Applies a protection spell's effect to the targets. }
procedure SpellProtection;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is protected')
end;

{ Applies Resist Cold's effect to the targets. }
procedure SpellResistCold;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is cold-resistant')
end;

{ Casts Burning Hands: fire damage of 1 point per caster level. }
procedure SpellBurningHands;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, CharHlp.GetCasterLevel(GDVars.currentSpell), 9, '')
end;

{ Casts Charm Person: only targets of creature type 0 or 1 and icon size 1 can be charmed. The Charm effect's strength
  holds the caster's side in bit 7 and the caster level; afterwards the target's first Charm effect (normally the one
  just added) has its handler called as for an addition, not a removal. }
procedure SpellCharmPerson;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargets[1];
  if tgt <> nil then
    if (tgt^.charType > 1) or (tgt^.iconDimensions > 1) then
      CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
    else begin
      Magic.ResolveSpell(GDVars.currentSpell,
                   GDVars.curChar^.hostile * 128 + CharHlp.GetCasterLevel(GDVars.currentSpell), True, 0, 0,
                   'is charmed');
      if CharHlp.HasEffect(tgt, 11, eff) then
        FxEngine.CallEffectHandler(11, tgt, eff, False)
    end
end;

{ Casts Enlarge: Strength by caster level (18 at level 1, 18/01, 18/51, 18/76, 18/91 and 18/100 at 2 to 6, 19 to 21 at 7
  to 9, 22 at 10 and 11, and 18 at any other level) as the Enlarge effect, when that beats the target's own ("is
  stronger"). }
procedure SpellEnlarge;
var
  enc: Byte;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargets[1];
  GDVars.spellTemp1 := 18;
  GDVars.spellTemp2 := 0;
  case CharHlp.GetCasterLevel(GDVars.currentSpell) of
    1: GDVars.spellTemp2 := 0;
    2: GDVars.spellTemp2 := 1;
    3: GDVars.spellTemp2 := 51;
    4: GDVars.spellTemp2 := 76;
    5: GDVars.spellTemp2 := 91;
    6: GDVars.spellTemp2 := 100;
    7: GDVars.spellTemp1 := 19;
    8: GDVars.spellTemp1 := 20;
    9: GDVars.spellTemp1 := 21;
    10, 11: GDVars.spellTemp1 := 22
  end;
  if FxEngine.AdjustForNewStrength(tgt, GDVars.spellTemp1, GDVars.spellTemp2, enc) then begin
    CharHlp.PrintCreatureMessage(tgt, 'is stronger', 10, True);
    FxEngine.AddEffect(tgt, 12, Magic.CalcSpellDuration(GDVars.currentSpell), enc, True);
    FxEngine.RecalcAbility(tgt, 0)
  end else CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
end;

{ Casts Reduce: removes Enlarge from the target unless it saves against spells ("has been reduced"). }
procedure SpellReduce;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargets[1];
  if tgt <> nil then
    if GDVars.spellTargetCount > 0 then
      if not FxEngine.RollSavingThrow(tgt, 4, 0) then
        if CharHlp.HasEffect(tgt, 12, eff) then begin
          FxEngine.RemoveEffect(tgt, 12, nil);
          FxEngine.RecalcAbility(tgt, 0);
          CharHlp.PrintCreatureMessage(tgt, 'has been reduced', 10, True)
        end
end;

{ Casts Friends: the effect with strength 2d4, then the caster's Charisma is recalculated. }
procedure SpellFriends;
var
  { Unused in this version; see the other implementations of this routine. }
  oldCha: Byte;
begin
  Magic.ResolveSpell(GDVars.currentSpell, FxEngine.RollDice(2, 4), True, 0, 0, 'is friendly');
  FxEngine.RecalcAbility(GDVars.curChar, 5)
end;

{ Casts Magic Missile: (caster level + 1) div 2 missiles of 1d4 + 1 magic damage. }
procedure SpellMagicMissile;
var
  cl: Byte;
begin
  cl := CharHlp.GetCasterLevel(GDVars.currentSpell) + 1;
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, cl div 2 + FxEngine.RollDamageDice(cl div 2, 4), 8, '')
end;

{ Applies Shield's effect to the targets. }
procedure SpellShield;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is shielded')
end;

{ Casts Shocking Grasp: 1d8 plus the caster level in electrical damage. }
procedure SpellShockingGrasp;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False,
               FxEngine.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.currentSpell), 12, '')
end;

{ Casts Sleep with a 4d4 hit-dice pool. Each target costs by its level: 0..1 costs 1, 2 costs 2, 3 costs 4, 4 costs 6, 5
  costs 10 for a creature of the monster race and 20 otherwise, and higher levels cost 20. Animated dead, targets
  already asleep and targets the remaining pool cannot pay for are dropped; the pool is spent greedily in target
  order. }
procedure SpellSleep;
var
  i: Byte;
  eff: Pointer;
begin
  GDVars.multiTarget := 1;
  GDVars.spellTemp1 := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.spellTargetCount do begin
    case GDVars.spellTargets[i]^.levelHighest of
      0..1: GDVars.spellTemp2 := 1;
      2: GDVars.spellTemp2 := 2;
      3: GDVars.spellTemp2 := 4;
      4: GDVars.spellTemp2 := 6;
      5: if Byte(GDVars.spellTargets[i]^.race) = C_Race.MONSTER then GDVars.spellTemp2 := 10
         else GDVars.spellTemp2 := 20;
    else
      GDVars.spellTemp2 := 20
    end;
    if (GDVars.spellTargets[i]^.status <> C_Status.ANIMATED) and
        (not CharHlp.HasEffect(GDVars.spellTargets[i], 53, eff)) and (GDVars.spellTemp1 >= GDVars.spellTemp2) then
      Dec(GDVars.spellTemp1, GDVars.spellTemp2)
    else GDVars.spellTargets[i] := nil
  end;
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'falls asleep')
end;

{ Hold Person and Hold Monsters: puts the hold effect on up to four targets, with a save modifier by their number: -2 or
  -3 for one, depending on the spell, -1 for two and 0 for three or four. Note: more targets leave the modifier
  undefined. }
procedure SpellHold;
var
  smod: ShortInt;
begin
  case GDVars.spellTargetCount of
    1: if GDVars.currentSpell = 23 then smod := -2 else smod := -3;
    2: smod := -1;
    3, 4: smod := 0
  end;
  Magic.ApplyEffectToTargets(smod, 'is held')
end;

{ Applies Resist Fire's effect to the targets. }
procedure SpellResistFire;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is fire resistant')
end;

{ Applies Silence's effect to the targets. }
procedure SpellSilence;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is silenced')
end;

{ Casts Slow Poison: on a poisoned target that is not animated, raises 0 hit points to 1, sets it okay and in play,
  applies the spell and re-arms the poison damage for 10. }
procedure SpellSlowPoison;
var
  eff: Pointer;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.spellTargets[1];
  if tgt^.status = C_Status.ANIMATED then GDVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, eff) then begin
    if tgt^.hpCur = 0 then tgt^.hpCur := 1;
    tgt^.status := C_Status.OKAY;
    tgt^.inPlay := 1;
    Magic.ResolveSpell(GDVars.currentSpell, 255, True, 0, 0, 'is affected');
    FxEngine.AddEffect(tgt, C_Effect.POISON_DAMAGE, 10, 255, True)
  end
end;

{ Casts Snake Charm: charms snakes in play and not yet charmed whose hit points, in total, fit in the caster's current
  hit points. }
procedure SpellSnakeCharm;
var
  p: Types.PCharRecord;
  eff: Pointer;
begin
  GDVars.spellTemp1 := Types.PCharRecord(GDVars.curChar)^.hpCur;
  GDVars.spellTargetCount := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    if ((p^.charType and $10) <> 0) and (p^.inPlay <> 0) and (not CharHlp.HasEffect(p, 51, eff)) and
        (GDVars.spellTemp1 >= p^.hpCur) then begin
      GDVars.spellTemp1 := GDVars.spellTemp1 - p^.hpCur;
      Inc(GDVars.spellTargetCount);
      GDVars.spellTargets[GDVars.spellTargetCount] := p
    end;
    p := p^.next
  end;
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is charmed')
end;

{ Casts Spiritual Hammer: applies the spell's effect, then runs the Spiritual Hammer effect handler for the first
  target. }
procedure SpellSpiritualHammer;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(23, GDVars.spellTargets[1], nil, False)
end;

{ Applies the Invisibility spells' effect to the targets. }
procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is invisible')
end;

{ Applies Knock's effect to the targets. }
procedure SpellKnock;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'Knock-Knock')
end;

{ Casts Mirror Image: 1d4 images in the effect strength's high nibble, the caster level in the low one. }
procedure SpellMirrorImage;
var
  strength: Byte;
begin
  strength := FxEngine.RollDice(1, 4) shl 4;
  strength := strength or CharHlp.GetCasterLevel(GDVars.currentSpell);
  Magic.ResolveSpell(GDVars.currentSpell, strength, False, 0, 0, 'is duplicated')
end;

{ Applies Ray of Enfeeblement's effect to the targets. }
procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is weakened')
end;

{ Casts Stinking Cloud: a cloud on the four cells around the target cell. A node joins the stinking-cloud list, numbered
  among the caster's clouds and tracked by an effect on the caster; each cell's terrain is saved (for a cell under
  another cloud or a body, the terrain beneath it) and passable cells get the cloud tile. Creatures inside take the
  cloud once each. Note: the count of the caster's clouds skips the list's last node. }
procedure SpellStinkingCloud;
var
  scan: Types.PCloudNode;
  node: Types.PCloudNode;
  dirs: array[1..4] of Byte;
  j: Byte;
  ownCnt: Byte;
  crIdx: Byte;
  lvl: Byte;
  i: Byte;
  k: Byte;
begin
  GDVars.multiTarget := 1;
  lvl := CharHlp.GetCasterLevel(GDVars.currentSpell);
  ownCnt := 0;
  node := GDVars.cloudHead;
  if GDVars.cloudHead = nil then begin
    GetMem(GDVars.cloudHead, SizeOf(Types.TCloudNode));
    node := GDVars.cloudHead
  end else begin
    while node^.next <> nil do begin
      if node^.owner = GDVars.curChar then Inc(ownCnt);
      node := node^.next
    end;
    GetMem(node^.next, SizeOf(Types.TCloudNode));
    node := node^.next
  end;
  FillChar(node^, SizeOf(node^), 0);
  FxEngine.AddEffect(GDVars.curChar, 40, lvl, lvl + ownCnt * 16, True);
  node^.owner := GDVars.curChar;
  node^.instanceId := ownCnt;
  node^.x := GDVars.targetX;
  node^.y := GDVars.targetY;
  for i := 1 to 4 do begin
    k := GDConsts.cloudDirs[i];
    CbtMap.GetArenaContents(GDVars.targetX + GDConsts.dirDeltaX[k], GDVars.targetY + GDConsts.dirDeltaY[k], dirs[i],
                            crIdx);
    if (crIdx > 0) and (GDConsts.terrainInfo[crIdx].movementCost < C_Terr.TERRAIN_IMPASSABLE) then
      node^.activeCells[i] := 1
    else
      node^.activeCells[i] := 0;
    if crIdx = C_Terr.TERRAIN_STINKING_CLOUD then begin
      scan := GDVars.cloudHead;
      while scan <> nil do begin
        if scan <> node then
          for j := 1 to 4 do
            if scan^.activeCells[j] <> 0 then
              if (scan^.x + GDConsts.dirDeltaX[GDConsts.cloudDirs[j]] = GDVars.targetX + GDConsts.dirDeltaX[k])
                 and (scan^.y + GDConsts.dirDeltaY[GDConsts.cloudDirs[j]] = GDVars.targetY + GDConsts.dirDeltaY[k])
                 and (scan^.terrainCells[j] <> C_Terr.TERRAIN_STINKING_CLOUD) then
                crIdx := scan^.terrainCells[j];
        scan := scan^.next
      end
    end else if crIdx = C_Terr.TERRAIN_CORPSE then begin
      for j := 1 to GDVars.downedCount do
        if (GDVars.downedCreatures[j].x = GDVars.targetX + GDConsts.dirDeltaX[k]) and
            (GDVars.downedCreatures[j].y = GDVars.targetY + GDConsts.dirDeltaY[k]) then
          crIdx := GDVars.downedCreatures[j].terrain
    end;
    node^.terrainCells[i] := crIdx;
    if node^.activeCells[i] <> 0 then
      GDVars.arena^.cells[GDVars.targetY + GDConsts.dirDeltaY[k],
                                  GDVars.targetX + GDConsts.dirDeltaX[k]] := C_Terr.TERRAIN_STINKING_CLOUD
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a noxious cloud', 10, False);
  CbtMap.ScrollView(GDVars.targetX, GDVars.targetY, 255, 8);
  TextRend.pauseOnly;
  CharHlp.ClearMessageWindow;
  for i := 2 to 4 do
    for j := 1 to 4 do
      if (dirs[i] = dirs[j]) and (i <> j) then dirs[i] := 0;
  for i := 1 to 4 do
    if dirs[i] > 0 then FxEngine.ConsiderTerrainEffects(GDVars.creatureArr[dirs[i]], 1)
end;

{ Spell 35 (Strength): 1d4 Strength for a magic-user, 1d6 for a cleric or thief, 1d8 for a fighter (the last match
  wins); above 18 a fighter, knight or ranger gets exceptional Strength instead. Applied as effect 38 when it beats the
  target's own. Note: a target with none of those classes never sets the roll, so it adds whatever the local held. }
procedure SpellStrength;
var
  tgt: Types.PCharRecord;
  pct: Byte;
  hd: Byte;
  base: Byte;
  strEff: Byte;
begin
  pct := 0;
  tgt := GDVars.spellTargets[1];
  if (tgt^.classLevels[C_Class.MAGE] > 0) or
      (tgt^.classLevels2[C_Class.MAGE] > tgt^.dualClassThreshold) then
    hd := FxEngine.RollDice(1, 4);
  if (tgt^.classLevels[C_Class.CLERIC] > 0) or
      (tgt^.classLevels2[C_Class.CLERIC] > tgt^.dualClassThreshold) or
      (tgt^.classLevels[C_Class.THIEF] > 0) or
      (tgt^.classLevels2[C_Class.THIEF] > tgt^.dualClassThreshold) then
    hd := FxEngine.RollDice(1, 6);
  if (tgt^.classLevels[C_Class.FIGHTER] > 0) or
      (tgt^.classLevels2[C_Class.FIGHTER] > tgt^.dualClassThreshold) then
    hd := FxEngine.RollDice(1, 8);
  base := tgt^.stats[C_Stat.STRENGTH].cur + hd;
  if base > 18 then
    if (tgt^.classLevels[C_Class.FIGHTER] > 0) or
        (tgt^.classLevels2[C_Class.FIGHTER] > tgt^.dualClassThreshold) or
        (tgt^.classLevels[C_Class.KNIGHT] > 0) or
        (tgt^.classLevels2[C_Class.KNIGHT] > tgt^.dualClassThreshold) or
        (tgt^.classLevels[C_Class.RANGER] > 0) or
        (tgt^.classLevels2[C_Class.RANGER] > tgt^.dualClassThreshold) then begin
      pct := tgt^.strExc + (base - 18) * 10;
      if pct > 100 then pct := 100;
      base := 18
    end else
      base := 18;
  if FxEngine.AdjustForNewStrength(tgt, base, pct, strEff) then begin
    strEff := hd + 100;
    FxEngine.AddEffect(tgt, 38, Magic.CalcSpellDuration(GDVars.currentSpell), strEff, True);
    FxEngine.RecalcAbility(tgt, 0)
  end
end;

{ Spells 36 and 90 (Animate Dead): does nothing. }
procedure SpellAnimateDead;
begin
end;

{ Casts Cure Blindness: ends the first target's blindness ('can see'). }
procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.BLIND) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], 1, 'can see')
end;

{ Casts Cause Blindness: blinds the targets. }
procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is blind')
end;

{ Removes the first spell target's diseases, with the effect lock set: Diseased, and the Strength-draining disease (with
  its hit-point and helpless effects, then the target's Strength is recalculated).
  @returns(True when one was removed.) }
function RemoveDiseaseEffects: Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectBusy := 1;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], 34) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], 43) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(GDVars.spellTargets[1], 44, nil);
    FxEngine.RemoveEffect(GDVars.spellTargets[1], 31, nil);
    FxEngine.RecalcAbility(GDVars.spellTargets[1], 0)
  end;
  GDVars.effectBusy := 0
end;

{ Casts Cure Disease: removes the first target's disease effects. }
procedure SpellCureDisease;
var
  { Unused in this version; see the other implementations of this routine. }
  removed: Boolean;
begin
  removed := Magic.RemoveDiseaseEffects
end;

{ Applies Cause Disease's effect to the targets. }
procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, True, 0, 0, 'is diseased')
end;

{ Spells 41 and 46 (Dispel Magic): tries each timed effect (strength below 255) of the target, removing it with chance
  50% + 5 per caster level above the effect's level (strength low nibble), - 2 per level below. Then each stinking cloud
  on the target cell and the eight around it is dispelled the same way against its caster; a cloud that resists is not
  tried again. Note: each pass of the target loop dispels the first target again, so the other targets keep their
  effects. }
procedure SpellDispelMagic;
var
  i: Byte;
  casterLevel: Byte;
  tgt: Types.PCharRecord;
  removed: Boolean;
  found: Boolean;
  eff: Types.PEffectRec;
  nextEff: Types.PEffectRec;
  x: ShortInt;
  y: ShortInt;
  terrIdx: Byte;
  crIdx: Byte;
  node: Types.PCloudNode;

  { Rolls whether caster cr's cloud is dispelled, by the caster level against cr's magic-user level. }
  function CloudDispelled(cr: Types.PCharRecord): Boolean;
  begin
    GDVars.spellTemp2 :=
      cr^.classLevels[C_Class.MAGE] +
      cr^.classLevels2[C_Class.MAGE] * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    if casterLevel > GDVars.spellTemp2 then
      GDVars.spellTemp1 := (casterLevel - GDVars.spellTemp2) * 5 + 50
    else if casterLevel < GDVars.spellTemp2 then
      GDVars.spellTemp1 := 50 - (GDVars.spellTemp2 - casterLevel) * 2
    else
      GDVars.spellTemp1 := 50;
    CloudDispelled := FxEngine.RollDice(1, 100) <= GDVars.spellTemp1
  end;

begin
  GDVars.multiTarget := 1;
  casterLevel := CharHlp.GetCasterLevel(GDVars.currentSpell);
  for i := 1 to GDVars.spellTargetCount do begin
    removed := False;
    tgt := GDVars.spellTargets[1];
    eff := tgt^.effects;
    while eff <> nil do begin
      nextEff := eff^.next;
      if eff^.strength < 255 then begin
        GDVars.spellTemp2 := eff^.strength and $0F;
        if casterLevel > GDVars.spellTemp2 then
          GDVars.spellTemp1 := (casterLevel - GDVars.spellTemp2) * 5 + 50
        else if casterLevel < GDVars.spellTemp2 then
          GDVars.spellTemp1 := 50 - (GDVars.spellTemp2 - casterLevel) * 2
        else
          GDVars.spellTemp1 := 50;
        if FxEngine.RollDice(1, 100) <= GDVars.spellTemp1 then begin
          FxEngine.RemoveEffect(tgt, eff^.id, eff);
          removed := True
        end
      end;
      eff := nextEff
    end;
    if removed then CharHlp.PrintNameStringAnim(tgt, 1, 'is affected')
  end;
  for GDVars.scratchIndex := 0 to 8 do begin
    case GDVars.scratchIndex of
      0: begin x := GDVars.targetX; y := GDVars.targetY end;
      1: y := GDVars.targetY - 1;
      2: x := GDVars.targetX + 1;
      3: y := GDVars.targetY;
      4: y := GDVars.targetY + 1;
      5: x := GDVars.targetX;
      6: x := GDVars.targetX - 1;
      7: y := GDVars.targetY;
      8: y := GDVars.targetY - 1
    end;
    CbtMap.GetArenaContents(x, y, crIdx, terrIdx);
    if terrIdx = C_Terr.TERRAIN_STINKING_CLOUD then begin
      node := GDVars.cloudHead;
      crIdx := 4;
      while node <> nil do begin
        for i := 1 to crIdx do
          if (x = node^.x + GDConsts.dirDeltaX[GDConsts.cloudDirs[i]]) and (y = node^.y +
              GDConsts.dirDeltaY[GDConsts.cloudDirs[i]]) and
              (node^.spent = 0) then
            if CloudDispelled(Types.PCharRecord(node^.owner)) then begin
              eff := Types.PCharRecord(node^.owner)^.effects;
              found := False;
              while (eff <> nil) and not found do begin
                if (eff^.id = 40) and (terrIdx = C_Terr.TERRAIN_STINKING_CLOUD) and
                    ((eff^.strength div 16) = node^.instanceId) then
                  found := True
                else
                  eff := eff^.next
              end;
              if found then
                FxEngine.RemoveEffect(Types.PCharRecord(node^.owner), 40, eff)
            end else
              node^.spent := 1;
        node := node^.next
      end;
      CbtMap.ScrollView(GDVars.targetX, GDVars.targetY, 3, 8)
    end
  end
end;

{ Casts Prayer: the effect with the caster's side in bit 4 and the caster level. }
procedure SpellPrayer;
begin
  Magic.ResolveSpell(GDVars.currentSpell,
                     CharHlp.GetCasterLevel(GDVars.currentSpell) + GDVars.curChar^.hostile * 16, False, 0, 0,
                     'is praying')
end;

procedure SpellRemoveCurse;
var
  item: Types.PItemRec;
  found: Boolean;
  i: Byte;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.CURSED) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], 1, 'is un-cursed')
  else begin
    found := False;
    item := GDVars.spellTargets[1]^.itemsAddr;
    while (item <> nil) and not found do begin
      if item^.cursed <> 0 then begin
        found := True;
        item^.equipped := 0;
        if item^.special > $7F then begin
          GDVars.overrideFlag := 1;
          FxEngine.CallEffectHandler(item^.special, GDVars.spellTargets[1], item, True);
          for i := 0 to 5 do FxEngine.RecalcAbility(GDVars.spellTargets[1], i)
        end
      end;
      item := item^.next
    end;
    if found then
      CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], 1, 'has an item un-cursed')
  end
end;

{ Spells 44 and 100 (Bestow Curse): applies the curse to the targets ("has been cursed!"). }
procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'has been cursed!')
end;

{ Applies Blink's effect to the targets. }
procedure SpellBlink;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is blinking')
end;

{ Casts Fireball: caster-level d6 fire damage (the item fireball rolls 3, 5 or 7 d6); outside 3D maps the targets are
  every creature within 2 cells of the target cell. }
procedure SpellFireball;
var
  range: Byte;
  i: Byte;
begin
  GDVars.multiTarget := 1;
  if GDVars.currentSpell = 64 then
    range := FxEngine.RollDice(1, 3) * 2 + 1
  else
    range := CharHlp.GetCasterLevel(GDVars.currentSpell);
  if GDVars.zone0^.view3dFlag = 0 then begin
    Pathing.BuildTargetList(GDVars.targetX, GDVars.targetY, 2, 255, 1, GDVars.arena);
    for i := 1 to GDVars.targetCount do
      GDVars.spellTargets[i] := GDVars.creatureArr[GDVars.targetList[i].creatureIndex];
    GDVars.spellTargetCount := GDVars.targetCount
  end;
  CbtMap.ScrollView(GDVars.targetX, GDVars.targetY, 0, 8);
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, FxEngine.RollDamageDice(range, 6), 9, '')
end;

{ Resolves Haste or Slow for up to the casting level of targets on one team, dropping the rest. A kept target with the
  opposing effect only loses it; the others take the spell's effect and have their movement and attack-rate effects run
  again.
  @param(effId The opposing effect, Slowed or Hasted.)
  @param(hostFlag The team to keep: 0 the party's side, 1 the hostiles.)
  @param(msg The effect message.) }
procedure HasteSlowLogic(effId, hostFlag: Byte; msg: Types.TStr40);
var
  casterLevel: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  affected: Byte;
begin
  GDVars.multiTarget := 1;
  casterLevel := CharHlp.GetCasterLevel(GDVars.currentSpell);
  for i := 1 to GDVars.spellTargetCount do
    if (Byte(GDVars.spellTargets[i]^.hostile) = hostFlag) and (casterLevel > 0) then begin
      Dec(casterLevel);
      if FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[i], effId) then
        GDVars.spellTargets[i] := nil
    end else
      GDVars.spellTargets[i] := nil;
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, msg);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then
      FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, GDVars.spellTargets[i])
end;

{ Casts Haste on the caster's side; it removes Slow instead where there is one. }
procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.curChar^.hostile, 'is Hasted')
end;

{ Hits the creature on cell (`x`, `y`), unless it is in combat slot `excludeIdx`, with electrical damage halved on a
  save of `saveType`; `blocked` becomes True at an impassable cell of a 3D map unless it already was, and False
  otherwise.
  @param(x The cell's column.)
  @param(y The cell's row.)
  @param(damage The electrical damage.)
  @param(saveType The saving-throw type that halves it.)
  @param(excludeIdx The combat slot of a creature to skip, or 0.)
  @param(blocked In, whether the bolt was blocked before this cell; out, as described above.) }
procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; excludeIdx: Byte; var blocked: Boolean);
var
  tgt: Types.PCharRecord;
  crIdx: Byte;
  terrIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hitDamage: Word;
begin
  CbtMap.GetArenaContents(x, y, crIdx, terrIdx);
  if (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].movementCost = C_Terr.TERRAIN_IMPASSABLE) and
      (GDVars.zone0^.view3dFlag = 1) and not blocked then
    blocked := True
  else
    blocked := False;
  if (crIdx > 0) and (crIdx <> excludeIdx) then begin
    tgt := GDVars.creatureArr[crIdx];
    FxEngine.InflictNonWeaponDamage(tgt, damage, 2, FxEngine.RollSavingThrow(tgt, saveType, 0));
    CharHlp.BuildIconFacings(19)
  end
end;

{ Carries a bolt on from the target cell, away from the caster, for the bolt's length in cells, hitting each creature it
  reaches (not the one just hit); at a wall it turns back toward the caster, the first bounce costing 4 more cells when
  the caster is within 4 cells and the bounce flag is set.
  @param(boltLen The bolt's length in cells.)
  @param(damage The electrical damage to each creature hit.)
  @param(saveType The saving-throw type that halves it.)
  @param(bounce True to let the first bounce cost 4 more cells.) }
procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean);
var
  req: Types.TPathState;
  req2: Types.TPathState;
  x0: ShortInt;
  y0: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  sign: ShortInt;
  blocked: Boolean;
  valid: Boolean;
  doBounce: Boolean;
  prevCr: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  budget: Byte;
  spent: Byte;
begin
  blocked := False;
  CharHlp.BuildIconFacings(19);
  CbtMap.GetArenaContents(GDVars.targetX, GDVars.targetY, prevCr, terrIdx);
  spent := 0;
  sign := 1;
  x0 := CbtMap.CombatCellX(Types.PCharRecord(GDVars.curChar));
  y0 := CbtMap.CombatCellY(Types.PCharRecord(GDVars.curChar));
  doBounce := bounce;
  if (x0 = GDVars.targetX) and (y0 = GDVars.targetY) then Exit;
  budget := boltLen * 2;
  GDVars.multiTarget := 1;
  while budget > 0 do begin
    FillChar(req, SizeOf(req), 0);
    req.startX := GDVars.targetX;
    req.startY := GDVars.targetY;
    req.endX := GDVars.targetX + (GDVars.targetX - x0) * sign * budget;
    req.endY := GDVars.targetY + (GDVars.targetY - y0) * sign * budget;
    Pathing.PathFind(req);
    repeat
      prevX := req.currentX;
      prevY := req.currentY;
      if (req.startX <> req.endX) or (req.startY <> req.endY) then begin
        repeat
          valid := Pathing.NextPathStep(req);
          CbtMap.GetArenaContents(req.currentX, req.currentY, crIdx, terrIdx);
          if GDConsts.terrainInfo[terrIdx].movementCost = 1 then blocked := False
        until (not valid) or ((crIdx > 0) and (crIdx <> prevCr)) or (terrIdx = 0) or
            (GDConsts.terrainInfo[terrIdx].movementCost > 1) or
            (req.distance >= budget)
      end;
      if terrIdx = 0 then budget := 0;
      CharHlp.CombatAnimateMovingIcon(prevX, prevY, req.currentX, req.currentY, 4, 50);
      Magic.LightningAttackAt(req.currentX, req.currentY, damage, saveType, prevCr, blocked);
      prevCr := crIdx;
      if blocked then begin
        GDVars.targetX := req.currentX;
        GDVars.targetY := req.currentY;
        FillChar(req2, SizeOf(req2), 0);
        req2.startX := GDVars.targetX;
        req2.startY := GDVars.targetY;
        req2.endX := x0;
        req2.endY := y0;
        Pathing.PathFind(req2);
        while Pathing.NextPathStep(req2) do ;
        if doBounce and (req2.distance <= 8) then Inc(req.distance, 8);
        sign := 0 - sign;
        doBounce := False;
        prevCr := 0
      end;
      spent := req.distance - spent;
      if spent < budget then
        Dec(budget, spent)
      else
        budget := 0;
      spent := req.distance
    until blocked or (budget = 0)
  end;
  GDVars.multiTarget := 0
end;

{ Casts Lightning Bolt: caster-level d6 electrical damage at the target cell, carried on as a 7-cell bolt that can
  bounce. }
procedure SpellLightningBolt;
var
  dmg: Byte;
  blocked: Boolean;
begin
  dmg := FxEngine.RollDice(CharHlp.GetCasterLevel(GDVars.currentSpell), 6);
  GDVars.elementMask := $0C;
  Magic.LightningAttackAt(GDVars.targetX, GDVars.targetY, dmg, 4, 0, blocked);
  Magic.LightningPath(7, dmg, 4, True)
end;

{ Casts Slow on the caster's enemies; it removes Haste instead where there is one. }
procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, CharHlp.EnemyTeam(GDVars.curChar), 'is Slowed')
end;

{ Spell 56 (Restoration): does nothing. }
procedure SpellRestoration;
begin
end;

{ Removes Slow from the target, or else applies the Potion of Speed's effect. }
procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.spellTargets[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is Speedy')
end;

{ Casts Cure Serious Wounds: heals the target 2d8 + 1, 1d8 more when the caster's deity is 4. }
procedure SpellCureSeriousWounds;
var
  bonus: Byte;
begin
  if GDVars.spellTargetCount = 0 then Exit;
  if Byte(GDVars.curChar^.deity) = 4 then
    bonus := FxEngine.RollDice(1, 8)
  else
    bonus := 0;
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(2, 8) + 1 + bonus, False) then
    CharHlp.AnnounceHealStatus(GDVars.spellTargets[1])
end;

{ Gives the target frost giant strength: Strength 21 for 1d4 * 10 + 40, announced when that beats the target's own; the
  effect is added either way. }
procedure SpellGiantStrength;
var
  effStrength: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldStrength: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.spellTargets[1], 21, 0, effStrength) then
    CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], 'is stronger', 10, True);
  FxEngine.AddEffect(GDVars.spellTargets[1], 113, FxEngine.RollDice(1, 4) * 10 + 40, effStrength, True);
  FxEngine.RecalcAbility(GDVars.spellTargets[1], 0)
end;

{ Spell 60 (javelin of lightning): 1d6 + 20 electrical damage at the target cell, then a 3-cell bolt of 20 that does not
  bounce. }
procedure SpellJavelinOfLightning;
var
  blocked: Boolean;
begin
  GDVars.elementMask := $04;
  Magic.LightningAttackAt(GDVars.targetX, GDVars.targetY, FxEngine.RollDice(1, 6) + 20, 4, 0, blocked);
  Magic.LightningPath(3, 20, 4, False)
end;

{ Applies the Wand of Paralyzation's effect to the targets ("is paralyzed"). }
procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is paralyzed')
end;

{ Heals the first target 2d4 + 2 hit points for the Potion of Healing. }
procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], 1, 'is Healed')
end;

{ Applies the Dust of Disappearance's effect. }
procedure SpellDustOfDisappearance;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is invisible')
end;

{ Deals the Wand of Magic Missiles' 2d4 + 2 magic damage. }
procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, FxEngine.RollDamageDice(2, 4) + 2, 8, '')
end;

{ Spell 66 (Cause Serious Wounds): 2d8 + 1 magic damage, 2d8 + 3 when the caster's deity is 4. }
procedure SpellCauseSeriousWounds;
var
  bonus: Byte;
begin
  if Byte(GDVars.curChar^.deity) = 4 then
    bonus := 3
  else
    bonus := 1;
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, FxEngine.RollDamageDice(2, 8) + bonus, 8, '')
end;

{ Casts Neutralize Poison: cures the poison of a target that is not animated (Poisoned and both slow-poison effects
  removed with the effect lock), raising 0 hit points to 1 and setting it okay; an unpoisoned target "is unaffected". }
procedure SpellNeutralizePoison;
var
  tgt: Types.PCharRecord;
  eff: Pointer;
begin
  tgt := GDVars.spellTargets[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, eff) then begin
    if tgt^.hpCur = 0 then tgt^.hpCur := 1;
    GDVars.effectBusy := 1;
    FxEngine.RemoveEffect(tgt, C_Effect.POISONED, nil);
    FxEngine.RemoveEffect(tgt, C_Effect.SLOW_POISON, nil);
    FxEngine.RemoveEffect(tgt, C_Effect.POISON_DAMAGE, nil);
    GDVars.effectBusy := 0;
    CharHlp.PrintCreatureMessage(tgt, 'is unpoisoned', 10, True);
    tgt^.inPlay := 1;
    tgt^.status := C_Status.OKAY
  end else
    CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
end;

{ Casts Poison: applies the spell, then, unless the effects of the caster's target cancel the poison attack, runs the
  poison attack's handler (a poison bite) for the caster. }
procedure SpellPoison;
var
  source: Pointer;
  p: Pointer;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 8, '');
  p := GDVars.curChar^.combatAddr^.target;
  GDVars.currentEffectId := 64;
  FxEngine.TriggerEffectsWithCondition(9, p);
  if GDVars.currentEffectId = 64 then
    FxEngine.CallEffectHandler(64, GDVars.curChar, source, False)
end;

{ Casts Sticks to Snakes: a target below attack level 6 fights snakes, with the caster level as the effect's strength; a
  stronger one "smashes them flat". }
procedure SpellSticksToSnakes;
var
  eff: Pointer;
begin
  if Types.PCharRecord(GDVars.spellTargets[1])^.levelHighest < 6 then begin
    Magic.ResolveSpell(GDVars.currentSpell, CharHlp.GetCasterLevel(GDVars.currentSpell), False, 0, 8, '');
    if CharHlp.HasEffect(GDVars.spellTargets[1], 3, eff) then
      FxEngine.CallEffectHandler(3, GDVars.spellTargets[1], eff, False)
  end else
    CharHlp.PrintCreatureMessage(GDVars.spellTargets[1], 'smashes them flat', 10, True)
end;

{ Spell 71 (Cure Critical Wounds): does nothing. }
procedure SpellCureCriticalWounds;
var
  { Unused in this version; see the other implementations of this routine. }
  bonus: Word;
begin
end;

{ Spell 72 (Cause Critical Wounds): does nothing. }
procedure SpellCauseCriticalWounds; begin end;

{ Spell 73 (Dispel Evil): does nothing. }
procedure SpellDispelEvil; begin end;

{ Spell 74 (Flame Strike): does nothing. }
procedure SpellFlameStrike; begin end;

{ Spell 75 (Raise Dead): does nothing. }
procedure SpellRaiseDead;
var
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
begin
end;

{ Spell 76 (Slay Living): does nothing. }
procedure SpellSlayLiving;
var
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
begin
end;

{ Spell 78 (Entangle): does nothing. }
procedure SpellEntangle;
var
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  saved: Boolean;
begin
end;

{ Spell 79 (Faerie Fire): does nothing. }
procedure SpellFaerieFire; begin end;

{ Spell 80 (Invisibility to Animals): does nothing. }
procedure SpellInvisibilityToAnimals; begin end;

{ Casts Charm Monsters: ApplyEffectToTargets ("is charmed"), then the charm handler for each charmed target. }
procedure SpellCharmMonsters;
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  charmCount: Integer;
  eff: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  charmInfo: array[0..2] of Byte;
begin
  Magic.ApplyEffectToTargets(0, 'is charmed');
  for i := 1 to GDVars.spellTargetCount do
    if CharHlp.HasEffect(GDVars.spellTargets[i], 11, eff) then
      FxEngine.CallEffectHandler(11, GDVars.spellTargets[i], eff, False)
end;

{ Casts Confusion: up to 2d8 targets save (type 4) or are confused. }
procedure SpellConfusion;
var
  i: Byte;
  saved: Boolean;
  tgt: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  maxTargets: Byte;
begin
  maxTargets := FxEngine.RollDice(2, 8);
  if GDVars.spellTargetCount > maxTargets then GDVars.spellTargetCount := maxTargets;
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      saved := FxEngine.RollSavingThrow(tgt, 4, 0);
      FxEngine.AddEffectWithMessage(tgt, 35, Magic.CalcSpellDuration(82), 0, 0, 1, Byte(saved), 'is confused')
    end
end;

{ Casts Dimension Door: erases the caster's icon, places it on the target cell, scrolls the view to it and reports
  "teleports". Note: the placement's result is ignored. }
procedure SpellDimensionDoor;
var
  caster: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  target: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  locOk: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  caster := Types.PCharRecord(GDVars.curChar);
  CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(Types.PCharRecord(caster)));
  locOk := CbtMap.IsValidCreatureLoc(Types.PCharRecord(caster), GDVars.targetX, GDVars.targetY, False);
  CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(caster)), CbtMap.CombatCellY(Types.PCharRecord(caster)), 0, 8);
  CharHlp.PrintCreatureMessage(caster, 'teleports', 10, True)
end;

{ Spell 84 (Fear): a 3-ray cone of 6 cells; each target saves (type 4) or runs in terror (effect 111), fleeing as a
  quick fighter with no target. }
procedure SpellFear;
var
  caster: Types.PCharRecord;
  tgt: Types.PCharRecord;
  i: Byte;
  saved: Boolean;
begin
  caster := Types.PCharRecord(GDVars.curChar);
  Magic.CollectConeTargets(CbtMap.CombatCellX(Types.PCharRecord(caster)), CbtMap.CombatCellY(Types.PCharRecord(caster)),
                     GDVars.targetX, GDVars.targetY, 3, 6);
  for i := 1 to GDVars.spellTargetCount do begin
    tgt := GDVars.spellTargets[i];
    saved := FxEngine.RollSavingThrow(tgt, 4, 0);
    if not saved then begin
      FxEngine.AddEffectWithMessage(tgt, 111, Magic.CalcSpellDuration(84), 0, 1, 1, Byte(saved), 'runs in terror');
      tgt^.combatAddr^.turned := 1;
      tgt^.quickfight := 1;
      if tgt^.npc <= $7F then tgt^.npc := $B3;
      tgt^.combatAddr^.target := nil
    end else
      CharHlp.PrintCreatureMessage(tgt, 'is unaffected', 10, True)
  end
end;

{ Spell 85 (Fire Shield): asks for hot or cold flames (random for a quick fighter): hot gives the caster effects 50 and
  112, cold 54 and 112; any other answer offers to abort. }
procedure SpellFireShield;
var
  ch: Char;
  ext: Boolean;
  done: Boolean;
begin
  done := False;
  repeat
    if Types.PCharRecord(GDVars.curChar)^.quickfight <> 0 then begin
      if FxEngine.RollDice(1, 10) > 5 then ch := 'H' else ch := 'C'
    end else
      ch := MenuCore.MenuHorizontal('flame type: ', 'Hot Cold', LightMagenta, LightGreen, White, False, False, ext);
    case ch of
      'H':
        begin
          FxEngine.AddEffectWithMessage(GDVars.curChar, 50, Magic.CalcSpellDuration(85), 0, 0, 0, 0,
                                        'is protected');
          FxEngine.AddEffectWithMessage(GDVars.curChar, 112, Magic.CalcSpellDuration(85), 0, 0, 0, 0, '');
          done := True
        end;
      'C':
        begin
          FxEngine.AddEffectWithMessage(GDVars.curChar, 54, Magic.CalcSpellDuration(85), 0, 0, 0, 0, '');
          FxEngine.AddEffectWithMessage(GDVars.curChar, 112, Magic.CalcSpellDuration(85), 0, 0, 0, 0, '');
          done := True
        end else begin
        ch := MenuCore.MenuHorizontal('Abort spell? ', 'Yes No', LightMagenta, LightGreen, White, False, False, ext);
        if ch = 'Y' then done := True
      end
    end
  until done
end;

{ Casts Fumble: a first target that fails a save (type 4) becomes clumsy ('is clumsy'), one that saves is slowed ('is
  slowed'), each effect with its handler run; then the spell's table effect is resolved on the targets as well ('is
  clumsy'). }
procedure SpellFumble;
var
  tgt: Types.PCharRecord;
  eff: Pointer;
begin
  tgt := GDVars.spellTargets[1];
  GDVars.elementMask := $40;
  if not FxEngine.RollSavingThrow(tgt, 4, 0) then begin
    FxEngine.AddEffectWithMessage(tgt, 27, Magic.CalcSpellDuration(86), 0, 0, 0, 0, 'is clumsy');
    if CharHlp.HasEffect(tgt, 27, eff) then
      FxEngine.CallEffectHandler(27, tgt, nil, False)
  end else begin
    FxEngine.AddEffectWithMessage(tgt, C_Effect.SLOWED, Magic.CalcSpellDuration(86), 0, 0, 0, 0, 'is slowed');
    if CharHlp.HasEffect(tgt, C_Effect.SLOWED, eff) then
      FxEngine.CallEffectHandler(C_Effect.SLOWED, tgt, nil, False)
  end;
  Magic.ResolveSpell(GDVars.currentSpell, 0, True, 0, 0, 'is clumsy')
end;

{ Casts Ice Storm: deals 3d10 cold damage. }
procedure SpellIceStorm;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, FxEngine.RollDamageDice(3, 10), 10, '')
end;

{ Casts Minor Globe of Invulnerability: applies its effect to the targets. }
procedure SpellMinorGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, 'is protected')
end;

{ Spell 91 (Cloudkill): does nothing. }
procedure SpellCloudkill;
var
  { Unused in this version; see the other implementations of this routine. }
  otherCloud: Types.PCloudNode;
  { Unused in this version; see the other implementations of this routine. }
  node: Types.PCloudNode;
  { Unused in this version; see the other implementations of this routine. }
  crIdx: array[1..9] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  j: Byte;
  { Unused in this version; see the other implementations of this routine. }
  myClouds: Byte;
  { Unused in this version; see the other implementations of this routine. }
  terr: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cl: Byte;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  dirIdx: Byte;
begin
end;

{ Spell 92 (Cone of Cold): does nothing. }
procedure SpellConeOfCold;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  reach: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lvl: Byte;
begin
end;

{ Spell 93 (Feeblemind): does nothing. }
procedure SpellFeeblemind;
var
  { Unused in this version; see the other implementations of this routine. }
  oldSpellSave: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
end;

{ Gives the targets the spell's effect, immunity to breath. }
procedure SpellImmuneBreath;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, '')
end;

{ Spell 96: applies its effect. }
procedure SpellImmuneParalysis;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, '')
end;

{ Spell 97: gives the targets the spell's effect. }
procedure SpellTurnInvisible;
begin
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, 0, 0, '')
end;

{ Spell 98: does nothing. }
procedure SpellConeBlast;
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  caster: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  saved: Boolean;
begin
end;

{ Spell 99: heals the target 2d4 + 2 hit points. }
procedure SpellHealSelf;
begin
  if FxEngine.RestoreHitPoints(GDVars.spellTargets[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.spellTargets[1], 1, 'is Healed')
end;

{ Effect 4: acts three times in four. While breaths are left (three per battle), a quarter of the time it breathes on
  the last enemy next to it ("Breathes!"): 10 damage on a save (type 3), else 20 and blindness, which ends its actions.
  Otherwise it fires an energy bolt at a chosen target (as spell 61), 1d8 + 2 damage, and a second one when the target
  is still in play, ending its actions.
  @param(cr The creature that carries the effect.)
  @param(eff The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffBlindBreathEnergyBolt(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  boltFired: Boolean;
  fired: Boolean;
  tgt: Types.PCharRecord;
  i: Byte;
begin
  tgt := nil;
  fired := False;
  if GDVars.roundNumber = 0 then
    Types.PEffectRec(eff)^.strength := 3;
  if FxEngine.RollDice(1, 100) > 75 then Exit;

  if Types.PEffectRec(eff)^.strength <> 0 then
  if FxEngine.RollDice(1, 100) <= 25 then begin
    tgt := nil;
    Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)), 1,
                            255, 1, GDVars.arena);
    for i := 2 to GDVars.targetCount do
      if Byte(GDVars.creatureArr[GDVars.targetList[i].creatureIndex]^.hostile) <>
          Byte(Types.PCharRecord(cr)^.hostile) then
        tgt := GDVars.creatureArr[GDVars.targetList[i].creatureIndex];
    if tgt <> nil then begin
      CharHlp.PrintCreatureMessage(cr, 'Breathes!', 10, True);
      fired := True;
      if FxEngine.RollSavingThrow(tgt, 3, 0) then
        FxEngine.InflictNonWeaponDamage(tgt, 10, 0, True)
      else begin
        FxEngine.InflictNonWeaponDamage(tgt, 20, 0, False);
        FxEngine.AddEffectWithMessage(tgt, C_Effect.BLIND, 0, 0, 0, 0, 0, 'is blinded');
        boltFired := CharHlp.EndActions(cr)
      end;
      Dec(Types.PEffectRec(eff)^.strength)
    end
  end;
  if fired then Exit;

  boltFired := False;
  i := 0;
  repeat
    GDVars.castTargetMenu(61, True, Boolean(GDVars.scratchFlag));
    if (GDVars.spellTargets[1] <> nil) and (GDVars.scratchFlag <> 0) then begin
      Inc(i);
      CharHlp.PrintCreatureMessage(cr, 'Fires An Energy Bolt!', 10, True);
      CharHlp.BuildIconFacings(18);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)),
                                      CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                      CbtMap.CombatCellX(Types.PCharRecord(GDVars.spellTargets[1])),
                                      CbtMap.CombatCellY(Types.PCharRecord(GDVars.spellTargets[1])), 1, 30);
      FxEngine.InflictNonWeaponDamage(GDVars.spellTargets[1], FxEngine.RollDamageDice(1, 8) + 2, 0, False);
      if (GDVars.spellTargets[1]^.inPlay <> 0) and (i = 1) then begin
        FxEngine.InflictNonWeaponDamage(GDVars.spellTargets[1], FxEngine.RollDamageDice(1, 8) + 2, 0, False);
        Inc(i)
      end;
      boltFired := True
    end else
      i := 2
  until i >= 2;
  if boltFired then
    boltFired := CharHlp.EndActions(cr)
end;

{ Effect 78: throws one fireball (as spell 47, 15d6 fire damage) at a chosen target, then loses the effect.
  @param(cr The creature that carries the effect.)
  @param(eff Unused.)
  @param(removed Unused.) }
procedure EffThrowFireball(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  accepted: Boolean;
begin
  GDVars.multiTarget := 1;
  accepted := False;
  GDVars.castTargetMenu(47, True, accepted);
  if not accepted then Exit;

  GDVars.currentSpell := 47;
  CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)), 0, 8);
  CharHlp.PrintCreatureMessage(cr, 'throws a fireball', 10, True);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                  CbtMap.CombatCellX(Types.PCharRecord(GDVars.spellTargets[1])),
                                  CbtMap.CombatCellY(Types.PCharRecord(GDVars.spellTargets[1])), 1, 30);
  Magic.ResolveSpell(GDVars.currentSpell, 0, False, FxEngine.RollDamageDice(15, 6), 9, '');
  FxEngine.RemoveEffect(cr, 78, nil)
end;

{ Effect 84: breathes poison on the creatures within 3 cells of a chosen cell no more than 3 cells away (as spell 36),
  each taking the creature's maximum hit points, halved on a save (type 3); three times per battle.
  @param(cr The creature that carries the effect.)
  @param(eff The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffBreathePoison(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  x: ShortInt;
  y: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  reach: Word;
  accepted: Boolean;
  saved: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  tgt: Types.PCharRecord;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  targetCells: array[1..30] of Byte;
  dir: Byte;
begin
  if GDVars.roundNumber = 0 then
    Types.PEffectRec(eff)^.strength := 3;
  if Types.PEffectRec(eff)^.strength <= 0 then Exit;

  x := CbtMap.CombatCellX(Types.PCharRecord(cr));
  y := CbtMap.CombatCellY(Types.PCharRecord(cr));
  GDVars.castTargetMenu(36, True, accepted);
  if not accepted then Exit;

  Magic.CollectConeTargets(x, y, GDVars.targetX, GDVars.targetY, 255, 3);
  if GDVars.spellTargetCount <= 0 then Exit;
  GDVars.elementMask := $20;
  CharHlp.PrintCreatureMessage(cr, 'breathes poison', 10, True);
  dir := CharHlp.DirTowardTarget(cr, GDVars.spellTargets[1]);
  CharHlp.CombatPrintCreatureInfo(cr);
  CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                  CbtMap.CombatCellX(Types.PCharRecord(GDVars.spellTargets[1])),
                                  CbtMap.CombatCellY(Types.PCharRecord(GDVars.spellTargets[1])), 1, 30);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      saved := FxEngine.RollSavingThrow(tgt, 3, 0);
      FxEngine.InflictNonWeaponDamage(tgt, Types.PCharRecord(cr)^.hpMax, 2, saved)
    end;
  Dec(Types.PEffectRec(eff)^.strength);
  turnDone := CharHlp.EndActions(cr)
end;

{ Lightning breath effect: three times a battle (the effect's strength is set to 3 in round 0 and counts the breaths
  left), the creature aims as for Lightning Bolt; if a target was chosen it prints "Breathes!", turns toward the target
  and breathes lightning at the target cell and along a 10-cell path, doing its maximum hit points (save type 3), then
  spends a breath and ends its turn.
  @param(cr The creature that carries the effect.)
  @param(eff The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffBreatheLightning(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  blocked: Boolean;
  x: ShortInt;
  y: ShortInt;
  dir: Byte;
begin
  if GDVars.roundNumber = 0 then
    Types.PEffectRec(eff)^.strength := 3;
  if Types.PEffectRec(eff)^.strength <= 0 then Exit;
  GDVars.elementMask := $24;
  x := CbtMap.CombatCellX(Types.PCharRecord(cr));
  y := CbtMap.CombatCellY(Types.PCharRecord(cr));
  GDVars.castTargetMenu(51, True, Boolean(GDVars.scratchFlag));
  if GDVars.scratchFlag = 0 then Exit;
  CharHlp.PrintCreatureMessage(cr, 'Breathes!', 10, True);
  dir := CharHlp.DirTowardTarget(cr, GDVars.spellTargets[1]);
  CharHlp.CombatPrintCreatureInfo(cr);
  CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
  CharHlp.BuildIconFacings(19);
  CharHlp.CombatAnimateMovingIcon(x, y, GDVars.targetX, GDVars.targetY, 4, 50);
  Magic.LightningAttackAt(GDVars.targetX, GDVars.targetY, Types.PCharRecord(cr)^.hpMax, 3, 0, blocked);
  Magic.LightningPath(10, Types.PCharRecord(cr)^.hpMax, 3, False);
  Dec(Types.PEffectRec(eff)^.strength);
  blocked := CharHlp.EndActions(cr)
end;

{ Effect 90: an acid breath cone (1 ray, 6 cells) for the creature's maximum hit points, halved on a save (type 3), only
  when every target is on the other side; three times per battle.
  @param(cr The creature that carries the effect.)
  @param(eff The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffBreatheAcid(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  x: ShortInt;
  y: ShortInt;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
  dir: Byte;
begin
  GDVars.scratchFlag := 0;
  if GDVars.roundNumber = 0 then
    Types.PEffectRec(eff)^.strength := 3;
  if Types.PEffectRec(eff)^.strength <= 0 then Exit;
  GDVars.elementMask := $30;
  x := CbtMap.CombatCellX(Types.PCharRecord(cr));
  y := CbtMap.CombatCellY(Types.PCharRecord(cr));
  GDVars.castTargetMenu(61, True, Boolean(GDVars.scratchFlag));
  if GDVars.scratchFlag <> 0 then
    Magic.CollectConeTargets(x, y, GDVars.targetX, GDVars.targetY, 1, 6);
  for i := 1 to GDVars.spellTargetCount do
    if Byte(CharHlp.EnemyTeam(cr)) <> Byte(Types.PCharRecord(GDVars.spellTargets[i])^.hostile) then
      GDVars.scratchFlag := 0;
  if GDVars.scratchFlag = 0 then Exit;
  if GDVars.spellTargetCount <= 0 then Exit;
  CharHlp.PrintCreatureMessage(cr, 'breathes acid', 10, True);
  dir := CharHlp.DirTowardTarget(cr, GDVars.spellTargets[1]);
  CharHlp.CombatPrintCreatureInfo(cr);
  CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                  CbtMap.CombatCellX(Types.PCharRecord(GDVars.spellTargets[1])),
                                  CbtMap.CombatCellY(Types.PCharRecord(GDVars.spellTargets[1])), 1, 30);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      saved := FxEngine.RollSavingThrow(tgt, 3, 0);
      FxEngine.InflictNonWeaponDamage(tgt, Types.PCharRecord(cr)^.hpMax, 2, saved)
    end;
  Dec(Types.PEffectRec(eff)^.strength);
  turnDone := CharHlp.EndActions(cr)
end;

{ Effects 6, 83 and 104: a 3-ray breath cone, cold of 8 cells (effect 6, once per battle) or 7 cells (83), or fire of 9
  cells (104), for the creature's maximum hit points, halved on a save (type 3), only when every target is on the other
  side; effects 83 and 104 breathe three times per battle.
  @param(cr The creature that carries the effect.)
  @param(eff The effect's node on the creature.)
  @param(removed Unused.) }
procedure EffDragonBreath(var cr: Pointer; eff: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
  x: ShortInt;
  y: ShortInt;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
  rays: Byte;
  reach: Byte;
  elementName: String[5];
  dir: Byte;
begin
  if (GDVars.roundNumber = 0) or (Types.PEffectRec(eff)^.strength > 3) then
    if Types.PEffectRec(eff)^.id = 6 then
      Types.PEffectRec(eff)^.strength := 1
    else
      Types.PEffectRec(eff)^.strength := 3;
  if Types.PEffectRec(eff)^.strength <= 0 then Exit;

  case Types.PEffectRec(eff)^.id of
    6, 83:
      begin
        GDVars.elementMask := $22;
        rays := 3;
        if Types.PEffectRec(eff)^.id = 6 then reach := 8 else reach := 7;
        elementName := 'cold'
      end;
    104:
      begin
        GDVars.elementMask := $21;
        rays := 3;
        reach := 9;
        elementName := 'Fire'
      end
  end;

  x := CbtMap.CombatCellX(Types.PCharRecord(cr));
  y := CbtMap.CombatCellY(Types.PCharRecord(cr));
  GDVars.castTargetMenu(61, True, Boolean(GDVars.scratchFlag));
  if GDVars.scratchFlag = 0 then Exit;
  Magic.CollectConeTargets(x, y, GDVars.targetX, GDVars.targetY, rays, reach);
  for i := 1 to GDVars.spellTargetCount do
    if Byte(CharHlp.EnemyTeam(cr)) <> Byte(Types.PCharRecord(GDVars.spellTargets[i])^.hostile) then
      GDVars.scratchFlag := 0;
  if GDVars.spellTargetCount <= 0 then Exit;
  if GDVars.scratchFlag = 0 then Exit;

  CharHlp.PrintCreatureMessage(cr, 'breathes ' + elementName, 10, True);
  dir := CharHlp.DirTowardTarget(cr, GDVars.spellTargets[1]);
  CharHlp.CombatPrintCreatureInfo(cr);
  CbtMap.SetCreatureFacing(Types.PCharRecord(cr), dir, 1, 0);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)),
                                  CbtMap.CombatCellX(Types.PCharRecord(GDVars.spellTargets[1])),
                                  CbtMap.CombatCellY(Types.PCharRecord(GDVars.spellTargets[1])), 1, 30);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.spellTargets[i] <> nil then begin
      tgt := GDVars.spellTargets[i];
      saved := FxEngine.RollSavingThrow(tgt, 3, 0);
      FxEngine.InflictNonWeaponDamage(tgt, Types.PCharRecord(cr)^.hpMax, 2, saved)
    end;
  Dec(Types.PEffectRec(eff)^.strength);
  turnDone := CharHlp.EndActions(cr)
end;

function ItemReadable(it: Pointer): Boolean;
begin
  if (it <> nil) and ((Types.PItemRec(it)^.itemType = 39) or (Types.PItemRec(it)^.itemType = 40)) then
    ItemReadable := True
  else
    ItemReadable := False
end;

procedure RemoveSpellFromScroll(cr, it: Pointer; sp: Byte);
var
  spell: Byte;
  i: Byte;
  found: Byte;
begin
  spell := sp;
  found := 0;
  for i := 1 to 3 do
    if (Types.PItemRec(it)^.spells[i] and $7F) = spell then
      found := i;
  if found = 0 then Exit;
  Types.PItemRec(it)^.spells[found] := 0;
  Dec(Types.PItemRec(it)^.nameIds[1]);
  if Types.PItemRec(it)^.nameIds[1] < 100 then
    CharHlp.RemoveItem(cr, it)
end;

procedure PrintCastSpellMsg(cr: Pointer; s: Types.TStr40; id: Byte);
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    CharHlp.PrintCreatureMessage(cr, 'Casts a Spell', 10, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.displayString(0, 23, LightGreen, Black, 'Spell:' + GDConsts.spellNames[id])
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(cr, 1, 19, False);
    TextRend.displayString(Length(Types.PCharRecord(cr)^.name) + 1 + 1, 19, LightGreen, Black, s);
    TextRend.displayString(1, 20, LightGreen, Black, GDConsts.spellNames[id]);
    TextRend.pauseOnly;
    CharHlp.ClearMessageWindow
  end
end;

procedure InitSpellFns;
begin
  GDVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
  GDVars.effectBusy := 0;
  GDVars.usingItemFlag := 0;
  GDVars.lastTarget := nil;
  GDVars.redrawInvMenu := 1;
  GDVars.spellDispatch[1] := Magic.SpellBless;
  GDVars.spellDispatch[2] := Magic.SpellCurse;
  GDVars.spellDispatch[C_Spell.CURE_LIGHT_WOUNDS] := Magic.SpellCureLightWounds;
  GDVars.spellDispatch[4] := Magic.SpellCauseLightWounds;
  GDVars.spellDispatch[5] := Magic.SpellDetection;
  GDVars.spellDispatch[6] := Magic.SpellProtection;
  GDVars.spellDispatch[7] := Magic.SpellProtection;
  GDVars.spellDispatch[8] := Magic.SpellResistCold;
  GDVars.spellDispatch[9] := Magic.SpellBurningHands;
  GDVars.spellDispatch[10] := Magic.SpellCharmPerson;
  GDVars.spellDispatch[11] := Magic.SpellDetection;
  GDVars.spellDispatch[12] := Magic.SpellEnlarge;
  GDVars.spellDispatch[13] := Magic.SpellReduce;
  GDVars.spellDispatch[14] := Magic.SpellFriends;
  GDVars.spellDispatch[15] := Magic.SpellMagicMissile;
  GDVars.spellDispatch[16] := Magic.SpellProtection;
  GDVars.spellDispatch[17] := Magic.SpellProtection;
  GDVars.spellDispatch[18] := Magic.SpellDetection;
  GDVars.spellDispatch[19] := Magic.SpellShield;
  GDVars.spellDispatch[20] := Magic.SpellShockingGrasp;
  GDVars.spellDispatch[21] := Magic.SpellSleep;
  GDVars.spellDispatch[22] := Magic.SpellDetection;
  GDVars.spellDispatch[23] := Magic.SpellHold;
  GDVars.spellDispatch[24] := Magic.SpellResistFire;
  GDVars.spellDispatch[25] := Magic.SpellSilence;
  GDVars.spellDispatch[26] := Magic.SpellSlowPoison;
  GDVars.spellDispatch[27] := Magic.SpellSnakeCharm;
  GDVars.spellDispatch[28] := Magic.SpellSpiritualHammer;
  GDVars.spellDispatch[29] := Magic.SpellDetection;
  GDVars.spellDispatch[30] := Magic.SpellInvisibility;
  GDVars.spellDispatch[31] := Magic.SpellKnock;
  GDVars.spellDispatch[32] := Magic.SpellMirrorImage;
  GDVars.spellDispatch[33] := Magic.SpellRayOfEnfeeblement;
  GDVars.spellDispatch[34] := Magic.SpellStinkingCloud;
  GDVars.spellDispatch[35] := Magic.SpellStrength;
  GDVars.spellDispatch[36] := Magic.SpellAnimateDead;
  GDVars.spellDispatch[37] := Magic.SpellCureBlindness;
  GDVars.spellDispatch[38] := Magic.SpellCauseBlindness;
  GDVars.spellDispatch[39] := Magic.SpellCureDisease;
  GDVars.spellDispatch[40] := Magic.SpellCauseDisease;
  GDVars.spellDispatch[41] := Magic.SpellDispelMagic;
  GDVars.spellDispatch[42] := Magic.SpellPrayer;
  GDVars.spellDispatch[43] := Magic.SpellRemoveCurse;
  GDVars.spellDispatch[44] := Magic.SpellBestowCurse;
  GDVars.spellDispatch[45] := Magic.SpellBlink;
  GDVars.spellDispatch[46] := Magic.SpellDispelMagic;
  GDVars.spellDispatch[47] := Magic.SpellFireball;
  GDVars.spellDispatch[48] := Magic.SpellHaste;
  GDVars.spellDispatch[49] := Magic.SpellHold;
  GDVars.spellDispatch[50] := Magic.SpellInvisibility;
  GDVars.spellDispatch[51] := Magic.SpellLightningBolt;
  GDVars.spellDispatch[52] := Magic.SpellProtection;
  GDVars.spellDispatch[53] := Magic.SpellProtection;
  GDVars.spellDispatch[54] := Magic.SpellProtection;
  GDVars.spellDispatch[55] := Magic.SpellSlow;
  GDVars.spellDispatch[56] := Magic.SpellRestoration;
  GDVars.spellDispatch[57] := Magic.SpellPotionOfSpeed;
  GDVars.spellDispatch[58] := Magic.SpellCureSeriousWounds;
  GDVars.spellDispatch[59] := Magic.SpellGiantStrength;
  GDVars.spellDispatch[60] := Magic.SpellJavelinOfLightning;
  GDVars.spellDispatch[61] := Magic.SpellWandOfParalyzation;
  GDVars.spellDispatch[62] := Magic.SpellPotionOfHealing;
  GDVars.spellDispatch[63] := Magic.SpellDustOfDisappearance;
  GDVars.spellDispatch[64] := Magic.SpellFireball;
  GDVars.spellDispatch[65] := Magic.SpellWandOfMagicMissiles;
  GDVars.spellDispatch[66] := Magic.SpellCauseSeriousWounds;
  GDVars.spellDispatch[67] := Magic.SpellNeutralizePoison;
  GDVars.spellDispatch[68] := Magic.SpellPoison;
  GDVars.spellDispatch[69] := Magic.SpellProtection;
  GDVars.spellDispatch[70] := Magic.SpellSticksToSnakes;
  GDVars.spellDispatch[71] := Magic.SpellCureCriticalWounds;
  GDVars.spellDispatch[72] := Magic.SpellCauseCriticalWounds;
  GDVars.spellDispatch[73] := Magic.SpellDispelEvil;
  GDVars.spellDispatch[74] := Magic.SpellFlameStrike;
  GDVars.spellDispatch[75] := Magic.SpellRaiseDead;
  GDVars.spellDispatch[76] := Magic.SpellSlayLiving;
  GDVars.spellDispatch[77] := Magic.SpellDetection;
  GDVars.spellDispatch[78] := Magic.SpellEntangle;
  GDVars.spellDispatch[79] := Magic.SpellFaerieFire;
  GDVars.spellDispatch[80] := Magic.SpellInvisibilityToAnimals;
  GDVars.spellDispatch[81] := Magic.SpellCharmMonsters;
  GDVars.spellDispatch[82] := Magic.SpellConfusion;
  GDVars.spellDispatch[83] := Magic.SpellDimensionDoor;
  GDVars.spellDispatch[84] := Magic.SpellFear;
  GDVars.spellDispatch[85] := Magic.SpellFireShield;
  GDVars.spellDispatch[86] := Magic.SpellFumble;
  GDVars.spellDispatch[87] := Magic.SpellIceStorm;
  GDVars.spellDispatch[88] := Magic.SpellMinorGlobeOfInvulnerability;
  GDVars.spellDispatch[89] := Magic.SpellRemoveCurse;
  GDVars.spellDispatch[90] := Magic.SpellAnimateDead;
  GDVars.spellDispatch[91] := Magic.SpellCloudkill;
  GDVars.spellDispatch[92] := Magic.SpellConeOfCold;
  GDVars.spellDispatch[93] := Magic.SpellFeeblemind;
  GDVars.spellDispatch[94] := Magic.SpellHold;
  GDVars.spellDispatch[95] := Magic.SpellImmuneBreath;
  GDVars.spellDispatch[96] := Magic.SpellImmuneParalysis;
  GDVars.spellDispatch[97] := Magic.SpellTurnInvisible;
  GDVars.spellDispatch[98] := Magic.SpellConeBlast;
  GDVars.spellDispatch[99] := Magic.SpellHealSelf;
  GDVars.spellDispatch[100] := Magic.SpellBestowCurse;
  GDVars.spellDispatch[101] := Magic.SpellProtection;
  GDVars.spellDispatch[102] := Magic.SpellSilence;
  GDVars.spellDispatch[103] := Magic.SpellDetection;
  GDVars.spellDispatch[104] := Magic.SpellRemoveCurse;
  GDVars.spellDispatch[105] := Magic.SpellBless;
  GDVars.spellDispatch[106] := Magic.SpellCharmPerson;
  GDVars.spellDispatch[107] := Magic.SpellBurningHands;
  @GDVars.effectHandlers[4] := @Magic.EffBlindBreathEnergyBolt;
  @GDVars.effectHandlers[6] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[104] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[83] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[84] := @Magic.EffBreathePoison;
  @GDVars.effectHandlers[85] := @Magic.EffBreatheLightning;
  @GDVars.effectHandlers[90] := @Magic.EffBreatheAcid;
  @GDVars.effectHandlers[78] := @Magic.EffThrowFireball
end;

begin
end.
