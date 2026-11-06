{ Screen frames drawn from 8x8 border symbols, and clearing of character-cell rectangles in video memory. The frames
  cover columns 0..39 and rows 0..23; the mouse cursor is hidden while each one is drawn. }
{$O+,F+}
unit Border;

interface

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22) and draws the outer frame: row 0, whose junctions
  at columns 8, 19 and 30 come from the zone's top-junction values, columns 0 and 39, and the bottom row, row 23.
  @param(layout True to draw plain sides at rows 15..17; False keeps the side junctions for a rule across row 16.) }
procedure DrawWindowFrame(layout: Boolean);

{ Clears the screen inside the outer frame and draws the banded credits window: solid rules across rows 0, 4, 20 and 23,
  joined by side columns 0 and 39. }
procedure DrawCreditsFrame;

{ Draws the exploration layout: the outer frame, a horizontal rule across row 16, a vertical rule down column 16 from
  row 0 to row 16, and an inner box on columns and rows 2..14. }
procedure DrawViewFrame;

{ Draws the outer frame with its side junctions and a horizontal rule across row 16. }
procedure DrawRowDivider;

{ Draws the outer frame and a horizontal rule across row 16, but clears only rows 1..16 inside the frame, leaving rows
  17..22 as they were. }
procedure DrawMemorizeFrame;

{ Clears the whole screen and draws the combat layout: row 0, columns 0, 22 and 39 from row 0 to row 22, and a bottom
  row across row 22. Row 23 is left blank. }
procedure DrawCombatFrame;

{ Clears the whole screen and draws the character sheet layout: row 0, horizontal rules across rows 8, 16, 20 and 23,
  columns 0 and 39 from row 0 to row 22, and a vertical rule down column 19 from row 9 to row 19. }
procedure DrawCharSheetFrame;

{ Draws the outer frame with plain sides, then a horizontal rule across row 2 that meets the sides at row 3. }
procedure DrawTitleInset;

{ Clears a rectangle of character cells, corners included, to color 0 directly in video memory, with the mouse cursor
  hidden. CGA clears the four scanlines of each cell row in both of its banks, EGA clears both display pages, and Tandy
  clears two scanlines in each of its four banks.
  @param(x1 Left column.)
  @param(y1 Top row.)
  @param(x2 Right column.)
  @param(y2 Bottom row.) }
procedure ClearBox(x1, y1, x2, y2: ShortInt);

implementation

uses Types, Sym8x8, Mouse, TextRend, GDConsts, GDVars;

const
  { first frame symbol in the 8x8 set; frame tiles are offsets from it }
  SYMBOL_BASE = 276;

var
  { graphics-memory planes as 2-D [row, col] grids: 80 bytes a row for the two-plane (mode 0) layout, 160 for the
    four-plane (mode 2) layout. }
  cga0: array[0..99, 0..79] of Byte absolute $B800:$0000;
  cga1: array[0..99, 0..79] of Byte absolute $BA00:$0000;
  qplane0: array[0..49, 0..159] of Byte absolute $B800:$0000;
  qplane1: array[0..49, 0..159] of Byte absolute $BA00:$0000;
  qplane2: array[0..49, 0..159] of Byte absolute $BC00:$0000;
  qplane3: array[0..49, 0..159] of Byte absolute $BE00:$0000;

procedure DrawWindowFrame(layout: Boolean);
var
  column: Byte;
  row: Byte;
  tile: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  for column := 0 to 39 do begin
    case column of
      8: tile := GDVars.zone0^.topJunction0 + 10;
      19: tile := GDVars.zone0^.topJunction1 + 6;
      30: tile := GDVars.zone0^.topJunction2 + 14;
    else
      tile := GDConsts.topEdgeTiles[column];
    end;
    Sym8x8.Put8x8Sym(column, 0, Border.SYMBOL_BASE + tile, False, False);
  end;
  for row := 0 to 23 do begin
    if (row > 14) and (row < 18) and layout then
      tile := 4
    else
      tile := GDConsts.leftEdgeTiles[row];
    Sym8x8.Put8x8Sym(0, row, Border.SYMBOL_BASE + tile, False, False);
    Sym8x8.Put8x8Sym(39, row, Border.SYMBOL_BASE + tile, False, False);
  end;
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 23, Border.SYMBOL_BASE, False, False);
  Mouse.ShowMouse;
