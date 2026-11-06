{ Class-derived-stat recalculation: THAC0, attacks, thief skills, spell slots and saving throws. }
{$O+,F+}
unit ClassCal;
interface

uses Types, MenuCore, Debug, GDConsts, GDVars, C_Class, C_Race;

{ Recomputes a character's level-derived values. The THAC0 base (thac0Base) becomes the best of its classes at their
  levels and levelHighest rises to its highest class level; a fighter or knight above level 6 or a ranger above level 7
  gets 3 half-attacks. A dwarf following deity 6, or anyone following deity 3, gains 1 on the THAC0 base. It then
  rebuilds the spell slots (RecalcSpellSlots), the saving throws (RecalcSaves) and, with thief levels, the thief skills
  (RecalcThiefSkills). The class mask (classMask) collects the item masks of the classes it has levels in, plus each
  earlier class whose level is below levelHighest; an equipped, uncursed item in an equipment slot that no class in the
  mask may use is unreadied. Once a dual-class character has passed its earlier class (EarlierClassActive), the earlier
  class levels also count for THAC0 and attacks, and earlier thief levels rebuild the thief skills.
  @param(cr The character to update.) }
procedure RecalcClassStats(cr: Types.PCharRecord);

{ Rebuilds a character's cleric slots when it has cleric levels: one first-level slot (two under the second cleric
  progression, chosen by a deity above 4) plus the progression for each level above 1, then the Wisdom bonus. Wisdom
  above 12 and above 13 each add a first-level slot, above 14 and above 15 each a second-level slot, above 16 a
  third-level slot and above 17 a fourth-level slot, each only to a spell level that already has slots.
  @param(cr The character to update.) }
procedure RecalcClericSlots(cr: Types.PCharRecord);

{ Recomputes a character's five saving throws (saves). Each starts at 20 and takes the lowest table value of its classes
  at their levels. Save 0 then adds 1 to 5, rising with Constitution from 4 to 18, for a dwarf, a kender or a character
  with an equipped item with special $86, and 1 to 4 for Constitution 19 to 25 for anyone. Note: the earlier-class check
  reuses classIndex after its loop has ended, so it looks only at class 7, and only when the current level of class 7 is
  above its earlier level.
  @param(cr The character to update.) }
procedure RecalcSaves(cr: Types.PCharRecord);

{ Recomputes a character's eight thief skills from the thief skill table at its thief level, counting its earlier thief
  levels once it has passed them. Each skill takes the race adjustment, falling to 0 when a race penalty exceeds it, and
  skills 1 to 5 also take the Dexterity adjustment. The first equipped item with a thief-skill special counts: one kind
  raises a level below 4 to 4, or else adds 10 to each skill; the other computes skill 1 at level 5 at least and skill 2
  at level 7 at least, adding 5 to a skill whose level is already that high, and the 5 or 0 chosen for skill 2 is added
  to skills 3 to 8 as well. Note: without the second kind of item the bonus added to each skill is never set, so it adds
  whatever the local held.
  @param(cr The character to update.) }
procedure RecalcThiefSkills(cr: Types.PCharRecord);

{ Empty routine with no callers. }
procedure NoopClassCal;

