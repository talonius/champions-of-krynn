{ DAX picture conversion, compositing, mirroring and display. CGA uses packed 2-bpp cells, EGA uses four planar bytes,
  and Tandy uses packed 4-bpp cells. Nine linked near leaves implement the mode-specific copy/mask/clip paths. }
{$O+,F+}
unit Blit;

interface

uses Types, DaxIo, GDConsts, GDVars, Dos, GameIo, Mouse, C_Ega, C_Video;

type
  { An 8-pixel chunk as stored in a picture: two pixels to a byte, the first in the high nibble. }
  TChunk = array[0..3] of Byte;

{ Returns the transparency mask of an 8-pixel chunk. A transparent color above 15 can match a high nibble but never a
  low one.
  @param(transpColor The color that is transparent, 0..15.)
  @param(chunk The chunk's eight pixels, two to a byte, the first in the high nibble of the first byte.)
  @returns(A bit set for each pixel of the transparent color, bit 7 for the first pixel down to bit 0 for the last.) }
function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;

{ Translates a color through a picture's color map. The map packs two colors per byte: even colors in the high nibble,
  odd colors in the low nibble.
  @param(color Color index, 0..15.)
  @param(map Color map of the picture.)
  @returns(The mapped color, 0..15.) }
function SrcNibble(color: Byte; map: Types.TColorMap): Byte;

{ Switches the display to a BIOS video mode, remembering the mode it replaces so RestoreVideoMode can go back. The BIOS
  result is not checked, so an unsupported mode fails silently while the current-mode bookkeeping still records it.
  @param(mode BIOS INT 10h mode number to select.) }
procedure SetVideoMode(mode: Byte);

{ Returns to the mode that was current before the last SetVideoMode call. That call saves the mode it replaces, so two
  calls in a row toggle between two modes. }
procedure RestoreVideoMode;

{ Loads a picture from a .dax file into a new image buffer in the active display mode's layout, freeing any buffer the
  picture already holds. If the DAX block is empty, the picture is left nil. Otherwise the raw block is released after
  conversion, and pending keystrokes are drained before returning.
  @param(name Base file name, without the .dax extension.)
  @param(fileId Block number within the file.)
  @param(hasMask True to give the picture a transparency mask.)
  @param(transpColor Color index treated as transparent in that mask.)
  @param(pic Receives the new buffer.) }
procedure LoadPic(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);

{ Converts raw 4-bit artwork into the active display mode's layout, filling an allocated image buffer and, when the
  buffer has one, its transparency mask. CGA produces two pixel bytes and two mask bytes per eight-pixel cell; EGA
  produces four plane bytes and repeats its one-byte mask over all four; Tandy copies the pixels unchanged and derives
  its mask in place. Transparent pixels are cleared in the pixel data, so masked drawing can keep the background and OR
  the graphic in. CGA and EGA OR into the pixel data and rely on AllocPic's zero fill.
  @param(imgData Raw block holding the artwork.)
  @param(srcOff Offset of the first pixel byte in imgData, just past the picture header.)
  @param(hasMask Unused; a mask is built whenever the buffer has one.)
  @param(transpColor Color index treated as transparent.)
  @param(pic Destination buffer, sized by AllocPic; nothing happens if nil.) }
procedure ExpandPicFrames(imgData: Types.PBytes; srcOff: Word; hasMask: Boolean; transpColor: Byte;
                          pic: Types.PImgBuf);

{ Draws one frame of a graphic into a buffer at a character-cell position with the display mode's assembly blitter
  (BlitCellCga or BlitCellCgaMasked for CGA, BlitCellEga or BlitCellEgaMasked for EGA, BlitCellTandy or
  BlitCellTandyMasked for Tandy), marking the touched scanlines dirty for FlushView. Nothing is clipped, so the frame
  must fit inside dest.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects masked drawing, which keeps the background where the mask is set; ignored when gfx has no
    mask.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Draws one frame of a graphic like BlitTileCell, but clipped against the edges of dest with the BlitClippedCga,
  BlitClippedEga or BlitClippedTandy blitter; a frame lying entirely off dest is skipped. When drawing masked with bit 2
  of flag set, the destination bytes about to be covered are saved to the save-under buffer first. Note: an opaque frame
  cut at the left or right edge is drawn with its rows out of step.
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Reverses the bit order of a byte, reflecting eight EGA pixels (one plane byte or mask byte) left to right.
  @param(value Byte to reflect.)
  @returns(The byte with bits 0..7 swapped with bits 7..0.) }
function MirrorBits(value: Byte): Byte;

{ Reverses the order of the eight 2-bit CGA pixels packed in a word, reflecting them left to right.
  @param(value Two CGA pixel bytes of one cell.)
  @returns(The word with its pixel order reversed.) }
function MirrorPairs(value: Word): Word;

{ Swaps the two 4-bit Tandy pixels of a byte, reflecting them left to right.
  @param(value Byte holding two pixels.)
  @returns(The byte with its nibbles exchanged.) }
function MirrorNibbles(value: Byte): Byte;

{ Writes a left-right mirror image of the first frame of src into dst, with src's color map and, when src has one, its
  transparency mask. dst must already have src's frame size and must have a mask if src does.
  @param(src Graphic to mirror; nothing happens if nil.)
  @param(dst Buffer receiving the mirror image; nothing happens if nil.) }
procedure MirrorPic(src, dst: Types.PImgBuf);

{ Copies a rectangle of video memory into the first frame of a picture, the reverse of ShowPic. On EGA each plane is
  read separately through the graphics controller's read-map register.
  @param(col Left edge, in character columns.)
  @param(row Top edge, in character rows of eight scanlines.)
  @param(pic Picture receiving the pixels; its width and height give the rectangle. Nothing happens if nil.) }
procedure GrabPic(col, row: Integer; pic: Types.PImgBuf);

{ Draws the first frame of a picture straight to video memory at a character-cell position, bypassing the view buffer
  and its dirty-span staging. No clipping or transparency is applied. CGA and Tandy copy whole rows through the segment
  tables; EGA writes each of the four planes separately through the sequencer map mask.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(pic Picture to show; nothing happens if nil.) }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);

