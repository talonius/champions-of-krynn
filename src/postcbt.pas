{ Post-combat resolution: experience, combat results, the summary, the loot menus, creature cleanup, the NPC treasure
  share and the bank-pool hand-out ("the party makes a withdrawl").

  GDConsts.clearedEffectIds lists the eleven effect ids stripped from every party member after combat. }
{$O+,F+}
unit PostCbt;

interface

{ Settles the end of a battle. The bank's held items go back to their owners first. Outside the demo the results are
  worked out (DetermineCombatResults); the combat records and the defeated creatures are then removed and each party
  member's stats recalculated. Unless the party was destroyed (a duel always counts as survived), a fleeing party loses
  the loot, the NPCs take their share, the summary and the loot menu run, and the treasure list is freed; a destroyed
  party gets the game-over message and combat result $80. The zone's per-battle modifiers and flags are reset at the
  end. The demo skips everything after the cleanup. }
procedure PostCombat;

{ Calls the priming entry of each overlay this unit uses except CharGen, so the overlay manager loads them. }
procedure PrimePostCbt;

implementation

uses Types, TextRend, Border, Shop, EclMenu, CharGen, ViewChar, Money, Magic, FxEngine, CharHlp, MenuCore, MapTiles,
  Debug, GDConsts, GDVars, C_Keys, C_Class, Crt, C_Stat, C_Status, C_Ifc, C_Side, C_Npc;

procedure PrimePostCbt;
begin
  ViewChar.PrimeViewChar;
  EclMenu.PrimeEclMenu;
  Money.PrimeMoney;
  MenuCore.PrimeMenuCore;
  Shop.PrimeShop;
  CharHlp.PrimeCharHlp;
  Debug.PrimeDebug;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  MapTiles.PrimeMapTiles;
end;

{ Works out the experience share of a won battle. In a duel it is 100 per level of the current character. Otherwise each
  defeated hostile adds its experience award plus its bonus per rolled hit point, its coins go to the treasure money
  when it was not a party member, and, unless the zone forbids combat items, copies of its items go to the treasure
  list. The treasure money then adds experience by coin type (1 per 100, 20 and 10 of the first three, 1, 2, 250 and
  2200 each of the rest), each new treasure item adds 400 per plus, and the total is divided among the party members who
  are not out of play or animated.
  @param(share Receives the experience each character earns.) }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharRecord;
  i: ShortInt;
  expTotal: LongInt;
  q: Types.PItemRec;
  it: Types.PItemRec;
  { written, never read }
  cnt: Byte;
begin
  if GDVars.duelFlag <> 0 then
    share := GDVars.curChar^.levelHighest * 100
  else begin
    expTotal := 0;
    p := GDVars.partyHead;
    cnt := 0;
    while p <> nil do begin
      it := p^.itemsAddr;
      if (p^.hostile = C_Side.ENEMY) and (p^.status <> C_Status.OKAY) and
          (p^.status <> C_Status.RUNNING) then begin
        GDVars.monstersKilled := True;
        if p^.combatAddr^.nonPartyMember = 1 then
          for i := 0 to 6 do
            Inc(GDVars.treasureMoney[i], p^.coinsA[i]);
        expTotal := expTotal + p^.xpAward + p^.xpBonusPerHp * p^.hpRolled;
        if GDVars.zone1^.noCombatItems <> 1 then
          while it <> nil do begin
            Inc(cnt);
            if GDVars.treasureItems = nil then begin
              GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
              CharHlp.PrintItemString(p, it, 0, 0, False, False);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := nil;
            end else begin
              q := GDVars.treasureItems;
              GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
              CharHlp.PrintItemString(p, it, 0, 0, False, False);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := q;
            end;
            it := it^.next;
          end;
      end;
      p := p^.next;
    end;
    Inc(expTotal, GDVars.treasureMoney[0] div 100);
    Inc(expTotal, GDVars.treasureMoney[1] div 20);
    Inc(expTotal, GDVars.treasureMoney[2] div 10);
    Inc(expTotal, GDVars.treasureMoney[3]);
    Inc(expTotal, GDVars.treasureMoney[4] * 2);
    Inc(expTotal, GDVars.treasureMoney[5] * 250);
    Inc(expTotal, GDVars.treasureMoney[6] * 2200);
    q := GDVars.treasureItems;
    while (q <> nil) and (q <> GDVars.prevTreasure) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    share := expTotal div (GDVars.zone1^.partySize - GDVars.nonAnimCount);
  end;
