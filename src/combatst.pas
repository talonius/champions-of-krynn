{ Combat setup: builds the arena, initializes combat records, places all creatures, and raises the combat interface. }
{$O+,F+}
unit CombatSt;

interface

{ Sets up a battle: frees the big animation, the portraits and the big picture, shows "A battle begins...", resets the
  combat state (magic off, a 15-round limit, empty cloud, acid pool, downed and bank lists), loads the combat tiles and
  builds the arena, creates the creatures' combat records and places every creature, allocates the combat view picture,
  centers the view on the party's leader and draws the combat interface. Each creature's turnings are reset and its
  condition-8 and condition-22 effects fire; the hostiles' hit-point percentage is figured, and the interface state
  becomes combat. }
procedure CombatStart;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCombatSt;

implementation

uses Types, Blit, TextRend, GameIo, CbtActs, SaveLoad, CharGen, ViewChar, FxEngine, CharHlp, MenuCore, Portrait, View3D,
  Pathing, CbtMap, MapTiles, Debug, Crt, GDConsts, GDVars, C_Side, C_Npc, C_Terr, C_Ifc, C_Status, C_Dir;

const
  WALL_OPEN = 0;
  WALL_SOLID = 1;
  WALL_DOOR = 3;

procedure PrimeCombatSt;
begin
  ViewChar.PrimeViewChar;
  Pathing.PrimePathing;
  View3D.PrimeView3D;
  CbtMap.PrimeCbtMap;
  SaveLoad.PrimeSaveLoad;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  FxEngine.PrimeFxEngine;
  CbtActs.PrimeCbtActs;
  MapTiles.PrimeMapTiles;
  CharGen.PrimeCharGen;
  Debug.PrimeDebug;
  Portrait.PrimePortrait;
end;

{ Sets one arena cell in the current dungeon cell's skewed six-by-five block, ignoring cells off the 50x25 arena.
  @param(columnOffset Column within the block.)
  @param(rowOffset Row within the block.)
  @param(terrainId The terrain, stored plus 1.) }
procedure PlotCell(columnOffset, rowOffset, terrainId: Byte);
var
  xCoordinate: ShortInt;
  yCoordinate: ShortInt;
begin
  xCoordinate := GDVars.mapOffsetX * 6 + GDVars.mapOffsetY * 5 + 21 + columnOffset;
  yCoordinate := GDVars.mapOffsetY * 5 + 10 + rowOffset;
  if (xCoordinate >= 0) and (xCoordinate <= 49) and (yCoordinate >= 0) and (yCoordinate <= 24) then
    GDVars.arena^.cells[yCoordinate, xCoordinate] := terrainId + 1;
end;

{ Decorates the current dungeon cell's floor. It records whether the cell is enclosed: at least one solid wall, no door,
  and no opposed pair of solid walls unless all four are solid. When the caller's map-event decoration flag is set and
  the cell is enclosed, each of its six middle spots that is open floor (terrain 22) has an even chance of becoming
  terrain 26, and each open-floor spot beside such a spot a nine in ten chance of becoming terrain 27. }
procedure DecorateCell;
var
  columnOffset: ShortInt;
  rowOffset: ShortInt;
  xCoordinate: ShortInt;
  yCoordinate: ShortInt;
  neighborX: ShortInt;
  neighborY: ShortInt;
  index: Byte;
begin
  GDVars.corridorOk := ((GDVars.northWall = CombatSt.WALL_SOLID) or (GDVars.eastWall = CombatSt.WALL_SOLID) or
                 (GDVars.southWall = CombatSt.WALL_SOLID) or (GDVars.westWall = CombatSt.WALL_SOLID)) and
    ((GDVars.northWall <> CombatSt.WALL_SOLID) or (GDVars.southWall <> CombatSt.WALL_SOLID) or
     ((GDVars.eastWall = CombatSt.WALL_SOLID) and (GDVars.westWall = CombatSt.WALL_SOLID))) and
    ((GDVars.eastWall <> CombatSt.WALL_SOLID) or (GDVars.westWall <> CombatSt.WALL_SOLID) or
     ((GDVars.northWall = CombatSt.WALL_SOLID) and (GDVars.southWall = CombatSt.WALL_SOLID))) and
    (GDVars.northWall <> CombatSt.WALL_DOOR) and (GDVars.eastWall <> CombatSt.WALL_DOOR) and
        (GDVars.southWall <> CombatSt.WALL_DOOR) and
    (GDVars.westWall <> CombatSt.WALL_DOOR);
  for columnOffset := 2 to 3 do
    for rowOffset := 2 to 4 do begin
      xCoordinate := GDVars.mapOffsetX * 6 + GDVars.mapOffsetY * 5 + 21 + columnOffset + rowOffset;
      yCoordinate := GDVars.mapOffsetY * 5 + 10 + rowOffset;
      if (xCoordinate >= 0) and (xCoordinate <= 49) and (yCoordinate >= 0) and (yCoordinate <= 24) and
          (GDConsts.terrainInfo[GDVars.arena^.cells[yCoordinate,
                                    xCoordinate]].tileId = 22) and (GDVars.mapEventFlag <> 0) and GDVars.corridorOk and
          (FxEngine.RollDice(1, 10) <= 5) then begin
        GDVars.arena^.cells[yCoordinate, xCoordinate] := 26;
        for index := 1 to 4 do begin
          neighborX := GDConsts.ringStepX[index] + xCoordinate;
          neighborY := GDConsts.ringStepY[index] + yCoordinate;
          if (neighborX >= 0) and (neighborX <= 49) and (neighborY >= 0) and (neighborY <= 24) and
              (GDConsts.terrainInfo[GDVars.arena^.cells[neighborY, neighborX]].tileId = 22) and
              (FxEngine.RollDice(1, 10) <= 9) then
            GDVars.arena^.cells[neighborY, neighborX] := 27;
        end;
      end;
    end;
