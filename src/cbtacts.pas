{ Combat actions, targeting, movement, attacks and combat spell selection. }
{$O+,F+}
unit CbtActs;
interface

uses Types, GDConsts, GDVars, ViewChar, Magic, FxEngine, CharHlp, ClassCal, MenuCore,
  Pathing, CbtMap, MapTiles, Debug, SoundDrv, TextRend, Crt, Blit, Border, GameIo, C_Keys, C_Class, C_Status, C_Terr,
  C_Dir, C_Spell, C_Side, C_Item, C_Cond;

{ Resets a creature for a new round: no spell being cast, casting allowed unless it stands in a stinking cloud, item use
  allowed, no attack made yet, the attack phase at 2, its current attacks (RecalcAttacksLeft, then the secondary attacks
  through AttacksFromRate after the condition-18 effects), its sweep budget (its attack level), its initiative and its
  movement. Initiative is 1d6 plus CharHlp.DexMissileAdjust's adjustment, at least 1, less 6 when the zone's surprise
  mask has the creature's side bit set (1 for the party, 2 for hostiles), and 0 for a creature out of play or a result
  outside 0..20.
  @param(creature The creature starting the round.) }
procedure BeginRound(creature: Pointer);

{ Computes a creature's movement in half-steps: its current movement plus, for the party, the zone's movement modifier
  (a result outside 1..96 becomes 1), doubled and then adjusted by its condition-18 effects, which run with the movement
  flag set.
  @param(creature The creature whose movement is computed.)
  @returns(The movement in half-steps.) }
function CalcCreatureMovement(creature: Pointer): Byte;

