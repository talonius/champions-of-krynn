{ Effect ids: TEffectRec.id, a spell-table row's effect, and the index into GDVars.effectHandlers. }
unit C_Effect;

interface

const
  { the slow damage Slow Poison leaves while it holds a fatal poison back }
  POISON_DAMAGE = 15;
  { Slow Poison: when it ends, a fatal poison still present kills }
  SLOW_POISON = 22;
  { Animate Dead }
  ANIMATED = 32;
  BLIND = 33;
  CURSED = 36;
  HASTED = 39;
  SLOWED = 42;
  POISONED = 55;
  { Feeblemind; Heal removes it }
  FEEBLEMINDED = 68;

implementation

end.
