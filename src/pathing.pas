{ Combat line walking and target selection. }
{$O+,F+}
unit Pathing;

interface

uses Types, CbtMap, GDConsts, GDVars, C_Dir;

{ Gives the sign of a number.
  @param(v The number.)
  @returns(-1, 0 or 1.) }
function SignOf(v: Integer): Integer;

{ Starts a line walk from its start point to its end point: sets the current point, the deltas, the step signs, and zero
  error and distance.
  @param(path The walk, with its start and end points set.) }
procedure PathFind(var path: Types.TPathState);

{ Takes one Bresenham step along a line walk, adding 2 to the doubled distance for a straight step and 3 for a diagonal,
  and records the step's direction.
  @param(path The walk, started by PathFind.)
  @returns(False, without moving, once the end point is reached.) }
function NextPathStep(var path: Types.TPathState): Boolean;

{ Tells whether a direction leads from one arena cell toward another: the target must lie in the 90-degree cone around
  the cell one step away in that direction. A target on the start cell or on the cell one step away always counts.
  @param(x Arena column of the start cell.)
  @param(y Arena row of the start cell.)
  @param(tx Arena column of the target cell.)
  @param(ty Arena row of the target cell.)
  @param(dir The direction, 0 to 7; 8 or 255 for any direction, which always counts.)
  @returns(True when the direction leads toward the target; False when a cell lies outside the arena. Note: a direction
    from 9 to 254 matches no case and leaves the result unset.) }
function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;

{ Walks a line between two arena cells until terrain or the range stops it. The walk stops once the doubled distance (2
  per straight step, 3 per diagonal) exceeds twice the range plus 1, or, when the arena's distance mode is 0, at a cell
  whose terrain rises above the line of sight from the start cell's clearance.
  @param(x Arena column of the start cell.)
  @param(y Arena row of the start cell.)
  @param(tx Arena column of the target cell; receives the cell where the walk stopped.)
  @param(ty Arena row of the target cell; receives the cell where the walk stopped.)
  @param(dist The range in cells; receives the doubled distance walked.)
  @param(view The arena.)
  @returns(True when the walk reached the target.) }
function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;