{ Moves a creature one cell in a direction. The step costs the terrain cost times 2 half-steps, times 3 on a diagonal;
  with too few left, movement drops to 0 but the step is still taken. The view follows the mover (faster in quick
  fight). The step plays the step sound, resets the creature's flanking counts and lets guarding enemies attack, and a
  mover left out of play or helpless loses the rest of its movement.
  @param(creature The creature moving.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure CombatMoveCreature(creature: Pointer; direction: Byte);

{ Gives each enemy adjacent to a creature before a step in direction, but not after it, one free attack on the mover,
  made as from behind, while the mover stays in play. Helpless and turned enemies are skipped, as are enemies an effect
  forbids to attack and those with a ranged weapon that cannot be thrown. An enemy with no initiative left that has
  already been attacked this round needs the mover in the five directions in front of it. The attack uses the enemy's
  highest phase with attacks left, granting one attack when that phase has no attacks left, and the enemy's own target
  is kept.
  @param(creature The creature about to move.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure AttacksOfOpportunity(creature: Pointer; direction: Byte);

{ Tries to flee. It succeeds automatically with no enemy in the target list, and otherwise when the creature's movement
  in whole steps beats the fastest enemy's, or on 1 in 2 when they tie. Success takes the creature out of play as
  running, with 'Got Away'; failure prints 'Escape is blocked'. The creature's actions end either way.
  @param(creature The creature fleeing.)
  @returns(The result of ending its actions.) }
function AttemptFlee(creature: Pointer): Boolean;

{ Sets a creature's current attacks for the round. It starts from the weapon's rate of fire (at least 2) when it has a
  ranged weapon with ammunition, else from its base attacks, both in half-attacks; applies its condition-18 effects and
  AttacksFromRate, and caps a ranged weapon by its ammunition. Once an attack has been made this round, the result only
  replaces the current attacks when it is lower.
  @param(creature The creature whose attacks are recalculated.) }
procedure RecalcAttacksLeft(creature: Pointer);

{ Sweeps level-0 enemies. When the defender is an adjacent level-0 enemy, the attacker's sweep budget exceeds its
  current attacks, and more adjacent level-0 enemies stand around it than it has current attacks, the attacker makes one
  attack on each of up to its sweep budget of them, the defender first.
  @param(att The creature attacking.)
  @param(def The enemy chosen to attack.)
  @returns(True if the attacker swept.) }
function SweepAttack(att, def: Pointer): Boolean;

{ Checks whether effects let one creature attack another. True when the target is the attacker itself, False when the
  target is nil. Otherwise the target's condition-1 effects run, then, unless they vetoed, the attacker's condition-0
  effects with the target as its temporary target; an effect vetoes by setting the targeting veto flag.
  @param(attacker The creature that would attack.)
  @param(target The creature it would attack, or nil.)
  @returns(True when the attack is allowed.) }
function CanTarget(attacker, target: Pointer): Boolean;

{ Turns undead. One d20 roll is compared with the turning table for up to 1d12 targets, highest-level undead first: a
  roll that fails against a target moves on to lower levels. The table row is the undead's level and the column the
  cleric level, counting earlier cleric levels while ClassCal.EarlierClassActive allows them, plus 2 for a follower of
  deity 2. A positive table value turns the target and zero or a negative one destroys it; while fewer than six undead
  have been affected, a destruction does not use up the last of the count. The creature's turnings and actions are used
  up.
  @param(creature The cleric turning undead.) }
procedure CombatTurnUndead(creature: Pointer);

{ Finds the highest-level unturned undead in the target list (any range) at or below a level cap; equal levels keep the
  earlier one.
  @param(creature The creature turning undead.)
  @param(target Receives the undead found, or nil.)
  @param(levelCap The highest undead level allowed; receives the level found, or 0.)
  @returns(True if a target was found.) }
function FindTurnUndeadTarget(creature: Pointer; var target; var levelCap): Boolean;

{ Records an attack on a defender for flanking: the defender's count of attackers goes up, and the angle between its
  facing and the attack's direction (0..4) is added to its spread, mod 8.
  @param(attacker The attacker.)
  @param(defender The defender.) }
procedure NoteAttackDirection(attacker, defender: Pointer);

{ Makes an attack, pushing the round limit 15 rounds on. Unless it comes from behind or the defender has already been
  attacked twice this round, the defender turns to face the attacker; otherwise, while the defender's icon is visible,
  an attack not from behind turns it around. The attacker turns toward the defender and takes it as its target, and
  missiles fly for the given weapon and for a readied weapon of type 28 or 29. If attacks remain, RollAttacks runs; the
  weapon then loses the primary attacks made from its quantity (not while a hoopak is readied), and once it is used up
  it is removed, an expended throwable weapon (other than a Spiritual Hammer) dropping into the treasure pile. Note: the
  readied weapon's type is read without checking that there is one.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(fromBehind Nonzero for an attack from behind: the defender keeps its facing.)
  @param(weapon The missile or thrown item, or nil for melee.)
  @param(done Set when the attacker's actions for the round are over.) }
procedure MakeAttack(attacker, defender: Pointer; fromBehind: Byte; weapon: Pointer; var done: Boolean);

{ Finds a Cure Light Wounds target in the creature's own cell or the eight around it. Candidates are the wounded ally
  with the fewest hit points (the creature itself, checked last, also wins whenever below half its maximum) and the last
  downed body, not dead, stoned or gone, found on a corpse cell. The body wins unless no body was found or the ally has
  7 hit points or fewer.
  @param(cr The caster.)
  @param(target Receives the target, or nil.)
  @returns(True if a target was found.) }
function FindCureTarget(cr: Pointer; var target): Boolean;

{ Builds the spell's target list from the low nibble of its area type. 0: the caster. 5: weighted picks until a second
  or later pick brings the total weight past a budget (spell 79: caster level, weighted by icon size; others: 2d4,
  weighted by level). 15: the picked creature, or the area around a picked bare cell. 8..14: everything within (area and
  7) of the picked cell. Others: (area and 3) + 1 separate picks; spells 23 and 49 refuse the caster. A repeated pick is
  refused; for the computer it uses up a pick, or one point of the weight budget. Note: the radius for a bare cell under
  type 15 is (area and $F) shr 4, which is always 0, and when the separate picks find nothing the target cell is read
  through the entry before the first target.
  @param(spell The spell being cast.)
  @param(ai False when the player aims; True for computer-controlled targeting.)
  @param(cast Set True; set False when the pick for types 8..15 fails or the separate picks find nothing.) }
procedure SelectCombatTargets(spell: Byte; ai: Boolean; var cast: Boolean);

{ Picks (from the spell menu, when no spell is given) and checks a spell, rejecting those not allowed in combat ('Camp
  Only Spell'). A casting delay (the casting time div 3) of 0 casts it at once and ends the caster's actions; otherwise
  the caster 'Begins Casting': the spell is recorded as being cast, initiative drops by the delay (to at least 1), and
  the caster moves back in the combat order to its new initiative, a tie going either way on a 1d2, so it resolves on a
  later action. Note: after an immediate cast, the result is that of ending the caster's actions, whatever the cast
  itself reported.
  @param(spell The spell to cast, or 0 to choose one from the menu.)
  @param(ai 0 redraws the combat screen first; passed on to the cast as its computer-controlled flag.)
  @param(cast Set True when a spell was cast or begun, False otherwise.) }
procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);

{ Confirms a weapon attack on an ally; enemies and quick-fighting attackers pass unasked. Yes sets the attacked-ally
  flags, and each NPC in okay status other than $B3 turns hostile and drops its target; the teams are recounted.
  @param(attacker The creature attacking.)
  @param(defender The creature it would attack.)
  @returns(True if the attack may go ahead.) }
function CheckAttackAlly(attacker, defender: Pointer): Boolean;

{ Runs target selection with cycling, the free cursor and confirmation. Targets the creature may not attack are skipped.
  N and P cycle, M (Manual) starts the free cursor, T confirms (a weapon attack goes through ConfirmAttackTarget), C
  recenters, and E or Escape exits.
  @param(cr The creature aiming.)
  @param(range The reach in whole steps; 255 means the readied weapon's range minus 1 (1 unarmed).)
  @param(weaponMode 1 for weapon attacks, 0 for spell casting.)
  @param(groundMode Nonzero lets the free cursor pick a bare cell.)
  @param(attackGate Nonzero lets the free cursor pick a creature.)
  @param(done True when a target was chosen.)
  @param(target Receives the choice, a creature pointer followed by its arena cell, passed untyped.) }
procedure CombatAimMenu(cr: Pointer; range: ShortInt; weaponMode, groundMode, attackGate: Byte; var done: Boolean;
                        var target);

{ Sets the hostiles' hit-point percentage: the enabled hostiles' current hit points as a percentage of the hostiles'
  combined maximum hit points, disabled ones included, rounded down to a multiple of five; it is left unchanged when
  there are no hostiles. Note: the totals are Words multiplied by 20, so above 3276 hit points the percentage wraps. }
procedure UpdateHostileHpPercent;

{ Finds the fastest enabled enemy's movement in whole steps, with no range or line-of-sight check.
  @param(creature The creature whose enemies are checked.)
  @returns(The highest enemy movement, in whole steps.) }
function HighestEnemyMovement(creature: Pointer): Byte;

{ Makes sure the creature's combat record holds a target. An existing lock is kept (without a range check) unless
  `forceNew` is set or it is now an ally, out of play or vetoed by CanTarget. Otherwise it makes up to 20 random picks
  among the enemies within range, dropping vetoed ones; a creature carrying effect 91 first tries the head of the target
  list when that is the marked creature. If that fails a second pass repeats it, ignoring terrain unless `forceNew` is
  set; there a nonzero `relaxed` accepts a pick without CanTarget.
  @param(cr The creature looking for a target.)
  @param(range The search range, in whole steps.)
  @param(relaxed Nonzero lets the second pass skip CanTarget.)
  @param(forceNew Nonzero drops any existing target and keeps terrain in the second pass.)
  @returns(True if a target is held.) }
function AcquireTarget(cr: Pointer; range, relaxed, forceNew: Byte): Boolean;

{ Debug victory: active when the second command-line parameter matches the debug password. Prints 'The Gods intervene!',
  kills each hostile, ends each creature's actions and rebuilds the view.
  @returns(True when the cheat ran.) }
function VictoryCheat: Boolean;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCbtActs;

implementation

function AttacksFromRate(rate: Byte): Byte; forward;

type
  { Selected creature or ground-cell result. }
  TAimTarget = record
    cr: Pointer;
    x: ShortInt;
    y: ShortInt;
    yTail: Byte;
  end;

procedure BeginRound(creature: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  cellIndex: Byte;
  inStinkingCloud: Byte;
  inAcidPool: Byte;
begin
  with Types.PCharRecord(creature)^.combatAddr^ do begin
    spellCast := 0;
    CbtMap.ProbeDirection(Types.PCharRecord(creature), C_Dir.CENTER,
                          cellIndex, cellIndex, inStinkingCloud, inAcidPool);
    castOk := Byte(inStinkingCloud = 0);
    itemUseAllowed := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GDVars.moveAttackMultiplier := Types.PCharRecord(creature)^.attacks2;
    GDVars.movementFlags[0] := 0;
    FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
    Types.PCharRecord(creature)^.curAtt[2] := CbtActs.AttacksFromRate(GDVars.moveAttackMultiplier);
    sweepBudget := Types.PCharRecord(creature)^.attackLevel;
    if Types.PCharRecord(creature)^.inPlay <> 0 then begin
      initiative := FxEngine.RollDice(1, 6) + CharHlp.DexMissileAdjust(creature);
      if initiative < 1 then
        initiative := 1;
      if Byte((Types.PCharRecord(creature)^.hostile + 1) and Integer(GDVars.zone1^.surpriseMask)) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  Types.PCharRecord(creature)^.combatAddr^.movement := CbtActs.CalcCreatureMovement(creature);
end;

function CalcCreatureMovement(creature: Pointer): Byte;
var
  movement: Byte;
begin
  movement := Types.PCharRecord(creature)^.movementCur;
  if Types.PCharRecord(creature)^.hostile = C_Side.PLAYER then
    movement := movement + GDVars.zone1^.modPartyMove;
  GDVars.movementFlags[0] := 1;
  if (movement < 1) or (movement > 96) then
    movement := 1;
  GDVars.moveAttackMultiplier := movement * 2;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  GDVars.movementFlags[0] := 0;
  CalcCreatureMovement := GDVars.moveAttackMultiplier;
end;

function IsBackstab(attacker, defender: Pointer): Boolean; forward;

procedure ApplyRangePenalty(attacker, defender: Pointer; var armorClass: Byte); forward;

procedure AnimateMissile(attacker, defender, weapon: Pointer); forward;

{ Rolls one attack's damage into GDVars.currentDamage: the current damage dice of the attack phase plus its modifier,
  adjusted by attacker's condition-4 and defender's condition-5 effects, then multiplied on a backstab by (thief level -
  1) div 4 + 2, where the thief level counts earlier thief levels while ClassCal.EarlierClassActive allows them. It then
  clears the damage element mask. Note: GDVars.currentDamage is a Byte, so the test for a negative total never passes
  and a negative total wraps.
  @param(attacker The creature dealing the damage.)
  @param(defender The creature hit; it is tested for a backstab.)
  @param(phase Attack phase, 1 or 2, whose dice and modifier are used.) }
procedure CalcWeaponDamage(attacker, defender: Pointer; phase: Byte);
begin
  GDVars.currentDamage := FxEngine.RollDamageDice(Types.PCharRecord(attacker)^.curRolls[phase],
                                                    Types.PCharRecord(attacker)^.curDice[phase])
             + Types.PCharRecord(attacker)^.curMod[phase];
  if GDVars.currentDamage < 0 then
    GDVars.currentDamage := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_ATTACKER, attacker);
  FxEngine.TriggerEffectsWithCondition(C_Cond.WEAPON_DAMAGE_DEFENDER, defender);
  if CbtActs.IsBackstab(attacker, defender) then
    GDVars.currentDamage := GDVars.currentDamage *
      (Word(Types.PCharRecord(attacker)^.classLevels[C_Class.THIEF] +
            Types.PCharRecord(attacker)^.classLevels2[C_Class.THIEF] *
            ShortInt(ClassCal.EarlierClassActive(attacker)) - 1) div 4 + 2);
  GDVars.elementMask := 0;
end;

{ Prints the attack message and, on a hit, inflicts the damage. Nonzero damage stops the defender casting this round and
  loses a spell it is casting, ending its actions. A defender that goes down is reported as going down, dying or killed,
  loses its hit-point-0 effects, runs its condition-13 effects and, if still out of play and not exploded, goes to
  CbtMap.CreatureDowned.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(manner 1 from behind, 2 a backstab, 3 slays a helpless target; anything else is a plain attack.)
  @param(damage Hit points inflicted on a hit.)
  @param(shownDamage The damage figure printed.)
  @param(isHit True for a hit, False for a miss.) }
procedure ProcessAttackResult(attacker, defender: Pointer; manner, damage, shownDamage: Byte; isHit: Boolean);
var
  row: Byte;
  message: String[80];
  { Unused in this version; see the other implementations of this routine. }
  isDone: Boolean;
begin
  case manner of
    2: message := '-Backstabs-';
    3: message := 'slays helpless';
  else
    message := 'Attacks';
  end;
  CharHlp.PrintCreatureMessage(attacker, message, 10, False);
  row := 12;
  CharHlp.DisplayCreatureName(defender, 23, row, False);
  Inc(row);
  if manner = 1 then
    message := '(from behind) '
  else
    message := '';
  if isHit then begin
    if manner = 3 then
      message := 'with one cruel blow'
    else begin
      message := message + 'Hitting for ' + CharHlp.Uint8Str(shownDamage);
      if shownDamage = 1 then
        message := message + ' point '
      else
        message := message + ' points ';
      message := message + 'of damage';
    end;
    CharHlp.InflictDamage(defender, damage);
  end else
    message := message + 'and Misses';
  if Types.PCharRecord(defender)^.status <> C_Status.GONE then
    TextRend.displayMessageWindow(23, row, 38, row + 3, LightGreen, Black, True, message);
  row := GDVars.curRow + 1;
  if damage > 0 then begin
    Types.PCharRecord(defender)^.combatAddr^.castOk := 0;
    if Types.PCharRecord(defender)^.combatAddr^.spellCast > 0 then begin
      TextRend.pauseOnly;
      CharHlp.PrintCreatureMessage(defender, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(defender, Types.PCharRecord(defender)^.combatAddr^.spellCast);
      isDone := CharHlp.EndActions(defender);
    end else
      TextRend.pauseOnly;
  end else
    TextRend.pauseOnly;
  if Types.PCharRecord(defender)^.inPlay = 0 then begin
    CharHlp.PrintCreatureMessage(defender, 'goes down', row, False);
    Inc(row, 2);
    if Types.PCharRecord(defender)^.status = C_Status.DYING then
      TextRend.displayString(23, row, LightGreen, Black, 'and is Dying');
    if Types.PCharRecord(defender)^.status in [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE] then
      CharHlp.PrintCreatureMessage(defender, 'is killed', row, False);
    Inc(row, 2);
    FxEngine.RemoveEffectsHp0(defender);
    FxEngine.TriggerEffectsWithCondition(C_Cond.HIT_POINTS_ZERO, defender);
    if (Types.PCharRecord(defender)^.inPlay = 0) and
        (Types.PCharRecord(defender)^.status <> C_Status.EXPLODED) then
      CbtMap.CreatureDowned(defender)
    else
      TextRend.pauseOnly;
  end;
  CharHlp.ClearMessageWindow;
end;

{ Lets guarding enemies strike a creature that moved next to them: each adjacent enemy that is guarding and not helpless
  spends its guard on one free attack, while the mover stays up.
  @param(creature The creature that moved.) }
procedure GuardersAttack(creature: Pointer);
var
  count: Byte;
  index: Byte;
  guarder: Pointer;
  done: Boolean;
begin
  count := CharHlp.CountTargets(creature, 1);
  for index := 1 to count do
    if Types.PCharRecord(creature)^.inPlay <> 0 then begin
      guarder := GDVars.creatureArr[GDVars.targetIdx[index]];
      if (Types.PCharRecord(guarder)^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(guarder)) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(creature)),
                          CbtMap.CombatCellY(Types.PCharRecord(creature)), 2, 8);
        Types.PCharRecord(guarder)^.combatAddr^.guarding := 0;
        CbtActs.NoteAttackDirection(guarder, creature);
        CbtActs.MakeAttack(guarder, creature, 0, nil, done);
      end;
    end;
end;

procedure CombatMoveCreature(creature: Pointer; direction: Byte);
var
  moveCost: Byte;
  slot: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  destTerrain: Byte;
begin
  slot := CbtMap.CombatSlot(Types.PCharRecord(creature));
  x := GDVars.arenaLoc[slot].x;
  y := GDVars.arenaLoc[slot].y;
  nx := x + GDConsts.dirDeltaX[direction];
  ny := y + GDConsts.dirDeltaY[direction];
  if Odd(direction) then
    moveCost := GDConsts.terrainInfo[GDVars.arena^.cells[ny, nx]].movementCost * 3
  else
    moveCost := GDConsts.terrainInfo[GDVars.arena^.cells[ny, nx]].movementCost * 2;
  if moveCost > Types.PCharRecord(creature)^.combatAddr^.movement then
    Types.PCharRecord(creature)^.combatAddr^.movement := 0
  else
    Dec(Types.PCharRecord(creature)^.combatAddr^.movement, moveCost);
  moveCost := 1;
  if Types.PCharRecord(creature)^.quickfight <> 0 then begin
    moveCost := 3;
    if not CbtMap.ViewCoordsValid(nx - GDVars.arena^.originX, ny - GDVars.arena^.originY) then
      if GDVars.gfxEnabled <> 0 then
        CbtMap.ScrollView(x, y, 2, 8);
  end;
  if GDVars.gfxEnabled <> 0 then
    CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.arenaLoc[slot].x := nx;
  GDVars.arenaLoc[slot].y := ny;
  CbtMap.BuildArenaArrays;
  if GDVars.gfxEnabled <> 0 then
    CbtMap.ScrollView(nx, ny, moveCost, 8);
  Types.PCharRecord(creature)^.combatAddr^.flankCount := 0;
  Types.PCharRecord(creature)^.combatAddr^.flankSpread := 0;
  SoundDrv.SoundCommand(GDConsts.soundIds[6]);
  CbtActs.GuardersAttack(creature);
  if (Types.PCharRecord(creature)^.inPlay = 0) or CharHlp.IsHelpless(creature) then
    Types.PCharRecord(creature)^.combatAddr^.movement := 0;
end;

procedure AttacksOfOpportunity(creature: Pointer; direction: Byte);
var
  candidates: array[1..12] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
  stillAdjacent: Boolean;
  attacked: Boolean;
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  candidateCount: Byte;
  countAfter: Byte;
  scanPos: Byte;
  index: Byte;
  phasePos: Byte;
  phase: Byte;
  facingScan: Byte;
  attacker: Pointer;
  savedTarget: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  leavingFoe: Boolean;
begin
  leavingFoe := False;
  FillChar(candidates, SizeOf(candidates), 0);
  slot := CbtMap.CombatSlot(Types.PCharRecord(creature));
  candidateCount := CharHlp.CountTargets(creature, 1);
  if candidateCount = 0 then
    Exit;
  index := 1;
  for scanPos := 1 to candidateCount do
    if not CharHlp.IsHelpless(GDVars.creatureArr[GDVars.targetIdx[scanPos]]) then
      if Types.PCharRecord(GDVars.creatureArr[GDVars.targetIdx[scanPos]])^.combatAddr^.turned = 0 then begin
        candidates[index] := GDVars.targetIdx[scanPos];
        Inc(index);
      end;
  candidateCount := index - 1;
  Inc(GDVars.arenaLoc[slot].x, GDConsts.dirDeltaX[direction]);
  Inc(GDVars.arenaLoc[slot].y, GDConsts.dirDeltaY[direction]);
  countAfter := CharHlp.CountTargets(creature, 1);
  Dec(GDVars.arenaLoc[slot].x, GDConsts.dirDeltaX[direction]);
  Dec(GDVars.arenaLoc[slot].y, GDConsts.dirDeltaY[direction]);
  for index := 1 to candidateCount do begin
    stillAdjacent := False;
    for scanPos := 1 to countAfter do
      if GDVars.targetIdx[scanPos] = candidates[index] then
        stillAdjacent := True;
    if stillAdjacent then
      candidates[index] := 0;
  end;
  if Types.PCharRecord(creature)^.hostile = C_Side.PLAYER then
    for index := 1 to candidateCount do
      if candidates[index] > 0 then
        if Types.PCharRecord(creature)^.inPlay <> 0 then
          leavingFoe := True;
  for index := 1 to candidateCount do
    if candidates[index] > 0 then
      if Types.PCharRecord(creature)^.inPlay <> 0 then begin
        GDVars.panelDirty := 1;
        GDVars.gfxEnabled := 1;
        attacked := False;
        attacker := GDVars.creatureArr[candidates[index]];
        if CbtActs.CanTarget(attacker, creature) then
          if (not CharHlp.HasRangedWeapon(attacker)) or CharHlp.HasThrowableWeapon(attacker) then
            for facingScan := Types.PCharRecord(attacker)^.combatAddr^.facing + 6
                to Types.PCharRecord(attacker)^.combatAddr^.facing + 10 do
              if not attacked then
                if (Types.PCharRecord(attacker)^.combatAddr^.initiative > 0)
                   or (Types.PCharRecord(attacker)^.combatAddr^.flankCount = 0)
                   or
                     Pathing.IsDirToward(CbtMap.CombatCellX(Types.PCharRecord(attacker)),
                                         CbtMap.CombatCellY(Types.PCharRecord(attacker)),
                                         CbtMap.CombatCellX(Types.PCharRecord(creature)),
                                         CbtMap.CombatCellY(Types.PCharRecord(creature)), facingScan mod 8) then begin
                  phase := 1;
                  if Types.PCharRecord(attacker)^.attacks = 0 then
                    phase := 2;
                  for phasePos := 1 to 2 do
                    if Types.PCharRecord(attacker)^.curAtt[phasePos] > 0 then
                      phase := phasePos;
                  if Types.PCharRecord(attacker)^.curAtt[phase] = 0 then
                    Types.PCharRecord(attacker)^.curAtt[phase] := 1;
                  Types.PCharRecord(attacker)^.combatAddr^.attackPhase := phase;
                  savedTarget := Types.PCharRecord(attacker)^.combatAddr^.target;
                  CbtActs.MakeAttack(attacker, creature, 1, nil, GDVars.combatExtendedKey);
                  attacked := True;
                  Types.PCharRecord(attacker)^.combatAddr^.target := savedTarget;
                  if Types.PCharRecord(creature)^.inPlay <> 0 then begin
                    GDVars.panelDirty := 1;
                    CharHlp.CombatPrintCreatureInfo(creature);
                  end;
                end;
      end;
end;

function AttemptFlee(creature: Pointer): Boolean;
var
  hasEscaped: Boolean;
  enemyMove: Byte;
  creatureMove: Byte;
begin
  hasEscaped := False;
  if CharHlp.CountTargets(creature, 255) = 0 then
    hasEscaped := True
  else begin
    creatureMove := CbtActs.CalcCreatureMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < creatureMove then
      hasEscaped := True
    else if enemyMove = creatureMove then
      if FxEngine.RollDice(1, 2) = 1 then
        hasEscaped := True;
  end;
  if hasEscaped then
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.RUNNING, 'Got Away')
  else
    CharHlp.PrintBottomLine('Escape is blocked');
  AttemptFlee := CharHlp.EndActions(creature);
end;

procedure RecalcAttacksLeft(creature: Pointer);
var
  attacks: Byte;
  previous: Byte;
  ammoLimit: Byte;
  rate: Byte;
  ranged: Boolean;
  weapon: Types.PItemRec;
begin
  ranged := False;
  previous := Types.PCharRecord(creature)^.curAtt[1];
  Types.PCharRecord(creature)^.curAtt[1] := Types.PCharRecord(creature)^.attacks;
  if CharHlp.HasRangedWeapon(creature) and CharHlp.FindDamagingRangedWeapon(creature, weapon) then begin
    ranged := True;
    rate := GDVars.baseItems[Types.PCharRecord(creature)^.equipped[0]^.itemType].rateOfFire;
    if rate < 2 then
      rate := 2;
    GDVars.moveAttackMultiplier := rate;
  end else
    GDVars.moveAttackMultiplier := Types.PCharRecord(creature)^.curAtt[1];
  GDVars.movementFlags[0] := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, creature);
  attacks := CbtActs.AttacksFromRate(GDVars.moveAttackMultiplier);
  if ranged then
    if weapon <> nil then begin
      ammoLimit := 1;
      if weapon <> nil then
        if weapon^.quantity > ammoLimit then
          ammoLimit := weapon^.quantity;
      if ammoLimit < attacks then
        if weapon^.quantity > 0 then
          attacks := ammoLimit;
    end;
  if (Types.PCharRecord(creature)^.combatAddr^.madeAttack = 0) or (attacks < previous) then
    Types.PCharRecord(creature)^.curAtt[1] := attacks
  else
    Types.PCharRecord(creature)^.curAtt[1] := previous;
end;

{ Converts half-attacks to attacks: adds 1 on odd rounds, then halves.
  @param(rate The rate in half-attacks.)
  @returns(The whole attacks for this round.) }
function AttacksFromRate(rate: Byte): Byte;
var
  adjusted: Byte;
begin
  adjusted := rate;
  if Odd(GDVars.roundNumber) then
    Inc(adjusted);
  AttacksFromRate := adjusted div 2;
end;

function SweepAttack(att, def: Pointer): Boolean;
var
  adjacentCount: Byte;
  sweepTargets: Byte;
  targetPos: Byte;
  defenderPos: Byte;
  target: Pointer;
begin
  SweepAttack := False;
  if Types.PCharRecord(att)^.curAtt[1] >= Types.PCharRecord(att)^.combatAddr^.sweepBudget then
    Exit;
  if Types.PCharRecord(def)^.levelHighest <> 0 then
    Exit;
  if CharHlp.CalcDistance(att, def) <> 1 then
    Exit;
  adjacentCount := CharHlp.CountTargets(att, 1);
  sweepTargets := 0;
  for targetPos := 1 to adjacentCount do begin
    target := GDVars.creatureArr[GDVars.targetIdx[targetPos]];
    if target = def then
      defenderPos := targetPos;
    if Types.PCharRecord(target)^.levelHighest = 0 then
      Inc(sweepTargets);
  end;
  if sweepTargets <= Types.PCharRecord(att)^.curAtt[1] then
    Exit;
  if sweepTargets > Types.PCharRecord(att)^.combatAddr^.sweepBudget then
    sweepTargets := Types.PCharRecord(att)^.combatAddr^.sweepBudget;
  CharHlp.PrintCreatureMessage(att, 'sweeps', 10, True);
  target := GDVars.creatureArr[GDVars.targetIdx[1]];
  if target <> def then begin
    GDVars.targetIdx[defenderPos] := GDVars.targetIdx[1];
    GDVars.targetIdx[1] := CbtMap.CombatSlot(Types.PCharRecord(def));
  end;
  for targetPos := 1 to adjacentCount do
    if sweepTargets > 0 then
      if Types.PCharRecord(GDVars.creatureArr[GDVars.targetIdx[targetPos]])^.levelHighest = 0 then begin
        target := GDVars.creatureArr[GDVars.targetIdx[targetPos]];
        CbtActs.NoteAttackDirection(att, target);
        Types.PCharRecord(att)^.curAtt[1] := 1;
        CbtActs.MakeAttack(att, target, 0, nil, GDVars.combatExtendedKey);
        Dec(sweepTargets);
      end;
  SweepAttack := True;
end;

function CanTarget(attacker, target: Pointer): Boolean;
var
  savedTarget: Pointer;
begin
  CanTarget := False;
  if target = nil then
    Exit;
  if attacker = target then begin
    CanTarget := True;
    Exit;
  end;
  GDVars.movementFlags[1] := 0;
  FxEngine.TriggerEffectsWithCondition(C_Cond.TARGET_VETO, target);
  if GDVars.movementFlags[1] = 0 then begin
    savedTarget := Types.PCharRecord(attacker)^.combatAddr^.target;
    Types.PCharRecord(attacker)^.combatAddr^.target := target;
    FxEngine.TriggerEffectsWithCondition(C_Cond.ATTACKER_VETO, attacker);
    Types.PCharRecord(attacker)^.combatAddr^.target := savedTarget;
  end;
  CanTarget := GDVars.movementFlags[1] = 0;
end;

procedure CombatTurnUndead(creature: Pointer);
var
  roll: Byte;
  affectedLeft: Byte;
  minimumLeft: Byte;
  needed: ShortInt;
  turnedAny: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  stop: Boolean;
  target: Pointer;
  tableColumn: ShortInt;
  levelCap: Byte;
begin
  CharHlp.PrintCreatureMessage(creature, 'turns undead...', 10, False);
  MenuCore.ClearBottomLine;
  TextRend.pauseOnly;
  turnedAny := False;
  stop := False;
  Inc(Types.PCharRecord(creature)^.combatAddr^.turnUses);
  levelCap := 13;
  minimumLeft := 6;
  affectedLeft := FxEngine.RollDice(1, 12);
  roll := FxEngine.RollDice(1, 20);
  tableColumn := Types.PCharRecord(creature)^.classLevels[C_Class.CLERIC]
       + Types.PCharRecord(creature)^.classLevels2[C_Class.CLERIC] * ShortInt(ClassCal.EarlierClassActive(creature));
  if Types.PCharRecord(creature)^.deity = 2 then
    tableColumn := tableColumn + 2;
  while CbtActs.FindTurnUndeadTarget(creature, target, levelCap) and (affectedLeft > 0) do begin
    needed := GDConsts.turnUndeadTable[Types.PCharRecord(target)^.levelUndead, tableColumn];
    if roll >= Abs(needed) then begin
      turnedAny := True;
      CbtMap.DisplayMapViewCentered(target, 3, False);
      GDVars.panelDirty := 1;
      CharHlp.CombatPrintCreatureInfo(target);
      if needed > 0 then
        FxEngine.PutOutOfPlayWithStatus(target, C_Status.RUNNING, 'is turned')
      else begin
        CharHlp.PrintCreatureMessage(target, 'Is destroyed', 10, False);
        CbtMap.CreatureDowned(target);
        Types.PCharRecord(target)^.status := C_Status.GONE;
        Types.PCharRecord(target)^.inPlay := 0;
      end;
      if minimumLeft > 0 then
        Dec(minimumLeft);
      Dec(affectedLeft);
      if affectedLeft = 0 then
        if minimumLeft > 0 then
          if needed < 0 then
            Inc(affectedLeft);
      CharHlp.ClearMessageWindow;
    end else
      Dec(levelCap);
  end;
  if not turnedAny then
    CharHlp.PrintBottomLine('Nothing Happens...');
  CharHlp.CountTeams;
  GDVars.combatExtendedKey := CharHlp.EndActions(creature);
  CharHlp.ClearMessageWindow;
end;

function FindTurnUndeadTarget(creature: Pointer; var target; var levelCap): Boolean;
var
  count: Byte;
  index: Byte;
  bestLevel: ShortInt;
  candidate: Pointer;
begin
  bestLevel := 0;
  Pointer(target) := nil;
  count := CharHlp.CountTargets(creature, 255);
  FindTurnUndeadTarget := False;
  for index := 1 to count do begin
    candidate := GDVars.creatureArr[GDVars.targetIdx[index]];
    if Types.PCharRecord(candidate)^.combatAddr^.turned = 0 then
      if Types.PCharRecord(candidate)^.levelUndead > 0 then
        if Types.PCharRecord(candidate)^.levelUndead > bestLevel then
          if Types.PCharRecord(candidate)^.levelUndead <= ShortInt(levelCap) then begin
            bestLevel := Types.PCharRecord(candidate)^.levelUndead;
            Pointer(target) := candidate;
            FindTurnUndeadTarget := True;
          end;
  end;
  ShortInt(levelCap) := bestLevel;
end;

{ Resolves att's remaining attacks on def. A helpless defender is slain with one blow (its hit points + 5) and the
  attacks are spent. Otherwise att uses its weapon's large-target dice against a large defender, and the defense is the
  rear AC less 4 on a backstab, the rear AC from behind (fromBehind, or def attacked more than once with att at its back
  and a flank spread above 4), else the front AC, plus range penalties. The attacks are rolled from the current attack
  phase down to 1 until def drops, a hit with damage on a defender still in play running att's condition-2 or
  condition-3 effects; a miss is reported when no attack hits, and the sweep budget is spent. Note: an attacker that
  goes down during its attacks loses the rest of that phase's attacks but still makes the next phase's.
  @param(att The creature attacking.)
  @param(def The creature attacked.)
  @param(fromBehind True to attack as from behind.)
  @param(done Set True when att has no attacks left or is out of play; its actions then end.)
  @param(weapon Unused.) }
procedure RollAttacks(att, def: Pointer; fromBehind: Boolean; var done: Boolean; weapon: Pointer);
var
  base: Types.TBaseItem;
  anyHit: Boolean;
  defDowned: Boolean;
  behind: Boolean;
  defense: Byte;
  phase: Byte;
  startPhase: Byte;
  atkType: Byte;
  behindIdx: ShortInt;
begin
  behind := fromBehind;
  done := False;
  GDVars.hitsMade[1] := 0;
  GDVars.hitsMade[2] := 0;
  GDVars.attacksMade[1] := 0;
  GDVars.attacksMade[2] := 0;
  anyHit := False;
  defDowned := False;
  GDVars.currentDamage := 0;
  Types.PCharRecord(att)^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    SoundDrv.SoundCommand(GDConsts.soundIds[3]);
    while Types.PCharRecord(att)^.curAtt[Types.PCharRecord(att)^.combatAddr^.attackPhase] = 0 do
      Dec(Types.PCharRecord(att)^.combatAddr^.attackPhase);
    Inc(GDVars.attacksMade[Types.PCharRecord(att)^.combatAddr^.attackPhase]);
    CbtActs.ProcessAttackResult(att, def, 3, Types.PCharRecord(def)^.hpCur + 5, 1, True);
    FxEngine.RemoveInvisibility(att);
    for phase := 1 to 2 do
      Types.PCharRecord(att)^.curAtt[phase] := 0;
    anyHit := True;
    done := True;
  end else begin
    if (Types.PCharRecord(att)^.equipped[0] <> nil) and
        ((Types.PCharRecord(def)^.iconDimensions > $80) or
         (Types.PCharRecord(def)^.iconDimensions and $07 > 1)) then begin
      base := GDVars.baseItems[Types.PCharRecord(att)^.equipped[0]^.itemType];
      Types.PCharRecord(att)^.curRolls[1] := base.dmgLgRolls;
      Types.PCharRecord(att)^.curDice[1] := base.dmgLgDice;
      Types.PCharRecord(att)^.curMod[1] := Types.PCharRecord(att)^.curMod[1] - base.dmgSmMod
          + base.dmgLgMod;
    end;
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_ARMOR_CLASS, def);
    behindIdx := 0;
    if CbtActs.IsBackstab(att, def) then
      defense := Types.PCharRecord(def)^.acCur[1] - 4
    else begin
      if Types.PCharRecord(def)^.combatAddr^.flankCount > 1 then
        if (CharHlp.DirTowardTarget(att, def) = Types.PCharRecord(def)^.combatAddr^.facing)
           and (Types.PCharRecord(def)^.combatAddr^.flankSpread > 4) then
          behind := True;
      if behind then
        behindIdx := 1;
      defense := Types.PCharRecord(def)^.acCur[behindIdx];
    end;
    CbtActs.ApplyRangePenalty(att, def, defense);
    atkType := 0;
    if behind then
      atkType := 1;
    if CbtActs.IsBackstab(att, def) then
      atkType := 2;
    startPhase := Types.PCharRecord(att)^.combatAddr^.attackPhase;
    for phase := startPhase downto 1 do
      while (Types.PCharRecord(att)^.curAtt[phase] > 0) and (defDowned = False) do begin
        Dec(Types.PCharRecord(att)^.curAtt[phase]);
        Types.PCharRecord(att)^.combatAddr^.attackPhase := phase;
        Inc(GDVars.attacksMade[phase]);
        if FxEngine.AttackRoll(att, def, defense) or CharHlp.IsHelpless(def) then begin
          Inc(GDVars.hitsMade[phase]);
          SoundDrv.SoundCommand(GDConsts.soundIds[3]);
          anyHit := True;
          CbtActs.CalcWeaponDamage(att, def, phase);
          if Types.PCharRecord(def)^.inPlay <> 0 then
            CbtActs.ProcessAttackResult(att, def, atkType, GDVars.currentDamage, GDVars.currentDamage, True);
          if (Types.PCharRecord(def)^.inPlay <> 0) and (GDVars.currentDamage > 0) then
            FxEngine.TriggerEffectsWithCondition(phase + 1, att);
          if Types.PCharRecord(def)^.inPlay = 0 then
            defDowned := True;
          if Types.PCharRecord(att)^.inPlay = 0 then begin
            startPhase := 0;
            Types.PCharRecord(att)^.curAtt[phase] := 0;
          end;
        end;
        FxEngine.ProcessExplodingCreatures;
      end;
    if not anyHit then begin
      SoundDrv.SoundCommand(GDConsts.soundIds[5]);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    done := True;
    for phase := 1 to 2 do
      if Types.PCharRecord(att)^.curAtt[phase] > 0 then
        done := False;
    Types.PCharRecord(att)^.combatAddr^.sweepBudget := 0;
  end;
  if Types.PCharRecord(att)^.inPlay = 0 then
    done := True;
  if done then
    done := CharHlp.EndActions(att);
end;

procedure NoteAttackDirection(attacker, defender: Pointer);
var
  angle: Byte;
  attackDirection: Byte;
begin
  Inc(Types.PCharRecord(defender)^.combatAddr^.flankCount);
  attackDirection := CharHlp.DirTowardTarget(defender, attacker);
  angle := (attackDirection - Types.PCharRecord(defender)^.combatAddr^.facing + 8) mod 8;
  if angle > 4 then
    angle := 8 - angle;
  Types.PCharRecord(defender)^.combatAddr^.flankSpread := (Types.PCharRecord(defender)^.combatAddr^.flankSpread +
    angle) mod 8;
end;

procedure MakeAttack(attacker, defender: Pointer; fromBehind: Byte; weapon: Pointer; var done: Boolean);
var
  thrownCopy: Pointer;
  walker: Pointer;
  savedCharacter: Pointer;
  direction: Byte;
begin
  GDVars.gfxEnabled := 1;
  GDVars.panelDirty := 1;
  GDVars.roundLimit := GDVars.roundNumber + 15;
  if (Types.PCharRecord(defender)^.combatAddr^.flankCount < 2) and (fromBehind = 0) then begin
    direction := CharHlp.DirTowardTarget(defender, attacker);
    Types.PCharRecord(defender)^.combatAddr^.facing := (direction + 4) mod 8;
  end else if CbtMap.CombatIconVisible(defender, 0) then begin
    direction := Types.PCharRecord(defender)^.combatAddr^.facing;
    if fromBehind = 0 then
      Types.PCharRecord(defender)^.combatAddr^.facing := (direction + 4) mod 8;
  end;
  if CbtMap.CombatIconVisible(defender, 0) then
    CbtMap.SetCreatureFacing(defender, direction, 0, 0);
  direction := CharHlp.DirTowardTarget(attacker, defender);
  CharHlp.CombatPrintCreatureInfo(attacker);
  CbtMap.SetCreatureFacing(attacker, direction, 1, 0);
  Types.PCharRecord(attacker)^.combatAddr^.target := defender;
  Delay(100);
  if weapon <> nil then
    CbtActs.AnimateMissile(attacker, defender, weapon);
  if (Types.PCharRecord(attacker)^.equipped[0]^.itemType = 28)
     or (Types.PCharRecord(attacker)^.equipped[0]^.itemType = 29) then
    CbtActs.AnimateMissile(attacker, defender, Types.PCharRecord(attacker)^.equipped[0]);
  done := True;
  if (Types.PCharRecord(attacker)^.curAtt[1] > 0) or (Types.PCharRecord(attacker)^.curAtt[2] > 0) then begin
    savedCharacter := GDVars.curChar;
    GDVars.curChar := attacker;
    CbtActs.RollAttacks(attacker, defender, Boolean(fromBehind), done, weapon);
    if weapon <> nil then
      if not CharHlp.HasReadiedHoopak(attacker) then begin
        if Types.PItemRec(weapon)^.quantity > 0 then
          Dec(Types.PItemRec(weapon)^.quantity, GDVars.attacksMade[1]);
        if Types.PItemRec(weapon)^.quantity = 0 then
          if CharHlp.HasThrowableWeapon(attacker) and (Types.PItemRec(weapon)^.effect <> 23) then begin
            GetMem(thrownCopy, SizeOf(Types.TItemRec));
            Move(weapon^, thrownCopy^, SizeOf(Types.TItemRec));
            walker := GDVars.treasureItems;
            if walker = nil then begin
              GDVars.treasureItems := thrownCopy;
              Types.PItemRec(thrownCopy)^.next := nil;
            end else begin
              while (Types.PItemRec(walker)^.next <> nil)
                    and (walker <> GDVars.prevTreasure) do
                walker := Types.PItemRec(walker)^.next;
              Types.PItemRec(thrownCopy)^.next := Types.PItemRec(walker)^.next;
              Types.PItemRec(walker)^.next := thrownCopy;
            end;
            Types.PItemRec(thrownCopy)^.equipped := 0;
            CharHlp.RemoveItem(attacker, weapon);
            GDVars.prevTreasure := thrownCopy;
          end else
            CharHlp.RemoveItem(attacker, weapon);
      end;
    CharHlp.RecalcStats(attacker);
    GDVars.curChar := savedCharacter;
  end;
  if done then
    done := CharHlp.EndActions(attacker);
  if CbtMap.CombatIconVisible(attacker, 0) then begin
    CbtMap.SetCreatureFacing(attacker, Types.PCharRecord(attacker)^.combatAddr^.facing, 1, 1);
    CbtMap.SetCreatureFacing(attacker, Types.PCharRecord(attacker)^.combatAddr^.facing, 0, 0);
  end;
end;

{ Raises a defense value for range. With a ranged weapon the band is (range - 1) div 3 steps; a defender more than one
  band away adds 2 and more than two bands away 3 more. A weapon of range 3 or less has a band of 0, so any distance
  adds both. Melee adds nothing.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(armorClass The defense value, raised in place.) }
procedure ApplyRangePenalty(attacker, defender: Pointer; var armorClass: Byte);
var
  band: ShortInt;
  distance: ShortInt;
begin
  distance := CharHlp.CalcDistance(attacker, defender);
  if CharHlp.HasRangedWeapon(attacker) then
    band := (GDVars.baseItems[Types.PCharRecord(attacker)^.equipped[0]^.itemType].range - 1) div 3
  else
    band := distance;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 2;
  end;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 3;
  end;
end;

procedure PrimeCbtActs;
begin
  ViewChar.PrimeViewChar;
  Pathing.PrimePathing;
  CbtMap.PrimeCbtMap;
  MapTiles.PrimeMapTiles;
  CharHlp.PrimeCharHlp;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  MenuCore.PrimeMenuCore;
  Debug.PrimeDebug;
  ClassCal.PrimeClassCal;
end;

function FindCureTarget(cr: Pointer; var target): Boolean;
var
  bestTarget: Pointer;
  nx: ShortInt;
  ny: ShortInt;
  downedIndex: Byte;
  lowestHp: Byte;
  direction: Byte;
  downedPos: Byte;
  creatureIndex: Byte;
  terrainIndex: Byte;
begin
  bestTarget := nil;
  downedIndex := 0;
  lowestHp := 255;
  for direction := C_Dir.NORTH to C_Dir.CENTER do begin
    nx := CbtMap.CombatCellX(Types.PCharRecord(cr)) + GDConsts.dirDeltaX[direction];
    ny := CbtMap.CombatCellY(Types.PCharRecord(cr)) + GDConsts.dirDeltaY[direction];
    CbtMap.GetArenaContents(nx, ny, creatureIndex, terrainIndex);
    if creatureIndex > 0 then begin
      Pointer(target) := GDVars.creatureArr[creatureIndex];
      if Types.PCharRecord(Pointer(target))^.hostile = Types.PCharRecord(cr)^.hostile then
        if Types.PCharRecord(Pointer(target))^.hpCur < Types.PCharRecord(Pointer(target))^.hpMax then
          if (Types.PCharRecord(Pointer(target))^.hpCur < lowestHp) or
              ((Pointer(target) = cr) and
               (Types.PCharRecord(Pointer(target))^.hpCur < Types.PCharRecord(Pointer(target))^.hpMax div 2)) then begin
            bestTarget := Pointer(target);
            lowestHp := Types.PCharRecord(Pointer(target))^.hpCur;
          end;
    end else if terrainIndex = C_Terr.TERRAIN_CORPSE then
      for downedPos := 1 to GDVars.downedCount do
        if GDVars.downedCreatures[downedPos].creature <> nil then
          if not (Types.PCharRecord(GDVars.downedCreatures[downedPos].creature)^.status in
                  [C_Status.DEAD_STATUS, C_Status.STONED, C_Status.GONE]) then
            if GDVars.downedCreatures[downedPos].x = nx then
              if GDVars.downedCreatures[downedPos].y = ny then
                downedIndex := downedPos;
  end;
  if (lowestHp < 8) or (downedIndex = 0) then
    Pointer(target) := bestTarget
  else
    Pointer(target) := GDVars.downedCreatures[downedIndex].creature;
  if Pointer(target) <> nil then
    FindCureTarget := True
  else
    FindCureTarget := False;
end;

{ Picks one spell target. For the player the aim goes through CombatAimMenu (one spell may aim at cells but not at
  creatures), which also locks the target. Otherwise a spell that does not target enemies goes to the caster, or for
  Cure Light Wounds to FindCureTarget's pick; an offensive spell takes one AcquireTarget pick, rejected when the target
  is helpless and the spell's effect is a helpless status. On success the target's cell becomes the spell's target cell;
  on failure the target is cleared.
  @param(spellId The spell being aimed.)
  @param(aiControlled 0 for the player's aim menu; nonzero for computer-controlled targeting.)
  @param(groundOk Passed to CombatAimMenu: nonzero lets the player pick a bare cell.)
  @param(target Receives the target: a creature pointer followed by its arena cell.)
  @returns(True if a target was found.) }
function SelectSpellTarget(spellId: Byte; aiControlled: Boolean; groundOk: Byte; var target: TAimTarget): Boolean;
var
  found: Boolean;
  acceptable: Boolean;
  candidate: Pointer;
  i: Byte;
  tries: Byte;
  creatureOk: Byte;
begin
  found := False;
  if not aiControlled then begin
    creatureOk := Byte(spellId <> 83);
    CbtActs.CombatAimMenu(GDVars.curChar, ShortInt(Magic.CalcSpellRange(spellId)), 0, groundOk, creatureOk, found,
                          target);
    GDVars.curChar^.combatAddr^.target := target.cr;
  end else begin
    if GDConsts.spellTbl[spellId].offensive = 0 then begin
      target.cr := GDVars.curChar;
      if (spellId <> C_Spell.CURE_LIGHT_WOUNDS)
         or CbtActs.FindCureTarget(GDVars.curChar, target.cr) then begin
        target.x := CbtMap.CombatCellX(Types.PCharRecord(target.cr));
        target.y := CbtMap.CombatCellY(Types.PCharRecord(target.cr));
        found := True;
      end;
    end else begin
      tries := 1;
      while (tries > 0) and (found = False) do begin
        acceptable := True;
        if CbtActs.AcquireTarget(GDVars.curChar, ShortInt(Magic.CalcSpellRange(spellId)), 0, 1) then begin
          candidate := GDVars.curChar^.combatAddr^.target;
          if CharHlp.IsHelpless(candidate) then
            for i := 1 to 4 do
              if GDConsts.spellTbl[spellId].effect = GDConsts.helplessFx[i] then
                acceptable := False;
          if acceptable then begin
            target.cr := GDVars.curChar^.combatAddr^.target;
            target.x := CbtMap.CombatCellX(Types.PCharRecord(target.cr));
            target.y := CbtMap.CombatCellY(Types.PCharRecord(target.cr));
            found := True;
          end;
        end;
        Dec(tries);
      end;
    end;
  end;
  if found then begin
    SelectSpellTarget := True;
    GDVars.targetX := target.x;
    GDVars.targetY := target.y;
  end else begin
    SelectSpellTarget := False;
    FillChar(target, SizeOf(target), 0);
  end;
end;

procedure SelectCombatTargets(spell: Byte; ai: Boolean; var cast: Boolean);
var
  remaining: Byte;
  selectionCount: Byte;
  existingPos: Byte;
  limit: Byte;
  total: Byte;
  selectedTarget: TAimTarget;
  dup: Boolean;
  stop: Boolean;

begin
  cast := True;
  GDVars.spellTargetCount := 0;
  GDVars.multiTarget := 0;
  GDVars.targetX := CbtMap.CombatCellX(GDVars.curChar);
  GDVars.targetY := CbtMap.CombatCellY(GDVars.curChar);
  case GDConsts.spellTbl[spell].area and $F of
    0:
      begin
        GDVars.spellTargets[1] := GDVars.curChar;
        GDVars.spellTargetCount := 1;
      end;
    5:
      begin
        total := 0;
        selectionCount := 0;
        if spell = 79 then
          limit := CharHlp.GetCasterLevel(79)
        else
          limit := FxEngine.RollDice(2, 4);
        stop := False;
        repeat
          if CbtActs.SelectSpellTarget(spell, ai, 0, selectedTarget) then begin
            dup := False;
            for existingPos := 1 to selectionCount do
              if GDVars.spellTargets[existingPos] = selectedTarget.cr then
                dup := True;
            if dup = False then begin
              Inc(selectionCount);
              GDVars.spellTargets[selectionCount] := selectedTarget.cr;
              GDVars.targetX := CbtMap.CombatCellX(Types.PCharRecord(selectedTarget.cr));
              GDVars.targetY := CbtMap.CombatCellY(Types.PCharRecord(selectedTarget.cr));
              Inc(GDVars.spellTargetCount);
              if spell <> 79 then
                case GDVars.spellTargets[selectionCount]^.levelHighest of
                  0, 1: Inc(total);
                  2: Inc(total, 2);
                  3: Inc(total, 4);
                else
                  Inc(total, 8);
                end else
                case GDVars.spellTargets[selectionCount]^.iconDimensions of
                  1: Inc(total);
                  2, 3: Inc(total, 2);
                  4: Inc(total, 4);
                end;
              if (selectionCount > 1) and (total > limit) then
                stop := True;
            end else if ai then
              Dec(limit)
            else
              CharHlp.PrintBottomLine('Already been targeted');
            CbtMap.RedrawArenaCell(CbtMap.CombatCellX(Types.PCharRecord(selectedTarget.cr)),
                                   CbtMap.CombatCellY(Types.PCharRecord(selectedTarget.cr)));
          end else
            stop := True;
        until stop or (limit = 0);
      end;
    15:
      begin
        if CbtActs.SelectSpellTarget(spell, ai, 0, selectedTarget) then begin
          if GDVars.curChar^.combatAddr^.target <> nil then begin
            GDVars.spellTargets[1] := GDVars.curChar^.combatAddr^.target;
            GDVars.spellTargetCount := 1;
          end else begin
            Pathing.BuildTargetList(GDVars.targetX, GDVars.targetY, (GDConsts.spellTbl[spell].area and $F) shr 4, 255,
                                    1, GDVars.arena);
            for selectionCount := 1 to GDVars.targetCount do
              GDVars.spellTargets[selectionCount] :=
                GDVars.creatureArr[GDVars.targetList[selectionCount].creatureIndex];
            GDVars.spellTargetCount := GDVars.targetCount;
            GDVars.multiTarget := 1;
          end;
        end else
          cast := False;
      end;
    8..14:
      begin
        if CbtActs.SelectSpellTarget(spell, ai, 1, selectedTarget) then begin
          Pathing.BuildTargetList(GDVars.targetX, GDVars.targetY, GDConsts.spellTbl[spell].area and $07, 255, 1,
                                  GDVars.arena);
          for selectionCount := 1 to GDVars.targetCount do
            GDVars.spellTargets[selectionCount] := GDVars.creatureArr[GDVars.targetList[selectionCount].creatureIndex];
          GDVars.spellTargetCount := GDVars.targetCount;
          GDVars.multiTarget := 1;
        end else
          cast := False;
      end;
  else begin
      remaining := (GDConsts.spellTbl[spell].area and $03) + 1;
      selectionCount := 0;
      while remaining > 0 do begin
        if CbtActs.SelectSpellTarget(spell, ai, 0, selectedTarget) then begin
          dup := False;
          for existingPos := 1 to selectionCount do
            if GDVars.spellTargets[existingPos] = selectedTarget.cr then
              dup := True;
          if (spell = 23) or (spell = 49) then
            if selectedTarget.cr = GDVars.curChar then
              dup := True;
          if dup = False then begin
            Inc(selectionCount);
            GDVars.spellTargets[selectionCount] := selectedTarget.cr;
            Dec(remaining);
            GDVars.targetX := CbtMap.CombatCellX(Types.PCharRecord(selectedTarget.cr));
            GDVars.targetY := CbtMap.CombatCellY(Types.PCharRecord(selectedTarget.cr));
          end else if ai = False then begin
            if selectedTarget.cr = GDVars.curChar then
              CharHlp.PrintBottomLine('Cannot target yourself')
            else
              CharHlp.PrintBottomLine('Already been targeted');
          end else
            Dec(remaining);
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(Types.PCharRecord(selectedTarget.cr)),
                                 CbtMap.CombatCellY(Types.PCharRecord(selectedTarget.cr)));
        end else
          remaining := 0;
      end;
      GDVars.spellTargetCount := selectionCount;
      if selectionCount = 0 then
        cast := False;
      GDVars.targetX := CbtMap.CombatCellX(GDVars.spellTargets[selectionCount]);
      GDVars.targetY := CbtMap.CombatCellY(GDVars.spellTargets[selectionCount]);
    end;
  end;
end;

procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);
var
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  castTime: Byte;
  orderPos: Byte;
  spellSelectionIndex: Integer;
  notEmpty: Boolean;
  caster: Pointer;
  orderEntry: Pointer;
begin
  caster := GDVars.curChar;
  notEmpty := True;
  spellSelectionIndex := -1;
  cast := False;
  spellId := spell;
  if spellId = 0 then
    spellId := ViewChar.SpellMenu(0, 1, spellSelectionIndex, notEmpty);
  if spellId > 0 then
    if GDConsts.spellTbl[spellId].combatOk = 0 then begin
      CharHlp.PrintBottomLine('Camp Only Spell');
      spellId := 0;
    end;
  if ai = 0 then begin
    CharHlp.DisplayCombatInterface;
    GDVars.gfxEnabled := 1;
    GDVars.panelDirty := 1;
    CbtMap.DisplayMapViewCentered(Types.PCharRecord(caster), 3, True);
    CharHlp.CombatPrintCreatureInfo(caster);
  end;
  if spellId > 0 then begin
    castTime := GDConsts.spellTbl[spellId].castTime div 3;
    if castTime = 0 then begin
      Magic.CastSpell(spellId, ai, 1, cast);
      cast := CharHlp.EndActions(caster);
    end else begin
      cast := True;
      CharHlp.PrintCreatureMessage(caster, 'Begins Casting', 10, True);
      Types.PCharRecord(caster)^.combatAddr^.spellCast := spellId;
      if Types.PCharRecord(caster)^.combatAddr^.initiative > castTime then
        Dec(Types.PCharRecord(caster)^.combatAddr^.initiative, castTime)
      else
        Types.PCharRecord(caster)^.combatAddr^.initiative := 1;
      orderPos := GDVars.roundIndex;
      orderEntry := GDVars.combatOrder[orderPos + 1];
      while (orderEntry <> nil) and
          ((Types.PCharRecord(orderEntry)^.combatAddr^.initiative >
            Types.PCharRecord(caster)^.combatAddr^.initiative) or
          ((Types.PCharRecord(orderEntry)^.combatAddr^.initiative =
            Types.PCharRecord(caster)^.combatAddr^.initiative) and (FxEngine.RollDice(1, 2) = 1))) do begin
        GDVars.combatOrder[orderPos] := orderEntry;
        Inc(orderPos);
        orderEntry := GDVars.combatOrder[orderPos + 1];
      end;
      GDVars.combatOrder[orderPos] := caster;
      Dec(GDVars.roundIndex);
      cast := True;
    end;
  end;
end;

{ Checks for a backstab: the attacker must be a thief (or have thief levels through ClassCal.EarlierClassActive), with
  no weapon, a hoopak, or one of item types 3, 4 and 17..19; the defender must be small, have been attacked more than
  once this round, stand next to the attacker, and face away from it.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @returns(True for a backstab.) }
function IsBackstab(attacker, defender: Pointer): Boolean;
var
  weapon: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  armor: Pointer;
  weaponType: Byte;
  canBackstab: Boolean;
begin
  canBackstab := False;
  weapon := Types.PCharRecord(attacker)^.equipped[0];
  if weapon <> nil then
    weaponType := Types.PItemRec(weapon)^.itemType;
  armor := Types.PCharRecord(attacker)^.equipped[2];
  if (Types.PCharRecord(attacker)^.classLevels[C_Class.THIEF] > 0) or
      ((Types.PCharRecord(attacker)^.classLevels2[C_Class.THIEF] > 0) and ClassCal.EarlierClassActive(attacker)) then
    if (weapon = nil) or (weaponType = C_Item.HOOPAK) or (weaponType = 3) or (weaponType = 4)
       or ((weaponType > 16) and (weaponType < 20)) then
      canBackstab := True;
  if canBackstab and (Types.PCharRecord(defender)^.combatAddr^.flankCount > 1)
     and (CharHlp.CalcDistance(attacker, defender) < 2)
     and ((Types.PCharRecord(defender)^.iconDimensions and $7F) <= 1)
     and (CharHlp.DirTowardTarget(attacker, defender) = Types.PCharRecord(defender)^.combatAddr^.facing) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

{ Flies a missile from attacker to defender. It plays the launch sound, then builds the icon for weapon's item type with
  a sound for its kind: item types 5, 7, 12 and 30 get an icon drawn for the direction of flight, and the others a fixed
  icon, some in four frames at a slower pace.
  @param(attacker The creature shooting.)
  @param(defender The creature shot at.)
  @param(weapon The missile or thrown item.) }
procedure AnimateMissile(attacker, defender, weapon: Pointer);
var
  missileCellBase: Byte;
  frames: Byte;
  direction: Byte;
  pace: Byte;
  { Unused in this version; see the other implementations of this routine. }
  imageSize: Word;
begin
  SoundDrv.SoundCommand(GDConsts.soundIds[8]);
  direction := CharHlp.DirTowardTarget(attacker, defender);
  frames := 1;
  pace := 10;
  missileCellBase := 13;
  imageSize := GDVars.viewPicture^.imgSize;
  case Types.PItemRec(weapon)^.itemType of
    5, 7, 12, 30:
      begin
        if Odd(direction) then begin
          if (direction = C_Dir.SOUTHEAST) or (direction = C_Dir.SOUTHWEST) then
            CharHlp.CopyIconFacing(missileCellBase + 1, 1, 0, direction = C_Dir.SOUTHWEST)
          else
            CharHlp.CopyIconFacing(missileCellBase + 1, 0, 0, direction = C_Dir.NORTHWEST);
        end else
          CharHlp.CopyIconFacing(missileCellBase + direction mod 4, direction div 4, 0, False);
        SoundDrv.SoundCommand(GDConsts.soundIds[8]);
      end;
    2, 3, 6:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 3);
        frames := 4;
        pace := 50;
        SoundDrv.SoundCommand(GDConsts.soundIds[5]);
      end;
    C_Item.HOLY_WATER_VIAL, 55:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 4);
        frames := 4;
        pace := 50;
        SoundDrv.SoundCommand(GDConsts.soundIds[2]);
      end;
    28, 29, C_Item.HOOPAK:
      begin
        Inc(missileCellBase);
        CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, False);
        CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, False);
        frames := 2;
        pace := 10;
        SoundDrv.SoundCommand(GDConsts.soundIds[2]);
      end;
  else begin
      CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, False);
      CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, False);
      frames := 2;
      pace := 20;
      SoundDrv.SoundCommand(GDConsts.soundIds[5]);
    end;
  end;
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker),
                                  CbtMap.CombatCellX(defender), CbtMap.CombatCellY(defender), frames, pace);
