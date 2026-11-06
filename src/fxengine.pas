{ The effects engine: per-effect handler dispatch, effect-list add/remove/trigger, attack rolls, saving throws, dice,
  non-weapon damage with the elemental message ladder, Strength-effect encoding, HP restore, revival, the Kender Yell
  and the Draconian death throes. }
{$O+,F+}
unit FxEngine;

interface

uses Types, GDConsts, GDVars, TextRend, Blit, CharHlp, ClassCal, Pathing, CbtMap, Debug, C_Class, C_Ifc,
  C_Status, C_Effect, C_Stat, C_Side, C_Cond;

{ Prints a message after a creature's name. Unless the creature is already stoned, dead or gone, it then gives it the
  status, takes it out of play at 0 hit points, removes its effects that end at 0 hit points, runs its condition-13
  (going down) effects, marks it downed on the combat map when those effects leave it out of play and it has not
  exploded, pauses, clears the message window and, outside combat, redraws the party.
  @param(cr Creature being killed.)
  @param(status Status to give it.)
  @param(msg Message printed after its name.) }
procedure KillCreature(cr: Pointer; status: Byte; msg: Types.TStr40);

{ Calls an effect's handler, or the override handler instead while an override is active.
  @param(effId Effect whose handler is called.)
  @param(cr Creature the effect acts on.)
  @param(p Node of the effect, passed on to the handler; may be nil.)
  @param(removed True when the call is for the effect's removal.) }
procedure CallEffectHandler(effId: Byte; var cr; p: Pointer; removed: Boolean);

{ Unlinks an effect node from a creature's effect list and frees it, calling the effect's handler first when the node
  asks for it on removal. Removing Friends recalculates Charisma; removing Enlarge or Strength recalculates Strength.
  @param(cr Creature whose effect is removed.)
  @param(id Effect looked for when no node is given; it also selects the handler and the ability recalculated.)
  @param(p Node to remove, or nil for the creature's first copy of the effect; nothing happens when there is none.) }
procedure RemoveEffect(cr: Pointer; id: Byte; p: Pointer);

{ Runs TriggerEffect for each effect on the list of condition id, in list order; conditions 6 and 9 first let the
  creature's magic resistance cancel the pending damage or effect (CheckSpellResistance). The conditions this unit
  raises are 6 damage taken, 9 an effect being applied, 10 the attacker's and 16 the defender's attack roll, 12 a saving
  throw, 13 going down and 20 damage taken without a save. Conditions 0, 22, 23 and values above 24 do nothing.
  @param(id Condition being checked.)
  @param(cr Creature whose effects are checked.) }
procedure TriggerEffectsWithCondition(id: Byte; var cr);

{ Applies the clouds and pools on the cells of a creature in play. In a stinking cloud, when b is nonzero and the
  creature is not undead, helpless or protected by effect 99, it rolls a saving throw (type 0): on a save it starts to
  cough for 1d4 + 1, otherwise nausea leaves it helpless for 1d4 + 1. The cloud's caster stands in as the current
  character while the effect is added and its handler runs. An acid pool deals 1d6 damage. Note: the cough handler is
  passed the node left by the last failed effect search, which is nil, rather than the cough effect just added.
  @param(cr Creature to check.)
  @param(b Nonzero to let a stinking cloud act.) }
procedure ConsiderTerrainEffects(cr: Pointer; b: Byte);

{ Rolls an attack that has no attacking creature: a d20, where 1 always misses and 20 counts as 100, adjusted by the
  defender's condition-16 effects.
  @param(defender Creature attacked.)
  @param(sixtyMinusThac0 The attack's to-hit value, 60 minus its THAC0.)
  @returns(True when the adjusted roll is not negative and the roll plus the to-hit value exceeds the defender's armor
    class.) }
function AttackRollNoAttacker(defender: Pointer; sixtyMinusThac0: Byte): Boolean;

{ Rolls an attack by one creature on another. Makes the attacker visible, rolls a d20 (1 always misses, 20 counts as
  100), runs the attacker's condition-10 and the defender's condition-16 effects, and adds the to-hit modifier zone 1
  holds for the attacker's side. Note: the party's light-level adjustment selects on a constant that matches none of its
  cases, so it never applies.
  @param(attacker Creature attacking.)
  @param(defender Creature attacked.)
  @param(sixtyMinusAc Value the attack must reach, 60 minus the defender's armor class.)
  @returns(True when the adjusted roll is not negative and the roll plus the attacker's THAC0 adjustment and the
    modifier reaches the value needed.) }
function AttackRoll(attacker, defender: Pointer; sixtyMinusAc: Byte): Boolean;

{ Rolls cr's saving throw. A natural 1 fails and a natural 20 succeeds; otherwise the d20 plus cr's saveBonus and b,
  after cr's condition-12 effects, must reach its save value for type a. A magic-user of a robe order gets 1 less or 1
  more as the zone's word for that order is 0 or 2. The roll and the result stay in GDVars.saveRoll and
  GDVars.saveResult; GDVars.saveType is set when the roll is neither 1 nor 20. Note: the total is kept in a Byte, so a
  total below 0 wraps to a large value and succeeds.
  @param(cr Creature saving.)
  @param(a Saving throw category, an index into cr's saves.)
  @param(b Modifier added to the roll, read as signed.)
  @returns(True when the save succeeds.) }
function RollSavingThrow(cr: Pointer; a, b: Byte): Boolean;

{ Rolls a number of dice and adds them up.
  @param(a Number of dice; 0 rolls nothing.)
  @param(b Faces per die.)
  @returns(The sum, kept in a Byte, so a total above 255 wraps.) }
function RollDice(a, b: Byte): Byte;

{ Rolls damage dice, recording the number of dice for the resistances.
  @param(a Number of dice.)
  @param(b Faces per die.)
  @returns(The sum, as RollDice returns it.) }
function RollDamageDice(a, b: Byte): Byte;

{ Adds an effect node to the end of a creature's effect list. It neither checks for a node already there nor calls the
  effect's handler.
  @param(cr The creature.)
  @param(effId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(onRemove True to call the effect's handler when it is removed.) }
procedure AddEffect(cr: Pointer; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);

{ Takes an enabled creature out of play: centers the map on it, prints a message after its name, disables it and sets
  its status. Its hit points drop to 0 unless it fled (running). Its icon is erased from the combat map and taken off
  the arena, and when its actions end the effects that end at 0 hit points are removed.
  @param(cr The creature.)
  @param(n Its new status.)
  @param(s The message.) }
procedure PutOutOfPlayWithStatus(cr: Pointer; n: Byte; s: Types.TStr40);

{ Removes each invisibility node from a creature.
  @param(cr The creature.) }
procedure RemoveInvisibility(cr: Pointer);

{ Removes one copy of each of the sixteen effects that end when a creature goes down. A creature that still has the
  Berserk effect afterwards and is marked as an animated player character returns to the party's side.
  @param(cr Creature that went down.) }
procedure RemoveEffectsHp0(cr: Pointer);

{ Empty: no effects end with combat AI control.
  @param(cr Unused.) }
procedure RemoveAiEffects(cr: Pointer);

{ Cures a creature of an effect: when it has the effect, prints that it is cured and removes the node.
  @param(cr The creature.)
  @param(effId The effect.)
  @returns(True when the creature had the effect.) }
function RemoveEffectWithMessage(cr: Pointer; effId: Byte): Boolean;

{ Tells whether a Strength beats a creature's permanent one: a higher base Strength, or 18 with an exceptional Strength
  above its permanent exceptional Strength.
  @param(cr Creature compared against.)
  @param(baseStr Candidate base Strength.)
  @param(excStr Candidate exceptional Strength.)
  @param(effStrength Receives the candidate's effect encoding when it is better; unchanged otherwise.)
  @returns(True when the candidate is better.) }
function AdjustForNewStrength(cr: Pointer; baseStr, excStr: Byte; var effStrength: Byte): Boolean;

{ Deals damage that is not a weapon hit. The creature's condition-6 effects adjust it first; then, when saved, a save
  reduction of 1 cancels it and 2 halves it, while without a save the condition-20 effects run. Damage left over on a
  creature in play is printed with its type and applied, and in combat it stops the creature's casting; a spell it was
  casting is lost and its actions for the round end. A creature this takes out of play is reported as going down, dying
  or killed: outside combat the game pauses; in combat its 0-hit-point effects are removed, its condition-13 effects run
  and it is marked downed if it is still out of play and has not exploded. The damage type comes from the current
  element mask: Fire, Cold, Electricity or Acid is named when it is the one type besides Magic, and "from Magic" is
  printed when Magic is the one type or no type is set.
  @param(cr Creature hurt.)
  @param(damage Damage before adjustment.)
  @param(saveReduction What a save does: 1 cancels the damage, 2 halves it, other values leave it.)
  @param(saved True when the creature made its saving throw.) }
procedure InflictNonWeaponDamage(cr: Pointer; damage, saveReduction: Byte; saved: Boolean);

{ Applies an effect to a creature unless its condition-9 effects block it or a save negates it; then "is Unaffected" is
  printed instead. The creature's first copy of the effect, when it has time left, is replaced. The message, when not
  empty, is printed.
  @param(cr Creature given the effect.)
  @param(effId Effect to add.)
  @param(minutes Duration.)
  @param(strength Effect strength, read by its handler.)
  @param(onRemove Set to call the effect's handler when it is removed.)
  @param(saveNegates True (1) when a successful save cancels the effect.)
  @param(saved Set when the creature made its saving throw.)
  @param(msg Message printed after its name, or empty.) }
procedure AddEffectWithMessage(cr: Pointer; effId: Byte; minutes: Word; strength: Byte; onRemove, saveNegates,
                               saved: Byte; msg: Types.TStr40);

{ Heals a creature that is okay, animated, unconscious or dying by the given hit points, capped at its maximum; when the
  flag is set, a creature already at its maximum is left alone. A healed creature out of play goes from dying to
  unconscious, and an unconscious one outside combat comes back into play okay. Note: the sum of the current and
  restored hit points is kept in a Byte, so a total above 255 wraps before the cap applies.
  @param(cr Creature healed.)
  @param(hp Hit points to restore.)
  @param(flag Set to leave a creature at its maximum unhealed.)
  @returns(True when it healed.) }
function RestoreHitPoints(cr: Pointer; hp: Byte; flag: Boolean): Boolean;

{ Stands cr back up with hp hit points when its combat cell can hold it (CbtMap.IsValidCreatureLoc): its status becomes
  okay, it comes back into play, the view is centered on it in combat, msg is printed, and the teams are recounted.
  @param(cr Creature revived.)
  @param(hp Hit points it gets back.)
  @param(msg Message printed after its name.)
  @returns(True when it revived.) }
function ReviveDeadCreature(cr: Pointer; hp: Byte; msg: Types.TStr40): Boolean;

{ Recomputes the current value of one ability of cr from its permanent value, its readied magic items and its effects.
  Items can raise or lower an ability or force it to 3 or 7. Strength keeps the best of the items, effects 113 and 12,
  and effect 38, which adds its decoded Strength to a creature at 18/99 or less and turns each point above 18 into 10
  exceptional points for a fighter, knight or ranger (others stop at 18). Constitution recomputes the maximum hit points
  from the rolled hit points and the Constitution bonus of the class levels, moves the current hit points by the change,
  and keeps effect 62 on while it is 20 or more. Dexterity takes a forced value, and Charisma adds the strength of
  effect 14. Note: Intelligence and Wisdom are worked out but never stored.
  @param(cr Creature recalculated.)
  @param(n Ability, a C_Stat index from STRENGTH to CHARISMA.) }
procedure RecalcAbility(cr: Pointer; n: ShortInt);

{ Carries out the kender's yell: the yeller becomes the yell target, and each okay creature with Intelligence above 3 on
  another side that is not helpless and fails a saving throw (type 4) is taunted and "wants to kill" the yeller.
  @param(cr The kender yelling.) }
procedure YellTaunt(cr: Pointer);

{ Calls the priming entries of CharHlp, ClassCal and the trace overlay, so the overlay manager loads those overlays. }
procedure PrimeFxEngine;

{ Explodes each queued creature: it "explodes.", deals 1d6 damage to each adjacent creature that has not exploded, and
  is left dead and downed; the queue is then cleared. Note: an empty queue slot is still marked dead and downed, through
  a nil pointer. }
procedure ProcessExplodingCreatures;

implementation

const
  { AttackRoll's light-source selector }
  LIGHT_LEVEL = 500;

type
  TDirs = array[0..255] of Byte;
  PDirs = ^TDirs;

var
  { the cloud cell directions, read through FindCreatureAtCell's table parameter }
  terrainDirs: array[0..4] of Byte absolute GDConsts.cloudDirs;

procedure PrimeFxEngine;
begin
  CharHlp.PrimeCharHlp;
  Debug.PrimeDebug;
  ClassCal.PrimeClassCal;
end;

procedure YellTaunt(cr: Pointer);
var
  p: Types.PCharRecord;
begin
  GDVars.yellTarget := cr;
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.status = C_Status.OKAY) and (p^.stats[C_Stat.INTELLIGENCE].cur > 3) and
        (p^.hostile <> Types.PCharRecord(cr)^.hostile) and (not CharHlp.IsHelpless(p)) and
        (not FxEngine.RollSavingThrow(p, 4, 0)) then
      FxEngine.AddEffectWithMessage(p, 91, 0, 255, 0, 0, 0, 'wants to kill ' + Types.PCharRecord(cr)^.name);
    p := p^.next;
  end;
end;

procedure KillCreature(cr: Pointer; status: Byte; msg: Types.TStr40);
begin
  CharHlp.PrintCreatureMessage(cr, msg, 10, False);
  case Types.PCharRecord(cr)^.status of
    C_Status.STONED, C_Status.DEAD_STATUS, C_Status.GONE: ;
  else begin
      Types.PCharRecord(cr)^.status := status;
      Types.PCharRecord(cr)^.inPlay := 0;
      Types.PCharRecord(cr)^.hpCur := 0;
      FxEngine.RemoveEffectsHp0(cr);
      FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, cr);
      if (Types.PCharRecord(cr)^.inPlay = 0) and (Types.PCharRecord(cr)^.status <> C_Status.EXPLODED) then
        CbtMap.CreatureDowned(Types.PCharRecord(cr));
      TextRend.pauseOnly;
      CharHlp.ClearMessageWindow;
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        CharHlp.DisplayParty(GDVars.curChar);
    end;
  end;
end;

procedure CallEffectHandler(effId: Byte; var cr; p: Pointer; removed: Boolean);
begin
  if GDVars.overrideFlag <> 0 then
    GDVars.overrideHandler(cr, p, removed)
  else
    GDVars.effectHandlers[effId](cr, p, removed);
end;

procedure RemoveEffect(cr: Pointer; id: Byte; p: Pointer);
var
  prev: Types.PEffectRec;
  node: Types.PEffectRec;
begin
  node := p;
  if node = nil then begin
    node := Types.PCharRecord(cr)^.effects;
    while (node <> nil) and (node^.id <> id) do
      node := node^.next;
  end;
  if node = nil then Exit;
  if node^.onRemove <> 0 then
    FxEngine.CallEffectHandler(id, cr, node, True);
  if Types.PCharRecord(cr)^.effects = node then
    Types.PCharRecord(cr)^.effects := node^.next
  else begin
    prev := Types.PCharRecord(cr)^.effects;
    while (prev <> nil) and (prev^.next <> node) do
      prev := prev^.next;
    prev^.next := node^.next;
  end;
  FreeMem(node, SizeOf(Types.TEffectRec));
  if id = 14 then
    FxEngine.RecalcAbility(cr, 5);
  if (id = 12) or (id = 38) then
    FxEngine.RecalcAbility(cr, 0);
end;

{ Fires one effect on a creature: calls its handler when the creature has the effect, or, for the aura effects Silence
  15', Protection from Evil 10', Protection from Good 10' and Prayer, when a creature carrying it has this one in range
  (6 cells for Prayer, else 1; outside combat any carrier counts). The handler gets the node found: the creature's own,
  or the carrier's for an aura. The range test builds a target list, and the caller's target list is kept around it.
  @param(cr The creature.)
  @param(effId The effect.) }
procedure TriggerEffect(var cr; effId: Byte);
var
  savedList: array[0..215] of Byte;
  p: Types.PCharRecord;
  eff: Types.PEffectRec;
  found: Boolean;
  i: Byte;
  range: Byte;
begin
  found := False;
  p := GDVars.partyHead;
  if CharHlp.HasEffect(Types.PCharRecord(cr), effId, eff) then
    found := True
  else if effId in [21, 45, 46, 49] then begin
    Move(GDVars.targetList, savedList, SizeOf(savedList));
    while (p <> nil) and (not found) do begin
      if CharHlp.HasEffect(p, effId, eff) then begin
        if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
          if effId = 49 then range := 6 else range := 1;
          Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(p)), CbtMap.CombatCellY(Types.PCharRecord(p)),
                                  range, 255, CbtMap.GetIconSize(Types.PCharRecord(p)), GDVars.arena);
          for i := 1 to GDVars.targetCount do
            if GDVars.targetList[i].creatureIndex = CbtMap.CombatSlot(Types.PCharRecord(Types.PCharRecord(cr))) then
              found := True;
        end else
          found := True;
      end;
      p := p^.next;
    end;
    Move(savedList, GDVars.targetList, SizeOf(savedList));
  end;
  if found then
    FxEngine.CallEffectHandler(effId, cr, eff, False);
end;

{ Lets a creature's magic resistance cancel the pending spell: with an effect pending (and, when damage is pending, a
  magical one), d100 against its resistance adjusted by 5 per caster level below 11 (above 11 lowers it) clears the
  pending damage and, except for effects 91 and 82, the pending effect.
  @param(cr The creature resisting.) }
procedure CheckSpellResistance(cr: Types.PCharRecord);
var
  resist: Byte;
  chance: Byte;
  lvl: Byte;
begin
  resist := cr^.magicResistance;
  if (resist <> 0) and (GDVars.currentEffectId <> 0) then begin
    if GDVars.currentDamage <> 0 then
      if (GDVars.elementMask and $08) = 0 then Exit;
    lvl := CharHlp.GetCasterLevel(GDVars.currentSpell);
    chance := resist + (11 - lvl) * 5;
    if FxEngine.RollDice(1, 100) <= chance then begin
      GDVars.currentDamage := 0;
      if (GDVars.currentEffectId <> 91) and (GDVars.currentEffectId <> 82) then
        GDVars.currentEffectId := 0;
    end;
  end;
end;

procedure TriggerEffectsWithCondition(id: Byte; var cr);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  case id of
    C_Cond.ATTACKER_VETO: ;
    C_Cond.TARGET_VETO: begin
         FxEngine.TriggerEffect(cr, 37); FxEngine.TriggerEffect(cr, 25);
       end;
    2: begin
         FxEngine.TriggerEffect(cr, 88); FxEngine.TriggerEffect(cr, 87); FxEngine.TriggerEffect(cr, 86);
         FxEngine.TriggerEffect(cr, 81); FxEngine.TriggerEffect(cr, 69); FxEngine.TriggerEffect(cr, 64);
         FxEngine.TriggerEffect(cr, 65);
       end;
    3: begin
         FxEngine.TriggerEffect(cr, 69); FxEngine.TriggerEffect(cr, 64); FxEngine.TriggerEffect(cr, 65);
         FxEngine.TriggerEffect(cr, 81); FxEngine.TriggerEffect(cr, 86); FxEngine.TriggerEffect(cr, 87);
       end;
    C_Cond.WEAPON_DAMAGE_ATTACKER: begin
         FxEngine.TriggerEffect(cr, 7); FxEngine.TriggerEffect(cr, 29); FxEngine.TriggerEffect(cr, 75);
         FxEngine.TriggerEffect(cr, 105); FxEngine.TriggerEffect(cr, 114); FxEngine.TriggerEffect(cr, 115);
         FxEngine.TriggerEffect(cr, 117);
       end;
    C_Cond.WEAPON_DAMAGE_DEFENDER: begin
         FxEngine.TriggerEffect(cr, 59); FxEngine.TriggerEffect(cr, 28); FxEngine.TriggerEffect(cr, 41);
         FxEngine.TriggerEffect(cr, 100); FxEngine.TriggerEffect(cr, 103); FxEngine.TriggerEffect(cr, 93);
         FxEngine.TriggerEffect(cr, 101); FxEngine.TriggerEffect(cr, 112);
       end;
    6: begin
         FxEngine.CheckSpellResistance(Types.PCharRecord(cr));
         FxEngine.TriggerEffect(cr, 71); FxEngine.TriggerEffect(cr, 59); FxEngine.TriggerEffect(cr, 61);
         FxEngine.TriggerEffect(cr, 10); FxEngine.TriggerEffect(cr, 20); FxEngine.TriggerEffect(cr, 102);
         FxEngine.TriggerEffect(cr, 17); FxEngine.TriggerEffect(cr, 28); FxEngine.TriggerEffect(cr, 98);
         FxEngine.TriggerEffect(cr, 73); FxEngine.TriggerEffect(cr, 63);
       end;
    7: begin
         FxEngine.TriggerEffect(cr, 51); FxEngine.TriggerEffect(cr, 52); FxEngine.TriggerEffect(cr, 53);
         FxEngine.TriggerEffect(cr, 31); FxEngine.TriggerEffect(cr, 3); FxEngine.TriggerEffect(cr, 27);
       end;
    8: begin
         FxEngine.TriggerEffect(cr, 82); FxEngine.TriggerEffect(cr, 89); FxEngine.TriggerEffect(cr, 56);
       end;
    9: begin
         FxEngine.CheckSpellResistance(Types.PCharRecord(cr));
         FxEngine.TriggerEffect(cr, 71); FxEngine.TriggerEffect(cr, 116); FxEngine.TriggerEffect(cr, 92);
         FxEngine.TriggerEffect(cr, 59); FxEngine.TriggerEffect(cr, 95); FxEngine.TriggerEffect(cr, 96);
         FxEngine.TriggerEffect(cr, 97); FxEngine.TriggerEffect(cr, 98); FxEngine.TriggerEffect(cr, 99);
         FxEngine.TriggerEffect(cr, 18); FxEngine.TriggerEffect(cr, 63);
       end;
    10: begin
         FxEngine.TriggerEffect(cr, 7); FxEngine.TriggerEffect(cr, 118); FxEngine.TriggerEffect(cr, 119);
         FxEngine.TriggerEffect(cr, 57); FxEngine.TriggerEffect(cr, 1); FxEngine.TriggerEffect(cr, 2);
         FxEngine.TriggerEffect(cr, C_Effect.BLIND); FxEngine.TriggerEffect(cr, C_Effect.CURSED);
         FxEngine.TriggerEffect(cr, 49); FxEngine.TriggerEffect(cr, 26); FxEngine.TriggerEffect(cr, 75);
       end;
    C_Cond.DEFENDER_ARMOR_CLASS: begin
         FxEngine.TriggerEffect(cr, C_Effect.BLIND); FxEngine.TriggerEffect(cr, 17); FxEngine.TriggerEffect(cr, 8);
         FxEngine.TriggerEffect(cr, 9); FxEngine.TriggerEffect(cr, 45); FxEngine.TriggerEffect(cr, 46);
         FxEngine.TriggerEffect(cr, 30);
       end;
    12: begin
         FxEngine.TriggerEffect(cr, 94); FxEngine.TriggerEffect(cr, 8); FxEngine.TriggerEffect(cr, 9);
         FxEngine.TriggerEffect(cr, 10); FxEngine.TriggerEffect(cr, 17); FxEngine.TriggerEffect(cr, 20);
         FxEngine.TriggerEffect(cr, C_Effect.BLIND); FxEngine.TriggerEffect(cr, C_Effect.CURSED);
         FxEngine.TriggerEffect(cr, 45);
         FxEngine.TriggerEffect(cr, 46); FxEngine.TriggerEffect(cr, 49); FxEngine.TriggerEffect(cr, 61);
         FxEngine.TriggerEffect(cr, 99); FxEngine.TriggerEffect(cr, 50); FxEngine.TriggerEffect(cr, 54);
       end;
    C_Cond.HIT_POINTS_ZERO: begin
         FxEngine.TriggerEffect(cr, C_Effect.FEEBLEMINDED); FxEngine.TriggerEffect(cr, 67);
         FxEngine.TriggerEffect(cr, 13);
         FxEngine.TriggerEffect(cr, C_Effect.ANIMATED); FxEngine.TriggerEffect(cr, 70);
       end;
    14: begin
         FxEngine.TriggerEffect(cr, 6); FxEngine.TriggerEffect(cr, 85); FxEngine.TriggerEffect(cr, 84);
         FxEngine.TriggerEffect(cr, 83); FxEngine.TriggerEffect(cr, 78); FxEngine.TriggerEffect(cr, 74);
         FxEngine.TriggerEffect(cr, 4); FxEngine.TriggerEffect(cr, 90); FxEngine.TriggerEffect(cr, 104);
       end;
    15: begin
         FxEngine.TriggerEffect(cr, 79); FxEngine.TriggerEffect(cr, 76); FxEngine.TriggerEffect(cr, 72);
         FxEngine.TriggerEffect(cr, 66); FxEngine.TriggerEffect(cr, 48); FxEngine.TriggerEffect(cr, 21);
         FxEngine.TriggerEffect(cr, 30); FxEngine.TriggerEffect(cr, 11); FxEngine.TriggerEffect(cr, 77);
       end;
    16: begin
         FxEngine.TriggerEffect(cr, 25); FxEngine.TriggerEffect(cr, 37); FxEngine.TriggerEffect(cr, 47);
         FxEngine.TriggerEffect(cr, 89);
       end;
    17: begin
         FxEngine.TriggerEffect(cr, 1); FxEngine.TriggerEffect(cr, 2); FxEngine.TriggerEffect(cr, 11);
       end;
    C_Cond.MOVE_ATTACK_RATE: begin
         FxEngine.TriggerEffect(cr, C_Effect.HASTED); FxEngine.TriggerEffect(cr, C_Effect.SLOWED);
       end;
    19: begin
         FxEngine.TriggerEffect(cr, 23); FxEngine.TriggerEffect(cr, 56); FxEngine.TriggerEffect(cr, 11);
       end;
    20: begin
         FxEngine.TriggerEffect(cr, 50); FxEngine.TriggerEffect(cr, 54);
       end;
    21: FxEngine.TriggerEffect(cr, 35);
    22: ;
    23: ;
    24: FxEngine.TriggerEffect(cr, 82);
  end;
end;

{ Finds the caster of the cloud covering a combat cell. Note: the direction table is read from index 1 against a table
  that starts at index 0, so with four cells per cloud the last cell checked comes from the byte after the table.
  @param(x Column of the cell.)
  @param(y Row of the cell.)
  @param(start First cloud node to check.)
  @param(count Number of cells checked per cloud.)
  @param(tbl Directions from a cloud's corner to its cells, read from index 1.)
  @returns(The caster of the first cloud, from the given node on, that has one of its checked cells live at the cell;
    the head of the creature list when there is none.) }
function FindCreatureAtCell(x, y: ShortInt; start: Types.PCloudNode; count: Byte; tbl: PDirs): Types.PCharRecord;
var
  p: Types.PCloudNode;
  found: Boolean;
  i: Byte;
begin
  p := start;
  found := False;
  while (p <> nil) and (not found) do begin
    for i := 1 to count do
      if p^.activeCells[i] <> 0 then
        if (p^.x + GDConsts.dirDeltaX[tbl^[i]] = x) and (p^.y + GDConsts.dirDeltaY[tbl^[i]] = y) then
          found := True;
    if not found then
      p := p^.next;
  end;
  if found then
    FindCreatureAtCell := p^.owner
  else
    FindCreatureAtCell := GDVars.partyHead;
end;

procedure ConsiderTerrainEffects(cr: Pointer; b: Byte);
var
  terrIdx: Byte;
  crIdx: Byte;
  eff: Types.PEffectRec;
  eff2: Types.PEffectRec;
  saved: Boolean;
  isCloud: Byte;
  isHarmful: Byte;
  savedChar: Types.PCharRecord;
begin
  if Types.PCharRecord(cr)^.inPlay <> 0 then begin
    CbtMap.ProbeDirection(Types.PCharRecord(cr), 8, crIdx, terrIdx, isCloud, isHarmful);
    if (isCloud <> 0) and (b <> 0) and (Byte(Types.PCharRecord(cr)^.levelUndead) = 0) and
        (not CharHlp.HasEffect(cr, 31, eff)) and (not CharHlp.HasEffect(cr, 99, eff)) then begin
      saved := FxEngine.RollSavingThrow(cr, 0, 0);
      if saved then begin
        savedChar := GDVars.curChar;
        GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(Types.PCharRecord(cr)),
                                               CbtMap.CombatCellY(Types.PCharRecord(cr)), GDVars.cloudHead, 4,
                                               @terrainDirs);
        FxEngine.AddEffectWithMessage(cr, 30, FxEngine.RollDice(1, 4) + 1, 255, 0, 0, Ord(saved), 'starts to cough');
        eff2 := nil;
        if CharHlp.HasEffect(cr, 30, eff2) then
          FxEngine.CallEffectHandler(30, cr, eff, False);
        GDVars.curChar := savedChar;
      end else begin
        savedChar := GDVars.curChar;
        GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(Types.PCharRecord(cr)),
                                               CbtMap.CombatCellY(Types.PCharRecord(cr)), GDVars.cloudHead, 4,
                                               @terrainDirs);
        FxEngine.AddEffectWithMessage(cr, 31, FxEngine.RollDice(1, 4) + 1, 255, 0, 0, Ord(saved),
                                      'chokes and gags from nausea');
        if CharHlp.HasEffect(cr, 31, eff) then
          FxEngine.CallEffectHandler(31, cr, eff, False);
        GDVars.curChar := savedChar;
      end;
    end;
    if isHarmful <> 0 then
      FxEngine.InflictNonWeaponDamage(cr, FxEngine.RollDamageDice(1, 6), 0, False);
  end;
end;

function AttackRollNoAttacker(defender: Pointer; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := False;
  GDVars.gAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.gAttackRoll > 1 then begin
    if GDVars.gAttackRoll = 20 then GDVars.gAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if GDVars.gAttackRoll >= 0 then
      if GDVars.gAttackRoll + sixtyMinusThac0 > Types.PCharRecord(defender)^.acCur[0] then
        AttackRollNoAttacker := True;
  end;
end;

function AttackRoll(attacker, defender: Pointer; sixtyMinusAc: Byte): Boolean;
var
  lightAdj: ShortInt;
begin
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.gAttackRoll := FxEngine.RollDice(1, 20);
  if GDVars.gAttackRoll > 1 then begin
    if GDVars.gAttackRoll = 20 then GDVars.gAttackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(10, attacker);
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if Types.PCharRecord(attacker)^.hostile = C_Side.PLAYER then begin
      lightAdj := GDVars.zone1^.modPartyThac0;
      case FxEngine.LIGHT_LEVEL of
        1: Inc(lightAdj, 2);
        2: Inc(lightAdj);
        4: Dec(lightAdj);
        5: Dec(lightAdj, 2);
      end;
    end else
      lightAdj := GDVars.zone1^.modMonThac0;
    if GDVars.gAttackRoll >= 0 then
      if GDVars.gAttackRoll + Types.PCharRecord(attacker)^.thac0Adj + lightAdj >= sixtyMinusAc then
        AttackRoll := True;
  end;
end;

function RollSavingThrow(cr: Pointer; a, b: Byte): Boolean;
var
  gv: Byte;
begin
  GDVars.saveResult := True;
  GDVars.saveRoll := FxEngine.RollDice(1, 20);
  case GDVars.saveRoll of
    1: GDVars.saveResult := False;
    20: GDVars.saveResult := True;
  else begin
      if ShortInt(Byte(Types.PCharRecord(cr)^.classLevels[C_Class.MAGE])) > 0 then
        if Types.PCharRecord(cr)^.robeOrder > 0 then begin
          gv := Types.PCharRecord(cr)^.robeOrder + $1F8;
          case GDVars.zone0^.vars[gv + $4B00] of
            0: Dec(b);
            2: Inc(b);
          end;
        end;
      GDVars.saveRoll := GDVars.saveRoll + Types.PCharRecord(cr)^.saveBonus + ShortInt(b);
      GDVars.saveType := a;
      FxEngine.TriggerEffectsWithCondition(12, cr);
      if Types.PCharRecord(cr)^.saves[ShortInt(a)] <= GDVars.saveRoll then
        GDVars.saveResult := True
      else
        GDVars.saveResult := False;
    end;
  end;
  RollSavingThrow := GDVars.saveResult;
end;

function RollDice(a, b: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if a > 0 then
    for i := 1 to a do
      Inc(total, Random(b) + 1);
  RollDice := total;
end;

function RollDamageDice(a, b: Byte): Byte;
begin
  GDVars.diceCount := a;
  RollDamageDice := FxEngine.RollDice(a, b);
end;

procedure AddEffect(cr: Pointer; effId: Byte; minutes: Word; strength: Byte; onRemove: Boolean);
var
  node: Types.PEffectRec;
  p: Types.PEffectRec;
begin
  GetMem(node, SizeOf(Types.TEffectRec));
  if Types.PCharRecord(cr)^.effects = nil then
    Types.PCharRecord(cr)^.effects := node
  else begin
    p := Types.PCharRecord(cr)^.effects;
    while p^.next <> nil do
      p := p^.next;
    p^.next := node;
  end;
  node^.next := nil;
  node^.id := effId;
  node^.duration := minutes;
  node^.onRemove := Ord(onRemove);
  node^.strength := strength;
end;

procedure PutOutOfPlayWithStatus(cr: Pointer; n: Byte; s: Types.TStr40);
var
  slot: Byte;
begin
  if Types.PCharRecord(cr)^.inPlay <> 0 then begin
    slot := CbtMap.CombatSlot(Types.PCharRecord(cr));
    CbtMap.DisplayMapViewCentered(Types.PCharRecord(cr), 3, False);
    CharHlp.PrintCreatureMessage(cr, s, 10, True);
    Types.PCharRecord(cr)^.inPlay := 0;
    Types.PCharRecord(cr)^.status := n;
    if Types.PCharRecord(cr)^.status <> C_Status.RUNNING then
      Types.PCharRecord(cr)^.hpCur := 0;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    Blit.FlushView;
    GDVars.arenaLoc[slot].size := 0;
    CbtMap.BuildArenaArrays;
    if CharHlp.EndActions(cr) then
      FxEngine.RemoveEffectsHp0(cr);
  end;
end;

procedure RemoveInvisibility(cr: Pointer);
var
  eff: Types.PEffectRec;
begin
  while CharHlp.HasEffect(cr, 25, eff) do
    FxEngine.RemoveEffect(cr, 25, eff);
end;

procedure RemoveEffectsHp0(cr: Pointer);
var
  i: Byte;
  eff: Types.PEffectRec;
begin
  for i := 1 to 16 do
    FxEngine.RemoveEffect(cr, GDConsts.hpZeroEffectIds[i], nil);
  if CharHlp.HasEffect(cr, 77, eff) then
    if Types.PCharRecord(cr)^.npc = $B3 then
      Types.PCharRecord(cr)^.hostile := C_Side.PLAYER;
end;

procedure RemoveAiEffects(cr: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
end;

function RemoveEffectWithMessage(cr: Pointer; effId: Byte): Boolean;
var
  eff: Types.PEffectRec;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(cr, effId, eff) then begin
    CharHlp.PrintCreatureMessage(cr, 'is Cured', 10, True);
    FxEngine.RemoveEffect(cr, effId, eff);
    RemoveEffectWithMessage := True;
  end;
end;

{ Encodes a Strength as an effect strength: 18 with exceptional Strength becomes the exceptional value + 1 (1..101), any
  other base Strength becomes the base + 100.
  @param(baseStr Base Strength.)
  @param(excStr Exceptional Strength, read when the base Strength is 18.)
  @returns(The encoded Strength.) }
function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then
    StrengthModifier := excStr + 1;
end;

{ Decodes an effect's strength byte, bit 7 aside, into Strength: up to 101 is Strength 18 with exceptional Strength of
  the value less 1, above it Strength of the value less 100 with no exceptional Strength.
  @param(eff The Strength effect.)
  @param(baseStr Receives Strength.)
  @param(excStr Receives exceptional Strength.) }
procedure StrengthEffectToStrength(eff: Types.PEffectRec; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := eff^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18;
  end else
    baseStr := baseStr - 100;
end;

function AdjustForNewStrength(cr: Pointer; baseStr, excStr: Byte; var effStrength: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  found: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  oldBase: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldExc: Byte;
begin
  if (baseStr > Types.PCharRecord(cr)^.stats[C_Stat.STRENGTH].base) or
      ((baseStr = 18) and (excStr > Types.PCharRecord(cr)^.strExcBase)) then begin
    AdjustForNewStrength := True;
    effStrength := FxEngine.StrengthModifier(baseStr, excStr);
  end else
    AdjustForNewStrength := False;
end;

procedure RecalcAbility(cr: Pointer; n: ShortInt);
var
  statVal: Byte;
  baseStr: Byte;
  strExc: Byte;
  excStr: Byte;
  eff: Types.PEffectRec;
  hpSave: Byte;
  accum: Byte;
  tmp: Byte;
  i: ShortInt;
  p: Types.PItemRec;
  statOverride: Byte;
  enc: Byte;
  count: Byte;

  { Raises the strength being built to the candidate when higher, comparing exceptional strength only at 18. }
  procedure StrClamp;
  begin
    if (baseStr > statVal) or ((baseStr = 18) and (excStr > strExc)) then begin
      statVal := baseStr;
      strExc := excStr;
    end;
  end;

  { Adds to accum the Constitution hit-point bonus of statVal for b levels of class a, held below the class's cap. }
  procedure StatBonus(a: ShortInt; b: Byte);
  begin
    if GDConsts.hitDiceLimit[a] <= b then
      b := GDConsts.hitDiceLimit[a] - 1;
    if a = C_Class.RANGER then
      if (Byte(Types.PCharRecord(cr)^.dualClassThreshold) = 0) or
          (Byte(Types.PCharRecord(cr)^.classLevels2[C_Class.RANGER]) =
           Byte(Types.PCharRecord(cr)^.dualClassThreshold)) then
        Inc(b);
    if (a = C_Class.FIGHTER) or (a = C_Class.RANGER) or (a = C_Class.KNIGHT) then begin
      case statVal of
        15..19: Inc(accum, (statVal - 14) * b);
        20: Inc(accum, b * 5);
        21..23: Inc(accum, b * 6);
        24..25: Inc(accum, b * 7);
      end;
    end else begin
      if statVal > 15 then
        Inc(accum, b * 2)
      else if statVal = 15 then
        Inc(accum, b);
    end;
  end;

begin
  accum := 0;
  baseStr := 0;
  excStr := 0;
  statOverride := 255;
  p := Types.PCharRecord(cr)^.itemsAddr;
  statVal := Types.PCharRecord(cr)^.stats[n].base;
  strExc := Types.PCharRecord(cr)^.strExcBase;
  { scan the item list and add up the stat modifiers }
  while p <> nil do begin
    if (p^.special > $80) and (p^.equipped <> 0) then begin
      enc := p^.special and $7F;
      case n of
        C_Stat.STRENGTH: begin
             case enc of
               3: begin baseStr := 18; excStr := 100; end;
               5: case p^.effect of
                    0: begin baseStr := 18; excStr := 100; end;
                    1: baseStr := 19;
                    2: baseStr := 20;
                    3: baseStr := 21;
                    4: baseStr := 22;
                    5: baseStr := 23;
                    6: baseStr := 24;
                  end;
               8: if (Types.PCharRecord(cr)^.stats[C_Stat.STRENGTH].base < 18) and
                 (p^.effect = C_Stat.STRENGTH) then begin
                    baseStr := Types.PCharRecord(cr)^.stats[C_Stat.STRENGTH].base + 1;
                    excStr := 0;
                  end;
               13: statOverride := 3;
             end;
             StrClamp;
           end;
        C_Stat.CONSTITUTION: begin
             if enc = 6 then Inc(statVal)
             else if enc = 8 then
               if (Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].base < 18) and
                   (p^.effect = C_Stat.CONSTITUTION) then Inc(statVal);
           end;
        C_Stat.INTELLIGENCE: begin
             case enc of
               8: if (Types.PCharRecord(cr)^.stats[C_Stat.INTELLIGENCE].base < 18) and
                 (p^.effect = C_Stat.INTELLIGENCE) then Inc(statVal);
               12: statOverride := 7;
               13: statOverride := 3;
             end;
           end;
        C_Stat.WISDOM: if enc = 8 then
             if (p^.effect = C_Stat.WISDOM) and
                 (Types.PCharRecord(cr)^.stats[C_Stat.WISDOM].base < 18) then Inc(statVal);
        C_Stat.DEXTERITY: begin
             case enc of
               2: case Types.PCharRecord(cr)^.stats[C_Stat.DEXTERITY].base of
                    0..6: Inc(statVal, 4);
                    7..13: Inc(statVal, 2);
                  else Inc(statVal);
                  end;
               8: if (Types.PCharRecord(cr)^.stats[C_Stat.DEXTERITY].base < 18) and
                 (p^.effect = C_Stat.DEXTERITY) then Inc(statVal);
               10: Dec(statVal, 2);
             end;
           end;
        C_Stat.CHARISMA: begin
             case enc of
               6: Dec(statVal);
               8: if (Types.PCharRecord(cr)^.stats[C_Stat.CHARISMA].base < 18) and
                 (p^.effect = C_Stat.CHARISMA) then Inc(statVal);
             end;
           end;
      end;
    end;
    p := p^.next;
  end;
  { write back the recomputed stat }
  case n of
    C_Stat.STRENGTH: begin
         if CharHlp.HasEffect(cr, 38, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           if (statVal <= 18) and (strExc < 100) then begin
             baseStr := statVal + baseStr;
             if baseStr > 18 then begin
               if (ShortInt(Byte(Types.PCharRecord(cr)^.classLevels[C_Class.FIGHTER])) > 0) or
                   (ShortInt(Byte(Types.PCharRecord(cr)^.classLevels2[C_Class.FIGHTER])) > 0) or
                   (ShortInt(Byte(Types.PCharRecord(cr)^.classLevels[C_Class.KNIGHT])) > 0) or
                   (ShortInt(Byte(Types.PCharRecord(cr)^.classLevels2[C_Class.KNIGHT])) > 0) or
                   (ShortInt(Byte(Types.PCharRecord(cr)^.classLevels[C_Class.RANGER])) > 0) or
                   (ShortInt(Byte(Types.PCharRecord(cr)^.classLevels2[C_Class.RANGER])) > 0) then begin
                 excStr := Types.PCharRecord(cr)^.strExc + (baseStr - 18) * 10;
                 if excStr > 100 then excStr := 100;
                 baseStr := 18;
               end else
                 baseStr := 18;
             end;
           end;
           StrClamp;
         end;
         if CharHlp.HasEffect(cr, 113, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         if CharHlp.HasEffect(cr, 12, eff) then begin
           FxEngine.StrengthEffectToStrength(eff, baseStr, excStr);
           StrClamp;
         end;
         if statOverride <> 255 then begin
           Types.PCharRecord(cr)^.stats[C_Stat.STRENGTH].cur := statOverride;
           Types.PCharRecord(cr)^.strExc := 0;
         end else begin
           Types.PCharRecord(cr)^.stats[C_Stat.STRENGTH].cur := statVal;
           Types.PCharRecord(cr)^.strExc := strExc;
         end;
       end;
    C_Stat.CONSTITUTION: begin
         count := 0;
         hpSave := Types.PCharRecord(cr)^.hpMax;
         Types.PCharRecord(cr)^.hpMax := Types.PCharRecord(cr)^.hpRolled;
         for i := 0 to 7 do begin
           tmp := Byte(Types.PCharRecord(cr)^.classLevels2[i]);
           if tmp > 0 then StatBonus(i, tmp);
           tmp := Byte(Types.PCharRecord(cr)^.classLevels[i]);
           if tmp > 0 then Inc(count);
           if GDConsts.hitDiceLimit[i] < tmp then tmp := GDConsts.hitDiceLimit[i];
           if tmp > Byte(Types.PCharRecord(cr)^.dualClassThreshold) then begin
             Dec(tmp, Byte(Types.PCharRecord(cr)^.dualClassThreshold));
             StatBonus(i, tmp);
           end;
         end;
         accum := accum div count;
         Inc(Types.PCharRecord(cr)^.hpMax, accum);
         if Types.PCharRecord(cr)^.hpMax > hpSave then
           Inc(Types.PCharRecord(cr)^.hpCur, Types.PCharRecord(cr)^.hpMax - hpSave);
         if Types.PCharRecord(cr)^.hpMax < hpSave then begin
           if Types.PCharRecord(cr)^.hpCur > hpSave - Types.PCharRecord(cr)^.hpMax then
             Dec(Types.PCharRecord(cr)^.hpCur, hpSave - Types.PCharRecord(cr)^.hpMax)
           else
             Types.PCharRecord(cr)^.hpCur := 0;
         end;
         Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur := statVal;
         if Types.PCharRecord(cr)^.stats[C_Stat.CONSTITUTION].cur >= 20 then begin
           if not CharHlp.HasEffect(cr, 62, eff) then
             FxEngine.AddEffect(cr, 62, 60, 255, True);
         end else
           FxEngine.RemoveEffect(cr, 62, nil);
       end;
    C_Stat.INTELLIGENCE: ;
    C_Stat.WISDOM: ;
    C_Stat.DEXTERITY: if statOverride <> 255 then
         Types.PCharRecord(cr)^.stats[C_Stat.DEXTERITY].cur := statOverride
       else
         Types.PCharRecord(cr)^.stats[C_Stat.DEXTERITY].cur := statVal;
    C_Stat.CHARISMA: begin
         if CharHlp.HasEffect(cr, 14, eff) then
           Inc(statVal, eff^.strength);
         Types.PCharRecord(cr)^.stats[C_Stat.CHARISMA].cur := statVal;
       end;
  end;
end;

procedure InflictNonWeaponDamage(cr: Pointer; damage, saveReduction: Byte; saved: Boolean);
var
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Byte;
begin
  GDVars.currentDamage := damage;
  FxEngine.TriggerEffectsWithCondition(6, cr);
  if saved then begin
    case saveReduction of
      1: GDVars.currentDamage := 0;
      2: GDVars.currentDamage := GDVars.currentDamage div 2;
    end;
  end else
    FxEngine.TriggerEffectsWithCondition(20, cr);
  if GDVars.currentDamage > 0 then
    if Types.PCharRecord(cr)^.inPlay <> 0 then begin
      if GDVars.currentDamage <> 1 then
        s := 'takes ' + CharHlp.Uint8Str(GDVars.currentDamage) + ' points of damage '
      else
        s := 'takes 1 point of damage ';
      case GDVars.elementMask and $F7 of
        1: s := s + 'from Fire';
        2: s := s + 'from Cold';
        4: s := s + 'from Electricity';
        $10: s := s + 'from Acid';
      end;
      if (GDVars.elementMask and $08) = GDVars.elementMask then
        s := s + 'from Magic';
      CharHlp.PrintNameStringAnim(cr, 0, s);
      CharHlp.InflictDamage(cr, GDVars.currentDamage);
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        Types.PCharRecord(cr)^.combatAddr^.castOk := 0;
        if Types.PCharRecord(cr)^.combatAddr^.spellCast > 0 then begin
          CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
          CharHlp.RemoveSpell(cr, Types.PCharRecord(cr)^.combatAddr^.spellCast);
          turnDone := Ord(CharHlp.EndActions(cr));
        end;
      end;
      if Types.PCharRecord(cr)^.inPlay = 0 then begin
        s := 'Goes Down';
        if Types.PCharRecord(cr)^.status = C_Status.DYING then
          s := s + ', and is Dying';
        if Types.PCharRecord(cr)^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
          s := 'is killed';
        CharHlp.PrintCreatureMessage(cr, s, GDVars.curRow + 1, False);
        if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
          TextRend.pauseOnly
        else begin
          FxEngine.RemoveEffectsHp0(cr);
          FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, cr);
          if (Types.PCharRecord(cr)^.inPlay = 0) and (Types.PCharRecord(cr)^.status <> C_Status.EXPLODED) then
            CbtMap.CreatureDowned(Types.PCharRecord(cr))
          else
            TextRend.pauseOnly;
        end;
      end;
      CharHlp.ClearMessageWindow;
    end;
end;

procedure AddEffectWithMessage(cr: Pointer; effId: Byte; minutes: Word; strength: Byte; onRemove, saveNegates,
                               saved: Byte; msg: Types.TStr40);
var
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  oldEffect: Byte;
begin
  GDVars.currentEffectId := effId;
  FxEngine.TriggerEffectsWithCondition(9, cr);
  if (GDVars.currentEffectId = 0) or ((saved <> 0) and (saveNegates = 1)) then
    CharHlp.PrintCreatureMessage(cr, 'is Unaffected', 10, True)
  else begin
    if CharHlp.HasEffect(cr, effId, eff) then
      if eff^.duration > 0 then
        FxEngine.RemoveEffect(cr, effId, eff);
    FxEngine.AddEffect(cr, effId, minutes, strength, Boolean(onRemove));
    if Length(msg) <> 0 then begin
      CharHlp.PrintNameStringAnim(cr, 1, msg);
      CharHlp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(cr: Pointer; hp: Byte; flag: Boolean): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
  RestoreHitPoints := False;
  if Types.PCharRecord(cr)^.status in
      [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS, C_Status.DYING] then begin
    if ((Types.PCharRecord(cr)^.hpCur < Types.PCharRecord(cr)^.hpMax) and flag) or (not flag) then begin
      Types.PCharRecord(cr)^.hpCur := Types.PCharRecord(cr)^.hpCur + hp;
      if Types.PCharRecord(cr)^.hpCur > Types.PCharRecord(cr)^.hpMax then
        Types.PCharRecord(cr)^.hpCur := Types.PCharRecord(cr)^.hpMax;
      if Types.PCharRecord(cr)^.inPlay = 0 then begin
        if Types.PCharRecord(cr)^.status = C_Status.DYING then
          Types.PCharRecord(cr)^.status := C_Status.UNCONSCIOUS;
        if Types.PCharRecord(cr)^.status = C_Status.UNCONSCIOUS then
          if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
            Types.PCharRecord(cr)^.status := C_Status.OKAY;
            Types.PCharRecord(cr)^.inPlay := 1;
          end;
      end;
      RestoreHitPoints := True;
    end;
  end;
end;

function ReviveDeadCreature(cr: Pointer; hp: Byte; msg: Types.TStr40): Boolean;
var
  savedGfx: Byte;
begin
  if CbtMap.IsValidCreatureLoc(Types.PCharRecord(cr), CbtMap.CombatCellX(Types.PCharRecord(cr)),
                               CbtMap.CombatCellY(Types.PCharRecord(cr)), True) then begin
    Types.PCharRecord(cr)^.status := C_Status.OKAY;
    Types.PCharRecord(cr)^.inPlay := 1;
    Types.PCharRecord(cr)^.hpCur := hp;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      savedGfx := GDVars.gfxEnabled;
      GDVars.gfxEnabled := 1;
      CbtMap.DisplayMapViewCentered(Types.PCharRecord(cr), 3, False);
      GDVars.gfxEnabled := savedGfx;
    end;
    CharHlp.PrintNameStringAnim(cr, 1, msg);
    CharHlp.CountTeams;
    ReviveDeadCreature := True;
  end else
    ReviveDeadCreature := False;
end;

procedure ProcessExplodingCreatures;
var
  i: Byte;
  j: Byte;
  cr: Types.PCharRecord;
  list: array[1..8] of Byte;
  cnt: Byte;
begin
  GDVars.explosionBusy := 1;
  GDVars.elementMask := 0;
  i := 1;
  while i <= GDVars.explosionCount do begin
    cr := GDVars.explosionQueue[i];
    if cr <> nil then begin
      CharHlp.PrintCreatureMessage(cr, 'explodes.', 10, True);
      Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(cr)), CbtMap.CombatCellY(Types.PCharRecord(cr)), 1,
                              255, CbtMap.GetIconSize(Types.PCharRecord(cr)), GDVars.arena);
      if GDVars.targetCount > 1 then begin
        cnt := GDVars.targetCount - 1;
        for j := 2 to GDVars.targetCount do
          list[j - 1] := GDVars.targetList[j].creatureIndex;
        for j := 1 to cnt do
          if GDVars.creatureArr[list[j]]^.status <> C_Status.EXPLODED then
            FxEngine.InflictNonWeaponDamage(GDVars.creatureArr[list[j]], FxEngine.RollDamageDice(1, 6), 0, False);
      end;
    end;
    { Note: these run outside the cr <> nil guard, so a nil queue slot is dereferenced here. }
    cr^.inPlay := 0;
    cr^.status := C_Status.DEAD_STATUS;
    CbtMap.CreatureDowned(Types.PCharRecord(cr));
    Inc(i);
  end;
  if GDVars.explosionCount > 0 then begin
    GDVars.explosionCount := 0;
    FillChar(GDVars.explosionQueue, SizeOf(GDVars.explosionQueue), 0);
  end;
  GDVars.explosionBusy := 0;
end;

begin
end.