{ Copies each dirty span of the view buffer to the screen, then clears the span tables; the mouse cursor is hidden
  meanwhile. Span slot n is view scanline n, shown at screen scanline n + 8, one character column in. On EGA each span
  is first written plane by plane to an off-screen page (EGA_STAGE_SEG), then copied to the visible page with the
  graphics controller in latch-copy write mode; normal write mode is restored afterwards. }
procedure FlushView;

{ Recolors a picture: in each slot 0..15 where the two color tables differ, pixels of the slot's source color become its
  replacement color. Matches are tested against the original pixels, not the partly recolored result, so remaps do not
  cascade and two colors can be swapped. The work is done in a temporary buffer that is copied back at the end. Note: a
  negative frame is meant to remap each frame, but the per-color loop resets the frame count to one, so frame 0 alone is
  remapped.
  @param(fromColors Colors to replace, by slot.)
  @param(toColors Replacement colors, by slot.)
  @param(frame Frame to remap; a negative value remaps frame 0.)
  @param(isDithered True to recolor about one in four matching pixels, chosen at random.)
  @param(pic Picture changed in place; nothing happens if nil.) }
procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);

{ Allocates a zero-filled image buffer for a number of frames in the active display mode's layout, optionally with a
  zero-filled transparency mask of the same size. A frame takes two bytes per cell on each scanline on CGA, and four on
  EGA and Tandy.
  @param(height Frame height, in scanlines.)
  @param(width Frame width, in eight-pixel cells.)
  @param(count Number of frames.)
  @param(flag Bit 0 requests a transparency mask.)
  @param(pic Receives the new buffer.) }
procedure AllocPic(height, width: Word; count: Byte; flag: Byte; var pic: Types.PImgBuf);

{ Releases an image buffer and its transparency mask, if any, and sets the pointer to nil. Does nothing if the pointer
  is already nil.
  @param(pic Buffer to free; nil on return.) }
procedure FreePic(var pic: Types.PImgBuf);

{ Fills a rectangle of a buffer with one solid color and marks the touched scanlines dirty for FlushView. The left and
  right edges are clipped to the buffer, and so is the bottom when the top edge is not negative. When the top edge is
  negative the fill starts at the top scanline and covers one row more than remain visible, without clipping the bottom.
  @param(x Left edge, in character columns; may be negative.)
  @param(y Top edge, in scanlines; may be negative.)
  @param(width Rectangle width, in eight-pixel cells.)
  @param(height Rectangle height, in scanlines.)
  @param(color Color to fill with, 0..15; CGA translates it through the color map.)
  @param(colorMap Color map used on CGA.)
  @param(pic Buffer filled, normally the view buffer; nothing happens if nil.) }
procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap;
                      pic: Types.PImgBuf);

implementation

const
  { Sequencer reg 2 = Map Mask (which planes writes hit) }
  SEQ_MAP_MASK_REG = 2;
  { GC reg 4 = Read Map Select (which plane a CPU read returns) }
  GC_READ_MAP_REG = 4;
  { GC reg 5 = Mode register }
  GC_MODE_REG = 5;
  { write-mode 0: normal (restore after a latch copy) }
  GC_WRITE_MODE_0 = 0;
  { write-mode 1: CPU write stores the 4 latched planes (a 4-plane block copy through the latches) }
  GC_WRITE_MODE_1 = 1;
  { off-screen planar staging area, 8 KB above the visible page }
  EGA_STAGE_SEG = $A200;

type
  { The header of a DAX picture as stored; the pixel data follows it. }
  PDaxPicHeader = ^TDaxPicHeader;
  TDaxPicHeader = record
    height: Word;
    width: Word;
    originX: Word;
    originY: Word;
    count: Byte;
    map: Types.TColorMap;
  end;

function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;
var
  mask: Byte;
  transpHigh: Byte;
  bit: Byte;
  i: Byte;
begin
  mask := 0;
  transpHigh := transpColor shl 4;
  bit := $80;
  for i := 0 to 3 do begin
    if (chunk[i] and $F0) = transpHigh then
      Inc(mask, bit);
    bit := bit shr 1;
    if (chunk[i] and $0F) = transpColor then
      Inc(mask, bit);
    bit := bit shr 1;
  end;
  ComputeMask := mask;
