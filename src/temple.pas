{ Temple services: the cures, healing, raising the dead and the temple menus. }
{$O+,F+}
unit Temple;

interface

{ Runs a temple. The money pool starts empty; the menu offers Heal, View, Pool and Appraise, plus Take and Share while
  the pool holds money; the up and down arrow keys change the current character. Exit with money left in the pool asks
  whether to go back for it. }
procedure TempleMainMenu;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeTemple;

implementation

uses Types, TextRend, Border, Crt, GDConsts, GDVars, EclMenu, ViewChar, Money, Magic, FxEngine, CharHlp,
  ClassCal, MenuCore, Debug, C_Keys, C_Class, C_Status, C_Stat, C_Ifc, C_Effect, C_Race;

procedure PrimeTemple;
begin
  Money.PrimeMoney;
  ViewChar.PrimeViewChar;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  EclMenu.PrimeEclMenu;
  Debug.PrimeDebug;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  ClassCal.PrimeClassCal;
end;

{ Reports that the current character does not need the cure and asks whether to cast it anyway.
  @param(msg The report, printed after the character's name.)
  @returns('Y' or 'N'.) }
function ConfirmCureAnyway(msg: String): Char;
begin
  CharHlp.PrintCreatureMessage(GDVars.curChar, msg, 0, False);
  ConfirmCureAnyway := MenuCore.YesNoMenu('cast cure anyway: ', LightMagenta, LightGreen, White);
  CharHlp.ClearMessageWindow;
end;

{ Offers a cure for a price and, if accepted, takes the money from the current character's coins when they cover it,
  else from the pool when it does ("Not enough money." otherwise), the remainder coming back as steel, and reports the
  cure.
  @param(spell The cure's name.)
  @param(cost The price in steel pieces.)
  @returns('Y' when it was paid for, else 'N'.) }
function ConfirmCureCost(spell: String; cost: Word): Char;
var
  key: Char;
  characterGold: Word;
  pooledGold: LongInt;
begin
  spell := spell + ' will only cost ' + CharHlp.Uint16Str(cost) + ' steel pieces.';
  TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, spell);
  key := MenuCore.YesNoMenu('pay for cure ', LightMagenta, LightGreen, White);
  if key = 'Y' then begin
    characterGold := ViewChar.CreatureCoinValueInSteel(GDVars.curChar);
    if cost <= characterGold then begin
      Dec(characterGold, cost);
      Money.SetCreatureCoinsInSteel(characterGold);
    end else begin
      pooledGold := Money.CoinValueInSteel(GDVars.treasureMoney);
      if cost <= pooledGold then begin
        Dec(pooledGold, cost);
        Money.SetTreasureCoinsInSteel(pooledGold);
      end else begin
        CharHlp.PrintBottomLine('Not enough money.');
        key := 'N';
      end;
    end;
  end;
  if key = 'Y' then begin
    CharHlp.ClearMessageWindow;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'is cured.', 0, True);
  end;
  ConfirmCureCost := key;
end;

{ Cure Blindness for 500 steel: removes Blind; asks first when the character is not blind. }
procedure CureBlindness;
var
  effectNode: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  messageText: String;
  key: Char;
begin
  messageText := '';
  key := 'Y';
  if not CharHlp.HasEffect(GDVars.curChar, C_Effect.BLIND, effectNode) then
    key := Temple.ConfirmCureAnyway('is not blind.');
  if key = 'Y' then begin
    key := Temple.ConfirmCureCost('Cure Blindness', 500);
    if key = 'Y' then
      FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
  end;
end;

{ Cure Disease for 500 steel: removes the six disease effects with the effect lock set and recalculates the character's
  abilities; asks first when the character has none. }
procedure CureDisease;
var
  effectNode: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  messageText: String;
  key: Char;
  effectIndex: Byte;
  found: Boolean;
begin
  found := False;
  messageText := '';
  key := 'Y';
  for effectIndex := 1 to 6 do
    if CharHlp.HasEffect(GDVars.curChar, GDConsts.diseaseEffects[effectIndex], effectNode) then
      found := True;
  if not found then
    key := Temple.ConfirmCureAnyway('is not Diseased.');
  if key = 'Y' then begin
    key := Temple.ConfirmCureCost('Cure Disease', 500);
    if key = 'Y' then begin
      GDVars.effectBusy := 1;
      for effectIndex := 1 to 6 do
        FxEngine.RemoveEffect(GDVars.curChar, GDConsts.diseaseEffects[effectIndex], nil);
      FxEngine.RecalcAbility(GDVars.curChar, 0);
      GDVars.effectBusy := 0;
    end;
  end;
