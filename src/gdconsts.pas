{ Initialized data: the data segment's typed constants, grouped by the subsystem that reads them and kept in address
  order. A new section starts wherever the data needs a word boundary. }
unit GDConsts;

interface

uses Types, C_Keys, C_Dir;

{ Copy protection: the documentation-lookup answers and the questions asked. }
const
  { the answer words' letters, each stored as a signed offset that the lookup adds back }
  answerLetterTable: array[1..201] of ShortInt = (
    15, -3, 1, -9, 8, 2, -7, 11, 7, -2, 10, 0, 9, -7, 11, -7, 5, -1, 6, 14, 6, 2, -9, 4, -5, -7, 2, -3, 9, 7, 6, 12, 11,
    5, 4, -7, -5, -10, -9, 4, 10, 9, 1, -5, 6, 10, -4, 5, 11, 8, 12, 7, -1, -6, 1, -6, 0, 5, -10, 7, 9, 14, 6, 5, 5, 8,
    1, -2, 8, 9, 8, -10, 7, 2, 4, 7, 9, -4, -5, 4, -4, 7, -6, 8, -10, -12, 5, -12, 0, 2, 1, 10, -9, 2, -5, -1, -4, 16,
    -6, -8, 5, -7, 4, 4, 7, 8, -5, 4, 1, 0, 8, -3, 5, 5, -6, 5, 12, -5, 8, 7, -9, 3, 9, 8, 7, -1, -4, 9, 8, -4, 6, 3, 8,
    0, 12, -6, -2, 7, -7, -4, 7, 11, 6, 6, -9, -3, 8, -3, -7, 7, -4, 7, -10, 11, -6, 7, -3, 0, 10, -7, 6, -9, 7, -10,
    11, -6, -8, -5, -5, 8, 7, 6, -4, 10, -10, 7, -7, 13, -1, 10, -2, 10, -1, 3, -5, 2, -2, 1, -6, 8, -7, -8, -5, 8, 9,
    -2, 1, 1, 14, -1, 6);
  { the questions: the word, entry and page each one asks for, and where its letters start }
  codeEntries: array[1..50] of Types.TCodeRec = (
    (wordNo: 5; entryNo: 1; pageNo: 26; letters: 2; firstLetter: 0),
    (wordNo: 9; entryNo: 2; pageNo: 26; letters: 4; firstLetter: 2),
    (wordNo: 7; entryNo: 3; pageNo: 26; letters: 2; firstLetter: 6),
    (wordNo: 9; entryNo: 6; pageNo: 26; letters: 2; firstLetter: 8),
    (wordNo: 2; entryNo: 7; pageNo: 27; letters: 3; firstLetter: 10),
    (wordNo: 1; entryNo: 8; pageNo: 27; letters: 2; firstLetter: 13),
    (wordNo: 7; entryNo: 12; pageNo: 28; letters: 2; firstLetter: 15),
    (wordNo: 7; entryNo: 14; pageNo: 29; letters: 3; firstLetter: 17),
    (wordNo: 2; entryNo: 16; pageNo: 29; letters: 4; firstLetter: 20),
    (wordNo: 7; entryNo: 19; pageNo: 30; letters: 6; firstLetter: 24),
    (wordNo: 7; entryNo: 20; pageNo: 30; letters: 3; firstLetter: 30),
    (wordNo: 6; entryNo: 24; pageNo: 31; letters: 4; firstLetter: 33),
    (wordNo: 4; entryNo: 26; pageNo: 31; letters: 5; firstLetter: 37),
    (wordNo: 3; entryNo: 28; pageNo: 31; letters: 4; firstLetter: 42),
    (wordNo: 2; entryNo: 29; pageNo: 31; letters: 4; firstLetter: 46),
    (wordNo: 6; entryNo: 30; pageNo: 32; letters: 2; firstLetter: 50),
    (wordNo: 7; entryNo: 33; pageNo: 32; letters: 5; firstLetter: 52),
    (wordNo: 5; entryNo: 35; pageNo: 32; letters: 5; firstLetter: 57),
    (wordNo: 9; entryNo: 36; pageNo: 32; letters: 4; firstLetter: 62),
    (wordNo: 4; entryNo: 39; pageNo: 33; letters: 5; firstLetter: 66),
    (wordNo: 4; entryNo: 52; pageNo: 35; letters: 5; firstLetter: 71),
    (wordNo: 1; entryNo: 57; pageNo: 36; letters: 3; firstLetter: 76),
    (wordNo: 2; entryNo: 66; pageNo: 38; letters: 5; firstLetter: 79),
    (wordNo: 8; entryNo: 67; pageNo: 38; letters: 7; firstLetter: 84),
    (wordNo: 2; entryNo: 74; pageNo: 40; letters: 4; firstLetter: 91),
    (wordNo: 1; entryNo: 1; pageNo: 44; letters: 3; firstLetter: 95),
    (wordNo: 2; entryNo: 3; pageNo: 44; letters: 3; firstLetter: 98),
    (wordNo: 4; entryNo: 5; pageNo: 44; letters: 5; firstLetter: 101),
    (wordNo: 4; entryNo: 9; pageNo: 44; letters: 5; firstLetter: 106),
    (wordNo: 2; entryNo: 11; pageNo: 44; letters: 4; firstLetter: 111),
    (wordNo: 6; entryNo: 14; pageNo: 45; letters: 4; firstLetter: 115),
    (wordNo: 2; entryNo: 15; pageNo: 45; letters: 6; firstLetter: 119),
    (wordNo: 5; entryNo: 17; pageNo: 45; letters: 3; firstLetter: 125),
    (wordNo: 6; entryNo: 19; pageNo: 45; letters: 6; firstLetter: 128),
    (wordNo: 3; entryNo: 20; pageNo: 45; letters: 5; firstLetter: 134),
    (wordNo: 8; entryNo: 21; pageNo: 45; letters: 2; firstLetter: 139),
    (wordNo: 3; entryNo: 23; pageNo: 45; letters: 3; firstLetter: 141),
    (wordNo: 7; entryNo: 25; pageNo: 45; letters: 6; firstLetter: 144),
    (wordNo: 5; entryNo: 31; pageNo: 46; letters: 5; firstLetter: 150),
    (wordNo: 2; entryNo: 32; pageNo: 46; letters: 6; firstLetter: 155),
    (wordNo: 9; entryNo: 36; pageNo: 47; letters: 5; firstLetter: 161),
    (wordNo: 4; entryNo: 40; pageNo: 47; letters: 4; firstLetter: 166),
    (wordNo: 8; entryNo: 41; pageNo: 47; letters: 2; firstLetter: 170),
    (wordNo: 4; entryNo: 43; pageNo: 47; letters: 5; firstLetter: 172),
    (wordNo: 4; entryNo: 44; pageNo: 47; letters: 4; firstLetter: 177),
    (wordNo: 8; entryNo: 47; pageNo: 48; letters: 4; firstLetter: 181),
    (wordNo: 6; entryNo: 50; pageNo: 48; letters: 5; firstLetter: 185),
    (wordNo: 2; entryNo: 52; pageNo: 48; letters: 3; firstLetter: 190),
    (wordNo: 4; entryNo: 53; pageNo: 48; letters: 5; firstLetter: 193),
    (wordNo: 2; entryNo: 54; pageNo: 48; letters: 3; firstLetter: 198));

{ Temple: the diseases it cures and its healing menu. }
const
  { The six disease effects, then the eleven temple menu entries, from Cure Blindness through Exit. }
  diseaseEffects: array[1..6] of Byte = (31, 34, 43, 44, 50, 57);
  { the menu entries, in the order the temple prices them }
  templeMenuItems: array[1..11] of Types.TStr40 = (
    'Cure Blindness', 'Cure Disease', 'Cure Light Wounds', 'Cure Serious Wounds', 'Cure Critical Wounds', 'Heal',
    'Neutralize Poison', 'Raise Dead', 'Remove Curse', 'Stone to Flesh', 'Exit');

{ Post-combat cleanup. }
const
  { the effects stripped from the combatants when the fight ends }
  clearedEffectIds: array[1..11] of Byte = (3, 11, 21, 23, 27, 35, 40, 51, 52, 53, 31);

{ Combat AI, battle-map placement and turning tables; camp menus and the journal-word check. }
const
  { per AI stance: the five directions a blocked monster tries, as offsets from its heading }
  aiDirOffsetTable: array[1..6, 1..5] of Byte = (
    (8, 7, 6, 1, 2),
    (8, 1, 2, 7, 6),
    (7, 1, 8, 6, 2),
    (1, 7, 8, 2, 6),
    (8, 7, 6, 5, 4),
    (8, 1, 2, 3, 4));
  { per team side and ring leg: the direction the placement walk turns to }
  ringDirectionTable: array[0..3, 0..3] of Byte = (
    (C_Dir.CENTER, C_Dir.SOUTH, C_Dir.WEST, C_Dir.EAST),
    (C_Dir.CENTER, C_Dir.WEST, C_Dir.SOUTH, C_Dir.NORTH),
    (C_Dir.CENTER, C_Dir.NORTH, C_Dir.WEST, C_Dir.EAST),
    (C_Dir.CENTER, C_Dir.EAST, C_Dir.NORTH, C_Dir.SOUTH));
  { per team side and ring: the quadrant the ring starts in }
  ringQuadrantTable: array[0..3, 0..3] of Byte = ((0, 0, 2, 6), (2, 2, 0, 4), (4, 4, 2, 6), (6, 6, 4, 0));
  { per quadrant: the facing a combatant placed there starts with }
  quadrantDirections: array[0..3] of Byte = (
    C_Dir.NORTHWEST, C_Dir.EAST, C_Dir.SOUTHEAST, C_Dir.WEST);
  { per corridor flag and quadrant: the starting column }
  quadrantStartXTable: array[Boolean, 0..3] of ShortInt = ((5, 4, 5, 6), (3, 8, 7, 2));
  { per corridor flag and quadrant: the starting row }
  quadrantStartYTable: array[Boolean, 0..3] of ShortInt = ((3, 2, 2, 3), (0, 2, 5, 3));
  { per ring and row: the columns a team may be placed in }
  placementBandTable: array[0..4, 0..5] of Types.TBandRec = (
    ((firstColumn: 1; lastColumn: 0), (firstColumn: 1; lastColumn: 0), (firstColumn: 1; lastColumn: 0),
    (firstColumn: 2; lastColumn: 9), (firstColumn: 3; lastColumn: 10), (firstColumn: 4; lastColumn: 10)),
    ((firstColumn: 0; lastColumn: 2), (firstColumn: 0; lastColumn: 3), (firstColumn: 1; lastColumn: 4),
    (firstColumn: 2; lastColumn: 5), (firstColumn: 3; lastColumn: 6), (firstColumn: 4; lastColumn: 7)),
    ((firstColumn: 0; lastColumn: 6), (firstColumn: 0; lastColumn: 7), (firstColumn: 1; lastColumn: 8),
    (firstColumn: 1; lastColumn: 0), (firstColumn: 1; lastColumn: 0), (firstColumn: 1; lastColumn: 0)),
    ((firstColumn: 3; lastColumn: 6), (firstColumn: 4; lastColumn: 7), (firstColumn: 5; lastColumn: 8),
    (firstColumn: 6; lastColumn: 9), (firstColumn: 7; lastColumn: 10), (firstColumn: 8; lastColumn: 10)),
    ((firstColumn: 0; lastColumn: 6), (firstColumn: 0; lastColumn: 7), (firstColumn: 1; lastColumn: 8),
    (firstColumn: 2; lastColumn: 9), (firstColumn: 3; lastColumn: 10), (firstColumn: 4; lastColumn: 10)));
  { the column step of each leg of a placement ring }
  ringStepX: array[1..4] of ShortInt = (0, 1, 0, -1);
  { the row step of each leg of a placement ring }
  ringStepY: array[1..4] of ShortInt = (-1, 0, 1, 0);
  { per area terrain type: the battle-map terrain class it builds }
  terrainClasses: array[0..31] of Byte = (
    $00, $18, $11, $15, $01, $01, $60, $14, $08, $01, $00, $21, $71, $09, $06, $04, $01, $09, $09, $08, $59, $00, $11,
    $11, $00, $00,
    $01, $11, $00, $00, $20, $20);
  { per undead level and turning level: the d20 roll needed; a negative entry destroys rather than turns }
  turnUndeadTable: array[1..12, 1..13] of ShortInt = (
    (10, 7, 4, 1, 1, 0, 0, -1, -1, -1, -1, -1, -1),
    (13, 10, 7, 1, 1, 0, 0, 0, -1, -1, -1, -1, -1),
    (16, 13, 10, 4, 1, 1, 0, 0, 0, 0, 0, 0, 0),
    (19, 16, 13, 7, 4, 1, 1, 0, 0, 0, 0, 0, 0),
    (20, 19, 16, 10, 7, 4, 1, 1, 0, 0, 0, 0, 0),
    (99, 20, 19, 13, 10, 7, 4, 1, 1, 1, 1, 1, 1),
    (99, 99, 20, 16, 13, 10, 7, 4, 1, 1, 1, 1, 1),
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 4, 4, 4, 4),
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 7, 7, 7, 7),
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 10, 10, 10, 10),
    (99, 99, 99, 99, 99, 99, 20, 16, 13, 10, 10, 10, 10),
    (99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99));
  { the camp menu's choices }
  campMenuText: Types.TStr40 = 'Save View Magic Rest Alter Fix Exit';
  { the magic menu's choices }
  magicMenuText: Types.TStr40 = 'Cast Memorize Scribe Display Rest Exit';
  { the alter menu's choices }
  alterMenuText: Types.TStr40 = 'Order Drop Speed Icon Pics Level Exit';
  { the difficulty levels offered by the level menu }
  levelMenuText: Types.TStr40 = 'Novice Squire Veteran Adept Champion';
  { the journal headings' letters, each stored as a signed offset that the lookup adds back }
  headLetterTable: array[1..204] of ShortInt = (
    -9, -4, 2, 0, -3, -14, 3, -15, 2, -9, -3, -4, -19, -16, -15, -6, -3, -16, -53, 4, -6, 0, -53, -5, -9, -20, 4, -22,
    -24, -9, -9, -20, -15, -22, -61, -10, -9, -28, -11, -9, -24, -25, -61, -12, -8, -20, -26, -18, -17, -4, 4, 2, -8,
    -3, -10, -49, -4, -12, -3, 4, 2, -21, -18, -16, -14, -9, -9, -14, -9, -16, -55, -3, -8, -55, -7, -11, -22, 2, -2,
    -15, -19, -1, -15, -10, -17, -56, -21, -16, -23, -6, -23, -21, -4, -19, -6, -5, -19, -14, -21, -4, -21, -19, -2,
    -17, -4, -54, -3, -2, -21, -2, -1, -3, 2, -10, -4, -2, -8, 7, 4, -7, 0, 0, 7, -15, -9, 4, -9, -6, -9, 8, -17, 2, -9,
    -3, -4, -11, -2, -13, -1, 5, -2, 4, -11, 2, 3, -9, 3, 1, -10, -11, 8, -19, -18, -11, -8, -11, 0, 5, -52, -1, -17,
    -5, -2, -15, -1, -14, -3, -6, -8, -1, -2, -10, -1, 5, -9, 3, 1, -10, -11, 8, 2, -10, -4, -2, -8, -9, -4, -8, 7, -4,
    -8, 6, 7, 4, -7, 0, 0, 7, -9, -4, -11, 6, 8, 7);
  { the journal words' letters, stored the same way }
  wordLetterTable: array[1..188] of ShortInt = (
    1, -8, -8, -5, -11, -5, -13, -2, 15, 5, 11, 8, 0, 2, -1, 4, -11, -13, 4, -7, -1, -2, -6, -9, 10, -9, 2, 5, -9, -6,
    -8, 3, 3, -8, 3, 3, -9, -6, -4, -2, 3, 2, 5, -9, -6, 7, -9, 6, -7, -7, 2, 5, 1, -9, 15, -12, -7, -14, 3, -14, -12,
    5, -10, 3, 12, 7, -11, -9, 8, -3, 10, -7, 2, 3, 7, -4, 2, 1, 6, 14, -1, 6, 10, -2, -5, 3, -6, -8, 5, 3, -9, 4, 15,
    -3, 6, 9, -3, 6, 9, 13, -2, -5, 4, 4, 6, -7, 9, 1, 6, -11, -9, 8, -3, 10, -7, -6, 11, -6, 7, 14, -12, -11, -4, -1,
    -4, 7, 12, 1, -2, 11, -6, 8, -6, 17, 5, 1, -10, -8, -6, 6, -13, -11, 6, -5, -11, -13, -2, 0, 7, 14, 3, 3, -10, -1,
    -8, 5, -4, -10, 6, -6, -9, 15, 9, 11, -3, 7, -8, 3, 1, -9, 1, -6, 8, 8, 7, -2, 8, 5, -6, 1, 1, -1, -4, 6, 7, -4, 1,
    -6);
  { per heading: its letter count and where its letters start }
  headEntries: array[1..19] of Types.THeadRec = (
    (letters: 12; firstLetter: 0),
    (letters: 15; firstLetter: 12),
    (letters: 23; firstLetter: 27),
    (letters: 11; firstLetter: 50),
    (letters: 17; firstLetter: 61),
    (letters: 18; firstLetter: 78),
    (letters: 16; firstLetter: 96),
    (letters: 5; firstLetter: 112),
    (letters: 6; firstLetter: 117),
    (letters: 12; firstLetter: 123),
    (letters: 10; firstLetter: 135),
    (letters: 6; firstLetter: 145),
    (letters: 14; firstLetter: 151),
    (letters: 9; firstLetter: 165),
    (letters: 6; firstLetter: 174),
    (letters: 5; firstLetter: 180),
    (letters: 7; firstLetter: 185),
    (letters: 6; firstLetter: 192),
    (letters: 6; firstLetter: 198));
  { per question: the word and page asked for, its heading, and where its letters start }
  wordEntries: array[1..39] of Types.TWordRec = (
    (wordNo: 4; pageNo: 1; headIdx: 1; letters: 8; firstLetter: 0),
    (wordNo: 7; pageNo: 1; headIdx: 2; letters: 4; firstLetter: 8),
    (wordNo: 5; pageNo: 1; headIdx: 2; letters: 10; firstLetter: 12),
    (wordNo: 6; pageNo: 1; headIdx: 3; letters: 4; firstLetter: 22),
    (wordNo: 9; pageNo: 1; headIdx: 3; letters: 4; firstLetter: 26),
    (wordNo: 1; pageNo: 1; headIdx: 4; letters: 3; firstLetter: 30),
    (wordNo: 1; pageNo: 1; headIdx: 4; letters: 3; firstLetter: 33),
    (wordNo: 2; pageNo: 2; headIdx: 5; letters: 5; firstLetter: 36),
    (wordNo: 8; pageNo: 2; headIdx: 5; letters: 4; firstLetter: 41),
    (wordNo: 7; pageNo: 4; headIdx: 6; letters: 6; firstLetter: 45),
    (wordNo: 1; pageNo: 4; headIdx: 7; letters: 4; firstLetter: 51),
    (wordNo: 6; pageNo: 4; headIdx: 7; letters: 9; firstLetter: 55),
    (wordNo: 1; pageNo: 7; headIdx: 8; letters: 2; firstLetter: 64),
    (wordNo: 8; pageNo: 7; headIdx: 8; letters: 6; firstLetter: 66),
    (wordNo: 6; pageNo: 7; headIdx: 8; letters: 7; firstLetter: 72),
    (wordNo: 5; pageNo: 8; headIdx: 9; letters: 3; firstLetter: 79),
    (wordNo: 8; pageNo: 8; headIdx: 9; letters: 4; firstLetter: 82),
    (wordNo: 6; pageNo: 8; headIdx: 9; letters: 3; firstLetter: 86),
    (wordNo: 3; pageNo: 8; headIdx: 10; letters: 4; firstLetter: 89),
    (wordNo: 6; pageNo: 8; headIdx: 10; letters: 3; firstLetter: 93),
    (wordNo: 6; pageNo: 8; headIdx: 10; letters: 3; firstLetter: 96),
    (wordNo: 1; pageNo: 9; headIdx: 11; letters: 4; firstLetter: 99),
    (wordNo: 8; pageNo: 9; headIdx: 11; letters: 4; firstLetter: 103),
    (wordNo: 1; pageNo: 10; headIdx: 12; letters: 2; firstLetter: 107),
    (wordNo: 7; pageNo: 10; headIdx: 12; letters: 6; firstLetter: 109),
    (wordNo: 1; pageNo: 5; headIdx: 13; letters: 5; firstLetter: 115),
    (wordNo: 8; pageNo: 5; headIdx: 13; letters: 7; firstLetter: 120),
    (wordNo: 7; pageNo: 10; headIdx: 14; letters: 5; firstLetter: 127),
    (wordNo: 8; pageNo: 10; headIdx: 14; letters: 2; firstLetter: 132),
    (wordNo: 6; pageNo: 12; headIdx: 15; letters: 5; firstLetter: 134),
    (wordNo: 9; pageNo: 12; headIdx: 15; letters: 8; firstLetter: 139),
    (wordNo: 7; pageNo: 15; headIdx: 16; letters: 5; firstLetter: 147),
    (wordNo: 9; pageNo: 15; headIdx: 16; letters: 7; firstLetter: 152),
    (wordNo: 4; pageNo: 17; headIdx: 17; letters: 4; firstLetter: 159),
    (wordNo: 8; pageNo: 17; headIdx: 17; letters: 6; firstLetter: 163),
    (wordNo: 5; pageNo: 49; headIdx: 18; letters: 5; firstLetter: 169),
    (wordNo: 9; pageNo: 49; headIdx: 18; letters: 2; firstLetter: 174),
    (wordNo: 1; pageNo: 53; headIdx: 19; letters: 5; firstLetter: 176),
    (wordNo: 7; pageNo: 53; headIdx: 19; letters: 7; firstLetter: 181));

{ Party order menus and the layouts of the character files the game can import. }
const
  { the order menu's two prompts: picking a member, then placing them }
  orderMenuTexts: array[0..1] of Types.TStr40 = ('Select Exit', 'Place Exit');
  { fifteen spaces, written over a name field before a new name goes in }
  blankName: String[15] = '               ';
  { per character-file format: the offset of the name in the record }
  nameOfsTbl: array[0..2] of Byte = (
    $00, $00, $04);
  { per character-file format: the offset of the in-party flag in the record }
  flagOffsets: array[0..2] of Word = (247, 132, 19);
  { per character-file format: the record size }
  recordSizes: array[0..2] of Word = (409, 409, 409);

{ Character generation: icon sizes and the creation menus. }
const
  { per icon size: the letter that picks the short or tall head and body pictures }
  heightMarks: array[1..2] of Char = ('S', 'T');
  { the party-creation menu; each entry starts enabled or disabled }
  mainMenuEntries: array[0..12] of Types.TMenuEntry = (
    (name: 'Create New Character'; enabled: 1),
    (name: 'Drop Character'; enabled: 0),
    (name: 'Modify Character'; enabled: 0),
    (name: 'Train Character'; enabled: 0),
    (name: 'Knight Change Classes'; enabled: 0),
    (name: 'View Character'; enabled: 0),
    (name: 'Add Character to Party'; enabled: 1),
    (name: 'Remove Character from Party'; enabled: 0),
    (name: 'Load Saved Game'; enabled: 1),
    (name: 'Save Current Game'; enabled: 0),
    (name: 'Begin Adventuring'; enabled: 0),
    (name: 'Initialize Mouse/Joystick'; enabled: 1),
    (name: 'Exit to DOS'; enabled: 1));
  { the alignments offered when a character's class allows any }
  alignmentChoices: array[0..5] of Byte = (
    0, 1, 3, 4, 6, 7);
  { the icon editor's menus, one per step }
  iconMenuTexts: array[1..5] of String[40] = (
    'Parts 1st-color 2nd-color Size Exit', 'Head Weapon Exit', 'Weapon Body xxxx Shield Arm Leg Exit', ' Keep Exit',
    'Next Prev Keep Exit');

{ Character rules, treasure, spell targeting, view and border tables, and the name tables. }
const
  { per class: the hit dice rolled at first level }
  hpDice: array[0..7] of Byte = (
    2, 1, 1, 1, 2, 1, 1, 2);
  { per class: the sides of each hit die }
  hpSides: array[0..7] of Byte = (
    8, 8, 10, 10, 8, 4, 6, 10);
  { the minimum base scores for joining the Order of the Sword }
  swordReq: array[0..5] of Byte = (
    12, 9, 13, 9, 10, 3);
  { the minimum base scores for joining the Order of the Rose }
  roseReq: array[0..5] of Byte = (
    15, 10, 13, 12, 15, 3);
  { the random treasure items, eight words to an item record }
  randomItemTable: array[1..56] of Word = (
    95, 94, 53, 1, 400, 3, 99, 0, 80, 90, 53, 1, 550, 1, 59, 0, 95, 90, 53, 1, 200, 1, 3, 0, 92, 90, 53, 1, 225, 1, 48,
    0, 98, 90, 51, 1, 5500, 30, 65, 0, 78, 90, 72, 10, 7500, 0, 38, 131, 88, 90, 7, 20, 1500, 1, 51, 0);
  { unused }
  specialLabel: String[40] = 'Special';
  { the spell-level labels shown in the spell menus }
  levelNameTable: array[1..9] of Types.TStr40 = (
    '1st Level', '2nd Level', '3rd Level', '4th Level', '5th Level', '6th Level', '7th Level', '8th Level',
    '9th Level');
  { per direction: the column step to the first side ray of an area spell }
  sideRayStepX1: array[0..7] of ShortInt = (-1, 0, 0, 1, 1, 0, 0, -1);
  { per direction: the row step to the first side ray }
  sideRayStepY1: array[0..7] of ShortInt = (0, -1, -1, 0, 0, 1, 1, 0);
  { per direction: the column step to the second side ray }
  sideRayStepX2: array[0..7] of ShortInt = (1, 1, 0, 0, -1, -1, 0, 0);
  { per direction: the row step to the second side ray }
  sideRayStepY2: array[0..7] of ShortInt = (0, 0, 1, 1, 0, 0, -1, -1);
  { the effects removed from a creature that drops to zero hit points }
  hpZeroEffectIds: array[1..16] of Byte = (3, 11, 21, 23, 27, 30, 31, 51, 52, 53, 91, 106, 107, 111, 118, 119);
  { per sky index: the sky color of the 3D view }
  skyMapArr: array[0..15] of Byte = (
    0, 15, 4, 11, 13, 2, 9, 14, 0, 15, 4, 11, 13, 2, 9, 14);
  { the colors an animation frame is remapped from }
  remapFromColors: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { the colors they become: color 13 turns black }
  remapToColors: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 14, 15);
  { per wall slice of the 3D view: where its tiles start, its size and its place on screen }
  viewSliceTable: Types.TViewSliceTable = (
    start: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154); cols: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1); rows: (2, 4, 4, 4, 8, 8, 8,
    11, 11, 2); xCol: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5); yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4));
  { Border-tile offset tables. Each cell's tile is SYMBOL_BASE plus the selected table value. }
  { the frame's top row }
  topEdgeTiles: array[0..39] of Byte = (
    0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0,
    0, 0, 0,
    0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0);
  { the frame's left column }
  leftEdgeTiles: array[0..23] of Byte = (
    0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0, 3, 4, 4, 4, 4, 5,
    0);
  { the column between the view and the text area }
  viewDividerTiles: array[0..16] of Byte = (
    0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0);
  { the frame's right column }
  rightEdgeTiles: array[0..23] of Byte = (
    0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0, 3, 4, 4, 4, 4, 5,
    0);
  { the left column of an inset window }
  insetLeftTiles: array[2..14] of Byte = (0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0);
  { the right column of an inset window }
  insetRightTiles: array[2..14] of Byte = (0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0);
  { the combat screen's left column }
  combatLeftTiles: array[0..22] of Byte = (
    0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0);
  { the combat screen's dividing column }
  combatMiddleTiles: array[0..22] of Byte = (
    0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0);
  { the combat screen's right column }
  combatRightTiles: array[0..22] of Byte = (
    0, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 0);
  { the character sheet's side columns }
  sheetSideTiles: array[0..22] of Byte = (
    0, 3, 4, 4, 4, 4, 4, 5, 0, 3, 4, 4, 4, 4, 4, 5, 0, 3, 4, 5, 0, 3, 5);
  { the character sheet's dividing column }
  sheetDividerTiles: array[9..19] of Byte = (3, 4, 4, 4, 4, 4, 5, 0, 3, 4, 5);
  { per CGA color: the byte that fills four pixels with it }
  cgaColorFill: array[0..3] of Byte = (
    $00, $55, $AA, $FF);
  { per Tandy color: the byte that fills two pixels with it }
  tandyColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);
  { the characters after which the word wrapper may break a line }
  breakChars: Types.TBreakCharSet = ['!', ',', '-', '.', ':', ';', '?'];
  { the characters a save name may not contain }
  invalidFileCharSet: array[1..10] of Char = (' ', '.', '*', ',', '?', '/', '\', ':', ';', '|');
  { Names: coin values; class, race, alignment, deity, order, gender, money and status names; name parts; compass
    names. }
  { per coin: its worth in the smallest coin }
  coinValue: array[0..4] of LongInt = (
    1, 5, 10, 25, 50);
  { per class id, single and multi-class }
  classNames: array[0..17] of String[26] = (
    'Cleric', 'Druid', 'Fighter', 'Paladin', 'Ranger', 'Mage', 'Thief', 'Knight', 'Cleric/Fighter',
    'Cleric/Fighter/Mage', 'Cleric/Ranger', 'Cleric/Mage', 'Cleric/Thief', 'Fighter/Mage', 'Fighter/Thief',
    'Fighter/Mage/Thief', 'Mage/Thief', 'OK buddy, who are you?');
  { per race id }
  raceNames: array[0..7] of String[15] = (
    'Silvanesti Elf', 'Qualinesti Elf', 'Half-elf', 'Mountain Dwarf', 'Hill Dwarf', 'Kender', 'Human', 'Monster');
  { per alignment id }
  alignmentNames: array[0..8] of String[16] = (
    'Lawful Good', 'Lawful Neutral', 'Lawful Evil', 'Neutral Good', 'True Neutral', 'Neutral Evil', 'Chaotic Good',
    'Chaotic Neutral', 'Chaotic Evil');
  { per deity id, None first }
  deityNames: array[0..7] of String[11] = (
    'None', 'Paladine', 'Majere', 'Kiri-Jolith', 'Mishakal', 'Sirrion', 'Reorx', 'Shinare');
  { per knightly order id, blank for none }
  orderNames: array[0..3] of String[6] = (
    '', 'White', 'Red', 'Black');
  { per gender id }
  genderNames: array[0..1] of String[6] = (
    'Male', 'Female');
  { per coin type, then gems and jewelry }
  moneyNames: array[0..6] of String[10] = (
    'Silver', 'Copper', 'Bronze', 'Platinum', 'Steel', 'Gems', 'Jewelry');
  { per health status }
  statusNames: array[0..8] of String[12] = (
    'Okay', 'Animated', 'tempgone', 'Running', 'Unconscious', 'Dying', 'Dead', 'Stoned', 'Gone');
  { Item-name components, indexed from 1. }
  nameParts: array[1..123] of String[20] = (
    'Battle Axe', 'Hand Axe', 'Club', 'Dagger', 'Dart', 'Hammer', 'Javelin', 'Mace', 'Morning Star',
    'Military Pick', 'Awl Pike', 'Quarrel', 'Scimitar', 'Spear', 'Quarter Staff', 'Bastard Sword',
    'Broad Sword', 'Long Sword', 'Short Sword', 'Two-Handed Sword', 'Trident', 'Composite Long Bow',
    'Composite Short Bow', 'Long Bow', 'Short Bow', 'Fine', 'Light Crossbow', 'Sling', 'Staff', 'Arrow',
    'Leather', 'Ring', 'Scale', 'Chain', 'Banded', 'Plate', 'Shield', 'Cler', 'Scroll', 'MU Scroll', 'Helm',
    'Belt', 'Robe', 'Cloak', 'Boots', 'Ring', 'Mail', 'Armor', 'Of Prot', 'Bracers', 'Wand', 'Amulet',
    'Potion', 'Holy Water', 'Ruby', 'Boulder', 'Dragon Breath', 'Displacement', 'Bag', 'Drow', 'Elven Chain',
    'Ice Storm', 'Saphire', 'Emerald', 'Wizardry', 'Hornet''s Nest', 'Hoopak', 'Solamnic Plate',
    'Dragonlance', 'Flail', 'Halberd', 'Gauntlets', 'Periapt', 'Proof vs Poison', 'Dust', 'Disappearance',
    'Disruption', 'Ogre Power', 'Girdle', 'Giant Strength', 'Mirror', 'Necklace', 'Dragon', 'vs Reptiles',
    'Frost Brand', 'Berserker', 'Diamond', 'Lightning', 'Fireballs', 'of', 'Vulnerability', 'Speed',
    'Silver', 'Extra', 'Healing', 'Opening', 'Fear', 'Magic Missiles', 'Missiles', '1 Spell', '2 Spells',
    '3 Spell', 'Paralyzation', 'Invisibility', 'Footman''s', 'AC 10', 'AC 6', 'AC 4', 'AC 3', 'AC 2', '+1',
    '+2', '+3', '+4', '+5', '-1', '-2', '-3', 'White', 'Red', 'Spiritual', 'Gem', 'Jewelry');
  { per facing, clockwise from north }
  dirNames: array[0..7] of String[2] = (
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW');
  { Video: Pathing's direction-by-delta table; text attributes; CGA/EGA pixel tables; color maps. }
  { per row and column step of -1, 0 or 1: the direction of the step }
  dirByDelta: array[0..2, 0..2] of Byte = (
    (C_Dir.NORTHWEST, C_Dir.NORTH, C_Dir.NORTHEAST), (C_Dir.WEST, C_Dir.CENTER, C_Dir.EAST),
    (C_Dir.SOUTHWEST, C_Dir.SOUTH, C_Dir.SOUTHEAST));
  { unused }
  dirByDeltaTail: array[0..11] of Byte = ($08, $04, $02, $01, $00, $00, $55, $55, $AA, $AA, $FF, $FF);
  { The attribute-to-CGA-color map: DaxIo and TEXTREND.OBJ read it. }
  attrTable: array[0..15] of Byte = (
    0, 0, 0, 1, 2, 2, 2, 3, 0, 1, 1, 1, 2, 2, 3, 3);
  { per pixel in a CGA word: the mask of its two bits }
  cgaBankMask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003);

{ Video pixel tables and color maps, sound commands, disk prompts, combat geometry and the spell table. }
const
  { per EGA plane: its bit in the map-mask register }
  egaPlaneBit: array[0..3] of Byte = (
    $01, $02, $04, $08);
  { per CGA color and pixel position: the color's bits at that position }
  cgaPixPos: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00), ($40, $10, $04, $01), ($80, $20, $08, $02), ($C0, $30, $0C, $03));
  { the four-color map the 3D view fills are drawn through }
  cmapStd: Types.TColorMap = (
    $00, $11, $22, $12, $01, $21, $30, $33);
  { the identity color table, the source side of a remap }
  cmapIdent: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  { the target side for icons: color 8 turns black }
  cmapPink8: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 0, 9, 10, 11, 12, 13, 14, 15);
  { Sound: sound commands and sound ids. }
  { SoundCommand's CMD_STOP -- FixMain and EclVm send it before priming an overlay while soundActive is set, FixMain's
    demo exit sends it unconditionally before introduction, and GameIo's reset sends it on exit }
  sndStop: Word = 255;
  { SoundCommand 0 -- every voice to sequence 0, the idle-channel sequence }
  sndSilence: Word = 0;
  { SoundCommand 1 -- sets the driver byte that gates its port writes }
  sndOutputOn: Word = 1;
  { the sound command played for a spell with no sound of its own }
  defaultSpellSound: Word = 2;
  { the sound command played when a creature takes damage }
  damageSnd: Word = 3;
  { the sound commands for the game's effects, from hits and misses to doors }
  soundIds: array[0..10] of Word = (
    4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14);
  { unused }
  soundIdsSpare: Word = 15;
  { Disk: data path and insert-disk message. }
  { per game disk after the first: the prompt to insert it }
  insertDiskMsg: array[1..3] of String[29] = (
    'Insert disk 2 in drive ', 'Insert disk 3 in drive ', 'Insert disk 4 in drive ');
  { Symbol-set ranges. }
  { per symbol set: its first symbol }
  symSetFirst: array[0..4] of Word = (
    1, 46, 116, 186, 256);
  { per symbol set: its last symbol }
  symSetLast: array[0..4] of Word = (
    45, 115, 185, 255, 295);
  { Combat: direction steps, combat terrain, icon footprints, helpless effects. }
  { per direction, then none: the column step }
  dirDeltaX: array[0..8] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0);
  { per direction, then none: the row step }
  dirDeltaY: array[0..8] of ShortInt = (
    -1, -1, 0, 1, 1, 1, 0, -1, 0);
  { per battle-map terrain id: what it costs to cross, its clearance, what it blocks and the tile drawn for it }
  terrainInfo: array[1..65] of Types.TTerrainRec = (
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 0),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 1),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 2),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 3),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 4),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 5),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 6),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 7),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 8),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 9),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 10),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 11),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 12),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 13),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 14),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 15),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 16),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 17),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 18),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 19),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 20),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 21),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 22),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 23),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 24),
    (movementCost: 2; clearance: 2; blocking: 0; tileId: 34),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 35),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 36),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 37),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 38),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 39),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 0),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 1),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 2),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 3),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 4),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 5),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 6),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 7),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 8),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 9),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 10),
    (movementCost: 255; clearance: 1; blocking: 2; tileId: 11),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 12),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 13),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 14),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 15),
    (movementCost: 2; clearance: 1; blocking: 0; tileId: 16),
    (movementCost: 2; clearance: 1; blocking: 0; tileId: 17),
    (movementCost: 2; clearance: 1; blocking: 0; tileId: 18),
    (movementCost: 2; clearance: 1; blocking: 0; tileId: 19),
    (movementCost: 2; clearance: 1; blocking: 0; tileId: 20),
    (movementCost: 2; clearance: 1; blocking: 0; tileId: 21),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 22),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 23),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 24),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 25),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 26),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 27),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 28),
    (movementCost: 4; clearance: 0; blocking: 0; tileId: 29),
    (movementCost: 4; clearance: 0; blocking: 0; tileId: 30),
    (movementCost: 4; clearance: 0; blocking: 0; tileId: 31),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 32),
    (movementCost: 1; clearance: 1; blocking: 0; tileId: 33));
  { per icon size and part: where the part sits relative to the icon's square }
  iconDelta: array[1..4, 0..3] of Types.TIconDelta = (
    ((deltaX: 0; deltaY: 0), (deltaX: -1; deltaY: -1), (deltaX: -1; deltaY: -1), (deltaX: -1; deltaY: -1)),
    ((deltaX: 0; deltaY: 0), (deltaX: 0; deltaY: 1), (deltaX: -1; deltaY: -1), (deltaX: -1; deltaY: -1)),
    ((deltaX: 0; deltaY: 0), (deltaX: 1; deltaY: 0), (deltaX: -1; deltaY: -1), (deltaX: -1; deltaY: -1)),
    ((deltaX: 0; deltaY: 0), (deltaX: 1; deltaY: 0), (deltaX: 0; deltaY: 1), (deltaX: 1; deltaY: 1)));
  { the effects that leave a creature helpless }
  helplessFx: array[1..4] of Byte = (
    51, 52, 53, 31);
  { Menu: digit scan codes and MenuCore's combat map. }
  { per keypad digit: the scan code of the key it stands for }
  digitScanCodes: array[0..8] of Byte = (
    Ord(C_Keys.END_KEY), Ord(C_Keys.DOWN), Ord(C_Keys.PAGE_DOWN), Ord(C_Keys.LEFT), 32, Ord(C_Keys.RIGHT),
    Ord(C_Keys.HOME), Ord(C_Keys.UP), Ord(C_Keys.PAGE_UP));
  { per square offset from the combat cursor: the arrow-key scan code that moves it that way }
  combatMap: array[3..13, 3..13] of Byte = (
    (72, 72, 72, 72, 72, 72, 72, 72, 72, 72, 72), (75, 72, 72, 72, 72, 72, 72, 72, 72, 72, 77),
    (75, 75, 72, 72, 72, 72, 72, 72, 72, 77, 77), (75, 75, 75, 72, 72, 72, 72, 72, 77, 77, 77),
    (75, 75, 75, 75, 72, 72, 72, 77, 77, 77, 77), (75, 75, 75, 75, 75, 72, 77, 77, 77, 77, 77),
    (75, 75, 75, 75, 80, 80, 80, 77, 77, 77, 77), (75, 75, 75, 80, 80, 80, 80, 80, 77, 77, 77),
    (75, 75, 80, 80, 80, 80, 80, 80, 80, 77, 77), (75, 80, 80, 80, 80, 80, 80, 80, 80, 80, 77),
    (80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80));
  { Magic: cloud directions. }
  { the directions of the four cells a cloud covers, from its corner cell }
  cloudDirs: array[1..4] of Byte = (C_Dir.CENTER, C_Dir.EAST, C_Dir.SOUTHEAST, C_Dir.SOUTH);
  { the directions of the nine cells a large cloud covers; nothing reads it }
  cloudDirs9: array[1..9] of Byte = (
    C_Dir.CENTER, C_Dir.NORTH, C_Dir.NORTHEAST, C_Dir.EAST, C_Dir.SOUTHEAST, C_Dir.SOUTH, C_Dir.SOUTHWEST, C_Dir.WEST,
    C_Dir.NORTHWEST);

{ Magic: spell names and the spell table. }
const
  { per spell id }
  spellNames: array[1..107] of Types.TStr40 = (
    'Bless', 'Curse', 'Cure Light Wounds', 'Cause Light Wounds', 'Detect Magic', 'Protection From Evil',
    'Protection from Good', 'Resist Cold', 'Burning Hands', 'Charm Person', 'Detect Magic', 'Enlarge', 'Reduce',
    'Friends', 'Magic Missile', 'Protection From Evil', 'Protection From Good', 'Read Magic', 'Shield',
    'Shocking Grasp', 'Sleep', 'Find Traps', 'Hold Person', 'Resist Fire', 'Silence, 15'' Radius', 'Slow Poison',
    'Snake Charm', 'Spiritual Hammer', 'Detect Invisibility', 'Invisibility', 'Knock', 'Mirror Image',
    'Ray of Enfeeblement', 'Stinking Cloud', 'Strength', 'Animate Dead', 'Cure Blindness', 'Cause Blindness',
    'Cure Disease', 'Cause Disease', 'Dispel Magic', 'Prayer', 'Remove Curse', 'Bestow Curse', 'Blink', 'Dispel Magic',
    'Fireball', 'Haste', 'Hold Person', 'Invisibility, 10'' Radius', 'Lightning Bolt',
    'Protection From Evil, 10'' Radius', 'Protection From Good, 10'' Radius', 'Protection From Normal Missiles', 'Slow',
    'Restoration', '', 'Cure Serious Wounds', '', '', '', '', '', '', '', 'Cause Serious Wounds', 'Neutralize Poison',
    'Poison', 'Protection Evil, 10'' Radius', 'Sticks to Snakes', 'Cure Critical Wounds', 'Cause Critical Wounds',
    'Dispel Evil', 'Flame Strike', 'Raise Dead', 'Slay Living', 'Detect Magic', 'Entangle', 'Faerie Fire',
    'Invisibility to Animals', 'Charm Monsters', 'Confusion', 'Dimension Door', 'Fear', 'Fire Shield', 'Fumble',
    'Ice Storm', 'Minor Globe Of Invulnerability', 'Remove Curse', 'Animate Dead', 'Cloud Kill', 'Cone of Cold',
    'Feeblemind', 'Hold Monsters', '', '', '', '', '', 'Bestow Curse', 'Protection From Evil 10'' Radius',
    'Silence 15'' radius', 'Detect Magic', 'Remove Curse', 'Bless', 'Charm Person', 'Burning Hands');
  { the spell table, indexed by spell id }
  spellTbl: array[1..107] of Types.TSpellRec = (
    { 1 Bless }
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; area: 10; targeting: 4;
     saveEffect: 0; saveType: 4; effect: 1; combatOk: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 2 Curse }
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; area: 10; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 2; combatOk: 1; castTime: 10; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 3 Cure Light Wounds }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 4 Cause Light Wounds }
    (castClass: 0; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 5; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 5 Detect Magic }
    (castClass: 0; level: 1; rangeBase: 3; rangePerLevel: 0; durBase: 10; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 5; combatOk: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 6 Protection From Evil }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 8; combatOk: 2; castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 7 Protection from Good }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 9; combatOk: 2; castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 8 Resist Cold }
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 10; combatOk: 2; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 9 Burning Hands }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 10 Charm Person }
    (castClass: 3; level: 1; rangeBase: 12; rangePerLevel: 0; durBase: 60; durPerLevel: 60; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 11; combatOk: 1; castTime: 1; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 11 Detect Magic }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 5; combatOk: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 12 Enlarge }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 12; combatOk: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 13 Reduce }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 1; saveType: 4; effect: 13; combatOk: 2; castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 14 Friends }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 14; combatOk: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 15 Magic Missile }
    (castClass: 3; level: 1; rangeBase: 6; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 1; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 16 Protection From Evil }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 8; combatOk: 2; castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 17 Protection From Good }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 9; combatOk: 2; castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 18 Read Magic }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 16; combatOk: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 19 Shield }
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 5; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 17; combatOk: 2; castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 20 Shocking Grasp }
    (castClass: 3; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 21 Sleep }
    (castClass: 3; level: 1; rangeBase: 3; rangePerLevel: 4; durBase: 0; durPerLevel: 5; area: 9; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 53; combatOk: 1; castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 1),
    { 22 Find Traps }
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 30; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 19; combatOk: 0; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 23 Hold Person }
    (castClass: 0; level: 2; rangeBase: 6; rangePerLevel: 0; durBase: 4; durPerLevel: 1; area: 6; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 52; combatOk: 1; castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 24 Resist Fire }
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 20; combatOk: 2; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 25 Silence, 15' Radius }
    (castClass: 0; level: 2; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 31; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 21; combatOk: 1; castTime: 5; aiPriority: 2; offensive: 1; aiRadius: 1),
    { 26 Slow Poison }
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 22; combatOk: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 27 Snake Charm }
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 240; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 51; combatOk: 1; castTime: 5; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 28 Spiritual Hammer }
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 23; combatOk: 2; castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 29 Detect Invisibility }
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 5; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 24; combatOk: 2; castTime: 2; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 30 Invisibility }
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 25; combatOk: 2; castTime: 2; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 31 Knock }
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 32 Mirror Image }
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 28; combatOk: 2; castTime: 2; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 33 Ray of Enfeeblement }
    (castClass: 3; level: 2; rangeBase: 1; rangePerLevel: 1; durBase: 0; durPerLevel: 1; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 29; combatOk: 1; castTime: 2; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 34 Stinking Cloud }
    (castClass: 3; level: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 9; targeting: 0;
     saveEffect: 3; saveType: 0; effect: 30; combatOk: 1; castTime: 2; aiPriority: 4; offensive: 1; aiRadius: 1),
    { 35 Strength }
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 38; combatOk: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 36 Animate Dead }
    (castClass: 4; level: 7; rangeBase: 5; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 8; targeting: 4;
     saveEffect: 1; saveType: 4; effect: 0; combatOk: 2; castTime: 0; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 37 Cure Blindness }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 38 Cause Blindness }
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 33; combatOk: 1; castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 39 Cure Disease }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 0; castTime: 100; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 40 Cause Disease }
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 34; combatOk: 1; castTime: 100; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 41 Dispel Magic }
    (castClass: 0; level: 3; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 9; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 4; aiPriority: 1; offensive: 1; aiRadius: 1),
    { 42 Prayer }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 4;
     saveEffect: 0; saveType: 4; effect: 49; combatOk: 2; castTime: 6; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 43 Remove Curse }
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 44 Bestow Curse }
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 36; combatOk: 1; castTime: 6; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 45 Blink }
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 37; combatOk: 1; castTime: 1; aiPriority: 4; offensive: 0; aiRadius: 0),
    { 46 Dispel Magic }
    (castClass: 3; level: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 9; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 1),
    { 47 Fireball }
    (castClass: 3; level: 3; rangeBase: 10; rangePerLevel: 1; durBase: 0; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 2; saveType: 4; effect: 0; combatOk: 1; castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 48 Haste }
    (castClass: 3; level: 3; rangeBase: 6; rangePerLevel: 0; durBase: 3; durPerLevel: 1; area: 10; targeting: 4;
     saveEffect: 0; saveType: 4; effect: 39; combatOk: 2; castTime: 3; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 49 Hold Person }
    (castClass: 3; level: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 7; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 52; combatOk: 1; castTime: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 50 Invisibility, 10' Radius }
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 9; targeting: 4;
     saveEffect: 0; saveType: 4; effect: 25; combatOk: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 51 Lightning Bolt }
    (castClass: 3; level: 3; rangeBase: 4; rangePerLevel: 1; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 2; saveType: 4; effect: 0; combatOk: 1; castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 52 Protection From Evil, 10' Radius }
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 45; combatOk: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 53 Protection From Good, 10' Radius }
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 46; combatOk: 2; castTime: 3; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 54 Protection From Normal Missiles }
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 41; combatOk: 2; castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 55 Slow }
    (castClass: 3; level: 3; rangeBase: 9; rangePerLevel: 1; durBase: 3; durPerLevel: 1; area: 10; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 42; combatOk: 1; castTime: 3; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 56 Restoration }
    (castClass: 0; level: 7; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 57 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 39; combatOk: 2; castTime: 0; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 58 Cure Serious Wounds }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 59 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 38; combatOk: 2; castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 60 }
    (castClass: 4; level: 6; rangeBase: 4; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 2; saveType: 4; effect: 0; combatOk: 1; castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 61 }
    (castClass: 4; level: 6; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 0; effect: 52; combatOk: 1; castTime: 0; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 62 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 39; combatOk: 2; castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 63 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 7; targeting: 4;
     saveEffect: 0; saveType: 4; effect: 71; combatOk: 2; castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 64 }
    (castClass: 4; level: 6; rangeBase: 7; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 2; saveType: 4; effect: 0; combatOk: 1; castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 65 }
    (castClass: 4; level: 6; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 0; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 66 Cause Serious Wounds }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 7; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 67 Neutralize Poison }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 0; castTime: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 68 Poison }
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 0; effect: 0; combatOk: 1; castTime: 7; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 69 Protection Evil, 10' Radius }
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 45; combatOk: 2; castTime: 7; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 70 Sticks to Snakes }
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 3; combatOk: 1; castTime: 7; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 71 Cure Critical Wounds }
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 8; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 72 Cause Critical Wounds }
    (castClass: 0; level: 5; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 0; combatOk: 1; castTime: 8; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 73 Dispel Evil }
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 8; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 74 Flame Strike }
    (castClass: 0; level: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 2; saveType: 4; effect: 0; combatOk: 1; castTime: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 75 Raise Dead }
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 76 Slay Living }
    (castClass: 0; level: 5; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 0; combatOk: 1; castTime: 10; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 77 Detect Magic }
    (castClass: 1; level: 1; rangeBase: 3; rangePerLevel: 0; durBase: 12; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 5; combatOk: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 78 Entangle }
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durBase: 10; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 0; combatOk: 1; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 79 Faerie Fire }
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durBase: 0; durPerLevel: 4; area: 5; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 7; combatOk: 1; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 80 Invisibility to Animals }
    (castClass: 1; level: 1; rangeBase: 255; rangePerLevel: 0; durBase: 10; durPerLevel: 1; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 69; combatOk: 2; castTime: 4; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 81 Charm Monsters }
    (castClass: 3; level: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 5; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 11; combatOk: 1; castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 82 Confusion }
    (castClass: 3; level: 4; rangeBase: 12; rangePerLevel: 0; durBase: 2; durPerLevel: 1; area: 11; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 35; combatOk: 1; castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 83 Dimension Door }
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 3; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 84 Fear }
    (castClass: 3; level: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 8; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 111; combatOk: 1; castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 85 Fire Shield }
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 2; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 4; aiPriority: 7; offensive: 0; aiRadius: 0),
    { 86 Fumble }
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 27; combatOk: 1; castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 87 Ice Storm }
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 0; area: 10; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 88 Minor Globe Of Invulnerability }
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 63; combatOk: 2; castTime: 4; aiPriority: 6; offensive: 0; aiRadius: 0),
    { 89 Remove Curse }
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 4; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 90 Animate Dead }
    (castClass: 4; level: 5; rangeBase: 1; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 240; targeting: 4;
     saveEffect: 0; saveType: 4; effect: 32; combatOk: 2; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 91 Cloud Kill }
    (castClass: 3; level: 5; rangeBase: 2; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 9; targeting: 0;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 92 Cone of Cold }
    (castClass: 3; level: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 2; saveType: 4; effect: 0; combatOk: 1; castTime: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 93 Feeblemind }
    (castClass: 3; level: 5; rangeBase: 16; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 68; combatOk: 1; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 94 Hold Monsters }
    (castClass: 3; level: 5; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 1; area: 7; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 52; combatOk: 1; castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 95 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 73; combatOk: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 96 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 97; combatOk: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 97 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 25; combatOk: 2; castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 98 }
    (castClass: 4; level: 6; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 0; combatOk: 1; castTime: 0; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 99 }
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 2; castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 100 Bestow Curse }
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 0; combatOk: 1; castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 101 Protection From Evil 10' Radius }
    (castClass: 2; level: 0; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 45; combatOk: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 102 Silence 15' radius }
    (castClass: 2; level: 0; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 31; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 21; combatOk: 1; castTime: 5; aiPriority: 2; offensive: 1; aiRadius: 1),
    { 103 Detect Magic }
    (castClass: 2; level: 0; rangeBase: 0; rangePerLevel: 0; durBase: 10; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 5; combatOk: 2; castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 104 Remove Curse }
    (castClass: 2; level: 0; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effect: 2; combatOk: 2; castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 105 Bless }
    (castClass: 2; level: 0; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; area: 10; targeting: 4;
     saveEffect: 0; saveType: 4; effect: 1; combatOk: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 106 Charm Person }
    (castClass: 2; level: 0; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effect: 11; combatOk: 1; castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 107 Burning Hands }
    (castClass: 2; level: 0; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 1;
     saveEffect: 0; saveType: 4; effect: 0; combatOk: 1; castTime: 1; aiPriority: 3; offensive: 1; aiRadius: 0));