end;

procedure UpdateHostileHpPercent;
var
  maximumTotal: Word;
  hitPointTotal: Word;
  combatant: Pointer;
begin
  maximumTotal := 0;
  hitPointTotal := 0;
  combatant := GDVars.partyHead;
  while combatant <> nil do begin
    if Types.PCharRecord(combatant)^.hostile = C_Side.ENEMY then begin
      if Types.PCharRecord(combatant)^.inPlay <> 0 then
        hitPointTotal := hitPointTotal + Types.PCharRecord(combatant)^.hpCur;
      maximumTotal := maximumTotal + Types.PCharRecord(combatant)^.hpMax;
    end;
    combatant := Types.PCharRecord(combatant)^.next;
  end;
  if maximumTotal > 0 then
    GDVars.hostileHpPct := hitPointTotal * 20 div maximumTotal * 5;
end;

function HighestEnemyMovement(creature: Pointer): Byte;
var
  highest: Byte;
  movement: Byte;
  combatant: Pointer;
begin
  highest := 0;
  combatant := GDVars.partyHead;
  while combatant <> nil do begin
    if (CharHlp.EnemyTeam(creature) = Types.PCharRecord(combatant)^.hostile) and
        (Types.PCharRecord(combatant)^.inPlay <> 0) then begin
      movement := CbtActs.CalcCreatureMovement(combatant) div 2;
      if movement > highest then
        highest := movement;
    end;
    combatant := Types.PCharRecord(combatant)^.next;
  end;
  HighestEnemyMovement := highest;