{ Builds the target list from an icon's position: each combatant with an icon on the arena is a target when a line from
  a tile of the icon reaches a tile of its icon within range, in the required direction. Each target keeps its shortest
  doubled distance and a direction toward it: the required direction itself when it is 0 to 7, otherwise the lowest
  direction that leads from the best pair of tiles. The list is then sorted by distance.
  @param(x Arena column of the icon's upper-left cell.)
  @param(y Arena row of the icon's upper-left cell.)
  @param(range The range in cells.)
  @param(filter The direction a target must lie in, 0 to 7; 8 or 255 for any direction.)
  @param(size The icon size.)
  @param(view The arena.) }
procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Pointer);

{ Empty entry; calling it loads this overlay. }
procedure PrimePathing;

implementation

procedure PrimePathing;
begin
end;

function SignOf(v: Integer): Integer;
begin
  if v < 0 then
    SignOf := -1
  else if v > 0 then
    SignOf := 1
  else
    SignOf := 0;
end;

{ Sorts the target list nearest first; on equal distance a lower direction goes first unless it is diagonal and the
  other is not. }
procedure SortTargets;
var
  outerIndex: Byte;
  innerIndex: Byte;
  directionJ: Byte;
  directionI: Byte;
  swapTarget: Types.TTargetRec;
begin
  if GDVars.targetCount <= 1 then Exit;
  for outerIndex := 1 to GDVars.targetCount - 1 do
    for innerIndex := outerIndex + 1 to GDVars.targetCount do begin
      directionI := GDVars.targetList[outerIndex].direction;
      directionJ := GDVars.targetList[innerIndex].direction;
      if (GDVars.targetList[innerIndex].distance < GDVars.targetList[outerIndex].distance) or
          ((GDVars.targetList[innerIndex].distance = GDVars.targetList[outerIndex].distance) and
           (directionJ < directionI) and (directionJ mod 2 <= directionI mod 2)) then begin
        swapTarget := GDVars.targetList[outerIndex];
        GDVars.targetList[outerIndex] := GDVars.targetList[innerIndex];
        GDVars.targetList[innerIndex] := swapTarget;
      end;
    end;
end;

procedure PathFind(var path: Types.TPathState);
begin
  with path do begin
    currentX := startX;
    currentY := startY;
    deltaX := Abs(endX - startX);
    deltaY := Abs(endY - startY);
    stepX := Pathing.SignOf(endX - startX);
    stepY := Pathing.SignOf(endY - startY);
    error := 0;
    distance := 0;
  end;
end;

function NextPathStep(var path: Types.TPathState): Boolean;
var
  deltaIndexX: ShortInt;
  deltaIndexY: ShortInt;
begin
  NextPathStep := False;
  deltaIndexX := 1;
  deltaIndexY := 1;
  with path do begin
    if deltaX >= deltaY then
    { x-major walk }
    begin
      if currentX <> endX then begin
        Inc(currentX, stepX);
        deltaIndexX := stepX + 1;
        Inc(error, deltaY);
        Inc(error, deltaY);
        Inc(distance);
        Inc(distance);
        if error >= deltaX then begin
          Dec(error, deltaX);
          Dec(error, deltaX);
          Inc(currentY, stepY);
          deltaIndexY := stepY + 1;
          Inc(distance);
        end;
        NextPathStep := True;
      end;
    end else
    { y-major walk }
    begin
      if currentY <> endY then begin
        Inc(currentY, stepY);
        deltaIndexY := stepY + 1;
        Inc(error, deltaX);
        Inc(error, deltaX);
        Inc(distance);
        Inc(distance);
        if error >= deltaY then begin
          Dec(error, deltaY);
          Dec(error, deltaY);
          Inc(currentX, stepX);
          deltaIndexX := stepX + 1;
          Inc(distance);
        end;
        NextPathStep := True;
      end;
    end;
    lastDirection := GDConsts.dirByDelta[deltaIndexY, deltaIndexX];
  end;
end;

function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;
var
  walk: Types.TPathState;
  meter: Types.TPathState;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  stepped: Boolean;
  maxDist: Word;
begin
  maxDist := dist * 2 + 1;
  walk.startX := x;
  walk.startY := y;
  walk.endX := tx;
  walk.endY := ty;
  Pathing.PathFind(walk);
  meter.startX := 0;
  meter.startY := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance;
  if walk.deltaX > walk.deltaY then
    meter.endX := walk.deltaX
  else
    meter.endX := walk.deltaY;
  meter.endY := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance;
  Pathing.PathFind(meter);
  done := False;
  repeat
    if ((Types.PArena(view)^.ignoreTerrain = 0) and
        (GDConsts.terrainInfo[Types.PArena(view)^.cells[walk.currentY, walk.currentX]].blocking > meter.currentY)) or
          (walk.distance > maxDist) then begin
      tx := walk.currentX;
      ty := walk.currentY;
      dist := walk.distance;
      WalkLine := False;
      Exit;
    end;
    stepped := Pathing.NextPathStep(meter);
    done := not Pathing.NextPathStep(walk);
  until done;
  dist := walk.distance;
  WalkLine := True;
end;

function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;
var
  nx: ShortInt;
  ny: ShortInt;
begin
  if (x < 0) or (x > 49) or (y < 0) or (y > 24) or (tx < 0) or (tx > 49) or (ty < 0) or (ty > 24) then begin
    IsDirToward := False;
    Exit;
  end;
  if dir = 255 then
    dir := C_Dir.CENTER;
  nx := x + GDConsts.dirDeltaX[dir];
  ny := y + GDConsts.dirDeltaY[dir];
  if ((x = tx) and (y = ty)) or ((nx = tx) and (ny = ty)) then begin
    IsDirToward := True;
    Exit;
  end;
  case dir of
    C_Dir.NORTH: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_Dir.NORTHEAST: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or
      ((tx >= (nx + ny) - ty) and (ty <= ny));
    C_Dir.EAST: IsDirToward := ((tx >= (nx + ny) - ty) and (ty <= ny)) or ((tx >= (nx + ty) - ny) and (ty >= ny));
    C_Dir.SOUTHEAST: IsDirToward := ((tx >= (nx + ty) - ny) and (ty >= ny)) or
      ((tx >= nx) and (ty >= (tx - nx) + ny));
    C_Dir.SOUTH: IsDirToward := ((tx >= nx) and (ty >= (tx - nx) + ny)) or ((tx <= nx) and (ty >= (nx - tx) + ny));
    C_Dir.SOUTHWEST: IsDirToward := ((tx <= nx) and (ty >= (nx - tx) + ny)) or
      ((tx <= (nx + ny) - ty) and (ty >= ny));
    C_Dir.WEST: IsDirToward := ((tx <= (nx + ny) - ty) and (ty >= ny)) or ((tx <= (nx + ty) - ny) and (ty <= ny));
    C_Dir.NORTHWEST: IsDirToward := ((tx <= (nx + ty) - ny) and (ty <= ny)) or
      ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_Dir.CENTER: IsDirToward := True;
  end;
end;

procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Pointer);
var
  i: Byte;
  bestDir: Byte;
  k: Byte;
  j: Byte;
  bestK: Byte;
  bestJ: Byte;
  found: Boolean;
  tx: ShortInt;
  ty: ShortInt;
  dx8: ShortInt;
  dy8: ShortInt;
  myX: array[0..3] of ShortInt;
  myY: array[0..3] of ShortInt;
  tgX: array[0..3] of ShortInt;
  tgY: array[0..3] of ShortInt;
  dist: Word;
  bestDist: Word;