end;

{ Gives each party member in play and not animated its share of the experience: a single-class character with high prime
  abilities gets a tenth more, a two-class character half, and a three-class character a third. Nothing is given when
  the zone withholds experience.
  @param(experience The share.) }
procedure AwardExperience(experience: LongInt);
var
  p: Types.PCharRecord;
  share: LongInt;
begin
  if GDVars.zone0^.mirrorDuel <> 0 then Exit;
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.inPlay <> 0) and (p^.status <> C_Status.ANIMATED) then begin
      share := experience;
      case p^.charClass of
        C_Class.CLERIC: if p^.stats[C_Stat.WISDOM].cur > 14 then share := experience div 10 + experience;
        C_Class.FIGHTER: if p^.stats[C_Stat.STRENGTH].cur > 15 then share := experience div 10 + experience;
        C_Class.PALADIN: if (p^.stats[C_Stat.STRENGTH].cur > 15) and (p^.stats[C_Stat.WISDOM].cur > 15) then
             share := experience div 10 + experience;
        C_Class.RANGER: if (p^.stats[C_Stat.STRENGTH].cur > 15) and (p^.stats[C_Stat.INTELLIGENCE].cur > 15) and
          (p^.stats[C_Stat.WISDOM].cur > 15) then
             share := experience div 10 + experience;
        C_Class.MAGE: if p^.stats[C_Stat.INTELLIGENCE].cur > 15 then share := experience div 10 + experience;
        C_Class.THIEF: if p^.stats[C_Stat.DEXTERITY].cur > 15 then share := experience div 10 + experience;
        C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
          C_Class.MAGE_THIEF:
          share := experience div 2;
        C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF: share := experience div 3;
      end;
      Inc(p^.experience, share);
    end;
    p := p^.next;
  end;
end;

{ Works out how a battle ended for the party, whose members head the creature list. It records whether a member fled;
  whether the party was defeated, unless a player character is still standing, the fight was a duel, or a zone flag is
  set with someone still alive; and whether the battle was won, when a member is okay or animated. It also counts the
  members out of play or animated. Each member loses the effects that end with combat, and a win awards experience. A
  surviving party gets running members back and the dying or unconscious ones okay or unconscious as that zone flag
  decides; a fleeing party records a fled result and leaves behind the members who did not run; a destroyed party is
  removed. A demo duel only awards the winner and settles the statuses. }
procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  done: Boolean;
  i: Byte;
  alive: Boolean;
