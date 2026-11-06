{ The out-of-memory handler. While a game is active it offers a save and repeats until one succeeds; otherwise it
  reports that the program is exiting. Either way it then exits through GameIo. A zero-size request returns at once. }
{$O+,F+}
unit HeapErr;

interface

{ Installed as HeapError, so the heap manager calls it when an allocation fails. For a nonzero request it shows an
  insufficient-memory warning; while a game is active it runs the save menu and repeats until a save sets the
  recently-saved flag, otherwise it says the program is exiting. Either way it then quits through GameIo.ExitGame. A
  zero-size request returns at once. Note: the result is never assigned.
  @param(size Bytes requested; 0 does nothing.)
  @returns(Nothing: the result is never assigned.) }
function HeapErrorHandler(size: Word): Integer;

implementation

uses TextRend, GameIo, SaveLoad, Crt, GDConsts, GDVars;

function HeapErrorHandler(size: Word): Integer;
var
  exitRequested: Byte;
begin
  if size > 0 then begin
    exitRequested := 0;
    repeat
      TextRend.displayAndPause(Yellow, Black, 'WARNING: Insufficient Memory');
      if GDVars.gameActive <> 0 then begin
        SaveLoad.SaveGame;
        exitRequested := GDVars.recentlySaved;
      end else begin
        exitRequested := 1;
        TextRend.displayAndPause(Yellow, Black, 'Insufficient Memory. Exiting Program');
      end;
    until exitRequested <> 0;
    GameIo.ExitGame;
  end;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