begin
  for k := 0 to 3 do
    if CbtMap.GetIconTileDelta(size, k, dx8, dy8) then begin
      myX[k] := x + dx8;
      myY[k] := y + dy8;
    end else
      myX[k] := -1;
  GDVars.targetCount := 0;
  for i := 1 to GDVars.arenaCount do
    if GDVars.arenaLoc[i].size > 0 then begin
      found := False;
      bestDist := 255;
      for j := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaLoc[i].size, j, dx8, dy8) then begin
          tgX[j] := GDVars.arenaLoc[i].x + dx8;
          tgY[j] := GDVars.arenaLoc[i].y + dy8;
        end else
          tgX[j] := -1;
      for j := 0 to 3 do
        if tgX[j] >= 0 then
          for k := 0 to 3 do
            if myX[k] >= 0 then
              if Pathing.IsDirToward(myX[k], myY[k], tgX[j], tgY[j], filter) then begin
                tx := tgX[j];
                ty := tgY[j];
                dist := range;
                if Pathing.WalkLine(myX[k], myY[k], tx, ty, dist, view) then begin
                  found := True;
                  if dist < bestDist then begin
                    bestDist := dist;
                    bestK := k;
                    bestJ := j;
                  end;
                end;
              end;
      if found then begin
        Inc(GDVars.targetCount);
        GDVars.targetList[GDVars.targetCount].creatureIndex := i;
        GDVars.targetList[GDVars.targetCount].distance := bestDist;
        bestDir := C_Dir.NORTH;
        if filter < C_Dir.CENTER then
          bestDir := filter
        else
          while not Pathing.IsDirToward(myX[bestK], myY[bestK], tgX[bestJ], tgY[bestJ], bestDir) do
            Inc(bestDir);
        GDVars.targetList[GDVars.targetCount].direction := bestDir;
      end;
    end;
  Pathing.SortTargets;
end;

begin
end.