begin
  GDVars.nonAnimCount := 0;
  GDVars.partyDefeated := True;
  GDVars.partyFled := False;
  p := GDVars.partyHead;
  while (p <> nil) and (p^.combatAddr^.nonPartyMember <> 1) do begin
    if p^.status = C_Status.RUNNING then
      GDVars.partyFled := True;
    p := p^.next;
  end;
  p := GDVars.partyHead;
  alive := False;
  while (p <> nil) and not alive do begin
    if (p^.inPlay <> 0) or (p^.status = C_Status.UNCONSCIOUS) or (p^.status = C_Status.RUNNING) or
        (p^.status = C_Status.DYING) then
      alive := True;
    p := p^.next;
  end;
  if (GDVars.duelFlag <> 0) or ((GDVars.zone1^.reviveFlag <> 0) and alive) then
    GDVars.partyDefeated := False;
  GDVars.combatWon := False;
  p := GDVars.partyHead;
  if (GDVars.duelFlag = 0) or (GDVars.demoFlag = 0) then begin
    while (p <> nil) and (p^.combatAddr^.nonPartyMember <> 1) do begin
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY)) and (p^.hostile = C_Side.PLAYER) and (p^.npc < C_Npc.NON_PLAYER) then
        GDVars.partyDefeated := False;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := True;
        GDVars.partyFled := False;
      end;
      if (p^.inPlay = 0) or (p^.status = C_Status.ANIMATED) then
        Inc(GDVars.nonAnimCount);
      for i := 1 to 11 do
        FxEngine.RemoveEffect(p, GDConsts.clearedEffectIds[i], nil);
      p := p^.next;
    end;
    if GDVars.combatWon then begin
      PostCbt.DetermineLootExp(GDVars.expShare);
      PostCbt.AwardExperience(GDVars.expShare);
    end;
    p := GDVars.partyHead;
    if not GDVars.partyDefeated then begin
      while (p <> nil) and (p^.combatAddr^.nonPartyMember <> 1) do begin
        if not GDVars.partyFled then begin
          case p^.status of
            C_Status.RUNNING: begin
                 p^.status := C_Status.OKAY;
                 p^.inPlay := 1;
               end;
            C_Status.DYING: if GDVars.zone1^.reviveFlag <> 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.inPlay := 1;
                 p^.hpCur := 1;
               end else
                 p^.status := C_Status.UNCONSCIOUS;
            C_Status.UNCONSCIOUS: if p^.hpCur > 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.inPlay := 1;
               end else if GDVars.zone1^.reviveFlag <> 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.inPlay := 1;
                 p^.hpCur := 1;
               end;
          end;
          p := p^.next;
        end else begin
          GDVars.zone1^.combatResult := $81;
          if p^.status = C_Status.RUNNING then begin
            p^.status := C_Status.OKAY;
            p^.inPlay := 1;
            p := p^.next;
          end else begin
            GDVars.curChar := p;
            p := p^.next;
            CharGen.RemoveCreature(False, True);
          end;
        end;
      end;
    end else begin
      p := GDVars.partyHead;
      done := False;
      while (p <> nil) and not done do begin
        if p^.combatAddr^.nonPartyMember <> 1 then begin
          GDVars.curChar := p;
          CharGen.RemoveCreature(False, True);
        end else
          done := True;
        p := p^.next;
      end;
      GDVars.zone1^.partySize := 0;
    end;
  end else begin
    p := GDVars.partyHead;
    while p <> nil do begin
      if (p^.inPlay = 1) and (p^.status = C_Status.OKAY) and (p^.hostile <> C_Side.ENEMY) then begin
        GDVars.combatWon := True;
        PostCbt.DetermineLootExp(GDVars.expShare);
        PostCbt.AwardExperience(GDVars.expShare);
      end;
      p := p^.next;
    end;
    p := GDVars.partyHead;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then
        p^.inPlay := 1;
      if p^.status = C_Status.DYING then
        p^.status := C_Status.UNCONSCIOUS;
      p := p^.next;
    end;
  end;
end;

{ Shows the outcome of the battle (fled, lost, won the duel, won, or treasure found; a bank withdrawal instead names the
  fee) and the experience each character, or the duelist, receives, then waits for Enter. Fleeing also throws away the
  treasure and money; a lost fight sets combat result $80.
  @param(experience The share shown; 0 after a flight or a lost fight.) }
