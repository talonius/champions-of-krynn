{ The character sheet, the inventory, trade and drop-money menus, and the spell-menu front end.

  The character sheet shows the status at the top right; a cleric's patron deity is prepended to the class name, the
  robe color is spliced in front of `Mage` in a multiclass name, and a Solamnic knight's order appends ' of the Crown',
  ' of the Sword' or ' of the Rose'. The money routines walk coin slots 1..6, never 0. Identifying an item costs 100
  steel. ToggleReadyItem refuses itemType $27 without a matching robe order ('Wrong Magical Order') and itemType $43 for
  anyone but a kender ('Usable Only By Kender'). CanHeal, CanCure, PaladinLayOnHands and PaladinCureDisease have empty
  bodies; their callers remain. }
{$O+,F+}
unit ViewChar;

interface

uses Types, Border, TextRend, GameTime, Money, Magic, FxEngine, CharHlp, ClassCal, MenuCore, MapView, Portrait, CbtMap,
  Debug, GDConsts, GDVars, C_Keys, C_Class, C_Race, Crt, C_Ifc, C_Gbvm, C_Status, C_Effect,
  C_Stat, C_Npc, C_Item;

{ Draws the current character's sheet: name, status, gender and age, alignment, race, class (with a cleric's deity in
  front, a magic-user's robe order before Mage, and a knight's order after it), levels, experience, the six abilities,
  the money, the combat values, and the readied weapon and armor. The character becomes tempCr1. }
procedure DisplayChar;

{ Recalculates the current character's stats and shows its hit points, armor class, encumbrance, THAC0, movement
  (doubled when hasted, halved when slowed) and damage dice on the character sheet. }
procedure PrintCombatStats;

{ Draws one of the current character's abilities on its row of the character sheet, in light magenta while modifying and
  light green otherwise. Strength 18 with exceptional strength adds '(NN)', with 100 shown as '(00)'; a '*' marks a
  current value (or exceptional strength) that differs from its base.
  @param(statIdx The ability, 0 to 5.)
  @param(modifying True draws it in the modify color.) }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