end;

{ Heals the current character for steel, once paid.
  @param(spell 1 Cure Light Wounds (50 steel, 1d8), 2 Cure Serious Wounds (175, 2d8 + 1), 3 Cure Critical Wounds (300,
    3d8 + 3), 4 Heal (2500: up to all but 1d4 hit points, with Blind, the disease effects and Feebleminded removed and
    abilities 1 and 2 recalculated).) }
procedure CureWounds(spell: Byte);
var
  { also the 1d4 roll in case 4 }
  healing: Byte;
  { case-4 loop counter }
  effectIndex: Byte;
  key: Char;
  { Unused in this version; see the other implementations of this routine. }
  restoreResult: Boolean;
begin
  case spell of
    1: begin
         key := Temple.ConfirmCureCost('Cure Light Wounds', 50);
         if key = 'Y' then begin
           healing := FxEngine.RollDice(1, 8);
           restoreResult := FxEngine.RestoreHitPoints(GDVars.curChar, healing, False);
         end;
       end;
    2: begin
         key := Temple.ConfirmCureCost('Cure Serious Wounds', 175);
         if key = 'Y' then begin
           healing := FxEngine.RollDice(2, 8) + 1;
           restoreResult := FxEngine.RestoreHitPoints(GDVars.curChar, healing, False);
         end;
       end;
    3: begin
         key := Temple.ConfirmCureCost('Cure Critical Wounds', 300);
         if key = 'Y' then begin
           healing := FxEngine.RollDice(3, 8) + 3;
           restoreResult := FxEngine.RestoreHitPoints(GDVars.curChar, healing, False);
         end;
       end;
    4: begin
         key := Temple.ConfirmCureCost('Heal', 2500);
         if key = 'Y' then begin
           healing := FxEngine.RollDice(1, 4);
           if GDVars.curChar^.hpCur + healing > GDVars.curChar^.hpMax then
             healing := 0
           else
             healing := GDVars.curChar^.hpMax - GDVars.curChar^.hpCur - healing;
           restoreResult := FxEngine.RestoreHitPoints(GDVars.curChar, healing, False);
           FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
           for effectIndex := 1 to 6 do
             FxEngine.RemoveEffect(GDVars.curChar, GDConsts.diseaseEffects[effectIndex], nil);
           FxEngine.RemoveEffect(GDVars.curChar, C_Effect.FEEBLEMINDED, nil);
           FxEngine.RecalcAbility(GDVars.curChar, 1);
           FxEngine.RecalcAbility(GDVars.curChar, 2);
         end;
       end;
  end;
end;

{ Raise Dead for 2750 steel (asks first when the character is not dead or is a Silvanesti or Qualinesti elf, and then
  changes nothing): a dead or animated character comes back okay at 1 hit point, with Animate Dead and poison removed
  under the effect lock, and loses a point of Constitution. At Constitution 14 and up, its hit points above the rolled
  ones are divided by its Constitution hit-point bonus over its class levels (undivided when that bonus is 0), and the
  result comes off its maximum when its Constitution is below 17 or it has fighter levels. Note: a third test, the
  fighter level against dualClassThreshold, adds no case to the fighter test. }
procedure RaiseDead;
var
  { Unused in this version; see the other implementations of this routine. }
  effectNode: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  messageText: String;
  key: Char;
  wasDead: Boolean;
  hpLoss: Byte;
  hpBonus: Byte;
  classIndex: ShortInt;
  character: Types.PCharRecord;
  cannotRaise: Boolean;
