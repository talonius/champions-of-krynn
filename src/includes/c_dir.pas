{ Compass directions, clockwise from north: map facings, arena moves and mouse headings. Also the slopes that split a
  heading into its octant. }
unit C_Dir;

interface

const
  NORTH = 0;
  NORTHEAST = 1;
  EAST = 2;
  SOUTHEAST = 3;
  SOUTH = 4;
  SOUTHWEST = 5;
  WEST = 6;
  NORTHWEST = 7;
  { a creature's own cell: no direction }
  CENTER = 8;
  { tan(67.5 degrees) * 256, rounded: a heading steeper than this is due north or south }
  OCTANT_STEEP = 618;
  { tan(22.5 degrees) * 256, rounded: a heading shallower than this is due east or west }
  OCTANT_SHALLOW = 106;

implementation

end.
