{ The out-of-memory handler. While a game is active it offers a save and repeats until one succeeds; otherwise it
  reports that the program is exiting. Either way it then exits through GameIo. }
{$O+,F+}
unit HeapErr;

interface

{ Warns that memory is short. While a game is in progress it saves the game, warning again until the saved flag shows
  the save went through; otherwise it says it is exiting. Note: the saved flag is not cleared before the save, so a flag
  still set by an earlier save ends the loop even if this save failed.
  @param(size Unused.)
  @returns(Never: ExitGame halts the program.) }
function HeapErrorHandler(size: Word): Integer;

{ Empty routine with no callers. }
procedure NoopHeapErr;

implementation

uses TextRend, GameIo, SaveLoad, Crt, GDConsts, GDVars;

procedure NoopHeapErr;
begin
end;

function HeapErrorHandler(size: Word): Integer;
var
  exitRequested: Byte;
begin
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

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
