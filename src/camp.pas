{ Encamp menus, noncombat spell preparation, party ordering, rest and the rule-book copy-protection challenge. }
{$O+,F+}
unit Camp;

interface

{ Runs the Camp menu (Save, which then offers to quit to DOS, View, Magic, Rest, Fix and Alter; extended keys change the
  current character) until Exit, Escape or an interrupted rest. Every tenth save first runs the rule-book check, and
  failing it quits the game. On entry, switches to the camping interface state, copies the portrait archive name and
  picture ID, clears the healing ticks, the rest clock and every pending memorize or scribe request, and announces 'The
  party makes camp...'. On exit, clears the pending requests and the cast target again, restores the interface state,
  and reloads the portrait animation from the copied archive name when it starts with PIC.
  @param(interrupted Set True when a rest is interrupted.) }
procedure CampMainMenu(var interrupted: Boolean);

{ Runs the noncombat Cast menu for the current character until no spell is picked, saying 'has no spells memorized' when
  the list is empty. Clears the remembered cast target on entry, and redraws the noncombat interface afterwards if a
  spell was cast or the spell list was not empty. }
procedure NoncombatCastMenu;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCamp;

implementation

uses Types, Border, TextRend, GameIo, SaveLoad, CharGen, ViewChar, GameTime, Magic, FxEngine, CharHlp, MenuCore,
  MapView, Portrait, Debug, Crt, GDConsts, GDVars, C_Keys, C_Class, C_Gbvm, C_Status, C_Ifc, C_Effect;

const
  SPELL_PENDING_FLAG = $80;
  SPELL_ID_MASK = $7F;

procedure PrimeCamp;
begin
  Debug.PrimeDebug;
  Magic.PrimeMagic;
  GameTime.PrimeGameTime;
  CharHlp.PrimeCharHlp;
  SaveLoad.PrimeSaveLoad;
  MenuCore.PrimeMenuCore;
  ViewChar.PrimeViewChar;
  MapView.PrimeMapView;
  FxEngine.PrimeFxEngine;
end;

{ Works out a character's spell preparation time: 15 minutes per level of each pending spell (a level-0 spell being
  memorized counts as 1), plus four hours when any spell is pending, or six when any pending spell is level 3 or higher.
  Pending memorizing and pending scribing (readable items only) both count. Stores the base hours (0, 4 or 6) in
  spellPrep.
  @param(character The character.)
  @returns(The preparation time in minutes.) }
function CampSpellPrepTime(character: Types.PCharRecord): Word;
var
  maxMemorizedLevel: Byte;
  maxScribedLevel: Byte;
  memorizedLevelTotal: Byte;
  scribedLevelTotal: Byte;
  scroll: Types.PItemRec;
  slotIndex: Byte;
  spellLevel: Byte;
  baseHours: Byte;
begin
  maxMemorizedLevel := 0;
  maxScribedLevel := 0;
  memorizedLevelTotal := 0;
  scribedLevelTotal := 0;
  for slotIndex := 0 to 57 do
    if character^.memorized[slotIndex] > Camp.SPELL_ID_MASK then begin
      spellLevel := GDConsts.spellTbl[character^.memorized[slotIndex] and Camp.SPELL_ID_MASK].level;
      if spellLevel = 0 then spellLevel := 1;
      if spellLevel > maxMemorizedLevel then maxMemorizedLevel := spellLevel;
      Inc(memorizedLevelTotal, spellLevel);
    end;
  scroll := character^.itemsAddr;
  while scroll <> nil do begin
    if Magic.ItemReadable(scroll) then
      for slotIndex := 1 to 3 do
        if scroll^.spells[slotIndex] > Camp.SPELL_ID_MASK then begin
          spellLevel := GDConsts.spellTbl[scroll^.spells[slotIndex] and Camp.SPELL_ID_MASK].level;
          if spellLevel > maxScribedLevel then maxScribedLevel := spellLevel;
          Inc(scribedLevelTotal, spellLevel);
        end;
    scroll := scroll^.next;
  end;
  baseHours := 0;
  if (memorizedLevelTotal > 0) or (scribedLevelTotal > 0) then
    baseHours := 4;
  if (maxMemorizedLevel > 2) or (maxScribedLevel > 2) then
    baseHours := 6;
  character^.spellPrep := baseHours;
  CampSpellPrepTime := baseHours * 60 + memorizedLevelTotal * 15 + scribedLevelTotal * 15;
end;

{ Runs the rule-book check: asks for word N after a heading on page P of the rule book, giving three tries to type it.
  The heading and the answer are decoded from GDConsts' letter tables. Note: the question number is Random(25) + 1, so
  the journal questions are never asked.
  @returns(1 when the last answer typed was right, else 0.) }
function RuleBookCheck: Byte;

  { Decodes a stored heading or answer word; each letter is a signed delta from $46 plus the word length. }
  function DecodeAnswer(tableIndex: Word; useHeading: Boolean): String;
  var
    count: Byte;
    letterIndex: Byte;
    firstLetter: Byte;
    decodedLetter: Byte;
    answer: String;
  begin
    answer := '';
    if useHeading then begin
      count := GDConsts.headEntries[tableIndex].letters;
      firstLetter := GDConsts.headEntries[tableIndex].firstLetter;
      for letterIndex := 1 to count do begin
        decodedLetter := GDConsts.headLetterTable[firstLetter + letterIndex] + 70 + count;
        answer := answer + Chr(decodedLetter);
      end;
    end else begin
      count := GDConsts.wordEntries[tableIndex].letters;
      firstLetter := GDConsts.wordEntries[tableIndex].firstLetter;
      for letterIndex := 1 to count do begin
        decodedLetter := GDConsts.wordLetterTable[firstLetter + letterIndex] + 70 + count;
        answer := answer + Chr(decodedLetter);
      end;
    end;
    DecodeAnswer := answer;
  end;