end;

function SrcNibble(color: Byte; map: Types.TColorMap): Byte;
begin
  if Odd(color) then
    SrcNibble := map[color div 2] and $0F
  else
    SrcNibble := (map[color div 2] and $F0) shr 4;
end;

procedure SetVideoMode(mode: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  oldMode: Word;
begin
  GDVars.savedVideoMode := GDVars.curVideoMode;
  GDVars.vregs.ah := C_Video.BIOS_SET_MODE;
  GDVars.vregs.al := mode;
  Intr($10, Registers(GDVars.vregs));
  GDVars.curVideoMode := mode;
end;

procedure RestoreVideoMode;
begin
  Blit.SetVideoMode(GDVars.savedVideoMode);
end;

procedure LoadPic(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);
var
  picHeight: Word;
  picWidth: Word;
  picOriginX: Word;
  picOriginY: Word;
  picCount: Byte;
  colorMap: Types.TColorMap;
  { bytes read by LoadDax }
  dataSize: Word;
  { where the pixel data starts }
  readOfs: Word;
  { the raw DAX block }
  data: Types.PBytes;
  { Unused in this version; see the other implementations of this routine. }
  frame: Byte;
begin
  if pic <> nil then Blit.FreePic(pic);
  DaxIo.LoadDax(name, '.dax', fileId, dataSize, data);
  if dataSize = 0 then Exit;
  Move(PDaxPicHeader(data)^.height, picHeight, SizeOf(picHeight));
  Move(PDaxPicHeader(data)^.width, picWidth, SizeOf(picWidth));
  Move(PDaxPicHeader(data)^.originX, picOriginX, SizeOf(picOriginX));
  Move(PDaxPicHeader(data)^.originY, picOriginY, SizeOf(picOriginY));
  Move(PDaxPicHeader(data)^.count, picCount, SizeOf(picCount));
  Move(PDaxPicHeader(data)^.map, colorMap, SizeOf(colorMap));
  Blit.AllocPic(picHeight, picWidth, picCount, Byte(hasMask), pic);
  with pic^ do begin
    originX := picOriginX;
    originY := picOriginY;
    map := colorMap;
  end;
  readOfs := SizeOf(TDaxPicHeader);
  Blit.ExpandPicFrames(data, readOfs, hasMask, transpColor, pic);
  FreeMem(data, dataSize);
  GameIo.FlushKeys;
end;

procedure ExpandPicFrames(imgData: Types.PBytes; srcOff: Word; hasMask: Boolean; transpColor: Byte;
                          pic: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  header: array[0..16] of Byte;
  { the 8-pixel raw chunk }
  chunk: TChunk;
  frame: Byte;
  col: Word;
  row: Word;
  dstOff: Word;
  maskOff: Word;
  mask: Byte;
  k: Byte;
  j: Byte;
  bit: Byte;
  { EGA plane 0..3 }
  plane: Byte;
  color: Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
    dstOff := 0;
    maskOff := 0;
    case GDVars.displayMode of
      Types.Cga: begin
        for frame := 1 to count do
          for row := 0 to height - 1 do
            for col := 0 to width - 1 do begin
              Move(imgData^[srcOff], chunk, SizeOf(chunk));
              if transp <> nil then begin
                mask := Blit.ComputeMask(transpColor, chunk);
                bit := $80;
                for j := 1 to 2 do begin
                  for k := 4 to 7 do begin
                    if (bit and mask) > 0 then
                      transp^[maskOff] := transp^[maskOff] or GDConsts.cgaBankMask[k];
                    bit := bit shr 1;
                  end;
                  Inc(maskOff);
                end;
              end;
              for k := 0 to 3 do
                if Odd(k) then
                  data[dstOff] := data[dstOff] or
                    GDConsts.cgaPixPos[Blit.SrcNibble(chunk[k div 2] and $0F, map)][k]
                else
                  data[dstOff] := data[dstOff] or
                    GDConsts.cgaPixPos[Blit.SrcNibble((chunk[k div 2] and $F0) shr 4, map)][k];
              if transp <> nil then
                data[dstOff] := data[dstOff] and not transp^[maskOff - 2];
              Inc(dstOff);
              for k := 4 to 7 do
                if Odd(k) then
                  data[dstOff] := data[dstOff] or
                    GDConsts.cgaPixPos[Blit.SrcNibble(chunk[k div 2] and $0F, map)][k - 4]
                else
                  data[dstOff] := data[dstOff] or
                    GDConsts.cgaPixPos[Blit.SrcNibble((chunk[k div 2] and $F0) shr 4, map)][k - 4];
              if transp <> nil then
                data[dstOff] := data[dstOff] and not transp^[maskOff - 1];
              Inc(dstOff);
              Inc(srcOff, 4);
            end;
      end;
      Types.Ega: begin
        for frame := 1 to count do
          for row := 0 to height - 1 do
            for col := 0 to width - 1 do begin
              Move(imgData^[srcOff], chunk, SizeOf(chunk));
              if transp <> nil then
                FillChar(transp^[dstOff], SizeOf(chunk), Blit.ComputeMask(transpColor, chunk));
              bit := $80;
              for k := 0 to 7 do begin
                if Odd(k) then
                  color := chunk[k div 2] and $0F
                else
                  color := chunk[k div 2] shr 4;
                for plane := 0 to 3 do
                  if (GDConsts.egaPlaneBit[plane] and color) > 0 then
                    data[plane + dstOff] := data[plane + dstOff] or bit;
                bit := bit shr 1;
              end;
              if transp <> nil then
                for plane := 0 to 3 do
                  data[plane + dstOff] := data[plane + dstOff] and not transp^[dstOff];
              Inc(dstOff, 4);
              Inc(srcOff, 4);
            end;
      end;
      Types.Tandy: begin
        for frame := 1 to count do begin
          Move(imgData^[srcOff], data[dstOff], imgSize);
          if transp <> nil then
            for col := dstOff to dstOff + imgSize - 1 do begin
              if (data[col] shr 4) = transpColor then
                transp^[col] := $F0;
              if (data[col] and $0F) = transpColor then
                Inc(transp^[col], $0F);
              data[col] := data[col] and not transp^[col];
            end;
          Inc(dstOff, imgSize);
          Inc(srcOff, imgSize);
        end;
      end;
    end;
  end;
end;

{ The compositor leaves in blit.asm: the nine per-mode blitters and the two scanline loops they share. They are near,
  called by BlitTileCell and BlitTileClipped within this unit, and take their arguments by value on the stack. }
{$F-}
{$L BLIT.OBJ}
{ Draws a frame of a graphic opaque into a CGA buffer (two bytes per cell) at a character-cell position, unclipped, and
  marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellCga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into a CGA
  buffer (two bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellCgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into a CGA buffer (two bytes per cell) at a character-cell position, clipped against the
  buffer's edges, opaque or masked as the flags ask, and marks the touched scanlines dirty for FlushView. A frame lying
  entirely off the buffer is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of
  step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedCga(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImgBuf); external;

{ Draws a frame of a graphic opaque into an EGA buffer (four plane bytes per cell) at a character-cell position,
  unclipped, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into an EGA
  buffer (four plane bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into an EGA buffer (four plane bytes per cell) at a character-cell position, clipped
  against the buffer's edges, opaque or masked as the flags ask, and marks the touched scanlines dirty for FlushView. A
  frame lying entirely off the buffer is skipped. Note: an opaque frame cut at the left or right edge is drawn with its
  rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedEga(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImgBuf); external;

{ Draws a frame of a graphic opaque into a Tandy buffer (four bytes per cell) at a character-cell position, unclipped,
  and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandy(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into a Tandy
  buffer (four bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandyMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImgBuf); external;

{ Draws a frame of a graphic into a Tandy buffer (four bytes per cell) at a character-cell position, clipped against the
  buffer's edges, opaque or masked as the flags ask, and marks the touched scanlines dirty for FlushView. A frame lying
  entirely off the buffer is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of
  step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of the flags set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame of the source graphic to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedTandy(under: Types.PImgBuf; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                           dest: Types.PImgBuf); external;
{$F+}

procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Byte;
  useMask: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
begin
  useMask := ((flag and $01) <> 0) and (gfx^.transp <> nil);
  case GDVars.displayMode of
    Types.Cga:
      if useMask then Blit.BlitCellCgaMasked(screenX, screenY, tileIdx, gfx, dest)
      else Blit.BlitCellCga(screenX, screenY, tileIdx, gfx, dest);
    Types.Ega:
      if useMask then Blit.BlitCellEgaMasked(screenX, screenY, tileIdx, gfx, dest)
      else Blit.BlitCellEga(screenX, screenY, tileIdx, gfx, dest);
    Types.Tandy:
      if useMask then Blit.BlitCellTandyMasked(screenX, screenY, tileIdx, gfx, dest)
      else Blit.BlitCellTandy(screenX, screenY, tileIdx, gfx, dest);
  end;
end;

procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  clipLeft: Word;
  { Unused in this version; see the other implementations of this routine. }
  clipRight: Word;
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Word;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskClipLeft: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskClipRight: Word;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  saveOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
begin
  case GDVars.displayMode of
    Types.Cga: Blit.BlitClippedCga(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
    Types.Ega: Blit.BlitClippedEga(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
    Types.Tandy: Blit.BlitClippedTandy(GDVars.saveUnder, screenX, screenY, tileIdx, flag, gfx, dest);
  end;
end;

function MirrorBits(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 7;
  Inc(mirrored, (value and $02) shl 5);
  Inc(mirrored, (value and $04) shl 3);
  Inc(mirrored, (value and $08) shl 1);
  Inc(mirrored, (value and $10) shr 1);
  Inc(mirrored, (value and $20) shr 3);
  Inc(mirrored, (value and $40) shr 5);
  Inc(mirrored, (value and $80) shr 7);
  MirrorBits := mirrored;
end;

function MirrorPairs(value: Word): Word;
var
  mirrored: Word;
begin
  mirrored := (value and GDConsts.cgaBankMask[7]) shl 14;
  Inc(mirrored, (value and GDConsts.cgaBankMask[6]) shl 10);
  Inc(mirrored, (value and GDConsts.cgaBankMask[5]) shl 6);
  Inc(mirrored, (value and GDConsts.cgaBankMask[4]) shl 2);
  Inc(mirrored, (value and GDConsts.cgaBankMask[3]) shr 2);
  Inc(mirrored, (value and GDConsts.cgaBankMask[2]) shr 6);
  Inc(mirrored, (value and GDConsts.cgaBankMask[1]) shr 10);
  Inc(mirrored, (value and GDConsts.cgaBankMask[0]) shr 14);
  MirrorPairs := mirrored;
end;

function MirrorNibbles(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 4;
  Inc(mirrored, (value and $F0) shr 4);
  MirrorNibbles := mirrored;
end;

procedure MirrorPic(src, dst: Types.PImgBuf);
var
  dstOff: Word;
  srcOff: Word;
  rowStart: Word;
  rowBytes: Word;
  col: Word;
  row: Word;
  plane: Byte;
  cell: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  with src^ do begin
    Move(map, dst^.map, SizeOf(map));
    case GDVars.displayMode of
      { CGA: 2 bytes per 8-px cell, word pair-mirror }
      Types.Cga: begin
        rowBytes := width * 2;
        srcOff := rowBytes - 2;
        dstOff := 0;
        for row := 1 to height do begin
          rowStart := dstOff;
          for col := 0 to width - 1 do begin
            Move(data[srcOff - dstOff + rowStart], cell, SizeOf(cell));
            cell := Blit.MirrorPairs(cell);
            Move(cell, dst^.data[dstOff], SizeOf(cell));
            if transp <> nil then begin
              Move(transp^[srcOff - dstOff + rowStart], cell, SizeOf(cell));
              cell := Blit.MirrorPairs(cell);
              Move(cell, dst^.transp^[dstOff], SizeOf(cell));
            end;
            Inc(dstOff, 2);
          end;
          Inc(srcOff, rowBytes);
        end;
      end;
      { EGA: 4 plane bytes per cell, bit-mirror each; transp has the same layout as data, so it mirrors with the same
        index math. }
      Types.Ega: begin
        rowBytes := width * 4;
        srcOff := rowBytes - 4;
        dstOff := 0;
        for row := 1 to height do begin
          rowStart := dstOff;
          for col := 1 to width do begin
            for plane := 0 to 3 do begin
              dst^.data[plane + dstOff] :=
                Blit.MirrorBits(data[srcOff - dstOff + rowStart + plane]);
              if transp <> nil then
                dst^.transp^[plane + dstOff] :=
                  Blit.MirrorBits(transp^[srcOff - dstOff + rowStart + plane]);
            end;
            Inc(dstOff, 4);
          end;
          Inc(srcOff, rowBytes);
        end;
      end;
      { Tandy: 4 bytes per cell, nibble-swap each }
      Types.Tandy: begin
        rowBytes := width * 4;
        srcOff := rowBytes - 1;
        dstOff := 0;
        for row := 1 to height do begin
          rowStart := dstOff;
          for col := 1 to rowBytes do begin
            dst^.data[dstOff] := Blit.MirrorNibbles(data[srcOff - dstOff +
                                                                            rowStart]);
            if transp <> nil then
              dst^.transp^[dstOff] :=
                Blit.MirrorNibbles(transp^[srcOff - dstOff + rowStart]);
            Inc(dstOff);
          end;
          Inc(srcOff, rowBytes);
        end;
      end;
    end;
  end;
end;

procedure GrabPic(col, row: Integer; pic: Types.PImgBuf);
var
  c: Integer;
  r: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  rowBytes: Word;
  dataOffset: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  with pic^ do
    case GDVars.displayMode of
      { CGA: read 2 bytes per 8-px cell back from the row seg }
      Types.Cga: begin
        rowBytes := width * 2;
        dataOffset := 0;
        firstRow := row * 8;
        lastRow := firstRow + height - 1;
        colOff := col * 2;
        for r := firstRow to lastRow do begin
          Move(Mem[GDVars.cgaRowSeg[r]:colOff], pic^.data[dataOffset], rowBytes);
          Inc(dataOffset, rowBytes);
        end;
      end;
      { EGA: read the 4 planes via GC Read Map Select }
      Types.Ega: begin
        dataOffset := 0;
        firstRow := row * 8;
        lastRow := firstRow + height - 1;
        colOff := col;
        colEnd := colOff + width - 1;
        Port[C_Ega.GC_ADDR_PORT] := Blit.GC_MODE_REG;
        Port[C_Ega.GC_DATA_PORT] := Blit.GC_WRITE_MODE_0;
        Port[C_Ega.GC_ADDR_PORT] := Blit.GC_READ_MAP_REG;
        for r := firstRow to lastRow do
          for c := colOff to colEnd do
            for plane := 0 to 3 do begin
              Port[C_Ega.GC_DATA_PORT] := plane;
              pic^.data[dataOffset] := Mem[C_Video.EGA_VIDEO_SEG:GDVars.fbRowOfs[r] + c];
              Inc(dataOffset);
            end;
        Port[C_Ega.GC_DATA_PORT] := 0;
        Port[C_Ega.GC_ADDR_PORT] := Blit.GC_MODE_REG;
        Port[C_Ega.GC_DATA_PORT] := Blit.GC_WRITE_MODE_0;
      end;
      { Tandy: read 4 bytes per 8-px cell back from the row seg }
      Types.Tandy: begin
        rowBytes := width * 4;
        dataOffset := 0;
        firstRow := row * 8;
        lastRow := firstRow + height - 1;
        colOff := col * 4;
        for r := firstRow to lastRow do begin
          Move(Mem[GDVars.tandyRowSeg[r]:colOff], pic^.data[dataOffset], rowBytes);
          Inc(dataOffset, rowBytes);
        end;
      end;
    end;
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  col: Integer;
  row: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  rowBytes: Word;
  srcOff: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  with pic^ do
    case GDVars.displayMode of
      { CGA: 2 bytes per 8-px cell }
      Types.Cga: begin
        rowBytes := width * 2;
        srcOff := 0;
        firstRow := screenY * 8;
        lastRow := firstRow + height - 1;
        colOff := screenX * 2;
        for row := firstRow to lastRow do begin
          Move(pic^.data[srcOff], Mem[GDVars.cgaRowSeg[row]:colOff], rowBytes);
          Inc(srcOff, rowBytes);
        end;
      end;
      { EGA: 4 plane bytes per cell via the Map Mask }
      Types.Ega: begin
        srcOff := 0;
        firstRow := screenY * 8;
        lastRow := firstRow + height - 1;
        colOff := screenX;
        colEnd := colOff + width - 1;
        Port[C_Ega.SEQ_ADDR_PORT] := Blit.SEQ_MAP_MASK_REG;
        for row := firstRow to lastRow do
          for col := colOff to colEnd do
            for plane := 0 to 3 do begin
              Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[plane];
              Mem[C_Video.EGA_VIDEO_SEG:GDVars.fbRowOfs[row] + col] := pic^.data[srcOff];
              Inc(srcOff);
            end;
        Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
      end;
      { Tandy: 4 bytes per 8-px cell }
      Types.Tandy: begin
        rowBytes := width * 4;
        srcOff := 0;
        firstRow := screenY * 8;
        lastRow := firstRow + height - 1;
        colOff := screenX * 4;
        for row := firstRow to lastRow do begin
          Move(pic^.data[srcOff], Mem[GDVars.tandyRowSeg[row]:colOff], rowBytes);
          Inc(srcOff, rowBytes);
        end;
      end;
    end;
end;

procedure FlushView;
var
  row: Word;
  srcOff: Word;
  dstOff: Word;
  dstBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  plane: Word;
  { Unused in this version; see the other implementations of this routine. }
  spanBuf: array[1..256] of Byte;
begin
  { hide the mouse cursor while the view is committed }
  Mouse.HideMouse;
  case GDVars.displayMode of
    Types.Cga: for row := 0 to 167 do
         if GDVars.spanActive[row] <> 0 then
           Move(GDVars.egaDest^.data[GDVars.spanX0[row]], Mem[GDVars.cgaRowSeg[row + 8]:GDVars.spanY[row] + 2],
                GDVars.spanX1[row] - GDVars.spanX0[row] + 1);
    Types.Ega: begin
      Port[C_Ega.SEQ_ADDR_PORT] := Blit.SEQ_MAP_MASK_REG;
      for row := 0 to 167 do
        if GDVars.spanActive[row] <> 0 then begin
          dstBase := GDVars.fbRowOfs[row + 8] + GDVars.spanY[row] + 1;
          Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[0];
          srcOff := GDVars.spanX0[row];
          dstOff := dstBase;
          repeat
            Mem[Blit.EGA_STAGE_SEG:dstOff] := GDVars.egaDest^.data[srcOff];
            Inc(srcOff, 4);
            Inc(dstOff);
          until srcOff > GDVars.spanX1[row];
          Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[1];
          srcOff := GDVars.spanX0[row] + 1;
          dstOff := dstBase;
          repeat
            Mem[Blit.EGA_STAGE_SEG:dstOff] := GDVars.egaDest^.data[srcOff];
            Inc(srcOff, 4);
            Inc(dstOff);
          until srcOff > GDVars.spanX1[row];
          Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[2];
          srcOff := GDVars.spanX0[row] + 2;
          dstOff := dstBase;
          repeat
            Mem[Blit.EGA_STAGE_SEG:dstOff] := GDVars.egaDest^.data[srcOff];
            Inc(srcOff, 4);
            Inc(dstOff);
          until srcOff > GDVars.spanX1[row];
          Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[3];
          srcOff := GDVars.spanX0[row] + 3;
          dstOff := dstBase;
          repeat
            Mem[Blit.EGA_STAGE_SEG:dstOff] := GDVars.egaDest^.data[srcOff];
            Inc(srcOff, 4);
            Inc(dstOff);
          until srcOff > GDVars.spanX1[row];
        end;
      Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
      dstOff := GDVars.fbRowOfs[8] + 1;
      Port[C_Ega.GC_ADDR_PORT] := Blit.GC_MODE_REG;
      Port[C_Ega.GC_DATA_PORT] := Blit.GC_WRITE_MODE_1;
      for row := 0 to 167 do begin
        if GDVars.spanActive[row] <> 0 then
          Move(Mem[Blit.EGA_STAGE_SEG:dstOff + GDVars.spanY[row]],
               Mem[C_Video.EGA_VIDEO_SEG:dstOff + GDVars.spanY[row]],
               (GDVars.spanX1[row] - GDVars.spanX0[row]) div 4 + 1);
        Inc(dstOff, 40);
      end;
      Port[C_Ega.GC_DATA_PORT] := Blit.GC_WRITE_MODE_0;
    end;
    Types.Tandy: for row := 0 to 167 do
         if GDVars.spanActive[row] <> 0 then
           Move(GDVars.egaDest^.data[GDVars.spanX0[row]], Mem[GDVars.tandyRowSeg[row + 8]:GDVars.spanY[row] + 4],
                GDVars.spanX1[row] - GDVars.spanX0[row] + 1);
  end;
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanX0, SizeOf(GDVars.spanX0), 255);
  FillChar(GDVars.spanX1, SizeOf(GDVars.spanX1), 0);
  Mouse.ShowMouse;
end;

procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);
var
  srcOff: Word;
  dstOff: Word;
  nFrames: Byte;
  col: Word;
  row: Word;
  match: Byte;
  planeMask: array[0..3] of Byte;
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellByte: Byte;
  pixPos: Byte;
  rowBytes: Word;
  fromHigh: Byte;
  toHigh: Byte;
  pairIdx: Byte;
  scratchPic: Types.PImgBuf;
begin
  if pic = nil then Exit;
  with pic^ do begin
    if frame < 0 then begin
      frame := 0;
      nFrames := count;
    end else
      nFrames := 1;
    srcOff := frame * imgSize;
  end;
  dstOff := 0;
  Blit.AllocPic(pic^.height, pic^.width, nFrames, 0, scratchPic);
  scratchPic^.map := pic^.map;
  Move(pic^.data[srcOff], scratchPic^.data[dstOff], scratchPic^.count * scratchPic^.imgSize);
  for pairIdx := 0 to 15 do begin
    with pic^ do begin
      if frame < 0 then begin
        frame := 0;
        nFrames := count;
      end else
        nFrames := 1;
      srcOff := frame * imgSize;
    end;
    dstOff := 0;
    if fromColors[pairIdx] <> toColors[pairIdx] then
      with scratchPic^ do
        case GDVars.displayMode of
          { CGA: match/rewrite each 2-bit pixel pattern }
          Types.Cga: begin
            rowBytes := width * 2;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to height do
                for col := 1 to rowBytes do begin
                  for pixPos := 0 to 3 do
                    if pic^.data[srcOff] and GDConsts.cgaBankMask[pixPos + 4] =
                        GDConsts.cgaPixPos[Blit.SrcNibble(fromColors[pairIdx], map)][pixPos] then
                      if not isDithered or isDithered and (Random(4) = 0) then
                        data[dstOff] := data[dstOff] and not GDConsts.cgaBankMask[pixPos + 4] or
                          GDConsts.cgaPixPos[Blit.SrcNibble(toColors[pairIdx], map)][pixPos];
                  Inc(srcOff);
                  Inc(dstOff);
                end;
          end;
          { EGA: bitmask match across the 4 plane bytes }
          Types.Ega: begin
            for plane := 0 to 3 do
              if (fromColors[pairIdx] and GDConsts.egaPlaneBit[plane]) > 0 then
                planeMask[plane] := 0
              else
                planeMask[plane] := $FF;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to height do
                for col := 1 to width do begin
                  if isDithered then
                    match := Random(256) and Random(256)
                  else
                    match := $FF;
                  for plane := 0 to 3 do
                    match := (pic^.data[plane + srcOff] xor planeMask[plane]) and match;
                  for plane := 0 to 3 do
                    if (toColors[pairIdx] and GDConsts.egaPlaneBit[plane]) > 0 then
                      data[plane + dstOff] := data[plane + dstOff] or match
                    else
                      data[plane + dstOff] := data[plane + dstOff] and not match;
                  Inc(srcOff, 4);
                  Inc(dstOff, 4);
                end;
          end;
          { Tandy: high and low nibble matched separately }
          Types.Tandy: begin
            rowBytes := width * 4;
            fromHigh := fromColors[pairIdx] shl 4;
            toHigh := toColors[pairIdx] shl 4;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to height do
                for col := 1 to rowBytes do begin
                  if pic^.data[srcOff] and $F0 = fromHigh then
                    if not isDithered or isDithered and (Random(4) = 0) then
                      data[dstOff] := data[dstOff] and $F or toHigh;
                  if pic^.data[srcOff] and $F = fromColors[pairIdx] then
                    if not isDithered or isDithered and (Random(4) = 0) then
                      data[dstOff] := data[dstOff] and $F0 or toColors[pairIdx];
                  Inc(srcOff);
                  Inc(dstOff);
                end;
          end;
        end;
  end;
  with pic^ do
    Move(scratchPic^.data, data[frame * imgSize], nFrames * imgSize);
  Blit.FreePic(scratchPic);
end;

procedure AllocPic(height, width: Word; count: Byte; flag: Byte; var pic: Types.PImgBuf);
var
  frameSize: Word;
  totalSize: Word;
begin
  frameSize := height * width * 2;
  if GDVars.displayMode <> Types.Cga then
    frameSize := frameSize * 2;
  totalSize := count * frameSize;
  GetMem(pic, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  FillChar(pic^, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)), 0);
  pic^.height := height;
  pic^.width := width;
  pic^.imgSize := frameSize;
  pic^.count := count;
  if (flag and $01) > 0 then begin
    GetMem(pic^.transp, totalSize);
    FillChar(pic^.transp^, totalSize, 0);
  end;
end;

procedure FreePic(var pic: Types.PImgBuf);
var
  allocationSize: Word;
begin
  if pic = nil then Exit;
  with pic^ do begin
    allocationSize := count * imgSize;
    if transp <> nil then
      FreeMem(transp, allocationSize);
  end;
  FreeMem(pic, allocationSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  pic := nil;
end;

procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImgBuf);
var
  clipLeft: Word;
  clipRight: Word;
  clampedX: Word;
  rightMargin: Word;
  runLen: Word;
  lastRow: Word;
  dstOff: Word;
  row: Word;
  planeMask: array[0..3] of Byte;
  absRow: Word;
  screenOfs: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  if x < 0 then begin
    clipLeft := Abs(x);
    clampedX := 0;
  end else begin
    clipLeft := 0;
    clampedX := x;
  end;
  if pic^.width < x + width then begin
    clipRight := x + width - pic^.width;
    rightMargin := 0;
  end else begin
    clipRight := 0;
    rightMargin := pic^.width - (x + width);
  end;
  if y < 0 then begin
    dstOff := 0;
    absRow := 0;
    lastRow := height - Abs(y);
  end else begin
    absRow := y;
    dstOff := absRow * pic^.width;
    lastRow := height - 1;
    if pic^.height < y + height then
      lastRow := pic^.height - 1 - y
    else
      lastRow := height - 1;
  end;
  case GDVars.displayMode of
    Types.Cga, Types.Tandy: begin
      { CGA: 2 bytes per cell }
      if GDVars.displayMode = Types.Cga then begin
        screenOfs := clampedX * 2;
        runLen := (width - clipLeft - clipRight) * 2;
        clampedX := clampedX * 2;
        rightMargin := rightMargin * 2;
        dstOff := dstOff * 2;
      end
      { Tandy: 4 bytes per cell }
      else begin
        runLen := (width - clipLeft - clipRight) * 4;
        clampedX := clampedX * 4;
        rightMargin := rightMargin * 4;
        dstOff := dstOff * 4;
        screenOfs := clampedX;
      end;
      for row := 0 to lastRow do begin
        GDVars.spanActive[absRow] := 1;
        Inc(dstOff, clampedX);
        if GDVars.spanX0[absRow] > dstOff then begin
          GDVars.spanY[absRow] := screenOfs;
          GDVars.spanX0[absRow] := dstOff;
        end;
        if GDVars.displayMode = Types.Cga then
          FillChar(pic^.data[dstOff], runLen, GDConsts.cgaColorFill[Blit.SrcNibble(color, colorMap)])
        else
          FillChar(pic^.data[dstOff], runLen, GDConsts.tandyColorFill[color]);
        Inc(dstOff, runLen);
        if dstOff - 1 > GDVars.spanX1[absRow] then
          GDVars.spanX1[absRow] := dstOff - 1;
        Inc(dstOff, rightMargin);
        Inc(absRow);
      end;
    end;
    { EGA: 4 plane bytes per cell }
    Types.Ega: begin
      screenOfs := clampedX;
      runLen := width - clipLeft - clipRight;
      clampedX := clampedX * 4;
      rightMargin := rightMargin * 4;
      dstOff := dstOff * 4;
      FillChar(planeMask, SizeOf(planeMask), 0);
      for plane := 0 to 3 do
        if (GDConsts.egaPlaneBit[plane] and color) > 0 then
          planeMask[plane] := $FF;
      for row := 0 to lastRow do begin
        GDVars.spanActive[absRow] := 1;
        Inc(dstOff, clampedX);
        if GDVars.spanX0[absRow] > dstOff then begin
          GDVars.spanY[absRow] := screenOfs;
          GDVars.spanX0[absRow] := dstOff;
        end;
        for GDVars.scratchIndex := 1 to runLen do begin
          Move(planeMask, pic^.data[dstOff], SizeOf(planeMask));
          Inc(dstOff, 4);
        end;
        if dstOff - 1 > GDVars.spanX1[absRow] then
          GDVars.spanX1[absRow] := dstOff - 1;
        Inc(dstOff, rightMargin);
        Inc(absRow);
      end;
    end;
  end;
end;

begin
end.
