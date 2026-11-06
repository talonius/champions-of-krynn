{ Saving and restoring games, and character-file I/O: listing, loading, saving and deleting characters, loading creature
  data and adding characters and creatures to the party.

  ScanSaveFiles is nested in LoadCharlist, and ComputePartySaveSize in SaveGame. Note: the file routines read DosError,
  not IOResult, after Reset, Rewrite and MkDir. }
{$O+,F+,I-}
unit SaveLoad;

interface

uses Types, Blit, Dos, TextRend, GameIo, DaxIo, FxEngine, CharHlp, ClassCal, MenuCore, Portrait, View3D, MapTiles,
  Debug, Crt, GDConsts, GDVars, C_Keys, C_Gbvm, C_Ifc, C_Npc;

type
  { the name field of an imported (importFormat = 2) character file }
  TRawCharacterName = array[0..15] of Byte;

{ Lists the characters that can be loaded: in import format 0, the *.who files of the character record's size in the
  save directory, leaving out characters already in the party and those with a byte above $7F at the format's flag
  offset. Both lists stay empty when the save directory cannot be reached or for another import format.
  @param(list Receives the stored names, padded, with "from saved game X" for a .sav file.)
  @param(files Receives the matching file names, in the same order.) }
procedure LoadCharlist(var list, files: Types.PCharacterListNode);

{ Makes sure the save directory can be reached in import format 0: while the game disk (volume CHAMP) sits in a floppy
  save drive it asks for the save disk; a missing directory is created, on a floppy after asking whether the save disk
  is in. An unexpected error on a hard disk is reported and fails.
  @returns(True when the directory is ready.) }
function CheckSaveDir: Boolean;

{ ORs one icon's pixels into another and ANDs its transparency mask into the other's.
  @param(src The icon to add.)
  @param(dst The icon that receives it.) }
procedure MergeIcon(src, dst: Types.PImgBuf);