var
  { Unused in this version; see the other implementations of this routine. }
  charIndex: Byte;
  wordIndex: Byte;
  attempts: Byte;
  { Unused in this version; see the other implementations of this routine. }
  passed: Byte;
  correctAnswer: String;
  headingText: String;
  wordNumber: Byte;
  headingIndex: Byte;
  pageNumber: Byte;
  reply: String;
begin
  Border.DrawWindowFrame(True);
  attempts := 0;
  wordIndex := Random(25) + 1;
  repeat
    Inc(attempts);
    correctAnswer := '';
    TextRend.displayString(3, 2, LightGreen, Black, ' what is word # ');
    wordNumber := GDConsts.wordEntries[wordIndex].wordNo;
    pageNumber := GDConsts.wordEntries[wordIndex].pageNo;
    headingIndex := GDConsts.wordEntries[wordIndex].headIdx;
    headingText := DecodeAnswer(headingIndex, True);
    correctAnswer := DecodeAnswer(wordIndex, False);
    TextRend.displayString(19, 2, LightGreen, Black, CharHlp.Uint8Str(wordNumber) + '    ');
    TextRend.displayString(3, 4, LightGreen, Black, ' after the heading ');
    TextRend.displayString(3, 6, LightGreen, Black, '                                  ');
    TextRend.displayString(3, 6, LightGreen, Black, '"' + headingText + '"');
    if wordIndex <= 25 then
      TextRend.displayString(3, 8, LightGreen, Black,
                             ' (rule book, page ' + CharHlp.Uint8Str(pageNumber) + ')?' + '     ')
    else
      TextRend.displayString(3, 8, LightGreen, Black,
                             ' (journal, page ' + CharHlp.Uint8Str(pageNumber) + ')?' + '     ');
    reply := TextRend.readString('Enter ', Yellow, Black, 20);
  until (attempts = 3) or (reply = correctAnswer);
  if reply = correctAnswer then
    RuleBookCheck := 1
  else
    RuleBookCheck := 0;
end;

{ Removes every pending memorize request of a character, zeroing the slot, and clears its preparation hours.
  @param(character The character.) }
procedure ResetMemorize(character: Types.PCharRecord);
var
  spellIndex: Byte;
begin
  for spellIndex := 0 to 57 do
    if character^.memorized[spellIndex] > Camp.SPELL_ID_MASK then
      character^.memorized[spellIndex] := 0;
  character^.spellPrep := 0;
end;

{ Clears the pending flag of every scroll spell on a character's readable items.
  @param(character The character.) }
procedure ResetScribe(character: Types.PCharRecord);
var
  scrollSlot: Byte;
  scroll: Types.PItemRec;
begin
  scroll := character^.itemsAddr;
  while scroll <> nil do begin
    if Magic.ItemReadable(scroll) then
      for scrollSlot := 1 to 3 do
        scroll^.spells[scrollSlot] := scroll^.spells[scrollSlot] and Camp.SPELL_ID_MASK;
    scroll := scroll^.next;
  end;
end;

{ Clears the pending memorizing and scribing of each party member. }
procedure ResetPartySpellActivities;
var
  character: Types.PCharRecord;
begin
  character := GDVars.partyHead;
  while character <> nil do begin
    Camp.ResetMemorize(character);
    Camp.ResetScribe(character);
    character := character^.next;
  end;
end;

{ Counts the spells the current character can still memorize of a class and level. For the cleric, druid and magic-user
  lists it is the allowance less the memorized and pending spells of that class and level, never below 0. The special
  list (class 2) has an allowance from the cleric's deity (3 for deity 4, none for deity 6, 1 otherwise), less one for
  each memorized spell 101..107. Note: without cleric levels the special allowance is never set.
  @param(spellLevel The spell level; unused for the special list.)
  @param(spellClass The spell class: 0 cleric, 1 druid, 2 special, 3 magic-user.)
  @param(usedSlots Receives the memorized and pending count; left as it was for the special list.)
  @returns(The spells left to memorize.) }
function SpellSlotsRemaining(spellLevel, spellClass: ShortInt; var usedSlots: Byte): Byte;
var
  remainingSlots: Byte;
  spellIndex: Byte;
begin
  if spellClass = 2 then begin
    if GDVars.curChar^.classLevels[C_Class.CLERIC] > 0 then
      case GDVars.curChar^.deity of
        4: remainingSlots := 3;
        6: remainingSlots := 0;
      else
        remainingSlots := 1;
      end;
    for spellIndex := 0 to 57 do
      if (GDVars.curChar^.memorized[spellIndex] and Camp.SPELL_ID_MASK > 100) and
          (GDVars.curChar^.memorized[spellIndex] and Camp.SPELL_ID_MASK < 108) then
        Dec(remainingSlots);
    SpellSlotsRemaining := remainingSlots;
  end else begin
    remainingSlots := 0;
    for spellIndex := 0 to 57 do
      if GDVars.curChar^.memorized[spellIndex] > 0 then
        if GDConsts.spellTbl[GDVars.curChar^.memorized[spellIndex] and Camp.SPELL_ID_MASK].level = spellLevel then
          if GDConsts.spellTbl[GDVars.curChar^.memorized[spellIndex] and Camp.SPELL_ID_MASK].castClass =
              spellClass then
            Inc(remainingSlots);
    usedSlots := remainingSlots;
    if GDVars.curChar^.slots[spellClass, spellLevel] < remainingSlots then
      remainingSlots := GDVars.curChar^.slots[spellClass, spellLevel];
    SpellSlotsRemaining := GDVars.curChar^.slots[spellClass, spellLevel] - remainingSlots;
  end;
end;

{ Checks whether the current character can cast, memorize or scribe. The area's anti-magic flag blocks casting; animated
  or disabled characters can do none of them. On failure, prints the character's name and the reason.
  @param(activity The activity: cast, memorize or scribe.)
  @returns(True when the character can do it.) }