{ Finds the first class in which a human has an earlier (pre-change) level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstEarlierClass(cr: Types.PCharRecord): Byte;

{ Finds the first class in which a human has a current level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstCurrentClass(cr: Types.PCharRecord): Byte;

{ Finds a human's current level in its first class with a level.
  @param(cr The character to check.)
  @returns(That level; 0 for a non-human or a human with no level.) }
function CurrentDualClassLevel(cr: Types.PCharRecord): ShortInt;

{ Tells whether a human's current class level exceeds the level it had when it changed class, which lets its earlier
  class's abilities count again.
  @param(cr The character to check.)
  @returns(True when the earlier class counts again.) }
function EarlierClassActive(cr: Types.PCharRecord): Boolean;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeClassCal;

implementation

procedure NoopClassCal;
begin
end;

procedure PrimeClassCal;
begin
  Debug.PrimeDebug;
  MenuCore.PrimeMenuCore;
end;

{ Rebuilds a character's spell slots from its current class levels. A cleric gets one first-level slot plus the cleric
  progression for each level above 1 (the progression chosen by its deity), then RecalcClericSlots, and knows the cleric
  spells listed for each spell level 1 to 4 it has slots for. A knight above level 5 outside order 1 adds the cleric
  slots of its order's progression for levels 6 up and knows the same cleric spells. A ranger above level 7 adds its
  druid slots (spell levels 1 to 3) and magic-user slots (spell levels 1 and 2) for levels 8 up and knows each druid
  spell. A magic-user gets one first-level slot plus the progression of its robe order. Each equipped item with special
  $81 doubles the magic-user slots of spell levels 1 to 3.
  @param(cr The character to update.) }
procedure RecalcSpellSlots(cr: Types.PCharRecord);
var
  i: ShortInt;
  progressionIndex: ShortInt;
  currentLevel: ShortInt;
  k: ShortInt;
  secondarySlotIndex: ShortInt;
  j: ShortInt;
  spellId: Byte;
  item: Types.PItemRec;
begin
  with cr^ do begin
  FillChar(slots, SizeOf(slots), 0);
  for i := 0 to 7 do begin
    currentLevel := classLevels[i];
    if currentLevel > 0 then
      case i of
        C_Class.CLERIC: begin
             if deity <= 4 then progressionIndex := 0 else progressionIndex := 1;
             Inc(slots[0, 1]);
             for k := 2 to currentLevel do
               for j := 1 to 5 do
                 Inc(slots[0, j], GDConsts.classProgression[progressionIndex].spellSlots[k, j]);
             ClassCal.RecalcClericSlots(cr);
             for k := 1 to 4 do
               if slots[0, k] > 0 then begin
                 GDVars.scratchIndex := 1;
                 spellId := 255;
                 while (GDVars.scratchIndex <= 10) and (spellId <> 0) do begin
                   spellId := GDConsts.knownSpellTable[1, k, GDVars.scratchIndex];
                   if spellId <> 0 then spellsKnown[spellId] := 1;
                   Inc(GDVars.scratchIndex);
                 end;
               end;
           end;
        C_Class.KNIGHT: begin
             if currentLevel > 5 then
               if knightOrder <> 1 then begin
                 if knightOrder = 2 then progressionIndex := 4 else progressionIndex := 5;
                 for k := 6 to currentLevel do
                   for j := 1 to 5 do
                     Inc(slots[0, j], GDConsts.classProgression[progressionIndex].spellSlots[k, j]);
                 for k := 1 to 4 do
                   if slots[0, k] > 0 then begin
                     GDVars.scratchIndex := 1;
                     spellId := 255;
                     while (GDVars.scratchIndex <= 10) and (spellId <> 0) do begin
                       spellId := GDConsts.knownSpellTable[1, k, GDVars.scratchIndex];
                       if spellId <> 0 then spellsKnown[spellId] := 1;
                       Inc(GDVars.scratchIndex);
                     end;
                   end;
               end;
           end;
        C_Class.RANGER: begin
             if currentLevel > 7 then begin
               for k := 8 to currentLevel do begin
                 for j := 1 to 3 do
                   Inc(slots[1, j], GDConsts.classProgression[6].spellSlots[k, j]);
                 for j := 4 to 5 do begin
                   secondarySlotIndex := j - 3;
                   Inc(slots[3, secondarySlotIndex], GDConsts.classProgression[6].spellSlots[k, j]);
                 end;
               end;
               for spellId := 1 to 100 do
                 if GDConsts.spellTbl[spellId].castClass = 1 then
                   spellsKnown[spellId] := 1;
             end;
           end;
        C_Class.MAGE: begin
             if robeOrder = 1 then progressionIndex := 7 else progressionIndex := 8;
             Inc(slots[3, 1]);
             for k := 2 to currentLevel do
               for j := 1 to 5 do
                 Inc(slots[3, j], GDConsts.classProgression[progressionIndex].spellSlots[k, j]);
           end;
      end;
  end;
  item := itemsAddr;
  while item <> nil do begin
    if (item^.special = $81) and (item^.equipped <> 0) then
      for j := 1 to 3 do
        Inc(cr^.slots[3, j], cr^.slots[3, j]);
    item := item^.next;
  end;
  end;
end;

procedure RecalcClassStats(cr: Types.PCharRecord);
var
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  levelIndex: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: ShortInt;
  classLevel: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  spellIndex: ShortInt;
  k: ShortInt;
begin
  cr^.thac0Base := 0;
  for i := 0 to 7 do begin
    classLevel := cr^.classLevels[i];
    if GDConsts.thac0Table[i, classLevel] > cr^.thac0Base then
      cr^.thac0Base := GDConsts.thac0Table[i, classLevel];
    if cr^.levelHighest < classLevel then
      cr^.levelHighest := classLevel;
    case i of
      C_Class.FIGHTER: if classLevel > 6 then cr^.attacks := 3;
      C_Class.RANGER: if classLevel > 7 then cr^.attacks := 3;
      C_Class.KNIGHT: if classLevel > 6 then cr^.attacks := 3;
    end;
  end;
  if ((cr^.deity = 6) and ((cr^.race = C_Race.MOUNTAIN_DWARF) or (cr^.race = C_Race.HILL_DWARF))) or
      (cr^.deity = 3) then
    Inc(cr^.thac0Base);
  ClassCal.RecalcSpellSlots(cr);
  ClassCal.RecalcSaves(cr);
  if cr^.classLevels[C_Class.THIEF] > 0 then
    ClassCal.RecalcThiefSkills(cr);
  { accumulate the character's class bitmask (the mask bits are disjoint), then unequip anything no class of theirs may
    use }
  cr^.classMask := 0;
  for i := 0 to 7 do
    if (cr^.classLevels[i] > 0) or
        ((cr^.classLevels2[i] > 0) and (cr^.classLevels2[i] < cr^.levelHighest)) then
      Inc(cr^.classMask, GDConsts.classMaskTable[i]);
  for k := 0 to 12 do
    if cr^.equipped[k] <> nil then
      if GDVars.baseItems[cr^.equipped[k]^.itemType].classMask and cr^.classMask = 0 then
        if cr^.equipped[k]^.cursed = 0 then
          cr^.equipped[k]^.equipped := 0;
  if ClassCal.EarlierClassActive(cr) then begin
    for i := 0 to 7 do begin
      classLevel := cr^.classLevels2[i];
      case i of
        C_Class.FIGHTER, C_Class.KNIGHT: if classLevel > 6 then cr^.attacks := 3;
        C_Class.RANGER: if classLevel > 7 then cr^.attacks := 3;
      end;
      if GDConsts.thac0Table[i, classLevel] > cr^.thac0Base then
        cr^.thac0Base := GDConsts.thac0Table[i, classLevel];
    end;
    if (cr^.classLevels2[C_Class.FIGHTER] > 6) or (cr^.classLevels2[C_Class.RANGER] > 7) or
        (cr^.classLevels2[C_Class.KNIGHT] > 6) then
      cr^.attacks := 3;
    if cr^.classLevels2[C_Class.THIEF] > 0 then
      ClassCal.RecalcThiefSkills(cr);
  end;
end;

procedure RecalcClericSlots(cr: Types.PCharRecord);
var
  k: ShortInt;
  spellLevel: ShortInt;
  currentLevel: ShortInt;
  progressionIndex: ShortInt;
begin
  currentLevel := cr^.classLevels[C_Class.CLERIC];
  if currentLevel > 0 then with cr^ do begin
    if deity <= 4 then progressionIndex := 0 else progressionIndex := 1;
    for spellLevel := 2 to 5 do slots[0, spellLevel] := 0;
    if progressionIndex = 0 then slots[0, 1] := 1 else slots[0, 1] := 2;
    for k := 2 to currentLevel do
      for spellLevel := 1 to 5 do
        Inc(slots[0, spellLevel], GDConsts.classProgression[progressionIndex].spellSlots[k, spellLevel]);
    if (stats[2].cur > 12) and (slots[0, 1] > 0) then Inc(slots[0, 1]);
    if (stats[2].cur > 13) and (slots[0, 1] > 0) then Inc(slots[0, 1]);
    if (stats[2].cur > 14) and (slots[0, 2] > 0) then Inc(slots[0, 2]);
    if (stats[2].cur > 15) and (slots[0, 2] > 0) then Inc(slots[0, 2]);
    if (stats[2].cur > 16) and (slots[0, 3] > 0) then Inc(slots[0, 3]);
    if (stats[2].cur > 17) and (slots[0, 4] > 0) then Inc(slots[0, 4]);
  end;
end;

procedure RecalcSaves(cr: Types.PCharRecord);
var
  i: ShortInt;
  classIndex: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  level: ShortInt;
  effectCode: ShortInt;
  item: Types.PItemRec;
  hasSaveBonusItem: Boolean;
begin
  hasSaveBonusItem := False;
  item := cr^.itemsAddr;
  while (item <> nil) and not hasSaveBonusItem do begin
    if (item^.special > $80) and (item^.equipped <> 0) then begin
      effectCode := item^.special and $7F;
      hasSaveBonusItem := effectCode = 6;
    end;
    item := item^.next;
  end;
  for i := 0 to 4 do begin
    cr^.saves[i] := 20;
    for classIndex := 0 to 7 do
      if cr^.classLevels[classIndex] > 0 then
        if cr^.saves[i] > GDConsts.savingThrowTable[classIndex, cr^.classLevels[classIndex], i] then
          cr^.saves[i] := GDConsts.savingThrowTable[classIndex, cr^.classLevels[classIndex], i];
    { Note: classIndex still holds the loop's terminal value here. }
    if cr^.classLevels[classIndex] > cr^.classLevels2[classIndex] then
      if cr^.saves[i] > GDConsts.savingThrowTable[classIndex, cr^.classLevels2[classIndex], i] then
        cr^.saves[i] := GDConsts.savingThrowTable[classIndex, cr^.classLevels2[classIndex], i];
    if i = 0 then
      if (cr^.race = C_Race.MOUNTAIN_DWARF) or (cr^.race = C_Race.KENDER) or
          (cr^.race = C_Race.HILL_DWARF) or hasSaveBonusItem then
        case cr^.stats[4].cur of
          4..6: Inc(cr^.saves[i]);
          7..10: Inc(cr^.saves[i], 2);
          11..13: Inc(cr^.saves[i], 3);
          14..17: Inc(cr^.saves[i], 4);
          18: Inc(cr^.saves[i], 5);
        end;
    if i = 0 then
      case cr^.stats[4].cur of
        19, 20: Inc(cr^.saves[i]);
        21, 22: Inc(cr^.saves[i], 2);
        23, 24: Inc(cr^.saves[i], 3);
        25: Inc(cr^.saves[i], 4);
      end;
  end;
end;

procedure RecalcThiefSkills(cr: Types.PCharRecord);
var
  i: Byte;
  skillBonus: Byte;
  effectCode: Byte;
  base: ShortInt;
  baseSkillLevel: Byte;
  item: Types.PItemRec;
  a: Boolean;
  b: Boolean;
begin
  with cr^ do begin
  a := False;
  b := False;
  item := itemsAddr;
  while (item <> nil) and not a and not b do begin
    if (item^.special > $80) and (item^.equipped <> 0) then begin
      effectCode := item^.special and $7F;
      a := effectCode = 11;
      b := effectCode = 2;
    end;
    item := item^.next;
  end;
  base := Ord(ClassCal.EarlierClassActive(cr)) * cr^.classLevels2[C_Class.THIEF] +
      cr^.classLevels[C_Class.THIEF];
  if (base < 4) and b then begin
    base := 4;
    b := False;
  end;
  baseSkillLevel := base;
  for i := 1 to 8 do begin
    if a then
      case i of
        1: if base < 5 then begin base := 5; skillBonus := 0; end else skillBonus := 5;
        2: if base < 7 then begin base := 7; skillBonus := 0; end else skillBonus := 5;
      end;
    if (GDConsts.raceSkillAdjust[race, i] < 0) and
        (GDConsts.thiefSkillTable[base, i] < Abs(GDConsts.raceSkillAdjust[race, i]) + skillBonus) then
      thiefSkills[i] := 0
    else begin
      thiefSkills[i] := GDConsts.thiefSkillTable[base, i] + GDConsts.raceSkillAdjust[race, i] + skillBonus;
      if i < 6 then
        thiefSkills[i] := thiefSkills[i] + GDConsts.dexteritySkillAdjust[stats[3].cur, i];
    end;
    if b then
      Inc(thiefSkills[i], 10);
    base := baseSkillLevel;
  end;
  end;
end;

function FirstEarlierClass(cr: Types.PCharRecord): Byte;
var i: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then FirstEarlierClass := 17
  else begin
    i := 0;
    while (i < 7) and (cr^.classLevels2[i] = 0) do Inc(i);
    if cr^.classLevels2[i] > 0 then FirstEarlierClass := i
    else FirstEarlierClass := 17;
  end;
end;

function FirstCurrentClass(cr: Types.PCharRecord): Byte;
var i: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then FirstCurrentClass := 17
  else begin
    i := 0;
    while (i < 7) and (cr^.classLevels[i] = 0) do Inc(i);
    if cr^.classLevels[i] > 0 then FirstCurrentClass := i
    else FirstCurrentClass := 17;
  end;
end;

function CurrentDualClassLevel(cr: Types.PCharRecord): ShortInt;
var i: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then CurrentDualClassLevel := 0
  else begin
    i := 0;
    while (i < 7) and (cr^.classLevels[i] = 0) do Inc(i);
    CurrentDualClassLevel := cr^.classLevels[i];
  end;
end;

function EarlierClassActive(cr: Types.PCharRecord): Boolean;
begin
  EarlierClassActive := ClassCal.CurrentDualClassLevel(cr) > cr^.dualClassThreshold;
end;

begin
end.