end;

function CheckAttackAlly(attacker, defender: Pointer): Boolean;
var
  combatant: Pointer;
begin
  if (CharHlp.EnemyTeam(defender) = Types.PCharRecord(attacker)^.hostile) or
      (Types.PCharRecord(attacker)^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenu('Attack Ally: ', LightMagenta, LightGreen, White) <> 'Y' then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GDVars.allyAttacked := 1;
    GDVars.zone1^.attackedAlly := 1;
    combatant := GDVars.partyHead;
    while combatant <> nil do begin
      if (Types.PCharRecord(combatant)^.status = C_Status.OKAY) and (Types.PCharRecord(combatant)^.npc <> $B3)
         and (Types.PCharRecord(combatant)^.npc > $7F) then begin
        Types.PCharRecord(combatant)^.hostile := C_Side.ENEMY;
        Types.PCharRecord(combatant)^.combatAddr^.target := nil;
      end;
      combatant := Types.PCharRecord(combatant)^.next;
    end;
    CharHlp.CountTeams;
  end;
end;

{ Shows one aim-menu round on the target: centers the view on it, shows the range in weapon mode, and offers Target when
  the target cell is in range and allowed (spell mode: always; weapon mode: when the target is another creature and the
  attacker either has no ranged weapon, or has ammunition for it and no adjacent enemy or a throwable weapon), then
  Next, Prev, Manual, Center and Exit.
  @param(cur The creature aiming.)
  @param(target The creature under the aim.)
  @param(range The reach, in whole steps.)
  @param(weaponMode Nonzero for a weapon attack, 0 for a spell.)
  @param(groundMode Unused.)
  @param(attackGate Unused.)
  @param(ground Nonzero to allow Target at all.)
  @param(tx Arena column of the target cell.)
  @param(ty Arena row of the target cell.)
  @returns(The key chosen.) }
function AimTargetMenu(cur, target: Pointer; range, weaponMode: Byte; groundMode, attackGate: Byte; ground: Byte; tx,
                       ty: ShortInt): Char;
var
  menu: String[40];
  ext: Boolean;
  weapon: Types.PItemRec;
  dist: Word;
  { Unused in this version; see the other implementations of this routine. }
  losFound: Boolean;
  savedDistMode: Byte;
begin
  menu := '';
  dist := 255;
  savedDistMode := GDVars.arena^.ignoreTerrain;
  GDVars.arena^.ignoreTerrain := 1;
  losFound := Pathing.WalkLine(CbtMap.CombatCellX(Types.PCharRecord(cur)), CbtMap.CombatCellY(Types.PCharRecord(cur)),
                               tx, ty, dist, GDVars.arena);
  GDVars.arena^.ignoreTerrain := savedDistMode;
  dist := dist shr 1;
  if weaponMode <> 0 then
    TextRend.displayString(0, 23, LightGreen, Black, 'Range = ' + CharHlp.Uint16Str(dist) + '  ');
  if dist <= range then
    if ground <> 0 then begin
      if weaponMode = 0 then
        menu := 'Target '
      else if cur <> target then begin
        if not CharHlp.HasRangedWeapon(cur) then
          menu := 'Target '
        else if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
          if (CharHlp.CountTargets(cur, 1) = 0) or CharHlp.HasThrowableWeapon(cur) then
            menu := 'Target ';
      end;
    end;
  menu := 'Next Prev Manual ' + menu + 'Center Exit';
  if target <> nil then begin
    CbtMap.DisplayMapViewCentered(Types.PCharRecord(target), 3, True);
    GDVars.panelDirty := 1;
    CharHlp.CombatPrintCreatureInfo(target);
  end;
  AimTargetMenu := MenuCore.MenuHorizontal('Aim:', menu, LightMagenta, LightGreen, White, True, False, ext);
end;

{ Confirms an aim selection: weapon mode 1 makes a weapon attack, anything else selects a spell target. A weapon attack
  on an ally needs CheckAttackAlly's consent, otherwise the selection is cleared and the done flag is False. The attack
  tries a sweep first; a throwable ranged weapon used at distance 1 strikes as melee.
  @param(cur The creature aiming.)
  @param(target The creature chosen.)
  @param(weaponMode 1 for a weapon attack.)
  @param(done False when the attack was declined; otherwise True or the attack's result.)
  @param(sel Receives the target and its cell; cleared when declined.) }
procedure ConfirmAttackTarget(cur, target: Pointer; weaponMode: Byte; var done: Boolean; var sel: TAimTarget);
var
  { Unused in this version; see the other implementations of this routine. }
  targetDir: Byte;
  weapon: Types.PItemRec;
begin
  weapon := nil;
  done := True;
  if weaponMode = 1 then
    if not CbtActs.CheckAttackAlly(cur, target) then
      done := False;
  if done then begin
    sel.cr := target;
    sel.x := CbtMap.CombatCellX(Types.PCharRecord(target));
    sel.y := CbtMap.CombatCellY(Types.PCharRecord(target));
    GDVars.arena^.cursorOn := False;
    CbtMap.ScrollView(GDVars.arena^.originX + 3, GDVars.arena^.originY + 3, 3, 8);
    if weaponMode = 1 then begin
      if CbtActs.SweepAttack(cur, target) then
        done := CharHlp.EndActions(cur)
      else begin
        CbtActs.NoteAttackDirection(cur, target);
        if CharHlp.HasRangedWeapon(cur) then
          if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
            if CharHlp.HasThrowableWeapon(cur) then
              if CharHlp.CalcDistance(cur, target) = 1 then
                weapon := nil;
        CbtActs.MakeAttack(cur, target, 0, weapon, done);
      end;
    end;
  end else
    FillChar(sel, SizeOf(sel), 0);
end;

{ Runs the free cursor: the arrow keys move a cell cursor (kept inside the arena) from a starting cell, Target or Enter
  takes the cell under it and Space recenters; Exit and Escape leave with nothing chosen. A cell is valid when a line
  reaches it within range and its terrain is passable; a bare cell also needs the ground flag, and a creature needs the
  creature flag and CanTarget's consent. In weapon mode a creature is also invalid when it is the attacker itself or a
  downed body, or when the attacker's ranged weapon has no ammunition or, unless throwable, an enemy stands adjacent.
  @param(cur The creature aiming.)
  @param(underCursor Overwritten: holds the creature under the cursor while it moves.)
  @param(range The reach, in whole steps.)
  @param(weaponMode Nonzero for a weapon attack, 0 for a spell target.)
  @param(ground Nonzero lets a bare cell be chosen.)
  @param(attackGate Nonzero lets a creature be chosen.)
  @param(valid Set True when the cell under the cursor may be chosen.)
  @param(confirmed Set True when a cell was taken, False on Exit or Escape.)
  @param(sel Receives the creature (nil for a bare cell) and cell taken; on Exit the starting cell.)
  @param(cx Arena column the cursor starts on.)
  @param(cy Arena row the cursor starts on.) }
procedure ManualAimCursor(cur, underCursor: Pointer; range, weaponMode, ground, attackGate: Byte; var valid: Boolean;
                          var confirmed: Boolean; var sel: TAimTarget; cx, cy: Byte);
var
  menu: String[40];
  ch: Char;
  weapon: Types.PItemRec;
  direction: Byte;
  j: Byte;
  wx: ShortInt;
  wy: ShortInt;
  creatureIndex: Byte;
  terrainIndex: Byte;
  savedCx: Byte;
  savedCy: Byte;
  dist: Word;
begin
  GDVars.mapCursorActive := 1;
  savedCx := cx;
  savedCy := cy;
  GDVars.cursorX := cx;
  GDVars.cursorY := cy;
  FillChar(sel, SizeOf(sel), 0);
  GDVars.arena^.cursorOn := True;
  GDVars.arena^.cursorSize := 1;
  ch := ' ';
  direction := C_Dir.CENTER;
  GDVars.scratchFlag := 0;
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    CbtMap.ScrollView(GDVars.cursorX, GDVars.cursorY, 2, direction);
    Inc(GDVars.cursorX, GDConsts.dirDeltaX[direction]);
    Inc(GDVars.cursorY, GDConsts.dirDeltaY[direction]);
    if GDVars.cursorX < 0 then GDVars.cursorX := 0;
    if GDVars.cursorY < 0 then GDVars.cursorY := 0;
    if GDVars.cursorX > 49 then GDVars.cursorX := 49;
    if GDVars.cursorY > 24 then GDVars.cursorY := 24;
    CbtMap.GetArenaContents(GDVars.cursorX, GDVars.cursorY, creatureIndex, terrainIndex);
    GameIo.FlushKeys;
    valid := False;
    dist := 255;
    wx := GDVars.cursorX;
    wy := GDVars.cursorY;
    if Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), wx, wy, dist, GDVars.arena) then begin
      valid := True;
      if weaponMode <> 0 then
        TextRend.displayString(0, 23, LightGreen, Black, 'Range = ' + CharHlp.Uint16Str(dist div 2) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    dist := dist div 2;
    underCursor := nil;
    if valid then begin
      if creatureIndex > 0 then
        underCursor := GDVars.creatureArr[creatureIndex]
      else if terrainIndex = C_Terr.TERRAIN_CORPSE then
        for j := 1 to GDVars.downedCount do
          if GDVars.downedCreatures[j].x = GDVars.cursorX then
            if GDVars.downedCreatures[j].y = GDVars.cursorY then
              underCursor := GDVars.downedCreatures[j].creature;
    end;
    if underCursor <> nil then begin
      GDVars.panelDirty := 1;
      CharHlp.CombatPrintCreatureInfo(underCursor);
    end else
      Border.ClearBox(23, 1, 38, 21);
    if (range < dist) or (GDConsts.terrainInfo[terrainIndex].movementCost = C_Terr.TERRAIN_IMPASSABLE) then
      valid := False;
    if underCursor <> nil then begin
      if (not CbtActs.CanTarget(cur, underCursor)) or (attackGate = 0) then
        valid := False;
      if weaponMode = 1 then
        if (cur = underCursor) or ((creatureIndex = 0) and (terrainIndex = C_Terr.TERRAIN_CORPSE)) then
          valid := False
        else if CharHlp.HasRangedWeapon(cur) then
          if (not CharHlp.FindDamagingRangedWeapon(cur, weapon)) or
              ((CharHlp.CountTargets(cur, 1) > 0) and (not CharHlp.HasThrowableWeapon(cur))) then
            valid := False;
    end else if ground = 0 then
      valid := False;
    if valid then
      menu := 'Target'
    else
      menu := 'Exit';
    ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', menu, LightMagenta, LightGreen, White, True, False,
                         GDVars.combatExtendedKey);
    case ch of
      C_Keys.ENTER, 'T':
        begin
          confirmed := True;
          sel.x := GDVars.cursorX;
          sel.y := GDVars.cursorY;
          if underCursor <> nil then
            sel.cr := underCursor
          else
            sel.cr := nil;
          GDVars.arena^.cursorOn := False;
          CbtMap.RedrawArenaCell(GDVars.cursorX, GDVars.cursorY);
          GDVars.scratchFlag := 0;
        end;
      C_Keys.UP: direction := C_Dir.NORTH;
      C_Keys.PAGE_UP: direction := C_Dir.NORTHEAST;
      C_Keys.RIGHT: direction := C_Dir.EAST;
      C_Keys.PAGE_DOWN: direction := C_Dir.SOUTHEAST;
      C_Keys.DOWN: direction := C_Dir.SOUTH;
      C_Keys.END_KEY: direction := C_Dir.SOUTHWEST;
      C_Keys.LEFT: direction := C_Dir.WEST;
      C_Keys.HOME: direction := C_Dir.NORTHWEST;
      ' ':
        begin
          CbtMap.ScrollView(GDVars.cursorX, GDVars.cursorY, 0, 8);
          direction := C_Dir.CENTER;
        end;
      'E', C_Keys.NONE:
        begin
          confirmed := False;
          CbtMap.RedrawArenaCell(GDVars.cursorX, GDVars.cursorY);
          FillChar(sel, SizeOf(sel), 0);
          sel.x := savedCx;
          sel.y := savedCy;
          CbtMap.ScrollView(savedCx, savedCy, 0, 8);
          GDVars.arena^.cursorOn := False;
          CbtMap.RedrawArenaCell(savedCx, savedCy);
          GDVars.scratchFlag := 0;
        end;
    else
      direction := C_Dir.CENTER;
    end;
  end;
  GDVars.mapCursorActive := 0;