begin
  character := GDVars.curChar;
  wasDead := False;
  cannotRaise := False;
  messageText := '';
  key := 'Y';
  if (character^.status = C_Status.DEAD_STATUS) or (character^.status = C_Status.ANIMATED) then
    wasDead := True;
  if character^.race < C_Race.HALF_ELF then
    cannotRaise := True;
  if (not wasDead) or cannotRaise then
    if cannotRaise then
      key := Temple.ConfirmCureAnyway('cannot be raised')
    else
      key := Temple.ConfirmCureAnyway('is not dead.');
  if key = 'Y' then begin
    key := Temple.ConfirmCureCost('Raise Dead', 2750);
    if key = 'Y' then begin
      if wasDead then
        if not cannotRaise then begin
          GDVars.effectBusy := 1;
          FxEngine.RemoveEffect(character, C_Effect.ANIMATED, nil);
          FxEngine.RemoveEffect(character, C_Effect.POISONED, nil);
          GDVars.effectBusy := 0;
          character^.hpCur := 1;
          character^.status := C_Status.OKAY;
          character^.inPlay := 1;
          if character^.stats[C_Stat.CONSTITUTION].cur > 0 then
            Dec(character^.stats[C_Stat.CONSTITUTION].cur);
          if character^.hpMax > character^.hpRolled then
            hpLoss := character^.hpMax - character^.hpRolled
          else
            hpLoss := 0;
          hpBonus := 0;
          if character^.stats[C_Stat.CONSTITUTION].cur >= 14 then begin
            for classIndex := 0 to 7 do
              if character^.classLevels[classIndex] > 0 then begin
                if classIndex = C_Class.FIGHTER then
                  Inc(hpBonus, (character^.stats[C_Stat.CONSTITUTION].cur - 14) * character^.classLevels[classIndex])
                else if character^.stats[C_Stat.CONSTITUTION].cur > 15 then
                  Inc(hpBonus, character^.classLevels[classIndex] * 2)
                else
                  Inc(hpBonus, character^.classLevels[classIndex]);
              end;
            if hpBonus > 0 then
              hpLoss := hpLoss div hpBonus;
            if (character^.stats[C_Stat.CONSTITUTION].cur < 17) or (character^.classLevels[C_Class.FIGHTER] > 0)
               or (character^.classLevels[C_Class.FIGHTER] > character^.dualClassThreshold) then
              Dec(character^.hpMax, hpLoss);
          end;
        end;
    end;
  end;
end;

{ Neutralize Poison for 500 steel: a poisoned character loses Poisoned, Slow Poison and the poison damage effect under
  the effect lock, comes back into play okay, and has at least 1 hit point; asks first when the character is not
  poisoned, and then changes nothing. }
procedure NeutralizePoison;
var
  effectNode: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  messageText: String;
  key: Char;
  found: Boolean;
begin
  found := False;
  messageText := '';
  key := 'Y';
  if CharHlp.HasEffect(GDVars.curChar, C_Effect.POISONED, effectNode) then
    found := True;
  if not found then
    key := Temple.ConfirmCureAnyway('is not poisoned.');
  if key = 'Y' then begin
    key := Temple.ConfirmCureCost('Neutralize Poison', 500);
    if key = 'Y' then
      if found then begin
        if GDVars.curChar^.hpCur = 0 then
          GDVars.curChar^.hpCur := 1;
        GDVars.effectBusy := 1;
        FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISONED, nil);
        FxEngine.RemoveEffect(GDVars.curChar, C_Effect.SLOW_POISON, nil);
        FxEngine.RemoveEffect(GDVars.curChar, C_Effect.POISON_DAMAGE, nil);
        GDVars.effectBusy := 0;
        GDVars.curChar^.inPlay := 1;
        GDVars.curChar^.status := C_Status.OKAY;
      end;
  end;
end;

{ Remove Curse for 1750 steel: casts the spell (Magic.SpellRemoveCurse) on the current character; asks first when it has
  neither a cursed item nor the Cursed effect. }
procedure RemoveCurse;
var
  cursed: Boolean;
  { inventory node }
  item: Types.PItemRec;
  effectNode: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  messageText: String;
  key: Char;
begin
  messageText := '';
  key := 'Y';
  cursed := False;
  item := GDVars.curChar^.itemsAddr;
  while (item <> nil) and (not cursed) do begin
    if item^.cursed <> 0 then
      cursed := True;
    item := item^.next;
  end;
  if not cursed then
    if not CharHlp.HasEffect(GDVars.curChar, C_Effect.CURSED, effectNode) then
      key := Temple.ConfirmCureAnyway('is not cursed.');
  if key = 'Y' then begin
    key := Temple.ConfirmCureCost('Remove Curse', 1750);
    if key = 'Y' then begin
      GDVars.spellTargets[1] := GDVars.curChar;
      Magic.SpellRemoveCurse;
    end;
  end;
end;

{ Stone to Flesh for 1000 steel: a stoned character comes back into play okay at 1 hit point; asks first otherwise. }
procedure StoneToFlesh;
var
  { Unused in this version; see the other implementations of this routine. }
  effectNode: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  messageText: String;
  key: Char;
