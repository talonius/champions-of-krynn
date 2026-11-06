{ Keyboard input and the debug log: a unified ReadGameKey/InputPending/flush layer that synthesizes keystrokes from the
  mouse and joystick drivers, the Ctrl-S sound toggle, and a Ctrl-key debug mode (enabled by the "Woof" command-line
  code) that toggles a debug.txt character-record dumper. The unit also holds the shutdown routine and the overlay-read
  retry callback. }
{$O+,F+}
{$I-}
unit GameIo;

interface

uses Types, Dos, GDConsts, GDVars;

{ Ends the program: hides and resets the mouse, restores the saved sound mode, stops the resident sound driver (or,
  while the intro's own driver holds sound, shuts that one down), restores the startup video mode, closes the debug log
  if it is open, and halts. }
procedure ExitGame;

{ Returns the next key. A waiting key is read at once. Otherwise the mouse, or the joystick when there is no mouse, is
  polled until it gives input or a key is pressed: a left or right mouse button gives Enter or Escape, a joystick
  direction gives its key from scancodeTable, and joystick buttons 1 and 2 give Enter and Escape; a key pressed
  meanwhile wins. With neither device it waits for a key, or returns #0 while the demo runs. Ctrl-S turns the sound off
  or back on unless sound is disabled. With Woof as the first parameter, Ctrl-D turns the debug log (debug.txt) on or
  off, Ctrl-Z writes the effects of each party member to it while it is open, and Ctrl-C quits.
  @returns(The key, or #0 in the demo when none was waiting.) }
function ReadGameKey: Char;

{ Tells whether input is waiting.
  @returns(True when a key is waiting, a mouse button is down, or -- without a mouse -- a joystick button is down or the
    stick is out of the center.) }
function InputPending: Boolean;

{ Reads and discards every key waiting in the keyboard buffer. }
procedure FlushKeys;

{ Reads and discards one waiting input through ReadGameKey, so its control-key commands still work. }
procedure DiscardPendingKeys;

{ Reads an overlay for the overlay manager, as installed by GameBoot: calls the saved reader until that succeeds,
  beeping (4000 Hz, 20 ms) after each failure.
  @param(arg The overlay to read, passed to the saved reader.)
  @returns(0, success.) }
function OverlayReadWithBeep(arg: Word): Word;

implementation

uses Crt, Mouse, SndLoad, Joystick, SoundDrv, C_Sound, C_Keys, C_Video;

const
  INPUT_ACCEPT = 1;
  INPUT_CANCEL = 2;
  KEY_CTRL_C = #3;
  KEY_CTRL_D = #4;
  KEY_CTRL_S = #19;
  KEY_CTRL_Z = #26;

procedure ExitGame;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  Mouse.HideMouse;
  Mouse.ResetMouse;
  GDVars.soundMode := GDVars.soundSaved;
  if GDVars.soundDisabled <> 0 then begin
    if GDVars.soundMode <> C_Sound.OFF then begin
      SndLoad.DriverCommand;
      SndLoad.ShutdownSound;
    end;
  end else
    SoundDrv.SoundCommand(GDConsts.sndStop);
  GDVars.vregs.ah := C_Video.BIOS_SET_MODE;
  GDVars.vregs.al := GDVars.savedVideoMode;
  Intr($10, Registers(GDVars.vregs));
  if GDVars.debugActive <> 0 then
    Close(GDVars.debugFile);
  Halt(0);
end;

{ Writes one line per effect on a creature to the debug log: its name and the effect's id.
  @param(p The creature.) }
procedure DumpSpells(p: Types.PCharRecord);
var cur: Types.PEffectRec;
begin
  cur := p^.effects;
  while cur <> nil do begin
    WriteLn(GDVars.debugFile, 'who: ', p^.name, '  sp#: ', cur^.id);
    cur := cur^.next;
  end;
end;

function ReadGameKey: Char;
var
  key: Char;
  who: Types.PCharRecord;
  inputState: record flag: Byte; scan: Byte; special: Integer end;
  { Unused in this version; see the other implementations of this routine. }
  paramIndex: Byte;

  { Waits for a key or for joystick input, turning a button into Enter or Escape and a stick zone into its keypad key. }
  procedure TranslateJoystick;
  begin
    inputState.special := 0;
    inputState.flag := 0;
    while not (KeyPressed or (inputState.flag <> 0)) do begin
      Joystick.GetJoystick(inputState.special, inputState.scan);
      if (inputState.scan < 8) or Boolean(inputState.special <> 0) then begin
        if inputState.scan < 8 then
          key := Char(GDConsts.scancodeTable[inputState.scan])
        else
          case inputState.special of
            GameIo.INPUT_ACCEPT: key := C_Keys.ENTER;
            GameIo.INPUT_CANCEL: key := C_Keys.ESCAPE;
          end;
        inputState.flag := 1;
      end;
    end;
  end;

  { Waits for a key or a mouse button, turning the button into Enter or Escape and noting the mouse click. }
  procedure TranslateMouse;
  begin
    inputState.special := 0;
    inputState.flag := 0;
    while not (KeyPressed or (inputState.flag <> 0)) do begin
      Mouse.GetMouse(inputState.special, GDVars.mouseX, GDVars.mouseY);
      if inputState.special <> 0 then begin
        case inputState.special of
          GameIo.INPUT_ACCEPT: key := C_Keys.ENTER;
          GameIo.INPUT_CANCEL: key := C_Keys.ESCAPE;
        end;
        GDVars.mouseButtonSeen := 1;
        inputState.flag := 1;
      end;
    end;
  end;

begin
  GDVars.mouseButtonSeen := 0;
  if KeyPressed then
    key := ReadKey
  else if GDVars.joyOn or GDVars.mouseOn then begin
    if GDVars.mouseOn then
      TranslateMouse
    else
      TranslateJoystick;
    if KeyPressed then
      key := ReadKey;
  end else begin
    if GDVars.demoFlag <> 0 then
      key := #0
    else
      key := ReadKey;
  end;

  if (key = GameIo.KEY_CTRL_S) and (GDVars.soundDisabled = 0) then begin
    if GDVars.soundMode <> C_Sound.OFF then begin
      GDVars.soundSaved := GDVars.soundMode;
      SoundDrv.SoundCommand(GDConsts.sndSilence);
      GDVars.soundMode := C_Sound.OFF;
    end else if GDVars.soundSaved in [C_Sound.TANDY, C_Sound.SPEAKER] then begin
      GDVars.soundMode := GDVars.soundSaved;
      SoundDrv.SoundCommand(GDConsts.sndOutputOn);
    end;
  end;

  if ParamStr(1) = 'Woof' then
    case key of
      GameIo.KEY_CTRL_D:
        begin
          GDVars.debugActive := Ord(GDVars.debugActive = 0);
          if GDVars.debugActive <> 0 then begin
            Assign(GDVars.debugFile, 'debug.txt');
            Rewrite(GDVars.debugFile);
          end else
            Close(GDVars.debugFile);
        end;
      GameIo.KEY_CTRL_Z:
        if GDVars.debugActive <> 0 then begin
          who := GDVars.partyHead;
          while who <> nil do begin
            GameIo.DumpSpells(who);
            who := who^.next;
          end;
        end;
      GameIo.KEY_CTRL_C:
        GameIo.ExitGame;
    end;

  ReadGameKey := key;
end;

function InputPending: Boolean;
var special: Integer; scan: Byte;
begin
  InputPending := KeyPressed;
  if GDVars.joyOn or GDVars.mouseOn then
    if GDVars.mouseOn then begin
      Mouse.GetMouse(special, GDVars.mouseX, GDVars.mouseY);
      InputPending := KeyPressed or Boolean(special <> 0);
    end else begin
      Joystick.GetJoystick(special, scan);
      InputPending := KeyPressed or Boolean(special > 0) or Boolean(scan < 8);
    end;
end;

procedure FlushKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  while KeyPressed do
    c := ReadKey;
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  if GameIo.InputPending then
    c := GameIo.ReadGameKey;
end;

function OverlayReadWithBeep(arg: Word): Word;
begin
  while GDVars.previousOverlayReadVector(arg) <> 0 do begin
    Sound(4000);
    Delay(20);
    NoSound;
  end;
  OverlayReadWithBeep := 0;
end;

begin
end.
