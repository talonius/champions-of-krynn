{ Money, treasure and random items.

  The coins are, by index: 0 Silver, 1 Copper, 2 Bronze, 3 Platinum, 4 Steel, 5 Gems, 6 Jewelry. Steel is the currency
  of record, so CoinValueInSteel divides by coinValue[4] and SetCreatureCoinsInSteel stores into coinsA[4]; the
  appraisal message reads "The Gem is Valued at N steel." for the same reason.

  GDConsts.randomItemTable holds seven 8-word random-item rows, indexed from 1: a row is read as [flag..flag+2] names,
  [flag+3] weight, [flag+4] value and [flag+5..flag+7] spells, where flag is 1 + 8 * row. }
{$O+,F+}
unit Money;

interface

uses Types, TextRend, Border, GameIo, FxEngine, CharHlp, MenuCore, Debug, GDConsts, GDVars, C_Keys, Crt,
  C_Ifc, C_Screen, C_Npc;

{ Gives the most weight a character can carry: its weight allowance plus 1500.
  @param(p The character.)
  @returns(The capacity.) }
function CarryingCapacity(p: Types.PCharRecord): Word;

{ Takes weight off a character's encumbrance.
  @param(p The character.)
  @param(w The weight removed.) }
procedure RemoveWeight(p: Types.PCharRecord; w: Word);

{ Adds weight to a character's encumbrance.
  @param(p The character.)
  @param(w The weight added.) }
procedure AddWeight(p: Types.PCharRecord; w: Word);

{ Tells whether more weight would overload a character.
  @param(p Character to test.)
  @param(w Weight to add.)
  @param(takable Receives what it can still take when it would be overloaded (0 if already over), otherwise 0.)
  @returns(True when the weight would overload it.) }
function CheckOverload(p: Types.PCharRecord; w: Word; var takable: Word): Boolean;

{ Moves the money of each player character, and of each NPC with the value $B3, into the pool, taking its weight off,
  and marks the pool as holding money. }
procedure PoolMoney;

{ Counts the party members and animated creatures (NPC value 0 or $B3).
  @returns(The count.) }
function CountPoolers: Byte;

{ Divides the pool. Each money type's share is the pool divided by CountPoolers, the remainder held back. The first pass
  gives each member with an NPC value below $80, highest money type first, its share and one coin of the remainder while
  they fit, or as much of the share as it can carry, the rest going back to the remainder. The second pass hands what is
  left, type by type, to each member in list order as far as it can carry, and the rest stays in the pool, which is
  marked as holding money when anything stays. Note: the divisor counts animated members ($B3), whom the first pass
  skips, and not NPC values 1 to $7F, whom it pays. }
procedure ShareMoney;

{ Lists the money in the pool and lets the current character take an amount of the chosen type, until the pool is empty
  or the player leaves. Note: leaving the menu without choosing does not free the list it was built from. }
procedure TakeMoneyMenu;

{ Gives the current character steel pieces; what it cannot carry goes into the pool, after a pause and a message saying
  so.
  @param(pp The amount of steel.) }
procedure GiveSteel(pp: Word);