end;

procedure CombatAimMenu(cr: Pointer; range: ShortInt; weaponMode, groundMode, attackGate: Byte; var done: Boolean;
                        var target);
var
  targets: array[1..72] of Types.TTargetRec;
  effRange: Byte;
  tgtCount: Byte;
  curIdx: Byte;
  targetStep: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  menuStep: ShortInt;
  curX: ShortInt;
  curY: ShortInt;
  nextX: ShortInt;
  nextY: ShortInt;
  currentTarget: Pointer;
  ch: Char;
  ground: Boolean;
  confirmedFlag: Boolean;
  px: ShortInt;
  py: ShortInt;
  oldPx: ShortInt;
  oldPy: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  aimDelay: Word;

  { Copies the targets within radius 127 of center that it may attack into the local target list. }
  procedure BuildAimTargets(center: Pointer);
  var
    targetPos: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(center)),
                            CbtMap.CombatCellY(Types.PCharRecord(center)), 127, 255,
                            CbtMap.GetIconSize(Types.PCharRecord(center)), GDVars.arena);
    tgtCount := 0;
    for targetPos := 1 to GDVars.targetCount do
      if CbtActs.CanTarget(center, GDVars.creatureArr[GDVars.targetList[targetPos].creatureIndex]) then begin
        Inc(tgtCount);
        targets[tgtCount] := GDVars.targetList[targetPos];
      end;
  end;

  { Steps the target index by step, wrapping; animate flies a marker to the new target, else the old cell is redrawn. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Pointer;
  var
    { Unused in this version; see the other implementations of this routine. }
    previousTarget: Pointer;
  begin
    if animate then begin
      curX := GDVars.arenaLoc[targets[curIdx].creatureIndex].x;
      curY := GDVars.arenaLoc[targets[curIdx].creatureIndex].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    AdvanceAimTarget := GDVars.creatureArr[targets[curIdx].creatureIndex];
    nextX := GDVars.arenaLoc[targets[curIdx].creatureIndex].x;
    nextY := GDVars.arenaLoc[targets[curIdx].creatureIndex].y;
    if animate then begin
      CharHlp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

begin

  CharHlp.CopyIconFacing(25, 0, 0, False);

  FillChar(target, SizeOf(TAimTarget), 0);
  done := False;
  effRange := range;
  if effRange = 255 then
    if Types.PCharRecord(cr)^.equipped[0] <> nil then
      effRange := GDVars.baseItems[Types.PCharRecord(cr)^.equipped[0]^.itemType].range - 1
    else
      effRange := 1;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  BuildAimTargets(cr);
  curIdx := 1;
  targetStep := 0;
  currentTarget := AdvanceAimTarget(targetStep, True);
  ch := ' ';
  px := CbtMap.CombatCellX(Types.PCharRecord(currentTarget));
  py := CbtMap.CombatCellY(Types.PCharRecord(currentTarget));
  oldPx := px;
  oldPy := py;
  ground := True;
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    ch := CbtActs.AimTargetMenu(cr, currentTarget, effRange, weaponMode, groundMode, attackGate, Byte(ground), px, py);
    if GDVars.extendedKeyFlag = False then
      case ch of
        'N':
          begin
            targetStep := 1;
            ground := True;
            currentTarget := AdvanceAimTarget(1, True);
          end;
        'P':
          begin
            targetStep := -1;
            ground := True;
            currentTarget := AdvanceAimTarget(-1, True);
          end;
        'M':
          begin
            CbtActs.ManualAimCursor(cr, currentTarget, effRange, weaponMode, groundMode, attackGate, ground,
                                    confirmedFlag, TAimTarget(target), px, py);
            currentTarget := TAimTarget(target).cr;
            px := TAimTarget(target).x;
            py := TAimTarget(target).y;
            if ground and confirmedFlag then begin
              ch := 'T';
              GDVars.horizontalChoice := 4;
              if currentTarget <> nil then
                TAimTarget(target).cr := currentTarget
              else
                TAimTarget(target).cr := nil;
              done := True;
              if weaponMode = 1 then
                CbtActs.ConfirmAttackTarget(cr, currentTarget, weaponMode, done, TAimTarget(target));
              if done = False then begin
                GDVars.arena^.cursorOn := False;
                CbtMap.ScrollView(px, py, 0, 8);
              end;
            end else
              GDVars.horizontalChoice := 3;
          end;
        'T':
          begin
            TAimTarget(target).x := px;
            TAimTarget(target).y := py;
            if currentTarget <> nil then
              TAimTarget(target).cr := currentTarget
            else
              TAimTarget(target).cr := nil;
            done := True;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cr, currentTarget, weaponMode, done, TAimTarget(target));
            if done = False then begin
              GDVars.arena^.cursorOn := False;
              CbtMap.ScrollView(px, py, 0, 8);
            end;
          end;
        'C':
          begin
            GDVars.arena^.cursorOn := True;
            GDVars.arena^.cursorSize := 1;
            CbtMap.ScrollView(px, py, 0, 8);
            GDVars.arena^.cursorOn := False;
          end;
        'E':
          begin
            GDVars.arena^.cursorOn := False;
            CbtMap.ScrollView(px, py, 0, 8);
          end;
        C_Keys.NONE:
          begin
            GDVars.arena^.cursorOn := False;
            CbtMap.RedrawArenaCell(px, py);
            CbtMap.ScrollView(oldPx, oldPy, 0, 8);
          end;
      end;
    if (ch = 'N') or (ch = 'P') or (ch = 'T') then
    begin
      px := CbtMap.CombatCellX(Types.PCharRecord(currentTarget));
      py := CbtMap.CombatCellY(Types.PCharRecord(currentTarget));
    end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