function CanDoSpellActivity(activity: Byte): Boolean;
var
  message: Types.TStr40;
begin
  message := '';
  if (activity = 1) and (GDVars.zone0^.vars[C_Gbvm.ANTI_MAGIC] > 0) then
    message := 'cannot cast spells in this area'
  else if (GDVars.curChar^.status = C_Status.ANIMATED) or (GDVars.curChar^.inPlay = 0) then begin
    message := 'is in no condition to ';
    case activity of
      1: message := message + 'cast any spells';
      2: message := message + 'memorize spells';
      3: message := message + 'scribe any scrolls';
    end;
  end;
  if message = '' then
    CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharHlp.PrintCreatureMessage(GDVars.curChar, message, 10, True);
  end;
end;

procedure NoncombatCastMenu;
var
  menuIndex: Integer;
  notEmpty: Boolean;
  needsRedraw: Boolean;
  castSelected: Boolean;
  spellId: Byte;
begin
  needsRedraw := False;
  menuIndex := -1;
  GDVars.lastTarget := nil;
  GDVars.horizontalChoice := 1;
  if Camp.CanDoSpellActivity(1) then
    repeat
      spellId := ViewChar.SpellMenu(0, 1, menuIndex, notEmpty);
      if spellId <> 0 then begin
        needsRedraw := True;
        Border.ClearBox(1, 17, 38, 22);
        Magic.CastSpell(spellId, 0, 1, castSelected);
      end else begin
        if notEmpty then
          needsRedraw := True
        else
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no spells memorized', 10, True);
      end;
    until spellId = 0;
  if needsRedraw then
    CharHlp.DisplayNoncombatInterface;
end;

{ Shows the current character's remaining spell slots for each list (cleric, druid, special, magic-user) and level 1..5.
  A level with no allowance is blank; a full level shows zero. The special list shows for a cleric not following deity
  6. A magic-user of a robe order also gets the bonus spells the zone grants that order (1 or 2), less any already
  spent beyond its slots, shown on a Bonus Spells line and kept in bonusSpells.
  @returns(True when the character has any spell allowance, even if every slot is taken.) }
function DisplaySpellSlots: Boolean;
var
  labelText: Types.TStr40;
  slotText: array[1..5, 0..3] of Types.TStr2;
  canUseClass: array[0..3] of Byte;
  spellClass: ShortInt;
  spellLevel: ShortInt;
  col: Byte;
  row: Byte;
  specialSlotsAvailable: Byte;
  anySlots: Boolean;
  baseSlotCount: Byte;
  usedSlotCount: Byte;
  slotsAvailable: Byte;
begin
  GDVars.bonusSpells := 0;
  anySlots := False;
  for spellClass := 0 to 3 do begin
    canUseClass[spellClass] := 0;
    if spellClass = 2 then begin
      if (GDVars.curChar^.classLevels[C_Class.CLERIC] > 0) and (GDVars.curChar^.deity <> 6) then begin
        canUseClass[2] := 1;
        anySlots := True;
      end;
      for spellLevel := 2 to 5 do
        slotText[spellLevel, 2] := ' ';
      specialSlotsAvailable := Camp.SpellSlotsRemaining(0, 2, slotsAvailable);
      if (specialSlotsAvailable > 0) or (anySlots <> False) then
        slotText[1, 2] := CharHlp.Uint8Str(specialSlotsAvailable)
      else
        slotText[1, 2] := ' ';
    end else
      for spellLevel := 1 to 5 do begin
        slotText[spellLevel,
                 spellClass] := CharHlp.Uint8Str(Camp.SpellSlotsRemaining(spellLevel, spellClass, slotsAvailable));
        if GDVars.curChar^.slots[spellClass, spellLevel] = 0 then
          slotText[spellLevel, spellClass] := ' '
        else begin
          canUseClass[spellClass] := 1;
          anySlots := True;
        end;
      end;
  end;
  if (GDVars.curChar^.classLevels[C_Class.MAGE] > 0) and (GDVars.curChar^.robeOrder > 0) then begin
    case GDVars.zone0^.vars[GDVars.curChar^.robeOrder + $4CF8] of
      1: GDVars.bonusSpells := 1;
      2: GDVars.bonusSpells := 2;
    else
      GDVars.bonusSpells := 0;
    end;
    if GDVars.bonusSpells > 0 then
      for spellLevel := 1 to 5 do begin
        baseSlotCount := GDVars.curChar^.slots[3, spellLevel];
        slotsAvailable := Camp.SpellSlotsRemaining(spellLevel, 3, usedSlotCount);
        if baseSlotCount < usedSlotCount then begin
          if usedSlotCount - baseSlotCount > GDVars.bonusSpells then
            GDVars.bonusSpells := 0
          else
            Dec(GDVars.bonusSpells, usedSlotCount - baseSlotCount);
        end;
      end;
    if GDVars.bonusSpells > 0 then
      anySlots := True;
  end;
  if anySlots then begin
    CharHlp.PrintCreatureMessage(GDVars.curChar, '', 10, False);
    row := 1;
    for spellClass := 0 to 3 do
      if canUseClass[spellClass] <> 0 then begin
        case spellClass of
          0: labelText := '    Cleric Spells:';
          1: labelText := '     Druid Spells:';
          2: labelText := '   Special Spells:';
          3: labelText := 'Magic-User Spells:';
        end;
        TextRend.displayString(1, row + 17, LightGreen, Black, labelText);
        col := 19;
        for spellLevel := 1 to 5 do begin
          TextRend.displayString(col + 1, row + 17, LightGreen, Black, slotText[spellLevel, spellClass]);
          Inc(col, 3);
        end;
        Inc(row);
      end;
    if GDVars.bonusSpells > 0 then begin
      TextRend.displayString(1, row + 17, LightGreen, Black, '     Bonus Spells');
      TextRend.displayString(20, row + 17, LightGreen, Black, CharHlp.Uint8Str(GDVars.bonusSpells));
    end;
  end;
  DisplaySpellSlots := anySlots;
