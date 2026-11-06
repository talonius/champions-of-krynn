{ Combat-map viewport, creature placement and downed-creature bookkeeping. }
{$O+,F+}
unit CbtMap;

interface

uses Types, Blit, TextRend, SoundDrv, Crt, MapTiles, Debug, GDConsts, GDVars, C_Ifc, C_Terr, C_Status;

{ Finds where one tile of a creature icon lies relative to the icon's upper-left cell.
  @param(iconSize The icon size; 0 for no icon.)
  @param(tileIndex The tile, 0 to 3.)
  @param(deltaX Receives the tile's column offset; left as it was for size 0.)
  @param(deltaY Receives the tile's row offset; left as it was for size 0.)
  @returns(True when the icon uses the tile; False for size 0 or an unused tile, whose column offset is negative.) }
function GetIconTileDelta(iconSize, tileIndex: Byte; var deltaX, deltaY: ShortInt): Boolean;

{ Empty: the palette is left as it is for combat. }
procedure SetCombatPalette;

{ Empty: the palette is left as it is after combat. }
procedure SetNoncombatPalette;

{ Redraws one arena cell: repaints its terrain (the whole icon footprint when a creature stands there, through
  UpdateCombatMapTile), then the creature's sprite if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuilds the arena's creature-index grid: clears it, then for each creature with a nonzero icon size marks every cell
  its icon covers with the creature's combat slot and recomputes the creature's view coordinates. }
procedure BuildArenaArrays;

{ Looks up what lies on an arena cell.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(creatureIndex Receives the combat slot of the creature standing there; 0 for none or outside the arena.)
  @param(terrainIndex Receives the cell's terrain; 0 outside the arena.) }
procedure GetArenaContents(x, y: ShortInt; var creatureIndex, terrainIndex: Byte);

{ Repaints the terrain under each visible tile of a creature's icon, erasing its sprite, or under the single view cell
  when no creature is there.
  @param(x View column of the cell; the creature's own view column replaces it.)
  @param(y View row of the cell; the creature's own view row replaces it.)
  @param(creatureIndex The creature's combat slot, or 0 to look up the creature standing on the cell.) }
procedure UpdateCombatMapTile(x, y: ShortInt; creatureIndex: Byte);

{ Tells whether a view cell lies inside the 7x7 view.
  @param(x View column.)
  @param(y View row.)
  @returns(True when both coordinates lie inside the view.) }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Tests whether a creature's icon is visible in the view.
  @param(creature The creature.)
  @param(requireWholeIcon Nonzero to require each tile of the icon in view, 0 to require one.)
  @returns(True when the icon is visible; False when the creature has no icon.) }
function CombatIconVisible(creature: Types.PCharRecord; requireWholeIcon: Byte): Boolean;

{ Targets the arena cell one step in direction from a cell and redraws the whole view if needed (BuildViewBuffer),
  redrawing each visible icon of a creature in play or exploded after a full redraw. Then redraws the cell, draws the
  cursor at the target (kept inside the arena) and flushes the view.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(delta How far the target may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(direction Direction of the target, 0 to 7; 8 for the cell itself.) }
procedure ScrollView(x, y: ShortInt; delta, direction: Byte);

{ Turns a creature. While the combat map shows, it scrolls the creature into view unless it is wholly visible, and
  repaints its terrain when the facing crosses between 0 to 3 and 4 to 7 (the mirrored sprites) or `animationFrame` or
  `eraseOnly` is nonzero. It stores the new facing and, unless `eraseOnly` is set, draws its sprite and flushes when it
  is visible and the map shows.
  @param(creature The creature.)
  @param(direction The new facing, 0 to 7.)
  @param(animationFrame The animation frame to draw.)
  @param(eraseOnly Nonzero to erase the sprite without drawing it again.) }
procedure SetCreatureFacing(creature: Types.PCharRecord; direction, animationFrame, eraseOnly: Byte);

{ Finds a creature's arena column.
  @param(creature The creature.)
  @returns(The column of its icon's upper-left cell.) }
function CombatCellX(creature: Types.PCharRecord): ShortInt;

{ Finds a creature's arena row.
  @param(creature The creature.)
  @returns(The row of its icon's upper-left cell.) }
function CombatCellY(creature: Types.PCharRecord): ShortInt;

{ Finds a creature's icon size in the arena.
  @param(creature The creature.)
  @returns(The icon size; 0 when it has no icon.) }
function GetIconSize(creature: Types.PCharRecord): Byte;

{ Finds a combatant's combat slot. Note: with no combatants, or more than 72, the search runs past the end of the table.
  @param(creature The combatant.)
  @returns(The slot, or 0 if it is not in the fight.) }
function CombatSlot(creature: Types.PCharRecord): Byte;

{ Probes the cells one step in direction from each of the creature's icon tiles.
  @param(creature The creature.)
  @param(direction The direction, 0 to 7; 8 probes the creature's own cells.)
  @param(creatureIndex Receives an adjacent creature's combat slot (0 for none); the creature itself is ignored and the
    last one found wins.)
  @param(terrainIndex Receives the dominant terrain: 0 (off the arena) beats everything, otherwise the highest cost wins
    (the later tile on a tie), starting from terrain 23 at cost 1. Stinking clouds and acid pools do not compete.)
  @param(adjacentCorpse Receives 1 when a probed cell holds a stinking cloud, else 0.)
  @param(adjacentWater Receives 1 when a probed cell holds an acid pool, else 0.) }
procedure ProbeDirection(creature: Types.PCharRecord; direction: Byte; var creatureIndex, terrainIndex, adjacentCorpse,
                         adjacentWater: Byte);

{ Handles a creature going down. Outside combat it plays the downed sound and pauses. In combat it scrolls the creature
  wholly into view, flashes the skull sprite over it, records a body for the party side (nonPartyMember = 0) and marks
  its cell as a corpse (unless the cell holds a stinking cloud), removes the icon, refreshes the view's center cell
  (ScrollView), and clears the creature's initiative, movement, casting and guarding. Note: the check for an already
  recorded body tests downedCreatures[animationFrame] with animationFrame not yet set, so it finds one only when that
  entry happens to hold the creature.
  @param(creature The creature that went down.) }
procedure CreatureDowned(creature: Types.PCharRecord);

{ Places a creature on an arena cell if it fits. Outside combat it does nothing. In combat it places the creature at the
  cell, probes its own cells and rejects the place, zeroing the icon size, on any creature, terrain 0 or impassable
  terrain. On success with `moving` set, for a party member it clears the creature's body entries and, unless another
  body lies on the cell, writes into it the terrain its last body covered, or the probed terrain when it has no body
  entry or the body covered a corpse cell. The creature grid is then refilled.
  @param(creature The creature.)
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(moving True when the creature moves there, so its bodies are cleared.)
  @returns(True outside combat or when the creature fits.) }
function IsValidCreatureLoc(creature: Types.PCharRecord; x, y: Byte; moving: Boolean): Boolean;

{ Scrolls the view to the creature (ScrollView toward its own cell) when the combat map shows, drawing the cursor over
  its icon footprint when `cursor` is set; afterwards the cursor is off with size 1.
  @param(creature The creature.)
  @param(delta How far it may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(cursor True to draw the cursor.) }
procedure DisplayMapViewCentered(creature: Types.PCharRecord; delta: Byte; cursor: Boolean);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCbtMap;

implementation

const
  { iconAnims row holding the two corpse ("skull") frames }
  DOWNED_ANIMATION = 24;

procedure PrimeCbtMap;
begin
  MapTiles.PrimeMapTiles;
  Debug.PrimeDebug;
end;

function GetIconTileDelta(iconSize, tileIndex: Byte; var deltaX, deltaY: ShortInt): Boolean;
begin
  GetIconTileDelta := False;
  if iconSize = 0 then Exit;
  deltaX := GDConsts.iconDelta[iconSize, tileIndex].deltaX;
  deltaY := GDConsts.iconDelta[iconSize, tileIndex].deltaY;
  if deltaX >= 0 then
    GetIconTileDelta := True;
end;

{ Recomputes each arena creature's view coordinates from its arena cell and the view's upper-left cell. }
procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.arenaCount do begin
    GDVars.gridX[i] := GDVars.arenaLoc[i].x - GDVars.arena^.originX;
    GDVars.gridY[i] := GDVars.arenaLoc[i].y - GDVars.arena^.originY;
  end;
end;

procedure SetCombatPalette;
begin
end;

procedure SetNoncombatPalette;
begin
end;

{ Repaints the terrain under the cursor's footprint at an arena cell, draws the cursor there when it is on, then redraws
  the creature standing on the cell if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure DrawCursorCell(x, y: ShortInt);
var
  viewX: ShortInt;
  viewY: ShortInt;
  tileDeltaX: ShortInt;
  tileDeltaY: ShortInt;
  i: Byte;
  c: Byte;
  t: Byte;
begin
  viewX := x - GDVars.arena^.originX;
  viewY := y - GDVars.arena^.originY;
  for i := 0 to 3 do
    if CbtMap.GetIconTileDelta(GDVars.arena^.cursorSize, i, tileDeltaX, tileDeltaY) then
      if CbtMap.ViewCoordsValid(viewX + tileDeltaX, viewY + tileDeltaY) then begin
        MapTiles.Copy2DTile((viewX + tileDeltaX) * 3, (viewY + tileDeltaY) * 3,
                   GDConsts.terrainInfo[GDVars.arena^.cells[y + tileDeltaY, x + tileDeltaX]].tileId, 0);
        if GDVars.arena^.cursorOn then
          MapTiles.DrawIconAnimSprite(viewX + tileDeltaX, viewY + tileDeltaY, 0, 0, 25);
      end;
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatureArr[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.creatureArr[c]^.combatAddr^.facing, 0,
                         GDVars.creatureArr[c]^.orderNumber);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  viewX: ShortInt;
  viewY: ShortInt;
  c: Byte;
  t: Byte;
begin
  viewX := x - GDVars.arena^.originX;
  viewY := y - GDVars.arena^.originY;
  CbtMap.UpdateCombatMapTile(viewX, viewY, 0);
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatureArr[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.creatureArr[c]^.combatAddr^.facing, 0,
                         GDVars.creatureArr[c]^.orderNumber);
end;

procedure BuildArenaArrays;
var
  i: Byte;
  j: Byte;
  tileDeltaX: ShortInt;
  tileDeltaY: ShortInt;
begin
  FillChar(GDVars.creatureIndexGrid, SizeOf(GDVars.creatureIndexGrid), 0);
  for i := 1 to GDVars.arenaCount do begin
    if GDVars.arenaLoc[i].size > 0 then begin
      for j := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaLoc[i].size, j, tileDeltaX, tileDeltaY) then
          GDVars.creatureIndexGrid[GDVars.arenaLoc[i].y + tileDeltaY, GDVars.arenaLoc[i].x + tileDeltaX] := i;
      GDVars.gridX[i] := GDVars.arenaLoc[i].x - GDVars.arena^.originX;
      GDVars.gridY[i] := GDVars.arenaLoc[i].y - GDVars.arena^.originY;
    end;
  end;
end;

procedure GetArenaContents(x, y: ShortInt; var creatureIndex, terrainIndex: Byte);
begin
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then begin
    terrainIndex := GDVars.arena^.cells[y, x];
    creatureIndex := GDVars.creatureIndexGrid[y, x];
  end else begin
    creatureIndex := 0;
    terrainIndex := 0;
  end;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; creatureIndex: Byte);
var
  arenaX: ShortInt;
  arenaY: ShortInt;
  tileDeltaX: ShortInt;
  tileDeltaY: ShortInt;
  i: Byte;
  t: Byte;
  iconSize: Byte;
begin
  if creatureIndex = 0 then begin
    arenaX := x + GDVars.arena^.originX;
    arenaY := y + GDVars.arena^.originY;
    CbtMap.GetArenaContents(arenaX, arenaY, creatureIndex, t);
  end;
  if creatureIndex > 0 then begin
    x := GDVars.gridX[creatureIndex];
    y := GDVars.gridY[creatureIndex];
    arenaX := x + GDVars.arena^.originX;
    arenaY := y + GDVars.arena^.originY;
    iconSize := GDVars.arenaLoc[creatureIndex].size;
    for i := 0 to 3 do
      if CbtMap.GetIconTileDelta(iconSize, i, tileDeltaX, tileDeltaY) then
        if CbtMap.ViewCoordsValid(x + tileDeltaX, y + tileDeltaY) then
          MapTiles.Copy2DTile((x + tileDeltaX) * 3, (y + tileDeltaY) * 3,
                     GDConsts.terrainInfo[GDVars.arena^.cells[arenaY + tileDeltaY, arenaX + tileDeltaX]].tileId, 0);
  end else if CbtMap.ViewCoordsValid(x, y) then
    MapTiles.Copy2DTile(x * 3, y * 3, GDConsts.terrainInfo[GDVars.arena^.cells[arenaY, arenaX]].tileId, 0);
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(creature: Types.PCharRecord; requireWholeIcon: Byte): Boolean;
var
  i: Byte;
  creatureSlot: Byte;
  tileDeltaX: ShortInt;
  tileDeltaY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  visibleTiles: Integer;
begin
  CombatIconVisible := True;
  creatureSlot := CbtMap.CombatSlot(creature);
  if GDVars.arenaLoc[creatureSlot].size = 0 then
    CombatIconVisible := False
  else
    for i := 0 to 3 do begin
      if CbtMap.GetIconTileDelta(GDVars.arenaLoc[creatureSlot].size, i, tileDeltaX, tileDeltaY) then
        if not CbtMap.ViewCoordsValid(GDVars.gridX[creatureSlot] + tileDeltaX,
                               GDVars.gridY[creatureSlot] + tileDeltaY) then begin
          CombatIconVisible := False;
          if requireWholeIcon <> 0 then Exit;
        end else begin
          CombatIconVisible := True;
          if requireWholeIcon = 0 then Exit;
        end;
    end;
end;

{ Recenters the 7x7 view on a target cell when it lies farther from the view center than allowed, keeping the view
  inside the arena, then draws the view's terrain and recomputes the creatures' view coordinates.
  @param(x Arena column of the target.)
  @param(y Arena row of the target.)
  @param(delta How far the target may lie from the view center; 255 forces a redraw.)
  @returns(True when the view was redrawn.) }
function BuildViewBuffer(x, y: ShortInt; delta: Byte): Boolean;
var
  d: Byte;
  pixelX: ShortInt;
  pixelY: ShortInt;
  i: Byte;
  j: Byte;
  centerX: ShortInt;
  centerY: ShortInt;
  minimumX: ShortInt;
  maximumX: ShortInt;
  minimumY: ShortInt;
  maximumY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  viewOffset: Integer;
begin
  BuildViewBuffer := False;
  centerX := GDVars.arena^.originX + 3;
  centerY := GDVars.arena^.originY + 3;
  d := delta;
  if delta = 255 then
    d := 0;
  minimumX := centerX - d;
  maximumX := centerX + d;
  minimumY := centerY - d;
  maximumY := centerY + d;
  if (delta <> 255) and (x >= minimumX) and (x <= maximumX)
     and (y >= minimumY) and (y <= maximumY) then Exit;
  if x < minimumX then
    while (x < centerX) and (centerX > 3) do Dec(centerX)
  else if x > maximumX then
    while (x > centerX) and (centerX < 49 - 3) do Inc(centerX);
  if y < minimumY then
    while (y < centerY) and (centerY > 3) do Dec(centerY)
  else if y > maximumY then
    while (y > centerY) and (centerY < 24 - 3) do Inc(centerY);
  GDVars.arena^.originX := centerX - 3;
  GDVars.arena^.originY := centerY - 3;
  pixelY := 0;
  centerY := GDVars.arena^.originY;
  for j := 0 to 6 do begin
    pixelX := 0;
    centerX := GDVars.arena^.originX;
    for i := 0 to 6 do begin
      MapTiles.Copy2DTile(pixelX, pixelY, GDConsts.terrainInfo[GDVars.arena^.cells[centerY, centerX]].tileId, 0);
      Inc(pixelX, 3);
      Inc(centerX);
    end;
    Inc(pixelY, 3);
    Inc(centerY);
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True;
end;

procedure ScrollView(x, y: ShortInt; delta, direction: Byte);
var
  p: Types.PCharRecord;
  i: Byte;
  targetX: ShortInt;
  targetY: ShortInt;
begin
  targetX := x + GDConsts.dirDeltaX[direction];
  targetY := y + GDConsts.dirDeltaY[direction];
  if CbtMap.BuildViewBuffer(targetX, targetY, delta) then begin
    for i := 1 to GDVars.arenaCount do begin
      p := GDVars.creatureArr[i];
      if ((p^.status = C_Status.EXPLODED) or (p^.inPlay <> 0)) and (GDVars.arenaLoc[i].size > 0) then
        if CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(GDVars.gridX[i], GDVars.gridY[i], p^.combatAddr^.facing, 0, p^.orderNumber);
    end;
  end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(targetX - GDVars.arena^.originX, targetY - GDVars.arena^.originY) then begin
    if targetX > 49 then targetX := 49;
    if targetX < 0 then targetX := 0;
    if targetY > 24 then targetY := 24;
    if targetY < 0 then targetY := 0;
  end;
  CbtMap.DrawCursorCell(targetX, targetY);
  Blit.FlushView;
end;

procedure SetCreatureFacing(creature: Types.PCharRecord; direction, animationFrame, eraseOnly: Byte);
var
  creatureSlot: Byte;
begin
  creatureSlot := CbtMap.CombatSlot(creature);
  if not CbtMap.CombatIconVisible(creature, 1) then
    if GDVars.gfxEnabled <> 0 then
      CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 3, 8);
  if (creature^.combatAddr^.facing div 4 <> direction div 4)
     or (animationFrame <> 0) or (eraseOnly <> 0) then
    if GDVars.gfxEnabled <> 0 then
      CbtMap.UpdateCombatMapTile(0, 0, creatureSlot);
  creature^.combatAddr^.facing := direction;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(creature, 0) then
      if GDVars.gfxEnabled <> 0 then begin
        MapTiles.DrawIconAnimSprite(GDVars.gridX[creatureSlot], GDVars.gridY[creatureSlot], direction,
                                    animationFrame, creature^.orderNumber);
        Blit.FlushView;
      end;
end;

function CombatCellX(creature: Types.PCharRecord): ShortInt;
begin
  CombatCellX := GDVars.arenaLoc[CbtMap.CombatSlot(creature)].x;
end;

function CombatCellY(creature: Types.PCharRecord): ShortInt;
begin
  CombatCellY := GDVars.arenaLoc[CbtMap.CombatSlot(creature)].y;
end;

function GetIconSize(creature: Types.PCharRecord): Byte;
begin
  GetIconSize := GDVars.arenaLoc[CbtMap.CombatSlot(creature)].size;
end;

function CombatSlot(creature: Types.PCharRecord): Byte;
var
  found: Boolean;
  i: Byte;
begin
  found := False;
  CombatSlot := 0;
  i := 0;
  repeat
    Inc(i);
    if GDVars.creatureArr[i] = creature then
      found := True;
  until found or (i = GDVars.arenaCount);
  if found then
    CombatSlot := i;
end;

procedure ProbeDirection(creature: Types.PCharRecord; direction: Byte; var creatureIndex, terrainIndex, adjacentCorpse,
                         adjacentWater: Byte);
var
  i: Byte;
  creatureSlot: Byte;
  c: Byte;
  t: Byte;
  highestCost: Byte;
  nextX: ShortInt;
  nextY: ShortInt;
  x: ShortInt;
  y: ShortInt;
  tileDeltaX: ShortInt;
  tileDeltaY: ShortInt;
begin
  creatureIndex := 0;
  terrainIndex := 23;
  highestCost := 1;
  adjacentCorpse := 0;
  adjacentWater := 0;
  creatureSlot := CbtMap.CombatSlot(creature);
  x := GDVars.arenaLoc[creatureSlot].x;
  y := GDVars.arenaLoc[creatureSlot].y;
  for i := 0 to 3 do begin
    if CbtMap.GetIconTileDelta(GDVars.arenaLoc[creatureSlot].size, i, tileDeltaX, tileDeltaY) then begin
      nextX := x + tileDeltaX + GDConsts.dirDeltaX[direction];
      nextY := y + tileDeltaY + GDConsts.dirDeltaY[direction];
      CbtMap.GetArenaContents(nextX, nextY, c, t);
      if c = creatureSlot then
        c := 0;
      if c > 0 then
        creatureIndex := c;
      if (t = 0) or (terrainIndex = 0) then
        terrainIndex := 0
      else
        case t of
          C_Terr.TERRAIN_STINKING_CLOUD: adjacentCorpse := 1;
          C_Terr.TERRAIN_ACID_POOL: adjacentWater := 1;
        else
          if GDConsts.terrainInfo[t].movementCost >= highestCost then begin
            highestCost := GDConsts.terrainInfo[t].movementCost;
            terrainIndex := t;
          end;
        end;
    end;
  end;
end;

procedure CreatureDowned(creature: Types.PCharRecord);
var
  creatureSlot: Byte;
  k: Byte;
  { also indexes the duplicate check, before it is set }
  animationFrame: Byte;
  tileDeltaX: ShortInt;
  tileDeltaY: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bodyCell: array[0..2] of Byte;
begin
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
    SoundDrv.SoundCommand(GDConsts.soundIds[1]);
    TextRend.pauseOnly;
  end else begin
    k := 1;
    while (k < 9) and (GDVars.downedCreatures[animationFrame].creature <> creature) do
      Inc(k);
    if k < 9 then Exit;
    creatureSlot := CbtMap.CombatSlot(creature);
    cellX := CbtMap.CombatCellX(creature);
    cellY := CbtMap.CombatCellY(creature);
    if not CbtMap.CombatIconVisible(creature, 1) then
      CbtMap.ScrollView(cellX, cellY, 3, 8);
    CbtMap.UpdateCombatMapTile(0, 0, creatureSlot);
    SoundDrv.SoundCommand(GDConsts.soundIds[1]);
    for animationFrame := 0 to 8 do begin
      for k := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaLoc[creatureSlot].size, k, tileDeltaX, tileDeltaY) then
          if CbtMap.ViewCoordsValid(GDVars.gridX[creatureSlot] + tileDeltaX,
                                    GDVars.gridY[creatureSlot] + tileDeltaY) then
            Blit.BlitTileClipped((GDVars.gridX[creatureSlot] + tileDeltaX) * 3,
                            (GDVars.gridY[creatureSlot] + tileDeltaY) * 3, 0, 5,
                            GDVars.iconAnims[CbtMap.DOWNED_ANIMATION, animationFrame mod 2], GDVars.egaDest);
      Blit.FlushView;
      Delay(10);
    end;
    if creature^.combatAddr^.nonPartyMember = 0 then begin
      Inc(GDVars.downedCount);
      GDVars.downedCreatures[GDVars.downedCount].terrain := GDVars.arena^.cells[cellY, cellX];
      if GDVars.arena^.cells[cellY, cellX] <> C_Terr.TERRAIN_STINKING_CLOUD then
        GDVars.arena^.cells[cellY, cellX] := C_Terr.TERRAIN_CORPSE;
      GDVars.downedCreatures[GDVars.downedCount].creature := creature;
      GDVars.downedCreatures[GDVars.downedCount].x := cellX;
      GDVars.downedCreatures[GDVars.downedCount].y := cellY;
    end;
    TextRend.pauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, creatureSlot);
    GDVars.arenaLoc[CbtMap.CombatSlot(creature)].size := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GDVars.arena^.originX + 3, GDVars.arena^.originY + 3, 3, 8);
    creature^.combatAddr^.initiative := 0;
    creature^.combatAddr^.movement := 0;
    creature^.combatAddr^.spellCast := 0;
    creature^.combatAddr^.guarding := 0;
  end;
end;

function IsValidCreatureLoc(creature: Types.PCharRecord; x, y: Byte; moving: Boolean): Boolean;
var
  creatureSlot: Byte;
  i: Byte;
  c: Byte;
  t: Byte;
  found: Boolean;
  adjacentCorpse: Byte;
  adjacentWater: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    creatureSlot := CbtMap.CombatSlot(creature);
    GDVars.arenaLoc[creatureSlot].size := creature^.iconDimensions and $7F;
    GDVars.arenaLoc[creatureSlot].x := x;
    GDVars.arenaLoc[creatureSlot].y := y;
    CbtMap.ProbeDirection(creature, 8, c, t, adjacentCorpse, adjacentWater);
    if (c <> 0) or (t = 0) or (GDConsts.terrainInfo[t].movementCost = C_Terr.TERRAIN_IMPASSABLE) then
      GDVars.arenaLoc[creatureSlot].size := 0
    else begin
      IsValidCreatureLoc := True;
      if moving then
        if creature^.combatAddr^.nonPartyMember = 0 then begin
          for i := 1 to GDVars.downedCount do
            if GDVars.downedCreatures[i].creature = creature then begin
              if GDVars.downedCreatures[i].terrain <> C_Terr.TERRAIN_CORPSE then
                t := GDVars.downedCreatures[i].terrain;
              FillChar(GDVars.downedCreatures[i], SizeOf(GDVars.downedCreatures[i]), 0);
            end;
          found := False;
          for i := 1 to GDVars.downedCount do
            if (GDVars.downedCreatures[i].creature <> nil) and (GDVars.downedCreatures[i].x = x)
               and (GDVars.downedCreatures[i].y = y) then
              found := True;
          if not found then
            GDVars.arena^.cells[y, x] := t;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(creature: Types.PCharRecord; delta: Byte; cursor: Boolean);
begin
  GDVars.arena^.cursorOn := cursor;
  GDVars.arena^.cursorSize := GDVars.arenaLoc[CbtMap.CombatSlot(creature)].size;
  if GDVars.gfxEnabled <> 0 then
    CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), delta, 8);
  GDVars.arena^.cursorOn := False;
  GDVars.arena^.cursorSize := 1;
end;

begin
end.