{ Lists the current character's money of types 1..6 on the character sheet; type 0 is never shown. }
procedure PrintMoney;

{ Shows the character sheet and runs its menu: Items, Spells, Trade (outside combat, for a player character or one out
  of play or animated, with money), Drop, Heal and Cure (when the character can), and Exit. The sheet is redrawn after
  items, spells or trade, and the noncombat interface afterwards.
  @param(done Set True when an item use ends the character's turn.) }
procedure ViewCharMenu(var done: Boolean);

{ Runs the current character's item menu: View (in debug mode), Ready, Use (in play, with no anti-magic, outside combat
  or when item use is allowed this round), Trade (outside combat, for a player character or one out of play or
  animated), Drop, Halve (below 16 items), Join, Sell and Id (in a shop). It repeats until Exit, Escape, an action that
  ends the turn, or no items are left.
  @param(done Set True when an item use ends the character's turn.) }
procedure UseItemMenu(var done: Boolean);

{ Readies or unreadies an item of the current character. A cursed item cannot be unreadied. Readying fails, with a
  message, for the wrong class, a slot already in use, too many hands, a robe of the wrong magical order, or a hoopak
  for anyone but a kender. An item with a special effect turns it on or off.
  @param(it The item.) }
procedure ToggleReadyItem(it: Types.PItemRec);

{ Uses an item of the current character: a scroll casts a spell picked from it (reliably for a magic-user or cleric, 75
  percent of the time for a thief above level 9, and otherwise "oops!"), any other item with a spell effect casts that
  spell. A use that completes spends the scroll's spell, or one of the item's quantity or charges, removing an item
  whose charges run out; in combat a combat spell ends the turn.
  @param(it The item.)
  @param(done Set True when the use completes.) }
procedure UseItem(it: Types.PItemRec; var done: Boolean);

{ Tells whether a character cannot take an item: it already holds 16 items, or the item's weight, times its quantity,
  would take it past its weight allowance plus 1500. The character's stats are recomputed first.
  @param(cr The character.)
  @param(it The item.)
  @returns(True when the character cannot take the item.) }
function CannotCarryItem(cr: Types.PCharRecord; it: Types.PItemRec): Boolean;

{ Makes the previous (up arrow) or next (down arrow) party member current, wrapping at either end; any other key selects
  the first member. Nothing changes after a mouse click.
  @param(c The key's scan code.) }
procedure SelectPrevNextChar(c: Char);

{ Works out what a character's coins are worth in steel, leaving out gems and jewelry.
  @param(cr The character.)
  @returns(The value in whole steel pieces.) }
function CreatureCoinValueInSteel(cr: Types.PCharRecord): LongInt;

{ Lists the current character's spells of a kind (memorized, grimoire, scroll, scrolls, choose, memorize, scribe) under
  its name and lets the player pick one.
  @param(menuType The list kind, 0..6.)
  @param(selType How the list is drawn and chosen from, passed to Magic.SpellSelection.)
  @param(idx The highlighted entry, kept between calls; negative redraws the frame.)
  @param(notEmpty Set True when the list has spells.)
  @returns(The spell picked, or 0.) }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

{ Always refuses: laying on hands is not offered.
  @param(cr Unused.)
  @returns(False.) }
function CanHeal(cr: Types.PCharRecord): Boolean;

{ Always refuses: curing disease is not offered.
  @param(cr Unused.)
  @returns(False.) }
function CanCure(cr: Types.PCharRecord): Boolean;

{ Empty: laying on hands does nothing.
  @param(cr Unused.) }
procedure PaladinLayOnHands(cr: Types.PCharRecord);

{ Empty: curing disease does nothing.
  @param(cr Unused.) }
procedure PaladinCureDisease(cr: Types.PCharRecord);

{ Shows an item's raw fields (type, name parts, plus, readiness, identification, curse, value, specials, missile type,
  range and slot) on a debug screen and waits for a key.
  @param(it The item.) }
procedure ViewItemDetail(it: Types.PItemRec);

{ Calls the priming entries of MenuCore, Portrait, Magic, FxEngine, Money, GameTime, MapView, CharHlp, ClassCal and the
  trace overlay, so the overlay manager loads them; CbtMap, which this unit also uses, is not primed. }
procedure PrimeViewChar;

{ Lets the player pick a party member with the arrow keys, allowing party picks with the mouse meanwhile.
  @returns(True when Select was chosen, False on Exit or Escape.) }
function PickCharacter: Boolean;

implementation

{ Private routines implemented after their callers. }
procedure ItemTradeMenu(it: Types.PItemRec); forward;

procedure HalveItem(it: Types.PItemRec); forward;

procedure JoinItem(it: Types.PItemRec); forward;

procedure SellItem(it: Types.PItemRec); forward;

procedure IdentifyItem(it: Types.PItemRec; var newInfo: Boolean); forward;

procedure TradeTreasureMenu; forward;

procedure DropMoneyMenu; forward;

procedure PrimeViewChar;
begin
  MenuCore.PrimeMenuCore;
  Portrait.PrimePortrait;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  Money.PrimeMoney;
  GameTime.PrimeGameTime;
  MapView.PrimeMapView;
  CharHlp.PrimeCharHlp;
  Debug.PrimeDebug;
  ClassCal.PrimeClassCal;
end;

procedure DisplayChar;
var
  { Unused in this version; see the other implementations of this routine. }
  statRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  i: Byte;
  statIdx: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
begin
  GDVars.tempCr1 := GDVars.curChar;
  Border.DrawCharSheetFrame;
  CharHlp.DisplayCreatureName(GDVars.tempCr1, 1, 1, False);
  TextRend.displayString(20, 1, White, Black, 'Status:');
  TextRend.displayString(27, 1, LightGreen, Black, GDConsts.statusNames[ShortInt(GDVars.tempCr1^.status)]);
  s := GDConsts.genderNames[GDVars.tempCr1^.gender];
  TextRend.displayString(1, 3, White, Black, s);
  TextRend.displayString(8, 3, White, Black, CharHlp.Uint16Str(GDVars.tempCr1^.age) + ' years');
  s := GDConsts.alignmentNames[GDVars.tempCr1^.alignment];
  TextRend.displayString(1, 4, White, Black, s);
  s := GDConsts.raceNames[GDVars.tempCr1^.race];
  TextRend.displayString(20, 4, White, Black, s);
  s := GDConsts.classNames[GDVars.tempCr1^.charClass];
  if GDVars.tempCr1^.classLevels[C_Class.CLERIC] > 0 then
    s := GDConsts.deityNames[GDVars.tempCr1^.deity] + ' ' + s;
  if GDVars.tempCr1^.classLevels[C_Class.MAGE] > 0 then begin
    i := 0;
    repeat
      Inc(i);
    until ((s[i] = 'M') and (s[i + 2] = 'g')) or (i > Length(s));
    Insert(GDConsts.orderNames[GDVars.tempCr1^.robeOrder] + ' ', s, i);
  end;
  if GDVars.tempCr1^.classLevels[C_Class.KNIGHT] > 0 then
    case GDVars.tempCr1^.knightOrder of
      1: s := s + ' of the Crown';
      2: s := s + ' of the Sword';
      3: s := s + ' of the Rose';
    end;
  TextRend.displayString(1, 5, White, Black, s);
  TextRend.displayString(1, 7, White, Black, 'Level');
  multi := False;
  s := '';
  for j := 0 to 7 do
    if (GDVars.tempCr1^.classLevels[j] > 0) or
        ((GDVars.tempCr1^.classLevels2[j] < ClassCal.CurrentDualClassLevel(GDVars.tempCr1)) and
         (GDVars.tempCr1^.classLevels2[j] > 0)) then begin
      if multi then
        s := s + '/';
      s := s + CharHlp.Uint8Str(GDVars.tempCr1^.classLevels[j] + GDVars.tempCr1^.classLevels2[j]);
      multi := True;
    end;
  TextRend.displayString(7, 7, White, Black, s);
  TextRend.displayString(20, 7, White, Black, 'Experience ' + CharHlp.Int32Str(GDVars.tempCr1^.experience));
  for statIdx := 0 to 5 do begin
    case statIdx of
      C_Stat.STRENGTH: s := 'STR ';
      C_Stat.INTELLIGENCE: s := 'INT ';
      C_Stat.WISDOM: s := 'WIS ';
      C_Stat.DEXTERITY: s := 'DEX ';
      C_Stat.CONSTITUTION: s := 'CON ';
      C_Stat.CHARISMA: s := 'CHA ';
    end;
    TextRend.displayString(1, statIdx + 9, LightGreen, Black, s);
    ViewChar.PrintStat(statIdx, False);
  end;
  ViewChar.PrintMoney;
  ViewChar.PrintCombatStats;
  if GDVars.tempCr1^.equipped[0] <> nil then
    CharHlp.PrintItemString(GDVars.tempCr1, GDVars.tempCr1^.equipped[0], 1, 21, False, True);
  if GDVars.tempCr1^.equipped[2] <> nil then
    CharHlp.PrintItemString(GDVars.tempCr1, GDVars.tempCr1^.equipped[2], 1, 22, False, True);
end;

procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(20, 9, 38, 15);
  row := 9;
  for m := 1 to 6 do
    if GDVars.curChar^.coinsA[m] > 0 then begin
      s := GDConsts.moneyNames[m];
      TextRend.displayString(20, row, LightGreen, Black, s);
      s := CharHlp.Uint16Str(GDVars.curChar^.coinsA[m]);
      TextRend.displayString(38 - Length(s), row, LightGreen, Black, s);
      Inc(row);
    end;
end;

procedure PrintCombatStats;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  col: Byte;
  mv: Byte;
  s: Types.TStr40;
  eff: Types.PEffectRec;

  { Pads t with leading spaces to width. }
  procedure RightAlignField(var t: Types.TStr40; width: Byte);
  begin
    while Length(t) < width do
      t := ' ' + t;
  end;

begin
  p := GDVars.curChar;
  CharHlp.RecalcStats(p);
  TextRend.displayString(20, 3, White, Black, 'Hit Points ');
  Border.ClearBox(31, 3, 37, 3);
  CharHlp.PrintHitPoints(p, 31, 3, False, True);
  TextRend.displayString(1, 17, White, Black, 'Armor Class');
  case GDVars.curChar^.acCur[0] of
    1..50: col := 16;
    51..60: col := 17;
    61..69: col := 16;
  else
    col := 15;
  end;
  Border.ClearBox(15, 17, 17, 17);
  CharHlp.PrintArmorClass(p, col, 17);
  TextRend.displayString(20, 17, White, Black, 'Encumbrance');
  s := CharHlp.Uint16Str(p^.encumbrance);
  RightAlignField(s, 5);
  TextRend.displayString(33, 17, LightGreen, Black, s);
  TextRend.displayString(1, 18, White, Black, 'THAC0   ');
  s := CharHlp.Uint8Str(60 - p^.thac0Adj);
  RightAlignField(s, 2);
  TextRend.displayString(16, 18, LightGreen, Black, s);
  mv := p^.movementCur;
  if CharHlp.HasEffect(p, C_Effect.HASTED, eff) then
    mv := mv * 2;
  if CharHlp.HasEffect(p, C_Effect.SLOWED, eff) then
    mv := mv div 2;
  TextRend.displayString(20, 18, White, Black, 'Movement');
  s := CharHlp.Uint8Str(mv);
  RightAlignField(s, 3);
  TextRend.displayString(35, 18, LightGreen, Black, s);
  s := CharHlp.Uint8Str(p^.curRolls[1]) + 'd' + CharHlp.Uint8Str(p^.curDice[1]);
  if p^.curMod[1] > 0 then
    s := s + '+' + CharHlp.Uint8Str(p^.curMod[1]);
  if p^.curMod[1] < 0 then
    s := s + '-' + CharHlp.Uint8Str(Abs(p^.curMod[1]));
  TextRend.displayString(1, 19, White, Black, 'Damage');
  RightAlignField(s, 7);
  TextRend.displayString(11, 19, LightGreen, Black, s);
end;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := LightMagenta
  else
    hlCol := LightGreen;
  col := 5;
  Border.ClearBox(col, statIdx + 9, 11, statIdx + 9);
  if GDVars.curChar^.stats[statIdx].cur < 10 then
    Inc(col);
  TextRend.displayString(col, statIdx + 9, hlCol, Black, CharHlp.Uint8Str(GDVars.curChar^.stats[statIdx].cur));
  if (statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.stats[C_Stat.STRENGTH].cur = 18) and
      (GDVars.curChar^.strExc > 0) then begin
    s := CharHlp.Uint8Str(GDVars.curChar^.strExc);
    if GDVars.curChar^.strExc < 10 then
      s := '0' + s;
    if GDVars.curChar^.strExc = 100 then
      s := '00';
    TextRend.displayString(7, 9, hlCol, Black, '(' + s + ')');
  end;
  if (GDVars.curChar^.stats[statIdx].cur <> GDVars.curChar^.stats[statIdx].base) or
      ((statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.strExcBase <> GDVars.curChar^.strExc)) then
    TextRend.displayString(12, statIdx + 9, hlCol, Black, '*');
end;

procedure ViewCharMenu(var done: Boolean);
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  s: Types.TStr40;
  hasMoney: Boolean;
  hasSpells: Boolean;
  ext: Boolean;
  i: Byte;
  j: ShortInt;
  idx: Integer;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  ch := ' ';
  done := False;
  GDVars.tempCr2 := GDVars.curChar;
  ViewChar.DisplayChar;
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    s := '';
    hasSpells := False;
    hasMoney := False;
    for i := 0 to 57 do
      if GDVars.tempCr1^.memorized[i] > 0 then
        hasSpells := True;
    for j := 1 to 6 do
      if GDVars.tempCr1^.coinsA[j] > 0 then
        hasMoney := True;
    if GDVars.tempCr1^.itemsAddr <> nil then
      s := s + 'Items ';
    if hasSpells then
      s := s + 'Spells ';
    if ((GDVars.tempCr1^.npc < C_Npc.NON_PLAYER) or (GDVars.tempCr1^.inPlay = 0) or
        (ShortInt(GDVars.tempCr1^.status) = C_Status.ANIMATED)) and hasMoney and
        (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
      s := s + 'Trade ';
    if hasMoney then
      s := s + 'Drop ';
    if ViewChar.CanHeal(GDVars.curChar) then
      s := s + 'Heal ';
    if ViewChar.CanCure(GDVars.curChar) then
      s := s + 'Cure ';
    s := s + 'Exit';
    ch := MenuCore.MenuHorizontal('', s, LightMagenta, LightGreen, White, False, False, ext);
    idx := -1;
    case ch of
      'I': ViewChar.UseItemMenu(done);
      'S': i := ViewChar.SpellMenu(0, 0, idx, hasSpells);
      'T': ViewChar.TradeTreasureMenu;
      'D': begin
             ViewChar.DropMoneyMenu;
             ViewChar.PrintMoney;
           end;
      'H': if not ext then
             ViewChar.PaladinLayOnHands(GDVars.curChar);
      'C': ViewChar.PaladinCureDisease(GDVars.curChar);
    end;
    if not done and (ch in ['I', 'S', 'T']) then
      ViewChar.DisplayChar;
  end;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    CbtMap.SetCombatPalette;
  CharHlp.DisplayNoncombatInterface;
end;

{ Tells whether an item may leave the current character's inventory: a readied item must be unreadied first, and a
  scroll with scribing pending (charges, effect or special above $7F) asks before that work is lost.
  @param(it The item.)
  @returns(True when the item may go.) }
function CheckItemAvail(it: Types.PItemRec): Boolean;
begin
  CheckItemAvail := False;
  if it^.equipped <> 0 then
    CharHlp.PrintBottomLine('Must be unreadied')
  else if not Magic.ItemReadable(it) then
    CheckItemAvail := True
  else if (it^.charges > $7F) or (it^.effect > $7F) or (it^.special > $7F) then begin
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 21, False);
    GDVars.curCol := Length(GDVars.curChar^.name) + 2;
    GDVars.curRow := 21;
    TextRend.displayMessageWindow(1, 21, 38, 22, Yellow, Black, False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White) = 'Y' then
      CheckItemAvail := True;
  end else
    CheckItemAvail := True;
  Border.ClearBox(1, 21, 38, 22);
end;

procedure ViewItemDetail(it: Types.PItemRec);
begin
  Border.DrawWindowFrame(True);
  with it^ do begin
    TextRend.displayString(1, 1, LightGreen, Black, 'itemptr:      ');
    TextRend.displayString(1, 2, LightGreen, Black, 'namenum(1):   ');
    TextRend.displayString(1, 3, LightGreen, Black, 'namenum(2):   ');
    TextRend.displayString(1, 4, LightGreen, Black, 'namenum(3):   ');
    TextRend.displayString(1, 5, LightGreen, Black, 'plus:         ');
    TextRend.displayString(1, 6, LightGreen, Black, 'plussave:     ');
    TextRend.displayString(1, 7, LightGreen, Black, 'ready:        ');
    TextRend.displayString(1, 8, LightGreen, Black, 'identified:   ');
    TextRend.displayString(1, 9, LightGreen, Black, 'cursed:       ');
    TextRend.displayString(1, 10, LightGreen, Black, 'value:        ');
    TextRend.displayString(1, 11, LightGreen, Black, 'special(1):   ');
    TextRend.displayString(1, 12, LightGreen, Black, 'special(2):   ');
    TextRend.displayString(1, 13, LightGreen, Black, 'special(3):   ');
    TextRend.displayString(1, 14, LightGreen, Black, 'missile type: ');
    TextRend.displayString(1, 15, LightGreen, Black, 'max range :   ');
    TextRend.displayString(1, 16, LightGreen, Black, 'item type :    ');
    TextRend.displayString(20, 1, LightGreen, Black, CharHlp.Uint8Str(itemType));
    TextRend.displayString(20, 2, LightGreen, Black, CharHlp.Uint8Str(nameIds[1]));
    TextRend.displayString(20, 3, LightGreen, Black, CharHlp.Uint8Str(nameIds[2]));
    TextRend.displayString(20, 4, LightGreen, Black, CharHlp.Uint8Str(nameIds[3]));
    TextRend.displayString(20, 5, LightGreen, Black, CharHlp.Uint8Str(Byte(plus)));
    TextRend.displayString(20, 6, LightGreen, Black, CharHlp.Uint8Str(Byte(saveBonus)));
    TextRend.displayString(20, 7, LightGreen, Black, CharHlp.Uint8Str(equipped));
    TextRend.displayString(20, 8, LightGreen, Black, CharHlp.Uint8Str(unidMask));
    TextRend.displayString(20, 9, LightGreen, Black, CharHlp.Uint8Str(cursed));
    TextRend.displayString(20, 10, LightGreen, Black, CharHlp.Uint16Str(value));
    TextRend.displayString(20, 11, LightGreen, Black, CharHlp.Uint8Str(charges));
    TextRend.displayString(20, 12, LightGreen, Black, CharHlp.Uint8Str(effect));
    TextRend.displayString(20, 13, LightGreen, Black, CharHlp.Uint8Str(special));
    TextRend.displayString(20, 14, LightGreen, Black, CharHlp.Uint8Str(GDVars.baseItems[itemType].props));
    TextRend.displayString(20, 15, LightGreen, Black, CharHlp.Uint8Str(GDVars.baseItems[itemType].range));
    TextRend.displayString(20, 16, LightGreen, Black, CharHlp.Uint8Str(GDVars.baseItems[itemType].slot));
  end;
  TextRend.displayAndPause(LightGreen, Black, 'press a key');
end;

procedure UseItemMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  idx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevItem: Types.PItemRec;
  cr: Types.PCharRecord;
  itemCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemSlot: Byte;
begin
  cr := GDVars.curChar;
  ch := ' ';
  sel := cr^.itemsAddr;
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  while not (ch in [C_Keys.NONE, 'E']) and not done and (cr^.itemCount > 0) do begin
    itemCount := cr^.itemCount;
    if cr^.itemsAddr <> nil then begin
      if GDVars.debugActive <> 0 then
        s := 'View Ready'
      else
        s := 'Ready';
      if (cr^.inPlay <> 0) and (GDVars.zone0^.vars[C_Gbvm.ANTI_MAGIC] = 0) and
          ((GDVars.interfaceState = C_Ifc.CAMPING) or (GDVars.interfaceState = C_Ifc.OVERLAND) or
           (GDVars.interfaceState = C_Ifc.VIEW_3D) or
           ((GDVars.interfaceState = C_Ifc.IN_COMBAT) and (cr^.combatAddr^.itemUseAllowed <> 0))) then
        s := s + ' Use';
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.inPlay = 0) or (ShortInt(cr^.status) = C_Status.ANIMATED)) and
          (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
        s := s + ' Trade';
      s := s + ' Drop';
      if cr^.itemCount < 16 then
        s := s + ' Halve';
      s := s + ' Join';
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.inPlay = 0) or (ShortInt(cr^.status) = C_Status.ANIMATED)) and
          (GDVars.interfaceState = C_Ifc.SHOP_TEMPLE) then
        s := s + ' Sell';
      if GDVars.interfaceState = C_Ifc.SHOP_TEMPLE then
        s := s + ' Id';
      p := cr^.itemsAddr;
      while p <> nil do begin
        CharHlp.PrintItemString(cr, p, 0, 0, True, False);
        p := p^.next;
      end;
      if needRedraw or (GDVars.redrawInvMenu <> 0) then begin
        Border.DrawTitleInset;
        CharHlp.DisplayCreatureName(cr, 1, 1, True);
        TextRend.displayString(Length(cr^.name) + 4, 1, LightGreen, Black, 'Items');
        TextRend.displayString(1, 3, White, Black, 'Ready Item');
        vmRedraw := True;
        needRedraw := False;
        GDVars.redrawInvMenu := 0;
      end;
      ch := MenuCore.MenuVertical('', s, LightMagenta, LightGreen, White, 1, 5, 38, 22, Types.PItemRec(cr^.itemsAddr),
                                  True, vmRedraw, idx, Types.PItemRec(sel));
      if sel <> nil then
        case ch of
          'V': begin
                 ViewChar.ViewItemDetail(sel);
                 vmRedraw := True;
                 needRedraw := True;
               end;
          'R': ViewChar.ToggleReadyItem(sel);
          'U': if sel^.equipped = 0 then
               begin
                 CharHlp.PrintBottomLine('Must be Readied');
                 ch := ' ';
               end else if Magic.ItemReadable(sel) or ((sel^.effect > 0) and (sel^.special < $80)) then begin
                 ViewChar.UseItem(sel, done);
                 if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
                   done := False;
                 if not done then
                   needRedraw := True;
               end;
          'T': begin
                 if ViewChar.CheckItemAvail(sel) then
                   ViewChar.ItemTradeMenu(sel)
                 else
                   ch := ' ';
                 needRedraw := True;
               end;
          'D': if ViewChar.CheckItemAvail(sel) then
               begin
                 CharHlp.PrintItemString(cr, sel, 0, 0, False, False);
                 TextRend.displayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                               'Your ' + sel^.name + 'will be gone forever');
                 if MenuCore.YesNoMenu('Drop It? ', LightMagenta, LightGreen, White) = 'Y' then
                 begin
                   CharHlp.RemoveItem(GDVars.curChar, sel);
                   vmRedraw := True;
                 end;
                 Border.ClearBox(1, 21, 38, 22);
               end else
                 ch := ' ';
          'H': ViewChar.HalveItem(sel);
          'J': ViewChar.JoinItem(sel);
          'S': if ViewChar.CheckItemAvail(sel) then
                 ViewChar.SellItem(sel)
               else
                 ch := ' ';
          'I': ViewChar.IdentifyItem(sel, vmRedraw);
        end;
      CharHlp.RecalcStats(cr);
    end;
    if cr^.itemCount <> itemCount then
      vmRedraw := True;
  end;
end;

{ Runs a special item's effect as it is readied or unreadied: its handler for kinds 0 and 2, a strength recalculation
  for 3 and 5, and effect 23 removed when kind 9 comes off.
  @param(it The item.)
  @param(equipping True when it is readied, False when it comes off.) }
procedure ToggleItemEffect(it: Types.PItemRec; equipping: Boolean);
var
  effId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  perClassLvl: Byte;
  { Unused in this version; see the other implementations of this routine. }
  damage: Byte;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  newLevel: Byte;
  { Unused in this version; see the other implementations of this routine. }
  j: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lvl: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellCnt: array[1..5] of Byte;
begin
  cr := GDVars.curChar;
  effId := it^.special and $7F;
  case effId of
    0, 2: begin
            GDVars.overrideFlag := 1;
            FxEngine.CallEffectHandler(it^.special, cr, it, equipping = False);
          end;
    1: ;
    3: FxEngine.RecalcAbility(cr, 0);
    5: FxEngine.RecalcAbility(cr, 0);
    8: ;
    9: if not equipping then
         FxEngine.RemoveEffect(cr, 23, nil);
  end;
end;

procedure ToggleReadyItem(it: Types.PItemRec);
var
  hasSpecial: Boolean;
  err: Byte;
  slot: ShortInt;
  cr: Types.PCharRecord;
begin
  hasSpecial := it^.special > $7F;
  cr := GDVars.curChar;
  if it^.equipped <> 0 then begin
    if it^.cursed <> 0 then
      CharHlp.PrintBottomLine('It''s Cursed')
    else begin
      it^.equipped := 0;
      if hasSpecial then
        ViewChar.ToggleItemEffect(it, False);
    end;
  end else begin
    err := 0;
    if cr^.handsEquipped + GDVars.baseItems[it^.itemType].hands > 2 then
      err := 3;
    slot := GDVars.baseItems[it^.itemType].slot;
    case Byte(slot) of
      0..8: if cr^.equipped[slot] <> nil then
              err := 2;
      9: if cr^.equipped[10] <> nil then
              err := 2;
    end;
    if it^.itemType = 39 then
      if not (((GDVars.curChar^.robeOrder = 1) and ((it^.unidMask and $20) <> 0)) or
              ((GDVars.curChar^.robeOrder = 2) and ((it^.unidMask and $10) <> 0))) then
        err := 4;
    if it^.itemType = C_Item.HOOPAK then
      if GDVars.curChar^.race <> C_Race.KENDER then
        err := 5;
    if it^.itemType = 30 then
      if cr^.equipped[11] <> nil then begin
        err := 2;
        slot := 11;
      end;
    if it^.itemType = 12 then
      if cr^.equipped[12] <> nil then begin
        err := 2;
        slot := 12;
      end;
    if GDVars.baseItems[it^.itemType].classMask and cr^.classMask = 0 then
      err := 1;
    case err of
      0: begin
           it^.equipped := 1;
           if hasSpecial then
             ViewChar.ToggleItemEffect(it, True);
         end;
      1: CharHlp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.PrintItemString(cr, cr^.equipped[slot], 0, 0, False, False);
           CharHlp.PrintBottomLine('already using ' + cr^.equipped[slot]^.name);
         end;
      3: if (GDVars.interfaceState <> C_Ifc.IN_COMBAT) or (cr^.quickfight = 0) then
           CharHlp.PrintBottomLine('Your hands are full!');
      4: CharHlp.PrintBottomLine('Wrong Magical Order');
      5: CharHlp.PrintBottomLine('Usable Only By Kender');
    end;
  end;
end;

{ Gives an item to another party member chosen by the player, unless that member cannot carry it.
  @param(it The item.) }
procedure ItemTradeMenu(it: Types.PItemRec);
var
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.tempCr2;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.SelectChar('Trade with Whom?', True, True, tgt);
  if tgt <> nil then begin
    GDVars.tempCr2 := tgt;
    if ViewChar.CannotCarryItem(tgt, it) then
      CharHlp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AddItemCopy(tgt, it);
      CharHlp.RemoveItem(GDVars.curChar, it);
      CharHlp.RecalcStats(tgt);
    end;
  end;
end;

{ Splits an item stack: a copy holding half the quantity, rounded down, and unreadied, follows the original, which keeps
  the rest. A quantity below 2 cannot be halved ("Can't halve that").
  @param(it The item.) }
procedure HalveItem(it: Types.PItemRec);
var
  newIt: Types.PItemRec;
  half: Byte;
  rest: Byte;
begin
  half := it^.quantity div 2;
  if half > 0 then begin
    rest := it^.quantity - half;
    GetMem(newIt, SizeOf(Types.TItemRec));
    Move(it^, newIt^, SizeOf(Types.TItemRec));
    newIt^.quantity := half;
    newIt^.equipped := 0;
    newIt^.next := it^.next;
    it^.quantity := rest;
    it^.next := newIt;
  end else
    CharHlp.PrintBottomLine('Can''t halve that');
end;

{ Merges into an item each other stack of the current character's that has a quantity and the same name, type, plus,
  save bonus, curse and weight and fewer than 2 charges. When the total would pass 255, the item is filled to 255 and
  the merging goes on into the stack that keeps the excess. Note: the charges, effect and special tests compare a stack
  with itself, so they always pass.
  @param(it The item to merge into.) }
procedure JoinItem(it: Types.PItemRec);
var
  cur: Types.PItemRec;
  next: Types.PItemRec;
  dst: Types.PItemRec;
  qty: Byte;
begin
  dst := it;
  qty := dst^.quantity;
  cur := GDVars.curChar^.itemsAddr;
  while cur <> nil do begin
    next := cur^.next;
    if (cur <> dst) and (cur^.quantity > 0) and (cur^.nameIds[1] = dst^.nameIds[1]) and
        (cur^.nameIds[2] = dst^.nameIds[2]) and (cur^.nameIds[3] = dst^.nameIds[3]) and
        (cur^.itemType = dst^.itemType) and (cur^.plus = dst^.plus) and (cur^.saveBonus = dst^.saveBonus) and
        (cur^.cursed = dst^.cursed) and (cur^.weight = dst^.weight) and (cur^.charges = cur^.charges) and
        (cur^.charges < 2) and (cur^.effect = cur^.effect) and (cur^.special = cur^.special) then begin
      if qty + cur^.quantity <= 255 then begin
        Inc(qty, cur^.quantity);
        CharHlp.RemoveItem(GDVars.curChar, cur);
      end else begin
        dst^.quantity := 255;
        cur^.quantity := cur^.quantity - (255 - qty);
        qty := cur^.quantity;
        dst := cur;
      end;
    end;
    cur := next;
  end;
  dst^.quantity := qty;
end;

procedure UseItem(it: Types.PItemRec; var done: Boolean);
var
  spell: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GDVars.usingItemFlag := 0;
  spell := 0;
  if Magic.ItemReadable(it) then begin
    GDVars.curScroll := it;
    spell := ViewChar.SpellMenu(2, 1, idx, notEmpty);
  end else if (it^.effect > 0) and (it^.special < $80) then begin
    GDVars.usingItemFlag := 1;
    spell := it^.effect and $7F;
  end;
  if spell = 0 then
    done := False
  else begin
    if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (GDVars.curChar^.quickfight = 0) then
      CharHlp.DisplayCombatInterface;
    if GDVars.usingItemFlag <> 0 then begin
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'uses an item', LightGreen, False);
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        TextRend.displayString(0, 23, LightGreen, Black, 'Item:');
        CharHlp.PrintItemString(GDVars.curChar, it, 5, 23, False, True);
      end else
        CharHlp.PrintItemString(GDVars.curChar, it, 1, 22, False, True);
      TextRend.pauseOnly;
      CharHlp.ClearMessageWindow;
    end;
    GDVars.usingItemFlag := 1;
    if Magic.ItemReadable(it) then begin
      if (ClassCal.FirstEarlierClass(GDVars.curChar) = C_Class.MAGE) or
          (ClassCal.FirstCurrentClass(GDVars.curChar) = C_Class.MAGE) or
          (ClassCal.FirstEarlierClass(GDVars.curChar) = C_Class.CLERIC) or
          (ClassCal.FirstCurrentClass(GDVars.curChar) = C_Class.CLERIC) or
          (GDVars.curChar^.classLevels[C_Class.MAGE] > 0) or
              (GDVars.curChar^.classLevels[C_Class.CLERIC] > 0) then
        Magic.CastSpell(spell, GDVars.curChar^.quickfight, 0, done)
      else if (GDVars.curChar^.classLevels[C_Class.THIEF] > 9) and (FxEngine.RollDice(1, 100) <= 75) then
        Magic.CastSpell(spell, GDVars.curChar^.quickfight, 0, done)
      else
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'oops!', GDVars.curRow + 1, True);
    end else
      Magic.CastSpell(spell, GDVars.curChar^.quickfight, 0, done);
    GDVars.usingItemFlag := 0;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      if GDConsts.spellTbl[spell].combatOk <> 0 then
        done := CharHlp.EndActions(GDVars.curChar);
  end;
  if done then begin
    if Magic.ItemReadable(it) then
      Magic.RemoveSpellFromScroll(GDVars.curChar, it, spell)
    else if it^.charges > 0 then begin
      if it^.quantity > 1 then
        Dec(it^.quantity)
      else begin
        Dec(it^.charges);
        if it^.charges = 0 then
          CharHlp.RemoveItem(GDVars.curChar, it);
      end;
    end;
  end;