{ Reads the money type named by the first non-space letter of a menu entry: G gems, P platinum, B bronze, S followed by
  I silver and S otherwise steel, C copper, J jewelry. Note: another letter leaves the result undefined.
  @param(s The menu entry.)
  @param(typeName Receives the type's name and a trailing space.)
  @returns(The money type.) }
function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ Shows a question on the bottom row and reads a number up to the largest accepted: digits are echoed in white, a larger
  number is cut to the largest, and backspace takes off the last digit. Enter or Escape ends the input. Note: backspace
  blanks the column after the last digit, so the digit taken off stays on screen.
  @param(max The largest number accepted.)
  @param(query The question shown.)
  @param(color The question's color.)
  @returns(The number, or 0 on Escape.) }
function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;

{ Moves coins of one type, with their weight, from one character to another when the receiver can carry them; otherwise
  shows "Overloaded", pauses and flushes the keyboard.
  @param(giver The character giving the coins.)
  @param(rcv The character receiving them.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);

{ Drops coins of one type from a character. In a shop, temple or loot menu they go to the pooled money; elsewhere they
  are lost.
  @param(p The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);

{ Tells what treasure is left.
  @param(hasMoney Set True when any pool slot is not 0, else False.)
  @param(items Set True when the treasure item list is not empty, else False.) }
procedure DetermineTreasure(var hasMoney, items: Boolean);

{ Replaces the current character's coins with an amount of steel; gems and jewelry are kept.
  @param(gp The amount of steel.) }
procedure SetCreatureCoinsInSteel(gp: Word);

{ Replaces the pool's coins with an amount of steel; gems and jewelry are kept.
  @param(gp The amount of steel.) }
procedure SetTreasureCoinsInSteel(gp: Word);

{ Works out what a set of coins is worth in steel, leaving out gems and jewelry.
  @param(m The money.)
  @returns(The value in whole steel pieces.) }
function CoinValueInSteel(m: Types.TMoney): LongInt;

{ Fills an item record with a random item of a kind. Weapons and armor (1..37, 50, 59, 70, 71) get a RandomBonus plus
  (kind 50 always +4) with their name, weight and value, which rises with the plus; a long sword has a one-in-five
  chance of being the random-item table's special sword instead. Kinds 39 and 40 are scrolls of 1..3 random spells of
  levels 1..4, kind 39 from one of two magic lists and kind 40 from the cleric list, worth 150 a spell level. Kinds 48,
  52 and 53 copy a row of the random-item table.
  @param(kind The item kind.)
  @param(it Receives the item.) }
procedure GenerateRandomItem(kind: Byte; var it: Types.TItemRec);

{ Appraises the current character's gems and jewelry one at a time: each gets a random value and is sold for its full
  value in steel, or, when the character has room and fewer than 16 items, kept as an item. Note: a kept gem or jewel is
  linked to the end of the item list without counting it or adding its weight, it is lost when the character carries no
  items, and leaving the Sell/Keep menu sells.
  @param(ok Set False when there is nothing to appraise, else True.) }
procedure AppraiseMenu(var ok: Boolean);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeMoney;

implementation

type
  { Low/high word view of the pooled LongInt slots; the two clamp sites read only the low word. }
  TLoW = record lo: Word; hi: Word end;
  TMoneyW = array[0..6] of TLoW;

  { Low/high byte view of a random-item table word. }
  TWB = record lo: Byte; hi: Byte end;

procedure PrimeMoney;
begin
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  FxEngine.PrimeFxEngine;
  Debug.PrimeDebug;
end;

function CarryingCapacity(p: Types.PCharRecord): Word;
begin
  CarryingCapacity := CharHlp.WeightAllowance(p) + 1500;
end;

procedure RemoveWeight(p: Types.PCharRecord; w: Word);
begin
  p^.encumbrance := p^.encumbrance - w;
end;

procedure AddWeight(p: Types.PCharRecord; w: Word);
begin
  p^.encumbrance := p^.encumbrance + w;
end;

function CheckOverload(p: Types.PCharRecord; w: Word; var takable: Word): Boolean;
var
  cap: Word;
begin
  cap := Money.CarryingCapacity(Types.PCharRecord(p));
  if Types.PCharRecord(p)^.encumbrance + w > cap then begin
    CheckOverload := True;
    if Types.PCharRecord(p)^.encumbrance > cap then
      takable := 0
    else
      takable := cap - Types.PCharRecord(p)^.encumbrance;
  end else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

function CoinValueInSteel(m: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := 0 to 4 do
    Inc(total, GDConsts.coinValue[i] * m[i]);
  CoinValueInSteel := total div GDConsts.coinValue[4];
end;

procedure SetCreatureCoinsInSteel(gp: Word);
var
  i: ShortInt;
begin
  for i := 0 to 4 do
    GDVars.curChar^.coinsA[i] := 0;
  GDVars.curChar^.coinsA[4] := gp;
end;

procedure SetTreasureCoinsInSteel(gp: Word);
var
  i: ShortInt;
begin
  for i := 0 to 4 do
    GDVars.treasureMoney[i] := 0;
  GDVars.treasureMoney[4] := gp;
end;

procedure GiveSteel(pp: Word);
var
  takable: Word;
begin
  if Money.CheckOverload(Types.PCharRecord(GDVars.curChar), pp, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    TextRend.pauseOnly;
    GameIo.FlushKeys;
    Inc(GDVars.curChar^.coinsA[4], takable);
    Money.AddWeight(GDVars.curChar, takable);
    GDVars.treasureMoney[4] := pp + GDVars.treasureMoney[4] - takable;
  end else begin
    Inc(GDVars.curChar^.coinsA[4], pp);
    Money.AddWeight(GDVars.curChar, pp);
  end;
end;

function InputNumberMax(max: Word; query: Types.TStr40; color: Byte): Word;
var
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  maxLen: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: Word;
begin
  TextRend.printSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
  TextRend.displayString(0, C_Screen.PROMPT_ROW, color, Black, query);
  qLen := Length(query);
  col := qLen;
  Str(max, maxStr);
  s := '';
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      '0'..'9': begin
          s := Concat(s, ch);
          Val(s, v, code);
          if max >= v then
            Inc(col)
          else begin
            s := maxStr;
            col := qLen + Length(maxStr);
          end;
          TextRend.displayString(qLen, C_Screen.PROMPT_ROW, White, Black, s);
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          TextRend.printSpaces(col, C_Screen.PROMPT_ROW, Black, 1);
          Dec(col);
        end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESCAPE);
  TextRend.printSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
  if ch = C_Keys.ESCAPE then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  if Types.PCharRecord(rcv)^.encumbrance + qty <= Money.CarryingCapacity(Types.PCharRecord(rcv)) then begin
    Types.PCharRecord(giver)^.coinsA[mType] := Types.PCharRecord(giver)^.coinsA[mType] - qty;
    Money.RemoveWeight(Types.PCharRecord(giver), qty);
    Types.PCharRecord(rcv)^.coinsA[mType] := Types.PCharRecord(rcv)^.coinsA[mType] + qty;
    Money.AddWeight(Types.PCharRecord(rcv), qty);
  end else begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.pauseOnly;
    GameIo.FlushKeys;
  end;
end;

procedure PoolMoney;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  i: ShortInt;
  mt: ShortInt;
begin
  p := GDVars.partyHead;
  GDVars.treasureMoneyFlag := True;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = $B3) then begin
      for mt := 0 to 6 do begin
        GDVars.treasureMoney[mt] := p^.coinsA[mt] + GDVars.treasureMoney[mt];
        Money.RemoveWeight(p, p^.coinsA[mt]);
      end;
      FillChar(p^.coinsA, SizeOf(p^.coinsA), 0);
    end;
    p := p^.next;
  end;
end;

function CountPoolers: Byte;
var
  p: Types.PCharRecord;
  n: Byte;
begin
  p := GDVars.partyHead;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = $B3) then
      Inc(n);
    p := p^.next;
  end;
  CountPoolers := n;
end;

procedure ShareMoney;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  receiver: Types.PCharRecord;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  takable: Word;
  share: array[0..6] of Word;
  rem: array[0..6] of Word;
  i: ShortInt;
begin
  p := GDVars.partyHead;
  done := False;
  cnt := Money.CountPoolers;
  FillChar(share, SizeOf(share), 0);
  FillChar(rem, SizeOf(rem), 0);
  for i := 0 to 6 do
    if GDVars.treasureMoney[i] > 0 then begin
      share[i] := GDVars.treasureMoney[i] div cnt;
      rem[i] := GDVars.treasureMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  while p <> nil do begin
    if p^.npc < C_Npc.NON_PLAYER then
      for i := 6 downto 0 do
        if not Money.CheckOverload(Types.PCharRecord(p), share[i], takable) then begin
          p^.coinsA[i] := share[i] + p^.coinsA[i];
          Money.AddWeight(p, share[i]);
          if rem[i] > 0 then
            if not Money.CheckOverload(Types.PCharRecord(p), 1, takable) then begin
              p^.coinsA[i] := p^.coinsA[i] + 1;
              Money.AddWeight(p, 1);
              Dec(rem[i]);
            end;
        end else begin
          p^.coinsA[i] := p^.coinsA[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          Money.AddWeight(p, takable);
        end;
    p := p^.next;
  end;
  for i := 6 downto 0 do
    if rem[i] > 0 then begin
      p := GDVars.partyHead;
      while p <> nil do begin
        takable := Money.CarryingCapacity(p) - p^.encumbrance;
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coinsA[i] := p^.coinsA[i] + takable;
            Money.AddWeight(p, takable);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coinsA[i] := p^.coinsA[i] + rem[i];
            Money.AddWeight(p, rem[i]);
            rem[i] := 0;
          end;
        p := p^.next;
      end;
    end;
  GDVars.treasureMoneyFlag := False;
  for i := 0 to 6 do begin
    GDVars.treasureMoney[i] := rem[i];
    if GDVars.treasureMoney[i] <> 0 then
      GDVars.treasureMoneyFlag := True;
  end;
end;

procedure DropMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
begin
  Types.PCharRecord(p)^.coinsA[mType] := Types.PCharRecord(p)^.coinsA[mType] - qty;
  Money.RemoveWeight(Types.PCharRecord(p), qty);
  if (GDVars.interfaceState = C_Ifc.LOOT) or (GDVars.interfaceState = C_Ifc.SHOP_TEMPLE) then
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] + qty;
end;

{ Moves money from the pool to a character, at most what the pool holds; an amount that would overload the character is
  refused whole: "Overloaded" is shown, the game pauses and the keyboard is flushed. Note: the overload test uses the
  amount asked for, before it is cut down to what the pool holds.
  @param(p The character.)
  @param(qty The amount asked for.)
  @param(mType The money type.) }
procedure TakeMoney(p: Types.PCharRecord; qty: Word; mType: ShortInt);
var
  takable: Word;
begin
  if Money.CheckOverload(p, qty, takable) then begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.pauseOnly;
    GameIo.FlushKeys;
  end else begin
    if qty > GDVars.treasureMoney[mType] then
      qty := TMoneyW(GDVars.treasureMoney)[mType].lo;
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] - qty;
    Types.PCharRecord(p)^.coinsA[mType] := Types.PCharRecord(p)^.coinsA[mType] + qty;
    Money.AddWeight(Types.PCharRecord(p), qty);
  end;
end;

function ParseMoneyType(s: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  i := 1;
  while s[i] = ' ' do
    Inc(i);
  case s[i] of
    'G': begin
           ParseMoneyType := 5;
           typeName := 'Gems ';
         end;
    'P': begin
           typeName := 'platinum ';
           ParseMoneyType := 3;
         end;
    'B': begin
           typeName := 'bronze ';
           ParseMoneyType := 2;
         end;
    'S': if UpCase(s[i + 1]) = 'I' then
         begin
           typeName := 'silver ';
           ParseMoneyType := 0;
         end else begin
           typeName := 'steel ';
           ParseMoneyType := 4;
         end;
    'C': begin
           typeName := 'Copper ';
           ParseMoneyType := 1;
         end;
    'J': begin
           typeName := 'Jewelry ';
           ParseMoneyType := 6;
         end;
  end;
end;

procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  save: Types.PItemRec;
  { unused }
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindowFrame(False);
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := 0 to 6 do
      if GDVars.treasureMoney[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TCharacterListNode));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TCharacterListNode));
          p^.next := sel;
        end;
        Str(GDVars.treasureMoney[i], numStr);
        p^.name := GDConsts.moneyNames[i] + ' ' + numStr;
        p^.inUse := 0;
      end;
    sel := p;
    save := p;
    ch := MenuCore.MenuVertical('Select type of coin ', 'Select', LightMagenta, LightGreen, White, 2, 2, 15, 8, p, True,
                                redraw, idx, sel);
    if (sel = nil) or (ch = C_Keys.NONE) then
      exitF := True
    else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      if mType = 5 then
        numStr := 'How Many ' + numStr + ' will you take? '
      else
        numStr := 'How much ' + numStr + ' will you take? ';
      n := Money.InputNumberMax(TMoneyW(GDVars.treasureMoney)[mType].lo, numStr, LightGreen);
      Money.TakeMoney(Types.PCharRecord(GDVars.curChar), n, mType);
      MenuCore.FreeStringList(save);
      GDVars.treasureMoneyFlag := False;
      exitF := True;
      for i := 0 to 6 do
        if GDVars.treasureMoney[i] > 0 then begin
          GDVars.treasureMoneyFlag := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