end;

procedure DrawCreditsFrame;
var
  column: Byte;
  row: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  for row := 0 to 23 do
    case row of
      0, 4, 20, 23:
        for column := 0 to 39 do
          Sym8x8.Put8x8Sym(column, row, Border.SYMBOL_BASE, False, False);
      1, 5, 21:
        begin
          Sym8x8.Put8x8Sym(0, row, Border.SYMBOL_BASE + 3, False, False);
          Sym8x8.Put8x8Sym(39, row, Border.SYMBOL_BASE + 3, False, False);
        end;
      3, 19, 22:
        begin
          Sym8x8.Put8x8Sym(0, row, Border.SYMBOL_BASE + 5, False, False);
          Sym8x8.Put8x8Sym(39, row, Border.SYMBOL_BASE + 5, False, False);
        end;
    else begin
        Sym8x8.Put8x8Sym(0, row, Border.SYMBOL_BASE + 4, False, False);
        Sym8x8.Put8x8Sym(39, row, Border.SYMBOL_BASE + 4, False, False);
      end;
    end;
  Mouse.ShowMouse;
end;

procedure DrawViewFrame;
var
  column: Byte;
  row: Byte;
begin
  Mouse.HideMouse;
  Border.DrawWindowFrame(False);
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 16, Border.SYMBOL_BASE, False, False);
  for row := 0 to 16 do
    Sym8x8.Put8x8Sym(16, row, Border.SYMBOL_BASE + GDConsts.viewDividerTiles[row], False, False);
  for column := 2 to 14 do begin
    Sym8x8.Put8x8Sym(column, 2, Border.SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(column, 14, Border.SYMBOL_BASE, False, False);
  end;
  for row := 2 to 14 do begin
    Sym8x8.Put8x8Sym(2, row, Border.SYMBOL_BASE + GDConsts.insetLeftTiles[row], False, False);
    Sym8x8.Put8x8Sym(14, row, Border.SYMBOL_BASE + GDConsts.insetRightTiles[row], False, False);
  end;
  Mouse.ShowMouse;
end;

procedure DrawRowDivider;
var
  column: Byte;
begin
  Mouse.HideMouse;
  Border.DrawWindowFrame(False);
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 16, Border.SYMBOL_BASE, False, False);
  Mouse.ShowMouse;
end;

procedure DrawMemorizeFrame;
var
  column: Byte;
  row: Byte;
  tileOffset: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 16);
  for column := 0 to 39 do begin
    case column of
      8: tileOffset := GDVars.zone0^.topJunction0 + 10;
      19: tileOffset := GDVars.zone0^.topJunction1 + 6;
      30: tileOffset := GDVars.zone0^.topJunction2 + 14;
    else
      tileOffset := GDConsts.topEdgeTiles[column];
    end;
    Sym8x8.Put8x8Sym(column, 0, Border.SYMBOL_BASE + tileOffset, False, False);
  end;
  for row := 0 to 23 do begin
    Sym8x8.Put8x8Sym(0, row, Border.SYMBOL_BASE + GDConsts.leftEdgeTiles[row], False, False);
    Sym8x8.Put8x8Sym(39, row, Border.SYMBOL_BASE + GDConsts.rightEdgeTiles[row], False, False);
  end;
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 23, Border.SYMBOL_BASE, False, False);
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 16, Border.SYMBOL_BASE, False, False);
  Mouse.ShowMouse;
end;