end;

{ Offers half the item's value for it in a shop (for a stack, that times its quantity over 20) and, on a deal, removes
  the item and pays in steel, the overflow going into the pool. Note: the stack test uses or where and was meant, so
  arrows and quarrels are priced like any other stack.
  @param(it The item.) }
procedure SellItem(it: Types.PItemRec);
var
  price: Word;
  plat: Word;
  takable: Word;
begin
  price := 0;
  if it^.value > 0 then
    price := it^.value div 2;
  if it^.quantity > 1 then begin
    if (it^.itemType <> 30) or (it^.itemType <> 12) then
      price := price * it^.quantity div 20
    else
      price := price * it^.quantity;
  end;
  CharHlp.PrintItemString(GDVars.tempCr1, it, 0, 0, False, False);
  TextRend.displayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                'I''ll give you ' + CharHlp.Uint16Str(price) + ' steel pieces for your ' + it^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    CharHlp.PrintBottomLine('Sold!');
    CharHlp.RemoveItem(GDVars.curChar, it);
    plat := price;
    if Money.CheckOverload(Types.PCharRecord(GDVars.curChar), plat, takable) then begin
      CharHlp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      if takable > plat then
        Inc(GDVars.curChar^.coinsA[4], plat)
      else begin
        Inc(GDVars.curChar^.coinsA[4], takable);
        Inc(GDVars.treasureMoney[4], plat - takable);
      end;
    end else
      Inc(GDVars.curChar^.coinsA[4], plat);
  end;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Identifies an item in a shop for 100 steel, paid from the current character's coins or else the pool.
  @param(it The item.)
  @param(newInfo Set True when the item reveals something new.) }
