{ Merchant and shop interface: buying, viewing characters, money handling and appraisal. }
{$O+,F+}
unit Shop;

interface

uses Types, TextRend, Border, EclMenu, ViewChar, Money, CharHlp, MenuCore, Debug, Crt, GDConsts, GDVars,
  C_Keys, C_Ifc;

{ Runs a shop: the money pool starts empty and the shop's goods are the treasure item list. The menu offers Buy, View,
  Pool and Appraise, plus Take and Share while the pool holds money; the up and down arrow keys change the current
  character; leaving with money in the pool asks first. }
procedure ShopMainMenu;

{ Gives the current character a copy of an item at the end of its items and recalculates its stats, unless it cannot
  carry the item, which reports the character as overloaded.
  @param(item The item to copy.)
  @param(failed Set True when the item was refused, else False.) }
procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeShop;

implementation

const
  PRICE_DIV_16 = 1;
  PRICE_DIV_8 = 2;
  PRICE_DIV_4 = 4;
  PRICE_DIV_2 = 8;
  PRICE_BASE = 16;
  PRICE_MUL_2 = 32;
  PRICE_MUL_4 = 64;
  PRICE_MUL_8 = 128;

procedure PrimeShop;
begin
  Money.PrimeMoney;
  ViewChar.PrimeViewChar;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  EclMenu.PrimeEclMenu;
  Debug.PrimeDebug;
end;