{ Builds the current character's combat icon in its slot (on disk 1): loads the head (CHEAD) icon into scratch slot 11
  and the body (CBODY) icon into the slot, both for its icon size, ORs the head's two frames onto the body's and,
  outside CGA, recolors color 8 to 0 in each; then frees slot 11 and discards pending keys.
  @param(loading Also recolors the icon with the character's six saved icon colors.) }
procedure LoadCharIconAnim(loading: Boolean);

{ Deletes a character's .who, .stf and .sfx files from the save directory.
  @param(character The character, whose name gives the file names.) }
procedure DeleteCharacterFiles(character: Types.PCharRecord);

{ Saves a character in the save directory: its record as <name>.who (or <fileStem>.sav), its items as .stf and its
  effects as .sfx. With no room it offers to try another disk; choosing Ok ('Lose character?') goes on writing anyway;
  instead of overwriting a .who file it can take a new name, which also renames the character.
  @param(character The character.)
  @param(fileStem The file name for a saved game's copy, or empty to save under the character's name.) }
procedure SaveChar(character: Types.PCharRecord; fileStem: Types.TStr8);

{ Loads a character from the save directory: its record (import format 0), then its .stf items and .sfx effects when
  those files exist, and recalculates its stats and class values.
  @param(name The file name, with its extension.)
  @param(character Receives the character.)
  @param(fromSavedGame Unused.)
  @param(promptForSaveDisk Asks for the save disk rather than the data disk while the file is missing.) }
procedure LoadChar(name: String; character: Types.PCharRecord; fromSavedGame, promptForSaveDisk: Boolean);

{ Loads a monster from MON<disk>CHA.DAX, with its effects from MON<disk>SPC and its items from MON<disk>ITM; quits when
  the monster is missing.
  @param(id The monster number.)
  @param(character Receives the monster.) }
procedure LoadCreatureData(id: Byte; character: Types.PCharRecord);

{ Adds a monster to the party, unless it already has 8 members, with its combat icon from CPIC.
  @param(id The monster number, also kept as its creature ID.) }
procedure AddCreatureToParty(id: Byte);

{ Offers the saved games A..J in the save directory and loads the chosen SAVGAM<x>.DAT: the disk number, three memory
  zones, the party position, the interface states, the three wall-set slots and the members' file names. The picture,
  animation and speed settings come back from zone 0, each member is loaded from its .sav file, the members' working
  files are deleted, the icons are rebuilt, the data disk is taken from zone 1, and the 3D map and wall sets or the
  overland picture are reloaded. The interface state becomes the main menu, remembering the saved one as the previous
  state. }
procedure LoadGame;

{ Asks which game (A..J) to save and writes SAVGAM<x>.DAT with the disk number, three memory zones, the party position,
  the interface states, the three wall-set slots and the members' file names CHRDAT<x><n>; then saves each member under
  that name, deletes its working files and marks the game as saved. It refuses when the disk lacks room. }
procedure SaveGame;

{ Appends a character to the party, makes it current, gives it the first free order slot, and counts it in the party
  size; an NPC also has its class values recalculated. Note: with all eight order slots taken, the order slot is left at
  8.
  @param(character The character.) }
procedure AddCharToParty(character: Types.PCharRecord);

{ Calls the priming entries of MapTiles, ClassCal, FxEngine, CharHlp and the trace overlay, so the overlay manager loads
  them; the other overlays this unit uses are not primed here. }
procedure PrimeSaveLoad;

implementation

uses CharGen;

procedure PrimeSaveLoad;
begin
  MapTiles.PrimeMapTiles;
  Debug.PrimeDebug;
  ClassCal.PrimeClassCal;
  FxEngine.PrimeFxEngine;
  CharHlp.PrimeCharHlp;
end;

{ Converts a zero-terminated string.
  @param(rawName The characters.)
  @returns(The characters before the terminator.) }
function CStrToStr(var rawName: TRawCharacterName): String;
var
  nameLength: Byte;
  decodedName: String;
begin
  nameLength := 0;
  while rawName[nameLength] > 0 do
    Inc(nameLength);
  Move(rawName, decodedName[1], nameLength);
  decodedName[0] := Chr(nameLength);
  CStrToStr := decodedName;
end;

procedure LoadCharlist(var list, files: Types.PCharacterListNode);

  { Appends the files matching pattern whose size is wantSize to listA (stored names) and listB (file names). }
  procedure ScanSaveFiles(pattern: Types.TStr80; ofsName, ofsFlag, wantSize: Word; var listA,
                          listB: Types.PCharacterListNode);
  var
    displayNode: Types.PCharacterListNode;
    displayTail: Types.PCharacterListNode;
    fileNode: Types.PCharacterListNode;
    fileTail: Types.PCharacterListNode;
    characterCursor: Types.PCharRecord;
    searchResult: SearchRec;
    bytesRead: Word;
    characterFile: file;
    sourceSuffix: String[80];
    savedFlag: Byte;
    rawName: TRawCharacterName;
    { Unused in this version; see the other implementations of this routine. }
    matchCount: Byte;
  begin
    displayNode := nil;
    fileNode := nil;
    FindFirst(pattern, 0, searchResult);
    while DosError = 0 do begin
      Assign(characterFile, GDVars.saveDir + searchResult.Name);
      Reset(characterFile, 1);
      if FileSize(characterFile) = wantSize then begin
        GetMem(displayNode, SizeOf(Types.TCharacterListNode));
        GetMem(fileNode, SizeOf(Types.TCharacterListNode));
        FillChar(displayNode^, SizeOf(Types.TCharacterListNode), 0);
        FillChar(fileNode^, SizeOf(Types.TCharacterListNode), 0);
        Seek(characterFile, ofsName);
        if GDVars.importFormat = 2 then begin
          BlockRead(characterFile, rawName, SizeOf(rawName), bytesRead);
          displayNode^.name := SaveLoad.CStrToStr(rawName);
        end else
          BlockRead(characterFile, displayNode^.name, SizeOf(characterCursor^.name), bytesRead);
        Seek(characterFile, ofsFlag);
        if GDVars.importFormat = 2 then
          savedFlag := 0
        else
          BlockRead(characterFile, savedFlag, SizeOf(savedFlag));
        fileNode^.name := searchResult.Name;
        if Copy(searchResult.Name, 9, 4) = '.SAV' then
          sourceSuffix := 'from saved game ' + searchResult.Name[7]
        else
          sourceSuffix := '';
        displayNode^.name := displayNode^.name + Copy(GDConsts.blankName, 1, 15 - Length(displayNode^.name)) +
          sourceSuffix;
        characterCursor := GDVars.partyHead;
        while (characterCursor <> nil) and
            (Copy(displayNode^.name, 1, 15) <> characterCursor^.name + Copy(GDConsts.blankName, 1,
                                                                            15 - Length(characterCursor^.name))) do
          characterCursor := characterCursor^.next;
        if (savedFlag > 127) or (characterCursor <> nil) then begin
          FreeMem(displayNode, SizeOf(Types.TCharacterListNode));
          FreeMem(fileNode, SizeOf(Types.TCharacterListNode));
          displayNode := nil;
          fileNode := nil;
        end;
        if displayNode <> nil then
          if listA = nil then begin
            listA := displayNode;
            displayTail := listA;
            listB := fileNode;
            fileTail := listB;
          end else begin
            displayTail^.next := displayNode;
            displayTail := displayTail^.next;
            fileTail^.next := fileNode;
            fileTail := fileTail^.next;
          end;
      end;
      Close(characterFile);
      FindNext(searchResult);
    end;
  end;

begin
  list := nil;
  files := nil;
  if not SaveLoad.CheckSaveDir then Exit;
  case GDVars.importFormat of
    0: ScanSaveFiles(GDVars.saveDir + '*.who', GDConsts.nameOfsTbl[GDVars.importFormat],
                     GDConsts.flagOffsets[GDVars.importFormat], GDConsts.recordSizes[GDVars.importFormat], list, files);
  end;
end;

function CheckSaveDir: Boolean;
var
  errorCode: Integer;
  searchResult: SearchRec;
  choice: Char;
begin
  CheckSaveDir := False;
  case GDVars.importFormat of
   0: begin
    repeat
      while (DaxIo.GetVolumeLabel(GDVars.saveDir[1]) = 'CHAMP') and (GDVars.saveDir[1] < 'C') do
        TextRend.displayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':');
      repeat
        FindFirst(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1), $10, searchResult);
        errorCode := DosError;
        case errorCode of
          0: ;
          2, 18:
            begin
              if UpCase(GDVars.saveDir[1]) < 'C' then begin
                choice := MenuCore.YesNoMenu('Is your save disk in drive ' + GDVars.saveDir[1] + ':? ', LightMagenta,
                                             LightGreen, White);
                if choice <> 'Y' then
                  TextRend.displayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':');
              end;
              MkDir(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1));
              errorCode := DosError;
            end;
        else
          if UpCase(GDVars.saveDir[1]) < 'C' then
            TextRend.displayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':')
          else begin
            TextRend.displayAndPause(Yellow, Black,
                                     'Unexpected error during save: ' + CharHlp.Uint8Str(errorCode) + 'hali');
            Exit;
          end;
        end;
      until errorCode in [0, 5];
    until errorCode in [0, 5];
   end;
  end;
  CheckSaveDir := True;
