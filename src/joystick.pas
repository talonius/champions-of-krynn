{ Game-port joystick driver and calibration. ReadJoystick is the assembly routine in JOYSTICK.OBJ. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Joystick;

interface

uses Types, Crt, GDConsts, GDVars;

{ Clears both calibration records; when the joystick is enabled, keeps it enabled only if joystick 1 can be read. }
procedure ProbeJoystick;

{ Reads a joystick and places each axis among its calibrated boundaries 1..5, then looks the column and row up in the
  zone map.
  @param(joy Joystick 1 or 2.)
  @returns(The zone from the zone map, or the center zone when the joystick is off or cannot be read.) }
function JoyZone(joy: Byte): Byte;

{ Tells whether a joystick button is pressed. Joystick 1's buttons are bits 0 and 1 of the button byte, joystick 2's
  bits 2 and 3; another joystick or button number reads as not pressed.
  @param(joy Joystick 1 or 2.)
  @param(button Button 1 or 2.)
  @returns(True when the button is down; False when the joystick is off or cannot be read.) }
function JoyButton(joy, button: Byte): Boolean;

{ Reads joystick 1 as input: a pressed button and the stick's zone.
  @param(button Receives 2 when button 2 is down, else 1 when button 1 is down, else 0.)
  @param(zone Receives the stick's zone, from JoyZone.) }
procedure GetJoystick(var button: Integer; var zone: Byte);

{ Calibrates joystick 1 and enables it. The center is the average of 20 readings; the player then holds the stick at the
  upper-left and lower-right extremes with button 1 down, each taken as the extreme of 20 readings, and the boundaries
  lie a third and two thirds of the way from each extreme to the center. 20000 polls without a press, or a failed read,
  abort the calibration with a message. Does nothing when the joystick cannot be read. }
procedure CalibrateJoystick;

{ Reads a joystick from the game port, timing each axis's capacitor discharge.
  @param(joy Joystick 1 or 2; any other number fails.)
  @param(xRaw Receives the X axis count.)
  @param(yRaw Receives the Y axis count.)
  @param(buttons Receives all four button bits of both joysticks, inverted so a set bit is a pressed button and shifted
    to the low nibble.)
  @returns(True when the read succeeded; False for a bad joystick number or when an axis times out.) }
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;

implementation

const
  PRIMARY_JOYSTICK = 1;
  FIRST_AXIS_BOUNDARY = 1;
  LAST_AXIS_BOUNDARY = 5;
  CENTER_POINT = 3;
  MAX_POINT = 6;
  CALIBRATION_SAMPLES = 20;
  CENTER_ZONE = 8;
  BUTTON_1_MASK = $01;
  BUTTON_2_MASK = $02;
  BUTTON_3_MASK = $04;
  BUTTON_4_MASK = $08;

{$L JOYSTICK.OBJ}
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;
  external;

procedure ProbeJoystick;
var
  rawX: Word;
  rawY: Word;
  buttons: Byte;
begin
  FillChar(GDVars.joyCalib, SizeOf(GDVars.joyCalib), 0);
  if GDVars.joyOn then
    GDVars.joyOn := Joystick.ReadJoystick(Joystick.PRIMARY_JOYSTICK, rawX, rawY, buttons);
end;

function JoyZone(joy: Byte): Byte;
var
  rawX: Word;
  rawY: Word;
  zoneColumn: Integer;
  zoneRow: Integer;
  buttons: Byte;
  { Unused in this version; see the other implementations of this routine. }
  boundaryIndex: Integer;
begin
  JoyZone := Joystick.CENTER_ZONE;
  if not GDVars.joyOn then
    Exit;
  if not Joystick.ReadJoystick(joy, rawX, rawY, buttons) then
    Exit;
  zoneColumn := 0;
  for GDVars.scratchIndex := Joystick.FIRST_AXIS_BOUNDARY to Joystick.LAST_AXIS_BOUNDARY do
    if GDVars.joyCalib[joy].x[GDVars.scratchIndex] < rawX then
      zoneColumn := GDVars.scratchIndex;
  zoneRow := 0;
  for GDVars.scratchIndex := Joystick.FIRST_AXIS_BOUNDARY to Joystick.LAST_AXIS_BOUNDARY do
    if GDVars.joyCalib[joy].y[GDVars.scratchIndex] < rawY then
      zoneRow := GDVars.scratchIndex;
  JoyZone := GDConsts.zoneMap[zoneRow, zoneColumn];
end;

function JoyButton(joy, button: Byte): Boolean;
var
  mask: Byte;
  rawX: Word;
  rawY: Word;
  buttons: Byte;
begin
  JoyButton := False;
  if not GDVars.joyOn then
    Exit;
  mask := 0;
  buttons := 0;
  if Joystick.ReadJoystick(joy, rawX, rawY, buttons) then
    case joy of
      1: case button of
           1: mask := Joystick.BUTTON_1_MASK;
           2: mask := Joystick.BUTTON_2_MASK;
         end;
      2: case button of
           1: mask := Joystick.BUTTON_3_MASK;
           2: mask := Joystick.BUTTON_4_MASK;
         end;
    end;
  JoyButton := (buttons and mask) > 0;
end;

procedure GetJoystick(var button: Integer; var zone: Byte);
begin
  button := 0;
  if Joystick.JoyButton(Joystick.PRIMARY_JOYSTICK, 2) then
    button := 2
  else if Joystick.JoyButton(Joystick.PRIMARY_JOYSTICK, 1) then
    button := 1;
  zone := Joystick.JoyZone(Joystick.PRIMARY_JOYSTICK);
end;

procedure CalibrateJoystick;
var
  sumX: Word;
  sumY: Word;
  readOk: Byte;
  rawX: Word;
  rawY: Word;
  { Unused in this version; see the other implementations of this routine. }
  sampleIndex: Byte;
  pollCount: Word;
  buttons: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.joyOn then
    Exit;
  sumX := 0;
  sumY := 0;
  for pollCount := 1 to Joystick.CALIBRATION_SAMPLES do begin
    readOk := Byte(Joystick.ReadJoystick(Joystick.PRIMARY_JOYSTICK, rawX, rawY, buttons));
    Inc(sumX, rawX);
    Inc(sumY, rawY);
  end;
  GDVars.joyCalib[Joystick.PRIMARY_JOYSTICK].x[Joystick.CENTER_POINT] := sumX div Joystick.CALIBRATION_SAMPLES;
  GDVars.joyCalib[Joystick.PRIMARY_JOYSTICK].y[Joystick.CENTER_POINT] := sumY div Joystick.CALIBRATION_SAMPLES;
  { upper-left corner }
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme upper left position and press BUTTON #1.');
    pollCount := 0;
    repeat
      readOk := Byte(Joystick.ReadJoystick(Joystick.PRIMARY_JOYSTICK, rawX, rawY, buttons));
      Inc(pollCount);
    until (pollCount > 20000) or ((readOk <> 0) and ((buttons and Joystick.BUTTON_1_MASK) <> 0));
    if pollCount > 20000 then begin
      ClrScr;
      WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    sumX := 65535;
    sumY := 65535;
    for GDVars.scratchIndex := 1 to Joystick.CALIBRATION_SAMPLES do begin
      if Joystick.ReadJoystick(Joystick.PRIMARY_JOYSTICK, rawX, rawY, buttons) then begin
        if (buttons and Joystick.BUTTON_1_MASK) <> 0 then begin
          if rawX < sumX then
            sumX := rawX;
          if rawY < sumY then
            sumY := rawY;
        end;
      end else begin
        ClrScr;
        WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
    end;
  until readOk <> 0;
  GDVars.joyCalib[1].x[0] := sumX;
  GDVars.joyCalib[1].x[1] := GDVars.joyCalib[1].x[0] +
    (GDVars.joyCalib[1].x[Joystick.CENTER_POINT] - GDVars.joyCalib[1].x[0]) div 3;
  GDVars.joyCalib[1].x[2] := GDVars.joyCalib[1].x[0] +
    (GDVars.joyCalib[1].x[Joystick.CENTER_POINT] - GDVars.joyCalib[1].x[0]) * 2 div 3;
  GDVars.joyCalib[1].y[0] := sumY;
  GDVars.joyCalib[1].y[1] := GDVars.joyCalib[1].y[0] +
    (GDVars.joyCalib[1].y[Joystick.CENTER_POINT] - GDVars.joyCalib[1].y[0]) div 3;
  GDVars.joyCalib[1].y[2] := GDVars.joyCalib[1].y[0] +
    (GDVars.joyCalib[1].y[Joystick.CENTER_POINT] - GDVars.joyCalib[1].y[0]) * 2 div 3;
  repeat
  until not Joystick.JoyButton(Joystick.PRIMARY_JOYSTICK, 1);
  { lower-right corner }
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme lower right position and press BUTTON #1.');
    pollCount := 0;
    repeat
      readOk := Byte(Joystick.ReadJoystick(Joystick.PRIMARY_JOYSTICK, rawX, rawY, buttons));
      Inc(pollCount);
    until (pollCount > 20000) or ((readOk <> 0) and ((buttons and Joystick.BUTTON_1_MASK) <> 0));
    if pollCount > 20000 then begin
      ClrScr;
      WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    sumX := 0;
    sumY := 0;
    for GDVars.scratchIndex := 1 to Joystick.CALIBRATION_SAMPLES do begin
      if Joystick.ReadJoystick(Joystick.PRIMARY_JOYSTICK, rawX, rawY, buttons) then begin
        if (buttons and Joystick.BUTTON_1_MASK) <> 0 then begin
          if rawX > sumX then
            sumX := rawX;
          if rawY > sumY then
            sumY := rawY;
        end;
      end else begin
        ClrScr;
        WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
    end;
  until readOk <> 0;
  GDVars.joyCalib[1].x[Joystick.MAX_POINT] := sumX;
  GDVars.joyCalib[1].x[4] := GDVars.joyCalib[1].x[Joystick.CENTER_POINT] +
    (GDVars.joyCalib[1].x[Joystick.MAX_POINT] - GDVars.joyCalib[1].x[Joystick.CENTER_POINT]) div 3;
  GDVars.joyCalib[1].x[5] := GDVars.joyCalib[1].x[Joystick.CENTER_POINT] +
    (GDVars.joyCalib[1].x[Joystick.MAX_POINT] - GDVars.joyCalib[1].x[Joystick.CENTER_POINT]) * 2 div 3;
  GDVars.joyCalib[1].y[Joystick.MAX_POINT] := sumY;
  GDVars.joyCalib[1].y[4] := GDVars.joyCalib[1].y[Joystick.CENTER_POINT] +
    (GDVars.joyCalib[1].y[Joystick.MAX_POINT] - GDVars.joyCalib[1].y[Joystick.CENTER_POINT]) div 3;
  GDVars.joyCalib[1].y[5] := GDVars.joyCalib[1].y[Joystick.CENTER_POINT] +
    (GDVars.joyCalib[1].y[Joystick.MAX_POINT] - GDVars.joyCalib[1].y[Joystick.CENTER_POINT]) * 2 div 3;
  GDVars.joyOn := True;
end;

begin
end.
