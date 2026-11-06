{ The display: the BIOS video service's set-mode function and the visible EGA framebuffer. }
unit C_Video;

interface

const
  { BIOS video function, passed in AH: set the video mode in AL }
  BIOS_SET_MODE = 0;
  { visible EGA framebuffer (planar, mode $0D) }
  EGA_VIDEO_SEG = $A000;

implementation

end.
