{ Global variables: the data segment's variables, grouped by the subsystem that owns them and kept in address order. A
  new section starts wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types;

{ Start-up menu: the title screen's play-or-demo choice. }
var
  { the letter MenuHorizontal returned on the title screen; 'D' starts the demo }
  menuSelection: Char;
  { set when the title-screen key was an extended key; nothing acts on it }
  extendedKey: Boolean;
  { loop counter for the copy-protection check over the four party slots }
  partySlot: Byte;

{ ECL interpreter: run control and the per-script load state. }
var
  { nonzero stops the interpreter loop after the current opcode }
  eclStop: Byte;
  { set when a script asks for a new ECL block; the main loop loads it before running on }
  newEclFlag: Byte;
  { set while savedChar must be restored as the active character }
  restoreChar: Byte;
  { set once the current script has loaded area data }
  filesLoaded: Byte;
  { set once the current script has loaded wall sets }
  piecesLoaded: Byte;
  { set once the current script has loaded a 3D map }
  mapLoaded: Byte;
  { creatures added to the encounter so far; capped at 63 }
  creatureCnt: Byte;
  { the active character saved across a script that picks someone else }
  savedChar: Types.PCharRecord;

{ Post-combat outcome. }
var
  { set once an enemy has been downed, so the fight leaves loot behind }
  monstersKilled: Boolean;
  { set when the party ran from the fight }
  partyFled: Boolean;
  { the shop menu's redraw request, passed to the item menu by reference }
  menuRedraw: Boolean;

{ Combat AI movement: oscillation detection for a monster that keeps stepping back and forth. }
var
  { the direction of the last step, or 8 for none }
  lastMoveDir: Byte;
  { how many times in a row the monster has stepped back the way it came }
  stuckCount: Byte;
  { reset at the start of each move but never read }
  stuckCountTail: Byte;

{ Combat placement: where each team's combatants start on the battle map. }
var
  { per team, ring, quadrant row and column: whether the spot is still free }
  placementAvailable: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { per team: the quadrant column the team's rings are laid out from }
  teamOriginX: array[0..1] of ShortInt;
  { per team: the quadrant row the team's rings are laid out from }
  teamOriginY: array[0..1] of ShortInt;
  { per team: how many rows the team fills, half its head count rounded up }
  teamPlacementRows: array[0..1] of ShortInt;
  { per team: the side of the map the team enters from }
  teamDirection: array[0..1] of ShortInt;
  { the map-square column being scanned while the battle map is built from the area map }
  mapOffsetX: ShortInt;
  { the map-square row being scanned while the battle map is built from the area map }
  mapOffsetY: ShortInt;
  { the wall type on the north side of the area-map square being converted }
  northWall: Byte;
  { the wall type on the west side }
  westWall: Byte;
  { the wall type on the east side }
  eastWall: Byte;
  { the wall type on the south side }
  southWall: Byte;
  { the team being placed: 0 the party, 1 the monsters }
  placementTeam: ShortInt;

{ Combat placement: the area-map square being converted. }
var
  { the area's terrain, an index into terrainClasses }
  terrainType: Byte;
  { the event bit of the area-map square being converted }
  mapEventFlag: Byte;
  { set when the square's walls make it a corridor the battle map can open up }
  corridorOk: Boolean;
  { unused }
  corridorOkTail: array[0..3] of Byte;

{ Game initialization: loop counters and the ITEMS file read. }
var
  { loop counter for the row-address tables }
  initIndex: Byte;
  { unused }
  initIndexTail: array[0..2] of Byte;
  { whether OpenWithRetry found ITEMS }
  itemsOk: Boolean;
  { unused }
  itemsOkTail: array[0..42] of Byte;
  { the buttons of the mouse sample taken at start-up }
  mouseButtons: Integer;
  { the column of that sample; past 320 means a 640-wide driver }
  mouseSampleX: Integer;
  { the row of that sample }
  mouseSampleY: Integer;
  { the ITEMS file, read once into baseItems }
  itemsFile: file;
  { unused }
  itemsFileTail: Byte;

{ Character view, spell lists and timed effects. }
var
  { the character shown on the character sheet }
  tempCr1: Types.PCharRecord;
  { the character whose items the inventory screen works on }
  tempCr2: Types.PCharRecord;
  { per party member: still carries a timed effect, cleared as the timers run out }
  effFlags: array[1..72] of Byte;
  { the menu list built for a spell choice; freed after the pick }
  spellList: Types.PItemRec;
  { per menu line: how many copies of the spell the caster has }
  spellCounts: array[0..57] of Byte;
  { per menu line: the spell id it stands for }
  spellIds: array[0..57] of Byte;
  { per menu line: the scroll the spell is read from, when scribing }
  scrollPtrs: array[0..48] of Types.PItemRec;
  { the number of entries in scrollPtrs }
  scrollCount: Byte;
  { the strength score a spell grants, such as Enlarge's }
  spellTemp1: Byte;
  { the exceptional strength that goes with spellTemp1 }
  spellTemp2: Byte;

{ Start-up configuration: the KRYNN.CFG dialogue and the paths it sets. }
var
  { Equipped-item weight subtotal; written but never read. }
  equippedWeight: Word;
  { the block held back at the top of the heap for the graphics buffers }
  gfxReserve: Pointer;
  { the digit just typed at a configuration prompt }
  inputChar: Char;
  { the configuration menu choice }
  menuChoice: Byte;
  { KRYNN.CFG, written while the player answers the set-up questions }
  cfgFile: Text;
  { unused }
  cfgFileTail: array[0..127] of Byte;
  { IOResult of the last configuration-file operation }
  configIoError: Byte;
  { loop counter while the save path is checked and upper-cased }
  configIndex: Byte;
  { the save path typed by the player }
  savePath: string[80];
  { the program's file name, split from its full path }
  fsName: String[8];
  { the program's extension }
  fsExt: String[4];
  { the save path offered when the player just presses Enter }
  defaultPath: string[79];

{ Music driver and disk paths. }
var
  { the music driver's entry point; sndload.asm calls through it on every tick }
  driverEntryPtr: Pointer;
  { the driver's block as allocated, kept to free it }
  driverAllocPtr: Pointer;
  { the size of that block }
  driverAllocSize: Word;
  { current data path; GameBoot also reads it as the DirStr that FSplit takes }
  dataPath: String[79];
  { master disk path }
  masterPath: String[79];
  { prompt drive char }
  driveChar: Char;

{ Play session: zones, ECL entry, interface state, game flags. }
var
  { points at the sound driver's data word }
  driverDataPtr: Pointer;
  { set when the full introduction plays rather than the short one }
  fullIntro: Boolean;
  { set once play has started, so the low-memory handler saves the game before it exits }
  gameActive: Byte;
  { the game-state block the ECL scripts read and write }
  zone0: Types.PZone0;
  { the area-state block }
  zone1: Types.PZone1;
  { the script's own data block }
  zone2: Types.PZone2;
  { the script code the interpreter runs }
  zone3: Types.PZone3;
  { the game speed, 0 fastest to 9 slowest }
  gameDelay: Byte;
  { the entry points read from the head of the current ECL block }
  eclEntryPoints: Types.TEclEntryPoints;
  { the interpreter's offset into zone3 }
  eclIp: Word;
  { unused }
  eclIpSpare: array[0..3] of Byte;
  { what the screen is showing: a C_Ifc mode }
  interfaceState: Byte;
  { the interface mode before the last location change }
  previousLocationType: Byte;
  { set while the demo plays }
  demoFlag: Byte;
  { unused }
  demoFlagSpare: Byte;
  { the player's pictures-on option }
  picturesEnabled: Byte;
  { set while a script shows a special view in place of the 3D view }
  specialView: Byte;
  { the player's animations-on option }
  animationsEnabled: Byte;
  { the number of monster pictures the encounter shows }
  monsterPictureCount: Byte;
  { debug.txt is open -- toggled by GameIo's Ctrl-D when run with 'Woof', cleared by GameInit's InitializeGame and
    ResetGameState }
  debugActive: Byte;
  { set after a saved game is loaded, until the first script has run }
  loadedSave: Byte;
  { clock ticks spent resting toward the area's rest period }
  restTicks: Word;
  { the head picture of the portrait last shown }
  portraitHeadId: Byte;
  { the body picture of the portrait last shown }
  portraitBodyId: Byte;
  { set when no party member is left in play }
  partyDefeated: Boolean;
  { set while the training hall is changing a knight's order }
  knightTrainingMode: Byte;
  { set while text is printed slowly, letter by letter }
  slowText: Byte;
  { Video: video registers, pages and modes; view buffer, dirty spans and row tables. }
  { the register block for BIOS and DOS calls }
  vregs: Types.TRegisters;
  { the EGA segment of the page being shown }
  egaCurPage: Word;
  { the EGA segment of the page being drawn }
  egaOtherPage: Word;
  { the EGA page being drawn }
  pageNum: Byte;
  { the EGA page being shown }
  curEgaPage: Byte;
  { the video mode found at start-up, restored on exit }
  savedVideoMode: Byte;
  { the BIOS video mode the game set }
  curVideoMode: Byte;
  { the display adapter the game draws for }
  displayMode: Types.TVideoMode;

{ Video: the view buffer, dirty spans and row tables. }
var
  { the off-screen cell buffer the view is drawn into }
  egaDest: Types.PImgBuf;
  { the save-under buffer for clipped sprites }
  saveUnder: Types.PImgBuf;
  { unused }
  saveUnderSpare: array[0..15] of Byte;
  { the dirty-span tables, also read by blit.asm: per span slot, whether it holds a span to flush }
  spanActive: array[0..167] of Byte;
  { per span slot: its screen row }
  spanY: array[0..167] of Word;
  { per span slot: its first column }
  spanX0: array[0..167] of Word;
  { per span slot: its last column }
  spanX1: array[0..167] of Word;
  { unused }
  spanX1Tail: array[0..671] of Byte;
  { per screen row: the CGA segment of the row }
  cgaRowSeg: array[0..199] of Word;
  { per screen row: the offset of the row in the frame buffer }
  fbRowOfs: array[0..199] of Word;
  { per screen row: the Tandy segment of the row }
  tandyRowSeg: array[0..199] of Word;
  { set once game initialization has run }
  initFlag: Byte;

{ Sound: sound mode and state. }
var
  { the sound hardware chosen at set-up: a C_Sound mode }
  soundMode: Byte;
  { the sound mode saved while sound is switched off }
  soundSaved: Byte;
  { set by StartSound and by GameInit's InitializeGame and ResetGameState; cleared by CMD_STOP unless soundDisabled is
    nonzero or soundMode is C_Sound.OFF; FixMain and EclVm send a sound command while it is set and call StartSound
    while it is clear }
  soundActive: Byte;

{ Start-up flags and the intro's sound lock. }
var
  { cleared when the game starts; nothing reads it }
  startupFlagA: Byte;
  { cleared with startupFlagA; nothing reads it }
  startupFlagB: Byte;
  { set while the intro owns the sound driver }
  soundDisabled: Byte;

{ Disk: disks, save directory and save state. }
var
  { the game disk the data files are read from }
  currentDisk: Byte;
  { currentDisk saved across a read from another disk }
  prevDisk: Byte;
  { the directory saved games go to }
  saveDir: String;
  { the key that answers an insert-disk prompt without asking, or #0 }
  suppressPrompt: Char;
  { set after a save, cleared by anything that changes the game }
  recentlySaved: Byte;
  { the base item table, indexed from zero }
  baseItems: array[0..128] of Types.TBaseItem;
  { Party and treasure list pointers. }
  { the active character }
  curChar: Types.PCharRecord;
  { head of the party list }
  partyHead: Types.PCharRecord;
  { head of the list of weapons knocked from their owners' hands, given back after the fight }
  bankHead: Types.PBankNode;
  { the last treasure item added during combat }
  prevTreasure: Types.PItemRec;
  { Scratch file and ITEMS read result. }
  { the file handle DeleteIfPresent erases through }
  delFile: file;
  { bytes BlockRead returned for ITEMS }
  itemsRead: Word;
  { Font and text cursor. }
  { the 8x8 font }
  gameFont: Types.PFontTable;
  { the glyph being drawn, staged for textrend.asm }
  glyphBuf: Types.TGlyph;
  { the text cursor's column }
  curCol: Byte;
  { the text cursor's row }
  curRow: Byte;
  { unused }
  curRowSpare: array[0..19] of Byte;
  { Symbol sets, cursor and map tile buffers. }
  { five symbol-set pointers }
  symbolSetPtrs: array[0..4] of Types.PImgBuf;
  { the 8x8 symbol being drawn }
  cur8x8Buf: Types.PImgBuf;
  { what the map cursor covers }
  cursorBackground: Types.PImgBuf;
  { the map cursor laid over what it covers }
  cursorComposite: Types.PImgBuf;
  { the first map tile set }
  tileSet1: Types.PImgBuf;
  { the second map tile set }
  tileSet2: Types.PImgBuf;
  { Icon images. }
  { per icon: its two animation frames }
  iconAnims: array[0..25, 0..1] of Types.PImgBuf;
  { Combat: combat arena, grids, creatures and targets. }
  { the number of combatants on the battle map }
  arenaCount: Byte;
  { each combatant's arena position and size }
  arenaLoc: array[1..72] of Types.TArenaLoc;
  { each combatant's column relative to the visible part of the arena }
  gridX: array[1..72] of ShortInt;
  { each combatant's row relative to the visible part of the arena }
  gridY: array[1..72] of ShortInt;
  { per arena square: the combatant standing on it, or 0 }
  creatureIndexGrid: array[0..24, 0..49] of Byte;
  { the combatants, by combat index }
  creatureArr: array[1..72] of Types.PCharRecord;
  { the combatants lying on the map, drawn as corpses }
  downedCreatures: array[1..8] of Types.TDownedRec;
  { the number of entries in downedCreatures }
  downedCount: Byte;
  { the battle map }
  arena: Types.PArena;
  { the number of entries in targetList }
  targetCount: Byte;
  { the targets in reach of the current attack or spell }
  targetList: array[1..72] of Types.TTargetRec;

{ Treasure and effect resolution. }
var
  { Treasure. }
  { the coins the party has won and not yet picked up }
  treasureMoney: Types.TMoney;
  { the items the party has won and not yet picked up }
  treasureItems: Types.PItemRec;
  { Combatants per side. }
  { per team: how many combatants it fields }
  teamCount: array[0..1] of Byte;
  { Effect resolution. }
  { the d20 rolled for the current saving throw, after bonuses }
  saveRoll: Byte;
  { the effect being applied }
  currentEffectId: Byte;
  { the damage the current effect deals }
  currentDamage: Byte;
  { the elements the current attack carries, one bit each }
  elementMask: Byte;
  { scratch rate: the attack rate or the doubled movement being converted to attacks }
  moveAttackMultiplier: Byte;
  { the spell being cast, or 0 }
  currentSpell: Byte;
  { the dice count the current effect rolls }
  diceCount: Byte;

{ Effect resolution: attack phases, saving throws and exploding items. }
var
  { [0] is raised while CbtActs calculates movement; [1] is the veto the effect handlers raise, which makes CanTarget
    refuse a target }
  movementFlags: array[0..1] of Byte;
  { set while an effect handler runs, so a nested one returns at once }
  effectBusy: Byte;
  { set once a spell has hit more than one target }
  multiTarget: Byte;
  { set to make the inventory menu redraw on its next pass }
  redrawInvMenu: Byte;
  { the attack roll being resolved, adjusted by the effect handlers }
  gAttackRoll: ShortInt;
  { per attack phase: the hits made this round }
  hitsMade: array[1..2] of Byte;
  { scratch the effect handlers share }
  effectScratch: Types.TEffectScratch;
  { the saving-throw category of the current effect }
  saveType: Byte;
  { the result of the last saving throw }
  saveResult: Boolean;
  { the creatures waiting for an exploding item to go off }
  explosionQueue: array[1..20] of Types.PCharRecord;
  { the number of entries in explosionQueue }
  explosionCount: Byte;
  { set while the explosion queue is being worked through }
  explosionBusy: Byte;

{ Effect dispatch, 3D view and pictures. }
var
  { Effect dispatch. }
  { per effect id: the routine that applies it }
  effectHandlers: array[1..119] of Types.TEffectHandler;
  { the handler called in place of the table while overrideFlag is set }
  overrideHandler: Types.TEffectHandler;
  { 3D view. }
  { the wall sets View3D loads and draws }
  wallGfx: Types.PWallGfx;
  { GameInit allocates it, View3D loads and draws it, Explore edits barriers }
  geo: Types.PGeoMap;
  { the 3D view's sky color }
  viewColSky: Byte;
  { the color of the upper horizon row }
  viewHorizonUpper: Byte;
  { the color of the lower horizon row }
  viewHorizonLower: Byte;
  { the 3D view's floor color }
  viewColFloor: Byte;
  { Map state, wall sets and view tiles. }
  { Explore toggles it; View3D draws the automap in place of the view while set }
  automapOn: Boolean;
  { the party's position and facing }
  mapState: Types.TMapState;
  { the three wall sets loaded for the area }
  wallSlots: array[1..3] of Types.TWallSetSlot;
  { three far pointers, cleared by GameInit: the tile drawn ahead of the party }
  frontTile: Types.PImgBuf;
  { the tile drawn at the view's side edges }
  edgeTile: Types.PImgBuf;
  { the sky tile }
  skyTile: Types.PImgBuf;
  { Portrait: big picture, portraits and picture archive. }
  { the animated picture in the view window }
  bigAnim: Types.TAnimation;
  { the head and body halves of the portrait }
  portraits: array[1..2] of Types.TPortraitSlot;
  { the picture archive the view window's picture came from }
  picArcName: Types.TStr8;
  { picArcName saved while the camp menu covers the picture }
  savedPictureName: Types.TStr8;
  { MapView: picture archive id; 9 cancels a pending redraw }
  picArcId: Byte;
  { picArcId saved while the camp menu covers the picture; 255 for none }
  savedPictureId: Byte;
  { the full-screen picture }
  bigPicBuf: Types.PImgBuf;
  { the id of the full-screen picture, so it is loaded once }
  bigPicId: Byte;

{ Menus, spell casting and rest. }
var
  { Menu: menu state and mouse hit areas. }
  { set while the selector picks the alternate character, altChar }
  useAlternateSelection: Byte;
  { the character picked by the alternate selection }
  altChar: Types.PCharRecord;
  { the list entry shown on the menu's top line }
  firstVisibleIndex: Integer;
  { the entry a horizontal menu starts on }
  horizontalChoice: Byte;
  { set when the menu's last key was an extended key }
  extendedKeyFlag: Boolean;
  { how long a menu waits for a key before it returns timerCh; 0 waits for ever }
  autoTimeout: LongInt;
  { the key a menu returns when autoTimeout runs out; set by FixMain }
  timerCh: Char;
  { per menu line: the column its hotspot starts at; 255 ends the table }
  hotspotRows: array[1..25] of Byte;
  { the screen row of the menu's first line }
  keyRowLo: ShortInt;
  { the screen row of the menu's last line }
  keyRowHi: ShortInt;
  { the mouse hit-test window: the 40-column bounds and the roster-line bounds; this is the left column }
  screenColumnLo: Byte;
  { the right column of the hit-test window }
  screenColumnHi: Byte;
  { the top roster line of the hit-test window }
  screenRowLo: Byte;
  { the bottom roster line of the hit-test window }
  screenRowHi: Byte;
  { the stat row the mouse picked on the modify screen; 255 for none }
  modifyMouseRow: Byte;
  { Magic: spell casting and targeting. }
  { the scroll being read or scribed from }
  curScroll: Types.PItemRec;
  { the target picker for a cast: one for camp, one for combat }
  castTargetMenu: Types.TCastTargetProc;
  { per spell id: the routine that casts it }
  spellDispatch: array[1..107] of Types.TSpellProc;
  { the number of entries in spellTargets }
  spellTargetCount: Byte;
  { the creatures the current spell will affect }
  spellTargets: array[1..72] of Types.PCharRecord;
  { the last character a camp spell was cast on, offered first next time }
  lastTarget: Types.PCharRecord;
  { the column a spell is aimed at }
  targetX: ShortInt;
  { the row a spell is aimed at }
  targetY: ShortInt;
  { head of the list of stinking and kill clouds on the battle map }
  cloudHead: Types.PCloudNode;
  { cleared at the start of each fight; nothing reads it }
  effectListHeadC: Pointer;
  { head of the list of acid pools on the battle map }
  acidPoolHead: Types.PCloudNode;
  { set while a spell is cast from an item rather than from memory }
  usingItemFlag: Byte;
  { set when the treasure on offer holds coins }
  treasureMoneyFlag: Boolean;

{ Rest and healing. }
var
  { the rest duration being set, one digit per time unit }
  restTime: Types.TClock;
  { per party member: the time left before the next spell is memorized }
  prepTimers: array[1..8] of Byte;
  { clock ticks toward the next natural healing }
  healTicks: Word;
  { set to suppress the message-window border }
  noBorder: Byte;

{ Misc: picture redraw, effect override, character-generation and spell-bonus flags. }
var
  { set when the view-window picture must be drawn again }
  pictureRedrawRequested: Byte;

{ Effect override. }
var
  { set while overrideHandler stands in for the effect table }
  overrideFlag: Byte;

{ Character generation and spell-bonus flags. }
var
  { the format of the character file being imported }
  importFormat: ShortInt;
  { set to leave the training menu }
  trainMenuDone: Byte;
  { set to let training run while the hall's train mask is empty }
  stingMode: Byte;
  { set while the modify-character screen is open }
  modifyActive: Byte;
  { set when the spell being memorized comes from the cast-class 2 list }
  bonusFlag: Byte;

{ Spell bonus. }
var
  { the extra mage spells the caster may memorize: 0, 1 or 2 }
  bonusSpells: Byte;

{ Door opening. }
var
  { per attempt kind: whether it may still be tried at the current door }
  doorOpen: array[0..2] of Byte;

{ Combat round. }
var
  { set once a party member has attacked an ally }
  allyAttacked: Byte;
  { the round number of the fight }
  roundNumber: Byte;
  { the round after which the fight ends on its own }
  roundLimit: Byte;
  { per target slot: the combat index of the target }
  targetIdx: array[1..72] of Byte;
  { per attack phase: the attacks made this round }
  attacksMade: array[1..2] of Byte;
  { the monsters' remaining hit points as a percentage, in fives; it drives their morale }
  hostileHpPct: Byte;
  { the player's combat magic-on option }
  magicEnabled: Boolean;
  { set when the combat menu's last key was an extended key }
  combatExtendedKey: Boolean;
  { unused }
  combatExtendedKeySpare: array[0..3] of Byte;
  { the picture shown in the combat view window }
  viewPicture: Types.PImgBuf;
  { unused }
  viewPictureTail: Byte;
  { the combat cursor's column }
  cursorX: ShortInt;
  { the combat cursor's row }
  cursorY: ShortInt;
  { set while the cursor shows on the battle map }
  mapCursorActive: Byte;
  { set while the cursor shows on a creature }
  creatureCursorActive: Byte;
  { the creature taunted by a kender's yell, nil while nobody is taunted }
  yellTarget: Pointer;
  { set when the AI's chosen target is within reach }
  inRange: Boolean;
  { set to force the combat panel to redraw }
  panelDirty: Byte;
  { set while combat moves are drawn rather than resolved off screen }
  gfxEnabled: Byte;
  { the combatants in the order they act this round }
  combatOrder: array[1..72] of Types.PCharRecord;
  { the position in combatOrder of the combatant acting }
  roundIndex: Byte;

{ ECL interpreter: registers, stack, variables and the encounter it runs. }
var
  { ECL color selectors and read registers. }
  { GBVM $C059: keys the CGA floor band's color }
  floorColorSel: Byte;
  { GBVM $C05F: keys both CGA horizon rows' colors }
  horizonColorSel: Byte;
  { values a script reads back through the special read addresses, one per address }
  readRegister1: Word;
  { the second read register }
  readRegister2: Word;
  { the third read register }
  readRegister3: Word;
  { ECL interpreter. }
  { the stack of ECL blocks called and not yet returned from }
  eclStack: Types.PEclRet;
  { the stack entry below the top, while a call is pushed }
  previousEclStack: Types.PEclRet;
  { the six comparison results of the last compare opcode }
  cmpFlags: array[0..5] of Boolean;
  { the opcode before the current one }
  previousOpcode: Boolean;
  { the opcode being run }
  eclOpcode: Byte;
  { unused }
  eclOpcodeSpare: Byte;
  { the monster picture of the encounter }
  approachA: Byte;
  { the approach type of the encounter }
  approachB: Byte;
  { the icon slot the next added creature takes }
  iconAnimId: Byte;
  { unused }
  iconAnimIdSpare: array[0..129] of Byte;
  { ECL variables and strings. }
  { per operand of the current opcode: its type }
  varTypes: array[1..64] of Byte;
  { per operand: the high byte of its value }
  varHi: array[1..64] of Byte;
  { per operand: the low byte of its value }
  varLo: array[1..64] of Byte;
  { scratch flag shared by the targeting loops }
  scratchFlag: Byte;
  { scratch index shared by the loops that walk tables }
  scratchIndex: ShortInt;
  { the strings the current opcode reads as operands }
  gbStrings: array[1..20] of String;
  { ECL monster, write-register and post-combat state. }
  { the encounter's monster flags }
  monFlags: Types.TMonFlags;
  { unused }
  monFlagsSpare: array[0..1] of Byte;
  { the sound effect a script asked for }
  sndEffect: Word;
  { values a script writes through the special write addresses, one per address }
  writeRegister1: Word;
  { the second write register }
  writeRegister2: Word;
  { set when a character's removal waits for the status line to clear }
  removeCharPending: Boolean;
  { set once the character-name line has been cleared }
  charNameCleared: Boolean;
  { noncombat display state }
  drawFlag: Byte;

{ Post-combat: duel, experience and outcome. }
var
  { set when the fight is a duel }
  duelFlag: Byte;
  { party members out of the fight, left out of the experience share }
  nonAnimCount: Byte;
  { each member's share of the experience for the fight }
  expShare: LongInt;
  { set when the party won the fight }
  combatWon: Boolean;

{ ECL interpreter: display and encounter flags. }
var
  { the id of the ECL block being run }
  curEclId: Byte;
  { the search flag saved while a script changes it }
  searchBackup: Byte;
  { set once the message box has been cleared }
  boxCleared: Byte;
  { set when the next print starts on a new line }
  printReturnFlag: Byte;
  { set while a script draws its own picture }
  eclGraphics: Boolean;
  { set once the encounter picture has been drawn }
  pictureDrawn: Byte;
  { set while the copy-protection picture is shown }
  protShown: Byte;
  { set while a 3D sprite is shown in the view }
  spriteShown: Boolean;
  { set once the bottom of the message area is clear }
  bottomClear: Byte;
  { set when a script changed the 3D view colors }
  viewColorsChanged: Boolean;
  { set when a script moved the party }
  partyMoved: Boolean;
  { set while the encounter has monsters }
  monstersOn: Byte;
  { set when the sky must be drawn again }
  redrawSky: Boolean;
  { set while the encounter menu is up }
  inEncounterMenu: Byte;
  { the picture id on show }
  pictureIdShown: Byte;
  { set when a script's character lookup found nobody }
  charNotFound: Byte;
  { set on entering an area, until its entry script has run }
  enteringLoop: Byte;
  { cleared at start-up and on reset; nothing reads it }
  encounterStateFlag: Byte;
  { the step mode saved while a script runs }
  extendedMode: Byte;
  { the undead in the encounter, counted for turning }
  undeadCount: Byte;
  { unused }
  undeadCountSpare: array[0..4] of Byte;
  { the overlay manager's own read routine, which GameIo's retrying reader calls }
  previousOverlayReadVector: Types.TOverlayReadFunc;

{ Debug log and map cursor. }
var
  { Debug file. }
  { debug.txt }
  debugFile: Text;
  { Map cursor image. }
  { the cursor picture loaded; 0 for none }
  cursorImageId: Byte;
  { the cursor picture }
  cursorImg: Types.PImgBuf;

{ Copy protection and mouse. }
var
  { Copy-protection answer and mark. }
  { the command-line word that skips the copy-protection check }
  cmpStr: String[20];
  { one byte per stage of the copy-protection check, set as it passes }
  protMark: array[1..4] of Byte;

{ Mouse. }
var
  { set when the driver reports 320-wide positions, so X is used unscaled }
  mouseScaled: Boolean;
  { set while the party roster answers mouse clicks }
  partyPickEnabled: Byte;
  { set when a mouse driver was found and enabled }
  mouseOn: Boolean;
  { set once a button press has been seen }
  mouseButtonSeen: Byte;
  { the button count the driver reported }
  mouseButtonCount: Byte;
  { the mouse column }
  mouseX: Integer;
  { the mouse row }
  mouseY: Integer;
  { the mouse column last acted on }
  mouseOldX: Integer;
  { the mouse row last acted on }
  mouseOldY: Integer;
  { the cursor mask for the display mode }
  cursorMask: Types.PCursorMask;

{ Joystick. }
var
  { per stick: its calibration }
  joyCalib: array[1..2] of Types.TJoyCalibration;
  { set when the joystick is enabled }
  joyOn: Boolean;
  { the stick's resting column, in screen terms }
  joystickCenterX: Integer;
  { the stick's resting row }
  joystickCenterY: Integer;

{ Sound-effect buffers. }
var
  { per sound slot: the size of its block }
  sfxAllocSize: array[2..15] of Word;
  { per sound slot: its block as allocated }
  sfxAllocPtr: array[2..15] of Types.PBytes;
  { per sound slot: the paragraph-aligned segment the driver plays from }
  sfxSegment: array[2..15] of Word;

implementation

end.
