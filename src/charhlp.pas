{ Character, inventory, combat-display and combat-state helpers. }
{$O+,F+}
unit CharHlp;
interface

uses Types, Crt, SoundDrv, TextRend, Border, Blit, ClassCal, MenuCore, MapView, Portrait, Pathing, CbtMap, MapTiles,
  Debug, GDConsts, GDVars, C_Class, C_Race, C_Dir, C_Status, C_Keys, C_Ifc, C_Stat,
  C_Side, C_Item;

{ Builds an item's display name in its own name field: a Yes/No readied column for the inventory view, '*' on a magical
  item (plus, save bonus or cursed) when any party member has Detect Magic, the quantity, then the identified name
  components, at most one of them pluralized when the quantity is above 1.
  @param(character Unused.)
  @param(item The item to name.)
  @param(column Screen column for the printed name.)
  @param(row Screen row for the printed name.)
  @param(inventoryView Adds the readied column.)
  @param(render Also prints the name at (`column`, `row`).) }
procedure PrintItemString(character, item: Pointer; column, row: Byte; inventoryView, render: Boolean);

{ Draws the party roster and records its rows for mouse picks: a Name, AC and HP heading on row 2 and one line per
  member from row 4 (highlighted in white, others colored by DisplayCreatureName), with AC and hit points right-aligned.
  The roster starts in column 1 in the main menu and column 17 otherwise, and is not drawn on the overland map without
  an area view or during a special view.
  @param(highlighted The member to highlight, usually the current character.) }
procedure DisplayParty(highlighted: Pointer);

{ Prints a creature's current hit points at a screen position: yellow when wounded, light green when whole, light
  magenta when asked. When asked, the maximum follows after a slash in light green.
  @param(character The creature.)
  @param(column The column.)
  @param(row The row.)
  @param(forceMagenta Set to print in light magenta.)
  @param(showMaximum Set to add the maximum after a slash.) }
procedure PrintHitPoints(character: Pointer; column, row: Byte; forceMagenta, showMaximum: Boolean);

{ Prints a character's armor class in light green: 60 minus the stored value, with a minus sign when the value is above
  60.
  @param(character The character.)
  @param(column Screen column.)
  @param(row Screen row.) }
procedure PrintArmorClass(character: Pointer; column, row: Byte);

{ Fills the combat side panel for a creature when the panel is marked dirty (and clears the mark): name, hit points,
  armor class, readied weapon, and the status name of a creature out of play, '(Helpless)' or '(Casting)'.
  @param(character The creature to show.) }
procedure CombatPrintCreatureInfo(character: Pointer);

{ Tells whether a creature is helpless: any of the four helplessness effects is on it.
  @param(character The creature.)
  @returns(True when the creature is helpless.) }
function IsHelpless(character: Pointer): Boolean;

{ Recomputes a character's derived values from its inventory: refills the readied-slot table (by item slot, with two
  ring slots, arrows in slot 11 and quarrels in slot 12), the item count, the hands in use and the encumbrance (item
  weights times quantity, plus coins of types 1..6); resets the current damage dice to the unarmed dice; and rebuilds
  THAC0 and damage (WeaponAdjust, or the Strength adjustments unarmed), movement (ArmorMoveAdjust, EncumbranceAdjust)
  and armor class from Dexterity and readied items (AddItemArmorAdjust), magic body armor canceling the ring bonus.
  acCur[0] gets the full AC value and acCur[1] the AC without Dexterity or shield, less 2; attackLevel gets the highest
  fighter, knight or ranger level of a character with such levels (an earlier fighter class counting while active) that
  is not a monster, else 1.
  @param(character The character to update.) }
procedure RecalcStats(character: Pointer);

{ Formats a number in decimal.
  @param(value The number.)
  @returns(Its decimal digits, with a minus sign when negative.) }
function Int32Str(value: LongInt): String;

{ Formats a number in decimal.
  @param(value The number.)
  @returns(Its decimal digits.) }
function Uint16Str(value: Word): String;

{ Formats a number in decimal.
  @param(value The number.)
  @returns(Its decimal digits.) }
function Uint8Str(value: Byte): String;

{ Computes the Dexterity missile adjustment from the current Dexterity: -4 at 0..2, -3..-1 at 3..5, +1..+3 at 16..18, 3
  at 19..20, 4 at 21..23, 5 at 24..25, else 0.
  @param(character The creature.)
  @returns(The adjustment.) }
function DexMissileAdjust(character: Pointer): ShortInt;

{ Computes the Strength to-hit bonus on TranslatedStrength's scale (-3 at 1..3 up to +7 at 30), or 0 unless the
  creature's Strength bonus applies.
  @param(character The creature.)
  @returns(The to-hit bonus.) }
function StrToHitAdjust(character: Pointer): ShortInt;

{ Computes the Strength damage bonus on TranslatedStrength's scale (-2 at 1..2 up to +14 at 30), or 0 unless the
  creature's Strength bonus applies.
  @param(character The creature.)
  @returns(The damage bonus.) }
function StrDamageAdjust(character: Pointer): ShortInt;

{ Computes the extra carrying allowance for a character's Strength on TranslatedStrength's scale, from -350 at 1..3 to
  15000 at 30, and 0 at 8..11.
  @param(character The character.)
  @returns(The allowance, which may be negative.) }
function WeightAllowance(character: Pointer): Integer;

{ Clears the first memorized-spell byte equal to spellId (used when a spell being cast is lost).
  @param(character The creature whose memorized spells are searched.)
  @param(spellId The spell to forget.) }
procedure RemoveSpell(character: Pointer; spellId: Byte);

{ Takes an item out of a creature's items and frees it; a nil item, or one not in the list, only gets an error message.
  @param(character The creature.)
  @param(item The item.) }
procedure RemoveItem(character, item: Pointer);

{ Appends a copy of an item to the end of a character's item list.
  @param(character The character who receives the copy.)
  @param(item The item to copy.) }
procedure AddItemCopy(character, item: Pointer);

{ Shows a message on the bottom row in light green for the text delay, then clears the row.
  @param(message The message.) }
procedure PrintBottomLine(message: Types.TStr40);

{ Prints a creature's name with a message under it: in combat in the side panel from the given row on, elsewhere in the
  text window from row 17, or 18 while the border is off.
  @param(character The creature.)
  @param(message The message.)
  @param(row The panel row of the name, read in combat.)
  @param(effect When set, pauses and then clears the message area.) }
procedure PrintCreatureMessage(character: Pointer; message: String; row: Byte; effect: Boolean);