procedure DrawCombatFrame;
var
  column: Byte;
  row: Byte;
  tileOffset: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(0, 0, 39, 23);
  for column := 0 to 39 do begin
    case column of
      8: tileOffset := GDVars.zone0^.topJunction0 + 10;
      19: tileOffset := GDVars.zone0^.topJunction1 + 6;
      30: tileOffset := GDVars.zone0^.topJunction2 + 14;
    else
      tileOffset := GDConsts.topEdgeTiles[column];
    end;
    Sym8x8.Put8x8Sym(column, 0, Border.SYMBOL_BASE + tileOffset, False, False);
  end;
  for row := 0 to 22 do begin
    Sym8x8.Put8x8Sym(0, row, Border.SYMBOL_BASE + GDConsts.combatLeftTiles[row], False, False);
    Sym8x8.Put8x8Sym(22, row, Border.SYMBOL_BASE + GDConsts.combatMiddleTiles[row], False, False);
    Sym8x8.Put8x8Sym(39, row, Border.SYMBOL_BASE + GDConsts.combatRightTiles[row], False, False);
  end;
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 22, Border.SYMBOL_BASE, False, False);
  Mouse.ShowMouse;
end;

procedure DrawCharSheetFrame;
var
  column: Byte;
  row: Byte;
  tile: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(0, 0, 39, 23);
  for column := 0 to 39 do begin
    case column of
      8: tile := GDVars.zone0^.topJunction0 + 10;
      19: tile := GDVars.zone0^.topJunction1 + 6;
      30: tile := GDVars.zone0^.topJunction2 + 14;
    else
      tile := GDConsts.topEdgeTiles[column];
    end;
    Sym8x8.Put8x8Sym(column, 0, Border.SYMBOL_BASE + tile, False, False);
    Sym8x8.Put8x8Sym(column, 8, Border.SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(column, 16, Border.SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(column, 20, Border.SYMBOL_BASE, False, False);
    Sym8x8.Put8x8Sym(column, 23, Border.SYMBOL_BASE, False, False);
  end;
  for row := 0 to 22 do begin
    Sym8x8.Put8x8Sym(0, row, Border.SYMBOL_BASE + GDConsts.sheetSideTiles[row], False, False);
    Sym8x8.Put8x8Sym(39, row, Border.SYMBOL_BASE + GDConsts.sheetSideTiles[row], False, False);
  end;
  for row := 9 to 19 do
    Sym8x8.Put8x8Sym(19, row, Border.SYMBOL_BASE + GDConsts.sheetDividerTiles[row], False, False);
  Mouse.ShowMouse;
end;

procedure DrawTitleInset;
var
  column: Byte;
begin
  Mouse.HideMouse;
  Border.DrawWindowFrame(True);
  for column := 0 to 39 do
    Sym8x8.Put8x8Sym(column, 2, Border.SYMBOL_BASE, False, False);
  Sym8x8.Put8x8Sym(0, 3, Border.SYMBOL_BASE + 3, False, False);
  Sym8x8.Put8x8Sym(39, 3, Border.SYMBOL_BASE + 3, False, False);
  Mouse.ShowMouse;
end;

procedure ClearBox(x1, y1, x2, y2: ShortInt);
var
  topRow: Word;
  bottomRow: Word;
  byteColumn: Integer;
  rowWidth: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaColOff: Word;
  row: Word;
begin
  Mouse.HideMouse;
  case GDVars.displayMode of
    Types.Cga:
      begin
        topRow := y1 * 4;
        bottomRow := y2 * 4 + 3;
        rowWidth := (x2 - x1 + 1) * 2;
        for row := topRow to bottomRow do begin
          FillChar(cga0[row, x1 * 2], rowWidth, 0);
          FillChar(cga1[row, x1 * 2], rowWidth, 0);
        end;
      end;
    Types.Ega:
      begin
        TextRend.fillRectEga(x1, y1, x2, y2, 0, 0);
        TextRend.fillRectEga(x1, y1, x2, y2, 1, 0);
      end;
    Types.Tandy:
      begin
        topRow := y1 * 2;
        bottomRow := y2 * 2 + 1;
        byteColumn := x1 * 4;
        rowWidth := (x2 - x1 + 1) * 4;
        for row := topRow to bottomRow do begin
          FillChar(qplane0[row, byteColumn], rowWidth, 0);
          FillChar(qplane1[row, byteColumn], rowWidth, 0);
          FillChar(qplane2[row, byteColumn], rowWidth, 0);
          FillChar(qplane3[row, byteColumn], rowWidth, 0);
        end;
      end;
  end;
  Mouse.ShowMouse;
end;

begin
end.
