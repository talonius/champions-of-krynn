{ Dungeon perspective renderer, automap, and GEO/WALLDEF loader. }
{$O+,F+,I-}
unit View3D;

interface

uses Types, GDConsts, GDVars, Blit, DaxIo, GameIo, Sym8x8, Debug, C_Dir, C_Gbvm;

{ Stores the four 3D view band colors: sky, the two horizon bands and floor.
  @param(skyColor The sky color.)
  @param(horizonUpper The first horizon band's color.)
  @param(horizonLower The second horizon band's color.)
  @param(floorColor The floor color.) }
procedure SetView3DColors(skyColor, horizonUpper, horizonLower, floorColor: Byte);

{ Reads the wall type on one side of a cell: north and east share one map plane and south and west another, one nibble
  each. Off-map coordinates wrap around the 16x16 map, except in scripts 0 and 80, where they give 0.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The wall type, 0 for none. Note: a facing other than the four compass points leaves it undefined.) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the barrier on one side of a cell. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The two-bit barrier type of the wall there, or 1 when there is no wall.) }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Reads a cell's event from the 3D map. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @returns(The cell event.) }
function GetMapEvent(x, y: ShortInt): Byte;

{ Draws the 3D view from a cell, or the automap while it is on. The view is the backdrop, then the walls row by row from
  two cells ahead to the party's own row: fronts, the corners between far fronts, and the side walls. It is flushed to
  the screen.
  @param(x Map column of the party's cell.)
  @param(y Map row of the party's cell.)
  @param(facing The direction the party faces.) }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Loads a wall-definition block of WALLDEF<disk>.DAX into a wall slot, and into the following slots when the block holds
  several entries. In each filled slot the cache entry is cleared, wall symbols from the first set's last symbol on are
  moved up to the slot's symbol set, and the matching 8x8 symbol set is loaded (for entry n of a multi-entry block, the
  picture numbered ten times the block plus n); the first slot's cache entry is then stamped with the block and the
  slot. A slot outside 1 to 3 does nothing; a missing block, or one that does not fit in slots 1 to 3, restores the
  video mode, reports it, waits for a key and quits. Note: the size check does not count a partial last entry, but the
  copy still copies it, into the slot after the last one counted, which can lie past slot 3.
  @param(fileId The block to load.)
  @param(wallSetSlot The first slot it fills, 1 to 3.) }
procedure LoadWallSet(fileId, wallSetSlot: Byte);

{ Loads a 3D map block of GEO<disk>.DAX (1026 bytes: a 2-byte header and the four 16x16 planes) and records its id for
  the script; a missing or wrong-sized block reports it, waits for a key and quits.
  @param(mapId The block to load.) }
procedure Load3DMap(mapId: Byte);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeView3D;

implementation

const
  { party arrow symbols, one per facing / 2 }
  AUTOMAP_ARROW_SYM = 256;
  { + 1 north, + 2 east, + 4 south, + 8 west wall }
  AUTOMAP_WALL_SYM = 260;
  GBVM_BORDER_WALL = $4BC9;

procedure PrimeView3D;
begin
  Sym8x8.PrimeSym8x8;
  Debug.PrimeDebug;
end;

