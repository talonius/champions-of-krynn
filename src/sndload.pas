{ Loads the runtime MIDI driver and the sound-effect buffers, keeps their paragraph-aligned entry addresses, and
  supplies the INT8 timer/dispatch routines. }
{$O+,F+}
unit SndLoad;

interface

uses Types, DaxIo, GDConsts, GDVars;

{ Loads music driver driverId + 1 from midi.dax and copies it to the start of a paragraph in a new buffer, which
  driverEntryPtr then addresses at offset 0; the sound-effect slot tables are cleared.
  @param(driverId The sound mode; the driver is block driverId + 1.) }
procedure LoadMidiDriver(driverId: Byte);

{ Removes the driver's timer interrupt, then frees the driver and every loaded sound-effect slot, 2 to 15. }
procedure ShutdownSound;

{ Loads block chunkId of sound.dax into a sound-effect slot, freeing what the slot held. The data is copied to the start
  of a paragraph in a zero-filled buffer, and the slot keeps that paragraph's segment for the driver.
  @param(chunkId Block number within sound.dax.)
  @param(slotId The slot, 2 to 15.) }
procedure LoadSound(chunkId, slotId: Byte);

{ Starts the sound in a slot through the driver; an empty slot does nothing.
  @param(slotId The slot.) }
procedure PlaySound(slotId: Word);

{ Saves the old timer interrupt handler and installs the one that ticks the loaded driver, speeding up the timer; the
  old handler still runs every third tick, so the BIOS clock keeps its rate. }
procedure InstallTimer;

{ Restores the old timer interrupt handler and the BIOS timer rate. }
procedure UninstallTimer;

{ Calls the loaded driver's function 1, passing the segment of a sound to play.
  @param(driverSegment Segment of the sound data, at offset 0.) }
procedure DriverDispatch(driverSegment: Word);

{ Calls the loaded driver's function 2, which stops playback. }
procedure DriverCommand;

implementation

const
  NEXT_SEGMENT_DELTA = $10000;
  SEGMENT_ONLY_MASK = $FFFF0000;

{$L SNDLOAD.OBJ}
procedure InstallTimer; external;

procedure UninstallTimer; external;

procedure DriverDispatch(driverSegment: Word); external;

procedure DriverCommand; external;

procedure LoadMidiDriver(driverId: Byte);
var
  sourceBuffer: Types.PBytes;
  payloadSize: Word;
begin
  DaxIo.LoadDax('midi', '.dax', driverId + 1, payloadSize, sourceBuffer);
  FillChar(GDVars.sfxAllocSize,
    SizeOf(GDVars.sfxAllocSize) + SizeOf(GDVars.sfxAllocPtr) + SizeOf(GDVars.sfxSegment), 0);
  GDVars.driverAllocSize := payloadSize + 16;
  GetMem(GDVars.driverEntryPtr, GDVars.driverAllocSize);
  GDVars.driverAllocPtr := GDVars.driverEntryPtr;
  if 16 - Ofs(GDVars.driverEntryPtr) > 0 then
    LongInt(GDVars.driverEntryPtr) := LongInt(GDVars.driverEntryPtr) + SndLoad.NEXT_SEGMENT_DELTA;
  LongInt(GDVars.driverEntryPtr) := LongInt(GDVars.driverEntryPtr) and SndLoad.SEGMENT_ONLY_MASK;
  Move(sourceBuffer^, GDVars.driverEntryPtr^, payloadSize);
  FreeMem(sourceBuffer, payloadSize);
end;

procedure ShutdownSound;
var slotId: Byte;
begin
  SndLoad.UninstallTimer;
  FreeMem(GDVars.driverAllocPtr, GDVars.driverAllocSize);
  for slotId := 2 to 15 do
    if GDVars.sfxAllocPtr[slotId] <> nil then
      FreeMem(GDVars.sfxAllocPtr[slotId], GDVars.sfxAllocSize[slotId]);
end;

procedure LoadSound(chunkId, slotId: Byte);
var
  sourceBuffer: Types.PBytes;
  payloadSize: Word;
  alignOffset: Byte;
begin
  if GDVars.sfxAllocPtr[slotId] <> nil then
    FreeMem(GDVars.sfxAllocPtr[slotId], GDVars.sfxAllocSize[slotId]);
  DaxIo.LoadDax('sound', '.dax', chunkId, payloadSize, sourceBuffer);
  GDVars.sfxAllocSize[slotId] := payloadSize + 16;
  GetMem(GDVars.sfxAllocPtr[slotId], GDVars.sfxAllocSize[slotId]);
  FillChar(GDVars.sfxAllocPtr[slotId]^, GDVars.sfxAllocSize[slotId], 0);
  alignOffset := 16 - Ofs(GDVars.sfxAllocPtr[slotId]^);
  if alignOffset = 16 then alignOffset := 0;
  GDVars.sfxSegment[slotId] := Seg(GDVars.sfxAllocPtr[slotId]^);
  if alignOffset > 0 then
    Inc(GDVars.sfxSegment[slotId]);
  Move(sourceBuffer^, GDVars.sfxAllocPtr[slotId]^[alignOffset], payloadSize);
  FreeMem(sourceBuffer, payloadSize);
end;

procedure PlaySound(slotId: Word);
begin
  if GDVars.sfxAllocPtr[slotId] = nil then Exit;
  SndLoad.DriverDispatch(GDVars.sfxSegment[slotId]);
end;

begin
end.
