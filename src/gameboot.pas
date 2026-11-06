{ Startup and interactive KRYNN.CFG creation/loading. It selects graphics, sound and input devices, validates the save
  path, transfers joystick calibration, initializes overlays and reserves Tandy graphics memory. All of it runs from the
  unit's initialization section. }
{$O+,F+}
{$I-}
unit GameBoot;

interface

implementation

uses Types, Crt, Dos, Overlay, DaxIo, Joystick, Blit, TextRend, GameIo, GDConsts, GDVars, C_Sound;

const
  { paragraphs reserved at the top of the heap for Tandy graphics }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 163840;
  { BIOS video function: read the current video mode into AL }
  BIOS_GET_MODE = 15;
  BIOS_MODE_CGA = 4;
  BIOS_MODE_TANDY = 9;
  BIOS_MODE_EGA = 13;
  SOUND_CMS = 0;
  SOUND_ROLAND = 1;
  SOUND_ADLIB = 2;

type
  { HeapEnd, read as words }
  THeapEndWords = record
    offset: Word;
    segment: Word;
  end;

var
  heapEndWords: THeapEndWords absolute HeapEnd;

  { GDVars.dataPath as the DirStr FSplit takes }
  fsDir: DirStr absolute GDVars.dataPath;

{ Waits for a digit key in a range and echoes it.
  @param(lowChoice The lowest digit accepted.)
  @param(highChoice The highest digit accepted.)
  @returns(The digit's value.) }
function ReadDigit(lowChoice, highChoice: Byte): Byte;
begin
  repeat
    GDVars.inputChar := ReadKey;
  until (GDVars.inputChar in ['0'..'9']) and ((Ord(GDVars.inputChar) - Ord('0')) in [lowChoice..highChoice]);
  Write(GDVars.inputChar);
  ReadDigit := Ord(GDVars.inputChar) - Ord('0');
end;

{ Resident initialization section. }
begin
  CheckBreak := False;
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  { Hook the overlay manager's read routine: GameIo keeps the original, and OverlayReadWithBeep retries it, beeping,
    until it succeeds. }
  @GDVars.previousOverlayReadVector := @OvrReadBuf;
  @OvrReadBuf := @GameIo.OverlayReadWithBeep;
  { locate the master drive from the running .EXE's path }
  FSplit(FExpand('*.exe'), fsDir, NameStr(GDVars.fsName), ExtStr(GDVars.fsExt));
  if fsDir[1] < 'C' then begin
    if fsDir[1] = 'A' then
      GDVars.masterPath := 'B:\'
    else
      GDVars.masterPath := 'A:\';
  end else
    GDVars.masterPath := fsDir;
  GDVars.driveChar := GDVars.masterPath[1];

  if not DaxIo.FileExists('krynn.cfg') then begin
    { first run: write the configuration interactively }
    Assign(GDVars.cfgFile, 'krynn.cfg');
    Rewrite(GDVars.cfgFile);
    GDVars.configIoError := IOResult;
    if GDVars.configIoError <> 0 then begin
      ClrScr;
      WriteLn('Sorry, disk A can''t be write-protected.');
      WriteLn;
      WriteLn('If these are your masters, use DISKCOPY to make duplicates.');
      Halt(1);
    end;

    ClrScr;
    Write('GRAPHICS ADAPTER TYPE:  [1] CGA  [2] EGA  [3] Tandy  ');
    GDVars.menuChoice := GameBoot.ReadDigit(1, 3);
    case GDVars.menuChoice of
      1: WriteLn(GDVars.cfgFile, 'C');
      2: WriteLn(GDVars.cfgFile, 'E');
      3: WriteLn(GDVars.cfgFile, 'T');
    end;

    ClrScr;
    WriteLn('SOUND TYPE:  [1] C/MS');
    WriteLn('             [2] Roland LAPC');
    WriteLn('             [3] AdLib');
    WriteLn('             [4] Tandy 1000');
    WriteLn('             [5] PC');
    WriteLn('             [6] Silent');
    GDVars.menuChoice := GameBoot.ReadDigit(1, 6);
    case GDVars.menuChoice of
      1: WriteLn(GDVars.cfgFile, 'C');
      2: WriteLn(GDVars.cfgFile, 'R');
      3: WriteLn(GDVars.cfgFile, 'A');
      4: WriteLn(GDVars.cfgFile, 'T');
      5: WriteLn(GDVars.cfgFile, 'P');
      6: WriteLn(GDVars.cfgFile, 'S');
    end;

    GDVars.joyOn := False;
    ClrScr;
    Write('ALTERNATE INPUT TYPE:  [1] JOYSTICK  [2] MOUSE  [3] NEITHER  ');
    GDVars.menuChoice := GameBoot.ReadDigit(1, 3);
    case GDVars.menuChoice of
      1: begin WriteLn(GDVars.cfgFile, 'J'); GDVars.joyOn := True; end;
      2: WriteLn(GDVars.cfgFile, 'M');
      3: WriteLn(GDVars.cfgFile, 'N');
    end;

    ClrScr;
    GDVars.defaultPath := GDVars.masterPath + 'SAVE';
    Write('PATH TO SAVE DATA (DEFAULT - ' + GDVars.defaultPath + '):  ');
    ReadLn(GDVars.savePath);
    GDVars.savePath[1] := UpCase(GDVars.savePath[1]);
    if (Length(GDVars.savePath) < 4) or (GDVars.savePath[2] <> ':')
       or ((GDVars.savePath[1] in ['A'..'B']) and (GDVars.savePath[1] = fsDir[1]))
       or not (GDVars.savePath[1] in ['A'..'P']) then begin
      GDVars.savePath := GDVars.defaultPath;
      WriteLn('USING DEFAULT PATH: ' + GDVars.savePath);
      Delay(2000);
    end;
    for GDVars.configIndex := 1 to Length(GDVars.savePath) do
      GDVars.savePath[GDVars.configIndex] := UpCase(GDVars.savePath[GDVars.configIndex]);
    if GDVars.savePath[Length(GDVars.savePath)] <> '\' then
      GDVars.savePath := GDVars.savePath + '\';
    WriteLn(GDVars.cfgFile, GDVars.savePath);
    WriteLn(GDVars.cfgFile, 'F');
    Joystick.CalibrateJoystick;
    for GDVars.configIndex := 0 to 6 do begin
      WriteLn(GDVars.cfgFile, GDVars.joyCalib[1].x[GDVars.configIndex]);
      WriteLn(GDVars.cfgFile, GDVars.joyCalib[1].y[GDVars.configIndex]);
    end;
    Close(GDVars.cfgFile);
  end;

  { read the configuration back into the runtime state }
  ClrScr;
  WriteLn('TANDY 1000 USERS - Make sure NUMLOCK is on.');
  Delay(2000);
  Assign(GDVars.cfgFile, 'krynn.cfg');
  Reset(GDVars.cfgFile);
  ReadLn(GDVars.cfgFile, GDVars.inputChar);
  GDVars.vregs.ah := GameBoot.BIOS_GET_MODE;
  Intr($10, Registers(GDVars.vregs));
  GDVars.savedVideoMode := GDVars.vregs.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;
  case GDVars.inputChar of
    'E': begin
      GDVars.displayMode := Types.Ega;
      Blit.SetVideoMode(GameBoot.BIOS_MODE_EGA);
      GDVars.curEgaPage := 0;
      GDVars.pageNum := 0;
      TextRend.setupEgaCurrentPage(GDVars.curEgaPage);
      TextRend.setupEgaOtherPage(GDVars.pageNum);
    end;
    'T': begin
      GDVars.displayMode := Types.Tandy;
      GDVars.gfxReserve := Ptr(heapEndWords.segment - GameBoot.GFX_RESERVE_PARAS, heapEndWords.offset);
      { Lower HeapEnd so the heap stays clear of the top $400 paragraphs. }
      HeapEnd := GDVars.gfxReserve;
      Blit.SetVideoMode(GameBoot.BIOS_MODE_TANDY);
    end;
    else begin
      GDVars.displayMode := Types.Cga;
      Blit.SetVideoMode(GameBoot.BIOS_MODE_CGA);
    end;
  end;
  if GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then
    OvrSetBuf(GameBoot.OVERLAY_BUF_BYTES)
  else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf - MemAvail,
            ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;
  ReadLn(GDVars.cfgFile, GDVars.inputChar);
  case GDVars.inputChar of
    'C': GDVars.soundMode := GameBoot.SOUND_CMS;
    'R': GDVars.soundMode := GameBoot.SOUND_ROLAND;
    'A': GDVars.soundMode := GameBoot.SOUND_ADLIB;
    'T': GDVars.soundMode := C_Sound.TANDY;
    'P': GDVars.soundMode := C_Sound.SPEAKER;
    else GDVars.soundMode := C_Sound.OFF;
  end;
  ReadLn(GDVars.cfgFile, GDVars.inputChar);
  case GDVars.inputChar of
    'J': begin GDVars.joyOn := True; GDVars.mouseOn := False; end;
    'M': begin GDVars.mouseOn := True; GDVars.joyOn := False; end;
    'N': begin GDVars.mouseOn := False; GDVars.joyOn := False; end;
  end;
  ReadLn(GDVars.cfgFile, GDVars.saveDir);
  ReadLn(GDVars.cfgFile, GDVars.inputChar);
  if GDVars.inputChar = 'F' then
    GDVars.fullIntro := True
  else
    GDVars.fullIntro := False;
  Joystick.ProbeJoystick;
  if GDVars.joyOn then
    for GDVars.configIndex := 0 to 6 do begin
      ReadLn(GDVars.cfgFile, GDVars.joyCalib[1].x[GDVars.configIndex]);
      ReadLn(GDVars.cfgFile, GDVars.joyCalib[1].y[GDVars.configIndex]);
    end;
  Close(GDVars.cfgFile);
end.