{ Draws the automap into the view buffer and flushes it: the 11x11 cells around the viewer, kept on the 16x16 map, each
  as the symbol for its walls (symbol 260 plus one bit per side), and the viewer's arrow (symbol 256 plus facing div 2)
  on its cell.
  @param(x The viewer's map column.)
  @param(y The viewer's map row.)
  @param(facing The direction faced: 0, 2, 4 or 6.) }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  playerWindowX: ShortInt;
  playerWindowY: ShortInt;
  wallX: ShortInt;
  wallY: ShortInt;
  mapOriginX: ShortInt;
  mapOriginY: ShortInt;
  mapX: ShortInt;
  mapY: ShortInt;
  wallSymbol: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
  mapOriginX := x - 5;
  if mapOriginX < 0 then mapOriginX := 0;
  if mapOriginX > 5 then mapOriginX := 5;
  playerWindowX := x - mapOriginX;
  mapOriginY := y - 5;
  if mapOriginY < 0 then mapOriginY := 0;
  if mapOriginY > 5 then mapOriginY := 5;
  playerWindowY := y - mapOriginY;
  for wallY := 0 to 10 do begin
    mapY := wallY + mapOriginY;
    for wallX := 0 to 10 do begin
      mapX := wallX + mapOriginX;
      wallSymbol := View3D.AUTOMAP_WALL_SYM;
      if View3D.GetWallType(mapX, mapY, C_Dir.NORTH) > 0 then Inc(wallSymbol);
      if View3D.GetWallType(mapX, mapY, C_Dir.EAST) > 0 then Inc(wallSymbol, 2);
      if View3D.GetWallType(mapX, mapY, C_Dir.SOUTH) > 0 then Inc(wallSymbol, 4);
      if View3D.GetWallType(mapX, mapY, C_Dir.WEST) > 0 then Inc(wallSymbol, 8);
      Sym8x8.Put8x8Sym(wallX + 3 - 1, wallY + 3 - 1, wallSymbol, True, False);
    end;
  end;
  Sym8x8.Put8x8Sym(playerWindowX + 3 - 1, playerWindowY + 3 - 1, facing div 2 + View3D.AUTOMAP_ARROW_SYM, True, False);
  Blit.FlushView;
end;

procedure SetView3DColors(skyColor, horizonUpper, horizonLower, floorColor: Byte);
begin
  GDVars.viewColSky := skyColor;
  GDVars.viewHorizonUpper := horizonUpper;
  GDVars.viewHorizonLower := horizonLower;
  GDVars.viewColFloor := floorColor;
end;

{ Paints the 3D view's background into the view buffer in the recorded colors; CGA uses its own bands. Outside CGA,
  under an open sky (a cell event below $80 and a light cyan sky) it draws the sun (edgeTile) by the clock's hour when
  the party faces east, south or west, and the north sky picture (frontTile) when it faces north; then it draws the
  horizon picture (skyTile). }
procedure DrawBackdrop;
var
  borderWall: Word;
  tileX: Byte;
  tileY: Byte;
  edgeX: Byte;
  { Unused in this version; see the other implementations of this routine. }
  by1: Byte;
begin
  if GDVars.displayMode = Types.Cga then begin
    Blit.FillPicRect(2, 16, 11, 43, GDVars.viewColSky, GDConsts.cmapStd, GDVars.egaDest);
    Blit.FillPicRect(2, 59, 11, 1, GDVars.viewHorizonUpper, GDConsts.cmapStd, GDVars.egaDest);
    Blit.FillPicRect(2, 60, 11, 2, GDVars.viewHorizonLower, GDConsts.cmapStd, GDVars.egaDest);
    Blit.FillPicRect(2, 62, 11, 42, GDVars.viewColFloor, GDConsts.cmapStd, GDVars.egaDest);
  end else begin
    Blit.FillPicRect(2, 16, 11, 44, GDVars.viewColSky, GDConsts.cmapStd, GDVars.egaDest);
    Blit.FillPicRect(2, 60, 11, 2, GDVars.viewHorizonLower, GDConsts.cmapStd, GDVars.egaDest);
    Blit.FillPicRect(2, 62, 11, 42, GDVars.viewColFloor, GDConsts.cmapStd, GDVars.egaDest);
    if (View3D.GetMapEvent(GDVars.mapState.x, GDVars.mapState.y) < $80) and (GDVars.viewColSky = 11) then begin
      tileX := 2;
      tileY := 2;
      edgeX := 12;
      by1 := 12;
      borderWall := GDVars.zone0^.vars[View3D.GBVM_BORDER_WALL];
      case borderWall of
        1..5: begin
          case GDVars.mapState.facing of
            2: Blit.BlitTileClipped(edgeX - 3, tileY + 5 - borderWall, 0, 1, GDVars.edgeTile, GDVars.egaDest);
            4: if borderWall > 2 then
                 Blit.BlitTileClipped(tileX + borderWall - 3, tileY + 5 - borderWall, 0, 1, GDVars.edgeTile,
                                      GDVars.egaDest);
          end;
        end;
        13..18: begin
          case GDVars.mapState.facing of
            6: Blit.BlitTileClipped(tileX, tileY + borderWall - 13, 0, 1, GDVars.edgeTile, GDVars.egaDest);
            4: if borderWall < 16 then
                 Blit.BlitTileClipped(tileX + borderWall - 8, tileY + borderWall - 13, 0, 1, GDVars.edgeTile,
                                      GDVars.egaDest);
          end;
        end;
      end;
      if GDVars.mapState.facing = C_Dir.NORTH then
        Blit.BlitTileClipped(tileX, tileY, 0, 1, GDVars.frontTile, GDVars.egaDest);
    end;
    Blit.BlitTileClipped(2, 7, 0, 1, GDVars.skyTile, GDVars.egaDest);
  end;
end;

{ Draws a wall in one perspective form, its width by its height in symbols, clipped to the 11x11 view; symbol 0 is left
  transparent.
  @param(x The view column of its top left symbol.)
  @param(y The view row of its top left symbol.)
  @param(wallType The wall type, an index into the loaded wall graphics.)
  @param(slot The perspective form.) }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  lastColumn: Integer;
  lastRow: Integer;
  columnIndex: Integer;
  rowIndex: Integer;
  symbolIndex: Byte;
begin
  symbolIndex := GDConsts.viewSliceTable.start[slot];
  lastColumn := GDConsts.viewSliceTable.cols[slot] + x - 1;
  lastRow := GDConsts.viewSliceTable.rows[slot] + y - 1;
  for rowIndex := y to lastRow do
    for columnIndex := x to lastColumn do begin
      if (rowIndex >= 0) and (rowIndex <= 10) and (columnIndex >= 0) and (columnIndex <= 10) and
          (GDVars.wallGfx^.slices[wallType][symbolIndex] > 0) then
        Sym8x8.Put8x8Sym(columnIndex + 3 - 1, rowIndex + 3 - 1, GDVars.wallGfx^.slices[wallType][symbolIndex], True,
                         True);
      Inc(symbolIndex);
    end;
end;

{ Tells whether a cell is on the 16x16 map.
  @param(x The map column.)
  @param(y The map row.)
  @returns(True when the cell is on the map.) }
function Valid3DCoords(x, y: ShortInt): Boolean;
begin
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  b: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.curEclId = 0) or (GDVars.curEclId = 80)) then
    GetBarrierType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    b := 1;
    if View3D.GetWallType(x, y, facing) > 0 then
      case facing of
        C_Dir.WEST: b := (GDVars.geo^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: b := (GDVars.geo^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: b := (GDVars.geo^.barriers[y][x] and $0C) shr 2;
        C_Dir.NORTH: b := GDVars.geo^.barriers[y][x] and $03;
      end;
    GetBarrierType := b;
  end;
end;

function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.curEclId = 0) or (GDVars.curEclId = 80)) then
    GetWallType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.geo^.wallsNE[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.geo^.wallsNE[y][x] and $0F;
      C_Dir.SOUTH: GetWallType := (GDVars.geo^.wallsSW[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.geo^.wallsSW[y][x] and $0F;
    end;
  end;
end;

function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.curEclId = 0) or (GDVars.curEclId = 80)) then
    GetMapEvent := 0
  else begin
    { The x-clamp uses else-if; the y-clamp is two separate ifs. }
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    GetMapEvent := GDVars.geo^.events[y][x];
  end;
end;

procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  leftFacing: Byte;
  rightFacing: Byte;
  reverseFacing: Byte;
  currentX: Integer;
  currentY: Integer;
  forwardDeltaX: Word;
  forwardDeltaY: Word;
  wallX: Integer;
  wallY: Integer;
  side: Byte;
  horizontalOffset: Integer;
  distance: Byte;
  wallFront: Byte;
  wallSide: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slack: Byte;
  previousWall: Byte;
begin
  if GDVars.automapOn then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    View3D.DrawBackdrop;
    leftFacing := (facing + 6) mod 8;
    reverseFacing := (facing + 4) mod 8;
    rightFacing := (facing + 2) mod 8;
    currentX := x;
    currentY := y;
    forwardDeltaX := GDConsts.dirDeltaX[facing];
    forwardDeltaY := GDConsts.dirDeltaY[facing];
    distance := 2;
    Inc(currentX, distance * forwardDeltaX);
    Inc(currentY, distance * forwardDeltaY);
    repeat
      case distance of
        2: begin
          wallX := currentX;
          wallY := currentY;
          side := 0;
          horizontalOffset := 0;
          previousWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wallX, wallY, facing);
            if not View3D.Valid3DCoords(wallX, wallY) and (View3D.GetWallType(wallX, wallY, rightFacing) = 0) then
              previousWall := 0;
            if wallFront <> 0 then begin
              if previousWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[9] + horizontalOffset + 1,
                                     GDConsts.viewSliceTable.yRow[9], previousWall, 9);
              previousWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[0] + horizontalOffset, GDConsts.viewSliceTable.yRow[0],
                                   wallFront, 0);
            end else begin
              if (previousWall > 0) and
                  (View3D.GetWallType(wallX - GDConsts.dirDeltaX[leftFacing], wallY - GDConsts.dirDeltaY[leftFacing],
                                      leftFacing) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[9] + horizontalOffset + 1,
                                     GDConsts.viewSliceTable.yRow[9], previousWall, 9);
              previousWall := 0;
            end;
            Inc(side);
            Dec(horizontalOffset, 2);
            wallX := wallX + GDConsts.dirDeltaX[leftFacing];
            wallY := wallY + GDConsts.dirDeltaY[leftFacing];
          end;
          wallX := currentX;
          wallY := currentY;
          side := 0;
          horizontalOffset := 0;
          previousWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wallX, wallY, facing);
            if not View3D.Valid3DCoords(wallX, wallY) and (View3D.GetWallType(wallX, wallY, leftFacing) = 0) then
              previousWall := 0;
            if wallFront <> 0 then begin
              if previousWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[9] + horizontalOffset - 1,
                                     GDConsts.viewSliceTable.yRow[9], previousWall, 9);
              previousWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[0] + horizontalOffset, GDConsts.viewSliceTable.yRow[0],
                                   wallFront, 0);
            end else begin
              if (previousWall > 0) and
                  (View3D.GetWallType(wallX - GDConsts.dirDeltaX[rightFacing], wallY - GDConsts.dirDeltaY[rightFacing],
                                      rightFacing) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[9] + horizontalOffset - 1,
                                     GDConsts.viewSliceTable.yRow[9], previousWall, 9);
              previousWall := 0;
            end;
            Inc(side);
            Inc(horizontalOffset, 2);
            wallX := wallX + GDConsts.dirDeltaX[rightFacing];
            wallY := wallY + GDConsts.dirDeltaY[rightFacing];
          end;
          wallX := currentX;
          wallY := currentY;
          side := 0;
          horizontalOffset := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wallX, wallY, leftFacing);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[1] + horizontalOffset,
                                     GDConsts.viewSliceTable.yRow[1], wallSide, 1)
              else
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[1] + horizontalOffset - 1,
                                     GDConsts.viewSliceTable.yRow[1], wallSide, 1);
            Inc(side);
            Dec(horizontalOffset, 2);
            wallX := wallX + GDConsts.dirDeltaX[leftFacing];
            wallY := wallY + GDConsts.dirDeltaY[leftFacing];
          end;
          wallX := currentX;
          wallY := currentY;
          side := 0;
          horizontalOffset := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wallX, wallY, rightFacing);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[2] + horizontalOffset,
                                     GDConsts.viewSliceTable.yRow[2], wallSide, 2)
              else
                View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[2] + horizontalOffset + 1,
                                     GDConsts.viewSliceTable.yRow[2], wallSide, 2);
            Inc(side);
            Inc(horizontalOffset, 2);
            wallX := wallX + GDConsts.dirDeltaX[rightFacing];
            wallY := wallY + GDConsts.dirDeltaY[rightFacing];
          end;
        end;
        1: begin
          wallX := currentX + GDConsts.dirDeltaX[leftFacing];
          wallX := wallX + GDConsts.dirDeltaX[leftFacing];
          wallY := currentY + GDConsts.dirDeltaY[leftFacing];
          wallY := wallY + GDConsts.dirDeltaY[leftFacing];
          side := 0;
          horizontalOffset := -6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wallX, wallY, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[3] + horizontalOffset, GDConsts.viewSliceTable.yRow[3],
                                   wallFront, 3);
            wallSide := View3D.GetWallType(wallX, wallY, leftFacing);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[4] + horizontalOffset, GDConsts.viewSliceTable.yRow[4],
                                   wallSide, 4);
            Inc(side);
            Inc(horizontalOffset, 3);
            wallX := wallX + GDConsts.dirDeltaX[rightFacing];
            wallY := wallY + GDConsts.dirDeltaY[rightFacing];
          end;
          wallX := currentX + GDConsts.dirDeltaX[rightFacing];
          wallX := wallX + GDConsts.dirDeltaX[rightFacing];
          wallY := currentY + GDConsts.dirDeltaY[rightFacing];
          wallY := wallY + GDConsts.dirDeltaY[rightFacing];
          side := 0;
          horizontalOffset := 6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wallX, wallY, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[3] + horizontalOffset, GDConsts.viewSliceTable.yRow[3],
                                   wallFront, 3);
            wallSide := View3D.GetWallType(wallX, wallY, rightFacing);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[5] + horizontalOffset, GDConsts.viewSliceTable.yRow[5],
                                   wallSide, 5);
            Inc(side);
            Dec(horizontalOffset, 3);
            wallX := wallX + GDConsts.dirDeltaX[leftFacing];
            wallY := wallY + GDConsts.dirDeltaY[leftFacing];
          end;
        end;
        0: begin
          wallX := currentX + GDConsts.dirDeltaX[leftFacing];
          wallY := currentY + GDConsts.dirDeltaY[leftFacing];
          side := 0;
          horizontalOffset := -7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wallX, wallY, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[6] + horizontalOffset, GDConsts.viewSliceTable.yRow[6],
                                   wallFront, 6);
            wallSide := View3D.GetWallType(wallX, wallY, leftFacing);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[7] + horizontalOffset, GDConsts.viewSliceTable.yRow[7],
                                   wallSide, 7);
            Inc(side);
            Inc(horizontalOffset, 7);
            wallX := wallX + GDConsts.dirDeltaX[rightFacing];
            wallY := wallY + GDConsts.dirDeltaY[rightFacing];
          end;
          wallX := currentX + GDConsts.dirDeltaX[rightFacing];
          wallY := currentY + GDConsts.dirDeltaY[rightFacing];
          side := 0;
          horizontalOffset := 7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wallX, wallY, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[6] + horizontalOffset, GDConsts.viewSliceTable.yRow[6],
                                   wallFront, 6);
            wallSide := View3D.GetWallType(wallX, wallY, rightFacing);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSliceTable.xCol[8] + horizontalOffset, GDConsts.viewSliceTable.yRow[8],
                                   wallSide, 8);
            Inc(side);
            Dec(horizontalOffset, 7);
            wallX := wallX + GDConsts.dirDeltaX[leftFacing];
            wallY := wallY + GDConsts.dirDeltaY[leftFacing];
          end;
        end;
      end;
      currentX := currentX + GDConsts.dirDeltaX[reverseFacing];
      currentY := currentY + GDConsts.dirDeltaY[reverseFacing];
      Dec(distance);
    until distance = 255;
    Blit.FlushView;
  end;
