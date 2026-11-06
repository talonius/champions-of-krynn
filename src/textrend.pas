{ Text on the graphics screen in the 8x8 game font: loading the font, drawing characters and strings in foreground and
  background colors through the CGA, EGA or Tandy blitter, the word-wrapped message window, bottom-line prompts, input
  and pauses, screen and rectangle clearing, EGA page setup and fills, and the centisecond clock. }

{ The message window keeps its cursor in GDVars.curCol and curRow between calls, so callers can position the next
  message or let it continue where the last one stopped; a cursor outside the window starts over at the window's
  upper-left corner. ReadString edits on the bottom line with a column of its own. }
{$O+,F+}
unit TextRend;

interface

uses Types, DaxIo, GDConsts, GDVars, Crt, Dos, GameIo, Mouse, C_Keys, C_Ega, C_Video, C_Screen;

{ Resets the EGA graphics controller (registers 0 to 5 to 0, color don't-care $0F, bit mask $FF) and enables writes to
  the four planes. }
procedure ResetEgaGc;

{ Shows an EGA page (video BIOS function 5) and records its segment as the current page.
  @param(page The page to show.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Records an EGA page's segment as the other page.
  @param(page The page.) }
procedure SetupEgaOtherPage(page: Byte);

{ Fills a character-cell rectangle of an EGA page with one color in write mode 2, then restores write mode 0 and points
  the other page back at the page number saved for it.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(page The EGA page to fill.)
  @param(color The fill color.) }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

{ Loads the 8x8 game font (block 201 of 8X8D1.DAX) into the font buffer; nothing happens when it is missing. }
procedure LoadGameFont;

{ Draws a run of one character rightward from a cell, with the display mode's glyph routine. Nothing is drawn when the
  first cell is off the 40x25 screen or there is no font; the run itself is not clipped.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(fg The character's color.)
  @param(bg The background color.)
  @param(count How many times to draw it.)
  @param(ch The character, or a font index when the translate flag is 0.)
  @param(translateAscii Nonzero to upper-case the character and take it mod 64 as the font index.) }
procedure RenderChar(col, row, fg, bg, count, ch, translateAscii: Byte);

{ Blanks a run of cells with the mouse cursor hidden. Note: a first cell off the screen exits early and leaves the mouse
  hidden.
  @param(col The first cell's column.)
  @param(row The cell row.)
  @param(color The color to blank to.)
  @param(count The number of cells.) }
procedure PrintSpaces(col, row, color, count: Byte);

{ Writes a string from a cell, one character per cell, with the mouse cursor hidden; characters off the screen are not
  drawn. Note: a column above 39 or a row above 39 exits early and leaves the mouse hidden.
  @param(col The first character's column.)
  @param(row The row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(source The text.) }
procedure DisplayString(col, row, fg, bg: Byte; source: string);

{ Writes a string word-wrapped into a window, from the text cursor when it is inside the window, else, or after clearing
  when asked, from the top left. Punctuation stays with the word next to it. Characters appear one by one with a delay
  while slow text is on. When the window fills with text left over, it waits for a key and goes on in the cleared
  window. The text cursor is left after the text. Note: the check meant to keep a word whose trailing space alone
  overruns the right edge can never hold, so such a word wraps as well; and a window edge off the screen exits early
  with the mouse left hidden.
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(clearFirst True to clear the window and start at its top left.)
  @param(source The text.) }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: string);

{ Shows a prompt on the bottom row and reads text from the keyboard, echoed in white: a space through z is added while
  there is room and backspace deletes, until Enter or Escape, or after the first key while the demo runs. The row is
  cleared afterwards.
  @param(query The prompt.)
  @param(color The prompt's color.)
  @param(bg The prompt's background color.)
  @param(maxLen The most characters accepted.)
  @returns(The text typed, upper-cased; Escape returns it too.) }
function ReadString(query: Types.TStr40; color, bg, maxLen: Byte): Types.TStr40;

{ Reads numbers of up to six characters (ReadString) until one parses within 0 to 65536. Note: 65536 is accepted and
  becomes 0.
  @param(query The prompt.)
  @param(color The prompt's color.)
  @param(bg The prompt's background color.)
  @returns(The number.) }
function ReadNumber(query: Types.TStr40; color, bg: Byte): Word;

{ Shows a message on the bottom row and waits for a key; the message stays.
  @param(color The text color.)
  @param(bg The background color.)
  @param(msg The message.) }
procedure DisplayAndPause(color, bg: Byte; msg: Types.TStr40);

{ Reads the time of day.
  @returns(The time since midnight in hundredths of a second.) }
function GetTicks: LongInt;

{ Clears the whole screen to black: both EGA pages, or each CGA or Tandy bank. }
procedure ClearScreen;

{ Shows a message on the bottom row for the game-speed pause (PauseOnly), then clears the row.
  @param(msg The message.)
  @param(color The text color.)
  @param(bg The background color.) }
procedure PrintAndPause(msg: Types.TStr40; color, bg: Byte);

{ Waits for the game-speed setting times 100 milliseconds. }
procedure PauseOnly;

{ Clears a character-cell rectangle to black, on both EGA pages, with the mouse cursor hidden.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);

implementation

const
  { BIOS video function: select the active display page in AL }
  BIOS_SET_PAGE = 5;
  { CGA even rows / Tandy bank 0 }
  GFX_BANK0_SEG = $B800;
  { CGA odd rows / Tandy bank 1 }
  GFX_BANK1_SEG = $BA00;
  { Tandy bank 2 }
  GFX_BANK2_SEG = $BC00;
  { Tandy bank 3 }
  GFX_BANK3_SEG = $BE00;

type
  TCgaRows = array[0..99] of array[0..39] of Word;
  TTandyBank = array[0..49] of array[0..159] of Byte;

var
  { Visible scanline views: CGA interleaves 100 rows per bank; Tandy uses 50. Each view covers the 8000 bytes cleared by
    ClearScreen. }
  cgaEvenRows: TCgaRows absolute TextRend.GFX_BANK0_SEG:$0000;
  cgaOddRows: TCgaRows absolute TextRend.GFX_BANK1_SEG:$0000;
  tandyBank0: TTandyBank absolute TextRend.GFX_BANK0_SEG:$0000;
  tandyBank1: TTandyBank absolute TextRend.GFX_BANK1_SEG:$0000;
  tandyBank2: TTandyBank absolute TextRend.GFX_BANK2_SEG:$0000;
  tandyBank3: TTandyBank absolute TextRend.GFX_BANK3_SEG:$0000;

{$F-}
{$L TextRend.OBJ}
{ Draws one character cell on CGA from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(glyphIdx Unused.) }
procedure RenderCharCga(col, row: Word; fg, bg, glyphIdx: Byte); external;

{ Draws one character cell on EGA from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(glyphIdx Unused.) }
procedure RenderCharEga(col, row: Word; fg, bg, glyphIdx: Byte); external;

{ Draws one character cell on Tandy from the glyph rows that RenderChar staged.
  @param(col The cell column.)
  @param(row The cell row.)
  @param(fg The color of the glyph's set pixels.)
  @param(bg The color of its clear pixels.)
  @param(glyphIdx Unused.) }
procedure RenderCharTandy(col, row: Word; fg, bg, glyphIdx: Byte); external;
{$F+}

procedure ResetEgaGc;
begin
  Port[C_Ega.GC_ADDR_PORT] := 0;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 1;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 2;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 3;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 4;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 5;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 7;
  Port[C_Ega.GC_DATA_PORT] := $0F;
  Port[C_Ega.GC_ADDR_PORT] := 8;
  Port[C_Ega.GC_DATA_PORT] := $FF;
  Port[C_Ega.SEQ_ADDR_PORT] := 2;
  Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
end;

procedure SetupEgaCurrentPage(page: Byte);
begin
  GDVars.vregs.ah := TextRend.BIOS_SET_PAGE;
  GDVars.vregs.al := page;
  Intr($10, Registers(GDVars.vregs));
  GDVars.egaCurPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaOtherPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);
var
  savedPage: Byte;
  destinationOffset: Word;
  lastScanRow: Word;
  scanRow: Word;
begin
  savedPage := GDVars.pageNum;
  destinationOffset := Word(ulRow) * 40 * 8 + ulCol;
  lastScanRow := (lrRow - ulRow + 1) * 8 - 1;
  TextRend.SetupEgaOtherPage(page);
  TextRend.ResetEgaGc;
  Port[C_Ega.GC_ADDR_PORT] := 5;
  Port[C_Ega.GC_DATA_PORT] := 2;
  for scanRow := 0 to lastScanRow do begin
    FillChar(Mem[GDVars.egaOtherPage: destinationOffset], lrCol - ulCol + 1, color);
    Inc(destinationOffset, 40);
  end;
  Port[C_Ega.GC_ADDR_PORT] := 5;
  Port[C_Ega.GC_DATA_PORT] := 0;
  GDVars.pageNum := savedPage;
  TextRend.SetupEgaOtherPage(GDVars.pageNum);
end;

procedure LoadGameFont;
var
  fontBytes: Word;
  dataPtr: Types.PBytes;
begin
  DaxIo.LoadDax('8X8d1', '.dax', 201, fontBytes, dataPtr);
  if fontBytes = 0 then Exit;
  Move(dataPtr^, GDVars.gameFont^, fontBytes);
  FreeMem(dataPtr, fontBytes);
end;

procedure RenderChar(col, row, fg, bg, count, ch, translateAscii: Byte);
var
  copyIndex: Byte;
  glyphIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  dstOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  cnt: Word;
  { Unused in this version; see the other implementations of this routine. }
  colBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaWord: Word;
  { Unused in this version; see the other implementations of this routine. }
  tandyPx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  bank: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outerRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  plane: Byte;
begin
  if (col > 39) or (row > 24) or (GDVars.gameFont = nil) then Exit;
  if translateAscii <> 0 then
    glyphIndex := Ord(UpCase(Chr(ch))) mod 64
  else
    glyphIndex := ch;
  Move(GDVars.gameFont^[glyphIndex], GDVars.glyphBuf, SizeOf(Types.TGlyph));
  case GDVars.displayMode of
    Types.Cga:
      for copyIndex := 1 to count do begin
        TextRend.RenderCharCga(col, row, fg, bg, glyphIndex);
        Inc(col);
      end;
    Types.Ega:
      for copyIndex := 1 to count do begin
        TextRend.RenderCharEga(col, row, fg, bg, glyphIndex);
        Inc(col);
      end;
    Types.Tandy:
      for copyIndex := 1 to count do begin
        TextRend.RenderCharTandy(col, row, fg, bg, glyphIndex);
        Inc(col);
      end;
  end;
end;

procedure PrintSpaces(col, row, color, count: Byte);
begin
  { Note: range exits after hiding the mouse leave it hidden. }
  Mouse.HideMouse;
  if (col < 0) or (col > 39) or (row < 0) or (row > 24) then Exit;
  TextRend.RenderChar(col, row, color, color, count, 32, 1);
  Mouse.ShowMouse;
end;

procedure DisplayString(col, row, fg, bg: Byte; source: string);
var
  sourceLength: Byte;
  sourceIndex: Byte;
begin
  Mouse.HideMouse;
  { The outer row guard accepts 39; RenderChar still rejects rows above 24. }
  if (col > 39) or (row > 39) then Exit;
  sourceLength := Length(source);
  for sourceIndex := 1 to sourceLength do begin
    TextRend.RenderChar(col, row, fg, bg, 1, Ord(source[sourceIndex]), 1);
    Inc(col);
  end;
  Mouse.ShowMouse;
end;

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: string);
var
  { windowWidth is assigned but never read. }
  sourceLength: Byte;
  { Unused in this version; see the other implementations of this routine. }
  windowWidth: Byte;
  sourceIndex: Byte;
  lineEnd: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineStart: Byte;

  { Prints the current word at the text cursor, advancing it, with a delay after each character while slow text is on. }
  procedure PrintCharInWindow;
  begin
    while sourceIndex <= lineEnd do begin
      TextRend.RenderChar(GDVars.curCol, GDVars.curRow, fg, bg, 1, Ord(source[sourceIndex]), 1);
      if GDVars.slowText <> 0 then Delay(GDVars.gameDelay * 3);
      Inc(sourceIndex);
      Inc(GDVars.curCol);
    end;
  end;

  { Skips the spaces at the start of the next line. }
  procedure FindNewIndex;
  begin
    while (sourceIndex < sourceLength) and (source[sourceIndex] = ' ') do
      Inc(sourceIndex);
  end;

begin
  Mouse.HideMouse;
  { The lower-right row guard uses 39; glyph drawing stops at row 24. }
  if (ulCol > 39) or (ulRow > 24) or (lrCol > 39) or (lrRow > 39) then Exit;
  if (GDVars.curCol < ulCol) or (GDVars.curCol > lrCol) or (GDVars.curRow < ulRow) or
      (GDVars.curRow > lrRow) then begin
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  if clearFirst then begin
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
  end;
  sourceIndex := 1;
  sourceLength := Length(source);
  if sourceLength = 0 then begin
    Mouse.ShowMouse;
    Exit;
  end;
  windowWidth := lrCol - ulCol + 1;
  repeat
    lineEnd := sourceIndex;
    while (lineEnd < sourceLength) and (source[lineEnd] in GDConsts.breakChars) do
      Inc(lineEnd);
    while (lineEnd < sourceLength) and not (source[lineEnd] in GDConsts.breakChars) and (source[lineEnd] <> ' ') do
      Inc(lineEnd);
    if source[lineEnd] <> ' ' then
      while (lineEnd + 1 < sourceLength) and (source[lineEnd + 1] in GDConsts.breakChars) do
        Inc(lineEnd);
    if lineEnd - sourceIndex + GDVars.curCol > lrCol then begin
      if (lineEnd - sourceIndex + GDVars.curCol = lrCol) and (source[lineEnd] = ' ') then begin
        Dec(lineEnd);
        PrintCharInWindow;
      end;
      GDVars.curCol := ulCol;
      Inc(GDVars.curRow);
      FindNewIndex;
      if (GDVars.curRow > lrRow) and (sourceIndex < sourceLength) then begin
        GDVars.curCol := ulCol;
        GDVars.curRow := ulRow;
        TextRend.DisplayAndPause(LightMagenta, Black, 'Press any key to continue');
        GameIo.FlushKeys;
        TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
        PrintCharInWindow;
      end;
    end else
      PrintCharInWindow;
  until sourceIndex > sourceLength;
  if GDVars.curCol > lrCol then begin
    GDVars.curCol := ulCol;
    Inc(GDVars.curRow);
  end;
  Mouse.ShowMouse;
end;

function ReadString(query: Types.TStr40; color, bg, maxLen: Byte): Types.TStr40;
var
  column: Byte;
  inputText: string;
  inputKey: Char;
begin
  TextRend.PrintSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.PROMPT_ROW, color, bg, query);
  column := Length(query);
  inputText := '';
  repeat
    inputKey := ReadKey;
    case inputKey of
      ' '..'z':
        if Length(inputText) < maxLen then begin
          inputText := inputText + inputKey;
          Inc(column);
          TextRend.DisplayString(column, C_Screen.PROMPT_ROW, White, Black, inputKey);
        end;
      C_Keys.BACKSPACE:
        if Length(inputText) > 0 then begin
          inputText := Copy(inputText, 1, Length(inputText) - 1);
          TextRend.PrintSpaces(column, C_Screen.PROMPT_ROW, Black, 1);
          Dec(column);
        end;
      #0:
        inputKey := ReadKey;
    end;
  until (inputKey = C_Keys.ENTER) or (inputKey = C_Keys.ESCAPE) or (GDVars.demoFlag <> 0);
  TextRend.PrintSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
  for column := 1 to Length(inputText) do
    inputText[column] := UpCase(inputText[column]);
  ReadString := inputText;
end;

function ReadNumber(query: Types.TStr40; color, bg: Byte): Word;
var
  value: LongInt;
  inputText: Types.TStr40;
  conversionCode: Integer;
begin
  repeat
    inputText := TextRend.ReadString(query, color, bg, 6);
    Val(inputText, value, conversionCode);
    if conversionCode = 0 then
      if (value > 65536) or (value < 0) then conversionCode := 1;
  until conversionCode = 0;
  ReadNumber := value;
end;

procedure DisplayAndPause(color, bg: Byte; msg: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  TextRend.PrintSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.PROMPT_ROW, color, bg, msg);
  key := GameIo.ReadGameKey;
end;

function GetTicks: LongInt;
var
  hours: Word;
  minutes: Word;
  seconds: Word;
  hundredths: Word;
begin
  GetTime(hours, minutes, seconds, hundredths);
  GetTicks := LongInt(hours) * 360000 + LongInt(minutes) * 6000 + LongInt(seconds) * 100 + hundredths;
end;

procedure ClearScreen;
begin
  case GDVars.displayMode of
    Types.Cga: begin
      FillChar(cgaOddRows, SizeOf(cgaOddRows), 0);
      FillChar(cgaEvenRows, SizeOf(cgaEvenRows), 0);
    end;
    Types.Ega: begin
      TextRend.FillRectEga(0, 0, 39, 24, 0, Black);
      TextRend.FillRectEga(0, 0, 39, 24, 1, Black);
    end;
    Types.Tandy: begin
      FillChar(tandyBank0, SizeOf(tandyBank0), 0);
      FillChar(tandyBank1, SizeOf(tandyBank1), 0);
      FillChar(tandyBank2, SizeOf(tandyBank2), 0);
      FillChar(tandyBank3, SizeOf(tandyBank3), 0);
    end;
  end;
end;

procedure PrintAndPause(msg: Types.TStr40; color, bg: Byte);
begin
  TextRend.PrintSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
  TextRend.DisplayString(0, C_Screen.PROMPT_ROW, color, bg, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, C_Screen.PROMPT_ROW, Black, 40);
end;

procedure PauseOnly;
begin
  Delay(GDVars.gameDelay * 100);
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  firstRow: Word;
  lastRow: Word;
  firstByteColumn: Word;
  byteCount: Word;
  row: Word;
begin
  Mouse.HideMouse;
  case GDVars.displayMode of
    Types.Cga: begin
      firstRow := ulRow * 4;
      lastRow := lrRow * 4 + 3;
      byteCount := (lrCol - ulCol + 1) * 2;
      for row := firstRow to lastRow do begin
        FillChar(cgaEvenRows[row][ulCol], byteCount, 0);
        FillChar(cgaOddRows[row][ulCol], byteCount, 0);
      end;
    end;
    Types.Ega: begin
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, Black);
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, Black);
    end;
    Types.Tandy: begin
      firstRow := ulRow * 2;
      lastRow := lrRow * 2 + 1;
      firstByteColumn := ulCol * 4;
      byteCount := (lrCol - ulCol + 1) * 4;
      for row := firstRow to lastRow do begin
        FillChar(tandyBank0[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank1[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank2[row][firstByteColumn], byteCount, 0);
        FillChar(tandyBank3[row][firstByteColumn], byteCount, 0);
      end;
    end;
  end;
  Mouse.ShowMouse;
end;

begin
end.