end;

procedure MergeIcon(src, dst: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
  pixelIndex: Word;
begin
  for pixelIndex := 0 to src^.imgSize - 1 do begin
    dst^.data[pixelIndex] := dst^.data[pixelIndex] or src^.data[pixelIndex];
    dst^.transp^[pixelIndex] := dst^.transp^[pixelIndex] and src^.transp^[pixelIndex];
  end;
end;

procedure LoadCharIconAnim(loading: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  animSlot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  iconIds: Byte;
  fromMap: Types.TColorTab;
  toMap: Types.TColorTab;
  colorIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  partIdx: Byte;
begin
  DaxIo.PushState(1);
  with GDVars.curChar^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.heightMarks[iconSize], iconHead, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.heightMarks[iconSize], iconBody, orderNumber);
    SaveLoad.MergeIcon(GDVars.iconAnims[11, 0], GDVars.iconAnims[orderNumber, 0]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmapPink8, 0, False, GDVars.iconAnims[orderNumber, 0]);
    SaveLoad.MergeIcon(GDVars.iconAnims[11, 1], GDVars.iconAnims[orderNumber, 1]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmapPink8, 0, False, GDVars.iconAnims[orderNumber, 1]);
    if loading then begin
      for colorIndex := 0 to 15 do begin
        fromMap[colorIndex] := colorIndex;
        toMap[colorIndex] := colorIndex;
      end;
      for colorIndex := 1 to 6 do begin
        toMap[GDConsts.defIconColors[colorIndex]] := iconColors[colorIndex] and $F;
        toMap[GDConsts.defIconColors[colorIndex] + 8] := (iconColors[colorIndex] and $F0) shr 4;
      end;
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.iconAnims[orderNumber, 0]);
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.iconAnims[orderNumber, 1]);
    end;
  end;
  MapTiles.FreeIconAnim(11);
  DaxIo.PopState;
  GameIo.FlushKeys;
end;

procedure DeleteCharacterFiles(character: Types.PCharRecord);
var
  fileName: String[80];
  { Unused in this version; see the other implementations of this routine. }
  fileBuf: file;