end;

procedure LoadWallSet(fileId, wallSetSlot: Byte);
var
  bytesRead: Word;
  archiveData: Types.PBytes;
  dataOffset: Word;
  horizontalOffset: Word;
  rowIndex: Byte;
  blockIndex: Word;
  columnIndex: Integer;
  blockCount: Byte;
  diskSuffix: String[1];
  { Unused in this version; see the other implementations of this routine. }
  discardedKey: Char;
begin
  if (wallSetSlot < 1) or (wallSetSlot > 3) then Exit;
  Str(GDVars.currentDisk, diskSuffix);
  DaxIo.LoadDax('WALLDEF' + diskSuffix, '.dax', fileId, bytesRead, archiveData);
  if (bytesRead = 0) or (bytesRead div SizeOf(Types.TWallDef) + wallSetSlot > 4) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load ', fileId, ' from WALLDEF' + diskSuffix + '.');
    discardedKey := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  horizontalOffset := GDConsts.symSetFirst[wallSetSlot] - GDConsts.symSetFirst[1];
  dataOffset := 0;
  blockIndex := 1;
  repeat
    Move(archiveData^[dataOffset], GDVars.wallGfx^.defs[wallSetSlot + blockIndex - 1], SizeOf(Types.TWallDef));
    Inc(dataOffset, SizeOf(Types.TWallDef));
    Inc(blockIndex);
  until dataOffset >= bytesRead;
  FreeMem(archiveData, bytesRead);
  blockCount := blockIndex - 1;
  for blockIndex := 1 to blockCount do
    if (wallSetSlot + blockIndex - 1) in [1..3] then begin
      GDVars.wallSlots[wallSetSlot + blockIndex - 1].id := -1;
      GDVars.wallSlots[wallSetSlot + blockIndex - 1].slot := -1;
      for rowIndex := 1 to 5 do
        for columnIndex := 0 to 155 do begin
          if GDVars.wallGfx^.defs[wallSetSlot + blockIndex - 1][rowIndex][columnIndex] >= GDConsts.symSetLast[0] then
            Inc(GDVars.wallGfx^.defs[wallSetSlot + blockIndex - 1][rowIndex][columnIndex], horizontalOffset);
        end;
      if blockCount > 1 then
        Sym8x8.Load8x8Set(fileId * 10 + blockIndex, wallSetSlot + blockIndex - 1)
      else
        Sym8x8.Load8x8Set(fileId, wallSetSlot + blockIndex - 1);
    end;
  GDVars.wallSlots[wallSetSlot].id := fileId;
  GDVars.wallSlots[wallSetSlot].slot := wallSetSlot;