{ The game clock and the class, race, age, level and skill rules. }
const
  { GameTime: rest time units. }
  { per clock component: its modulus, ticks first and years last }
  unitScale: Types.TClock = (
    10, 10, 6, 24, 30, 12, 256);
  { Class, race, age, level and skill rules. }
  { per class and level: the to-hit base }
  thac0Table: array[0..7, 0..12] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46), (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46),
    (39, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51), (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51),
    (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51), (39, 39, 39, 39, 39, 39, 41, 41, 41, 41, 41, 43, 43),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44, 44, 44), (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51));
  { class slot -> its bit in TBaseItem.classMask; eight disjoint single bits }
  classMaskTable: array[0..7] of Byte = (
    $02, $20, $08, $40, $80, $01, $04, $10);
  { per class id: its bit in the class masks }
  classBits: array[0..16] of Byte = (
    $02, $02, $08, $10, $20, $01, $04, $10, $10, $10, $10, $20, $20, $20, $40, $40, $40);
  { per class: the level after which hit points no longer come from dice }
  hitDiceLimit: array[0..7] of Byte = (
    10, 15, 10, 10, 11, 12, 11, 10);
  { the default colors of a new character's icon parts }
  defIconColors: array[1..6] of Byte = (
    1, 2, 3, 4, 6, 7);
  { per thief level: the eight thief skills in percent }
  thiefSkillTable: array[1..12, 1..8] of Byte = (
    (30, 25, 20, 15, 10, 10, 85, 0), (35, 29, 25, 21, 15, 10, 86, 0), (40, 33, 30, 27, 20, 15, 87, 0),
    (45, 37, 35, 33, 25, 15, 88, 20), (50, 42, 40, 40, 31, 20, 90, 25), (55, 47, 45, 47, 37, 20, 92, 30),
    (60, 52, 50, 55, 43, 25, 94, 35), (65, 57, 55, 62, 49, 25, 96, 40), (70, 62, 60, 70, 56, 30, 98, 45),
    (80, 67, 65, 78, 63, 30, 99, 50), (90, 72, 70, 86, 70, 35, 99, 60), (100, 77, 75, 94, 77, 35, 99, 65));
  { per race: the change to each thief skill }
  raceSkillAdjust: array[0..6, 1..8] of ShortInt = (
    (0, 10, 15, 0, 0, 0, -10, -5), (5, -5, 0, 5, 10, 5, 0, 0), (0, 5, 10, 5, 5, 10, -15, 0), (10, 0, 0, 0, 5, 0, 0, 0),
    (5, 5, 5, 10, 15, 5, -15, -5), (-5, 5, 5, 0, 0, 5, 5, -10), (0, 0, 0, 0, 0, 0, 0, 0));
  { per dexterity: the change to the first five thief skills }
  dexteritySkillAdjust: array[9..19, 1..5] of ShortInt = (
    (-15, -10, -10, -20, -10), (-19, -5, -10, -15, -5), (-5, 0, -5, -10, 0), (0, 0, 0, -5, 0),
    (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, -5, 0, 0, 0), (5, 10, 0, 5, 5),
    (10, 15, 5, 10, 10), (15, 20, 10, 12, 12));
  { per race: the lowest and highest scores a character of that race may have }
  raceLimits: array[0..6] of Types.TRaceLimits = (
    (strMin: (3, 3); strMax: (18, 16); strExcMax: (75, 0);
     intMin: 10; intMax: 18; wisMin: 6; wisMax: 18; dexMin: 7; dexMax: 19;
     conMin: 6; conMax: 18; chaMin: 12; chaMax: 18),
    (strMin: (7, 7); strMax: (18, 16); strExcMax: (75, 0);
     intMin: 8; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 7; dexMax: 19;
     conMin: 7; conMax: 18; chaMin: 8; chaMax: 18),
    (strMin: (3, 3); strMax: (18, 17); strExcMax: (90, 0);
     intMin: 4; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 6; dexMax: 18;
     conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (8, 8); strMax: (18, 17); strExcMax: (99, 0);
     intMin: 3; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17;
     conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    (strMin: (9, 9); strMax: (18, 17); strExcMax: (99, 0);
     intMin: 3; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17;
     conMin: 14; conMax: 19; chaMin: 3; chaMax: 12),
    (strMin: (6, 6); strMax: (16, 16); strExcMax: (0, 0);
     intMin: 6; intMax: 18; wisMin: 3; wisMax: 16; dexMin: 8; dexMax: 19;
     conMin: 10; conMax: 18; chaMin: 6; chaMax: 18),
    (strMin: (3, 3); strMax: (18, 18); strExcMax: (100, 50);
     intMin: 3; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18;
     conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { per race: count, class ids }
  raceClass: array[0..6, 0..14] of ShortInt = (
    (9, 0, 2, 5, 4, 8, 9, 10, 11, 13, 0, 0, 0, 0, 0),
    (13, 0, 2, 5, 6, 4, 8, 10, 9, 11, 13, 14, 15, 16, 0),
    (14, 0, 2, 5, 6, 4, 7, 8, 10, 9, 11, 13, 14, 15, 16),
    (6, 0, 2, 6, 8, 12, 14, 0, 0, 0, 0, 0, 0, 0, 0),
    (8, 0, 2, 6, 4, 8, 10, 12, 14, 0, 0, 0, 0, 0, 0),
    (8, 0, 2, 6, 4, 8, 10, 12, 14, 0, 0, 0, 0, 0, 0),
    (6, 0, 2, 5, 6, 4, 7, 0, 0, 0, 0, 0, 0, 0, 0));
  { per race and class: the starting age as a base plus dice }
  startAge: array[0..6, 0..7] of Types.TStartAge = (
    ((base: 250; dice: 10; sides: 10), (base: 0; dice: 0; sides: 0), (base: 150; dice: 5; sides: 6),
     (base: 150; dice: 5; sides: 6), (base: 150; dice: 5; sides: 6), (base: 250; dice: 10; sides: 10),
     (base: 150; dice: 5; sides: 4), (base: 130; dice: 5; sides: 6)),
    ((base: 250; dice: 10; sides: 10), (base: 0; dice: 0; sides: 0), (base: 150; dice: 5; sides: 6),
     (base: 150; dice: 5; sides: 6), (base: 150; dice: 5; sides: 6), (base: 250; dice: 10; sides: 10),
     (base: 150; dice: 5; sides: 4), (base: 130; dice: 5; sides: 6)),
    ((base: 40; dice: 3; sides: 6), (base: 0; dice: 0; sides: 0), (base: 22; dice: 3; sides: 4),
     (base: 22; dice: 3; sides: 4), (base: 22; dice: 3; sides: 4), (base: 40; dice: 3; sides: 6),
     (base: 22; dice: 3; sides: 8), (base: 22; dice: 3; sides: 4)),
    ((base: 60; dice: 3; sides: 10), (base: 0; dice: 0; sides: 0), (base: 60; dice: 3; sides: 6),
     (base: 60; dice: 3; sides: 6), (base: 60; dice: 3; sides: 6), (base: 60; dice: 3; sides: 10),
     (base: 22; dice: 3; sides: 4), (base: 22; dice: 3; sides: 6)),
    ((base: 60; dice: 3; sides: 10), (base: 0; dice: 0; sides: 0), (base: 60; dice: 3; sides: 6),
     (base: 60; dice: 3; sides: 6), (base: 60; dice: 3; sides: 6), (base: 60; dice: 3; sides: 10),
     (base: 22; dice: 3; sides: 4), (base: 22; dice: 3; sides: 6)),
    ((base: 33; dice: 3; sides: 6), (base: 0; dice: 0; sides: 0), (base: 22; dice: 3; sides: 4),
     (base: 22; dice: 3; sides: 4), (base: 22; dice: 3; sides: 6), (base: 33; dice: 3; sides: 6),
     (base: 20; dice: 2; sides: 4), (base: 22; dice: 1; sides: 4)),
    ((base: 18; dice: 1; sides: 4), (base: 18; dice: 1; sides: 4), (base: 15; dice: 1; sides: 4),
     (base: 17; dice: 1; sides: 4), (base: 20; dice: 1; sides: 4), (base: 24; dice: 2; sides: 4),
     (base: 18; dice: 1; sides: 4), (base: 20; dice: 1; sides: 4)));
  { per race: the ages at which each age category begins }
  ageLimit: array[0..6] of Types.TAgeLimits = (
    (limit: (250, 650, 1000, 1500, 2000)), (limit: (250, 650, 1000, 1500, 2000)),
    (limit: (40, 100, 175, 250, 325)), (limit: (60, 175, 275, 400, 525)), (limit: (50, 150, 250, 350, 450)),
    (limit: (33, 68, 101, 144, 199)), (limit: (20, 40, 60, 90, 120)));
  { per class id: the lowest score in each ability the class needs }
  classMin: array[0..16, 0..5] of Byte = (
    (6, 6, 9, 0, 0, 0), (0, 0, 12, 0, 0, 15), (9, 0, 6, 6, 7, 0), (10, 7, 10, 8, 10, 0),
    (13, 13, 14, 0, 14, 0), (0, 9, 6, 6, 0, 0), (6, 6, 0, 9, 0, 0), (10, 7, 10, 8, 10, 0), (9, 0, 9, 0, 0, 0),
    (9, 9, 9, 0, 0, 0), (0, 13, 14, 0, 14, 0), (0, 9, 9, 0, 0, 0), (0, 0, 9, 9, 0, 0), (9, 9, 0, 0, 0, 0),
    (9, 0, 0, 9, 0, 0), (9, 9, 0, 9, 0, 0), (0, 9, 0, 9, 0, 0));
  { per class id: the alignments it allows, one bit each }
  classAlignMask: array[0..16] of Byte = (
    $3F, $3F, $3F, $01, $15, $3F, $0E, $01, $3F, $3F, $15, $3F, $0E, $3F, $0E, $0E, $0E);
  { per constitution: the hit-point change per die }
  conHpTable: array[3..25] of ShortInt = (
    -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);
  { per class: the experience for each level and the spells gained at each }
  classProgression: array[0..9] of Types.TClassProgression = (
    (nextLevelXp: (4000, 7500, 15250, 25000, 40000, 90000, 160000, -1, -1, -1, -1);
     spellSlots: ((1, 0, 0, 0, 0), (0, 1, 0, 0, 0), (0, 1, 0, 0, 0), (1, 1, 1, 0, 0), (0, 0, 1, 0, 0), (0, 0, 0, 1, 0),
       (0, 0, 1, 1, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (3000, 6000, 13000, 27500, 55000, 110000, 225000, -1, -1, -1, -1);
     spellSlots: ((0, 1, 0, 0, 0), (1, 1, 1, 0, 0), (1, 0, 1, 0, 0), (0, 1, 0, 0, 0), (0, 0, 0, 1, 0), (0, 1, 1, 0, 0),
       (0, 0, 0, 1, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (2001, 4001, 8001, 18001, 35001, 70001, 125001, -1, -1, -1, -1);
     spellSlots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (5000, 10000, 18500, 37000, 85000, 140000, 220000, -1, -1, -1, -1);
     spellSlots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (5000, 12000, 24000, 45000, 95000, 175000, 350000, -1, -1, -1, -1);
     spellSlots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (1, 0, 0, 0, 0), (1, 0, 0, 0, 0),
       (0, 1, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (5000, 12000, 27000, 60000, 125000, 200000, 425000, -1, -1, -1, -1);
     spellSlots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (1, 0, 0, 0, 0), (1, 0, 0, 0, 0),
       (0, 1, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (2251, 4501, 10001, 20001, 40001, 90001, -1, -1, -1, -1, -1);
     spellSlots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (5000, 10000, 20000, 38000, 55000, 100000, 200000, -1, -1, -1, -1);
     spellSlots: ((1, 0, 0, 0, 0), (0, 1, 0, 0, 0), (1, 1, 0, 0, 0), (1, 0, 1, 0, 0), (0, 0, 1, 0, 0), (0, 1, 0, 1, 0),
       (0, 0, 1, 1, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (5000, 10000, 18000, 36000, 50000, 90000, 180000, -1, -1, -1, -1);
     spellSlots: ((1, 0, 0, 0, 0), (0, 1, 0, 0, 0), (1, 1, 1, 0, 0), (1, 1, 0, 0, 0), (0, 0, 1, 0, 0), (0, 0, 0, 1, 0),
       (0, 0, 1, 1, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (nextLevelXp: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001, -1, -1, -1);
     spellSlots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))));
  { each class's starting-money dice (count, sides); unused, CharGen rolls its own }
  startingMoneyDice: array[0..7, 0..1] of Byte = (
    (3, 6), (3, 6), (5, 4), (5, 4), (5, 4), (2, 4), (2, 6), (5, 4));
  { per class, level and save category: the d20 roll needed }
  savingThrowTable: array[0..7, 1..12, 0..4] of Byte = (
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11), (6, 9, 10, 12, 11)),
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11), (6, 9, 10, 12, 11)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14), (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10), (7, 8, 9, 8, 10)),
    ((12, 13, 14, 15, 15), (12, 13, 14, 15, 15), (11, 12, 13, 14, 14), (11, 12, 13, 14, 14), (9, 9, 11, 11, 12),
     (9, 9, 11, 11, 12), (8, 9, 10, 10, 11), (9, 9, 10, 10, 11), (6, 7, 8, 7, 9), (6, 7, 8, 7, 9), (5, 6, 7, 6, 8),
     (5, 6, 7, 6, 8)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14), (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10), (7, 8, 9, 8, 10)),
    ((14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12),
     (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10),
     (11, 9, 7, 11, 8), (11, 9, 7, 11, 8)),
    ((13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (11, 10, 10, 14, 11), (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11), (11, 10, 10, 14, 11)),
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14), (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10), (7, 8, 9, 8, 10)));
  { the spells a caster knows, by list and spell level: the cleric's, then the mage's for robe order 1 and for the other
    orders }
  knownSpellTable: array[1..3, 1..4, 1..10] of Byte = (
    ((1, 3, 5, 6, 0, 0, 0, 0, 0, 0), (22, 23, 24, 25, 26, 27, 28, 0, 0, 0),
     (37, 39, 41, 42, 43, 0, 0, 0, 0, 0), (67, 70, 58, 69, 0, 0, 0, 0, 0, 0)),
    ((10, 11, 14, 15, 16, 18, 19, 21, 0, 0), (29, 34, 33, 0, 0, 0, 0, 0, 0, 0),
     (46, 47, 49, 51, 52, 54, 0, 0, 0, 0), (85, 87, 81, 82, 86, 88, 89, 0, 0, 0)),
    ((9, 11, 12, 15, 18, 19, 20, 0, 0, 0), (29, 30, 31, 32, 34, 35, 0, 0, 0, 0),
     (45, 47, 48, 50, 51, 55, 0, 0, 0, 0), (85, 87, 83, 84, 0, 0, 0, 0, 0, 0)));

{ Mouse cursor masks and the joystick. }
const
  { Mouse cursor masks. }
  { the arrow cursor's screen and cursor masks for EGA and Tandy }
  cursorMaskEga: Types.TCursorMask = (
    $FF, $3F, $FF, $1F, $FF, $0F, $FF, $07, $FF, $03, $FF, $01, $FF, $00, $7F, $00, $3F, $00, $3F, $00, $FF, $01, $FF,
    $00, $FF, $10,
    $7F, $F8, $7F, $F8, $7F, $FC, $00, $00, $00, $40, $00, $60, $00, $70, $00, $78, $00, $7C, $00, $7E, $00, $7F, $80,
    $7F, $00, $7C,
    $00, $6C, $00, $46, $00, $06, $00, $03, $00, $03, $00, $00);
  { the arrow cursor's masks for CGA }
  cursorMaskCga: Types.TCursorMask = (
    $FF, $0F, $FF, $03, $FF, $00, $3F, $00, $0F, $00, $03, $00, $00, $00, $03, $00, $03, $00, $03, $3F, $00, $FF, $00,
    $FF, $C3, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $00, $00, $00, $30, $00, $3C, $00, $3F, $C0, $3F, $F0, $3F, $FC, $3F, $C0, $3F, $F0,
    $3C, $F0, $00,
    $3C, $00, $3C, $00, $00, $00, $00, $00, $00, $00, $00, $00);
  { Joystick zone map. }
  { per stick zone: the direction it stands for, 8 for the center }
  zoneMap: array[0..5, 0..5] of Byte = (
    (7, 7, 0, 0, 1, 1), (7, 8, 8, 8, 8, 1), (6, 8, 8, 8, 8, 2), (6, 8, 8, 8, 8, 2), (5, 8, 8, 8, 8, 3),
    (5, 5, 4, 4, 3, 3));
  { The keypad digit each joystick direction stands for, clockwise from north. }
  scancodeTable: array[0..9] of Byte = (
    Ord('8'), Ord('9'), Ord('6'), Ord('3'), Ord('2'), Ord('1'), Ord('4'), Ord('7'), 32, 0);

implementation

end.