procedure DetermineTreasure(var hasMoney, items: Boolean);
var
  i: ShortInt;
begin
  hasMoney := False;
  items := False;
  for i := 0 to 6 do
    if GDVars.treasureMoney[i] <> 0 then
      hasMoney := True;
  if GDVars.treasureItems <> nil then
    items := True;
end;

{ Rolls a random weapon or armor bonus.
  @returns(1 on a d10 roll of 1..9, 2 on 10.) }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := FxEngine.RollDice(1, 10);
  case r of
    1..9: RandomBonus := 1;
    10: RandomBonus := 2;
  end;
end;

procedure GenerateRandomItem(kind: Byte; var it: Types.TItemRec);
var
  r: Byte;
  n: Byte;
  j: Byte;
  flag: Byte;
  spell: Byte;
  { which list of GDConsts.knownSpellTable }
  book: Byte;
begin
  FillChar(it, SizeOf(it), 0);
  flag := 0;
  with it do begin
    FillChar(spells, SizeOf(spells), 0);
    next := nil;
    equipped := 0;
    unidMask := $06;
    cursed := 0;
    itemType := kind;
    FillChar(nameIds, SizeOf(nameIds), 0);
    case itemType of
      1..37, 50, 70, 71, 59: begin
          plus := Money.RandomBonus;
          case itemType of
            { long sword: 20% from the table }
            7: begin
                 r := FxEngine.RollDice(1, 5);
                 if r = 5 then
                   flag := $31;
                 nameIds[3] := 7;
                 nameIds[2] := plus + 110;
               end;
            12: begin
                 nameIds[3] := 12;
                 nameIds[2] := plus + 110;
               end;
            31: begin
                 nameIds[3] := itemType;
                 nameIds[2] := 48;
                 nameIds[1] := plus + 110;
                 unidMask := $04;
               end;
            32..36: begin
                 nameIds[3] := itemType;
                 nameIds[2] := 47;
                 nameIds[1] := plus + 110;
                 unidMask := $04;
               end;
            30: begin
                 nameIds[3] := 30;
                 nameIds[2] := plus + 110;
               end;
            50: begin
                 nameIds[3] := 50;
                 nameIds[2] := 90;
                 plus := 4;
                 nameIds[1] := 107;
               end;
            59: begin
                 nameIds[3] := 46;
                 nameIds[2] := 49;
                 nameIds[1] := plus + 110;
               end;
            else begin
                 nameIds[3] := itemType;
                 nameIds[2] := plus + 110;
               end;
          end;
          saveBonus := 0;
          quantity := 0;
          { weight in coins }
          case itemType of
            1, 17:
              weight := 75;
            6, 14, 15, 23, 25, 37, 29, 67:
              weight := 50;
            9: weight := 125;
            8, 16, 24:
              weight := 100;
            70, 31:
              weight := 150;
            71: weight := 175;
            4, 50:
              weight := 10;
            5: begin
                 weight := 5;
                 quantity := 20;
               end;
            10, 18:
              weight := 60;
            22: weight := 80;
            7: weight := 20;
            13: weight := 40;
            19: weight := 35;
            20, 32:
              weight := 250;
            33: weight := 400;
            34: weight := 300;
            35: weight := 350;
            36: weight := 450;
            28, 59:
              weight := 1;
            else begin
                 weight := 4;
                 quantity := 20;
               end;
          end;
          { value in steel = plus * K }
          case itemType of
            37: value := plus * 1250;
            30: value := plus * 75;
            32, 33: value := plus * 1500;
            34: value := plus * 1750;
            35: value := plus * 2000;
            36: value := plus * 2500;
            50: value := plus * 1500;
            else value := plus * 1000;
          end;
        end;
      { scrolls }
      39, 40: begin
          unidMask := $04;
          n := FxEngine.RollDice(1, 3);
          if itemType = 39 then begin
            if FxEngine.RollDice(1, 2) = 1 then begin
              book := 3;
              nameIds[3] := 120;
              nameIds[2] := 40;
            end else begin
              book := 2;
              nameIds[3] := 119;
              nameIds[2] := 40;
            end;
          end else begin
            book := 0;
            nameIds[3] := 38;
            nameIds[2] := 39;
          end;
          nameIds[1] := n + 99;
          plus := 1;
          weight := 25;
          quantity := 0;
          for j := 1 to n do begin
            r := FxEngine.RollDice(1, 4);
            if itemType = 39 then
              case r of
                1: if book = 2 then
                     spell := GDConsts.knownSpellTable[2, 1, FxEngine.RollDice(1, 8)]
                   else
                     spell := GDConsts.knownSpellTable[3, 1, FxEngine.RollDice(1, 7)];
                2: if book = 2 then
                     spell := GDConsts.knownSpellTable[2, 2, FxEngine.RollDice(1, 3)]
                   else
                     spell := GDConsts.knownSpellTable[3, 2, FxEngine.RollDice(1, 6)];
                3: if book = 2 then
                     spell := GDConsts.knownSpellTable[2, 3, FxEngine.RollDice(1, 6)]
                   else
                     spell := GDConsts.knownSpellTable[3, 3, FxEngine.RollDice(1, 6)];
                4: if book = 2 then
                     spell := GDConsts.knownSpellTable[2, 4, FxEngine.RollDice(1, 7)]
                   else
                     spell := GDConsts.knownSpellTable[3, 4, FxEngine.RollDice(1, 4)];
              end else
              case r of
                1: spell := GDConsts.knownSpellTable[1, 1, FxEngine.RollDice(1, 4)];
                2: spell := GDConsts.knownSpellTable[1, 2, FxEngine.RollDice(1, 7)];
                3: spell := GDConsts.knownSpellTable[1, 3, FxEngine.RollDice(1, 4)];
                4: spell := GDConsts.knownSpellTable[1, 4, FxEngine.RollDice(1, 4)];
              end;
            spells[j] := spell;
            value := r * 150 + value;
          end;
          case book of
            2: unidMask := unidMask or $20;
            3: unidMask := unidMask or $10;
          else
            unidMask := 0;
          end;
        end;
      52: flag := $21;
      53: flag := $09;
      48: begin
             r := FxEngine.RollDice(1, 8);
             case r of
               1..5: flag := $11;
               6..8: flag := $01;
             end;
           end;
    end;
    { a fixed row from the table }
    if flag <> 0 then begin
      for j := 0 to 2 do
        nameIds[j + 1] := TWB(GDConsts.randomItemTable[flag + j]).lo;
      plus := 1;
      saveBonus := 1;
      weight := GDConsts.randomItemTable[flag + 3];
      quantity := 0;
      value := GDConsts.randomItemTable[flag + 4];
      for j := 1 to 3 do
        spells[j] := TWB(GDConsts.randomItemTable[flag + 4 + j]).lo;
    end;
  end;
