{ Record and type declarations shared by the units; the unit contributes no code. Units that pass these records to one
  another must use these declarations, since separately declared copies are different Pascal types. }
{$F+,O-,I-,R-,S-}
{$A-}
unit Types;

interface

uses C_Gbvm;

type
  TStr2 = String[2];
  TStr8 = String[8];
  TStr40 = String[40];
  TStr80 = String[80];

  { An inventory or treasure item node. The menus reuse its leading fields (name, inUse, next) as their string-list
    node. }
  PItemRec = ^TItemRec;
  TItemRec = record
    name: String[40];
    inUse: Byte;
    next: PItemRec;
    itemType: Byte;
    nameIds: array[1..3] of Byte;
    plus: ShortInt;
    saveBonus: ShortInt;
    equipped: Byte;
    unidMask: Byte;
    cursed: Byte;
    weight: Word;
    quantity: Byte;
    value: Word;
    case Byte of
      0: (charges: Byte;
          effect: Byte;
          special: Byte);
      { a scroll: its three spells }
      1: (spells: array[1..3] of Byte);
  end;

  { A string-list node: the leading fields of an item record. }
  PCharacterListNode = ^TCharacterListNode;
  TCharacterListNode = record
    name: String[40];
    inUse: Byte;
    next: PCharacterListNode;
  end;

  { An effect node: one active effect on a creature (TCharRecord.effects heads the list). }
  PEffectRec = ^TEffectRec;
  TEffectRec = record
    { effect id }
    id: Byte;
    duration: Word;
    strength: Byte;
    onRemove: Byte;
    next: PEffectRec;
  end;

  { The party's treasure pool: one count per coin type, indexed like TCharRecord.coinsA. }
  TMoney = array[0..6] of LongInt;

  { One joystick's calibration, GDVars.joyCalib[1..2]: for each axis the low extreme, two boundaries, the center, two
    boundaries and the high extreme. }
  TJoyAxis = array[0..6] of Word;
  TJoyCalibration = record
    x: TJoyAxis;
    y: TJoyAxis;
  end;

  { One class-progression row, GDConsts.classProgression[0..9]: the experience needed to reach each level (-1 = none)
    and the spell slots gained there, by spell level. }
  TClassProgression = record
    nextLevelXp: array[2..12] of LongInt;
    spellSlots: array[2..12, 1..5] of Byte;
  end;

  { One combatant's arena cell, GDVars.arenaLoc[1..72]: its position, the slot index CombatSt stores in it, and its icon
    size. }
  TArenaLoc = record
    x: ShortInt;
    y: ShortInt;
    { the combatant's own slot }
    combatantIndex: Byte;
    { icon size; 0 = out of play }
    size: Byte;
  end;

  { One entry of Pathing's target list, GDVars.targetList[1..72]: the creature reached, its walking distance (doubled)
    and the direction toward it. }
  TTargetRec = record
    { index into GDVars.creatureArr }
    creatureIndex: Byte;
    distance: Byte;
    direction: Byte;
  end;

  { One combat terrain type, GDConsts.terrainInfo[1..65]; each arena cell holds the number of its terrain. }
  TTerrainRec = record
    { 255 = impassable }
    movementCost: Byte;
    clearance: Byte;
    blocking: Byte;
    { the 2D tile drawn for it; tile 22 is open grass or floor }
    tileId: Byte;
  end;

  { The offset from an icon's position to one of its tiles, GDConsts.iconDelta[size, tile]; -1, -1 marks a tile that
    icon size does not have. }
  TIconDelta = record
    deltaX: ShortInt;
    deltaY: ShortInt;
  end;

  { An effect handler: GDVars.effectHandlers[1..119] and overrideHandler. It applies or removes one effect on a creature
    (passed by reference) with the handler data. }
  TEffectHandler = procedure(var creature; handlerData: Pointer; removed: Boolean);

  { A spell handler, GDVars.spellDispatch[1..107]. }
  TSpellProc = procedure;
  { The cast-target menu, GDVars.castTargetMenu. }
  TCastTargetProc = procedure(spell: Byte; b: Boolean; var cast: Boolean);

  { One spell-table row, GDConsts.spellTbl[1..107]; spell ids index it. }
  TSpellRec = record
    castClass: ShortInt;
    level: ShortInt;
    rangeBase: Byte;
    rangePerLevel: Byte;
    durBase: Byte;
    durPerLevel: Byte;
    { packed area/touch bits }
    area: Byte;
    targeting: Byte;
    { what a successful save does; 0 = no save }
    saveEffect: Byte;
    saveType: Byte;
    { effect id }
    effect: Byte;
    { 0 = camp-only spell }
    combatOk: Byte;
    castTime: Byte;
    { 0 = the AI never casts it }
    aiPriority: Byte;
    { 1 = offensive }
    offensive: Byte;
    { friendly-fire scan radius }
    aiRadius: Byte;
  end;

  { The EGA-16 -> CGA-4 color map: 16 nibbles in 8 bytes. }
  TColorMap = array[0..7] of Byte;
  { A byte buffer: a DAX resource as loaded, or a picture's transparency mask. }
  PBytes = ^TBytes;
  TBytes = array[0..65534] of Byte;
  PImgBuf = ^TImgBuf;
  { An image buffer: the header, then the image data. LoadPic fills height..map from the DAX picture header. }
  TImgBuf = record
    { image height in pixels }
    height: Word;
    { image width in character cells of 8 pixels }
    width: Word;
    { draw origin column (DAX header) }
    originX: Word;
    { draw origin row (DAX header) }
    originY: Word;
    { images in buffer }
    count: Byte;
    { EGA->CGA color map }
    map: TColorMap;
    { bytes in one image }
    imgSize: Word;
    { extra transparency space (default nil) }
    transp: PBytes;
    { image data (open-ended) }
    data: array[0..32000] of Byte;
  end;
  { RemapPic's from/to color tables, passed by value. }
  TColorTab = array[0..15] of Byte;
  { One animation frame: the 4 header bytes from the file, which MenuCore times as the frame duration, and the frame's
    image. }
  TAnimationFrame = record
    duration: LongInt;
    image: PImgBuf;
  end;
  { The big-picture animation record, GDVars.bigAnim. }
  TAnimation = record
    { loaded frame count }
    frameCount: Byte;
    { rotating display frame }
    currentFrame: Byte;
    frames: array[1..8] of TAnimationFrame;
  end;

  { One portrait slot, GDVars.portraits[1..2] (head, body): the loaded picture's file id ($FF = none) and its image. }
  TPortraitSlot = record
    fileId: Byte;
    pic: PImgBuf;
  end;

  { A cloud / acid-pool node, the lists at GDVars.cloudHead and acidPoolHead: the creature that owns it, the next node,
    the terrain saved under each of its 9 cells and which of them are live, its center, the owner's instance number and
    the spent flag. }
  PCloudNode = ^TCloudNode;
  TCloudNode = record
    owner: Pointer;
    next: PCloudNode;
    terrainCells: array[1..9] of Byte;
    activeCells: array[1..9] of Byte;
    x: ShortInt;
    y: ShortInt;
    instanceId: Byte;
    spent: Byte;
  end;

  { The seven-component game clock, [0] ticks to [6] years; GDConsts.unitScale holds each component's modulus. }
  TClock = array[0..6] of Word;

  { The effect handlers' scratch, GDVars.effectScratch: the morale adjustment the morale effects raise and lower, and
    the creature a handler is working on. }
  TEffectScratch = record
    morale: Byte;
    other: Pointer;
  end;

  { Which monster pictures EclMenu.DisplayMonster has shown, GDVars.monFlags: [0] the distant sprite, [1] the close-up
    picture. }
  TMonFlags = array[0..1] of Boolean;

  { INT 33h graphics cursor block: 16 screen-mask words followed by 16 cursor-mask words. Mouse.SetMouseCursor takes a
    far pointer to it. }
  PCursorMask = ^TCursorMask;
  TCursorMask = array[0..63] of Byte;

  { An overlay read routine, the shape of OvrReadBuf: GDVars.previousOverlayReadVector keeps the overlay manager's
    original, which GameIo.OverlayReadWithBeep retries. }
  TOverlayReadFunc = function(ovrSeg: Word): Integer;

  { A combatant's per-combat record (TCharRecord.combatAddr points here). }
  PCombatRec = ^TCombatRec;
  TCombatRec = record
    { queued spell id }
    spellCast: Byte;
    castOk: Byte;
    itemUseAllowed: Byte;
    initiative: ShortInt;
    attackPhase: Byte;
    sweepBudget: Byte;
    movement: Byte;
    guarding: Byte;
    madeAttack: Byte;
    facing: Byte;
    { the creature it attacks or targets }
    target: Pointer;
    { damage taken past 0 hp; counts up each dying turn, dead past 9 }
    overkill: Byte;
    flankCount: Byte;
    turned: Byte;
    turnUses: Byte;
    flankSpread: Byte;
    { 0 = party member }
    nonPartyMember: Byte;
    fleeing: Byte;
    aiStance: Byte;
  end;

  { The 6 icon color bytes of a character record. }
  TIconColors = array[1..6] of Byte;
  { One ability score: the base value and the current (adjusted) one. }
  TStatPair = record
    base: Byte;
    cur: Byte;
  end;
  { The character / creature record. }
  PCharRecord = ^TCharRecord;
  TCharRecord = record
    name: String[15];
    { Str, Int, Wis, Dex, Con, Cha }
    stats: array[0..5] of TStatPair;
    strExc: Byte;
    strExcBase: Byte;
    memorized: array[0..57] of Byte;
    { signed }
    spellPrep: ShortInt;
    thac0Base: Byte;
    race: ShortInt;
    charClass: ShortInt;
    { 1 Crown, 2 Sword, 3 Rose }
    knightOrder: Byte;
    deity: ShortInt;
    robeOrder: Byte;
    { knight-level bracket: (knight levels - 1) div 5 + 1 }
    levelBucket: Byte;
    age: Word;
    hpMax: Byte;
    spellsKnown: array[1..107] of Byte;
    { CbtActs' sweep-attack budget }
    attackLevel: Byte;
    iconDimensions: Byte;
    { the five saving throws }
    saves: array[0..4] of Byte;
    { base movement; CharGen sets 12 }
    movementBase: Byte;
    levelHighest: ShortInt;
    dualClassThreshold: ShortInt;
    { levels lost to energy drain }
    drainedLevels: Byte;
    { hit points lost with them }
    drainedHps: Byte;
    levelUndead: ShortInt;
    thiefSkills: array[1..8] of Byte;
    effects: PEffectRec;
    npc: Byte;
    modified: Byte;
    modifiedTail: array[$0E9..$0EA] of Byte;
    coinsA: array[0..6] of Word;
    classLevels: array[0..7] of ShortInt;
    classLevels2: array[0..7] of ShortInt;
    gender: ShortInt;
    alignment: ShortInt;
    attacks: Byte;
    attacks2: Byte;
    unarmedRolls: array[1..2] of Byte;
    unarmedDice: array[1..2] of Byte;
    unarmedMod: array[1..2] of ShortInt;
    { base armor class; CharGen sets $32 }
    acBase: Byte;
    { CharGen sets 1 }
    useStrength: Byte;
    creatureId: Byte;
    experience: LongInt;
    { class bitmask; ANDed with an item's classMask }
    classMask: Byte;
    hpRolled: Byte;
    slots: array[0..3, 1..5] of Byte;
    xpAward: Word;
    xpBonusPerHp: Byte;
    xpBonusPerHpTail: array[$133..$134] of Byte;
    iconHead: Byte;
    iconBody: Byte;
    orderNumber: Byte;
    iconSize: Byte;
    iconColors: TIconColors;
    charType: Byte;
    targetFlags: Byte;
    targetFlagsTail: Byte;
    itemCount: Byte;
    itemsAddr: PItemRec;
    equipped: array[0..12] of PItemRec;
    handsEquipped: Byte;
    saveBonus: ShortInt;
    { carried weight; Money maintains it }
    encumbrance: Word;
    next: PCharRecord;
    combatAddr: PCombatRec;
    { magic-resistance percent }
    magicResistance: Byte;
    status: Byte;
    inPlay: Byte;
    hostile: ShortInt;
    quickfight: Byte;
    thac0Adj: Byte;
    { armor class: [0] front, [1] from behind }
    acCur: array[0..1] of Byte;
    curAtt: array[1..2] of Byte;
    curRolls: array[1..2] of Byte;
    curDice: array[1..2] of Byte;
    curMod: array[1..2] of ShortInt;
    hpCur: Byte;
    movementCur: Byte;
  end;

  { The state of a line walk across the arena (Pathing.PathFind, NextPathStep). }
  TPathState = record
    startX: Integer;
    startY: Integer;
    endX: Integer;
    endY: Integer;
    error: Integer;
    deltaX: Integer;
    deltaY: Integer;
    currentX: Integer;
    currentY: Integer;
    { x step (-1/0/1), word }
    stepX: Integer;
    { y step (-1/0/1), word }
    stepY: Integer;
    { doubled distance walked }
    distance: Byte;
    { direction of last step (0..8) }
    lastDirection: Byte;
  end;

  { The combat arena, GDVars.arena, which CombatSt allocates: the cell at the view's upper left, the cursor CbtMap
    draws, the switch that makes Pathing.WalkLine ignore terrain, and each cell's terrain number, [row, column]. }
  PArena = ^TArena;
  TArena = record
    originXLead: array[0..1] of Byte;
    originX: ShortInt;
    originY: ShortInt;
    { CbtMap draws the cursor icon while it is True }
    cursorOn: Boolean;
    cursorSize: Byte;
    { nonzero while a target-list build measures distance: terrain does not stop the walk }
    ignoreTerrain: Byte;
    { indices into GDConsts.terrainInfo }
    cells: array[0..24, 0..49] of Byte;
  end;

  { An ECL GOSUB return-stack node, GDVars.eclStack: the GBVM address to return to and the node below. }
  PEclRet = ^TEclRet;
  TEclRet = record
    address: Word;
    next: PEclRet;
  end;

  { A bank-pool node, GDVars.bankHead: an item knocked from its owner's hands, given back after the fight. }
  PBankNode = ^TBankNode;
  TBankNode = record
    item: TItemRec;
    owner: PCharRecord;
    next: PBankNode;
  end;

  { One 8x8 glyph, a byte per row. }
  TGlyph = array[0..7] of Byte;
  { The font, GDVars.gameFont: block 201 of 8X8D1.DAX expands to 177 glyphs, matching GameInit's allocation.
    TextRend.RenderChar does not check the index when translateAscii is zero. }
  PFontTable = ^TFontTable;
  TFontTable = array[0..176] of TGlyph;

  { One wall set of the 3D view: five rows of 156 symbol bytes. }
  TWallDef = array[1..5, 0..155] of Byte;
  { The 3D view's wall graphics, GDVars.wallGfx, which GameInit allocates: written as up to four wall sets (defs) and
    read as one run of symbol rows (slices). Note: GameInit allocates room for three wall sets (2340 bytes), so the
    fourth set and slices 16..20 lie past the allocation. }
  PWallGfx = ^TWallGfx;
  TWallGfx = record
    case Byte of
      0: (defs: array[1..4] of TWallDef);
      1: (slices: array[1..20, 0..155] of Byte);
  end;

  { A downed combatant left on the arena (GDVars.downedCreatures[1..8]): who, where, and the terrain under it. }
  TDownedRec = record
    creature: PCharRecord;
    x: ShortInt;
    y: ShortInt;
    terrain: Byte;
  end;

  { The current ECL script's five entry points, loaded by EclMenu from the script header in this order and called by
    EclVm: vmRun every step, searchLocation on search/look (Explore re-enters it), preCampCheck before the camp menu,
    campInterrupted when camping is interrupted, initialEntry when a script is loaded. }
  TEclEntryPoints = record
    case Byte of
      0: (entries: array[1..5] of Word);
      1: (vmRun: Word; searchLocation: Word; preCampCheck: Word; campInterrupted: Word; initialEntry: Word);
  end;

  { GBVM bank 0, GDVars.zone0: the game-state words scripts read and write by GBVM address (vars), with the ones the
    engine reads itself named. }
  PZone0 = ^TZone0;
  TZone0 = record
    case Byte of
      0: (vars: array[C_Gbvm.ZONE0_BASE..C_Gbvm.ZONE0_TOP] of Word);
      1: (partyXLead: array[$000..$185] of Byte;
          { the party's overland position }
          partyX: Word;
          partyY: Word;
          { the id of the loaded 3D map }
          mapId: Word;
          minLoLead: array[$18C..$18D] of Byte;
          { the clock: minutes, tens of minutes and hours }
          minLo: Word;
          min10: Word;
          hours: Word;
          castLockLead: array[$194..$1C9] of Byte;
          { nonzero where spellcasting is forbidden }
          castLock: Word;
          { nonzero while the party is in a 3D area, where combat uses a dungeon arena; 0 on the wilderness overland }
          view3dFlag: Word;
          gfx1: Word;
          gfx2: Word;
          prevXLead: array[$1D2..$1DF] of Byte;
          { the party's position before its last overland step }
          prevX: Word;
          prevY: Word;
          { the script to return to }
          prevEcl: Word;
          areaLockLead: array[$1E6..$1F5] of Byte;
          { nonzero: no automap and no coordinates in this area }
          areaLock: Word;
          skyIndexNormalLead: array[$1F8..$1F9] of Byte;
          skyIndexNormal: Word;
          skyIndexHighEvent: Word;
          areaViewLead: array[$1FE..$26F] of Byte;
          areaView: Word;
          dungeonLevelLead: array[$272..$3E7] of Byte;
          dungeonLevel: Word;
          mirrorDuel: Word;
          wildOnLead: array[$3EC..$3ED] of Byte;
          wildOn: Word;
          bankFlag: Word;
          { the frame tiles where the interior vertical dividers meet the top border }
          topJunction0: Word;
          topJunction1: Word;
          topJunction2: Word;
          facingOffsetLead: array[$3F8..$3FD] of Byte;
          { a facing bias }
          facingOffset: Word);
  end;

  { GBVM bank 1, GDVars.zone1: the encounter, combat and interpreter words, by GBVM address (vars) and by name. }
  PZone1 = ^TZone1;
  TZone1 = record
    case Byte of
      0: (vars: array[C_Gbvm.ZONE1_BASE..C_Gbvm.ZONE1_TOP] of Word);
      1: (trainMaskLead: array[$000..$54F] of Byte;
          trainMask: Word;
          distReqLead: array[$552..$57F] of Byte;
          distReq: Word;
          { the encounter distance }
          monsterDist: Word;
          moraleBaseLead: array[$584..$58B] of Byte;
          { the encounter's morale: allies' base morale and the hostiles' group-morale threshold }
          moraleBase: Word;
          combatResult: Word;
          monstersDef: Word;
          moveLocked: Word;
          searchFlags: Word;
          surpriseMask: Word;
          restPeriodLead: array[$598..$5A3] of Byte;
          { rest-interruption checks: the ticks between them and the chance, in percent }
          restPeriod: Word;
          interruptPct: Word;
          leaveMapLead: array[$5A8..$5A9] of Byte;
          leaveMap: Word;
          picLoadingLead: array[$5AC..$5C1] of Byte;
          picLoading: Word;
          enterTemple: Word;
          noCombatItems: Word;
          reviveFlagLead: array[$5C8..$5CB] of Byte;
          reviveFlag: Word;
          attackedAllyLead: array[$5CE..$665] of Byte;
          attackedAlly: Word;
          partySizeLead: array[$668..$67B] of Byte;
          partySize: Word;
          divRem: Word;
          enterShopLead: array[$680..$6D7] of Byte;
          enterShop: Word;
          { the shop's price scale: 1, 2, 4 .. 128 = price div 16 .. price * 8 }
          priceLevel: Word;
          modMonThac0Lead: array[$6DC..$6DF] of Byte;
          { the to-hit adjustments of monsters and of the party, and the party's movement adjustment }
          modMonThac0: Word;
          modPartyThac0: Word;
          modPartyMove: Word);
  end;

  { GBVM bank 2, GDVars.zone2: words by GBVM address. }
  PZone2 = ^TZone2;
  TZone2 = array[C_Gbvm.ZONE2_BASE..C_Gbvm.ZONE2_TOP] of Word;

  { GBVM bank 3, GDVars.zone3: the loaded ECL script, a byte per GBVM address. }
  PZone3 = ^TZone3;
  TZone3 = array[C_Gbvm.ZONE3_BASE..C_Gbvm.ZONE3_TOP] of Byte;

  { the display adapter the game draws for, GDVars.displayMode }
  TVideoMode = (Cga, Ega, Tandy);
  { TextRend's line-break punctuation }
  TBreakCharSet = set of ' '..'?';
  TRaceLimits = record
    strMin: array[0..1] of Byte;
    strMax: array[0..1] of Byte;
    strExcMax: array[0..1] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;
  TStartAge = record
    base: Word;
    dice: Byte;
    sides: Byte;
  end;
  TAgeLimits = record
    { the top age of each of five bands }
    limit: array[0..4] of Word;
  end;
  { the party's map cell and view; SaveLoad saves all of it }
  TMapState = record
    x: ShortInt;
    y: ShortInt;
    facing: Byte;
    wallAhead: Byte;
    event: Byte;
  end;
  { one loaded wall set: the two arguments View3D's LoadWallSet got }
  TWallSetSlot = record
    { its file id, -1 for none; SaveLoad reloads it only when id > 0 }
    id: Integer;
    { the 8x8 symbol-set slot it was loaded into }
    slot: Integer;
  end;
  { [row, col] = [y, x] }
  TGeoPlane = array[0..15, 0..15] of Byte;
  { the 3D-view map block; GameInit allocates it, View3D loads and draws it }
  TGeoMap = record
    wallsNE: TGeoPlane;
    wallsSW: TGeoPlane;
    events: TGeoPlane;
    barriers: TGeoPlane;
  end;
  PGeoMap = ^TGeoMap;
  { one row of the ITEMS file; GameInit reads 129 rows }
  TBaseItem = record
    slot: Byte;
    hands: Byte;
    dmgLgRolls: Byte;
    dmgLgDice: Byte;
    dmgLgMod: ShortInt;
    rateOfFire: Byte;
    acDescr: Byte;
    defenseFlags: Byte;
    { unused }
    weaponFlag: Byte;
    dmgSmRolls: Byte;
    dmgSmDice: Byte;
    dmgSmMod: ShortInt;
    range: Byte;
    classMask: Byte;
    props: Byte;
    { unused }
    propsTail: Byte;
  end;

  { copy-protection code tables: one record per heading and one per question. Both letter arrays are signed deltas. }
  THeadRec = record
    letters: Byte;
    firstLetter: Byte;
  end;
  TWordRec = record
    wordNo: Byte;
    pageNo: Byte;
    headIdx: Byte;
    letters: Byte;
    firstLetter: Byte;
  end;
  { A party-creation menu entry and whether it starts enabled. }
  TMenuEntry = record
    name: String[40];
    enabled: Byte;
  end;
  { The columns a team may be placed in, for one ring and row of the arena. }
  TBandRec = record
    { valid quadrant-row range }
    firstColumn: ShortInt;
    lastColumn: ShortInt;
  end;
  { One code-word record. wordNo/entryNo/pageNo are the three numbers the prompt displays; letters/firstLetter drive the
    answer regeneration. }
  TCodeRec = record
    wordNo: Byte;
    entryNo: Byte;
    pageNo: Byte;
    letters: Byte;
    firstLetter: Byte;
  end;
  { Per wall slice of the 3D view: where its tiles start, its size and its place on screen. }
  TViewSliceTable = record
    start: array[0..9] of Byte;
    cols: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xCol: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;
  { The register block for software interrupts, laid out as Dos.Registers so storage can hold one without using Dos;
    callers pass it to Intr as a Registers. }
  TRegisters = record
    case Integer of
      0: (ax: Word;
          bx: Word;
          cx: Word;
          dx: Word;
          bp: Word;
          si: Word;
          di: Word;
          ds: Word;
          es: Word;
          flags: Word);
      1: (al: Byte;
          ah: Byte;
          bl: Byte;
          bh: Byte;
          cl: Byte;
          ch: Byte;
          dl: Byte;
          dh: Byte);
  end;

implementation

end.