end;

{ Classifies the edge between a map cell and its neighbor in a direction, from both sides. Off the map it is open on the
  party's row going east or west, otherwise blocked.
  @param(xCoordinate Map column.)
  @param(yCoordinate Map row.)
  @param(direction Direction of the neighbor.)
  @returns(0 open, 1 blocked, 3 a wall that can be passed; the two sides' bits combined.) }
function WallBetween(xCoordinate, yCoordinate: ShortInt; direction: Byte): Byte;
var
  nearWallKind: Byte;
  farWallKind: Byte;
  oppositeDirection: Byte;

  { Classifies one side of a cell; off the map, east and west on the party's row are open, all else solid. }
  function GetWallKind(probeX, probeY: ShortInt; probeDirection: Byte): Byte;
  begin
    if (probeX >= 0) and (probeX <= 15) and (probeY >= 0) and (probeY <= 15) then begin
      if View3D.GetBarrierType(probeX, probeY, probeDirection) = 0 then
        GetWallKind := CombatSt.WALL_SOLID
      else if View3D.GetWallType(probeX, probeY, probeDirection) = 0 then
        GetWallKind := CombatSt.WALL_OPEN
      else
        GetWallKind := CombatSt.WALL_DOOR;
    end else begin
      if (probeY = GDVars.mapState.y) and
          ((probeDirection = C_Dir.EAST) or (probeDirection = C_Dir.WEST)) then
        GetWallKind := CombatSt.WALL_OPEN
      else
        GetWallKind := CombatSt.WALL_SOLID;
    end;
  end;

begin
  oppositeDirection := (direction + 4) mod 8;
  nearWallKind := GetWallKind(xCoordinate, yCoordinate, direction);
  farWallKind := GetWallKind(xCoordinate + GDConsts.dirDeltaX[direction], yCoordinate + GDConsts.dirDeltaY[direction],
                             oppositeDirection);
  WallBetween := nearWallKind or farWallKind;
end;

{ Builds the dungeon combat arena from the 13 by 5 dungeon cells around the party: each cell's walls are classified and
  drawn as a skewed six-by-five block of floor and wall terrain, and the cell is decorated (DecorateCell). }
procedure BuildDungeonArena;
var
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cornerIdx: Byte;

  { Draws the cell's three floor rows and its west wall or door. }
  procedure DrawFloorWestWall;
  var
    column: Byte;
    row: Byte;
  begin
    for row := 2 to 4 do
      for column := 0 to 5 do
        CombatSt.PlotCell(column, row, 22);
    if GDVars.westWall = CombatSt.WALL_SOLID then begin
      for row := 2 to 4 do begin
        CombatSt.PlotCell(row - 1, row, 4);
        CombatSt.PlotCell(row, row, 3);
        CombatSt.PlotCell(row + 1, row, 13);
      end;
    end else if GDVars.westWall = CombatSt.WALL_DOOR then begin
      CombatSt.PlotCell(1, 2, 8);
      CombatSt.PlotCell(5, 4, 0);
    end;
  end;

  { Draws the current cell's north wall band (spots 3..4 on rows 0..1): wall terrain when solid, floor otherwise. }
  procedure DrawNorthWall;
  var
    { Unused in this version; see the other implementations of this routine. }
    column: Integer;
  begin
    if GDVars.northWall = CombatSt.WALL_SOLID then begin
      CombatSt.PlotCell(3, 0, 5);
      CombatSt.PlotCell(4, 0, 5);
      CombatSt.PlotCell(3, 1, 10);
      CombatSt.PlotCell(4, 1, 10);
    end else begin
      CombatSt.PlotCell(3, 0, 22);
      CombatSt.PlotCell(4, 0, 22);
      CombatSt.PlotCell(3, 1, 22);
      CombatSt.PlotCell(4, 1, 22);
    end;
  end;

  { Fills the cell's northwest corner by its walls and whether the corner between its neighbors is open. }
  procedure FillCornerNorthWest;
  var
    index: Byte;
    tileTopLeft: Byte;
    tileBottomLeft: Byte;
    tileTopRight: Byte;
    tileBottomRight: Byte;
    passageOpen: Byte;
  begin
    if (CombatSt.WallBetween(cellX, cellY - 1, C_Dir.WEST) = CombatSt.WALL_OPEN) and
        (CombatSt.WallBetween(cellX - 1, cellY, C_Dir.NORTH) = CombatSt.WALL_OPEN) then
      passageOpen := 1
    else
      passageOpen := 0;
    for index := 1 to 4 do
      case index of
        1: case GDVars.northWall of
             CombatSt.WALL_OPEN: case GDVars.westWall of
                  CombatSt.WALL_OPEN: tileTopLeft := 22;
                  CombatSt.WALL_DOOR: tileTopLeft := 13;
                  CombatSt.WALL_SOLID: if passageOpen <> 0 then tileTopLeft := 0 else tileTopLeft := 13;
                end;
             CombatSt.WALL_DOOR, CombatSt.WALL_SOLID: if GDVars.westWall = CombatSt.WALL_OPEN then begin
                     if passageOpen <> 0 then tileTopLeft := 15 else tileTopLeft := 5;
                   end else begin
                     if passageOpen <> 0 then tileTopLeft := 18 else tileTopLeft := 2;
                   end;
           end;
        2: case GDVars.northWall of
             CombatSt.WALL_OPEN: tileTopRight := 22;
             CombatSt.WALL_DOOR: tileTopRight := 17;
             CombatSt.WALL_SOLID: tileTopRight := 5;
           end;
        3: case GDVars.westWall of
             CombatSt.WALL_OPEN: if GDVars.northWall = CombatSt.WALL_OPEN then
                  tileBottomLeft := 22
                else if passageOpen <> 0 then
                  tileBottomLeft := 16
                else
                  tileBottomLeft := 10;
             CombatSt.WALL_DOOR: if passageOpen <> 0 then tileBottomLeft := 20 else tileBottomLeft := 7;
             CombatSt.WALL_SOLID: if passageOpen <> 0 then tileBottomLeft := 1 else tileBottomLeft := 3;
           end;
        4: case GDVars.westWall of
             CombatSt.WALL_OPEN, CombatSt.WALL_DOOR: case GDVars.northWall of
                     CombatSt.WALL_OPEN: tileBottomRight := 22;
                     CombatSt.WALL_DOOR: tileBottomRight := 23;
                     CombatSt.WALL_SOLID: tileBottomRight := 10;
                   end;
             CombatSt.WALL_SOLID: case GDVars.northWall of
                  CombatSt.WALL_OPEN: tileBottomRight := 13;
                  CombatSt.WALL_DOOR: tileBottomRight := 21;
                  CombatSt.WALL_SOLID: tileBottomRight := 6;
                end;
           end;
      end;
    CombatSt.PlotCell(1, 0, tileTopLeft);
    CombatSt.PlotCell(2, 0, tileTopRight);
    CombatSt.PlotCell(1, 1, tileBottomLeft);
    CombatSt.PlotCell(2, 1, tileBottomRight);
  end;

  { Fills the cell's northeast corner (spots 5..6 on rows 0..1) by its walls and its neighbors'. }
  procedure FillCornerNorthEast;
  var
    index: Byte;
    tileTopLeft: Byte;
    tileBottomLeft: Byte;
    tileTopRight: Byte;
    tileBottomRight: Byte;
    passageOpen: Byte;
    northNeighborWall: Byte;
    eastNeighborWall: Byte;
  begin
    northNeighborWall := CombatSt.WallBetween(cellX, cellY - 1, C_Dir.EAST);
    eastNeighborWall := CombatSt.WallBetween(cellX + 1, cellY, C_Dir.NORTH);
    if (northNeighborWall = CombatSt.WALL_OPEN) and (eastNeighborWall = CombatSt.WALL_OPEN) then
      passageOpen := 1
    else
      passageOpen := 0;
    for index := 1 to 4 do
      case index of
        1: case GDVars.northWall of
             CombatSt.WALL_OPEN: if northNeighborWall = CombatSt.WALL_SOLID then
                  tileTopLeft := 4
                else
                  tileTopLeft := 22;
             CombatSt.WALL_DOOR: tileTopLeft := 15;
             CombatSt.WALL_SOLID: tileTopLeft := 5;
           end;
        2: if GDVars.northWall = CombatSt.WALL_OPEN then begin
             case northNeighborWall of
               CombatSt.WALL_OPEN: tileTopRight := 22;
               CombatSt.WALL_DOOR: if (GDVars.eastWall = CombatSt.WALL_OPEN) and
                 (eastNeighborWall <> CombatSt.WALL_OPEN) then
                    tileTopRight := 24
                  else
                    tileTopRight := 1;
               CombatSt.WALL_SOLID: if GDVars.eastWall = CombatSt.WALL_OPEN then begin
                    if eastNeighborWall <> CombatSt.WALL_OPEN then tileTopRight := 11 else tileTopRight := 7;
                  end else
                    tileTopRight := 3;
             end;
           end else begin
             if GDVars.eastWall <> CombatSt.WALL_OPEN then
               tileTopRight := 9
             else if eastNeighborWall <> CombatSt.WALL_OPEN then
               tileTopRight := 5
             else if passageOpen <> 0 then
               tileTopRight := 17
             else
               tileTopRight := 19;
           end;
        3: case GDVars.northWall of
             CombatSt.WALL_OPEN: tileBottomLeft := 22;
             CombatSt.WALL_DOOR: tileBottomLeft := 16;
             CombatSt.WALL_SOLID: tileBottomLeft := 10;
           end;
        4: if GDVars.northWall = CombatSt.WALL_OPEN then begin
             if northNeighborWall = CombatSt.WALL_OPEN then
               tileBottomRight := 22
             else if GDVars.eastWall <> CombatSt.WALL_OPEN then
               tileBottomRight := 4
             else if eastNeighborWall = CombatSt.WALL_OPEN then
               tileBottomRight := 8
             else
               tileBottomRight := 12;
           end else begin
             if GDVars.eastWall <> CombatSt.WALL_OPEN then
               tileBottomRight := 14
             else if eastNeighborWall = CombatSt.WALL_OPEN then
               tileBottomRight := 23
             else
               tileBottomRight := 10;
           end;
      end;
    CombatSt.PlotCell(5, 0, tileTopLeft);
    CombatSt.PlotCell(6, 0, tileTopRight);
    CombatSt.PlotCell(5, 1, tileBottomLeft);
    CombatSt.PlotCell(6, 1, tileBottomRight);
  end;

begin
  for GDVars.mapOffsetY := -2 to 2 do
    for GDVars.mapOffsetX := -6 to 6 do begin
      cellX := GDVars.mapState.x + GDVars.mapOffsetX;
      cellY := GDVars.mapState.y + GDVars.mapOffsetY;
      GDVars.westWall := CombatSt.WallBetween(cellX, cellY, C_Dir.WEST);
      GDVars.northWall := CombatSt.WallBetween(cellX, cellY, C_Dir.NORTH);
      GDVars.eastWall := CombatSt.WallBetween(cellX, cellY, C_Dir.EAST);
      GDVars.southWall := CombatSt.WallBetween(cellX, cellY, C_Dir.SOUTH);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNorthWest;
      FillCornerNorthEast;
      GDVars.mapEventFlag := View3D.GetMapEvent(cellX, cellY) and $40;
      CombatSt.DecorateCell;
    end;
end;

{ Looks up the class bits of the current terrain type, which steer the wilderness arena generators.
  @returns(The class bits.) }
function TerrainClassOf: Byte;
begin
  TerrainClassOf := GDConsts.terrainClasses[GDVars.terrainType];
end;

{ Draws a river across the wilderness arena by chance: 35 percent with class bit 5, 75 percent with bit 4, none
  otherwise. The river runs from top to bottom, two cells wide, drifting one column right per row, with an occasional
  two-row ford. }
procedure PlaceRiver;
var
  threshold: Byte;
  { Unused in this version; see the other implementations of this routine. }
  startColumn: ShortInt;
  column: ShortInt;
  row: ShortInt;

  { Draws a ford on the river's right bank at a row and the row below it. }
  procedure PlotFord(row, column: ShortInt);
  begin
    if column < 49 then
      GDVars.arena^.cells[row, column + 1] := 64;
    if (row < 24) and (column < 49) then
      GDVars.arena^.cells[row + 1, column + 1] := 65;
  end;

begin
  threshold := 0;
  if CombatSt.TerrainClassOf and $20 <> 0 then threshold := 35;
  if CombatSt.TerrainClassOf and $10 <> 0 then threshold := 75;
  if FxEngine.RollDice(1, 100) > threshold then Exit;
  column := 34 - FxEngine.RollDice(5, 4);
  while (column + 2) mod 7 > 0 do
    Dec(column);
  startColumn := column;
  for row := 0 to 24 do
    if column <= 49 then begin
      GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 2) + 59;
      if column < 49 then
        GDVars.arena^.cells[row, column + 1] := FxEngine.RollDice(1, 2) + 61;
      if FxEngine.RollDice(1, 20) = 1 then
        PlotFord(row, column);
      Inc(column);
    end;
end;

{ Plants trees on pairs of grass cells, one above the other, at a density set by the terrain's class bits: some become a
  one-cell bush, the others a two-cell tree. Class bit 7 plants none. }
procedure PlaceTrees;
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  column: ShortInt;
  row: ShortInt;
  density: ShortInt;
begin
  if CombatSt.TerrainClassOf and $80 <> 0 then Exit;
  density := 10;
  if CombatSt.TerrainClassOf and $02 <> 0 then Dec(density, 5);
  if CombatSt.TerrainClassOf and $04 <> 0 then Dec(density, 2);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(density, 5);
  if CombatSt.TerrainClassOf and $08 <> 0 then Inc(density, 10);
  if density < 0 then density := 1;
  for column := 0 to 49 do
    for row := 1 to 24 do
      if (GDConsts.terrainInfo[GDVars.arena^.cells[row, column]].tileId = 22) and
          (GDConsts.terrainInfo[GDVars.arena^.cells[row - 1, column]].tileId = 22) and
          (density >= FxEngine.RollDice(1, 100)) then begin
        if density >= FxEngine.RollDice(1, 100) then
          GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 2) + 41
        else begin
          GDVars.arena^.cells[row - 1, column] := FxEngine.RollDice(1, 6) + 31;
          GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 4) + 37;
        end;
      end;
end;

{ Scatters features over the grass cells of the wilderness arena, with the odds of each kind chosen by a weight the
  terrain's class bits raise and lower. }
procedure ScatterFeatures;
var
  column: ShortInt;
  row: ShortInt;
  featureWeight: Integer;

  { Rolls d100 against five stacked bands and turns the cell into the matching feature, if any. }
  procedure ScatterOneCell(column, row: ShortInt; weight1, weight2, weight3, weight4, weight5: Byte);
  var
    roll: Byte;
  begin
    roll := FxEngine.RollDice(1, 100);
    if roll <= weight1 then
      GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 2) + 57
    else if roll <= weight1 + weight2 then
      GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 2) + 47
    else if roll <= weight1 + weight2 + weight3 then
      GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 4) + 43
    else if roll <= weight1 + weight2 + weight3 + weight4 then
      GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 3) + 54
    else if roll <= weight5 + (weight1 + weight2 + weight3 + weight4) then
      GDVars.arena^.cells[row, column] := FxEngine.RollDice(1, 4) + 49;
  end;

begin
  featureWeight := 50;
  if CombatSt.TerrainClassOf and $10 <> 0 then Inc(featureWeight, 10);
  if CombatSt.TerrainClassOf and $20 <> 0 then Inc(featureWeight, 30);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(featureWeight, 20);
  if CombatSt.TerrainClassOf and $04 <> 0 then Dec(featureWeight, 10);
  if CombatSt.TerrainClassOf and $02 <> 0 then Dec(featureWeight, 20);
  if CombatSt.TerrainClassOf and $80 <> 0 then Dec(featureWeight, 50);
  for column := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrainInfo[GDVars.arena^.cells[row, column]].tileId = 22 then
        case featureWeight of
          -30..9: ScatterOneCell(column, row, 0, 0, 0, 30, 15);
          10..29: ScatterOneCell(column, row, 0, 1, 5, 20, 10);
          30..69: ScatterOneCell(column, row, 0, 2, 5, 10, 5);
          70..89: ScatterOneCell(column, row, 10, 2, 10, 10, 1);
          90..110: ScatterOneCell(column, row, 15, 5, 15, 10, 1);
        end;
end;

{ Builds the wilderness combat arena: fills it with grass, sets terrain type 15, then places a river, trees and
  scattered features. }
procedure BuildWildernessArena;
var
  { Unused in this version; see the other implementations of this routine. }
  mapX: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  mapY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  mapIndex: Integer;
begin
  FillChar(GDVars.arena^.cells, SizeOf(GDVars.arena^.cells), 23);
  mapX := GDVars.zone0^.partyX;
  mapY := GDVars.zone0^.partyY;
  GDVars.terrainType := 15;
  CombatSt.PlaceRiver;
  CombatSt.PlaceTrees;
  CombatSt.ScatterFeatures;
end;

{ Loads the combat tiles (DungCom in 3D, WildCom overland) and the random tiles (RandCom), allocates the arena with its
  cursor off, and builds the dungeon or wilderness arena. }
procedure LoadCombatTileSet;
begin
  if GDVars.zone0^.view3dFlag <> 0 then
    MapTiles.Load24x24Set('DungCom', 1, 0, 25)
  else
    MapTiles.Load24x24Set('WildCom', 1, 0, 33);
  MapTiles.Load24x24Set('RandCom', 1, 34, 6);
  GetMem(GDVars.arena, SizeOf(Types.TArena));
  GDVars.arena^.cursorOn := False;
  GDVars.arena^.cursorSize := 1;
  GDVars.arena^.ignoreTerrain := 0;
  if GDVars.zone0^.view3dFlag <> 0 then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Gives each creature a zeroed combat record after recalculating its statistics: creatures past the party's size are
  marked as non-party members, allies face the party's way and hostiles the other way, and a friendly non-party creature
  with no morale, or one above 102, takes the zone's base morale as a non-player. }
procedure InitCreatureCombatData;
var
  character: Types.PCharRecord;
  count: Byte;
  moraleValue: Byte;
begin
  character := GDVars.partyHead;
  count := 0;
  while character <> nil do begin
    CharHlp.RecalcStats(character);
    Inc(count);
    GetMem(character^.combatAddr, SizeOf(Types.TCombatRec));
    FillChar(character^.combatAddr^, SizeOf(Types.TCombatRec), 0);
    if count > GDVars.zone1^.partySize then
      character^.combatAddr^.nonPartyMember := 1;
    character^.combatAddr^.facing := GDConsts.quadrantDirections[GDVars.mapState.facing div 2];
    if character^.hostile = C_Side.ENEMY then
      character^.combatAddr^.facing := (character^.combatAddr^.facing + 4) mod 8;
    moraleValue := character^.npc and C_Npc.MORALE_MASK;
    if (character^.hostile = C_Side.PLAYER) and (character^.combatAddr^.nonPartyMember = 1) and
        ((moraleValue = 0) or (moraleValue > 102)) then
      character^.npc := GDVars.zone1^.moraleBase + C_Npc.NON_PLAYER;
    character := character^.next;
  end;
end;

{ Tells whether a placement square lies off the 11x6 grid on both axes.
  @param(quadX The square's column.)
  @param(quadY The square's row.)
  @returns(True when both coordinates are off the grid.) }
function QuadFullyOff(quadX, quadY: ShortInt): Boolean;
begin
  if ((quadX >= 0) and (quadX < 11)) or ((quadY >= 0) and (quadY < 6)) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Tries to put a creature on a placement square of its team's grid for one ring. The square must be on the grid and
  free; its arena cell, from the same skewed mapping as the dungeon builder, is stored before the probe, and the cell
  must hold no creature and passable terrain.
  @param(combatantSlot The creature's combat slot.)
  @param(quadX The square's column.)
  @param(quadY The square's row.)
  @param(baseOffsetX The grid's base column.)
  @param(baseOffsetY The grid's base row.)
  @param(ring The placement ring, 0 to 3.)
  @returns(1 when the creature was placed, which takes the square; 0 otherwise.) }
function TryPlaceAt(combatantSlot: Byte; quadX, quadY, baseOffsetX, baseOffsetY: ShortInt; ring: Byte): Byte;
var
  occupantIndex: Byte;
  terrainIndex: Byte;
  adjacentCorpse: Byte;
  adjacentWater: Byte;
begin
  if (quadX < 0) or (quadY < 0) or (quadX > 10) or (quadY > 5) or
      (GDVars.placementAvailable[GDVars.placementTeam, ring, quadY, quadX] = 0) then
    TryPlaceAt := 0
  else begin
    GDVars.arenaLoc[combatantSlot].x := quadX + baseOffsetX * 6 + baseOffsetY * 5 + 22;
    GDVars.arenaLoc[combatantSlot].y := quadY + baseOffsetY * 5 + 10;
    CbtMap.ProbeDirection(Types.PCharRecord(GDVars.creatureArr[combatantSlot]), C_Dir.CENTER, occupantIndex,
                          terrainIndex, adjacentCorpse, adjacentWater);
    if (occupantIndex = 0) and (terrainIndex > 0) and
        (GDConsts.terrainInfo[terrainIndex].movementCost < C_Terr.TERRAIN_IMPASSABLE) then begin
      TryPlaceAt := 1;
      GDVars.placementAvailable[GDVars.placementTeam, ring, quadY, quadX] := 0;
    end else
      TryPlaceAt := 0;
  end;
end;

{ Searches the team's placement grid for a square for a creature, in zigzag legs from the ring's start square. A leg
  ends at a square partly off the grid or after a set number of tries, and the next leg starts a step further back; for
  team 0 facing diagonally, ring 0's first step back is doubled when any of the ring's three directions is not walled
  off (always outdoors). A square fully off the grid moves on to the next ring whose direction is not walled off (always
  outdoors), up to ring 3.
  @param(combatantSlot The creature's combat slot.)
  @returns(True when the creature was placed; False when no ring is left.) }
function FindPlacement(combatantSlot: Byte): Boolean;
var
  placed: Byte;
  firstTraversal: Byte;
  placementFailed: Byte;
  outsideGrid: Byte;
  passageOpen: Byte;
  traversalState: Byte;
  direction: Byte;
  quadrant: Byte;
  index: Byte;
  directionStepX: ShortInt;
  directionStepY: ShortInt;
  wallCellX: ShortInt;
  wallCellY: ShortInt;
  legOffset: Byte;
  legLength: Byte;
  baseQuadX: ShortInt;
  baseQuadY: ShortInt;
  placementAttempts: Byte;
  ring: Byte;
  legOriginX: ShortInt;
  legOriginY: ShortInt;
  quadX: ShortInt;
  quadY: ShortInt;
begin
  firstTraversal := 1;
  placementFailed := 0;
  traversalState := 1;
  legOffset := 0;
  ring := 0;
  baseQuadX := GDVars.teamOriginX[GDVars.placementTeam];
  baseQuadY := GDVars.teamOriginY[GDVars.placementTeam];
  repeat
    quadrant := GDConsts.ringQuadrantTable[GDVars.teamDirection[GDVars.placementTeam], ring] div 2;
    case traversalState of
      1: begin
           directionStepX := GDConsts.dirDeltaX[GDConsts.quadrantDirections[(quadrant + 2) mod 4]];
           directionStepY := GDConsts.dirDeltaY[GDConsts.quadrantDirections[(quadrant + 2) mod 4]];
           legOriginX := GDConsts.quadrantStartXTable[ring > 0, quadrant] + directionStepX * legOffset;
           legOriginY := GDConsts.quadrantStartYTable[ring > 0, quadrant] + directionStepY * legOffset;
           quadX := legOriginX;
           quadY := legOriginY;
           legLength := 1;
           traversalState := 2;
           placementAttempts := 1;
         end;
      2: begin
           directionStepX := GDConsts.dirDeltaX[GDConsts.quadrantDirections[(quadrant + 1) mod 4]];
           directionStepY := GDConsts.dirDeltaY[GDConsts.quadrantDirections[(quadrant + 1) mod 4]];
           quadX := legOriginX + directionStepX * legLength;
           quadY := legOriginY + directionStepY * legLength;
           traversalState := 3;
           Inc(placementAttempts);
         end;
      3: begin
           directionStepX := GDConsts.dirDeltaX[GDConsts.quadrantDirections[(quadrant + 3) mod 4]];
           directionStepY := GDConsts.dirDeltaY[GDConsts.quadrantDirections[(quadrant + 3) mod 4]];
           quadX := legOriginX + directionStepX * legLength;
           quadY := legOriginY + directionStepY * legLength;
           traversalState := 2;
           Inc(legLength);
           Inc(placementAttempts);
         end;
    end;
    if (quadX < 0) or (quadY < 0) or (quadX > 10) or (quadY > 5) then
      outsideGrid := 1
    else
      outsideGrid := 0;
    if traversalState > 1 then begin
      if ((outsideGrid <> 0) and (not CombatSt.QuadFullyOff(quadX, quadY))) or
          ((firstTraversal <> 0) and (placementAttempts >= GDVars.teamPlacementRows[GDVars.placementTeam])) or
          ((firstTraversal = 0) and (placementAttempts > 11)) then begin
        Inc(legOffset);
        if (GDVars.placementTeam = 0) and Odd(GDVars.teamDirection[0]) and (ring = 0) and (legOffset = 1) then begin
          wallCellX := GDVars.teamOriginX[GDVars.placementTeam] + GDVars.mapState.x;
          wallCellY := GDVars.teamOriginY[GDVars.placementTeam] + GDVars.mapState.y;
          passageOpen := 0;
          for index := 1 to 3 do begin
            direction := GDConsts.ringDirectionTable[GDVars.teamDirection[GDVars.placementTeam], index];
            if (GDVars.interfaceState = C_Ifc.OVERLAND) or
                (CombatSt.WallBetween(wallCellX, wallCellY, direction) <> CombatSt.WALL_SOLID) then
              passageOpen := 1;
          end;
          if passageOpen <> 0 then
            Inc(legOffset);
        end;
        traversalState := 1;
        firstTraversal := 0;
      end;
    end;
    if (outsideGrid <> 0) and CombatSt.QuadFullyOff(quadX, quadY) then begin
      placed := 0;
      traversalState := 0;
      while (ring < 3) and (traversalState <> 1) do begin
        Inc(ring);
        wallCellX := GDVars.teamOriginX[GDVars.placementTeam] + GDVars.mapState.x;
        wallCellY := GDVars.teamOriginY[GDVars.placementTeam] + GDVars.mapState.y;
        direction := GDConsts.ringDirectionTable[GDVars.teamDirection[GDVars.placementTeam], ring];
        if (GDVars.interfaceState = C_Ifc.OVERLAND) or
            (CombatSt.WallBetween(wallCellX, wallCellY, direction) <> CombatSt.WALL_SOLID) then begin
          baseQuadX := GDVars.teamOriginX[GDVars.placementTeam] + GDConsts.dirDeltaX[direction];
          baseQuadY := GDVars.teamOriginY[GDVars.placementTeam] + GDConsts.dirDeltaY[direction];
          legOffset := 0;
          traversalState := 1;
        end;
      end;
      if traversalState <> 1 then
        placementFailed := 1;
    end;
    if outsideGrid = 0 then
      placed := CombatSt.TryPlaceAt(combatantSlot, quadX, quadY, baseQuadX, baseQuadY, ring);
  until (placed <> 0) or (placementFailed <> 0);
  if placementFailed <> 0 then
    FindPlacement := False
  else
    FindPlacement := True;
end;

{ Places every creature in the arena. The party's team starts at the party's cell facing its way, the hostiles
  monsterDist cells ahead facing back; each team's placement grid is limited to its band. Out-of-play party members
  become corpses on their cells (except in a duel), removed creatures are taken out of play, and a non-party creature
  that cannot be placed is removed from the game. }
procedure PlaceAllCreatures;
var
  xCoordinate: ShortInt;
  yCoordinate: ShortInt;
  previousCharacter: Types.PCharRecord;
  character: Types.PCharRecord;
  combatantSlot: Byte;
  ringIndex: Byte;
  bandDirection: Byte;
  placedCount: Byte;
  removedCount: Byte;
begin
  CharHlp.CountTeams;
  removedCount := 0;
  placedCount := 0;
  for combatantSlot := 1 to 255 do
    GDVars.arenaLoc[combatantSlot].size := 0;
  CbtMap.BuildArenaArrays;
  GDVars.teamOriginX[0] := 0;
  GDVars.teamOriginY[0] := 0;
  GDVars.teamDirection[0] := GDVars.mapState.facing div 2;
  GDVars.teamOriginX[1] := GDConsts.dirDeltaX[GDVars.mapState.facing] * GDVars.zone1^.monsterDist +
    GDVars.teamOriginX[0];
  GDVars.teamOriginY[1] := GDConsts.dirDeltaY[GDVars.mapState.facing] * GDVars.zone1^.monsterDist +
    GDVars.teamOriginY[0];
  GDVars.teamDirection[1] := (GDVars.mapState.facing + 4) mod 8 div 2;
  for GDVars.placementTeam := 0 to 1 do
    GDVars.teamPlacementRows[GDVars.placementTeam] := (GDVars.teamCount[GDVars.placementTeam] + 1) div 2;
  for GDVars.placementTeam := 0 to 1 do
    for ringIndex := 0 to 3 do begin
      if ringIndex = 1 then
        bandDirection := 4
      else
        bandDirection := GDVars.teamDirection[GDVars.placementTeam];
      for yCoordinate := 0 to 5 do
        for xCoordinate := 0 to 10 do
          if (GDConsts.placementBandTable[bandDirection, yCoordinate].firstColumn > xCoordinate) or
              (GDConsts.placementBandTable[bandDirection, yCoordinate].lastColumn < xCoordinate) then
            GDVars.placementAvailable[GDVars.placementTeam, ringIndex, yCoordinate, xCoordinate] := 0
          else
            GDVars.placementAvailable[GDVars.placementTeam, ringIndex, yCoordinate, xCoordinate] := 1;
    end;
  combatantSlot := 1;
  GDVars.arenaCount := 1;
  previousCharacter := GDVars.partyHead;
  character := GDVars.partyHead;
  while character <> nil do begin
    GameIo.DiscardPendingKeys;
    GDVars.creatureArr[combatantSlot] := character;
    GDVars.placementTeam := character^.hostile;
    GDVars.arenaLoc[combatantSlot].combatantIndex := combatantSlot;
    GDVars.arenaLoc[combatantSlot].size := character^.iconDimensions and $07;
    if CombatSt.FindPlacement(combatantSlot) then begin
      previousCharacter := character;
      if character^.inPlay = 0 then begin
        GDVars.arenaLoc[combatantSlot].size := 0;
        if (GDVars.duelFlag = 0) and (character^.combatAddr^.nonPartyMember = 0) then begin
          xCoordinate := GDVars.arenaLoc[combatantSlot].x;
          yCoordinate := GDVars.arenaLoc[combatantSlot].y;
          Inc(GDVars.downedCount);
          GDVars.downedCreatures[GDVars.downedCount].terrain := GDVars.arena^.cells[yCoordinate, xCoordinate];
          GDVars.arena^.cells[yCoordinate, xCoordinate] := C_Terr.TERRAIN_CORPSE;
          GDVars.downedCreatures[GDVars.downedCount].creature := character;
          GDVars.downedCreatures[GDVars.downedCount].x := xCoordinate;
          GDVars.downedCreatures[GDVars.downedCount].y := yCoordinate;
        end;
      end;
      if character^.status = C_Status.REMOVED then begin
        character^.inPlay := 0;
        GDVars.arenaLoc[combatantSlot].size := 0;
      end;
      CbtMap.BuildArenaArrays;
      Inc(combatantSlot);
      Inc(GDVars.arenaCount);
      Inc(placedCount);
    end else begin
      GDVars.arenaLoc[combatantSlot].size := 0;
      if character^.combatAddr^.nonPartyMember = 1 then begin
        Inc(removedCount);
        GDVars.creatureArr[combatantSlot] := nil;
        GDVars.curChar := character;
        CharGen.RemoveCreature(True, False);
        character := previousCharacter;
      end else begin
        previousCharacter := character;
        Inc(combatantSlot);
        Inc(GDVars.arenaCount);
      end;
    end;
    character := character^.next;
  end;
  previousCharacter^.next := nil;
end;

procedure CombatStart;
var
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..10] of Byte;
  character: Types.PCharRecord;
begin
  GDVars.slowText := 0;
  Portrait.FreeAnimation(GDVars.bigAnim);
  Blit.FreePic(GDVars.portraits[1].pic);
  Blit.FreePic(GDVars.portraits[2].pic);
  Blit.FreePic(GDVars.bigPicBuf);
  GDVars.bigPicId := 255;
  GDVars.portraits[1].fileId := 255;
  GDVars.portraits[2].fileId := 255;
  MenuCore.ClearBottomLine;
  TextRend.pauseOnly;
  TextRend.displayString(0, 24, LightGreen, Black, 'A battle begins...');
  GDVars.magicEnabled := False;
  GDVars.explosionBusy := 0;
  GDVars.roundNumber := 0;
  GDVars.roundLimit := 15;
  GDVars.gAttackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.cloudHead := nil;
  GDVars.acidPoolHead := nil;
  GDVars.effectListHeadC := nil;
  GDVars.yellTarget := nil;
  GDVars.prevTreasure := nil;
  GDVars.bankHead := nil;
  FillChar(GDVars.downedCreatures, SizeOf(GDVars.downedCreatures), 0);
  GDVars.zone1^.attackedAlly := 0;
  CombatSt.LoadCombatTileSet;
  GameIo.DiscardPendingKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.DiscardPendingKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.DiscardPendingKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.viewPicture);
  GDVars.arena^.originX := CbtMap.CombatCellX(Types.PCharRecord(GDVars.partyHead)) - 3;
  GDVars.arena^.originY := CbtMap.CombatCellY(Types.PCharRecord(GDVars.partyHead)) - 3;
  CharHlp.DisplayCombatInterface;
  character := GDVars.partyHead;
  while character <> nil do begin
    character^.combatAddr^.turnUses := 0;
    FxEngine.TriggerEffectsWithCondition(8, character);
    FxEngine.TriggerEffectsWithCondition(22, character);
    character := character^.next;
  end;
  CbtActs.UpdateHostileHpPercent;
  GDVars.creatureCursorActive := 0;
  GDVars.mapCursorActive := 0;
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  GDVars.extendedMode := 0;
  FillChar(GDVars.explosionQueue, SizeOf(GDVars.explosionQueue), 0);
  GDVars.explosionCount := 0;
  character := GDVars.partyHead;
  while character <> nil do begin
    Debug.PrintDebug(character^.name, character^.status, character^.inPlay, 0);
    character := character^.next;
  end;
end;

begin
end.
