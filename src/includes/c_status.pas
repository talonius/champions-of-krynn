{ Creature status values (TCharRecord.status), in statusNames order, and the state past the table that a gating summons
  brings back. }
unit C_Status;

interface

const
  OKAY = 0;
  ANIMATED = 1;
  { fled combat }
  RUNNING = 3;
  UNCONSCIOUS = 4;
  DYING = 5;
  DEAD_STATUS = 6;
  STONED = 7;
  GONE = 8;
  { out of play: combat places it off the arena, and a gating summons brings it in }
  REMOVED = 9;
  { died out of play and queued in explosionQueue }
  EXPLODED = 10;

implementation

end.