{ Clears the message area: the side panel's rows 10..21 in combat, otherwise rows 18..22. }
procedure ClearMessageWindow;

{ Prints a creature's name in light red when out of play, yellow when hostile in combat, light cyan otherwise.
  @param(character The creature.)
  @param(column Screen column.)
  @param(row Screen row.)
  @param(possessive Appends 's.) }
procedure DisplayCreatureName(character: Pointer; column, row: Byte; possessive: Boolean);

{ Copies one frame of an icon slot, mirrored or not, into one frame of the combat view picture.
  @param(cell The icon slot.)
  @param(half The icon frame to copy, 0 or 1.)
  @param(row The picture frame to fill.)
  @param(mirror Mirrors the frame.) }
procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);

{ Builds the four-frame moving-icon sheet from an icon: frame 0 straight and mirrored, then frame 1 mirrored and
  straight.
  @param(cell The icon slot.) }
procedure BuildIconFacings(cell: Byte);

{ Flies the combat view picture from one arena cell to another along a third-cell path, cycling its frames and keeping
  it in view: the view stays put when both ends are visible, is centered between them when they lie within 6 cells of
  each other, and otherwise follows the picture and finishes at the target. With a pause of 0 the picture is drawn on
  cell edges and skipped between them. Paths of fewer than four steps are not drawn.
  @param(startX Start column.)
  @param(startY Start row.)
  @param(endX Target column.)
  @param(endY Target row.)
  @param(frameCount The number of picture frames to cycle.)
  @param(pace Milliseconds to pause on each drawn step.) }
procedure CombatAnimateMovingIcon(startX, startY, endX, endY: Integer; frameCount, pace: Byte);

{ Announces an effect on a creature. In combat, builds the effect picture from icon slot 22 for an effect or 23 for
  damage, scrolls to the creature, plays the matching sound, prints the message and animates the picture over it (one
  more time than the game delay for an effect, once followed by a pause for damage); elsewhere prints the message with a
  pause.
  @param(character The creature.)
  @param(effect Set for an effect, clear for damage.)
  @param(message The message.) }
procedure PrintNameStringAnim(character: Pointer; effect: Byte; message: String);

{ Finds a creature's first effect with an id. The node comes back through an untyped parameter, so callers may pass any
  pointer variable.
  @param(character The creature.)
  @param(id The effect to look for.)
  @param(matchedEffect Receives that effect, or nil.)
  @returns(True if found.) }
function HasEffect(character: Pointer; id: Byte; var matchedEffect): Boolean;

{ Subtracts damage from a creature's hit points. Falling more than 9 below 0, or an animated creature reaching 0, kills
  it; 1..9 below makes it dying (in combat the deficit is kept as overkill); landing on 0 makes it unconscious. A
  creature whose status is then anything but okay or animated is out of play at 0 hit points and, in combat, removed
  from its side's count and loses its initiative.
  @param(character The creature.)
  @param(damage The damage.) }
procedure InflictDamage(character: Pointer; damage: Byte);

{ Prints 'is fully healed' or 'is partially healed' for a creature, and outside combat redraws the roster.
  @param(character The healed creature.) }
procedure AnnounceHealStatus(character: Pointer);

{ Gives the side opposing a creature.
  @param(character The creature.)
  @returns(C_Side.ENEMY for the party's side, else C_Side.PLAYER.) }
function EnemyTeam(character: Pointer): ShortInt;

{ Recounts the creatures in play on each side. }
procedure CountTeams;

{ Builds the target list within a range of a creature, narrows it to the creature's enemies and copies their creature
  indices into the target-slot table. A creature under effect 91 gets its preferred target moved to the front.
  @param(character The creature at the center.)
  @param(rangeLimit The range.)
  @returns(The number of targets kept.) }
function CountTargets(character: Pointer; rangeLimit: Byte): Byte;

{ Measures the distance in whole steps from one creature to another, read from a fresh range-255 target list built
  ignoring terrain (the previous list is saved and restored). Note: an absent target gives the last entry's distance.
  @param(character The creature measuring.)
  @param(target The creature to find.)
  @returns(The distance.) }
function CalcDistance(character, target: Pointer): Byte;

{ Ends a creature's actions for the round: clears its initiative, casting, guarding and movement.
  @param(character The creature.)
  @returns(Always True.) }
function EndActions(character: Pointer): Boolean;

{ Ends a creature's actions and, unless it is turned, sets it guarding with a 'Guarding' message.
  @param(character The creature.)
  @returns(Always True.) }
function Guard(character: Pointer): Boolean;

{ Computes the current character's caster level for a spell. With no cleric or magic-user levels, a knight below 9 and a
  ranger below 8, it is 6. Otherwise by the spell's class: cleric and special spells use the higher of the cleric level
  and knight level - 8; druid spells ranger level - 7 (at least 0); magic-user spells the higher of the magic-user level
  and ranger level - 8, a magic-user of a robe order losing 1 or (above level 5) gaining 1 as the zone's word for that
  order is 0 or 2; class 4 spells give 12. Dual-class earlier levels count. While an item is being used, any spell but a
  class 4 one is cast at level 6.
  @param(spellId The spell.)
  @returns(The caster level.) }
function GetCasterLevel(spellId: Byte): Byte;

{ Lets the player pick a party member: the up and down arrows move through the party (a mouse click on the roster picks
  directly), Enter or S selects, and E or Escape ends the pick.
  @param(query The prompt text.)
  @param(allowExit Offers an Exit choice; Exit or Escape then sets selection to nil.)
  @param(useAlternate Lets a mouse pick go to altChar instead of the current character.)
  @param(selection The member highlighted at the start; receives the pick, passed untyped.) }
procedure SelectChar(query: Types.TStr40; allowExit, useAlternate: Boolean; var selection);

{ Redraws the noncombat screen for the current interface state (main menu, shop or temple, camp, 3D view, overland map
  unless picture 9 or an area view is shown, treasure), with the roster and status line where they apply, and marks the
  picture for redraw. }
procedure DisplayNoncombatInterface;

{ Draws the status line on row 15: the party's map position (unless the area hides it), compass direction and time, '*'
  while the debug trace is on, and ' camping' or ' search' when they apply. Not drawn on the overland map. }
procedure PrintPositionAndTime;

{ Switches to the combat palette, draws the combat frame and rebuilds the combat view. }
procedure DisplayCombatInterface;

{ Tells whether a creature's readied weapon has a range above 1.
  @param(character The creature.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(character: Pointer): Boolean;

{ Tells whether a creature's readied weapon is ranged and either is thrown as its own missile or is item type 67.
  @param(character The creature.)
  @returns(True for a thrown weapon.) }
function HasThrowableWeapon(character: Pointer): Boolean;

{ Finds the item that does the damage in a ranged attack: the readied weapon itself when thrown, else the readied arrows
  for a bow or the readied quarrels for a crossbow, or nil when there is none.
  @param(character The creature.)
  @param(weapon Receives the item, or nil.)
  @returns(True when an item is found, and also for a weapon whose properties are exactly $0A, which needs no
    ammunition.) }
function FindDamagingRangedWeapon(character: Pointer; var weapon): Boolean;

{ Checks whether a creature's readied weapon is a hoopak.
  @param(character The creature.)
  @returns(True for a hoopak.) }
function HasReadiedHoopak(character: Pointer): Boolean;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCharHlp;

{ Tells whether any party member (a side-0 player or non-player character) is dying. With `applyBandage` set, the first
  dying member found is bandaged: it becomes unconscious, its overkill is cleared and the bandaging is announced.
  @param(applyBandage Set to bandage the first dying member.)
  @returns(True when a member is dying.) }
function BandageDying(applyBandage: Boolean): Boolean;

{ Maps a class code to its sub-order index: a cleric 0 or 1 by deity, a knight 3..5 by order, a magic-user 7 or 8 by
  robe order, and codes 2, 4 and 6 to 2, 6 and 9. Note: other codes, and a knight with no order, leave the result
  undefined.
  @param(character The character.)
  @param(classCode The class code.)
  @returns(The sub-order index.) }
function ClassSuborderIndex(character: Pointer; classCode: Byte): Byte;

{ Finds the compass direction (0 = N, 1 = NE, ... 7 = NW) from one creature to another on the combat grid, by octant:
  the slopes 618/256 and 106/256 are tan 67.5 and tan 22.5 degrees.
  @param(creature The creature looked from.)
  @param(other The creature looked at.)
  @returns(The direction.) }
function DirTowardTarget(creature, other: Pointer): Byte;

implementation

const
  EFF_DETECT_MAGIC = 5;

type
  { the 5-slot AC adjustment array AddItemArmorAdjust mutates: 0 Dexterity, 1 shield, 2 miscellaneous, 3 Ring of
    Protection, 4 body armor or bracers. }
  TAcAdjust = array[0..4] of ShortInt;

function TranslatedStrength(character: Types.PCharRecord): Byte; forward;

function DexterityArmorAdjustment(character: Types.PCharRecord): ShortInt; forward;

procedure PrimeCharHlp;
begin
  MapTiles.PrimeMapTiles;
  Debug.PrimeDebug;
  Portrait.PrimePortrait;
  MapView.PrimeMapView;
  MenuCore.PrimeMenuCore;
  ClassCal.PrimeClassCal;
end;

{ Sets the readied weapon's THAC0 and damage. THAC0 starts from its base, plus the Dexterity missile adjustment for a
  missile weapon and the Strength to-hit bonus for a weapon that uses Strength, which also adds the Strength damage
  bonus. The damage modifier starts from the weapon's small-target modifier. The weapon's plus and its ammunition's plus
  (the readied quarrels or arrows it fires) are added to both the damage modifier and THAC0; a Silvanesti or Qualinesti
  elf adds 1 more to THAC0 alone with item types 18, 19 and 22..26, and a kender 2 more with a hoopak. The damage dice
  are the small-target dice. Does nothing without a readied weapon.
  @param(character The character.) }
procedure WeaponAdjust(character: Types.PCharRecord);
var
  readiedWeapon: Types.PItemRec;
  { base-item index }
  weaponType: Byte;
  { accumulated magical bonus }
  magicBonus: ShortInt;
begin
  readiedWeapon := character^.equipped[0];
  if readiedWeapon = nil then Exit;
  weaponType := readiedWeapon^.itemType;
  character^.thac0Adj := character^.thac0Base;
  if (GDVars.baseItems[weaponType].props and $02) <> 0 then
    character^.thac0Adj := CharHlp.DexMissileAdjust(character) + character^.thac0Adj;
  character^.curMod[1] := GDVars.baseItems[weaponType].dmgSmMod;
  if (GDVars.baseItems[weaponType].props and $04) <> 0 then begin
    character^.thac0Adj := CharHlp.StrToHitAdjust(character) + character^.thac0Adj;
    character^.curMod[1] := CharHlp.StrDamageAdjust(character) + character^.curMod[1];
  end;
  magicBonus := readiedWeapon^.plus;
  { bit 128: quarrel ammo }
  if GDVars.baseItems[weaponType].props > $7F then
    if character^.equipped[12] <> nil then
      magicBonus := magicBonus + character^.equipped[12]^.plus;
  { bit 1: arrow ammo }
  if (GDVars.baseItems[weaponType].props and $01) > 0 then
    if character^.equipped[11] <> nil then
      magicBonus := magicBonus + character^.equipped[11]^.plus;
  character^.curMod[1] := character^.curMod[1] + magicBonus;
  if ((character^.race = C_Race.SILVANESTI_ELF) or (character^.race = C_Race.QUALINESTI_ELF)) and
      (((readiedWeapon^.itemType > 21) and (readiedWeapon^.itemType < 27)) or (readiedWeapon^.itemType = 19) or
       (readiedWeapon^.itemType = 18)) then
    Inc(magicBonus);
  if (character^.race = C_Race.KENDER) and (readiedWeapon^.itemType = C_Item.HOOPAK) then
    Inc(magicBonus, 2);
  character^.thac0Adj := character^.thac0Adj + magicBonus;
  character^.curRolls[1] := GDVars.baseItems[weaponType].dmgSmRolls;
  character^.curDice[1] := GDVars.baseItems[weaponType].dmgSmDice;
end;

{ Sets movement from readied body armor's weight: the base movement up to 150, 9 up to 399, else 6; magic armor adds 3
  when that leaves 9 or less.
  @param(character The character.)
  @param(item A readied item; anything but body armor is ignored.) }
procedure ArmorMoveAdjust(character: Types.PCharRecord; item: Types.PItemRec);
begin
  if GDVars.baseItems[item^.itemType].slot = 2 then begin
    case item^.weight of
      0..150: character^.movementCur := character^.movementBase;
      151..399: character^.movementCur := 9;
    else
      character^.movementCur := 6;
    end;
    if (item^.plus <> 0) and (character^.movementCur <= 9) then
      character^.movementCur := character^.movementCur + 3;
  end;
end;

{ Folds one readied item into the armor-class adjustments. Only an item whose base armor value has bit 7 set counts; the
  low seven bits are its own armor class. A shield sets the shield slot to its armor class plus its plus. An item with
  armor class 0 adds its save bonus to the creature's and its plus to the slot of armor-class-0 items, except a ring,
  which raises the best-ring slot to its plus. Any other item keeps the best armor class plus plus in the armor slot,
  marking magical body armor when that new best is body armor with a positive plus.
  @param(character The creature.)
  @param(item The item.)
  @param(adjustments The adjustments: 0 Dexterity, 1 shield, 2 pluses of armor-class-0 items, 3 best ring, 4 best
    armor.)
  @param(isMagicBody Set when the best armor becomes magical body armor.) }
procedure AddItemArmorAdjust(character: Types.PCharRecord; item: Types.PItemRec; var adjustments: TAcAdjust;
                             var isMagicBody: Boolean);
var
  { base acDescr, masked to its low 7 bits }
  armorDescription: Byte;
  equipSlot: Byte;
begin
  armorDescription := GDVars.baseItems[item^.itemType].acDescr;
  if armorDescription > $7F then begin
    armorDescription := armorDescription and $7F;
    equipSlot := GDVars.baseItems[item^.itemType].slot;
    if equipSlot = 1 then
      adjustments[1] := armorDescription + item^.plus
    else if armorDescription = 0 then begin
      if equipSlot = 9 then begin
        if item^.plus > adjustments[3] then
          adjustments[3] := item^.plus;
      end else
        adjustments[2] := adjustments[2] + item^.plus;
      character^.saveBonus := character^.saveBonus + item^.saveBonus;
    end else begin
      if armorDescription + item^.plus > adjustments[4] then begin
        adjustments[4] := armorDescription + item^.plus;
        if item^.plus > 0 then
          if equipSlot = 2 then
            isMagicBody := True;
      end;
    end;
  end;
end;

{ Lowers a creature's movement for the coins it carries past its weight allowance: up to 512 over changes nothing, and
  each further band of 256 steps down to 9, 6 and 3. The movement is only ever lowered.
  @param(character The creature.) }
procedure EncumbranceAdjust(character: Types.PCharRecord);
var
  { coins carried over the allowance }
  excessWeight: Integer;
  { movement for that band }
  movementRate: Byte;
begin
  excessWeight := character^.encumbrance - CharHlp.WeightAllowance(character);
  if excessWeight < 0 then
    excessWeight := 0;
  case excessWeight of
    0..512: movementRate := character^.movementCur;
    513..768: movementRate := 9;
    769..1024: movementRate := 6;
  else
    movementRate := 3;
  end;
  if movementRate < character^.movementCur then
    character^.movementCur := movementRate;
end;

procedure PrintItemString;
var
  componentIndex: Byte;
  { identified-component bits }
  identificationMask: Byte;
  { HasEffect's out-node }
  effectNode: Pointer;
  { Detect Magic active on someone }
  found: Boolean;
  { plural 's' already emitted }
  appended: Boolean;
  partyMember: Types.PCharRecord;
begin
  Types.PItemRec(item)^.name := '';
  if inventoryView then begin
    if Types.PItemRec(item)^.equipped <> 0 then
      Types.PItemRec(item)^.name := ' Yes  '
    else
      Types.PItemRec(item)^.name := ' No   ';
  end;
  found := False;
  partyMember := GDVars.partyHead;
  while (partyMember <> nil) and not found do begin
    if CharHlp.HasEffect(partyMember, CharHlp.EFF_DETECT_MAGIC, effectNode) then
      found := True;
    partyMember := partyMember^.next;
  end;
  if found then
    if (Types.PItemRec(item)^.plus > 0) or (Types.PItemRec(item)^.saveBonus > 0) or
        (Types.PItemRec(item)^.cursed <> 0) then
      Types.PItemRec(item)^.name := Types.PItemRec(item)^.name + '*' + ' ';
  if Types.PItemRec(item)^.quantity > 0 then
    Types.PItemRec(item)^.name := Types.PItemRec(item)^.name + CharHlp.Uint8Str(Types.PItemRec(item)^.quantity) +
      ' ';
  identificationMask := 0;
  for componentIndex := 1 to 3 do
    if Types.PItemRec(item)^.nameIds[componentIndex] <> 0 then
      if (Types.PItemRec(item)^.unidMask shr (3 - componentIndex)) and $01 = 0 then
        Inc(identificationMask, 1 shl (componentIndex - 1));
  appended := False;
  for componentIndex := 3 downto 1 do
    if (identificationMask shr (componentIndex - 1)) and $01 > 0 then begin
      Types.PItemRec(item)^.name := Types.PItemRec(item)^.name +
          GDConsts.nameParts[Types.PItemRec(item)^.nameIds[componentIndex]];
      if (Types.PItemRec(item)^.quantity < 2) or appended then
        Types.PItemRec(item)^.name := Types.PItemRec(item)^.name + ' '
      else if ((1 shl (componentIndex - 1)) = identificationMask) or
        ((componentIndex = 1) and (identificationMask > 4) and (Types.PItemRec(item)^.itemType <> 55)) or
        ((componentIndex = 2) and not Odd(identificationMask)) or
        ((componentIndex = 3) and (Types.PItemRec(item)^.itemType = 55)) or
        (((Types.PItemRec(item)^.itemType = 30) or (Types.PItemRec(item)^.itemType = 5) or
          (Types.PItemRec(item)^.itemType = 12)) and
         (Types.PItemRec(item)^.nameIds[3] <> 93)) then begin
        Types.PItemRec(item)^.name := Types.PItemRec(item)^.name + 's ';
        appended := True;
      end else
        Types.PItemRec(item)^.name := Types.PItemRec(item)^.name + ' ';
    end;
  if render then
    TextRend.displayString(column, row, LightGreen, Black, Types.PItemRec(item)^.name);
end;

procedure DisplayParty;
var
  { roster walker }
  member: Types.PCharRecord;
  { panel left column }
  panelColumn: Byte;
  { current panelRow }
  panelRow: Byte;
  { digit-width column nudge }
  digitBand: Byte;
begin
  if ((GDVars.interfaceState = C_Ifc.OVERLAND) and (GDVars.zone0^.areaView = 0)) or (GDVars.specialView <> 0) then
    Exit;
  if GDVars.interfaceState = C_Ifc.MAIN_MENU then
    panelColumn := 1
  else
    panelColumn := 17;
  GDVars.screenColumnLo := panelColumn;
  GDVars.screenRowLo := 4;
  GDVars.screenColumnHi := 38;
  GDVars.screenRowHi := 3;
  panelRow := 2;
  TextRend.displayString(panelColumn, panelRow, White, Black, 'Name');
  TextRend.displayString(33, panelRow, White, Black, 'AC  HP');
  Inc(panelRow, 2);
  member := GDVars.partyHead;
  while member <> nil do begin
    Inc(GDVars.screenRowHi);
    Border.ClearBox(panelColumn, panelRow, 38, panelRow);
    if member = highlighted then
      TextRend.displayString(panelColumn, panelRow, White, Black, member^.name)
    else
      CharHlp.DisplayCreatureName(member, panelColumn, panelRow, False);
    case member^.acCur[0] of
      0..50: digitBand := 1;
      51..60: digitBand := 2;
      61..69: digitBand := 1;
    else
      digitBand := 0;
    end;
    CharHlp.PrintArmorClass(member, digitBand + 32, panelRow);
    case member^.hpCur of
      0..9: digitBand := 2;
      10..99: digitBand := 1;
    else
      digitBand := 0;
    end;
    CharHlp.PrintHitPoints(member, digitBand + 36, panelRow, False, False);
    Inc(panelRow);
    member := member^.next;
  end;
  Border.ClearBox(panelColumn, panelRow, 38, panelRow);
end;

procedure PrintArmorClass;
var
  armorText: String;
  { Unused in this version; see the other implementations of this routine. }
  color: Byte;
begin
  armorText := CharHlp.Uint8Str(Abs(Types.PCharRecord(character)^.acCur[0] - 60));
  if Types.PCharRecord(character)^.acCur[0] > 60 then
    armorText := '-' + armorText;
  TextRend.displayString(column, row, LightGreen, Black, armorText);
end;

procedure PrintHitPoints;
var
  hpText: String;
  color: Byte;
  separatorOffset: ShortInt;
begin
  if Types.PCharRecord(character)^.hpCur < Types.PCharRecord(character)^.hpMax then
    color := 14
  else
    color := 10;
  if forceMagenta then
    color := 13;
  hpText := CharHlp.Uint8Str(Types.PCharRecord(character)^.hpCur);
  TextRend.displayString(column, row, color, Black, hpText);
  if showMaximum then begin
    separatorOffset := Length(hpText);
    TextRend.displayString(column + separatorOffset, row, LightGreen, Black,
                           '/' + CharHlp.Uint8Str(Types.PCharRecord(character)^.hpMax));
  end;
end;

procedure CombatPrintCreatureInfo;
var
  { Unused in this version; see the other implementations of this routine. }
  displayColumn: Byte;
  displayRow: Byte;
begin
  if GDVars.panelDirty <> 0 then begin
    GDVars.panelDirty := 0;
    Border.ClearBox(23, 1, 38, 21);
    displayRow := 1;
    CharHlp.PrintCreatureMessage(character, ' ', displayRow, False);
    Inc(displayRow);
    TextRend.displayString(23, displayRow + 1, LightGreen, Black, 'Hitpoints');
    CharHlp.PrintHitPoints(character, 33, displayRow + 1, False, False);
    Inc(displayRow, 2);
    TextRend.displayString(23, displayRow + 1, LightGreen, Black, 'AC');
    CharHlp.PrintArmorClass(character, 26, displayRow + 1);
    GDVars.curRow := displayRow + 1;
    if Types.PCharRecord(character)^.equipped[0] <> nil then begin
      Inc(displayRow, 2);
      displayColumn := 23;
      CharHlp.PrintItemString(character, Types.PCharRecord(character)^.equipped[0], 0, 0, False, False);
      TextRend.displayMessageWindow(23, displayRow + 1, 38, displayRow + 1 + 1 + 1, LightGreen, Black, True,
                                    Types.PCharRecord(character)^.equipped[0]^.name);
    end;
    displayRow := GDVars.curRow + 1;
    if Types.PCharRecord(character)^.inPlay = 0 then
      TextRend.displayString(23, displayRow + 1, White, Black,
                             GDConsts.statusNames[ShortInt(Types.PCharRecord(character)^.status)])
    else if CharHlp.IsHelpless(character) then
      TextRend.displayString(23, displayRow + 1, White, Black, '(Helpless)')
    else if Types.PCharRecord(character)^.combatAddr^.spellCast > 0 then
      TextRend.displayString(23, displayRow + 1, White, Black, '(Casting)');
  end;
end;

function IsHelpless;
var
  effectIndex: Byte;
  { HasEffect's out-node }
  effectNode: Pointer;
begin
  IsHelpless := False;
  for effectIndex := 1 to 4 do
    if CharHlp.HasEffect(character, GDConsts.helplessFx[effectIndex], effectNode) then
      IsHelpless := True;
end;

procedure RecalcStats;
var
  { unarmed-copy index }
  weaponIndex: Byte;
  { armorAdjustments index }
  adjustIndex: ShortInt;
  { inventory walker }
  item: Types.PItemRec;
  { magical body armor seen }
  magicBodyArmor: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  bag: Boolean;
  armorAdjustments: TAcAdjust;
  { equipped-clear index }
  equipIndex: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  propertySlot: Byte;
  coinIndex: ShortInt;
  { one item's weight }
  itemWeight: Word;
  equipSlot: 0..127;
begin
  for equipIndex := 0 to 12 do
    Types.PCharRecord(character)^.equipped[equipIndex] := nil;
  bag := False;
  Types.PCharRecord(character)^.itemCount := 0;
  item := Types.PCharRecord(character)^.itemsAddr;
  Types.PCharRecord(character)^.handsEquipped := 0;
  Types.PCharRecord(character)^.encumbrance := 0;
  GDVars.equippedWeight := 0;
  while item <> nil do begin
    Inc(Types.PCharRecord(character)^.itemCount);
    itemWeight := item^.weight;
    if item^.quantity > 0 then
      itemWeight := item^.quantity * itemWeight;
    Inc(Types.PCharRecord(character)^.encumbrance, itemWeight);
    if item^.equipped <> 0 then begin
      Inc(GDVars.equippedWeight, itemWeight);
      equipSlot := GDVars.baseItems[item^.itemType].slot;
      case Byte(equipSlot) of
        0..8: Types.PCharRecord(character)^.equipped[equipSlot] := item;
        9:
          if Types.PCharRecord(character)^.equipped[9] <> nil then begin
            if Types.PCharRecord(character)^.equipped[10] = nil then
              Types.PCharRecord(character)^.equipped[10] := item;
          end else
            Types.PCharRecord(character)^.equipped[9] := item;
      end;
      if item^.itemType = 30 then
        Types.PCharRecord(character)^.equipped[11] := item;
      if item^.itemType = 12 then
        Types.PCharRecord(character)^.equipped[12] := item;
      Types.PCharRecord(character)^.handsEquipped := Types.PCharRecord(character)^.handsEquipped
                                 + GDVars.baseItems[item^.itemType].hands;
    end;
    item := item^.next;
  end;
  for coinIndex := 1 to 6 do
    Types.PCharRecord(character)^.encumbrance :=
      Types.PCharRecord(character)^.encumbrance + Types.PCharRecord(character)^.coinsA[coinIndex];
  for weaponIndex := 1 to 2 do begin
    Types.PCharRecord(character)^.curRolls[weaponIndex] := Types.PCharRecord(character)^.unarmedRolls[weaponIndex];
    Types.PCharRecord(character)^.curDice[weaponIndex] := Types.PCharRecord(character)^.unarmedDice[weaponIndex];
    Types.PCharRecord(character)^.curMod[weaponIndex] := Types.PCharRecord(character)^.unarmedMod[weaponIndex];
  end;
  for adjustIndex := 0 to 4 do
    armorAdjustments[adjustIndex] := 0;
  magicBodyArmor := False;
  Types.PCharRecord(character)^.saveBonus := 0;
  Types.PCharRecord(character)^.acCur[0] := Types.PCharRecord(character)^.acBase;
  Types.PCharRecord(character)^.movementCur := Types.PCharRecord(character)^.movementBase;
  Types.PCharRecord(character)^.thac0Adj := Types.PCharRecord(character)^.thac0Base;
  armorAdjustments[0] := CharHlp.DexterityArmorAdjustment(Types.PCharRecord(character));
  if Types.PCharRecord(character)^.equipped[0] = nil then begin
    Types.PCharRecord(character)^.thac0Adj := CharHlp.StrToHitAdjust(character) +
      Types.PCharRecord(character)^.thac0Adj;
    Types.PCharRecord(character)^.curMod[1] := CharHlp.StrDamageAdjust(character) +
        Types.PCharRecord(character)^.curMod[1];
  end;
  CharHlp.WeaponAdjust(Types.PCharRecord(character));
  item := Types.PCharRecord(character)^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(Types.PCharRecord(character), item);
      CharHlp.AddItemArmorAdjust(Types.PCharRecord(character), item, armorAdjustments, magicBodyArmor);
    end;
    item := item^.next;
  end;
  if magicBodyArmor then
    armorAdjustments[3] := 0;
  CharHlp.EncumbranceAdjust(Types.PCharRecord(character));
  if armorAdjustments[4] < Types.PCharRecord(character)^.acCur[0] then
    armorAdjustments[4] := Types.PCharRecord(character)^.acCur[0];
  Types.PCharRecord(character)^.acCur[0] := 0;
  for adjustIndex := 0 to 4 do
    Types.PCharRecord(character)^.acCur[0] := Types.PCharRecord(character)^.acCur[0] + armorAdjustments[adjustIndex];
  Types.PCharRecord(character)^.acCur[1] := armorAdjustments[4] + armorAdjustments[2] + armorAdjustments[3] - 1 - 1;
  if ((Types.PCharRecord(character)^.classLevels[C_Class.FIGHTER] > 0) or
      ((Types.PCharRecord(character)^.classLevels2[C_Class.FIGHTER] > 0) and
       ClassCal.EarlierClassActive(character)) or
         (Types.PCharRecord(character)^.classLevels[C_Class.KNIGHT] > 0) or
         (Types.PCharRecord(character)^.classLevels[C_Class.RANGER] > 0)) and
         (Types.PCharRecord(character)^.race < C_Race.MONSTER) then begin
    Types.PCharRecord(character)^.attackLevel := Types.PCharRecord(character)^.classLevels[C_Class.FIGHTER];
    if Byte(Types.PCharRecord(character)^.classLevels[C_Class.KNIGHT]) >
        Types.PCharRecord(character)^.attackLevel then
      Types.PCharRecord(character)^.attackLevel := Types.PCharRecord(character)^.classLevels[C_Class.KNIGHT];
    if Byte(Types.PCharRecord(character)^.classLevels[C_Class.RANGER]) >
        Types.PCharRecord(character)^.attackLevel then
      Types.PCharRecord(character)^.attackLevel := Types.PCharRecord(character)^.classLevels[C_Class.RANGER];
  end else
    Types.PCharRecord(character)^.attackLevel := 1;
end;

function Uint8Str;
var
  resultText: String;
begin
  Str(value, resultText);
  Uint8Str := resultText;
end;

function Uint16Str;
var
  resultText: String;
begin
  Str(value, resultText);
  Uint16Str := resultText;
end;

function Int32Str;
var
  resultText: String;
begin
  Str(value, resultText);
  Int32Str := resultText;
end;

{ Computes the Dexterity defensive adjustment from the current Dexterity: -4 at 1..3, -3..-1 at 4..6, +1..+4 at 15..18,
  4 at 19..20, 5 at 21..23, 6 at 24..25, else 0.
  @param(character The creature.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment(character: Types.PCharRecord): ShortInt;
var
  dexterity: Byte;
begin
  dexterity := character^.stats[C_Stat.DEXTERITY].cur;
  case dexterity of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := dexterity - 7;
    15..18: DexterityArmorAdjustment := dexterity - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

function DexMissileAdjust;
var
  dexterity: Byte;
begin
  dexterity := Types.PCharRecord(character)^.stats[C_Stat.DEXTERITY].cur;
  case dexterity of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := dexterity - 6;
    16..18: DexMissileAdjust := dexterity - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Converts Strength to one scale: 0..17 as is; 18 by exceptional Strength (without it 18, 01-50 19, 51-75 20, 76-90 21,
  91-99 22, 00 23); 19..25 become 24..30. Note: other values leave the result undefined.
  @param(character The creature.)
  @returns(Strength on that scale.) }
function TranslatedStrength(character: Types.PCharRecord): Byte;
begin
  case character^.stats[C_Stat.STRENGTH].cur of
    0..17: TranslatedStrength := character^.stats[C_Stat.STRENGTH].cur;
    18:
      case character^.strExc of
        0: TranslatedStrength := 18;
        1..50: TranslatedStrength := 19;
        51..75: TranslatedStrength := 20;
        76..90: TranslatedStrength := 21;
        91..99: TranslatedStrength := 22;
        100: TranslatedStrength := 23;
      end;
    19..25: TranslatedStrength := character^.stats[C_Stat.STRENGTH].cur + 5;
  end;
end;

function StrToHitAdjust;
var
  strengthIndex: Byte;
begin
  StrToHitAdjust := 0;
  strengthIndex := CharHlp.TranslatedStrength(Types.PCharRecord(character));
  if Types.PCharRecord(character)^.useStrength <> 0 then
    case strengthIndex of
      1..3: StrToHitAdjust := -3;
      4..5: StrToHitAdjust := -2;
      6..7: StrToHitAdjust := -1;
      17..19: StrToHitAdjust := 1;
      20..22: StrToHitAdjust := 2;
      23..25: StrToHitAdjust := 3;
      26..27: StrToHitAdjust := 4;
      28..30: StrToHitAdjust := strengthIndex - 23;
    end;
end;

function StrDamageAdjust;
var
  strengthIndex: Byte;
begin
  StrDamageAdjust := 0;
  strengthIndex := CharHlp.TranslatedStrength(Types.PCharRecord(character));
  if Types.PCharRecord(character)^.useStrength <> 0 then
    case strengthIndex of
      1..2: StrDamageAdjust := -2;
      3..5: StrDamageAdjust := -1;
      16: StrDamageAdjust := 1;
      17..19: StrDamageAdjust := strengthIndex - 16;
      20..29: StrDamageAdjust := strengthIndex - 17;
      30: StrDamageAdjust := 14;
    end;
end;

function WeightAllowance;
var
  strengthIndex: Byte;
begin
  strengthIndex := CharHlp.TranslatedStrength(Types.PCharRecord(character));
  case strengthIndex of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (strengthIndex - 17) * 250 + 500;
    22..26: WeightAllowance := (strengthIndex - 22) * 1000 + 2000;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (strengthIndex - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
end;

procedure RemoveSpell;
var
  spellIndex: Byte;
begin
  spellIndex := 0;
  while spellIndex <= 57 do begin
    if Types.PCharRecord(character)^.memorized[spellIndex] = spellId then begin
      Types.PCharRecord(character)^.memorized[spellIndex] := 0;
      spellIndex := 58;
    end;
    Inc(spellIndex);
  end;
end;

procedure RemoveItem;
var
  cursor: Types.PItemRec;
begin
  if item = nil then
    TextRend.displayAndPause(Yellow, Black, 'Nil Item pointer...')
  else begin
    cursor := Types.PCharRecord(character)^.itemsAddr;
    if cursor = item then
      Types.PCharRecord(character)^.itemsAddr := Types.PItemRec(item)^.next
    else
      while (cursor <> nil) and (cursor^.next <> item) do
        cursor := cursor^.next;
    if cursor = nil then
      TextRend.displayAndPause(Yellow, Black, 'Tried to Lose item & couldn''t find it!')
    else begin
      cursor^.next := Types.PItemRec(item)^.next;
      Types.PItemRec(item)^.next := nil;
      FreeMem(item, SizeOf(Types.TItemRec));
    end;
  end;
end;

procedure AddItemCopy;
var
  { the tail walker }
  tail: Types.PItemRec;
  { the fresh copy }
  newItem: Types.PItemRec;
begin
  GetMem(newItem, SizeOf(Types.TItemRec));
  Move(Types.PItemRec(item)^, newItem^, SizeOf(Types.TItemRec));
  newItem^.next := nil;
  tail := Types.PCharRecord(character)^.itemsAddr;
  if tail = nil then
    Types.PCharRecord(character)^.itemsAddr := newItem
  else begin
    while tail^.next <> nil do
      tail := tail^.next;
    tail^.next := newItem;
  end;
end;

procedure PrintBottomLine;
begin
  Border.ClearBox(0, 24, 39, 24);
  TextRend.displayString(0, 24, LightGreen, Black, message);
  TextRend.pauseOnly;
  Border.ClearBox(0, 24, 39, 24);
end;

procedure PrintCreatureMessage;
var
  windowTop: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(character, 23, row, False);
    TextRend.displayMessageWindow(23, row + 1, 38, 21, LightGreen, Black, True, message);
  end else begin
    if GDVars.noBorder <> 0 then
      windowTop := 18
    else
      windowTop := 17;
    Border.ClearBox(1, windowTop, 38, 22);
    CharHlp.DisplayCreatureName(character, 1, windowTop + 1, False);
    TextRend.displayMessageWindow(1, windowTop + 1 + 1, 38, 22, LightGreen, Black, True, message);
  end;
  if effect then begin
    TextRend.pauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure ClearMessageWindow;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    Border.ClearBox(1, 18, 38, 22);
end;

procedure DisplayCreatureName;
var
  nameColor: Byte;
begin
  if Types.PCharRecord(character)^.inPlay = 0 then
    nameColor := LightRed
  else if (Types.PCharRecord(character)^.hostile = C_Side.ENEMY) and
    (GDVars.interfaceState = C_Ifc.IN_COMBAT) then
    nameColor := Yellow
  else
    nameColor := LightCyan;
  TextRend.displayString(column, row, nameColor, Black, Types.PCharRecord(character)^.name);
  if possessive then
    TextRend.displayString(column + Length(Types.PCharRecord(character)^.name), row, nameColor, Black, '''s');
end;

procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);
var
  { scratch for the mirrored half }
  mirroredImage: Types.PImgBuf;
  { bytes in one image, both planes }
  stride: Word;
begin
  stride := GDVars.viewPicture^.imgSize;
  if mirror then begin
    Blit.AllocPic(24, 3, 1, 1, mirroredImage);
    Blit.MirrorPic(GDVars.iconAnims[cell, half], mirroredImage);
    Move(mirroredImage^.data, GDVars.viewPicture^.data[row * stride], stride);
    Move(mirroredImage^.transp^, GDVars.viewPicture^.transp^[row * stride], stride);
    Blit.FreePic(mirroredImage);
  end else begin
    Move(GDVars.iconAnims[cell, half]^.data, GDVars.viewPicture^.data[row * stride], stride);
    Move(GDVars.iconAnims[cell, half]^.transp^, GDVars.viewPicture^.transp^[row * stride], stride);
  end;
end;

procedure BuildIconFacings(cell: Byte);
begin
  CharHlp.CopyIconFacing(cell, 0, 0, False);
  CharHlp.CopyIconFacing(cell, 0, 1, True);
  CharHlp.CopyIconFacing(cell, 1, 2, True);
  CharHlp.CopyIconFacing(cell, 1, 3, False);
end;

procedure CombatAnimateMovingIcon;
var
  { path directions }
  steps: array[0..147] of Byte;
  pathState: Types.TPathState;
  { Unused in this version; see the other implementations of this routine. }
  pathCount: Integer;
  stepIndex: Byte;
  { steps found, less two }
  count: Byte;
  { facing frame }
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  stop: Byte;
  { final outer iteration }
  lastPass: Boolean;
  { path stop / edge flag }
  stopPath: Boolean;
  { scroll target x }
  camX: Integer;
  { scroll target y }
  camY: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevY: Integer;
  { sub-cell x accumulator }
  accX: Integer;
  { sub-cell y accumulator }
  accY: Integer;
  { whole-move x delta }
  dirX: Integer;
  { whole-move y delta }
  dirY: Integer;
  { this step's x delta }
  stepX: Integer;
  { this step's y delta }
  stepY: Integer;
  { icon pixel x (0..18) }
  pixX: Integer;
  { icon pixel y (0..18) }
  pixY: Integer;
  { backward-walk x clamp }
  backX: Integer;
  { backward-walk y clamp }
  backY: Integer;
begin
  prevX := startX;
  prevY := startY;
  FillChar(steps, SizeOf(steps), 8);
  FillChar(pathState, SizeOf(pathState), 0);
  stepIndex := 0;
  frame := 0;
  pathState.startX := startX * 3;
  pathState.startY := startY * 3;
  pathState.endX := endX * 3;
  pathState.endY := endY * 3;
  Pathing.PathFind(pathState);
  repeat
    stopPath := not Pathing.NextPathStep(pathState);
    steps[stepIndex] := pathState.lastDirection;
    Inc(stepIndex);
  until stopPath;
  count := stepIndex - 2;
  if (count < 2) or (stepIndex < 2) then Exit;
  dirX := endX - startX;
  dirY := endY - startY;
  if not CbtMap.ViewCoordsValid(startX - GDVars.arena^.originX, startY - GDVars.arena^.originY) or
      not CbtMap.ViewCoordsValid(endX - GDVars.arena^.originX, endY - GDVars.arena^.originY) then begin
    if (Abs(dirX) <= 6) and (Abs(dirY) <= 6) then begin
      lastPass := True;
      camX := startX + dirX div 2;
      camY := startY + dirY div 2;
    end else begin
      lastPass := False;
      camX := GDVars.arena^.originX + 3;
      camY := GDVars.arena^.originY + 3;
    end;
  end else begin
    lastPass := True;
    camX := GDVars.arena^.originX + 3;
    camY := GDVars.arena^.originY + 3;
  end;
  CbtMap.ScrollView(camX, camY, 255, 8);
  stepIndex := 0;
  accX := 0;
  accY := 0;
  repeat
    pixX := (startX - GDVars.arena^.originX) * 3 + accX;
    pixY := (startY - GDVars.arena^.originY) * 3 + accY;
    prevX := startX;
    prevY := startY;
    stopPath := False;
    repeat
      stepX := GDConsts.dirDeltaX[steps[stepIndex]];
      stepY := GDConsts.dirDeltaY[steps[stepIndex]];
      Inc(pixX, stepX);
      Inc(pixY, stepY);
      if (pace > 0) or (pixX mod 3 = 0) or (pixY mod 3 = 0) then begin
        Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.viewPicture, GDVars.egaDest);
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.saveUnder, GDVars.egaDest);
        Inc(frame);
        if frame >= frameCount then
          frame := 0;
      end;
      Inc(stepIndex);
      if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then
        stopPath := True;
      if not stopPath and (stepIndex < count) then begin
        Inc(accX, stepX);
        Inc(accY, stepY);
        if Abs(accX) = 3 then begin
          Inc(startX, Pathing.SignOf(accX));
          Inc(camX, Pathing.SignOf(accX));
          accX := 0;
        end;
        if Abs(accY) = 3 then begin
          Inc(startY, Pathing.SignOf(accY));
          Inc(camY, Pathing.SignOf(accY));
          accY := 0;
        end;
      end;
    until (stepIndex >= count) or stopPath;
    if stepIndex < count then begin
      backX := 0;
      backY := 0;
      accY := 0;
      accX := 0;
      startX := endX;
      startY := endY;
      prevX := startX;
      prevY := startY;
      if endX + 3 > 49 then
        backX := endX - 49
      else if endX < 3 then
        backX := 3 - endX;
      if endY + 3 > 24 then
        backY := endY - 24
      else if endY < 3 then
        backY := 3 - endY;
      camX := endX + backX;
      camY := endY + backY;
      CbtMap.ScrollView(camX, camY, 255, 8);
      pixX := (endX - GDVars.arena^.originX) * 3;
      pixY := (endY - GDVars.arena^.originY) * 3;
      stepIndex := count;
      stopPath := False;
      repeat
        stepX := -GDConsts.dirDeltaX[steps[stepIndex]];
        stepY := -GDConsts.dirDeltaY[steps[stepIndex]];
        Inc(pixX, stepX);
        Inc(pixY, stepY);
        if pixX > 18 then
          startX := GDVars.arena^.originX + 6
        else if pixX < 0 then
          startX := GDVars.arena^.originX;
        if pixY > 18 then
          startY := GDVars.arena^.originY + 6
        else if pixY < 0 then
          startY := GDVars.arena^.originY;
        if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then
          stopPath := True;
        if not stopPath then begin
          Inc(accX, stepX);
          Inc(accY, stepY);
          if Abs(accX) = 3 then begin
            Inc(startX, Pathing.SignOf(accX));
            Inc(camX, Pathing.SignOf(accX));
            accX := 0;
          end;
          if Abs(accY) = 3 then begin
            Inc(startY, Pathing.SignOf(accY));
            Inc(camY, Pathing.SignOf(accY));
            accY := 0;
          end;
          Dec(stepIndex);
        end;
      until stopPath;
    end else begin
      lastPass := True;
      if not CbtMap.ViewCoordsValid(endX - GDVars.arena^.originX, endY - GDVars.arena^.originY) then
        CbtMap.ScrollView(endX, endY, 3, 8);
      pixX := (endX - GDVars.arena^.originX) * 3;
      pixY := (endY - GDVars.arena^.originY) * 3;
      Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.viewPicture, GDVars.egaDest);
      if pace > 0 then begin
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.saveUnder, GDVars.egaDest);
      end;
    end;
  until lastPass;
  Blit.FlushView;
end;

procedure PrintNameStringAnim;
var
  { flash pixel x }
  pixelX: ShortInt;
  { flash pixel y }
  pixelY: ShortInt;
  { icon sheet cell }
  cell: Byte;
  { frame index }
  frameIndex: Byte;
  { repetition index }
  repeatIndex: Byte;
  { flash repetitions }
  repeatCount: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    if effect <> 0 then
      cell := 22
    else
      cell := 23;
    CharHlp.BuildIconFacings(cell);
    if not CbtMap.CombatIconVisible(character, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), 3, 8);
    if effect <> 0 then
      SoundDrv.SoundCommand(GDConsts.soundIds[0])
    else
      SoundDrv.SoundCommand(GDConsts.damageSnd);
    CharHlp.PrintCreatureMessage(character, message, 10, False);
    if effect <> 0 then
      repeatCount := GDVars.gameDelay
    else
      repeatCount := 0;
    pixelX := GDVars.gridX[CbtMap.CombatSlot(character)] * 3;
    pixelY := GDVars.gridY[CbtMap.CombatSlot(character)] * 3;
    for repeatIndex := 0 to repeatCount do
      for frameIndex := 0 to 3 do begin
        Blit.BlitTileClipped(pixelX, pixelY, frameIndex, 5, GDVars.viewPicture, GDVars.egaDest);
        Blit.FlushView;
        Delay(70);
        Blit.BlitTileClipped(pixelX, pixelY, 0, 0, GDVars.saveUnder, GDVars.egaDest);
      end;
    Blit.FlushView;
    if repeatCount = 0 then
      TextRend.pauseOnly;
  end else
    CharHlp.PrintCreatureMessage(character, message, 10, True);
end;

function HasEffect;
var
  found: Boolean;
begin
  found := False;
  Types.PEffectRec(matchedEffect) := Types.PCharRecord(character)^.effects;
  while (Types.PEffectRec(matchedEffect) <> nil) and not found do begin
    if Types.PEffectRec(matchedEffect)^.id = id then
      found := True
    else
      Types.PEffectRec(matchedEffect) := Types.PEffectRec(matchedEffect)^.next;
  end;
  HasEffect := found;
end;

procedure InflictDamage;
var
  { damage past 0 hp }
  excessDamage: Byte;
  { hp left }
  remainingHp: Byte;
begin
  excessDamage := 0;
  remainingHp := 0;
  if Types.PCharRecord(character)^.hpCur >= damage then
    remainingHp := Types.PCharRecord(character)^.hpCur - damage
  else
    excessDamage := damage - Types.PCharRecord(character)^.hpCur;
  if (excessDamage > 9) or
      ((remainingHp = 0) and (ShortInt(Types.PCharRecord(character)^.status) = C_Status.ANIMATED)) then
    ShortInt(Types.PCharRecord(character)^.status) := C_Status.DEAD_STATUS
  else if excessDamage > 0 then begin
    ShortInt(Types.PCharRecord(character)^.status) := C_Status.DYING;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      Types.PCharRecord(character)^.combatAddr^.overkill := excessDamage;
  end else if remainingHp = 0 then
    ShortInt(Types.PCharRecord(character)^.status) := C_Status.UNCONSCIOUS;
  if not (ShortInt(Types.PCharRecord(character)^.status) in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    Types.PCharRecord(character)^.inPlay := 0;
    Types.PCharRecord(character)^.hpCur := 0;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.teamCount[Types.PCharRecord(character)^.hostile]);
      Types.PCharRecord(character)^.combatAddr^.initiative := 0;
    end;
  end else
    Types.PCharRecord(character)^.hpCur := remainingHp;
end;

procedure AnnounceHealStatus;
var
  message: Types.TStr40;
begin
  if Types.PCharRecord(character)^.hpCur = Types.PCharRecord(character)^.hpMax then
    message := 'is fully healed'
  else
    message := 'is partially healed';
  CharHlp.PrintCreatureMessage(character, message, 10, True);
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
    CharHlp.DisplayParty(GDVars.curChar);
end;

function EnemyTeam;
begin
  if Types.PCharRecord(character)^.hostile = C_Side.PLAYER then
    EnemyTeam := C_Side.ENEMY
  else
    EnemyTeam := C_Side.PLAYER;
end;

procedure CountTeams;
var
  member: Types.PCharRecord;
begin
  GDVars.teamCount[C_Side.PLAYER] := 0;
  GDVars.teamCount[C_Side.ENEMY] := 0;
  member := GDVars.partyHead;
  while member <> nil do begin
    if member^.inPlay <> 0 then
      Inc(GDVars.teamCount[member^.hostile]);
    member := member^.next;
  end;
end;

function CountTargets;
var
  { list count }
  listCount: Byte;
  { opposing-team count }
  enemyCount: Byte;
  { loop index }
  targetPos: Byte;
  { HasEffect's out-node }
  effectNode: Pointer;
  { stop after one swap }
  swapped: Boolean;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), rangeLimit, 255,
                          CbtMap.GetIconSize(character), GDVars.arena);
  listCount := GDVars.targetCount;
  enemyCount := 0;
  if listCount > 0 then begin
    for targetPos := 1 to listCount do
      if CharHlp.EnemyTeam(character) =
          GDVars.creatureArr[GDVars.targetList[targetPos].creatureIndex]^.hostile then begin
        Inc(enemyCount);
        Move(GDVars.targetList[targetPos], GDVars.targetList[enemyCount], SizeOf(GDVars.targetList[targetPos]));
      end;
    listCount := enemyCount;
    GDVars.targetCount := enemyCount;
  end;
  CountTargets := listCount;
  for targetPos := 1 to listCount do
    GDVars.targetIdx[targetPos] := GDVars.targetList[targetPos].creatureIndex;
  if CharHlp.HasEffect(character, 91, effectNode) then begin
    targetPos := 1;
    swapped := False;
    while (targetPos <= listCount) and not swapped do begin
      if GDVars.creatureArr[GDVars.targetIdx[targetPos]] = GDVars.yellTarget then begin
        enemyCount := GDVars.targetIdx[1];
        GDVars.targetIdx[1] := GDVars.targetIdx[targetPos];
        GDVars.targetIdx[targetPos] := enemyCount;
        swapped := True;
      end;
      Inc(targetPos);
    end;
  end;
end;

function CalcDistance;
var
  savedTargets: array[1..255] of Types.TTargetRec;
  targetPos: Byte;
begin
  Move(GDVars.targetList, savedTargets, SizeOf(GDVars.targetList));
  GDVars.arena^.ignoreTerrain := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(character), CbtMap.CombatCellY(character), 255, 255,
                          CbtMap.GetIconSize(character), GDVars.arena);
  GDVars.arena^.ignoreTerrain := 0;
  targetPos := 1;
  while (GDVars.creatureArr[GDVars.targetList[targetPos].creatureIndex] <> target) and
      (targetPos < GDVars.targetCount) do
    Inc(targetPos);
  CalcDistance := GDVars.targetList[targetPos].distance shr 1;
  Move(savedTargets, GDVars.targetList, SizeOf(GDVars.targetList));
end;

function EndActions;
begin
  Types.PCharRecord(character)^.combatAddr^.initiative := 0;
  Types.PCharRecord(character)^.combatAddr^.spellCast := 0;
  Types.PCharRecord(character)^.combatAddr^.guarding := 0;
  Types.PCharRecord(character)^.combatAddr^.movement := 0;
  EndActions := True;
end;

function Guard;
begin
  Guard := CharHlp.EndActions(character);
  if Types.PCharRecord(character)^.combatAddr^.turned = 0 then begin
    Types.PCharRecord(character)^.combatAddr^.guarding := 1;
    CharHlp.PrintBottomLine('Guarding');
  end;
end;

function GetCasterLevel;
var
  primaryLevel: ShortInt;
  secondaryLevel: ShortInt;
  lookupValue: Word;
begin
  if (GDVars.curChar^.classLevels[C_Class.CLERIC] = 0) and
      (GDVars.curChar^.classLevels[C_Class.MAGE] = 0) and
      (GDVars.curChar^.classLevels[C_Class.KNIGHT] < 9) and
      (GDVars.curChar^.classLevels[C_Class.RANGER] < 8) then
    GetCasterLevel := 6
  else
    case GDConsts.spellTbl[spellId].castClass of
      0, 2:
        begin
          primaryLevel := GDVars.curChar^.classLevels[C_Class.CLERIC] +
              GDVars.curChar^.classLevels2[C_Class.CLERIC]
                  * ShortInt(ClassCal.EarlierClassActive(GDVars.curChar));
          secondaryLevel := GDVars.curChar^.classLevels[C_Class.KNIGHT] +
              GDVars.curChar^.classLevels2[C_Class.KNIGHT]
                  * ShortInt(ClassCal.EarlierClassActive(GDVars.curChar)) - 8;
          if primaryLevel > secondaryLevel then
            GetCasterLevel := primaryLevel
          else
            GetCasterLevel := secondaryLevel;
        end;
      1:
        begin
          primaryLevel := GDVars.curChar^.classLevels[C_Class.RANGER] +
              GDVars.curChar^.classLevels2[C_Class.RANGER]
                  * ShortInt(ClassCal.EarlierClassActive(GDVars.curChar)) - 7;
          if primaryLevel > 0 then
            GetCasterLevel := primaryLevel
          else
            GetCasterLevel := 0;
        end;
      3:
        begin
          primaryLevel := GDVars.curChar^.classLevels[C_Class.MAGE] +
              GDVars.curChar^.classLevels2[C_Class.MAGE]
                  * ShortInt(ClassCal.EarlierClassActive(GDVars.curChar));
          secondaryLevel := GDVars.curChar^.classLevels[C_Class.RANGER] +
              GDVars.curChar^.classLevels2[C_Class.RANGER]
                  * ShortInt(ClassCal.EarlierClassActive(GDVars.curChar)) - 8;
          if (GDVars.curChar^.classLevels[C_Class.MAGE] > 0) and (GDVars.curChar^.robeOrder > 0) then begin
            lookupValue := GDVars.curChar^.robeOrder + 504;
            case GDVars.zone0^.vars[lookupValue + 19200] of
              0: Dec(primaryLevel);
              2: if GDVars.curChar^.classLevels[C_Class.MAGE] > 5 then
                   Inc(primaryLevel);
            end;
          end;
          if primaryLevel > secondaryLevel then
            GetCasterLevel := primaryLevel
          else
            GetCasterLevel := secondaryLevel;
        end;
      4:
        GetCasterLevel := 12;
    end;
  if (GDVars.usingItemFlag <> 0) and (GDConsts.spellTbl[spellId].castClass <> 4) then
    GetCasterLevel := 6;
end;

procedure DisplayNoncombatInterface;
begin
  GDVars.pictureRedrawRequested := 1;
  case GDVars.interfaceState of
    C_Ifc.MAIN_MENU: Border.DrawWindowFrame(True);
    C_Ifc.SHOP_TEMPLE: begin
         if GDVars.drawFlag <> 0 then
           Border.DrawViewFrame;
         if GDVars.zone0^.view3dFlag = 0 then
           Portrait.DisplayImageBuf(3, 3, True, GDVars.bigAnim.frames[1].image)
         else begin
           Portrait.LoadPortraitBufs(GDVars.portraitHeadId, GDVars.portraitBodyId);
           Portrait.DisplayPortraitBufs(3, 3, True);
         end;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    C_Ifc.CAMPING: begin
         Border.DrawViewFrame;
         Portrait.LoadAnimation('PIC', 59, 0, GDVars.bigAnim);
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
       end;
    C_Ifc.VIEW_3D: begin
         Border.DrawViewFrame;
         if GDVars.zone0^.areaView = 0 then
           MapView.DisplayMapView;
         CharHlp.DisplayParty(GDVars.curChar);
         CharHlp.PrintPositionAndTime;
         GDVars.enteringLoop := 0;
       end;
    C_Ifc.OVERLAND: if (GDVars.picArcId <> 9) and (GDVars.zone0^.areaView = 0) then
         MapView.DisplayMapView;
    C_Ifc.LOOT: begin
         Border.DrawViewFrame;
         Portrait.LoadAnimation('PIC', 60, 0, GDVars.bigAnim);
         CharHlp.DisplayParty(GDVars.curChar);
       end;
  end;
end;

procedure PrintPositionAndTime;
var
  mapX: Byte;
  mapY: Byte;
  hourText: String[2];
  minuteText: String[2];
  infoText: Types.TStr40;
  directionIndex: Byte;
begin
  if GDVars.interfaceState = C_Ifc.OVERLAND then Exit;
  infoText := '';
  mapX := GDVars.mapState.x;
  mapY := GDVars.mapState.y;
  hourText := CharHlp.Uint16Str(GDVars.zone0^.hours);
  if Length(hourText) < 2 then
    hourText := '0' + hourText;
  minuteText := CharHlp.Uint16Str(10 * GDVars.zone0^.min10 + GDVars.zone0^.minLo);
  if Length(minuteText) < 2 then
    minuteText := '0' + minuteText;
  if GDVars.zone0^.areaLock = 0 then
    infoText := CharHlp.Uint8Str(mapX) + ',' + CharHlp.Uint8Str(mapY) + ' ';
  if GDVars.zone0^.view3dFlag <> 0 then
    directionIndex := GDVars.zone0^.facingOffset * 2 + GDVars.mapState.facing
  else
    directionIndex := GDVars.mapState.facing + GDVars.zone0^.facingOffset;
  if directionIndex >= 8 then
    Dec(directionIndex, 8);
  infoText := infoText + GDConsts.dirNames[directionIndex] + ' ';
  infoText := infoText + hourText + ':' + minuteText;
  if GDVars.debugActive <> 0 then
    infoText := infoText + '*';
  if GDVars.interfaceState = C_Ifc.CAMPING then
    infoText := infoText + ' camping'
  else if GDVars.zone1^.searchFlags and $01 > 0 then
    infoText := infoText + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.displayString(17, 15, LightGreen, Black, infoText);
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawCombatFrame;
  CbtMap.ScrollView(GDVars.arena^.originX + 3, GDVars.arena^.originY + 3, 255, 8);
end;

function HasRangedWeapon;
begin
  if (Types.PCharRecord(character)^.equipped[0] <> nil) and
      (GDVars.baseItems[Types.PCharRecord(character)^.equipped[0]^.itemType].range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

function HasReadiedHoopak;
begin
  if (Types.PCharRecord(character)^.equipped[0] <> nil) and
      (Types.PCharRecord(character)^.equipped[0]^.itemType = C_Item.HOOPAK) then
    HasReadiedHoopak := True
  else
    HasReadiedHoopak := False;
end;

function HasThrowableWeapon;
begin
  if CharHlp.HasRangedWeapon(character) and
      (((GDVars.baseItems[Types.PCharRecord(character)^.equipped[0]^.itemType].props and $14) = $14) or
       (Types.PCharRecord(character)^.equipped[0]^.itemType = C_Item.HOOPAK)) then
    HasThrowableWeapon := True
  else
    HasThrowableWeapon := False;
end;

function FindDamagingRangedWeapon;
var
  item: Types.PItemRec;
  properties: Byte;
begin
  FindDamagingRangedWeapon := False;
  item := Types.PCharRecord(character)^.equipped[0];
  Types.PItemRec(weapon) := nil;
  properties := 0;
  if item <> nil then begin
    properties := GDVars.baseItems[item^.itemType].props;
    if (properties and $10) <> 0 then
      Types.PItemRec(weapon) := item;
    if (properties and $08) <> 0 then begin
      if (properties and $01) <> 0 then
        Types.PItemRec(weapon) := Types.PCharRecord(character)^.equipped[11];
      if (properties and $80) <> 0 then
        Types.PItemRec(weapon) := Types.PCharRecord(character)^.equipped[12];
    end;
  end;
  if (Types.PItemRec(weapon) <> nil) or (properties = $A) then
    FindDamagingRangedWeapon := True;
end;

function BandageDying;
var
  member: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  member := GDVars.partyHead;
  while member <> nil do begin
    if (member^.combatAddr^.nonPartyMember = 0) and (member^.hostile = C_Side.PLAYER) and
        (ShortInt(member^.status) = C_Status.DYING) then begin
      found := True;
      if applyBandage then begin
        ShortInt(member^.status) := C_Status.UNCONSCIOUS;
        member^.combatAddr^.overkill := 0;
        CharHlp.PrintCreatureMessage(member, 'is bandaged', 10, True);
        applyBandage := False;
      end;
    end;
    member := member^.next;
  end;
  BandageDying := found;
end;

procedure SelectChar;
var
  key: Byte;
  { MenuHorizontal's extended-key result }
  extendedKey: Boolean;
  animateMenu: Byte;
  cursor: Types.PCharRecord;
  exitPrompt: Types.TStr40;
  savedMouseMode: Byte;
begin
  savedMouseMode := GDVars.partyPickEnabled;
  GDVars.useAlternateSelection := Byte(useAlternate);
  GDVars.altChar := GDVars.curChar;
  key := 32;
  exitPrompt := '';
  if allowExit then
    exitPrompt := ' Exit';
  while not (key in [Ord(C_Keys.ENTER), Ord(C_Keys.ESCAPE), Ord('E'), Ord('S')]) do begin
    CharHlp.DisplayParty(Types.PCharRecord(selection));
    if (GDVars.interfaceState = C_Ifc.CAMPING) or (GDVars.interfaceState = C_Ifc.LOOT) then
      animateMenu := 1
    else
      animateMenu := 0;
    if GDVars.interfaceState = C_Ifc.MAIN_MENU then
      GDVars.partyPickEnabled := 1;
    key := Byte(MenuCore.MenuHorizontal(query + ' ', 'Select' + exitPrompt, LightMagenta, LightGreen, White, True,
                                        Boolean(animateMenu), extendedKey));
    GDVars.partyPickEnabled := savedMouseMode;
    cursor := Types.PCharRecord(selection);
    if extendedKey then begin
      case key of
        Ord(C_Keys.DOWN): begin
               cursor := cursor^.next;
               if cursor = nil then
                 cursor := GDVars.partyHead;
             end;
        Ord(C_Keys.UP): if GDVars.mouseButtonSeen <> 0 then begin
               if GDVars.useAlternateSelection <> 0 then
                 cursor := GDVars.altChar
               else
                 cursor := GDVars.curChar;
             end else begin
               cursor := GDVars.partyHead;
               if Types.PCharRecord(selection) <> GDVars.partyHead then
                 while cursor^.next <> Types.PCharRecord(selection) do
                   cursor := cursor^.next
               else
                 while cursor^.next <> nil do
                   cursor := cursor^.next;
             end;
      end;
    end else begin
      if allowExit and ((key = Ord('E')) or (key = 0)) then
        cursor := nil;
    end;
    Types.PCharRecord(selection) := cursor;
  end;
  GDVars.useAlternateSelection := 0;
end;

function DirTowardTarget;
var
  dir: Byte;
  found: Boolean;
  x1: Integer;
  y1: Integer;
  x2: Integer;
  y2: Integer;
  deltaX: Integer;
  deltaY: Integer;
begin
  x1 := CbtMap.CombatCellX(creature);
  y1 := CbtMap.CombatCellY(creature);
  x2 := CbtMap.CombatCellX(other);
  y2 := CbtMap.CombatCellY(other);
  deltaX := Abs(x2 - x1);
  deltaY := Abs(y2 - y1);
  dir := C_Dir.NORTH;
  found := False;
  while not found do begin
    case dir of
      C_Dir.NORTH: found := (y2 <= y1) and ((C_Dir.OCTANT_STEEP * deltaX) div 256 <= deltaY);
      C_Dir.EAST: found := (x2 >= x1) and ((C_Dir.OCTANT_SHALLOW * deltaX) div 256 >= deltaY);
      C_Dir.SOUTH: found := (y2 >= y1) and ((C_Dir.OCTANT_STEEP * deltaX) div 256 <= deltaY);
      C_Dir.WEST: found := (x2 <= x1) and ((C_Dir.OCTANT_SHALLOW * deltaX) div 256 >= deltaY);
      C_Dir.NORTHEAST: found := (y2 < y1) and (x2 > x1) and
        ((C_Dir.OCTANT_STEEP * deltaX) div 256 >= deltaY) and
        ((C_Dir.OCTANT_SHALLOW * deltaX) div 256 <= deltaY);
      C_Dir.SOUTHEAST: found := (y2 > y1) and (x2 > x1) and
        ((C_Dir.OCTANT_STEEP * deltaX) div 256 >= deltaY) and
        ((C_Dir.OCTANT_SHALLOW * deltaX) div 256 <= deltaY);
      C_Dir.SOUTHWEST: found := (y2 > y1) and (x2 < x1) and
        ((C_Dir.OCTANT_STEEP * deltaX) div 256 >= deltaY) and
        ((C_Dir.OCTANT_SHALLOW * deltaX) div 256 <= deltaY);
      C_Dir.NORTHWEST: found := (y2 < y1) and (x2 < x1) and
        ((C_Dir.OCTANT_STEEP * deltaX) div 256 >= deltaY) and
        ((C_Dir.OCTANT_SHALLOW * deltaX) div 256 <= deltaY);
    end;
    if not found then
      Inc(dir);
  end;
  DirTowardTarget := dir;
end;

function ClassSuborderIndex;
var
  resultIndex: Byte;
begin
  case classCode of
    0: if Types.PCharRecord(character)^.deity <= 4 then
         resultIndex := 0
       else
         resultIndex := 1;
    7: case Types.PCharRecord(character)^.knightOrder of
         1: resultIndex := 3;
         2: resultIndex := 4;
         3: resultIndex := 5;
       end;
    2: resultIndex := 2;
    4: resultIndex := 6;
    5: if Types.PCharRecord(character)^.robeOrder = 1 then
         resultIndex := 7
       else
         resultIndex := 8;
    6: resultIndex := 9;
  end;
  ClassSuborderIndex := resultIndex;
end;

begin
end.