procedure PostCombatSummary(experience: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  { always empty }
  query: String[1];
  ext: Boolean;
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  query[0] := #0;
  Border.DrawWindowFrame(True);
  if GDVars.monstersKilled or (GDVars.duelFlag <> 0) then begin
    if GDVars.partyFled then begin
      TextRend.displayString(1, 3, LightGreen, Black, 'The party has fled.');
      experience := 0;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p^.next;
        FreeMem(p, SizeOf(Types.TItemRec));
        p := q;
      end;
      FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
    end else if ((GDVars.duelFlag <> 0) and not GDVars.combatWon) or
      (not GDVars.combatWon and (GDVars.zone1^.reviveFlag <> 0)) then begin
      GDVars.zone1^.combatResult := $80;
      TextRend.displayString(1, 3, LightGreen, Black, 'You have lost the fight.');
      experience := 0;
    end else if GDVars.duelFlag <> 0 then
      TextRend.displayString(1, 3, LightGreen, Black, 'You have won the duel.')
    else
      TextRend.displayString(1, 3, LightGreen, Black, 'The party has won.');
  end else begin
    if GDVars.zone0^.mirrorDuel <> 0 then begin
      TextRend.displayString(1, 5, LightGreen, Black, 'The party makes a withdrawl.  A small');
      TextRend.displayString(1, 7, LightGreen, Black, 'fee has been assessed by the bank.');
    end else
      TextRend.displayString(1, 3, LightGreen, Black, 'The party has found Treasure!');
  end;
  Str(experience, numStr);
  if GDVars.duelFlag <> 0 then
    msg := 'The duelist receives ' + numStr
  else
    msg := 'Each character receives ' + numStr;
  if GDVars.zone0^.mirrorDuel = 0 then begin
    TextRend.displayString(1, 5, LightGreen, Black, msg);
    TextRend.displayString(1, 7, LightGreen, Black, 'experience points.');
  end;
  c := MenuCore.MenuHorizontal(query, 'press <enter>/<return> to continue', White, White, White, True, False, ext);
end;

{ Lists the treasure items in a vertical Take menu.
  @param(c Receives the key pressed.)
  @param(itemToTake Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  itemText: String[16];
  { Unused in this version; see the other implementations of this routine. }
  lenv: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  redraw: Boolean;
  p: Types.PItemRec;
begin
  redraw := True;
  Border.DrawWindowFrame(True);
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, False, False);
    p := p^.next;
  end;
  head := Types.PItemRec(GDVars.treasureItems);
  c := MenuCore.MenuVertical('Items: ', 'Take', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True, redraw,
                             idx, cursor);
  itemToTake := Types.PItemRec(cursor);
end;

{ Runs the item-taking menu: each item taken goes to the current character as a copy, and the treasure item is freed. It
  ends on any key other than Take or Enter, or when no treasure items are left. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  p: Types.PItemRec;
  c: Char;
  done: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := Types.PItemRec(GDVars.treasureItems);
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if (c <> 'T') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(Types.PItemRec(itemToTake), failed);
      if not failed then begin
        p := GDVars.treasureItems;
        if p = itemToTake then
          GDVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        if itemToTake <> nil then
          FreeMem(itemToTake, SizeOf(Types.TItemRec));
        if GDVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharHlp.DisplayNoncombatInterface;
end;

{ Offers the treasure's money and items to take: with both a Money/Items menu, where the up and down arrows change the
  current character, until one kind is gone; otherwise straight to the money or the items.
  @param(treasure Whether money is left; updated.)
  @param(items Whether items are left; updated.) }
procedure LootTakeMenu(var treasure, items: Boolean);
var
  c: Char;
  done: Boolean;
  ext: Boolean;
begin
  done := False;
  if treasure then begin
    if items then begin
      repeat
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', LightMagenta, LightGreen, White, True, True, ext);
        case c of
          'M': begin
                 Money.TakeMoneyMenu;
                 CharHlp.DisplayNoncombatInterface;
               end;
          'I': PostCbt.LootTakeItemMenu;
          'E', C_Keys.NONE: done := True;
          C_Keys.UP: ViewChar.SelectPrevNextChar(c);
          C_Keys.DOWN: ViewChar.SelectPrevNextChar(c);
        end;
        CharHlp.DisplayParty(GDVars.curChar);
        Money.DetermineTreasure(treasure, items);
        if not treasure or not items then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ Runs the after-battle menu until the party leaves: View, Take while treasure is left, Pool, Share while money is left,
  and Detect when the current character is in play with a detect spell memorized and items are left. The arrow keys
  change the current character. Leaving with treasure left asks whether to go back for it. }
procedure LootMenu;
var
  treasure: Boolean;
  items: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  canDetect: Boolean;
  menu: String;
  c: Char;
  done: Boolean;
  ext: Boolean;
  { always empty }
  query: String[1];
  ynIdx: Byte;
  i: Byte;
  detectSpell: Byte;
  hasDetect: Boolean;
  tail: String[13];
begin
  query[0] := #0;
  done := False;
  CharHlp.DisplayNoncombatInterface;
  treasure := False;
  repeat
    Money.DetermineTreasure(treasure, items);
    menu := 'View Pool Exit';
    i := 0;
    tail := ' Exit';
    hasDetect := False;
    if items then
      while (i <= 57) and not hasDetect do begin
        if (GDVars.curChar^.memorized[i] = 5) or (GDVars.curChar^.memorized[i] = 11) or
            (GDVars.curChar^.memorized[i] = 77) or (GDVars.curChar^.memorized[i] = 103) then
          if GDVars.curChar^.inPlay <> 0 then begin
            hasDetect := True;
            detectSpell := GDVars.curChar^.memorized[i];
          end;
        Inc(i);
      end;
    if hasDetect then
      tail := ' Detect Exit';
    if treasure then
      menu := 'View Take Pool Share' + tail
    else if items then
      menu := 'View Take Pool' + tail;
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, True, ext);
    if not ext then
      case c of
        'V': ViewChar.ViewCharMenu(ext);
        'T': PostCbt.LootTakeMenu(treasure, items);
        'P': if not ext then Money.PoolMoney;
        'S': Money.ShareMoney;
        'D': Magic.CastSpell(detectSpell, 0, 0, ext);
        'E', C_Keys.NONE: begin
                   Money.DetermineTreasure(treasure, items);
                   if treasure or items then begin
                     menu := '~Yes ~No';
                     TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True,
                                                   'There is still treasure left.  ');
                     TextRend.displayMessageWindow(1, 17, 38, 22, White, Black, False,
                                                   'Do you want to go back and claim your treasure?');
                     ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White, False,
                                                                    False);
                     if ynIdx = 1 then
                       done := True
                     else
                       TextRend.ClearRect(1, 17, 38, 22);
                   end else
                     done := True;
                 end;
      end else begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end;
  until done;
