{ Title screens and credits. The introduction loads and drives its own sound driver for its duration and hands sound
  back to the resident layer when it ends. }
{$O+,F+}
unit Intro;

interface

{ Runs the title sequence: frees the shared animation, hides the mouse and, unless sound is off, starts the intro's own
  sound driver and music, then shows the four TITLE.DAX screens, waiting 5 or 10 seconds after each group, and ends with
  the credit roll. A key pressed during any wait skips straight to the cleanup, which hands sound back to the resident
  driver and marks the game active. }
procedure Introduction;

{ Does nothing; nothing calls it. }
procedure NoopIntro;

implementation

uses Crt, Types, TextRend, Blit, GameIo, SndLoad, Mouse, Border, GDConsts, GDVars, Portrait, C_Sound;

procedure NoopIntro;
begin
end;

{ Waits up to a number of seconds or until a key is pressed, draining pending keystrokes before and after.
  @param(seconds The longest wait, in seconds.)
  @returns(True when a key ended the wait, False on timeout.) }
function DelayOrKey(seconds: Word): Boolean;
var
  startTick: LongInt;
  deadline: LongInt;
begin
  GameIo.FlushKeys;
  startTick := TextRend.getTicks;
  deadline := startTick + 100 * seconds;
  repeat
  until GameIo.InputPending or (TextRend.getTicks >= deadline);
  if TextRend.getTicks >= deadline then
    DelayOrKey := False
  else
    DelayOrKey := True;
  GameIo.FlushKeys;
end;

{ Ends the introduction: clears the screen, stops the sound and frees its buffers unless sound is off, shows the mouse
  cursor again, marks the game active so a heap failure offers a save, and clears the guard that kept the sound off
  during the introduction. }
procedure FinishIntroduction;
begin
  TextRend.clearScreen;
  if GDVars.soundMode <> C_Sound.OFF then begin
    SndLoad.DriverCommand;
    SndLoad.ShutdownSound;
  end;
  Mouse.ShowMouse;
  GDVars.soundDisabled := 0;
  GDVars.gameActive := 1;
end;

{ Draws the banded credits window and the two-column credit roll: headings in magenta or light red, names in yellow. }
procedure Credits;
begin
  Border.DrawCreditsFrame;
  TextRend.displayString(5, 1, Magenta, Black, 'based on an original story by:');
  TextRend.displayString(15, 2, Yellow, Black, 'Jim Ward');
  TextRend.displayString(4, 3, Yellow, Black, 'Victor Penman,');
  TextRend.displayString(19, 3, Magenta, Black, 'and');
  TextRend.displayString(24, 3, Yellow, Black, 'Dave Shelley');
  TextRend.displayString(2, 5, Magenta, Black, 'game created by:');
  TextRend.displayString(18, 5, LightRed, Black, 'SSI Special Projects');
  TextRend.displayString(2, 7, LightRed, Black, 'Project Director:');
  TextRend.displayString(20, 7, LightRed, Black, 'Programming');
  TextRend.displayString(2, 8, Yellow, Black, 'Victor Penman');
  TextRend.displayString(20, 8, Yellow, Black, 'Russ Brown');
  TextRend.displayString(20, 9, Yellow, Black, 'Scot Bayless');
  TextRend.displayString(2, 10, LightRed, Black, 'Graphic Arts:');
  TextRend.displayString(2, 11, Yellow, Black, 'Tom Wahl');
  TextRend.displayString(20, 11, LightRed, Black, 'Encounter Design');
  TextRend.displayString(2, 12, Yellow, Black, 'Fred Butts');
  TextRend.displayString(20, 12, Yellow, Black, 'Dave Shelley');
  TextRend.displayString(2, 13, Yellow, Black, 'Mark Johnson');
  TextRend.displayString(20, 13, Yellow, Black, 'Michael Mancuso');
  TextRend.displayString(2, 14, Yellow, Black, 'Cyrus Lum');
  TextRend.displayString(20, 14, Yellow, Black, 'Ken Humphries');
  TextRend.displayString(2, 15, Yellow, Black, 'Susan Manley');
  TextRend.displayString(2, 17, LightRed, Black, 'playtest:');
  TextRend.displayString(12, 17, Yellow, Black, 'Rick White,Don Mc Clure,');
  TextRend.displayString(2, 18, Yellow, Black, 'Mike Bench,Cliff Mann, Rick Wilson,');
  TextRend.displayString(2, 19, Yellow, Black, 'Erik Flom,James Young,Graeme Bayless');
  TextRend.displayString(2, 21, Magenta, Black, 'Musical Score:');
  TextRend.displayString(20, 21, Magenta, Black, 'Musical Driver:');
  TextRend.displayString(2, 22, Yellow, Black, 'John Halbleib');
  TextRend.displayString(20, 22, Yellow, Black, 'Electronic Arts');
end;

procedure Introduction;
var
  titlePicture: Types.PImgBuf;
  { Unused in this version; see the other implementations of this routine. }
  creditPage: Byte;
  { Unused in this version; see the other implementations of this routine. }
  keyPressedDuringCredits: Boolean;
begin
  Portrait.FreeAnimation(GDVars.bigAnim);
  GDVars.soundDisabled := 1;
  Mouse.HideMouse;
  if GDVars.soundMode <> C_Sound.OFF then begin
    SndLoad.LoadMidiDriver(GDVars.soundMode);
    SndLoad.InstallTimer;
    SndLoad.LoadSound(1, 2);
    SndLoad.PlaySound(2);
  end;
  titlePicture := nil;
  Blit.LoadPic('title', 1, False, 0, titlePicture);
  Blit.ShowPic(0, 0, titlePicture);
  Blit.FreePic(titlePicture);
  if Intro.DelayOrKey(5) then begin
    Intro.FinishIntroduction;
    Exit;
  end;
  Blit.LoadPic('title', 2, False, 0, titlePicture);
  Blit.ShowPic(0, 0, titlePicture);
  Blit.FreePic(titlePicture);
  Blit.LoadPic('title', 3, False, 0, titlePicture);
  Blit.ShowPic(5, 1, titlePicture);
  Blit.FreePic(titlePicture);
  if Intro.DelayOrKey(10) then begin
    Intro.FinishIntroduction;
    Exit;
  end;
  Blit.LoadPic('title', 4, False, 0, titlePicture);
  Blit.ShowPic(0, 1, titlePicture);
  Blit.FreePic(titlePicture);
  if Intro.DelayOrKey(10) then begin
    Intro.FinishIntroduction;
    Exit;
  end;
  TextRend.clearScreen;
  Intro.Credits;
  keyPressedDuringCredits := Intro.DelayOrKey(10);
  Intro.FinishIntroduction;
end;

begin
end.