end;

procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  menu: String[40];
  actionStr: String[40];
  r: Byte;
  value: Word;
  takable: Word;
  p: Types.PItemRec;
  gem: Types.PItemRec;
  exitF: Boolean;
  ext: Boolean;
  mustSell: Boolean;
begin
  ok := True;
  if (GDVars.curChar^.coinsA[5] = 0) and (GDVars.curChar^.coinsA[6] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.curChar^.coinsA[5] = 0) and (GDVars.curChar^.coinsA[6] = 0) then
        exitF := True
      else begin
        exitF := False;
        Str(GDVars.curChar^.coinsA[5], gemStr);
        Str(GDVars.curChar^.coinsA[6], jwlStr);
        case GDVars.curChar^.coinsA[5] of
          0: gemStr := '';
          1: gemStr := gemStr + ' Gem';
        else
          gemStr := gemStr + ' Gems';
        end;
        case GDVars.curChar^.coinsA[6] of
          0: jwlStr := '';
          1: jwlStr := jwlStr + ' piece of Jewelry';
        else
          jwlStr := jwlStr + ' pieces of Jewelry';
        end;
        TextRend.ClearRect(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.displayString(1, 7, White, Black, 'You have a fine collection of:');
        TextRend.displayString(1, 9, White, Black, gemStr);
        TextRend.displayString(1, 10, White, Black, jwlStr);
        menu := '';
        if GDVars.curChar^.coinsA[5] <> 0 then
          menu := '  Gems';
        if GDVars.curChar^.coinsA[6] <> 0 then
          menu := menu + '  Jewelry';
        menu := menu + ' Exit';
        ch := MenuCore.MenuHorizontal('Appraise : ', menu, LightMagenta, LightGreen, White, True, False, ext);
        case ch of
          'G': if GDVars.curChar^.coinsA[5] <> 0 then
            begin
              Dec(GDVars.curChar^.coinsA[5]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: value := 5;
                26..50: value := 25;
                51..70: value := 50;
                71..90: value := 250;
                91..99: value := 500;
                100: value := 2500;
              end;
              Str(value, gemStr);
              gemStr := 'The Gem is Valued at ' + gemStr + ' steel.';
              TextRend.displayString(1, 12, White, Black, gemStr);
              if Money.CheckOverload(Types.PCharRecord(GDVars.curChar), 1, takable)
                 or (GDVars.curChar^.itemCount >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, True, False, ext);
              if (ch = 'K') and (not mustSell) then
              begin
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(gem^), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 122;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 47;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  { Note: the item is lost }
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else
                Money.GiveSteel(value);
            end;
          'J': if GDVars.curChar^.coinsA[6] <> 0 then
            begin
              Dec(GDVars.curChar^.coinsA[6]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: value := Trunc(Random(450)) + 50;
                11..20: value := Trunc(Random(500)) + 100;
                21..40: value := Trunc(Random(750)) + 150;
                41..50: value := Trunc(Random(1250)) + 250;
                51..70: value := Trunc(Random(2500)) + 500;
                71..90: value := Trunc(Random(3000)) + 1000;
                91..100: value := Trunc(Random(5000)) + 1000;
              end;
              Str(value, jwlStr);
              gemStr := 'The Jewel is Valued at ' + jwlStr + ' steel.';
              TextRend.displayString(1, 12, White, Black, gemStr);
              if Money.CheckOverload(Types.PCharRecord(GDVars.curChar), 1, takable)
                 or (GDVars.curChar^.itemCount >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, True, False, ext);
              if (ch = 'K') and (not mustSell) then
              begin
                GetMem(gem, SizeOf(Types.TItemRec));
                FillChar(gem^, SizeOf(gem^), 0);
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 123;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 47;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  { Note: the item is lost }
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else
                Money.GiveSteel(value);
            end;
          'E', C_Keys.NONE:
            exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

begin
end.