end;

{ Rests the party for the longest spell preparation time among its members, then clears the rest time and redraws the
  position and time.
  @param(interrupted Receives True when the rest was interrupted.) }
procedure RestForSpellPrep(var interrupted: Boolean);
var
  character: Types.PCharRecord;
  maxPrepMinutes: Word;
  prepMinutes: Word;
  { Unused in this version; see the other implementations of this routine. }
  hours: Word;
begin
  maxPrepMinutes := 0;
  character := GDVars.partyHead;
  while character <> nil do begin
    prepMinutes := Camp.CampSpellPrepTime(character);
    if maxPrepMinutes < prepMinutes then maxPrepMinutes := prepMinutes;
    character := character^.next;
  end;
  GDVars.restTime[3] := maxPrepMinutes div 60;
  GDVars.restTime[2] := (maxPrepMinutes - 60 * GDVars.restTime[3]) div 10;
  GDVars.restTime[1] := maxPrepMinutes mod 10;
  interrupted := GameTime.CampRest(True);
  FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
  CharHlp.PrintPositionAndTime;
end;

{ Sorts the current character's memorized-spell slots by spell ID, keeping each pending flag with its spell. Empty slots
  sort to the front. }
procedure SortMemorizedSpells;
var
  leftIndex: Byte;
  rightIndex: Byte;
  tempSpell: Byte;
begin
  for leftIndex := 0 to 56 do
    for rightIndex := leftIndex to 57 do
      if (GDVars.curChar^.memorized[leftIndex] and Camp.SPELL_ID_MASK) >
          (GDVars.curChar^.memorized[rightIndex] and Camp.SPELL_ID_MASK) then begin
        tempSpell := GDVars.curChar^.memorized[leftIndex];
        GDVars.curChar^.memorized[leftIndex] := GDVars.curChar^.memorized[rightIndex];
        GDVars.curChar^.memorized[rightIndex] := tempSpell;
      end;
end;

{ Shows the pending memorize list first: Yes keeps it and skips selection, No clears it. Then lets the player pick
  spells from the spellbook, marking each as pending while slots of its class and level remain (or, for a magic-user
  spell, bonus spells), and confirms the pending list again if the spellbook menu was used. }
procedure CampMemorizeMenu;
var
  finished: Boolean;
  hasOptions: Boolean;
  needsRedraw: Boolean;
  spellId: Byte;
  emptySlot: Byte;
  menuIndex: Integer;
  usedSlots: Byte;