end;

{ Removes the monsters and hostile creatures from the creature list, recording each removal as a monster killed and
  counting those out of play for the zone, and frees the combat records of the party. The first one removed raises a
  zone flag when it is out of play, and a running one sets combat result 1 when none is set. The current character
  becomes the party's first member. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
  first: Boolean;
begin
  first := True;
  GDVars.zone1^.monstersDef := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.combatAddr^.nonPartyMember = 1) or (p^.hostile = C_Side.ENEMY) then begin
      GDVars.monstersKilled := True;
      if p^.inPlay <> 1 then begin
        Inc(GDVars.zone1^.monstersDef);
        if first then
          GDVars.zone0^.bankFlag := 1;
      end;
      if (p^.status = C_Status.RUNNING) and (GDVars.zone1^.combatResult = 0) then
        GDVars.zone1^.combatResult := 1;
      first := False;
      next := p^.next;
      GDVars.curChar := p;
      CharGen.RemoveCreature(p^.combatAddr^.nonPartyMember = 1, True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      p := p^.next;
    end;
  end;
  GDVars.curChar := GDVars.partyHead;
end;

{ Lets each okay NPC take its share of the treasure money: its weight is the low three bits of its modified field,
  everyone else counts 1, and the NPCs' shares come out of each coin type. Each NPC that took a share says so, and the
  player presses Enter. }
procedure NpcTreasureShare;
var
  p: Types.PCharRecord;
  npcShares: Byte;
  total: Byte;
  { the LongInt quotient, truncated }
  cut: Byte;
  row: Byte;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  msg: String[8];
  took: Boolean;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  took := False;
  p := GDVars.partyHead;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    if (p^.npc > $7F) and (p^.status = C_Status.OKAY) then begin
      Inc(npcShares, p^.modified and $07);
      Inc(total, p^.modified and $07);
    end else
      Inc(total);
    p := p^.next;
  end;
  if npcShares > 0 then
    for i := 0 to 6 do
      if GDVars.treasureMoney[i] > 0 then begin
        cut := GDVars.treasureMoney[i] div total;
        Dec(GDVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindowFrame(True);
    p := GDVars.partyHead;
    row := 0;
    while p <> nil do begin
      if (p^.npc > $7F) and (p^.status = C_Status.OKAY) and (p^.modified > 0) then begin
        if p^.gender = 0 then
          TextRend.displayMessageWindow(5, row + 5, 34, 22, LightGreen, Black, True,
                                        p^.name + ' takes and hides ' + 'his' + ' share.')
        else
          TextRend.displayMessageWindow(5, row + 5, 34, 22, LightGreen, Black, True,
                                        p^.name + ' takes and hides ' + 'her' + ' share.');
        Inc(row, 2);
      end;
      p := p^.next;
    end;
    c := MenuCore.MenuHorizontal('', 'press <enter>/<return> to continue', White, White, White, True, False, ext);
  end;
end;

{ Gives each item the bank holds back to its owner, as the current character, and frees the bank's list. }
procedure BankPoolClone;
var
  node: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  copiedItem: Types.PItemRec;
  p: Types.PBankNode;
  tmp: Types.PBankNode;
  failed: Boolean;
begin
  p := GDVars.bankHead;
  while p <> nil do begin
    GetMem(node, SizeOf(Types.TItemRec));
    GDVars.curChar := p^.owner;
    node^ := p^.item;
    node^.next := nil;
    Shop.GiveItemCopyToCreature(Types.PItemRec(node), failed);
    FreeMem(node, SizeOf(Types.TItemRec));
    tmp := p;
    p := p^.next;
    FreeMem(tmp, SizeOf(Types.TBankNode));
  end;
  GDVars.bankHead := nil;
end;

procedure PostCombat;
var
  p: Types.PItemRec;
  q: Types.PItemRec;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  lootCount: Word;
begin
  PostCbt.BankPoolClone;
  GDVars.zone1^.combatResult := 0;
  GDVars.monstersKilled := False;
  if GDVars.demoFlag = 0 then
    PostCbt.DetermineCombatResults;
  GDVars.interfaceState := C_Ifc.LOOT;
  PostCbt.PostCombatCreatureCleanup;
  if GDVars.demoFlag <> 0 then Exit;
  cr := GDVars.partyHead;
  while cr <> nil do begin
    CharHlp.RecalcStats(cr);
    cr := cr^.next;
  end;
  if not GDVars.partyDefeated or (GDVars.duelFlag <> 0) then begin
    if GDVars.partyFled then begin
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p;
        p := p^.next;
        FreeMem(q, SizeOf(Types.TItemRec));
      end;
      GDVars.treasureItems := nil;
    end;
    if GDVars.demoFlag = 0 then begin
      PostCbt.NpcTreasureShare;
      PostCbt.PostCombatSummary(GDVars.expShare);
      PostCbt.LootMenu;
    end;
    p := GDVars.treasureItems;
    while p <> nil do begin
      q := p;
      p := p^.next;
      FreeMem(q, SizeOf(Types.TItemRec));
    end;
    GDVars.treasureItems := nil;
  end else begin
    GDVars.zone1^.combatResult := $80;
    Border.DrawWindowFrame(True);
    GDVars.curCol := 2;
    GDVars.curRow := 6;
    TextRend.displayMessageWindow(2, 5, 37, 22, LightGreen, Black, True,
                                  'The monsters rejoice for the party has been destroyed');
    TextRend.displayAndPause(LightMagenta, Black, 'Press any key to continue');
  end;
  GDVars.slowText := 1;
  GDVars.zone1^.modMonThac0 := 0;
  GDVars.zone1^.modPartyThac0 := 0;
  GDVars.zone1^.modPartyMove := 0;
  GDVars.zone1^.noCombatItems := 0;
  GDVars.zone1^.reviveFlag := 0;
  GDVars.zone0^.mirrorDuel := 0;
end;

begin
end.
