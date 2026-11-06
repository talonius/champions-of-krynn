{ Script-visible game-memory addresses, used as indices into the zone banks. }
unit C_Gbvm;

interface

const
  { the GBVM address range of each bank: zones 0 to 2 hold words, zone 3 the script bytes }
  ZONE0_BASE = $4B00;
  ZONE0_TOP = $4EFF;
  ZONE1_BASE = $7C00;
  ZONE1_TOP = $7FFF;
  ZONE2_BASE = $7A00;
  ZONE2_TOP = $7BFF;
  ZONE3_BASE = $8000;
  ZONE3_TOP = $9DFF;
  { zone 0: the id of the loaded 3D map }
  GEO_MAP_ID = $4BC5;
  { zone 0: nonzero where spellcasting is forbidden }
  ANTI_MAGIC = $4BE5;
  { zone 0: nonzero while the party is in a 3D area }
  VIEW_3D = $4BE6;
  { zone 1: the number of characters in the party }
  PARTY_SIZE = $7F3E;

implementation

end.