begin
  if Camp.CanDoSpellActivity(2) then begin
    finished := False;
    menuIndex := -1;
    GDVars.horizontalChoice := 1;
    spellId := ViewChar.SpellMenu(5, 0, menuIndex, hasOptions);
    needsRedraw := True;
    if hasOptions then begin
      if MenuCore.YesNoMenu('Memorize These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetMemorize(GDVars.curChar)
      else
        finished := True;
    end else
      needsRedraw := False;
    menuIndex := -1;
    while finished = False do begin
      finished := Camp.DisplaySpellSlots = False;
      if finished then
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'cannot memorize any spells', 10, True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, menuIndex, hasOptions);
        needsRedraw := True;
        if spellId = 0 then
          finished := True
        else if (Camp.SpellSlotsRemaining(GDConsts.spellTbl[spellId].level, GDConsts.spellTbl[spellId].castClass,
                                     usedSlots) > 0) or
                                       ((GDConsts.spellTbl[spellId].castClass = 3) and
                                        (GDVars.bonusSpells > 0)) then begin
          if GDConsts.spellTbl[spellId].castClass = 2 then
            GDVars.bonusFlag := 1
          else
            GDVars.bonusFlag := 0;
          emptySlot := 0;
          while GDVars.curChar^.memorized[emptySlot] <> 0 do
            Inc(emptySlot);
          GDVars.curChar^.memorized[emptySlot] := spellId + Camp.SPELL_PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if menuIndex <> -1 then begin
      menuIndex := -1;
      spellId := ViewChar.SpellMenu(5, 0, menuIndex, hasOptions);
      if hasOptions then
        if MenuCore.YesNoMenu('Memorize these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetMemorize(GDVars.curChar);
    end;
    if needsRedraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Runs the Scribe menu. The spells already pending are shown first: Yes keeps them and skips the choosing, No clears
  them. Then scroll spells are chosen and marked pending, refusing a spell already known or pending or beyond the
  character's slots, and when the scrolls were shown the pending spells are confirmed again. Note: the marking does not
  check that the item is readable; it marks the first unmarked spell byte equal to the spell on any item. Note: the
  spell's class and level index the slot table unchecked, so a spell an item alone provides can read past it. }
procedure CampScribeMenu;
var
  finished: Boolean;
  hasOptions: Boolean;
  needsRedraw: Boolean;
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  scrollSlot: Byte;
  menuIndex: Integer;
  scroll: Types.PItemRec;
  alreadyPending: Boolean;
begin
  if Camp.CanDoSpellActivity(3) then begin
    finished := False;
    menuIndex := -1;
    spellId := ViewChar.SpellMenu(6, 0, menuIndex, hasOptions);
    needsRedraw := True;
    if hasOptions then begin
      if MenuCore.YesNoMenu('Scribe These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetScribe(GDVars.curChar)
      else
        finished := True;
    end else
      needsRedraw := False;
    menuIndex := -1;
    while finished = False do begin
      spellId := ViewChar.SpellMenu(3, 3, menuIndex, hasOptions);
      if spellId = 0 then begin
        finished := True;
        if hasOptions = False then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no copyable scrolls', 10, True)
        else
          needsRedraw := True;
      end else begin
        needsRedraw := True;
        if GDVars.curChar^.spellsKnown[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          scroll := GDVars.curChar^.itemsAddr;
          alreadyPending := False;
          while (scroll <> nil) and (alreadyPending = False) do begin
            if Magic.ItemReadable(scroll) then
              for scrollSlot := 1 to 3 do
                if (scroll^.spells[scrollSlot] > Camp.SPELL_ID_MASK) and
                    (scroll^.spells[scrollSlot] and Camp.SPELL_ID_MASK = spellId) then begin
                  CharHlp.PrintBottomLine('You are already scibing that spell');
                  alreadyPending := True;
                end;
            scroll := scroll^.next;
          end;
          if alreadyPending = False then begin
            if GDVars.curChar^.slots[GDConsts.spellTbl[spellId].castClass,
                                       GDConsts.spellTbl[spellId].level] > 0 then begin
              scroll := GDVars.curChar^.itemsAddr;
              while (scroll <> nil) and (alreadyPending = False) do begin
                scrollSlot := 1;
                repeat
                  if scroll^.spells[scrollSlot] = spellId then begin
                    scroll^.spells[scrollSlot] := scroll^.spells[scrollSlot] or Camp.SPELL_PENDING_FLAG;
                    alreadyPending := True;
                  end;
                  Inc(scrollSlot);
                until (scrollSlot > 3) or alreadyPending;
                scroll := scroll^.next;
              end;
            end else
              CharHlp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if menuIndex <> -1 then begin
      menuIndex := -1;
      spellId := ViewChar.SpellMenu(6, 0, menuIndex, hasOptions);
      if hasOptions then
        if MenuCore.YesNoMenu('Scribe these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetScribe(GDVars.curChar);
    end;
    if needsRedraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Lists the spell effects on each party member under the member's name. Spell effects show the name of the first spell
  (1..56) producing them, or 'Funky--<id>' when none does; other visible effects have fixed labels, and the rest are
  hidden. A member with none shows '<No Spell Effects>'. }
procedure CampDisplayMenu;
var
  effect: Types.PEffectRec;
  listHead: Types.PItemRec;
  listTail: Types.PItemRec;
  character: Types.PCharRecord;
  effectId: Byte;
  spellIndex: Byte;
  effectCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  isHeading: Byte;
  effectNameFound: Boolean;
  displayEffect: Boolean;
  viewNeedsRedraw: Boolean;
  effectName: Types.TStr40;
  menuIndex: Integer;
  { Unused in this version; see the other implementations of this routine. }
  choice: Char;

  { Appends a list node with the given text; isTitle marks a character-name heading. }
  procedure AddToList(isTitle: Boolean; displayText: Types.TStr40);
  begin
    GetMem(listTail^.next, SizeOf(Types.TCharacterListNode));
    listTail := listTail^.next;
    listTail^.next := nil;
    listTail^.name := displayText;
    listTail^.inUse := Ord(isTitle);
  end;

begin
  GetMem(listHead, SizeOf(Types.TCharacterListNode));
  listTail := listHead;
  listTail^.inUse := 0;
  listTail^.name := ' ';
  listTail^.next := nil;
  character := GDVars.partyHead;
  while character <> nil do begin
    effectCount := 0;
    AddToList(True, character^.name);
    effect := character^.effects;
    while effect <> nil do begin
      displayEffect := True;
      effectId := effect^.id;
      case effectId of
        1, 2, 5, 8..12, 14, 16, 17, 19..25, 28, 29, 32..34,
        36..39, 41, 42, 45, 46, 49, 51..53:
          begin
            spellIndex := 1;
            effectNameFound := False;
            while (spellIndex <= 56) and (effectNameFound = False) do
              if GDConsts.spellTbl[spellIndex].effect = effectId then begin
                effectName := GDConsts.spellNames[spellIndex];
                effectNameFound := True;
              end else
                Inc(spellIndex);
            if effectNameFound = False then
              effectName := 'Funky--' + CharHlp.Uint8Str(effectId);
          end;
        4: effectName := 'Dispel Evil';
        27: effectName := 'Fumbling';
        31: effectName := 'Helpless';
        35: effectName := 'Confused';
        44: effectName := 'Cause Disease';
        50: effectName := 'Hot Fire Shield';
        54: effectName := 'Cold Fire Shield';
        C_Effect.POISONED: effectName := 'Poisoned';
        59: effectName := 'Regenerating';
        61: effectName := 'Fire Resistance';
        63: effectName := 'Minor Globe of Invulnerability';
        C_Effect.FEEBLEMINDED: effectName := 'enfeebled';
        69: effectName := 'invisible to animals';
        71: effectName := 'Invisible';
        72: effectName := 'Camouflaged';
        73: effectName := 'protected from dragon breath';
        77: effectName := 'berserk';
        89: effectName := 'Displaced';
      else
        displayEffect := False;
      end;
      if displayEffect then begin
        Inc(effectCount);
        AddToList(False, ' ' + effectName);
      end;
      effect := effect^.next;
    end;
    if effectCount = 0 then
      AddToList(False, ' <No Spell Effects>');
    AddToList(False, ' ');
    character := character^.next;
  end;
  viewNeedsRedraw := True;
  menuIndex := 0;
  Border.DrawWindowFrame(True);
  choice := MenuCore.MenuVertical('', '', LightCyan, LightGreen, White, 1, 4, 38, 22, listHead, True, viewNeedsRedraw,
                                  menuIndex, listTail);
  MenuCore.FreeStringList(listHead);
  CharHlp.DisplayNoncombatInterface;
end;

{ Runs the Magic menu (cast, memorize, scribe, display, rest); extended keys change the current character. Ends on Exit,
  Escape or an interrupted rest.
  @param(interrupted Set True when a rest is interrupted; the menu ends at once when it is already True.) }
procedure CampMagicMenu(var interrupted: Boolean);
var
  choice: Char;
  extendedKey: Boolean;
begin
  choice := ' ';
  while (interrupted = False) and (not (choice in [C_Keys.NONE, 'E'])) do
  begin
    choice := MenuCore.MenuHorizontal('', GDConsts.magicMenuText, LightMagenta, LightGreen, White, True, True,
                                      extendedKey);
    if extendedKey then begin
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case choice of
        'C': Camp.NoncombatCastMenu;
        'M': Camp.CampMemorizeMenu;
        'S': Camp.CampScribeMenu;
        'D': Camp.CampDisplayMenu;
        'R': Camp.RestForSpellPrep(interrupted);
      end;
  end;
end;

{ Moves the current character one place earlier in the party; the first character moves to the end. }
procedure OrderMoveUp;
var
  previousCharacter: Types.PCharRecord;
  predecessor: Types.PCharRecord;
  successor: Types.PCharRecord;
begin
  predecessor := GDVars.partyHead;
  previousCharacter := nil;
  if predecessor = GDVars.curChar then begin
    while predecessor^.next <> nil do
      predecessor := predecessor^.next;
  end else
    while predecessor^.next <> GDVars.curChar do begin
      previousCharacter := predecessor;
      predecessor := predecessor^.next;
    end;
  successor := GDVars.curChar^.next;
  if GDVars.partyHead = GDVars.curChar then begin
    if successor <> nil then
      GDVars.partyHead := successor;
    predecessor^.next := GDVars.curChar;
    GDVars.curChar^.next := nil;
  end else begin
    predecessor^.next := successor;
    GDVars.curChar^.next := predecessor;
    if (predecessor = GDVars.partyHead) or (previousCharacter = nil) then
      GDVars.partyHead := GDVars.curChar
    else
      previousCharacter^.next := GDVars.curChar;
  end;
end;

{ Moves the current character one place later in the party; the last character moves to the front. }
procedure OrderMoveDown;
var
  predecessor: Types.PCharRecord;
  successor: Types.PCharRecord;
begin
  predecessor := GDVars.partyHead;
  if predecessor <> GDVars.curChar then
    while predecessor^.next <> GDVars.curChar do
      predecessor := predecessor^.next;
  successor := GDVars.curChar^.next;
  if successor = nil then begin
    GDVars.curChar^.next := GDVars.partyHead;
    GDVars.partyHead := GDVars.curChar;
    predecessor^.next := successor;
  end else begin
    GDVars.curChar^.next := successor^.next;
    if GDVars.partyHead = GDVars.curChar then
      GDVars.partyHead := successor;
    if predecessor <> GDVars.curChar then
      predecessor^.next := successor;
    successor^.next := GDVars.curChar;
  end;
end;

{ Reorders the party in two modes. In Select mode extended keys change the current character; in Place mode the up arrow
  moves it up and the down arrow moves it down. Enter, P and S switch modes. }
procedure PartyOrderMenu;
var
  selected: ShortInt;
  isExtendedKey: Boolean;
  choice: Char;
begin
  selected := 0;
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do
  begin
    choice := MenuCore.MenuHorizontal('Party Order: ', GDConsts.orderMenuTexts[selected], LightMagenta, LightGreen,
                                      White, True, True, isExtendedKey);
    if isExtendedKey then begin
      if selected = 0 then begin
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayParty(GDVars.curChar);
      end else begin
        case choice of
          'H': Camp.OrderMoveUp;
          'P': Camp.OrderMoveDown;
        end;
        CharHlp.DisplayParty(GDVars.curChar);
      end;
    end else
      if choice in [C_Keys.ENTER, 'P', 'S'] then
      begin
        selected := Ord(selected = 0);
        if selected <> 0 then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has been selected', 10, False)
        else
          CharHlp.ClearMessageWindow;
      end;
  end;
end;

{ Drops the current character from the party after confirmation, with a farewell that depends on whether it is enabled,
  and redraws the party. For the last party member it offers to quit to DOS instead. }
procedure CampDropMenu;
begin
  if (GDVars.curChar^.next = nil) and (GDVars.curChar = GDVars.partyHead) then begin
    if MenuCore.YesNoMenu('quit TO DOS: ', Yellow, LightGreen, White) = 'Y' then
    begin
      CharGen.RemoveCreature(False, True);
      GameIo.ExitGame;
    end else
      Exit;
    Exit;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'will be gone', 10, False);
  if MenuCore.YesNoMenu('Drop from party? ', Yellow, LightGreen, White) = 'Y' then
  begin
    if GDVars.curChar^.inPlay <> 0 then
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'bids you farewell', 10, True)
    else
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'is dumped in a ditch', 10, True);
    CharGen.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharHlp.DisplayParty(GDVars.curChar);
  end else
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'Breathes A sigh of relief', 10, True);
end;

