{ Arena terrain values. }
unit C_Terr;

interface

const
  { the cell an acid pool covers }
  TERRAIN_ACID_POOL = 29;
  { a cell under a stinking cloud; the cloud keeps the terrain beneath }
  TERRAIN_STINKING_CLOUD = 30;
  { the marker a downed creature leaves on its cell }
  TERRAIN_CORPSE = 31;
  { a terrain movement cost no move can pay }
  TERRAIN_IMPASSABLE = 255;

implementation

end.
