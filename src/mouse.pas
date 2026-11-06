{ INT 33h mouse driver. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Mouse;

interface

uses Types, Dos, GDConsts, GDVars, C_Keys, C_Dir;

{ Resets the mouse driver through INT 33h; when a driver answers, marks the mouse present and records the button count,
  otherwise marks it absent. }
procedure InitMouse;

{ Shows the mouse cursor. Does nothing without a mouse. }
procedure ShowMouse;

{ Hides the mouse cursor. Does nothing without a mouse. }
procedure HideMouse;

{ Reads the mouse buttons and position, halving the column unless the mouse's scale flag is set. Does nothing without a
  mouse.
  @param(buttons Receives the button state.)
  @param(x Receives the column.)
  @param(y Receives the row.) }
procedure GetMouse(var buttons, x, y: Integer);

{ Moves the mouse cursor, doubling the column unless the mouse's scale flag is set. Does nothing without a mouse.
  @param(x Column.)
  @param(y Row.) }
procedure SetMouse(x, y: Integer);

{ Sets the graphics cursor shape and hot spot. Does nothing without a mouse.
  @param(hotX Hot spot column within the cursor.)
  @param(hotY Hot spot row within the cursor.)
  @param(mask Screen and cursor masks of the shape.) }
procedure SetMouseCursor(hotX, hotY: Integer; mask: Types.PCursorMask);

{ Resets the mouse driver's software state. Does nothing without a mouse. }
procedure ResetMouse;

{ Classifies a mouse move into one of eight 45-degree sectors and returns the matching keypad key. The slopes 618/256
  and 106/256 stand for tan 67.5 and tan 22.5 degrees; the sectors are tried clockwise from up, so a move with no motion
  counts as up. Note: the horizontal change times 618 overflows an Integer for moves wider than 53 units, which can give
  the wrong direction.
  @param(oldX Starting column.)
  @param(oldY Starting row.)
  @param(newX Ending column.)
  @param(newY Ending row.)
  @returns(The scan code of the arrow, Home, End, Page Up or Page Down key for that direction.) }
function MouseDirection(oldX, oldY, newX, newY: Integer): Byte;

implementation

const
  RESET_DRIVER = 0;
  SHOW_CURSOR = 1;
  HIDE_CURSOR = 2;
  GET_POSITION = 3;
  SET_POSITION = 4;
  SET_CURSOR = 9;
  SOFT_RESET = 33;
  DRIVER_PRESENT = 65535;

procedure InitMouse;
begin
  GDVars.vregs.AX := Mouse.RESET_DRIVER;
  Intr($33, Registers(GDVars.vregs));
  if GDVars.vregs.AX = Mouse.DRIVER_PRESENT then begin
    GDVars.mouseButtonCount := GDVars.vregs.BX;
    GDVars.mouseOn := True;
  end else
    GDVars.mouseOn := False;
end;

procedure ShowMouse;
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.vregs.AX := Mouse.SHOW_CURSOR;
  Intr($33, Registers(GDVars.vregs));
end;

procedure HideMouse;
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.vregs.AX := Mouse.HIDE_CURSOR;
  Intr($33, Registers(GDVars.vregs));
end;

procedure GetMouse(var buttons, x, y: Integer);
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.vregs.AX := Mouse.GET_POSITION;
  Intr($33, Registers(GDVars.vregs));
  buttons := GDVars.vregs.BX;
  x := GDVars.vregs.CX;
  if not GDVars.mouseScaled then
    x := x div 2;
  y := GDVars.vregs.DX;
end;

procedure SetMouse(x, y: Integer);
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.vregs.AX := Mouse.SET_POSITION;
  if not GDVars.mouseScaled then
    x := x shl 1;
  GDVars.vregs.CX := x;
  GDVars.vregs.DX := y;
  Intr($33, Registers(GDVars.vregs));
end;

procedure SetMouseCursor(hotX, hotY: Integer; mask: Types.PCursorMask);
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.vregs.AX := Mouse.SET_CURSOR;
  GDVars.vregs.BX := hotX;
  GDVars.vregs.CX := hotY;
  GDVars.vregs.ES := Seg(mask^);
  GDVars.vregs.DX := Ofs(mask^);
  Intr($33, Registers(GDVars.vregs));
end;

procedure ResetMouse;
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.vregs.AX := Mouse.SOFT_RESET;
  Intr($33, Registers(GDVars.vregs));
end;

function MouseDirection(oldX, oldY, newX, newY: Integer): Byte;
var
  directionIndex: Byte;
  directionFound: Boolean;
  scanCode: Byte;
  deltaX: Integer;
  deltaY: Integer;
begin
  deltaX := Abs(newX - oldX);
  deltaY := Abs(newY - oldY);
  directionIndex := C_Dir.NORTH;
  directionFound := False;
  while not directionFound do begin
    case directionIndex of
      C_Dir.NORTH: begin
           directionFound := (newY <= oldY) and (deltaX * C_Dir.OCTANT_STEEP div 256 <= deltaY);
           scanCode := Ord(C_Keys.UP);
         end;
      C_Dir.EAST: begin
           directionFound := (newX >= oldX) and (deltaX * C_Dir.OCTANT_SHALLOW div 256 >= deltaY);
           scanCode := Ord(C_Keys.RIGHT);
         end;
      C_Dir.SOUTH: begin
           directionFound := (newY >= oldY) and (deltaX * C_Dir.OCTANT_STEEP div 256 <= deltaY);
           scanCode := Ord(C_Keys.DOWN);
         end;
      C_Dir.WEST: begin
           directionFound := (newX <= oldX) and (deltaX * C_Dir.OCTANT_SHALLOW div 256 >= deltaY);
           scanCode := Ord(C_Keys.LEFT);
         end;
      C_Dir.NORTHEAST: begin
           directionFound := (newY < oldY) and (newX > oldX) and
             (deltaX * C_Dir.OCTANT_STEEP div 256 >= deltaY) and (deltaX * C_Dir.OCTANT_SHALLOW div 256 <= deltaY);
           scanCode := Ord(C_Keys.PAGE_UP);
         end;
      C_Dir.SOUTHEAST: begin
           directionFound := (newY > oldY) and (newX > oldX) and
             (deltaX * C_Dir.OCTANT_STEEP div 256 >= deltaY) and (deltaX * C_Dir.OCTANT_SHALLOW div 256 <= deltaY);
           scanCode := Ord(C_Keys.PAGE_DOWN);
         end;
      C_Dir.SOUTHWEST: begin
           directionFound := (newY > oldY) and (newX < oldX) and
             (deltaX * C_Dir.OCTANT_STEEP div 256 >= deltaY) and (deltaX * C_Dir.OCTANT_SHALLOW div 256 <= deltaY);
           scanCode := Ord(C_Keys.END_KEY);
         end;
      C_Dir.NORTHWEST: begin
           directionFound := (newY < oldY) and (newX < oldX) and
             (deltaX * C_Dir.OCTANT_STEEP div 256 >= deltaY) and (deltaX * C_Dir.OCTANT_SHALLOW div 256 <= deltaY);
           scanCode := Ord(C_Keys.HOME);
         end;
    end;
    if not directionFound then
      Inc(directionIndex);
  end;
  MouseDirection := scanCode;
end;

begin
end.
