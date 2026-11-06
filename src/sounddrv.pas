{ The interrupt-driven PC-speaker/Tandy sound driver. }
{$F+}
unit SoundDrv;

interface

uses GDConsts, GDVars, C_Sound;

{ Sends a command to the sound driver. Nothing happens while sound is disabled, and with sound off only command 15 acts.
  0 silences both banks of voices, 1 sets the voice byte to 1, 2 to 12 play sound commandId - 1 on the Tandy voices in
  Tandy mode and on the PC speaker otherwise, 15 arms the driver's forced-exit countdown with 5000 ticks, and CMD_STOP
  silences the voices, removes the driver and marks sound inactive. Other values do nothing.
  @param(commandId The command.) }
procedure SoundCommand(commandId: Word);

{ Starts sound: remembers the sound mode and marks sound active, then, unless sound is off, installs the driver's timer
  interrupt and silences both banks of voices. }
procedure StartSound;

implementation

const
  CMD_STOP = 255;

{ The assembly driver, in SOUNDDRV.OBJ. DriverData labels the data word that driverDataPtr points to. }
{$L SOUNDDRV.OBJ}
{ Installs the driver's timer interrupt handler, saving the old one, and speeds up the timer. }
procedure InstallSoundTimer; external;

{ Restores the old timer interrupt handler and the BIOS timer rate, and silences both banks of voices. }
procedure UninstallSoundTimer; external;

{ Starts a sound on the PC-speaker voices; sound 0 silences them.
  @param(value The sound number.) }
procedure ProgramSpeakerVoices(value: Word); external;

{ Starts a sound on the Tandy voices; sound 0 silences them.
  @param(value The sound number.) }
procedure ProgramTandyVoices(value: Word); external;

{ Sets the voice byte; while it is 0 the timer interrupt keeps both banks quiet.
  @param(value The new voice byte, in its low byte.) }
procedure SetVoiceByte(value: Word); external;

{ Not code: the forced-exit countdown word that the driver's timer interrupt counts down. }
procedure DriverData; external;

procedure SoundCommand(commandId: Word);
begin
  if GDVars.soundDisabled <> 0 then Exit;
  if not (commandId in [0..15, SoundDrv.CMD_STOP]) then Exit;
  case commandId of
    0:
      if GDVars.soundMode <> C_Sound.OFF then begin
        SoundDrv.ProgramTandyVoices(0);
        SoundDrv.ProgramSpeakerVoices(0);
      end;
    1:
      if GDVars.soundMode <> C_Sound.OFF then SoundDrv.SetVoiceByte(1);
    SoundDrv.CMD_STOP:
      if GDVars.soundMode <> C_Sound.OFF then begin
        SoundDrv.ProgramTandyVoices(0);
        SoundDrv.ProgramSpeakerVoices(0);
        SoundDrv.UninstallSoundTimer;
        GDVars.soundActive := 0;
      end;
    2..12:
      if GDVars.soundMode <> C_Sound.OFF then
        if GDVars.soundMode = C_Sound.TANDY then SoundDrv.ProgramTandyVoices(commandId - 1)
        else SoundDrv.ProgramSpeakerVoices(commandId - 1);
    15:
      Word(GDVars.driverDataPtr^) := 5000;
  end;
end;

procedure StartSound;
begin
  GDVars.soundSaved := GDVars.soundMode;
  GDVars.soundActive := 1;
  if GDVars.soundMode = C_Sound.OFF then Exit;
  SoundDrv.InstallSoundTimer;
  SoundDrv.ProgramSpeakerVoices(0);
  SoundDrv.ProgramTandyVoices(0);
end;

{ Point driverDataPtr at DriverData and zero that word. }
begin
  GDVars.driverDataPtr := @SoundDrv.DriverData;
  Word(GDVars.driverDataPtr^) := 0;
end.
