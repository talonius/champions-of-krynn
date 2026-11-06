{ DAX archive I/O, overlay-disk prompting and BIOS text output. The decoder streams each run directly from the archive;
  LoadDax brackets every exit path with the disk-load sound commands. }
{$O+,F+}
{$I-}
unit DaxIo;

interface

uses Types, Dos, Crt, GDConsts, GDVars, GameIo, SoundDrv, C_Screen;

type
  TString20 = string[20];

{ Writes a run of one character in text mode through the video BIOS on page 0, placing the cursor first. On CGA the
  attribute is translated through the CGA attribute table.
  @param(col Text column.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(count How many copies to write.)
  @param(ch The character.) }
procedure WriteChar(col, row, attr, count, ch: Byte);

{ Writes a string in text mode through the video BIOS, one character per column.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(source The text.) }
procedure WriteString(col, row, attr: Byte; source: string);

{ Writes a run of solid block characters through the BIOS.
  @param(col Column of the first block.)
  @param(row Row of the run.)
  @param(attr Text attribute.)
  @param(count Number of blocks.) }
procedure WriteBlock(col, row, attr, count: Byte);

{ Shows a message on the bottom text row over a cleared bar, waits for a key, then clears the bar.
  @param(attr Attribute of the message.)
  @param(message The message.) }
procedure PromptBox(attr: Byte; message: Types.TStr40);

{ Erases a file if it exists.
  @param(name The file's name.) }
procedure DeleteIfPresent(name: Types.TStr80);

{ Waits until GAME.OVR can be found, asking for the overlay disk and a key each time it is missing. }
procedure OverlayPrompt;

{ Reads a drive's volume label. The FindFirst status is not checked: the name buffer is cleared first, so a failed
  search leaves it empty.
  @param(drive The drive letter.)
  @returns(The label, or an empty string when it has none.) }
function GetVolumeLabel(drive: Types.TStr2): Types.TStr40;

{ Opens a file for reading in records of one byte. A path without a directory looks in the data path; when the file is
  not there the data path and master path are swapped and it looks again. While the file is missing and prompts are
  allowed, it asks for the disk (a floppy drive) or reports the missing file (a hard disk) and tries again.
  @param(fileName The file's name, with or without a directory.)
  @param(promptMsg The disk prompt shown for a floppy drive, followed by the drive letter.)
  @param(noPrompt #0 to keep asking until the file is found; anything else fails at once.)
  @param(f Receives the open file.)
  @returns(True when the file was found and opened.) }
function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Char; var f: file): Boolean;

{ Tells whether a normal file matching a name exists.
  @param(name The file name or pattern; an empty name never exists.)
  @returns(True when one exists.) }
function FileExists(name: Types.TStr80): Boolean;

{ Removes the occurrences of one string from another. Note: the scan limit is computed once from the starting lengths
  and the scan moves on after each deletion, so a match shifted into the current position survives, and a substring
  longer than the string wraps the limit round to a large byte value.
  @param(source The string.)
  @param(removeText The text to remove.)
  @returns(The string without the text.) }
function SanitizeString(source, removeText: string): string;

{ Makes a file name from a string: removes the characters a DOS file name cannot hold, in SanitizeString's single pass,
  keeps the first eight characters and uppercases them.
  @param(name The string.)
  @returns(The file name.) }
function SanitizeFileName(name: string): Types.TStr80;

{ Decodes a run-length packed entry. A control byte 0..$7E copies the next control+1 bytes; -127..-1 repeats the next
  byte -control times. Note: controls $7F and $80 do nothing, so a stream holding one makes no progress, and `outLen` is
  checked only between runs, so bad data can overrun the buffer by one run.
  @param(dst The buffer that receives the decoded bytes.)
  @param(outLen The number of bytes to decode.)
  @param(f The archive, positioned at the entry.) }
procedure DecompressDax(var dst: Types.PBytes; var outLen: Word; var f: file);

{ Opens an archive twice, one handle for its entry directory from the start and one positioned at the first data byte.
  Note: if the second open fails, the first handle is left open.
  @param(dirName The archive's base name.)
  @param(ext Its extension.)
  @param(headerSize Receives the offset of the first data byte.)
  @param(dataFile Receives the handle positioned at the data.)
  @param(indexFile Receives the handle that reads the directory.)
  @returns(True when both opens succeeded.) }
function OpenDax(dirName, ext: TString20; var headerSize: Word; var dataFile, indexFile: file): Boolean;

{ Closes both handles of a DAX archive.
  @param(dataFile The data handle.)
  @param(indexFile The directory handle.) }
procedure CloseDax(var dataFile, indexFile: file);

{ Loads and decodes one block of a DAX archive into a new buffer. The directory is searched for the block's ID; each
  entry gives the block's offset and its decoded and compressed sizes. Sound output is silenced during the load. A
  missing archive or block gives a size of 0 and nil.
  @param(fileName The archive's name.)
  @param(ext The archive's extension.)
  @param(fileId The block's ID.)
  @param(sizeRead Receives the decoded size, 0 on failure.)
  @param(data Receives the buffer, nil on failure.) }
procedure LoadDax(fileName, ext: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PBytes);

{ Remembers the current disk and switches to the disk that holds a given part of the game, two parts to a disk.
  @param(v The part, 1 up.) }
procedure PushState(v: Byte);

{ Returns to the disk PushState remembered. }
procedure PopState;

implementation

const
  SOLID_BLOCK_CHAR = 219;
  { BIOS video function: place the cursor at DH, DL on page BH }
  BIOS_SET_CURSOR = 2;
  { BIOS video function: write AL, attribute BL, CX times at the cursor on page BH }
  BIOS_WRITE_CHAR_ATTR = 9;
  { the text page the BIOS writes to }
  TEXT_PAGE = 0;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GDVars.vregs.ah := DaxIo.BIOS_SET_CURSOR;
  GDVars.vregs.bh := DaxIo.TEXT_PAGE;
  GDVars.vregs.dh := row;
  GDVars.vregs.dl := col;
  Intr($10, Registers(GDVars.vregs));
  GDVars.vregs.ah := DaxIo.BIOS_WRITE_CHAR_ATTR;
  GDVars.vregs.al := ch;
  GDVars.vregs.bh := DaxIo.TEXT_PAGE;
  if GDVars.displayMode = Types.Cga then
    GDVars.vregs.bl := GDConsts.attrTable[attr]
  else
    GDVars.vregs.bl := attr;
  GDVars.vregs.cx := count;
  Intr($10, Registers(GDVars.vregs));
end;

procedure WriteString(col, row, attr: Byte; source: string);
var
  charCount: Byte;
  charIndex: Byte;
begin
  charCount := Length(source);
  for charIndex := 1 to charCount do begin
    DaxIo.WriteChar(col, row, attr, 1, Ord(source[charIndex]));
    Inc(col);
  end;
end;

procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, DaxIo.SOLID_BLOCK_CHAR);
end;

procedure PromptBox(attr: Byte; message: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  DaxIo.WriteBlock(0, C_Screen.PROMPT_ROW, Black, 40);
  DaxIo.WriteString(0, C_Screen.PROMPT_ROW, attr, message);
  key := GameIo.ReadGameKey;
  DaxIo.WriteBlock(0, C_Screen.PROMPT_ROW, Black, 40);
end;

procedure DeleteIfPresent(name: Types.TStr80);
begin
  if DaxIo.FileExists(name) then begin
    Assign(GDVars.delFile, name);
    Close(GDVars.delFile);
    Erase(GDVars.delFile);
  end;
end;

procedure OverlayPrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  found: Boolean;
begin
  repeat
    found := DaxIo.FileExists('game.ovr');
    if not found then begin
      WriteLn('Please insert overlay disk.');
      key := GameIo.ReadGameKey;
    end;
  until found;
end;

function GetVolumeLabel(drive: Types.TStr2): Types.TStr40;
var sr: SearchRec;
begin
  FillChar(sr.Name, SizeOf(sr.Name), 0);
  FindFirst(drive + ':\*.*', VolumeID, sr);
  GetVolumeLabel := sr.Name;
end;

function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Char; var f: file): Boolean;
var
  found: Boolean;
  swapTmp: String[79];
  dir: DirStr; name: NameStr; ext: ExtStr;
begin
  FSplit(fileName, dir, name, ext);
  if dir = '' then
    dir := GDVars.dataPath;
  repeat
    found := DaxIo.FileExists(dir + name + ext);
    if not found then
      if dir = GDVars.dataPath then begin
        swapTmp := GDVars.dataPath;
        GDVars.dataPath := GDVars.masterPath;
        GDVars.masterPath := swapTmp;
        dir := GDVars.dataPath;
        found := DaxIo.FileExists(dir + name + ext);
      end;
    if (not found) and (noPrompt = #0) then
      if dir[1] < 'C' then
        DaxIo.PromptBox(Yellow, promptMsg + GDVars.driveChar + ':')
      else
        DaxIo.PromptBox(Yellow, 'Couldn''t find ' + name + ext + '. Check install.');
  until found or (noPrompt <> #0);
  if found then begin
    Assign(f, dir + name + ext);
    Reset(f, 1);
  end;
  OpenWithRetry := found;
end;

function FileExists(name: Types.TStr80): Boolean;
var sr: SearchRec;
begin
  FindFirst(name, 0, sr);
  FileExists := (DosError = 0) and (name <> '');
end;

function SanitizeString(source, removeText: string): string;
var
  scanLimit: Byte;
  removeLen: Byte;
  charIndex: Byte;
begin
  removeLen := Length(removeText);
  scanLimit := Length(source) - removeLen + 1;
  for charIndex := 1 to scanLimit do
    if Copy(source, charIndex, removeLen) = removeText then
      Delete(source, charIndex, removeLen);
  SanitizeString := source;
end;

function SanitizeFileName(name: string): Types.TStr80;
var charIndex: Byte;
begin
  for charIndex := 1 to 10 do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileCharSet[charIndex]);
  name := Copy(name, 1, 8);
  for charIndex := 1 to Length(name) do
    name[charIndex] := UpCase(name[charIndex]);
  SanitizeFileName := name;
end;

procedure DecompressDax(var dst: Types.PBytes; var outLen: Word; var f: file);
var
  { Unused in this version; see the other implementations of this routine. }
  inputIndex: Word;
  outputIndex: Word; runControl: ShortInt; fillByte: Byte;
    { Unused in this version; see the other implementations of this routine. }
    inputBuffer: array[1..512] of Byte;
begin
  inputIndex := 0;
  outputIndex := 0;
  repeat
    BlockRead(f, runControl, SizeOf(runControl));
    case runControl of
      0..126: begin
        BlockRead(f, dst^[outputIndex], runControl + 1);
        Inc(outputIndex, runControl + 1);
      end;
      -127..-1: begin
        runControl := -runControl;
        BlockRead(f, fillByte, SizeOf(fillByte));
        FillChar(dst^[outputIndex], runControl, fillByte);
        Inc(outputIndex, runControl);
      end;
    end;
  until outputIndex >= outLen;
end;

function OpenDax(dirName, ext: TString20; var headerSize: Word; var dataFile, indexFile: file): Boolean;
var
  bytesRead: Word;
  { Unused in this version; see the other implementations of this routine. }
  ioStatus: Word;
begin
  if DaxIo.OpenWithRetry(dirName + ext, GDConsts.insertDiskMsg[GDVars.currentDisk], GDVars.suppressPrompt,
                         dataFile) then begin
    if not DaxIo.OpenWithRetry(dirName + ext, GDConsts.insertDiskMsg[GDVars.currentDisk], GDVars.suppressPrompt,
                               indexFile) then begin
      OpenDax := False;
      Exit;
    end;
    BlockRead(indexFile, headerSize, SizeOf(headerSize), bytesRead);
    Inc(headerSize, 2);
    Seek(dataFile, headerSize);
    OpenDax := True;
  end else
    OpenDax := False;
end;

procedure CloseDax(var dataFile, indexFile: file);
begin
  Close(dataFile);
  Close(indexFile);
end;

procedure LoadDax(fileName, ext: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PBytes);
var compSize: Word; offset: LongInt; entryId: Byte; bytesRead: Word;
    dataFile: file;
    indexFile: file; headerSize: Word;
    { Unused in this version; see the other implementations of this routine. }
    soundState: Byte;
    { Unused in this version; see the other implementations of this routine. }
    numStr: String[6];
begin
  SoundDrv.SoundCommand(GDConsts.sndSilence);
  if not DaxIo.OpenDax(fileName, ext, headerSize, dataFile, indexFile) then begin
    sizeRead := 0;
    data := nil;
    SoundDrv.SoundCommand(GDConsts.sndOutputOn);
    Exit;
  end;
  repeat
    BlockRead(indexFile, entryId, SizeOf(entryId), bytesRead);
    BlockRead(indexFile, offset, SizeOf(offset), bytesRead);
    BlockRead(indexFile, sizeRead, SizeOf(sizeRead), bytesRead);
    BlockRead(indexFile, compSize, SizeOf(compSize), bytesRead);
  until (entryId = fileId) or (FilePos(indexFile) >= headerSize);
  if entryId <> fileId then begin
    sizeRead := 0;
    data := nil;
    DaxIo.CloseDax(dataFile, indexFile);
    SoundDrv.SoundCommand(GDConsts.sndOutputOn);
  end else begin
    GetMem(data, sizeRead);
    Seek(dataFile, headerSize + offset);
    DaxIo.DecompressDax(data, sizeRead, dataFile);
    DaxIo.CloseDax(dataFile, indexFile);
    SoundDrv.SoundCommand(GDConsts.sndOutputOn);
  end;
end;

procedure PushState(v: Byte);
begin
  GDVars.prevDisk := GDVars.currentDisk;
  GDVars.currentDisk := (v + 1) div 2;
end;

procedure PopState;
begin
  GDVars.currentDisk := GDVars.prevDisk;
end;

begin
end.