end;

procedure Load3DMap(mapId: Byte);
var
  bytesRead: Word;
  archiveData: Types.PBytes;
  dataOffset: Word;
  diskSuffix: String[1];
  { Unused in this version; see the other implementations of this routine. }
  discardedKey: Char;
begin
  Str(GDVars.currentDisk, diskSuffix);
  DaxIo.LoadDax('GEO' + diskSuffix, '.dax', mapId, bytesRead, archiveData);
  if (bytesRead = 0) or (bytesRead <> 1026) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load geo in Load3DMap.');
    discardedKey := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  dataOffset := 2;
  Move(archiveData^[dataOffset], GDVars.geo^.wallsNE, SizeOf(GDVars.geo^.wallsNE));
  Inc(dataOffset, SizeOf(Types.TGeoPlane));
  Move(archiveData^[dataOffset], GDVars.geo^.wallsSW, SizeOf(GDVars.geo^.wallsSW));
  Inc(dataOffset, SizeOf(Types.TGeoPlane));
  Move(archiveData^[dataOffset], GDVars.geo^.events, SizeOf(GDVars.geo^.events));
  Inc(dataOffset, SizeOf(Types.TGeoPlane));
  Move(archiveData^[dataOffset], GDVars.geo^.barriers, SizeOf(GDVars.geo^.barriers));
  FreeMem(archiveData, bytesRead);
  GDVars.zone0^.vars[C_Gbvm.GEO_MAP_ID] := mapId;
end;

begin
end.