{ Shows the difficulty menu with the current level highlighted and stores the level picked (Novice 1 to Champion 5) in
  the zone's difficulty variable; extended keys change the current character instead. }
procedure CampDifficultyMenu;
var
  choice: Char;
  isExtendedKey: Boolean;
  difficulty: Byte;
begin
  { the level is the low byte of the zone-0 word }
  difficulty := Lo(GDVars.zone0^.vars[$4CF4]);
  GDVars.horizontalChoice := difficulty;
  choice := MenuCore.MenuHorizontal('', GDConsts.levelMenuText, LightMagenta, LightGreen, White, True, True,
                                    isExtendedKey);
  if isExtendedKey then begin
    ViewChar.SelectPrevNextChar(choice);
    CharHlp.DisplayParty(GDVars.curChar);
  end else
    case choice of
      'N': difficulty := 1;
      'S': difficulty := 2;
      'V': difficulty := 3;
      'A': difficulty := 4;
      'C': difficulty := 5;
    end;
  GDVars.zone0^.vars[$4CF4] := difficulty;
end;

{ Adjusts the game delay, 0 (fastest) to 9 (slowest). Faster and Slower are offered only while the delay can move that
  way; the up arrow slows the game and the down arrow speeds it up. }
procedure CampSpeedMenu;
var
  choice: Char;
  isExtendedKey: Boolean;
  menuText: Types.TStr40;
begin
  repeat
    TextRend.displayString(1, 18, LightGreen, Black,
                           'Game Speed = ' + CharHlp.Uint8Str(GDVars.gameDelay) + ' (0=fastest 9=slowest)');
    menuText := '';
    if GDVars.gameDelay > 0 then
      menuText := menuText + ' Faster';
    if GDVars.gameDelay < 9 then
      menuText := menuText + ' Slower';
    menuText := menuText + ' Exit';
    choice := MenuCore.MenuHorizontal('Game Speed:', menuText, LightMagenta, LightGreen, White, True, True,
                                      isExtendedKey);
    if isExtendedKey then
      case choice of
        'P': if GDVars.gameDelay > 0 then Dec(GDVars.gameDelay);
        'H': if GDVars.gameDelay < 9 then Inc(GDVars.gameDelay);
      end else
      case choice of
        'F': Dec(GDVars.gameDelay);
        'S': Inc(GDVars.gameDelay);
      end;
  until choice in [C_Keys.NONE, 'E'];
  CharHlp.ClearMessageWindow;
end;

{ Runs the Alter menu: difficulty level, party order, drop, game speed, portrait icon, and a submenu toggling pictures
  and animation. Extended keys change the current character. }
procedure CampAlterMenu;
var
  choice: Char;
  toggleChoice: Char;
  isExtendedKey: Boolean;
  menuText: Types.TStr40;
begin
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do
  begin
    choice := MenuCore.MenuHorizontal('', GDConsts.alterMenuText, LightMagenta, LightGreen, White, True, True,
                                      isExtendedKey);
    if isExtendedKey then begin
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case choice of
        'L': Camp.CampDifficultyMenu;
        'O': Camp.PartyOrderMenu;
        'D': Camp.CampDropMenu;
        'S': Camp.CampSpeedMenu;
        'I': begin
               CharGen.CustomizeIcon;
               CharHlp.DisplayNoncombatInterface;
             end;
        'P': repeat
               if GDVars.picturesEnabled <> 0 then begin
                 menuText := 'Pics on  ';
                 if GDVars.animationsEnabled <> 0 then
                   menuText := menuText + 'Animation on  '
                 else
                   menuText := menuText + 'Animation off  ';
               end else
                 menuText := 'Pics off  ';
               menuText := menuText + 'Exit';
               toggleChoice := MenuCore.MenuHorizontal('', menuText, LightMagenta, LightGreen, White, False, True,
                                                       isExtendedKey);
               case toggleChoice of
                 'P': GDVars.picturesEnabled := Ord(GDVars.picturesEnabled = 0);
                 'A': GDVars.animationsEnabled := Ord(GDVars.animationsEnabled = 0);
               end;
             until toggleChoice in [C_Keys.NONE, 'E'];
      end;
  end;
end;

{ Heals the party with its cure spells. Rolls each cure spell the conscious members have memorized into a healing pool,
  rests for a time set by their cleric slots of levels 1, 4 and 5, then, unless the rest is interrupted, rolls one cure
  for each of those slots into the pool, spends the pool on the party in order and puts the rest clock back. When the
  party misses fewer hit points than the slots' combined heal time, the rest is shortened in proportion. Note: that heal
  time is never set to 0 before it is added up, and a member who is not conscious repeats the previous member's slot
  times.
  @param(interrupted Set True when the rest is interrupted.) }
procedure CampFixMenu(var interrupted: Boolean);
var
  healPool: Word;
  cureLightSlots: Word;
  cureSeriousSlots: Word;
  cureCriticalSlots: Word;
  savedRestTime: Types.TClock;

  { A member counts as conscious only when its status is OKAY. }
  function CanCast(character: Types.PCharRecord): Boolean;
  begin
    CanCast := character^.status = C_Status.OKAY;
  end;

  { Adds a roll for each cure spell memorized by a conscious member to the healing pool. }
  procedure RollMemorizedCures;
  var
    rolledHealing: Word;
    spellIndex: Byte;
    character: Types.PCharRecord;
  begin
    rolledHealing := 0;
    character := GDVars.partyHead;
    while character <> nil do begin
      if CanCast(character) then
        for spellIndex := 0 to 57 do
          case character^.memorized[spellIndex] of
            3: Inc(rolledHealing, FxEngine.RollDice(1, 8));
            58: Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
            71: Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
          end;
      character := character^.next;
    end;
    Inc(healPool, rolledHealing);
  end;

  { Adds a cure roll for each cleric slot of levels 1, 4 and 5 counted by ComputeFixTime. }
  procedure RollCureSlots;
  var
    rolledHealing: Word;
    rollIndex: Byte;
  begin
    rolledHealing := 0;
    for rollIndex := 1 to cureLightSlots do Inc(rolledHealing, FxEngine.RollDice(1, 8));
    for rollIndex := 1 to cureSeriousSlots do Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
    for rollIndex := 1 to cureCriticalSlots do Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
    Inc(healPool, rolledHealing);
  end;

  { Returns the party's total missing hit points. }
  function PartyHitPointsMissing: Word;
  var
    totalDamage: Word;
    character: Types.PCharRecord;
  begin
    totalDamage := 0;
    character := GDVars.partyHead;
    while character <> nil do begin
      Inc(totalDamage, character^.hpMax - character^.hpCur);
      character := character^.next;
    end;
    PartyHitPointsMissing := totalDamage;
  end;

  { Counts the conscious members' cleric slots of levels 1, 4 and 5 and sets the rest clock from them. }
  procedure ComputeFixTime;
  var
    healingMinutes: Word;
    character: Types.PCharRecord;
    requiredRestMinutes: Word;
    lightMinutes: Word;
    seriousMinutes: Word;
    criticalMinutes: Word;
    characterRestMinutes: Word;
    reductionRatio: Byte;
  begin
    character := GDVars.partyHead;
    lightMinutes := 0;
    seriousMinutes := 0;
    criticalMinutes := 0;
    cureLightSlots := 0;
    cureSeriousSlots := 0;
    cureCriticalSlots := 0;
    requiredRestMinutes := 0;
    while character <> nil do begin
      characterRestMinutes := 0;
      if CanCast(character) then begin
        Inc(cureLightSlots, character^.slots[0, 1]);
        lightMinutes := character^.slots[0, 1] * 15;
        Inc(cureSeriousSlots, character^.slots[0, 4]);
        seriousMinutes := character^.slots[0, 4] * 60;
        Inc(cureCriticalSlots, character^.slots[0, 5]);
        criticalMinutes := character^.slots[0, 5] * 75;
      end;
      if lightMinutes > 0 then begin
        characterRestMinutes := 240;
        Inc(healingMinutes, 27);
      end;
      if seriousMinutes + criticalMinutes > 0 then begin
        characterRestMinutes := 360;
        if criticalMinutes > 0 then
          Inc(healingMinutes, 78)
        else
          Inc(healingMinutes, 34);
      end;
      Inc(characterRestMinutes, lightMinutes + seriousMinutes + criticalMinutes);
      if requiredRestMinutes < characterRestMinutes then
        requiredRestMinutes := characterRestMinutes;
      character := character^.next;
    end;
    if PartyHitPointsMissing < healingMinutes then begin
      reductionRatio := healingMinutes div PartyHitPointsMissing;
      requiredRestMinutes := requiredRestMinutes div reductionRatio;
    end;
    GDVars.restTime[3] := requiredRestMinutes div 60;
    GDVars.restTime[2] := (requiredRestMinutes - 60 * GDVars.restTime[3]) div 10;
    GDVars.restTime[1] := requiredRestMinutes mod 10;
  end;

  { Spends the healing pool on each member in party order, up to that member's missing hit points. }
  procedure HealParty;
  var
    character: Types.PCharRecord;
    healingNeeded: Word;
  begin
    character := GDVars.partyHead;
    while character <> nil do begin
      if character^.hpMax > character^.hpCur then begin
        healingNeeded := character^.hpMax - character^.hpCur;
        if healingNeeded > healPool then healingNeeded := healPool;
        if healingNeeded < 1 then healingNeeded := 0;
        if healingNeeded > 0 then
          if FxEngine.RestoreHitPoints(character, healingNeeded, False) then
            if healingNeeded <= healPool then
              Dec(healPool, healingNeeded);
      end;
      character := character^.next;
    end;
  end;

begin
  interrupted := False;
  healPool := 0;
  if PartyHitPointsMissing <> 0 then begin
    RollMemorizedCures;
    if PartyHitPointsMissing = 0 then begin
      CharHlp.DisplayParty(GDVars.curChar);
      CharHlp.PrintPositionAndTime;
    end else begin
      savedRestTime := GDVars.restTime;
      ComputeFixTime;
      interrupted := GameTime.CampRest(False);
      if interrupted = False then begin
        RollCureSlots;
        HealParty;
        CharHlp.DisplayParty(GDVars.curChar);
        CharHlp.PrintPositionAndTime;
        GDVars.restTime := savedRestTime;
      end;
    end;
  end;
end;

procedure CampMainMenu(var interrupted: Boolean);
var
  savedInterfaceState: Byte;
  choice: Char;
  viewDone: Boolean;
  extendedKey: Boolean;
begin
  savedInterfaceState := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.CAMPING;
  GDVars.healTicks := 0;
  FillChar(GDVars.restTime, SizeOf(GDVars.restTime), 0);
  GDVars.savedPictureName := GDVars.picArcName;
  GDVars.savedPictureId := GDVars.picArcId;
  CharHlp.DisplayNoncombatInterface;
  Border.ClearBox(1, 17, 38, 22);
  TextRend.displayString(1, 18, LightGreen, Black, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  choice := ' ';
  while (interrupted = False) and (not (choice in [C_Keys.NONE, 'E'])) do
  begin
    choice := MenuCore.MenuHorizontal('', GDConsts.campMenuText, LightMagenta, LightGreen, White, True, True,
                                      extendedKey);
    if extendedKey then begin
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case choice of
        'S': begin
               Inc(GDVars.zone0^.vars[$4C3C]);
               if GDVars.zone0^.vars[$4C3C] >= 10 then begin
                 if Camp.RuleBookCheck = 0 then
                   GameIo.ExitGame;
                 CharHlp.DisplayNoncombatInterface;
                 GDVars.zone0^.vars[$4C3C] := 0;
               end;
               SaveLoad.SaveGame;
               if MenuCore.YesNoMenu('Quit TO DOS ', Yellow, LightGreen, White) = 'Y' then
                 GameIo.ExitGame;
             end;
        'V': begin
               GDVars.horizontalChoice := 1;
               ViewChar.ViewCharMenu(viewDone);
             end;
        'M': begin
               GDVars.horizontalChoice := 1;
               Camp.CampMagicMenu(interrupted);
             end;
        'R': begin
               GDVars.horizontalChoice := 1;
               Camp.RestForSpellPrep(interrupted);
             end;
        'F': Camp.CampFixMenu(interrupted);
        'A': begin
               GDVars.horizontalChoice := 1;
               Camp.CampAlterMenu;
             end;
      end;
  end;
  if Copy(GDVars.savedPictureName, 1, 3) = 'PIC' then
    Portrait.LoadAnimation(GDVars.savedPictureName, GDVars.savedPictureId, 0, GDVars.bigAnim);
  Camp.ResetPartySpellActivities;
  GDVars.lastTarget := nil;
  GDVars.interfaceState := savedInterfaceState;
  CharHlp.PrintPositionAndTime;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
end;

begin
end.
