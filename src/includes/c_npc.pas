{ TCharRecord.npc values: bit 7 marks a creature outside the party; bits 0..6 hold its morale. }
unit C_Npc;

interface

const
  NON_PLAYER = $80;
  MORALE_MASK = $7F;

implementation

end.