function AcquireTarget(cr: Pointer; range, relaxed, forceNew: Byte): Boolean;
var
  availableCount: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  target: Pointer;
  effectData: Pointer;
begin
  effectData := nil;
  pass := False;
  found := False;
  second := False;
  target := Types.PCharRecord(cr)^.combatAddr^.target;
  if (forceNew <> 0) or
      ((target <> nil) and
       ((Types.PCharRecord(target)^.hostile = Types.PCharRecord(cr)^.hostile) or
        (Types.PCharRecord(target)^.inPlay = 0) or (not CbtActs.CanTarget(cr, target)))) then
    Types.PCharRecord(cr)^.combatAddr^.target := nil;
  if Types.PCharRecord(cr)^.combatAddr^.target <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GDVars.arena^.ignoreTerrain := 1;
    tries := 20;
    availableCount := CharHlp.CountTargets(cr, range);
    while (tries > 0) and (not found) and (availableCount > 0) do begin
      Dec(tries);
      if CharHlp.HasEffect(cr, 91, effectData) and (GDVars.creatureArr[GDVars.targetIdx[1]] = GDVars.yellTarget)
         and (tries = 19) then
        pick := 1
      else
        pick := FxEngine.RollDice(1, availableCount);
      if GDVars.targetIdx[pick] > 0 then begin
        target := GDVars.creatureArr[GDVars.targetIdx[pick]];
        if ((relaxed <> 0) and (GDVars.arena^.ignoreTerrain <> 0)) or CbtActs.CanTarget(cr, target) then begin
          found := True;
          Types.PCharRecord(cr)^.combatAddr^.target := target;
        end else begin
          GDVars.targetIdx[pick] := 0;
          for pick := 1 to availableCount do
            if GDVars.targetIdx[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            availableCount := 0;
        end;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GDVars.arena^.ignoreTerrain := 0;
  AcquireTarget := found;
end;

function VictoryCheat: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  combatant: Pointer;
begin
  VictoryCheat := False;
  if ParamStr(2) <> GDVars.cmpStr then
    Exit;
  VictoryCheat := True;
  CharHlp.PrintBottomLine('The Gods intervene!');
  combatant := GDVars.partyHead;
  while combatant <> nil do begin
    if Types.PCharRecord(combatant)^.hostile = C_Side.ENEMY then begin
      Types.PCharRecord(combatant)^.inPlay := 0;
      Types.PCharRecord(combatant)^.status := C_Status.DEAD_STATUS;
      GDVars.arenaLoc[CbtMap.CombatSlot(Types.PCharRecord(combatant))].size := 0;
    end;
    done := CharHlp.EndActions(combatant);
    combatant := Types.PCharRecord(combatant)^.next;
  end;
  CbtMap.ScrollView(GDVars.arena^.originX + 3, GDVars.arena^.originY + 3, 255, 8);
end;

begin
end.
