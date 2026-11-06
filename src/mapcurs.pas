{ The party cursor on the overland map. DrawCursor saves the map cell under the party, draws the cursor over a copy of
  it and shows the result; RestoreCursorBackground puts the saved cell back. Explore calls them around each overland
  step, and EclVm after a redraw. }
{$O+,F+}
unit MapCurs;
interface

{ Draws the party cursor on the overland map: saves the map cell under the party (one cell in from the map's corner)
  into a buffer, lays the cursor image over a copy of it through its mask, shows the result and clears the dirty spans
  the drawing recorded. }
procedure DrawCursor;

{ Erases the party cursor by putting back the map cell DrawCursor saved. }
procedure RestoreCursorBackground;

{ Does nothing; calling it loads this overlay. }
procedure PrimeMapCurs;

implementation

uses Blit, GDConsts, GDVars;

procedure PrimeMapCurs;
begin
end;

procedure DrawCursor;
begin
  Blit.GrabPic(GDVars.zone0^.partyX + 1, GDVars.zone0^.partyY + 1, GDVars.cursorBackground);
  Blit.BlitTileCell(0, 0, 0, 0, GDVars.cursorBackground, GDVars.cursorComposite);
  Blit.BlitTileCell(0, 0, 0, 1, GDVars.cursorImg, GDVars.cursorComposite);
  Blit.ShowPic(GDVars.zone0^.partyX + 1, GDVars.zone0^.partyY + 1, GDVars.cursorComposite);
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanY, SizeOf(GDVars.spanY), 0);
  FillChar(GDVars.spanX0, SizeOf(GDVars.spanX0), 255);
  FillChar(GDVars.spanX1, SizeOf(GDVars.spanX1), 0);
end;

procedure RestoreCursorBackground;
begin
  Blit.ShowPic(GDVars.zone0^.partyX + 1, GDVars.zone0^.partyY + 1, GDVars.cursorBackground);
end;

begin
end.