begin
  messageText := '';
  key := 'Y';
  if GDVars.curChar^.status <> C_Status.STONED then
    key := Temple.ConfirmCureAnyway('is not stoned.');
  if key = 'Y' then begin
    key := Temple.ConfirmCureCost('Stone to Flesh', 1000);
    if key = 'Y' then
      if GDVars.curChar^.status = C_Status.STONED then begin
        GDVars.curChar^.status := C_Status.OKAY;
        GDVars.curChar^.inPlay := 1;
        GDVars.curChar^.hpCur := 1;
      end;
  end;
end;

{ Lists the temple's ten healing services and runs the chosen one (Heal or Enter) for the current character until the
  player leaves, then redraws the party display. }
procedure HealMenu;
var
  { menu string-list node }
  listHead: Types.PItemRec;
  selection: Types.PItemRec;
  menuRedraw: Boolean;
  spellIndex: Byte;
  selectionIndex: Integer;
  done: Boolean;
  messageText: String[40];
  key: Char;
begin
  done := False;
  listHead := nil;
  selection := nil;
  MenuCore.AllocStringList(10, listHead);
  selection := listHead;
  spellIndex := 1;
  while listHead <> nil do begin
    listHead^.name := GDConsts.templeMenuItems[spellIndex];
    listHead^.inUse := 0;
    listHead := listHead^.next;
    Inc(spellIndex);
  end;
  listHead := selection;
  TextRend.ClearRect(0, 24, 39, 24);
  menuRedraw := True;
  Border.DrawRowDivider;
  repeat
    messageText := GDVars.curChar^.name + ', how can we help you?';
    TextRend.displayString(1, 1, White, Black, messageText);
    key := MenuCore.MenuVertical('', 'Heal Exit', LightMagenta, LightGreen, White, 2, 4, 38, 15, listHead, False,
                                 menuRedraw, selectionIndex, selection);
    case key of
      'H', C_Keys.ENTER:
        case selectionIndex of
          0: Temple.CureBlindness;
          1: Temple.CureDisease;
          2: Temple.CureWounds(1);
          3: Temple.CureWounds(2);
          4: Temple.CureWounds(3);
          5: Temple.CureWounds(4);
          6: Temple.NeutralizePoison;
          7: Temple.RaiseDead;
          8: Temple.RemoveCurse;
          9: Temple.StoneToFlesh;
          10: done := True;
        end;
      C_Keys.NONE: done := True;
    end;
  until done;
  MenuCore.FreeStringList(listHead);
  CharHlp.DisplayNoncombatInterface;
  CharHlp.DisplayParty(GDVars.curChar);
end;

procedure TempleMainMenu;
var
  key: Char;
  done: Boolean;
  extendedKey: Boolean;
  menu: String[40];
  hasMoney: Boolean;
  hasItems: Boolean;
  yesNoIndex: Byte;
  appraisalAccepted: Boolean;
begin
  GDVars.interfaceState := C_Ifc.SHOP_TEMPLE;
  GDVars.drawFlag := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.drawFlag := 1;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  GDVars.treasureMoneyFlag := False;
  done := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := 'Heal View Take Pool Share Appraise Exit'
    else
      menu := 'Heal View Pool Appraise Exit';
    key := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, extendedKey);
    case key of
      'H': if not extendedKey then Temple.HealMenu
           else ViewChar.SelectPrevNextChar(key);
      'V': ViewChar.ViewCharMenu(extendedKey);
      'T': Money.TakeMoneyMenu;
      'P': if not extendedKey then Money.PoolMoney
           else ViewChar.SelectPrevNextChar(key);
      'S': Money.ShareMoney;
      'A': Money.AppraiseMenu(appraisalAccepted);
      'E': begin
             Money.DetermineTreasure(hasMoney, hasItems);
             if hasMoney then begin
               menu := '~Yes ~No';
               TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True,
'As you leave a priest says, "Excuse me but you have left some money here" ');
               TextRend.displayMessageWindow(1, 17, 38, 22, LightGreen, Black, True,
                                             'Do you want to go back and retrieve your money?');
               yesNoIndex := EclMenu.MenuHorizontalCharacterSelect('', menu, LightMagenta, LightGreen, White, False,
                                                                   False);
               if yesNoIndex = 1 then
                 done := True
               else
                 TextRend.ClearRect(1, 17, 38, 22);
             end else
               done := True;
           end;
    end;
    case key of
      'B', 'T': CharHlp.DisplayNoncombatInterface;
      'A': if appraisalAccepted then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until done;
end;

begin
end.
