{ Combat AI: controls one automated combatant turn and selects its equipment. }
{$O+,F+}
unit CombatAi;

interface

uses Types, TextRend, GameIo, CbtActs, ViewChar, Magic, FxEngine, CharHlp, ClassCal, MenuCore, View3D, Pathing, CbtMap,
  Debug, Crt, GDConsts, GDVars, C_Class, C_Side, C_Npc, C_Spell, C_Terr, C_Stat, C_Status,
  C_Effect, C_Item, C_Init;

{ Runs one AI-controlled turn: checks the keyboard (space returns the party to manual control), rerolls the approach
  pattern, checks morale, then tries in order an item's spell, a spell readied earlier, turning undead and a new spell,
  and otherwise re-equips and runs the move-and-attack loop. The pattern is rerolled when unset, after a sweep pattern
  or on 1 turn in 4: 1 in 8 picks a sweep pattern (5 or 6), else 1 to 4.
  @param(character The creature.) }
procedure CombatAiControl(character: Types.PCharRecord);

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCombatAi;

implementation

const
  MAX_POLICY_ITERATIONS = 20;
  ALIGNED_WEAPON_SPECIAL = $84;

function TurnUndeadAi(character: Types.PCharRecord): Boolean; forward;

function DecideCastSpell(character: Types.PCharRecord; spellId, minimumPriority: Byte): Boolean; forward;

function SelectItemToUse(character: Types.PCharRecord): Boolean; forward;

function SelectSpellToCast(character: Types.PCharRecord): Boolean; forward;

function AiCanStep(character: Types.PCharRecord; attempt, baseDirection: Byte;
                   var leavesMap: Boolean): Boolean; forward;

procedure AiMoveStep(character: Types.PCharRecord); forward;

function AiMoveAttack(character: Types.PCharRecord): Boolean; forward;

function FinishRound(character: Types.PCharRecord): Boolean; forward;

function CheckKeystroke(character: Types.PCharRecord): Boolean; forward;

function CheckMorale(character: Types.PCharRecord): Boolean; forward;

function CalcWeaponPriority(character: Types.PCharRecord; item: Types.PItemRec): Byte; forward;

procedure EquipWeaponAndArmor(character: Types.PCharRecord); forward;

procedure PrimeCombatAi;
begin
  ViewChar.PrimeViewChar;
  Pathing.PrimePathing;
  CbtMap.PrimeCbtMap;
  View3D.PrimeView3D;
  MenuCore.PrimeMenuCore;
  CharHlp.PrimeCharHlp;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  CbtActs.PrimeCbtActs;
  Debug.PrimeDebug;
  ClassCal.PrimeClassCal;
end;

procedure CombatAiControl(character: Types.PCharRecord);
var
  approachPattern: Byte;
  actionComplete: Boolean;
begin
  actionComplete := CombatAi.CheckKeystroke(character);
  MenuCore.ClearBottomLine;
  CharHlp.ClearMessageWindow;
  if character^.inPlay = 0 then
    actionComplete := CharHlp.EndActions(character);
  approachPattern := character^.combatAddr^.aiStance;
  { keep the pattern 3 turns in 4; 1d8 = 8 -> a sweep pattern (5..6) }
  if (approachPattern = 0) or (approachPattern > 4) or (FxEngine.RollDice(1, 4) = 1) then begin
    approachPattern := FxEngine.RollDice(1, 8);
    if approachPattern = 8 then
      approachPattern := FxEngine.RollDice(1, 2) + 4
    else
      approachPattern := FxEngine.RollDice(1, 4);
  end;
  character^.combatAddr^.aiStance := approachPattern;
  if not actionComplete then
    actionComplete := CombatAi.CheckMorale(character);
  if (character^.combatAddr^.fleeing <> 0) and (character^.combatAddr^.turned = 0) then
    CharHlp.PrintCreatureMessage(character, 'flees in panic', 10, True);
  if actionComplete then
    Exit;
  if CombatAi.SelectItemToUse(character) then
    actionComplete := CharHlp.EndActions(character)
  else if character^.combatAddr^.spellCast > 0 then begin
    { a spell queued earlier resolves this segment }
    Magic.CastSpell(character^.combatAddr^.spellCast, 1, 1, actionComplete);
    actionComplete := CharHlp.EndActions(character);
  end else if CombatAi.TurnUndeadAi(character) then
    actionComplete := CharHlp.EndActions(character)
  else if CombatAi.SelectSpellToCast(character) then
    actionComplete := True
  else begin
    CombatAi.EquipWeaponAndArmor(character);
    actionComplete := CombatAi.CheckKeystroke(character);
    while not actionComplete do
      if CbtActs.AcquireTarget(character, 255, 1, 0) and (character^.combatAddr^.initiative > 0)
         and (character^.inPlay <> 0) then
        actionComplete := CombatAi.AiMoveAttack(character)
      else
        actionComplete := CombatAi.FinishRound(character);
  end;
end;

{ Turns undead when the creature is a cleric (a former cleric counts while its old cleric level is above its level at
  the class change) with turnings left against the undead present, and a turnable undead target exists.
  @param(character The creature.)
  @returns(True if it turned undead.) }
