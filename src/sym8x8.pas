{ The 8x8 graphics-symbol set loader and renderer. Symbols 1..295 fall in five sets; 0 and 296..$7FFF are errors. }
{$O+,F+}
{$I-}
unit Sym8x8;

interface

{ Empty routine with no callers. }
procedure NoopSym8x8;

{ Loads an 8x8 symbol set from picture fileId of 8X8D<disk>.DAX into symbolSetPtrs[setId], with light magenta
  transparent, then drains pending keystrokes. A set number outside 0..4 does nothing. If the picture cannot be loaded,
  the error is shown in text mode and the game exits after a key. Note: RestoreVideoMode runs twice on that path.
  @param(fileId Picture number within the file.)
  @param(setId Symbol set slot, 0..4.) }
procedure Load8x8Set(fileId, setId: Byte);

{ Draws 8x8 symbol 1..295, found in its symbol set by number, at a character cell: composited into the view buffer, or
  copied to the 8x8 work buffer and shown on screen at once. Nothing is drawn if its set is not loaded. Symbol 0 and
  296..32767 show an error in text mode and exit after a key. Note: a symbol above 32767 passes every band and the error
  test, so the set index is read uninitialized.
  @param(col Character column.)
  @param(row Character row.)
  @param(symbol Symbol number.)
  @param(intoView True to draw into the view buffer, False to draw straight to the screen.)
  @param(transparent True to draw through the symbol's mask; used only when drawing into the view buffer.) }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; intoView, transparent: Boolean);

{ Does nothing; calling it loads this overlay. }
procedure PrimeSym8x8;

implementation

uses Types, Blit, GameIo, Crt, GDConsts, GDVars;

procedure NoopSym8x8;
begin
end;

procedure PrimeSym8x8;
begin
end;

procedure Load8x8Set(fileId, setId: Byte);
var
  { disk number digit }
  diskDigit: String[1];
  { written, never read }
  fileIdStr: String[3];
  { Unused in this version; see the other implementations of this routine. }
  ignoredKey: Word;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if GDVars.debugActive <> 0 then
    WriteLn(GDVars.debugFile, 'slotnum = ', setId);
  if setId in [0..4] then begin
    Str(GDVars.currentDisk, diskDigit);
    Str(fileId, fileIdStr);
    Blit.LoadPic('8x8d' + diskDigit, fileId, True, LightMagenta, GDVars.symbolSetPtrs[setId]);
    if GDVars.symbolSetPtrs[setId] = nil then begin
      Blit.RestoreVideoMode;
      WriteLn('Unable to load ', fileId, ' from 8x8D' + diskDigit);
      ch := GameIo.ReadGameKey;
      Blit.RestoreVideoMode;
      GameIo.ExitGame;
    end;
    GameIo.FlushKeys;
  end;
end;

procedure Put8x8Sym(col, row: ShortInt; symbol: Word; intoView, transparent: Boolean);
var
  setIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  case symbol of
    1..45: setIdx := 0;
    46..115: setIdx := 1;
    116..185: setIdx := 2;
    186..255: setIdx := 3;
    256..295: setIdx := 4;
    0, 296..32767: begin
      Blit.RestoreVideoMode;
      WriteLn('Bad symbol number in Put8x8Symbol.');
      ch := GameIo.ReadGameKey;
      GameIo.ExitGame;
    end;
  end;
  if GDVars.symbolSetPtrs[setIdx] <> nil then begin
    Dec(symbol, GDConsts.symSetFirst[setIdx]);
    if intoView then
      Blit.BlitTileCell(col, row, symbol, Ord(transparent), GDVars.symbolSetPtrs[setIdx], GDVars.egaDest)
    else begin
      with GDVars.symbolSetPtrs[setIdx]^ do
        Move(data[symbol * imgSize], GDVars.cur8x8Buf^.data, imgSize);
      Blit.ShowPic(col, row, GDVars.cur8x8Buf);
    end;
  end;
end;

begin
end.