procedure IdentifyItem(it: Types.PItemRec; var newInfo: Boolean);
var
  charGold: LongInt;
  poolGold: LongInt;
  paid: Boolean;
begin
  paid := False;
  CharHlp.PrintItemString(GDVars.tempCr1, it, 0, 0, False, False);
  TextRend.displayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                'For 100 steel pieces I''ll identify your ' + it^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    charGold := ViewChar.CreatureCoinValueInSteel(GDVars.curChar);
    if charGold >= 100 then begin
      paid := True;
      Dec(charGold, 100);
      Money.SetCreatureCoinsInSteel(charGold);
    end else begin
      poolGold := Money.CoinValueInSteel(GDVars.treasureMoney);
      if poolGold >= 100 then begin
        paid := True;
        Dec(poolGold, 100);
        Money.SetTreasureCoinsInSteel(poolGold);
      end else
        CharHlp.PrintBottomLine('Not Enough Money');
    end;
  end;
  if paid then begin
    if (it^.unidMask and $07) = 0 then
      TextRend.displayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                    'I can''t tell anything new about your ' + it^.name)
    else begin
      it^.unidMask := it^.unidMask and $F8;
      CharHlp.PrintItemString(GDVars.tempCr1, it, 0, 0, False, False);
      TextRend.displayMessageWindow(1, 21, 38, 22, Yellow, Black, True, 'It looks like some sort of ' + it^.name);
      newInfo := True;
    end;
  end;
  if paid then
    TextRend.pauseOnly;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Lets the current character give money of types 1..6 to party members it picks, until it has no money left or the
  player leaves. }