function TurnUndeadAi(character: Types.PCharRecord): Boolean;
var
  targetCandidate: Pointer;
  targetKind: Byte;
begin
  if (character^.combatAddr^.turnUses < GDVars.undeadCount) and
      ((character^.classLevels[C_Class.CLERIC] > 0) or
       (character^.classLevels2[C_Class.CLERIC] > character^.dualClassThreshold)) and
      CbtActs.FindTurnUndeadTarget(character, targetCandidate, targetKind) then begin
    TurnUndeadAi := True;
    CbtActs.CombatTurnUndead(character);
  end else
    TurnUndeadAi := False;
end;

{ Decides whether the AI should use a spell (from its spellbook, or an item's spell effect). Its AI priority must be at
  least `minimumPriority`. Non-offensive spells other than Cure Light Wounds always qualify, as does Cure Light Wounds
  with a cure target. Everything else needs an enemy within the spell's range and, for an area spell, no candidate
  target whose area would catch a creature off the caster's enemy team that fails a saving throw, rolled at once (-2 for
  a party caster, +8 for a hostile one); a spell whose save result is 1 never counts as catching one.
  @param(character The caster.)
  @param(spellId The spell.)
  @param(minimumPriority The lowest AI priority accepted.)
  @returns(True when the AI should cast the spell.) }