begin
  fileName := GDVars.saveDir + DaxIo.SanitizeFileName(character^.name);
  DaxIo.DeleteIfPresent(fileName + '.who');
  DaxIo.DeleteIfPresent(fileName + '.stf');
  DaxIo.DeleteIfPresent(fileName + '.sfx');
end;

procedure SaveChar(character: Types.PCharRecord; fileStem: Types.TStr8);
var
  characterFile: file;
  fileName: Types.TStr40;
  fileExtension: String[4];
  choice: Char;
  { Unused in this version; see the other implementations of this routine. }
  bytesRead: Byte;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  nameBuf: array[1..24] of Byte;
  errorCode: Integer;
  requiredBytes: Word;
  extendedKey: Boolean;
begin
  GDVars.importFormat := 0;
  repeat
    if not SaveLoad.CheckSaveDir then Exit;
    requiredBytes := 0;
    Inc(requiredBytes, SizeOf(Types.TCharRecord));
    if character^.itemsAddr <> nil then begin
      item := character^.itemsAddr;
      while item <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TItemRec));
        item := item^.next;
      end;
    end;
    if character^.effects <> nil then begin
      effect := character^.effects;
      while effect <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TEffectRec));
        effect := effect^.next;
      end;
    end;
    choice := 'O';
    if requiredBytes > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - 64) then begin
      TextRend.displayAndPause(Yellow, Black, 'Can''t save.  No room on this disk.');
      choice := MenuCore.MenuHorizontal('Lose character? ', 'Ok  Try another disk', LightMagenta, LightGreen, White,
                                        False, False, extendedKey);
    end;
  until choice = 'O';
  if Length(fileStem) = 0 then begin
    fileExtension := '.who';
    fileName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(character^.name, '.'));
  end else begin
    fileExtension := '.sav';
    fileName := fileStem;
  end;
  repeat
    Assign(characterFile, GDVars.saveDir + fileName + fileExtension);
    Reset(characterFile, 1);
    errorCode := DosError;
    if not (errorCode in [0, 2]) then begin
      if UpCase(GDVars.saveDir[1]) < 'C' then
        TextRend.displayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':')
      else begin
        TextRend.displayAndPause(Yellow, Black, 'Unexpected error during save: ' + CharHlp.Uint8Str(errorCode));
        Close(characterFile);
        Exit;
      end;
    end;
  until (errorCode = 0) or (errorCode = 2);
  Close(characterFile);
  choice := 'N';
  while (choice = 'N') and (Length(fileStem) = 0) and
      DaxIo.FileExists(GDVars.saveDir + fileName + fileExtension) do begin
    choice := MenuCore.YesNoMenu('Overwrite ' + fileName + '? ', Yellow, LightGreen, White);
    if choice = 'N' then begin
      fileName := '';
      while Length(fileName) = 0 do
        fileName := TextRend.readString('New file name: ', LightGreen, Black, 8);
      character^.name := fileName;
    end;
  end;
  Assign(characterFile, GDVars.saveDir + fileName + fileExtension);
  Rewrite(characterFile, 1);
  BlockWrite(characterFile, character^, SizeOf(Types.TCharRecord));
  Close(characterFile);
  DaxIo.DeleteIfPresent(GDVars.saveDir + fileName + '.stf');
  if character^.itemsAddr <> nil then begin
    Assign(characterFile, GDVars.saveDir + fileName + '.stf');
    Rewrite(characterFile, 1);
    item := character^.itemsAddr;
    while item <> nil do begin
      BlockWrite(characterFile, item^, SizeOf(Types.TItemRec));
      item := item^.next;
    end;
    Close(characterFile);
  end;
  DaxIo.DeleteIfPresent(GDVars.saveDir + fileName + '.sfx');
  if character^.effects <> nil then begin
    Assign(characterFile, GDVars.saveDir + fileName + '.sfx');
    Rewrite(characterFile, 1);
    effect := character^.effects;
    while effect <> nil do begin
      BlockWrite(characterFile, effect^, SizeOf(Types.TEffectRec));
      effect := effect^.next;
    end;
    Close(characterFile);
  end;
end;

