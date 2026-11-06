{ 2D map-tile and icon-animation loading/rendering. }
{$O+,F+,I-}
unit MapTiles;

interface

uses Types, Blit, GameIo, Crt, GDConsts, GDVars, Debug, C_Dir;

{ Loads a picture of 24x24 map tiles and copies the given number of its tiles into tile-set buffer 1 from the given slot
  on, then drains pending keystrokes. A slot above 39 is a fatal error, reported in text mode.
  @param(resourceName Base name of the DAX file.)
  @param(fileId Picture number within the file.)
  @param(slot First tile slot written.)
  @param(count Number of tiles copied.) }
procedure Load24x24Set(resourceName: string; fileId, slot, count: Byte);

{ Draws a 24x24 map tile into the view buffer at a character cell. Tiles 0..127 come from tile-set buffer 1, tiles 128
  and up from tile-set buffer 2.
  @param(col Character column.)
  @param(row Character row.)
  @param(tile Tile number.)
  @param(drawFlags Drawing flags passed to the tile blitter; bit 0 draws through the mask.) }
procedure Copy2DTile(col, row: ShortInt; tile, drawFlags: Byte);

{ Frees both frames of an icon animation slot.
  @param(animIdx The slot.) }
procedure FreeIconAnim(animIdx: Byte);

{ Loads the two frames of an icon animation, picture fileId and fileId + 128, with black transparent. For CHEAD and
  CBODY files the last letter of the name is a size letter: it is dropped, and T adds 64 to fileId. COMSPR and ICON are
  loaded as named. Any other name gets the current disk number appended, and outside CGA both frames are recolored from
  color 13 to color 8. Pending keystrokes are drained afterwards.
  @param(resourceName Base name of the DAX file.)
  @param(fileId Picture number of the first frame.)
  @param(animIdx Slot receiving the frames.) }
procedure LoadIconAnim(resourceName: string; fileId, animIdx: Byte);

{ Draws one frame of an icon animation into the view buffer, clipped, at three character cells per map cell, mirrored
  for facings past southeast. Nothing is drawn if the frame is not loaded.
  @param(col Map column.)
  @param(row Map row.)
  @param(facing Direction the icon faces.)
  @param(frame Frame to draw, 0 or 1.)
  @param(animIdx Animation slot.) }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeMapTiles;

implementation

const
  { ids 128+ live in tile-set buffer 2 }
  TILE_ID_MASK = $7F;

procedure PrimeMapTiles;
begin
  Debug.PrimeDebug;
end;

procedure Load24x24Set(resourceName: string; fileId, slot, count: Byte);
var
  sourceTiles: Types.PImgBuf;
  byteCount: Word;
  destOffset: Word;
begin
  if slot > 39 then begin
    Blit.RestoreVideoMode;
    WriteLn('Start range error in Load24x24Set');
    GameIo.ExitGame;
  end;
  sourceTiles := nil;
  Blit.LoadPic(resourceName, fileId, False, 0, sourceTiles);
  byteCount := count * sourceTiles^.imgSize;
  destOffset := slot * sourceTiles^.imgSize;
  if GDVars.tileSet1 <> nil then
    Move(sourceTiles^.data, GDVars.tileSet1^.data[destOffset], byteCount);
  Blit.FreePic(sourceTiles);
  GameIo.FlushKeys;
end;

procedure Copy2DTile(col, row: ShortInt; tile, drawFlags: Byte);
begin
  if tile > MapTiles.TILE_ID_MASK then
    Blit.BlitTileCell(col, row, tile and MapTiles.TILE_ID_MASK, drawFlags, GDVars.tileSet2, GDVars.egaDest)
  else
    Blit.BlitTileCell(col, row, tile, drawFlags, GDVars.tileSet1, GDVars.egaDest);
end;

procedure FreeIconAnim(animIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Integer;
begin
  if GDVars.iconAnims[animIdx, 0] <> nil then
    Blit.FreePic(GDVars.iconAnims[animIdx, 0]);
  if GDVars.iconAnims[animIdx, 1] <> nil then
    Blit.FreePic(GDVars.iconAnims[animIdx, 1]);
end;

procedure LoadIconAnim(resourceName: string; fileId, animIdx: Byte);
var
  fileSuffix: string[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if (Copy(resourceName, 1, 5) = 'CHEAD') or (Copy(resourceName, 1, 5) = 'CBODY') then begin
    if UpCase(resourceName[Length(resourceName)]) = 'T' then
      Inc(fileId, 64);
    resourceName := Copy(resourceName, 1, Length(resourceName) - 1);
    fileSuffix := '';
    Blit.LoadPic(resourceName + fileSuffix, fileId, True, Black, GDVars.iconAnims[animIdx, 0]);
    Blit.LoadPic(resourceName + fileSuffix, fileId + 128, True, Black, GDVars.iconAnims[animIdx, 1]);
  end else if (resourceName = 'COMSPR') or (resourceName = 'ICON') then begin
    fileSuffix := '';
    Blit.LoadPic(resourceName + fileSuffix, fileId, True, Black, GDVars.iconAnims[animIdx, 0]);
    Blit.LoadPic(resourceName + fileSuffix, fileId + 128, True, Black, GDVars.iconAnims[animIdx, 1]);
  end else begin
    Str(GDVars.currentDisk, fileSuffix);
    Blit.LoadPic(resourceName + fileSuffix, fileId, True, Black, GDVars.iconAnims[animIdx, 0]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmapPink8, 0, False, GDVars.iconAnims[animIdx, 0]);
    Blit.LoadPic(resourceName + fileSuffix, fileId + 128, True, Black, GDVars.iconAnims[animIdx, 1]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmapPink8, 0, False, GDVars.iconAnims[animIdx, 1]);
  end;
  GameIo.FlushKeys;
end;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  scratchPic: Types.PImgBuf;
begin
  if GDVars.iconAnims[animIdx, frame] = nil then
    Exit;
  with GDVars.iconAnims[animIdx, frame]^ do begin
    Blit.AllocPic(height, width, 1, 1, scratchPic);
    if facing > C_Dir.SOUTHEAST then
      Blit.MirrorPic(GDVars.iconAnims[animIdx, frame], scratchPic)
    else begin
      Move(data, scratchPic^.data, imgSize);
      Move(transp^, scratchPic^.transp^, imgSize);
    end;
  end;
  Blit.BlitTileClipped(col * 3, row * 3, 0, 1, scratchPic, GDVars.egaDest);
  Blit.FreePic(scratchPic);
end;

begin
end.