procedure TradeTreasureMenu;
var
  tgt: Types.PCharRecord;
  m: ShortInt;
  mType: ShortInt;
  k: Byte;
  gapLen: Byte;
  p: Types.PItemRec;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  count: Word;
  idx: Integer;
  numStr: String[15];
  line: String[15];
  promptStr: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
  exitOuter: Boolean;
  exitInner: Boolean;
  redraw: Boolean;
begin
  repeat
    tgt := GDVars.tempCr2;
    CharHlp.DisplayNoncombatInterface;
    CharHlp.SelectChar('Trade to?', True, True, tgt);
    if tgt = nil then
      exitOuter := True
    else begin
      ViewChar.DisplayChar;
      repeat
        ViewChar.PrintMoney;
        GDVars.tempCr2 := tgt;
        p := nil;
        prev := nil;
        list := nil;
        count := 0;
        for m := 6 downto 1 do
          if GDVars.curChar^.coinsA[m] <> 0 then begin
            Inc(count);
            if p = nil then begin
              GetMem(p, SizeOf(Types.TCharacterListNode));
              p^.next := nil;
            end else begin
              prev := p;
              GetMem(p, SizeOf(Types.TCharacterListNode));
              p^.next := prev;
            end;
            numStr := CharHlp.Uint16Str(GDVars.curChar^.coinsA[m]);
            gapLen := 14 - Length(GDConsts.moneyNames[m]);
            line := '';
            for k := 1 to gapLen do
              line := line + ' ';
            p^.name := GDConsts.moneyNames[m] + line + numStr;
            p^.inUse := 0;
          end;
        list := p;
        idx := 0;
        redraw := True;
        ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 20, 9, 38, 15,
                                    Types.PItemRec(p), True, redraw, idx, Types.PItemRec(prev));
        if prev = nil then
          exitInner := True
        else begin
          promptStr := '';
          mType := Money.ParseMoneyType(prev^.name, promptStr);
          promptStr := 'How much ' + promptStr + 'will you trade? ';
          amount := Money.InputNumberMax(GDVars.curChar^.coinsA[mType], promptStr, LightGreen);
          Money.TradeMoney(Types.PCharRecord(GDVars.curChar), Types.PCharRecord(tgt), amount, mType);
          exitInner := True;
          exitOuter := True;
          for m := 1 to 6 do
            if GDVars.curChar^.coinsA[m] > 0 then begin
              exitOuter := False;
              exitInner := False;
            end;
        end;
        if list <> nil then
          MenuCore.FreeStringList(Types.PItemRec(list));
      until exitInner;
    end;
  until exitOuter;