procedure LoadChar(name: String; character: Types.PCharRecord; fromSavedGame, promptForSaveDisk: Boolean);
var
  characterFile: file;
  bytesRead: Word;
  item: Types.PItemRec;
  itemBuffer: Types.PItemRec;
  effect: Types.PEffectRec;
  effectBuffer: Types.PEffectRec;
  diskPrompt: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  fileOpened: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  savedBuf: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  hillsfarRec: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  retry: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  curCharBak: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  baseName: String;
  { Unused in this version; see the other implementations of this routine. }
  name15: String[15];
  { Unused in this version; see the other implementations of this routine. }
  ext: String[4];
  { Unused in this version; see the other implementations of this routine. }
  nameLen: Byte;
begin
  if promptForSaveDisk then
    diskPrompt := 'Put save disk in '
  else
    diskPrompt := GDConsts.insertDiskMsg[GDVars.currentDisk];
  fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + name, diskPrompt, #0, characterFile);
  TextRend.displayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  FillChar(character^, SizeOf(Types.TCharRecord), 0);
  case GDVars.importFormat of
    0: begin
         BlockRead(characterFile, character^, SizeOf(Types.TCharRecord), bytesRead);
         Close(characterFile);
         character^.itemsAddr := nil;
         character^.effects := nil;
         character^.combatAddr := nil;
         character^.next := nil;
       end;
  end;
  Delete(name, Pos('.', name), 4);
  if DaxIo.FileExists(GDVars.saveDir + name + '.stf') then begin
    GetMem(itemBuffer, SizeOf(Types.TItemRec));
    fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + name + '.stf', diskPrompt, #0, characterFile);
    repeat
      BlockRead(characterFile, itemBuffer^, SizeOf(Types.TItemRec), bytesRead);
      if bytesRead = SizeOf(Types.TItemRec) then begin
        if character^.itemsAddr = nil then begin
          GetMem(character^.itemsAddr, SizeOf(Types.TItemRec));
          item := character^.itemsAddr;
        end else begin
          GetMem(item^.next, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
        item^ := itemBuffer^;
        item^.next := nil;
      end;
    until bytesRead <> SizeOf(Types.TItemRec);
    Close(characterFile);
    FreeMem(itemBuffer, SizeOf(Types.TItemRec));
  end;
  if DaxIo.FileExists(GDVars.saveDir + name + '.sfx') then begin
    GetMem(effectBuffer, SizeOf(Types.TEffectRec));
    fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + name + '.sfx', diskPrompt, #0, characterFile);
    repeat
      BlockRead(characterFile, effectBuffer^, SizeOf(Types.TEffectRec), bytesRead);
      if bytesRead = SizeOf(Types.TEffectRec) then begin
        if character^.effects = nil then begin
          GetMem(character^.effects, SizeOf(Types.TEffectRec));
          effect := character^.effects;
        end else begin
          GetMem(effect^.next, SizeOf(Types.TEffectRec));
          effect := effect^.next;
        end;
        effect^ := effectBuffer^;
        effect^.next := nil;
      end;
    until bytesRead <> SizeOf(Types.TEffectRec);
    Close(characterFile);
    FreeMem(effectBuffer, SizeOf(Types.TEffectRec));
  end;
  GameIo.FlushKeys;
  CharHlp.RecalcStats(character);
  ClassCal.RecalcClassStats(character);
end;

procedure LoadCreatureData(id: Byte; character: Types.PCharRecord);
var
  dataSize: Word;
  dataBuffer: Types.PBytes;
  dataOffset: Word;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  itemIdx: Word;
begin
  Str(GDVars.currentDisk, numStr);
  DaxIo.LoadDax('MON' + numStr + 'CHA', '.dax', id, dataSize, dataBuffer);
  if dataSize = 0 then begin
    TextRend.displayAndPause(White, Black, 'Unable to load monster');
    GameIo.ExitGame;
  end;
  Move(dataBuffer^, character^, SizeOf(Types.TCharRecord));
  with character^ do begin
    itemsAddr := nil;
    effects := nil;
    next := nil;
    combatAddr := nil;
  end;
  FreeMem(dataBuffer, dataSize);
  GDVars.suppressPrompt := #1;
  DaxIo.LoadDax('MON' + numStr + 'SPC', '.dax', id, dataSize, dataBuffer);
  if dataSize <> 0 then begin
    dataOffset := 0;
    GetMem(character^.effects, SizeOf(Types.TEffectRec));
    effect := character^.effects;
    repeat
      Move(dataBuffer^[dataOffset], effect^, SizeOf(Types.TEffectRec));
      effect^.next := nil;
      Inc(dataOffset, SizeOf(Types.TEffectRec));
      if dataOffset < dataSize then begin
        GetMem(effect^.next, SizeOf(Types.TEffectRec));
        effect := effect^.next;
      end;
    until dataOffset >= dataSize;
    FreeMem(dataBuffer, dataSize);
  end;
  DaxIo.LoadDax('MON' + numStr + 'ITM', '.dax', id, dataSize, dataBuffer);
  if dataSize <> 0 then begin
    dataOffset := 0;
    GetMem(character^.itemsAddr, SizeOf(Types.TItemRec));
    item := character^.itemsAddr;
    repeat
      Move(dataBuffer^[dataOffset], item^, SizeOf(Types.TItemRec));
      item^.next := nil;
      Inc(dataOffset, SizeOf(Types.TItemRec));
      if dataOffset < dataSize then begin
        GetMem(item^.next, SizeOf(Types.TItemRec));
        item := item^.next;
      end;
    until dataOffset >= dataSize;
    FreeMem(dataBuffer, dataSize);
  end;
  GDVars.suppressPrompt := #0;
  GameIo.FlushKeys;
end;

procedure AddCreatureToParty(id: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  character: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  slot: Byte;
begin
  if GDVars.zone1^.vars[C_Gbvm.PARTY_SIZE] > 7 then Exit;
  GetMem(character, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(id, character);
  character^.creatureId := id;
  SaveLoad.AddCharToParty(character);
  MapTiles.LoadIconAnim('CPIC', id, character^.orderNumber);
end;

procedure AddCharToParty(character: Types.PCharRecord);
var
  characterCursor: Types.PCharRecord;
  usedOrderNumbers: array[0..7] of Byte;
begin
  character^.orderNumber := 255;
  if GDVars.partyHead = nil then
    GDVars.partyHead := character
  else begin
    characterCursor := GDVars.partyHead;
    while characterCursor^.next <> nil do
      characterCursor := characterCursor^.next;
    characterCursor^.next := character;
  end;
  GDVars.curChar := character;
  FillChar(usedOrderNumbers, SizeOf(usedOrderNumbers), 0);
  characterCursor := GDVars.partyHead;
  while characterCursor <> nil do begin
    if characterCursor^.orderNumber in [0..7] then
      usedOrderNumbers[characterCursor^.orderNumber] := 1;
    characterCursor := characterCursor^.next;
  end;
  with GDVars.curChar^ do begin
    orderNumber := 0;
    while (orderNumber < 8) and (usedOrderNumbers[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.zone1^.vars[C_Gbvm.PARTY_SIZE]);
  if character^.npc > 127 then
    ClassCal.RecalcClassStats(character);
end;

procedure LoadGame;
var
  characterNames: array[1..8] of Types.TStr40;
  saveFile: file;
  slotIndex: Byte;
  character: Types.PCharRecord;
  fileName: Types.TStr40;
  bytesRead: Word;
  characterCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  fileOpened: Boolean;
  saveSlot: Char;
  extendedKey: Boolean;
  availableSlots: String[20];
begin
  GDVars.importFormat := 0;
  if not SaveLoad.CheckSaveDir then Exit;
  availableSlots := '';
  for saveSlot := 'A' to 'J' do
    if DaxIo.FileExists(GDVars.saveDir + 'savgam' + saveSlot + '.dat') then
      availableSlots := availableSlots + saveSlot + ' ';
  if Length(availableSlots) = 0 then Exit;
  Delete(availableSlots, Length(availableSlots), 1);
  repeat
    saveSlot := MenuCore.MenuHorizontal('Load Which Game: ', availableSlots, LightMagenta, LightGreen, White, False,
                                        False, extendedKey);
  until ((saveSlot in ['A'..'J']) and DaxIo.FileExists(GDVars.saveDir + 'savgam' + saveSlot + '.dat')) or
      (saveSlot = C_Keys.NONE);
  if saveSlot = C_Keys.NONE then Exit;
  fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + 'savgam' + saveSlot + '.dat', 'Put save disk in ' + GDVars.saveDir,
                                    #1, saveFile);
  MenuCore.ClearBottomLine;
  TextRend.displayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  GDVars.loadedSave := 1;
  BlockRead(saveFile, GDVars.currentDisk, SizeOf(GDVars.currentDisk), bytesRead);
  BlockRead(saveFile, GDVars.zone0^, SizeOf(GDVars.zone0^), bytesRead);
  BlockRead(saveFile, GDVars.zone1^, SizeOf(GDVars.zone1^), bytesRead);
  BlockRead(saveFile, GDVars.zone2^, SizeOf(GDVars.zone2^), bytesRead);
  BlockRead(saveFile, GDVars.mapState, SizeOf(GDVars.mapState), bytesRead);
  BlockRead(saveFile, GDVars.previousLocationType, SizeOf(GDVars.previousLocationType), bytesRead);
  BlockRead(saveFile, GDVars.interfaceState, SizeOf(GDVars.interfaceState), bytesRead);
  for slotIndex := 1 to 3 do begin
    BlockRead(saveFile, GDVars.wallSlots[slotIndex].id, SizeOf(GDVars.wallSlots[slotIndex].id), bytesRead);
    BlockRead(saveFile, GDVars.wallSlots[slotIndex].slot, SizeOf(GDVars.wallSlots[slotIndex].slot), bytesRead);
  end;
  BlockRead(saveFile, characterCount, SizeOf(characterCount), bytesRead);
  BlockRead(saveFile, characterNames, SizeOf(characterNames), bytesRead);
  Close(saveFile);
  GDVars.picturesEnabled := GDVars.zone0^.vars[$4BFF] div 2;
  GDVars.animationsEnabled := GDVars.zone0^.vars[$4BFF] and $01;
  GDVars.gameDelay := Lo(GDVars.zone0^.vars[$4BFC]);
  GDVars.zone1^.vars[C_Gbvm.PARTY_SIZE] := 0;
  for slotIndex := 1 to characterCount do begin
    fileName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(characterNames[slotIndex], '.'));
    if DaxIo.FileExists(GDVars.saveDir + fileName + '.sav') then begin
      GetMem(character, SizeOf(Types.TCharRecord));
      SaveLoad.LoadChar(fileName + '.sav', character, True, True);
      SaveLoad.AddCharToParty(character);
      if not SaveLoad.CheckSaveDir then Exit;
    end;
  end;
  character := GDVars.partyHead;
  while character <> nil do begin
    SaveLoad.DeleteCharacterFiles(character);
    character := character^.next;
  end;
  GDVars.curChar := GDVars.partyHead;
  while GDVars.curChar <> nil do begin
    if GDVars.curChar^.npc < C_Npc.NON_PLAYER then
      SaveLoad.LoadCharIconAnim(True)
    else
      MapTiles.LoadIconAnim('CPIC', GDVars.curChar^.creatureId, GDVars.curChar^.orderNumber);
    GDVars.curChar := GDVars.curChar^.next;
  end;
  GDVars.curChar := GDVars.partyHead;
  GDVars.currentDisk := Lo(GDVars.zone1^.vars[$7F12]);
  if GDVars.zone0^.vars[C_Gbvm.VIEW_3D] <> 0 then begin
    if GDVars.wallSlots[1].id > 0 then
      View3D.Load3DMap(Lo(GDVars.zone0^.vars[C_Gbvm.GEO_MAP_ID]));
    for slotIndex := 1 to 3 do
      if GDVars.wallSlots[slotIndex].id > 0 then
        View3D.LoadWallSet(GDVars.wallSlots[slotIndex].id, GDVars.wallSlots[slotIndex].slot);
  end else
    Portrait.LoadBigPic(121);
  GameIo.FlushKeys;
  MenuCore.ClearBottomLine;
  GDVars.previousLocationType := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
end;

procedure SaveGame;
var
  characterNames: array[1..8] of Types.TStr40;
  saveFile: file;
  entryIndex: Byte;
  characterCursor: Types.PCharRecord;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  fileName: Types.TStr40;
  extendedKey: Boolean;
  saveSlot: Char;
  errorCode: Integer;
  requiredBytes: Word;

  { Empty routine with no callers. }
  procedure Noop;
  begin
  end;

  { Returns the bytes the members' files need: a record each plus its items and effects. }
  function ComputePartySaveSize: Word;
  var
    partyCharacter: Types.PCharRecord;
    item: Types.PItemRec;
    effect: Types.PEffectRec;
    totalBytes: Word;
  begin
    totalBytes := 0;
    partyCharacter := GDVars.partyHead;
    while partyCharacter <> nil do begin
      Inc(totalBytes, SizeOf(Types.TCharRecord));
      if partyCharacter^.itemsAddr <> nil then begin
        item := partyCharacter^.itemsAddr;
        while item <> nil do begin
          Inc(totalBytes, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
      end;
      if partyCharacter^.effects <> nil then begin
        effect := partyCharacter^.effects;
        while effect <> nil do begin
          Inc(totalBytes, SizeOf(Types.TEffectRec));
          effect := effect^.next;
        end;
      end;
      partyCharacter := partyCharacter^.next;
    end;
    ComputePartySaveSize := totalBytes;
  end;

begin
  repeat
    saveSlot := MenuCore.MenuHorizontal('Save Which Game: ', 'A B C D E F G H I J', LightMagenta, LightGreen, White,
                                        False, GDVars.interfaceState = C_Ifc.CAMPING, extendedKey);
  until saveSlot in [C_Keys.NONE, 'A'..'J'];
  if saveSlot = C_Keys.NONE then Exit;
  GDVars.importFormat := 0;
  if not SaveLoad.CheckSaveDir then Exit;
  if DaxIo.FileExists(GDVars.saveDir + 'savgam' + saveSlot + '.dat') then
    requiredBytes := 0
  else
    requiredBytes := 5128;
  Inc(requiredBytes, ComputePartySaveSize);
  if requiredBytes > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - 64) then begin
    TextRend.displayAndPause(Yellow, Black, 'Can''t save.  No room on this disk.');
    Exit;
  end;
  repeat
    Assign(saveFile, GDVars.saveDir + 'savgam' + saveSlot + '.dat');
    Rewrite(saveFile, 1);
    errorCode := DosError;
    if not (errorCode in [0, 2, 18]) then begin
      if UpCase(GDVars.saveDir[1]) < 'C' then
        TextRend.displayAndPause(Yellow, Black, 'Put save disk in ' + GDVars.saveDir[1] + ':')
      else begin
        TextRend.displayAndPause(Yellow, Black, 'Unexpected error during save: ' + CharHlp.Uint8Str(errorCode));
        Close(saveFile);
        Exit;
      end;
    end;
  until errorCode in [0, 2, 18];
  MenuCore.ClearBottomLine;
  TextRend.displayString(0, 24, LightGreen, Black, 'Saving...Please Wait');
  GDVars.zone0^.vars[$4BFC] := GDVars.gameDelay;
  GDVars.zone0^.vars[$4BFF] := GDVars.picturesEnabled * 2 + GDVars.animationsEnabled;
  GDVars.zone1^.vars[$7F12] := GDVars.currentDisk;
  BlockWrite(saveFile, GDVars.currentDisk, SizeOf(GDVars.currentDisk));
  BlockWrite(saveFile, GDVars.zone0^, SizeOf(GDVars.zone0^));
  BlockWrite(saveFile, GDVars.zone1^, SizeOf(GDVars.zone1^));
  BlockWrite(saveFile, GDVars.zone2^, SizeOf(GDVars.zone2^));
  BlockWrite(saveFile, GDVars.mapState, SizeOf(GDVars.mapState));
  BlockWrite(saveFile, GDVars.previousLocationType, SizeOf(GDVars.previousLocationType));
  BlockWrite(saveFile, GDVars.interfaceState, SizeOf(GDVars.interfaceState));
  for entryIndex := 1 to 3 do begin
    BlockWrite(saveFile, GDVars.wallSlots[entryIndex].id, SizeOf(GDVars.wallSlots[entryIndex].id));
    BlockWrite(saveFile, GDVars.wallSlots[entryIndex].slot, SizeOf(GDVars.wallSlots[entryIndex].slot));
  end;
  entryIndex := 0;
  characterCursor := GDVars.partyHead;
  if characterCursor = nil then
    TextRend.displayAndPause(Yellow, Black, 'WARNING: Problem Saving Characters');
  while characterCursor <> nil do begin
    Inc(entryIndex);
    Str(entryIndex, numStr);
    characterNames[entryIndex] := 'CHRDAT' + saveSlot + numStr;
    characterCursor := characterCursor^.next;
  end;
  BlockWrite(saveFile, entryIndex, SizeOf(entryIndex));
  BlockWrite(saveFile, characterNames, SizeOf(characterNames));
  Close(saveFile);
  characterCursor := GDVars.partyHead;
  entryIndex := 0;
  while characterCursor <> nil do begin
    Inc(entryIndex);
    Str(entryIndex, numStr);
    SaveLoad.SaveChar(characterCursor, 'CHRDAT' + saveSlot + numStr);
    SaveLoad.DeleteCharacterFiles(characterCursor);
    characterCursor := characterCursor^.next;
  end;
  GDVars.recentlySaved := 1;
  MenuCore.ClearBottomLine;
end;

begin
end.
