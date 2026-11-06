{ Effect trigger conditions: the id FxEngine.TriggerEffectsWithCondition dispatches on. }
unit C_Cond;

interface

const
  { the attacker's side of the attack check, run with its target set to the defender; no effect answers it }
  ATTACKER_VETO = 0;
  { the target's effects, which may veto an attack on it }
  TARGET_VETO = 1;
  WEAPON_DAMAGE_ATTACKER = 4;
  WEAPON_DAMAGE_DEFENDER = 5;
  DEFENDER_ARMOR_CLASS = 11;
  HIT_POINTS_ZERO = 13;
  MOVE_ATTACK_RATE = 18;

implementation

end.