end;

{ Lets the current character drop money of types 1..6 until it has none left or the player leaves. }
procedure DropMoneyMenu;
var
  m: ShortInt;
  mType: ShortInt;
  gapLen: Byte;
  k: Byte;
  count: Word;
  idx: Integer;
  p: Types.PItemRec;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  exitFlag: Boolean;
  redraw: Boolean;
  numStr: String[15];
  line: String[15];
  promptStr: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: Word;
begin
  repeat
    ViewChar.PrintMoney;
    p := nil;
    prev := nil;
    list := nil;
    count := 0;
    for m := 6 downto 1 do
      if GDVars.curChar^.coinsA[m] <> 0 then begin
        Inc(count);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TCharacterListNode));
          p^.next := nil;
        end else begin
          prev := p;
          GetMem(p, SizeOf(Types.TCharacterListNode));
          p^.next := prev;
        end;
        numStr := CharHlp.Uint16Str(GDVars.curChar^.coinsA[m]);
        gapLen := 18 - Length(GDConsts.moneyNames[m]) - Length(numStr);
        line := '';
        for k := 1 to gapLen do
          line := line + ' ';
        p^.name := GDConsts.moneyNames[m] + line + numStr;
        p^.inUse := 0;
      end;
    list := p;
    idx := 0;
    redraw := True;
    ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 20, 9, 38, 15,
                                Types.PItemRec(p), True, redraw, idx, Types.PItemRec(prev));
    if prev = nil then
      exitFlag := True
    else begin
      promptStr := '';
      mType := Money.ParseMoneyType(prev^.name, promptStr);
      promptStr := 'How much ' + promptStr + 'will you drop? ';
      amount := Money.InputNumberMax(GDVars.curChar^.coinsA[mType], promptStr, LightGreen);
      Money.DropMoney(Types.PCharRecord(GDVars.curChar), amount, mType);
      exitFlag := True;
      for m := 1 to 6 do
        if GDVars.curChar^.coinsA[m] > 0 then
          exitFlag := False;
    end;
    if list <> nil then
      MenuCore.FreeStringList(Types.PItemRec(list));
  until exitFlag;