function DecideCastSpell(character: Types.PCharRecord; spellId, minimumPriority: Byte): Boolean;
var
  targetCandidate: Pointer;
  targetTotal: Byte;
  aimIndex: Byte;

  { Tells whether the spell's area around (x, y) catches a non-enemy of the current character that fails its save. }
  function AreaHitsNonEnemy(x, y: ShortInt; spellId: Byte): Boolean;
  var
    targetIndex: Byte;
    targetKind: Byte;
  begin
    AreaHitsNonEnemy := False;
    if GDVars.curChar^.hostile = C_Side.PLAYER then
      targetKind := 254
    else
      targetKind := 8;
    Pathing.BuildTargetList(x, y, GDConsts.spellTbl[spellId].aiRadius, 255, 1, GDVars.arena);
    for targetIndex := 1 to GDVars.targetCount do
      if (GDVars.creatureArr[GDVars.targetList[targetIndex].creatureIndex]^.hostile <>
          CharHlp.EnemyTeam(GDVars.curChar)) and (GDConsts.spellTbl[spellId].saveEffect <> 1) and
          (not FxEngine.RollSavingThrow(GDVars.creatureArr[GDVars.targetList[targetIndex].creatureIndex],
                                        GDConsts.spellTbl[spellId].saveType, targetKind)) then
        AreaHitsNonEnemy := True;
  end;

begin
  DecideCastSpell := False;
  if GDConsts.spellTbl[spellId].aiPriority < minimumPriority then
    Exit;
  if ((spellId <> C_Spell.CURE_LIGHT_WOUNDS) and (GDConsts.spellTbl[spellId].offensive = 0))
     or ((spellId = C_Spell.CURE_LIGHT_WOUNDS) and CbtActs.FindCureTarget(character, targetCandidate)) then
    { buff / heal: no aiming }
    DecideCastSpell := True
  else begin
    targetTotal := CharHlp.CountTargets(character, Magic.CalcSpellRange(spellId));
    if targetTotal > 0 then
      if GDConsts.spellTbl[spellId].aiRadius = 0 then
        DecideCastSpell := True
      else begin
        { refuse the spell if any candidate aim point would splash a non-enemy }
        for aimIndex := 1 to targetTotal do
          if AreaHitsNonEnemy(GDVars.arenaLoc[GDVars.targetIdx[aimIndex]].x,
                              GDVars.arenaLoc[GDVars.targetIdx[aimIndex]].y, spellId) then
            Exit;
        DecideCastSpell := True;
      end;
  end;
end;

{ Uses an equipped item's spell when the creature may use items, an enemy team remains and there is no antimagic. Over
  1d7 passes the lowest AI priority accepted falls from 7, and the first equipped item that is not readable, has a
  special below $80 and a spell DecideCastSpell accepts is used. Item effects above 56 map to the spell entries 23
  lower.
  @param(character The creature.)
  @returns(True when an item was used.) }
function SelectItemToUse(character: Types.PCharRecord): Boolean;
var
  minimumPriority: Byte;
  priorityBands: Byte;
  priorityBand: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Integer;
  { Unused in this version; see the other implementations of this routine. }
  itemSlot: Byte;
  spellEffect: Byte;
  { Unused in this version; see the other implementations of this routine. }
  baseItem: Pointer;
  item: Types.PItemRec;
  chosenItem: Types.PItemRec;
  used: Boolean;
begin
  SelectItemToUse := False;
  chosenItem := nil;
  minimumPriority := 7;
  priorityBands := FxEngine.RollDice(1, 7);
  if (character^.combatAddr^.itemUseAllowed <> 0)
     and (GDVars.teamCount[CharHlp.EnemyTeam(character)] > 0)
     and (GDVars.zone0^.castLock = 0) then
    for priorityBand := 1 to priorityBands do begin
      item := character^.itemsAddr;
      while (item <> nil) and (chosenItem = nil) do begin
        spellEffect := item^.effect;
        itemSlot := GDVars.baseItems[item^.itemType].slot;
        if (not Magic.ItemReadable(item)) and (item^.special < $80)
           and (item^.equipped <> 0) and (spellEffect > 0) then begin
          if spellEffect > 56 then
            { item effects -> spell-table entries }
            spellEffect := spellEffect - 23;
          if CombatAi.DecideCastSpell(character, spellEffect, minimumPriority) then
            chosenItem := item;
        end;
        item := item^.next;
      end;
      Dec(minimumPriority);
    end;
  if chosenItem <> nil then begin
    ViewChar.UseItem(chosenItem, used);
    SelectItemToUse := True;
  end;
end;

{ Picks a spell for an NPC, or for a party member while magic is on (Alt-M), when enemies remain. The list holds
  memorized entries 1..57 (pending ones included) when casting is allowed. Over 1d7 passes the minimum AI priority drops
  from 7, with three random picks per pass; the first spell DecideCastSpell accepts goes to CastSpellCombat. Note: entry
  0 is never considered, and pending entries keep their $80 preparation bit, which DecideCastSpell does not strip.
  @param(character The caster.)
  @returns(CastSpellCombat's done flag, or False when no spell was cast.) }
function SelectSpellToCast(character: Types.PCharRecord): Boolean;
var
  spellCandidates: array[0..57] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  castTarget: Pointer;
  minimumPriority: Byte;
  priorityBands: Byte;
  castAccepted: Boolean;
  priorityBand: Byte;
  pickAttempt: Byte;
  spellCount: Byte;
  spellIndex: Byte;
  spellId: Byte;
  chosenItem: Byte;
begin
  spellCount := 0;
  if character^.combatAddr^.castOk <> 0 then
    for spellIndex := 1 to 57 do
      if character^.memorized[spellIndex] > 0 then begin
        spellCandidates[spellCount] := character^.memorized[spellIndex];
        Inc(spellCount);
      end;
  chosenItem := 0;
  minimumPriority := 7;
  priorityBands := FxEngine.RollDice(1, 7);
  priorityBand := 1;
  if spellCount > 0 then
    if (character^.npc > $7F) or GDVars.magicEnabled then
      if GDVars.teamCount[CharHlp.EnemyTeam(character)] > 0 then
        while (priorityBand <= priorityBands) and (chosenItem = 0) do begin
          pickAttempt := 1;
          { three random picks per pass }
          while (pickAttempt < 4) and (chosenItem = 0) do begin
            spellIndex := FxEngine.RollDice(1, spellCount) - 1;
            spellId := spellCandidates[spellIndex];
            if CombatAi.DecideCastSpell(character, spellId, minimumPriority) then
              chosenItem := spellId;
            Inc(pickAttempt);
          end;
          Dec(minimumPriority);
          Inc(priorityBand);
        end;
  if chosenItem > 0 then
    CbtActs.CastSpellCombat(chosenItem, 1, castAccepted)
  else
    castAccepted := False;
  SelectSpellToCast := castAccepted;
end;

{ Checks a step in direction `baseDirection` plus the approach pattern's offset for `attempt`. Off the arena it sets
  `leavesMap` and fails; an occupied or impassable cell fails. The step costs 2 (orthogonal) or 3 (diagonal) times the
  terrain cost and must be less than the movement left. Next to the first cloud kind ProbeDirection reports (a stinking
  cloud) the creature balks unless it has effect 32, 30, 99 or 63, is turned, or makes a saving throw; next to the
  second kind a creature below level 7 balks unless it has effect 99 or is turned.
  @param(character The moving creature.)
  @param(attempt The attempt, 1..5, which picks the pattern's turn.)
  @param(baseDirection The wanted direction, 0..7.)
  @param(leavesMap Set True when the step would leave the arena, else False.)
  @returns(True when the creature can take the step.) }
function AiCanStep(character: Types.PCharRecord; attempt, baseDirection: Byte; var leavesMap: Boolean): Boolean;
var
  effectNode: Pointer;
  directionOffset: Byte;
  direction: Byte;
  occupantIndex: Byte;
  terrainIndex: Byte;
  stepCost: Byte;
  adjacentCorpse: Byte;
  adjacentWater: Byte;
  canStep: Boolean;
begin
  leavesMap := False;
  canStep := False;
  directionOffset := GDConsts.aiDirOffsetTable[character^.combatAddr^.aiStance, attempt];
  direction := (baseDirection + directionOffset) mod 8;
  CbtMap.ProbeDirection(Types.PCharRecord(character), direction, occupantIndex, terrainIndex, adjacentCorpse,
                        adjacentWater);
  if terrainIndex = 0 then
    { off the map: a flee chance }
    leavesMap := True
  else begin
    if GDConsts.terrainInfo[terrainIndex].movementCost = C_Terr.TERRAIN_IMPASSABLE then begin
      AiCanStep := False;
      Exit;
    end;
    { diagonal: the doubled metric is 3 }
    if Odd(direction) then
      stepCost := GDConsts.terrainInfo[terrainIndex].movementCost * 3
    else
      stepCost := GDConsts.terrainInfo[terrainIndex].movementCost * 2;
    { a creature blocks the cell }
    if occupantIndex = 0 then
      if stepCost < character^.combatAddr^.movement then begin
        if adjacentCorpse <> 0 then
          if (not CharHlp.HasEffect(character, C_Effect.ANIMATED, effectNode))
             and (not CharHlp.HasEffect(character, 30, effectNode))
             and (not CharHlp.HasEffect(character, 99, effectNode))
             and (not CharHlp.HasEffect(character, 63, effectNode))
             and (character^.combatAddr^.turned = 0)
             and (not FxEngine.RollSavingThrow(character, 0, 0)) then
            stepCost := character^.combatAddr^.movement + 1;
        if adjacentWater <> 0 then
          if (character^.levelHighest < 7)
             and (not CharHlp.HasEffect(character, 99, effectNode))
             and (character^.combatAddr^.turned = 0) then
            stepCost := character^.combatAddr^.movement + 1;
        if character^.combatAddr^.movement >= stepCost then
          canStep := True;
      end;
  end;
  AiCanStep := canStep;
end;

{ Takes one AI movement step: toward the locked target, or for a fleeing creature away from the party's facing (the
  party flees the other way), trying up to five directions from the approach pattern; a fleeing creature at the arena
  edge tries to flee. A magic-user without armor does not advance, and an NPC advances when it passes a morale roll
  against the hostiles' remaining hit points, while party characters and hostile creatures always may. A step back the
  way it came, or no usable direction, counts as stuck and rotates the pattern; stuck twice drops the target, three
  times stops moving. The step allows opportunity attacks and terrain effects.
  @param(character The moving creature.) }
procedure AiMoveStep(character: Types.PCharRecord);
var
  direction: Byte;
  adjustedDirection: Byte;
  attempt: Byte;
  leavesMap: Boolean;
  actionComplete: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  combat: Pointer;
begin
  TextRend.displayString(0, 24, LightGreen, Black,
                         'Move/Attack, Move Left = ' + CharHlp.Uint8Str(character^.combatAddr^.movement div 2) +
                           ' ');
  if CombatAi.CheckKeystroke(character) then
    Exit;
  if (character^.combatAddr^.movement div 2 > 0)
     and (character^.combatAddr^.initiative > 0)
     and
       ((character^.npc < C_Npc.NON_PLAYER) or
        ((character^.npc > $7F) and (GDVars.hostileHpPct <= FxEngine.RollDice(1, 100) + GDVars.effectScratch.morale)) or
        (character^.hostile = C_Side.ENEMY))
     and
       ((character^.combatAddr^.fleeing <> 0) or (character^.equipped[2] <> nil) or
        (Byte(character^.charClass) <> C_Class.MAGE)) then begin
    if character^.combatAddr^.fleeing = 0 then
      direction := CharHlp.DirTowardTarget(character, character^.combatAddr^.target)
    else begin
      character^.combatAddr^.aiStance := FxEngine.RollDice(1, 2);
      { run against the party's facing, cardinalized }
      direction := GDVars.mapState.facing - Word((GDVars.mapState.facing + 2) mod 4) div 2;
      if character^.hostile = C_Side.PLAYER then
        { allies flee the other way }
        direction := direction + 4;
      direction := direction mod 8;
    end;
    leavesMap := False;
    actionComplete := False;
    attempt := 1;
    while (attempt < 6) and (not actionComplete)
          and (not CombatAi.AiCanStep(character, attempt, direction, leavesMap)) do
      if (character^.combatAddr^.fleeing <> 0) and leavesMap then
        actionComplete := CbtActs.AttemptFlee(character)
      else
        Inc(attempt);
    if actionComplete then
    { fled off the map }
    begin
      character^.combatAddr^.movement := 0;
      character^.combatAddr^.fleeing := 0;
      actionComplete := CharHlp.EndActions(character);
    end else begin
      adjustedDirection := (direction + GDConsts.aiDirOffsetTable[character^.combatAddr^.aiStance, attempt]) mod 8;
      { nothing walkable }
      if (attempt = 6)
         { reversing }
         or (GDVars.lastMoveDir = (adjustedDirection + 4) mod 8) then begin
        Inc(GDVars.stuckCount);
        character^.combatAddr^.aiStance := character^.combatAddr^.aiStance mod 6 + 1;
        if GDVars.stuckCount > 1 then begin
          character^.combatAddr^.target := nil;
          if GDVars.stuckCount > 2 then begin
            character^.combatAddr^.movement := 0;
            actionComplete := True;
          end else if not CbtActs.AcquireTarget(character, 255, 1, 0) then
            actionComplete := CombatAi.FinishRound(character);
        end;
      end;
      if attempt < 6 then
        GDVars.lastMoveDir := adjustedDirection
      else
        actionComplete := True;
    end;
    if not actionComplete then begin
      GDVars.gfxEnabled := Ord((GDVars.inRange <> False) or
                                 CbtMap.CombatIconVisible(Types.PCharRecord(character), 0) or
                                 (character^.hostile = C_Side.PLAYER));
      CbtMap.SetCreatureFacing(Types.PCharRecord(character), adjustedDirection, 0, 0);
      CbtActs.AttacksOfOpportunity(character, character^.combatAddr^.facing);
      if character^.inPlay = 0 then
        actionComplete := CharHlp.EndActions(character)
      else begin
        if character^.combatAddr^.movement > 0 then
          CbtActs.CombatMoveCreature(character, character^.combatAddr^.facing);
        if (character^.inPlay = 0) or CharHlp.IsHelpless(character) then
          actionComplete := CharHlp.EndActions(character);
        FxEngine.ConsiderTerrainEffects(character, 1);
      end;
    end;
  end else
    actionComplete := CombatAi.FinishRound(character);
end;

{ Runs the AI's move/attack loop (the 21st pass finishes the round): fires condition-14 effects, lets a party member
  bandage a dying teammate (ending its turn), moves a fleeing creature away, then attacks the locked target if it is a
  hostile in weapon range and in sight (a locked party-side target is dropped, so hostile creatures never use theirs
  here), or a random enemy in range, or moves toward a target. A ranged weapon that cannot fire with an enemy adjacent
  makes it re-equip and stop. Attacks try a sweep first. Note: the locked target is read before it is checked for nil,
  and the pass that finishes the round for the pass limit still goes on to seek and attack a target.
  @param(character The acting creature.)
  @returns(True when the creature can no longer act.) }
function AiMoveAttack(character: Types.PCharRecord): Boolean;
var
  actionComplete: Boolean;
  mayAct: Boolean;
  weaponRange: Byte;
  pathBudget: Word;
  targetTotal: Byte;
  targetChoice: Byte;
  weapon: Types.PItemRec;
  selectedTarget: Types.PCharRecord;
  targetX: ShortInt;
  targetY: ShortInt;
  policyIterations: Byte;
begin
  GDVars.lastMoveDir := 8;
  GDVars.stuckCount := 0;
  { written once, never read }
  GDVars.stuckCountTail := 0;
  policyIterations := 0;
  mayAct := True;
  actionComplete := False;
  FxEngine.TriggerEffectsWithCondition(14, character);
  if (character^.hostile = C_Side.PLAYER) and CharHlp.BandageDying(True) then
    character^.combatAddr^.initiative := 0;
  if character^.combatAddr^.initiative = 0 then
    mayAct := False;
  while (not actionComplete) and mayAct do begin
    { burn the remaining movement while fleeing }
    if character^.combatAddr^.fleeing <> 0 then
      while (character^.combatAddr^.movement > 0)
            and (character^.combatAddr^.initiative > 0)
            and (character^.combatAddr^.initiative < C_Init.TURN_FINISHED_INITIATIVE) do
        CombatAi.AiMoveStep(character);
    if (character^.combatAddr^.initiative = 0)
       or (character^.combatAddr^.initiative = C_Init.TURN_FINISHED_INITIATIVE) then
      mayAct := False
    else
      actionComplete := False;
    if (not actionComplete) and mayAct then begin
      Inc(policyIterations);
      if policyIterations > CombatAi.MAX_POLICY_ITERATIONS then begin
        actionComplete := True;
        mayAct := CombatAi.FinishRound(character) = False;
      end;
      GDVars.inRange := False;
      weaponRange := 1;
      if character^.equipped[0] <> nil then
        weaponRange := GDVars.baseItems[character^.equipped[0]^.itemType].range - 1;
      if (weaponRange = 0) or (weaponRange = 255) then
        weaponRange := 1;
      selectedTarget := character^.combatAddr^.target;
      if (selectedTarget^.inPlay = 0) or (selectedTarget^.hostile = C_Side.PLAYER) then
        { Note: the test reads the target before checking it for nil }
        selectedTarget := nil;
      if selectedTarget <> nil then
        if CbtActs.CanTarget(character, selectedTarget) then begin
          targetX := CbtMap.CombatCellX(Types.PCharRecord(selectedTarget));
          targetY := CbtMap.CombatCellY(Types.PCharRecord(selectedTarget));
          pathBudget := weaponRange;
          GDVars.arena^.ignoreTerrain := 0;
          if Pathing.WalkLine(CbtMap.CombatCellX(Types.PCharRecord(character)),
                              CbtMap.CombatCellY(Types.PCharRecord(character)), targetX, targetY, pathBudget,
                              GDVars.arena) then
            if pathBudget div 2 <= weaponRange then
              GDVars.inRange := True;
        end;
      if not GDVars.inRange then begin
        targetTotal := CharHlp.CountTargets(character, weaponRange);
        if targetTotal = 0 then begin
          if CbtActs.AcquireTarget(character, 255, 0, 0) then
            { approach }
            CombatAi.AiMoveStep(character)
          else
            actionComplete := CombatAi.FinishRound(character);
        end else begin
          targetChoice := FxEngine.RollDice(1, targetTotal);
          selectedTarget := GDVars.creatureArr[GDVars.targetIdx[targetChoice]];
          if CharHlp.HasRangedWeapon(character) and (not CharHlp.HasThrowableWeapon(character))
             and (CharHlp.CountTargets(character, 1) > 0) then begin
            { a pure missile weapon with an enemy adjacent: re-equip }
            CombatAi.EquipWeaponAndArmor(character);
            actionComplete := True;
          end else if (CharHlp.CalcDistance(character, selectedTarget) = 1)
                  or CbtActs.CanTarget(character, selectedTarget) then
            GDVars.inRange := True;
        end;
      end;
      if GDVars.inRange then
        CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(character)),
                          CbtMap.CombatCellY(Types.PCharRecord(character)), 2,
                          CharHlp.DirTowardTarget(character, selectedTarget));
      if GDVars.inRange then begin
        if CbtActs.SweepAttack(character, selectedTarget) then
          actionComplete := CharHlp.EndActions(character)
        else begin
          CbtActs.NoteAttackDirection(character, selectedTarget);
          weapon := nil;
          if CharHlp.HasRangedWeapon(character) then begin
            GDVars.inRange := CharHlp.FindDamagingRangedWeapon(character, weapon);
            if CharHlp.HasThrowableWeapon(character) then
              if CharHlp.CalcDistance(character, selectedTarget) = 1 then
                { adjacent: melee the throwable }
                weapon := nil;
          end;
          CbtActs.MakeAttack(character, selectedTarget, 0, weapon, actionComplete);
          if actionComplete then
            mayAct := False
          else if selectedTarget^.inPlay = 0 then
            actionComplete := True;
        end;
      end;
    end;
  end;
  AiMoveAttack := mayAct = False;
end;

{ Ends the creature's round: a helpless, ranged-armed or out-of-initiative creature just ends its actions; others guard.
  @param(character The creature.)
  @returns(What ending the actions or guarding returns.) }
function FinishRound(character: Types.PCharRecord): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(character) or CharHlp.HasRangedWeapon(character)
     or (character^.combatAddr^.initiative = 0) then
    FinishRound := CharHlp.EndActions(character)
  else
    FinishRound := CharHlp.Guard(character);
end;

{ Handles a key pressed during an AI turn: Alt-M toggles quick magic, space returns each creature that is neither a
  non-player character nor animated to manual control, and Alt-X tries the victory cheat. Pending keys are discarded
  afterwards. Note: the key is tested whether or not the extended-key prefix came first, so an unprefixed 2 also toggles
  quick magic and an unprefixed hyphen also tries the cheat.
  @param(character The creature.)
  @returns(True when space put the creature itself back under manual control, which marks it to act again at once.) }
function CheckKeystroke(character: Types.PCharRecord): Boolean;
var
  partyMember: Types.PCharRecord;
  key: Char;
begin
  CheckKeystroke := False;
  if GameIo.InputPending then begin
    key := GameIo.ReadGameKey;
    if key = #0 then
      { extended key: take the scan code }
      key := GameIo.ReadGameKey;
    case key of
      { Alt-M }
      #50:
        begin
          GDVars.magicEnabled := GDVars.magicEnabled = False;
          if GDVars.magicEnabled then
            CharHlp.PrintBottomLine('Magic On')
          else
            CharHlp.PrintBottomLine('Magic Off');
        end;
      { Space: everyone back to manual }
      ' ':
        begin
          partyMember := GDVars.partyHead;
          while partyMember <> nil do begin
            if (partyMember^.npc < C_Npc.NON_PLAYER) and (partyMember^.status <> C_Status.ANIMATED) then
              partyMember^.quickfight := 0;
            partyMember := partyMember^.next;
          end;
          if character^.quickfight = 0 then begin
            character^.combatAddr^.initiative := C_Init.TURN_FINISHED_INITIATIVE;
            CheckKeystroke := True;
          end;
        end;
      { Alt-X: result ignored }
      #45:
        if CbtActs.VictoryCheat then
          begin end;
    end;
  end;
  GameIo.FlushKeys;
end;

{ Clears the creature's fleeing flag and AI effects, then checks a non-player character's morale (party characters never
  check; a turned creature is forced to flee). Morale is twice the low 7 bits of its non-player-character byte (0 above
  102), adjusted by condition-17 effects, and it holds when it is nonzero and covers the creature's own hit-point loss
  in percent. Failing that, a hostile still holds when the hostiles' remaining hit-point percentage, adjusted the same
  way, is nonzero and at least 100 less the zone's base morale. On a failure the creature flees, dropping its effects 74
  and 75 (bite hold and blood drain), if it is at least twice as fast as the fastest enemy; otherwise one with
  Intelligence above 5 surrenders.
  @param(character The creature.)
  @returns(True on surrender.) }
function CheckMorale(character: Types.PCharRecord): Boolean;
var
  enemyMovement: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedMorale: Byte;
begin
  CheckMorale := False;
  character^.combatAddr^.fleeing := 0;
  FxEngine.RemoveAiEffects(character);
  if character^.combatAddr^.turned <> 0 then begin
    character^.combatAddr^.fleeing := 1;
    CharHlp.PrintCreatureMessage(character, 'is forced to flee', 10, True);
    Exit;
  end;
  if character^.npc <= $7F then
    { PCs never check morale }
    Exit;
  { packed morale rating }
  GDVars.effectScratch.morale := (character^.npc and C_Npc.MORALE_MASK) * 2;
  if GDVars.effectScratch.morale > 102 then
    GDVars.effectScratch.morale := 0;
  { Bless / Curse +-5 }
  FxEngine.TriggerEffectsWithCondition(17, character);
  if (GDVars.effectScratch.morale >= 100 - character^.hpCur * 100 div character^.hpMax) and
      (GDVars.effectScratch.morale <> 0) then
    { own-HP check holds }
    Exit;
  savedMorale := GDVars.effectScratch.morale;
  GDVars.effectScratch.morale := GDVars.hostileHpPct;
  FxEngine.TriggerEffectsWithCondition(17, character);
  if (GDVars.effectScratch.morale >= 100 - GDVars.zone1^.moraleBase) and (GDVars.effectScratch.morale <> 0)
     and (character^.hostile <> C_Side.PLAYER) then
    { group check holds (hostiles) }
    Exit;
  enemyMovement := CbtActs.HighestEnemyMovement(character);
  if enemyMovement <= CbtActs.CalcCreatureMovement(character) div 2 then begin
    { fast enough to get away: flee in panic }
    character^.combatAddr^.fleeing := 1;
    FxEngine.RemoveEffect(character, 74, nil);
    FxEngine.RemoveEffect(character, 75, nil);
  end else if character^.stats[C_Stat.INTELLIGENCE].cur > 5 then begin
    { Int 6+ hostiles give up instead }
    FxEngine.PutOutOfPlayWithStatus(character, C_Status.UNCONSCIOUS, 'Surrenders');
    CheckMorale := CharHlp.EndActions(character);
  end;
end;

{ Scores a weapon for EquipWeaponAndArmor: damage dice product, +8 per plus, +2 per damage bonus (holy water scores 8
  against an undead target), +2 per extra shot for a launcher, +3 one-handed. The score is zero when it would need more
  than 3 hands, for an aligned weapon of another alignment, for the Javelin of Lightning, and when cursed.
  @param(character The creature that would wield the weapon.)
  @param(item The weapon.)
  @returns(The score.) }
function CalcWeaponPriority(character: Types.PCharRecord; item: Types.PItemRec): Byte;
var
  priority: Byte;
  baseItem: Types.TBaseItem;
begin
  baseItem := GDVars.baseItems[item^.itemType];
  priority := baseItem.dmgSmDice * baseItem.dmgSmRolls;
  if item^.plus > 0 then
    priority := priority + item^.plus * 8;
  if baseItem.dmgSmMod > 0 then
    priority := priority + baseItem.dmgSmMod * 2;
  if (item^.itemType = C_Item.HOLY_WATER_VIAL)
     and (character^.combatAddr^.target <> nil)
     and (Types.PCharRecord(character^.combatAddr^.target)^.levelUndead > 0) then
    priority := 8;
  { a weapon that fires ammunition }
  if (baseItem.props and $08) > 0 then
    priority := priority + (baseItem.rateOfFire - 1) * 2;
  if baseItem.hands <= 1 then
    priority := priority + 3;
  if baseItem.hands + character^.handsEquipped > 3 then
    { not enough hands }
    priority := 0;
  if item^.special = CombatAi.ALIGNED_WEAPON_SPECIAL then
    if (item^.effect and $F) <> Byte(character^.alignment) then
      priority := 0;
  if item^.effect = 83 then
    priority := 0;
  if item^.cursed <> 0 then
    priority := 0;
  CalcWeaponPriority := priority;
end;

{ Re-equips a creature with its best usable weapon (CalcWeaponPriority; its unarmed damage sets the bar for melee) and
  its best shield (plus + 1). The ranged pick wins when it scores above half the melee score, has ammunition, and is a
  true ranged weapon or no enemy is beside the creature. Cursed items are never swapped out; with too many hands in use
  the shield, or else the weapon, is unreadied. The creature's information is redrawn when anything changed.
  @param(character The creature.) }
procedure EquipWeaponAndArmor(character: Types.PCharRecord);
var
  bestRanged: Types.PItemRec;
  bestMelee: Types.PItemRec;
  bestShield: Types.PItemRec;
  item: Types.PItemRec;
  ammunition: Types.PItemRec;
  bestRangedPriority: Byte;
  bestMeleePriority: Byte;
  bestShieldPriority: Byte;
  priority: Byte;
  itemType: Byte;
  weaponProperties: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hands: Byte;
  weaponNeedsSwap: Boolean;
  equipmentChanged: Boolean;
  genuineRanged: Boolean;
  ammunitionAvailable: Boolean;
begin
  { stop counting the current weapon / shield hands }
  if character^.equipped[0] <> nil then
    character^.handsEquipped := character^.handsEquipped
        - GDVars.baseItems[character^.equipped[0]^.itemType].hands;
  if character^.equipped[1] <> nil then
    character^.handsEquipped := character^.handsEquipped
        - GDVars.baseItems[character^.equipped[1]^.itemType].hands;
  bestRanged := nil;
  bestMelee := nil;
  bestShield := nil;
  bestRangedPriority := 1;
  bestMeleePriority := character^.unarmedDice[1] * character^.unarmedRolls[1];
  if character^.unarmedMod[1] > 0 then
    bestMeleePriority := bestMeleePriority + character^.unarmedMod[1] * 2;
  bestShieldPriority := 0;
  item := character^.itemsAddr;
  while item <> nil do begin
    itemType := item^.itemType;
    { weapon slot }
    if GDVars.baseItems[itemType].slot = 0 then
      if (GDVars.baseItems[itemType].classMask and character^.classMask) <> 0 then begin
        priority := CombatAi.CalcWeaponPriority(character, item);
        if ((GDVars.baseItems[itemType].props and $08) <> 0)
           or ((GDVars.baseItems[itemType].props and $10) <> 0) then
          if priority > bestRangedPriority then begin
            bestRanged := item;
            bestRangedPriority := priority;
          end;
        if (GDVars.baseItems[itemType].props and $08) = 0 then
          if priority > bestMeleePriority then begin
            bestMelee := item;
            bestMeleePriority := priority;
          end;
      end;
    { shield slot }
    if GDVars.baseItems[itemType].slot = 1 then
      if (GDVars.baseItems[itemType].classMask and character^.classMask) > 0 then begin
        if item^.plus >= 0 then
          priority := item^.plus + 1
        else
          priority := 0;
        if priority > bestShieldPriority then begin
          bestShield := item;
          bestShieldPriority := priority;
        end;
      end;
    item := item^.next;
  end;
  { a real ranged weapon (usable at range even when thrown)? }
  if (bestRanged <> nil)
     and (GDVars.baseItems[bestRanged^.itemType].range > 1)
     and ((GDVars.baseItems[bestRanged^.itemType].props and $14) = $14) then
    genuineRanged := True
  else
    genuineRanged := False;
  ammunitionAvailable := False;
  ammunition := nil;
  weaponProperties := 0;
  if bestRanged <> nil then begin
    weaponProperties := GDVars.baseItems[bestRanged^.itemType].props;
    if (weaponProperties and $10) <> 0 then
      { thrown: is its own ammunition }
      ammunition := bestRanged;
    if (weaponProperties and $08) <> 0 then begin
      if (weaponProperties and $01) <> 0 then
        { arrows }
        ammunition := character^.equipped[11];
      if (weaponProperties and $80) <> 0 then
        { quarrels }
        ammunition := character^.equipped[12];
    end;
  end;
  if (ammunition <> nil) or (weaponProperties = $A) then
    ammunitionAvailable := True;
  { choose the weapon }
  if (bestRanged <> nil)
     and (bestRangedPriority > bestMeleePriority div 2)
     and ammunitionAvailable
     and (genuineRanged or (CharHlp.CountTargets(character, 1) = 0)) then
    item := bestRanged
  else
    item := bestMelee;
  equipmentChanged := False;
  weaponNeedsSwap := True;
  if character^.equipped[0] <> nil then
    if (character^.equipped[0] = item) or (character^.equipped[0]^.cursed <> 0) then
      weaponNeedsSwap := False;
  if weaponNeedsSwap then begin
    if character^.equipped[0] <> nil then
      ViewChar.ToggleReadyItem(character^.equipped[0]);
    CharHlp.RecalcStats(character);
    if character^.equipped[1] <> nil then
      if character^.equipped[1]^.cursed = 0 then
        character^.handsEquipped := character^.handsEquipped
            - GDVars.baseItems[character^.equipped[1]^.itemType].hands;
    if item <> nil then
      ViewChar.ToggleReadyItem(item);
    equipmentChanged := True;
  end;
  CharHlp.RecalcStats(character);
  CbtActs.RecalcAttacksLeft(character);
  weaponNeedsSwap := True;
  if character^.equipped[1] <> nil then
    if (character^.equipped[1] = bestShield)
       or (character^.equipped[1]^.cursed <> 0) then
      weaponNeedsSwap := False;
  if character^.handsEquipped > 2 then begin
    { over-handed: shed the shield, or the new weapon if the shield is stuck }
    if (character^.equipped[1] = nil) or (character^.equipped[1]^.cursed <> 0) then begin
      ViewChar.ToggleReadyItem(item);
      equipmentChanged := True;
    end else begin
      ViewChar.ToggleReadyItem(character^.equipped[1]);
      equipmentChanged := True;
    end;
  end else if (character^.handsEquipped < 2) and weaponNeedsSwap then begin
    if character^.equipped[1] <> nil then
      ViewChar.ToggleReadyItem(character^.equipped[1]);
    CharHlp.RecalcStats(character);
    if bestShield <> nil then
      ViewChar.ToggleReadyItem(bestShield);
    equipmentChanged := True;
  end;
  CharHlp.RecalcStats(character);
  if equipmentChanged then
    CharHlp.CombatPrintCreatureInfo(character);
end;

begin
end.
