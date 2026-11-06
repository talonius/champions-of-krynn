{ Portrait and animation loading and rendering. }
{$O+,F+,I-}
unit Portrait;

interface

uses Types, Blit, DaxIo, Mouse, TextRend, Border, GameIo, Debug, Crt, GDConsts, GDVars;

{ Shows a picture at a character cell with the mouse cursor hidden: an animation frame is drawn clipped into the view
  buffer one cell up and left and the view flushed to the screen, any other picture is drawn straight to the screen.
  Nothing happens for nil.
  @param(col Character column.)
  @param(row Character row.)
  @param(compositeAnimation True to draw through the view buffer.)
  @param(image The picture.) }
procedure DisplayImageBuf(col, row: Integer; compositeAnimation: Boolean; image: Types.PImgBuf);

{ Draws a portrait head straight to the screen.
  @param(col Column of the head's upper-left character cell.)
  @param(row Row of the head's upper-left character cell.)
  @param(image The head picture; nil draws nothing.) }
procedure DisplayPortraitHead(col, row: Byte; image: Types.PImgBuf);

{ Draws a portrait body straight to the screen, five character rows below the head drawn at the same cell.
  @param(col Column of the head's upper-left character cell.)
  @param(row Row of the head's upper-left character cell.)
  @param(image The body picture; nil draws nothing.) }
procedure DisplayPortraitBody(col, row: Byte; image: Types.PImgBuf);

{ Loads picture picId of <archiveName><disk>.DAX into an animation, one image buffer per frame, freeing what the
  animation held; nothing happens when that picture is the one last loaded, or for picId 255. PIC and FINAL pictures
  store each frame after the first as an XOR difference from it, and load only their first frame while animations are
  off. A frame is skipped when less than 3900 bytes of heap are free. Outside CGA, frames with a mask are recolored
  through remapFromColors and remapToColors. "Loading...Please Wait" shows meanwhile when animations are on, and "PIC
  not found" when the picture is missing.
  @param(archiveName Base name of the DAX file.)
  @param(picId Picture number within the file.)
  @param(transparency Bit 0 gives the frames a transparency mask.)
  @param(animation Receives the frames.) }
procedure LoadAnimation(archiveName: Types.TStr8; picId: Byte; transparency: Byte; var animation: Types.TAnimation);

{ Frees each frame of an animation record, clears the record and forgets the last loaded picture.
  @param(animation The animation record.) }
procedure FreeAnimation(var animation: Types.TAnimation);

{ Draws the loaded portrait head straight to the screen at a character cell and, when asked, the body five character
  rows below it.
  @param(col Character column of the head.)
  @param(row Character row of the head.)
  @param(includeBody True to draw the body as well, False for the head alone.) }
procedure DisplayPortraitBufs(col, row: Byte; includeBody: Boolean);

{ Loads a portrait head from HEAD<disk>.DAX and a body from BODY<disk>.DAX into the portrait slots, skipping an id of
  255 or one already loaded, then drains pending keystrokes. Note: a missing body also reports "head not found".
  @param(headId Head picture number.)
  @param(bodyId Body picture number.) }
procedure LoadPortraitBufs(headId, bodyId: Byte);

{ Draws a 3D sprite frame transparently into the view buffer at its origin and flushes the view. A distance outside 1 to
  3 restores the video mode, prints an error and exits to DOS.
  @param(distance The view distance, 1 to 3, which is also the frame drawn.)
  @param(animation The sprite's animation record; a missing frame draws nothing.) }
procedure Show3DSprite(distance: Byte; animation: Types.TAnimation);

{ Frees the big animation, then loads a picture from BIGPIC<disk>.DAX into the big picture buffer unless it is the one
  already loaded.
  @param(picId Picture number.) }
procedure LoadBigPic(picId: Byte);

{ Draws the window frame with its row divider and shows the big picture at cell (1, 1), with the mouse cursor hidden. }
procedure DisplayBigPic;

{ Calls the priming entry of the overlay this unit uses, so the overlay manager loads it. }
procedure PrimePortrait;

implementation

procedure PrimePortrait;
begin
  Debug.PrimeDebug;
end;

procedure DisplayImageBuf(col, row: Integer; compositeAnimation: Boolean; image: Types.PImgBuf);
begin
  if image <> nil then
    if compositeAnimation then begin
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, image, GDVars.egaDest);
      Mouse.HideMouse;
      Blit.FlushView;
      Mouse.ShowMouse;
    end else begin
      Mouse.HideMouse;
      Blit.ShowPic(col, row, image);
      Mouse.ShowMouse;
    end;
end;

procedure DisplayPortraitHead(col, row: Byte; image: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row, False, image);
end;

procedure DisplayPortraitBody(col, row: Byte; image: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row + 5, False, image);
end;

procedure LoadAnimation(archiveName: Types.TStr8; picId: Byte; transparency: Byte; var animation: Types.TAnimation);
var
  archiveSize: Word;
  archiveData: Types.PBytes;
  dataOffset: Word;
  frameIndex: Byte;
  height: Word;
  width: Word;
  diskSuffix: String[1];
  xorBase: Types.PBytes;
  xorOffset: Word;
  planeSize: Word;
  isDeltaArchive: Boolean;
  hasXorBase: Boolean;
  loadedFrames: Byte;
begin
  if ((archiveName = GDVars.picArcName) and (picId = GDVars.picArcId)) or (picId = 255) then Exit;
  if GDVars.animationsEnabled <> 0 then begin
    TextRend.printSpaces(0, 24, Black, 40);
    TextRend.displayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  end;
  Portrait.FreeAnimation(animation);
  GDVars.picArcName := archiveName;
  GDVars.picArcId := picId;
  isDeltaArchive := (archiveName = 'PIC') or (archiveName = 'FINAL');
  Str(LongInt(GDVars.currentDisk), diskSuffix);
  DaxIo.LoadDax(archiveName + diskSuffix, '.dax', picId, archiveSize, archiveData);
  if archiveSize = 0 then begin
    TextRend.displayAndPause(Yellow, Black, 'PIC not found');
    Exit;
  end;
  dataOffset := 0;
  hasXorBase := False;
  with animation do begin
    frameCount := archiveData^[dataOffset];
    Inc(dataOffset);
    currentFrame := 1;
    loadedFrames := 0;
    if (GDVars.animationsEnabled = 0) and isDeltaArchive then frameCount := 1;
    for frameIndex := 1 to frameCount do begin
      Move(archiveData^[dataOffset], frames[frameIndex].duration, SizeOf(frames[frameIndex].duration));
      Inc(dataOffset, SizeOf(frames[frameIndex].duration));
      Move(archiveData^[dataOffset], height, SizeOf(height));
      Inc(dataOffset, SizeOf(height));
      Move(archiveData^[dataOffset], width, SizeOf(width));
      Inc(dataOffset, SizeOf(width));
      if MaxAvail >= 3900 then begin
        Inc(loadedFrames);
        Blit.AllocPic(height, width, 1, transparency, frames[frameIndex].image);
        with frames[frameIndex].image^ do begin
          Move(archiveData^[dataOffset], originX, SizeOf(originX));
          Inc(dataOffset, SizeOf(originX));
          Move(archiveData^[dataOffset], originY, SizeOf(originY));
          Inc(dataOffset, 3);
          Move(archiveData^[dataOffset], map, SizeOf(map));
          Inc(dataOffset, SizeOf(map));
        end;
        if GDVars.displayMode = Types.Cga then
          planeSize := frames[frameIndex].image^.imgSize * 2 - 1
        else
          planeSize := frames[frameIndex].image^.imgSize - 1;
        if isDeltaArchive then
          if frameIndex = 1 then begin
            GetMem(xorBase, planeSize + 1);
            Move(archiveData^[dataOffset], xorBase^, planeSize + 1);
            hasXorBase := True;
          end else
            for xorOffset := dataOffset to dataOffset + planeSize do
              archiveData^[xorOffset] := archiveData^[xorOffset] xor xorBase^[xorOffset - dataOffset];
        Blit.ExpandPicFrames(archiveData, dataOffset, Boolean(transparency), 0, frames[frameIndex].image);
        if (transparency and $01 > 0) and (GDVars.displayMode <> Types.Cga) then
          Blit.RemapPic(GDConsts.remapFromColors, GDConsts.remapToColors, 0, False, frames[frameIndex].image);
        Inc(dataOffset, planeSize + 1);
      end else
        frameCount := 1;
    end;
    frameCount := loadedFrames;
  end;
  if isDeltaArchive and hasXorBase then FreeMem(xorBase, planeSize + 1);
  FreeMem(archiveData, archiveSize);
  GameIo.FlushKeys;
  if GDVars.animationsEnabled <> 0 then TextRend.printSpaces(0, 24, Black, 40);
end;

procedure FreeAnimation(var animation: Types.TAnimation);
begin
  with animation do
    for GDVars.scratchIndex := 1 to frameCount do
      Blit.FreePic(frames[GDVars.scratchIndex].image);
  FillChar(animation, SizeOf(animation), 0);
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := 255;
end;

procedure LoadPortraitBufs(headId, bodyId: Byte);
var
  diskSuffix: String[1];
begin
  Str(LongInt(GDVars.currentDisk), diskSuffix);
  if headId <> 255 then
    if (GDVars.portraits[1].fileId = 255) or (GDVars.portraits[1].fileId <> headId)
    then begin
      Blit.LoadPic('HEAD' + diskSuffix, headId, False, 0, GDVars.portraits[1].pic);
      if GDVars.portraits[1].pic = nil then TextRend.displayAndPause(Yellow, Black, 'head not found');
      GDVars.portraits[1].fileId := headId;
    end;
  if bodyId <> 255 then
    if (GDVars.portraits[2].fileId = 255) or (GDVars.portraits[2].fileId <> bodyId)
    then begin
      Blit.LoadPic('BODY' + diskSuffix, bodyId, False, 0, GDVars.portraits[2].pic);
      if GDVars.portraits[2].pic = nil then TextRend.displayAndPause(Yellow, Black, 'head not found');
      GDVars.portraits[2].fileId := bodyId;
    end;
  GameIo.FlushKeys;
end;

procedure DisplayPortraitBufs(col, row: Byte; includeBody: Boolean);
begin
  if includeBody then begin
    Portrait.DisplayPortraitHead(col, row, GDVars.portraits[1].pic);
    Portrait.DisplayPortraitBody(col, row, GDVars.portraits[2].pic);
  end else
    Portrait.DisplayImageBuf(col, row, False, GDVars.portraits[1].pic);
end;

procedure Show3DSprite(distance: Byte; animation: Types.TAnimation);
begin
  if (distance < 1) or (distance > 3) then begin
    Blit.RestoreVideoMode;
    WriteLn('Illegal range in Show3DSprite.');
    GameIo.ExitGame;
  end;
  if animation.frames[distance].image <> nil then
    with animation.frames[distance].image^ do
      Blit.BlitTileClipped(originX + 3 - 1, originY + 3 - 1, 0, 1, animation.frames[distance].image, GDVars.egaDest)
  else
    Exit;
  Blit.FlushView;
end;

procedure LoadBigPic(picId: Byte);
var
  diskSuffix: String[1];
begin
  Portrait.FreeAnimation(GDVars.bigAnim);
  if GDVars.bigPicId = picId then Exit;
  Str(LongInt(GDVars.currentDisk), diskSuffix);
  Blit.LoadPic('bigpic' + diskSuffix, picId, False, 0, GDVars.bigPicBuf);
  GDVars.bigPicId := picId;
end;

procedure DisplayBigPic;
begin
  Mouse.HideMouse;
  Border.DrawRowDivider;
  Blit.ShowPic(1, 1, GDVars.bigPicBuf);
  Mouse.ShowMouse;
end;

begin
end.