end;

function CannotCarryItem(cr: Types.PCharRecord; it: Types.PItemRec): Boolean;
var
  f: Boolean;
  w: Word;
begin
  CharHlp.RecalcStats(cr);
  f := False;
  if cr^.itemCount > 15 then
    f := True;
  w := it^.weight;
  if it^.quantity > 0 then
    w := w * it^.quantity;
  { The comparison is Word > Integer, so WeightAllowance's result is typecast to Integer. }
  if cr^.encumbrance + w > Integer(CharHlp.WeightAllowance(cr)) + 1500 then
    f := True;
  CannotCarryItem := f;
end;

procedure SelectPrevNextChar(c: Char);
var
  p: Types.PCharRecord;
begin
  if not GDVars.mouseOn or (GDVars.mouseButtonSeen = 0) then begin
    p := GDVars.partyHead;
    if p <> nil then
      case c of
        C_Keys.UP:
          if p = GDVars.curChar then begin
            while p^.next <> nil do
              p := p^.next;
          end else
            while (p <> nil) and (p^.next <> GDVars.curChar) do
              p := p^.next;
        C_Keys.DOWN:
          if GDVars.curChar^.next <> nil then
            p := GDVars.curChar^.next;
      else
        p := GDVars.partyHead;
      end;
    GDVars.curChar := p;
  end;
end;

function CreatureCoinValueInSteel(cr: Types.PCharRecord): LongInt;
var
  sum: LongInt;
  m: ShortInt;
begin
  sum := 0;
  for m := 0 to 4 do
    Inc(sum, GDConsts.coinValue[m] * cr^.coinsA[m]);
  CreatureCoinValueInSteel := sum div GDConsts.coinValue[4];
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  s: Types.TStr40;
begin
  case menuType of
    0: s := 'in Memory';
    1: s := 'in Grimoire';
    2: s := 'on Scroll';
    3: s := 'on Scrolls';
    4: s := 'to Choose';
    5: s := 'to Memorize';
    6: s := 'to Scribe';
  else
    s := '';
  end;
  notEmpty := Magic.GenerateSpellList(menuType);
  if notEmpty then begin
    if (idx < 0) or (selType = 1) then begin
      if selType = 2 then
        Border.DrawMemorizeFrame
      else
        Border.DrawTitleInset;
    end;
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, True);
    TextRend.displayString(Length(GDVars.curChar^.name) + 4, 1, LightGreen, Black, 'Spells ' + s);
    SpellMenu := Magic.SpellSelection(selType, idx);
  end else
    SpellMenu := 0;
end;

function CanHeal(cr: Types.PCharRecord): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
  CanHeal := False;
end;

function CanCure(cr: Types.PCharRecord): Boolean;
begin
  CanCure := False;
end;

procedure PaladinLayOnHands(cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  tgt: Pointer;
begin
end;

procedure PaladinCureDisease(cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  tgt: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
end;

function PickCharacter: Boolean;
var
  ch: Char;
  ext: Boolean;
  saved: Byte;
begin
  saved := GDVars.partyPickEnabled;
  GDVars.partyPickEnabled := 1;
  repeat
    ch := MenuCore.MenuHorizontal('Pick Character ', 'Select Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.DisplayParty(GDVars.curChar);
    end;
  until (not ext) and (ch in [C_Keys.NONE, 'E', 'S']);
  CharHlp.DisplayParty(GDVars.curChar);
  PickCharacter := ch = 'S';
  GDVars.partyPickEnabled := saved;
end;

begin
end.