{ Lists the shop's items with their prices in a vertical Buy menu, then rebuilds the item names. The price is the value
  scaled by the zone's price level, and a level outside the seven scaling values keeps the value; an item whose value is
  0 is given the value 1.
  @param(key Receives the key pressed.)
  @param(itemToBuy Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(selectionIndex The highlighted item's position, kept between calls.) }
procedure ShopBuyItemSelection(var key: Char; var itemToBuy: Types.PItemRec; var cursor: Types.PItemRec;
                               var selectionIndex: Integer);
var
  listHead: Types.PItemRec;
  item: Types.PItemRec;
  priceText: String[16];
  menuLine: String[30];
  textLength: Byte;
  charIndex: Byte;
begin
  item := GDVars.treasureItems;
  while item <> nil do begin
    menuLine := '                              ';
    if item^.value = 0 then item^.value := 1;
    case GDVars.zone1^.priceLevel of
      Shop.PRICE_DIV_16: Str(item^.value div 16, priceText);
      Shop.PRICE_DIV_8: Str(item^.value div 8, priceText);
      Shop.PRICE_DIV_4: Str(item^.value div 4, priceText);
      Shop.PRICE_DIV_2: Str(item^.value div 2, priceText);
      Shop.PRICE_MUL_2: Str(item^.value * 2, priceText);
      Shop.PRICE_MUL_4: Str(item^.value * 4, priceText);
      Shop.PRICE_MUL_8: Str(item^.value * 8, priceText);
    else
      Str(item^.value, priceText);
    end;
    textLength := Length(priceText);
    for charIndex := 1 to textLength do
      menuLine[30 - textLength + charIndex] := priceText[charIndex];
    textLength := Length(item^.name);
    for charIndex := 1 to textLength do
      menuLine[charIndex] := item^.name[charIndex];
    item^.name := menuLine;
    item^.name[0] := #30;
    item := item^.next;
  end;
  listHead := Types.PItemRec(GDVars.treasureItems);
  GDVars.horizontalChoice := 0;
  key := MenuCore.MenuVertical('Items: ', 'Buy', LightMagenta, LightGreen, White, 1, 1, 38, 22, listHead, True,
                               GDVars.menuRedraw, selectionIndex, cursor);
  itemToBuy := Types.PItemRec(cursor);
  item := GDVars.treasureItems;
  while item <> nil do begin
    CharHlp.PrintItemString(nil, item, 0, 0, False, False);
    item := item^.next;
  end;
end;

procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);
var
  tail: Types.PItemRec;
  newItem: Types.PItemRec;
begin
  if ViewChar.CannotCarryItem(GDVars.curChar, item) then begin
    CharHlp.PrintBottomLine('OverLoaded');
    failed := True;
  end else begin
    failed := False;
    tail := GDVars.curChar^.itemsAddr;
    if tail = nil then begin
      GetMem(tail, SizeOf(Types.TItemRec));
      tail^ := item^;
      tail^.next := nil;
      GDVars.curChar^.itemsAddr := tail;
    end else begin
      while tail^.next <> nil do
        tail := tail^.next;
      GetMem(newItem, SizeOf(Types.TItemRec));
      newItem^ := item^;
      newItem^.next := nil;
      tail^.next := newItem;
    end;
    CharHlp.RecalcStats(GDVars.curChar);
  end;
end;

{ Buys items until the player leaves the Buy menu: the scaled price is paid from the current character's coins when they
  suffice, else from the pool ("Not enough Money." otherwise), the change coming back as steel, and the purchase is
  announced. Note: unlike the listing, a price level outside the eight named ones leaves the price unset. }
procedure ShopBuyMenu;
var
  itemToBuy: Types.PItemRec;
  key: Char;
  done: Boolean;
  price: Word;
  characterGold: Word;
  pooledGold: LongInt;
  failed: Boolean;
  cursor: Types.PItemRec;
  selectionIndex: Integer;
begin
  itemToBuy := nil;
  cursor := Types.PItemRec(GDVars.treasureItems);
  selectionIndex := 0;
  Border.DrawWindowFrame(True);
  GDVars.menuRedraw := True;
  repeat
    Shop.ShopBuyItemSelection(key, itemToBuy, cursor, selectionIndex);
    if (key <> 'B') and (key <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      case GDVars.zone1^.priceLevel of
        Shop.PRICE_DIV_16: price := itemToBuy^.value div 16;
        Shop.PRICE_DIV_8: price := itemToBuy^.value div 8;
        Shop.PRICE_DIV_4: price := itemToBuy^.value div 4;
        Shop.PRICE_DIV_2: price := itemToBuy^.value div 2;
        Shop.PRICE_BASE: price := itemToBuy^.value;
        Shop.PRICE_MUL_2: price := itemToBuy^.value * 2;
        Shop.PRICE_MUL_4: price := itemToBuy^.value * 4;
        Shop.PRICE_MUL_8: price := itemToBuy^.value * 8;
      end;
      characterGold := ViewChar.CreatureCoinValueInSteel(GDVars.curChar);
      if price <= characterGold then begin
        Shop.GiveItemCopyToCreature(itemToBuy, failed);
        if not failed then begin
          characterGold := characterGold - price;
          Money.SetCreatureCoinsInSteel(characterGold);
          if itemToBuy^.quantity > 0 then
            CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys ' + itemToBuy^.name)
          else
            CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys a ' + itemToBuy^.name);
        end;
      end else begin
        pooledGold := Money.CoinValueInSteel(GDVars.treasureMoney);
        if price <= pooledGold then begin
          Shop.GiveItemCopyToCreature(itemToBuy, failed);
          if not failed then begin
            pooledGold := pooledGold - price;
            Money.SetTreasureCoinsInSteel(pooledGold);
            if itemToBuy^.quantity > 0 then
              CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys ' + itemToBuy^.name)
            else
              CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys a ' + itemToBuy^.name);
          end;
        end else
          CharHlp.PrintBottomLine('Not enough Money.');
      end;
    end;
  until done;
end;

procedure ShopMainMenu;
var
  menu: String[40];
  { always empty }
  query: String[1];
  extendedKey: Boolean;
  done: Boolean;
  key: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  yesNoIndex: Byte;
  appraisalAccepted: Boolean;
  item: Types.PItemRec;
begin
  GDVars.interfaceState := C_Ifc.SHOP_TEMPLE;
  GDVars.drawFlag := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.drawFlag := 1;
  CharHlp.DisplayParty(GDVars.curChar);
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
  query[0] := #0;
  GDVars.treasureMoneyFlag := False;
  done := False;
  item := GDVars.treasureItems;
  while item <> nil do begin
    CharHlp.PrintItemString(nil, item, 0, 0, False, False);
    item := item^.next;
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := 'Buy View Take Pool Share Appraise Exit'
    else
      menu := 'Buy View Pool Appraise Exit';
    key := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, False, extendedKey);
    case key of
      'B': Shop.ShopBuyMenu;
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
'As you Leave the Shopkeeper says, "Excuse me but you have Left Some Money here."  ');
               TextRend.displayMessageWindow(1, 17, 38, 22, White, Black, False,
                                             'Do you want to go back and get your Money?');
               yesNoIndex := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen, White, False,
                                                                   False);
               if yesNoIndex = 1 then
                 done := True
               else
                 TextRend.ClearRect(1, 17, 38, 22);
             end else
               done := True;
           end;
      'H': ViewChar.SelectPrevNextChar(key);
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
