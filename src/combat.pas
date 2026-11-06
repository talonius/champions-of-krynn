{ Combat round and player-turn driver. }
{$O+,F+}
unit Combat;

interface

{ Runs a battle. Switches to the combat interface state and the combat cast-target menu, sets up the battle
  (CombatSt.CombatStart) and fires each party member's condition-24 effects, then, unless a side starts empty, plays
  rounds until EndOfRound reports the battle over: count the sides, run each creature's round-start setup, clear the
  zone's surprise mask, sort the creatures by initiative (OrderCreatures) and let them act in that order, each followed
  by any explosions, and end the round. Afterwards it cleans up and turns slow text back on. }
procedure CombatMain;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeCombat;

implementation

uses Types, Blit, Border, GameIo, Crt, CombatAi, CombatSt, CbtActs, ViewChar, GameTime, Magic, FxEngine, CharHlp,
  ClassCal, MenuCore, Pathing, CbtMap, MapTiles, Debug, GDConsts, GDVars, C_Keys, C_Race, C_Ifc, C_Side,
  C_Status, C_Dir, C_Terr, C_Npc, C_Class, C_Init;

procedure OrderCreatures; forward;

procedure CreatureAction(character: Types.PCharRecord); forward;

procedure ManualControl(character: Types.PCharRecord); forward;

procedure CombatMenu(character: Types.PCharRecord; var key: Char); forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(character: Types.PCharRecord; initialKey: Char; var done: Boolean); forward;

procedure MeleeAttack(character, targetCharacter: Types.PCharRecord; var done: Boolean); forward;

procedure DoneMenu(character: Types.PCharRecord; var done: Boolean); forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(character: Types.PCharRecord); forward;

procedure PrimeCombat;
begin
  ViewChar.PrimeViewChar;
  MenuCore.PrimeMenuCore;
  Pathing.PrimePathing;
  CbtMap.PrimeCbtMap;
  MapTiles.PrimeMapTiles;
  CharHlp.PrimeCharHlp;
  Magic.PrimeMagic;
  FxEngine.PrimeFxEngine;
  GameTime.PrimeGameTime;
  Debug.PrimeDebug;
  CombatSt.PrimeCombatSt;
  CbtActs.PrimeCbtActs;
  CombatAi.PrimeCombatAi;
  ClassCal.PrimeClassCal;
end;

{ Ends a battle: frees both cloud lists, turns each okay creature with effect 11 to running while more than one enemy
  remains, drops each creature's effects that end at 0 hit points, frees the arena and the combat view picture, restores
  the noncombat palette, and points the cast-target menu back at the noncombat one. }
procedure CombatDoneCleanup;
var
  nextNode: Types.PCloudNode;
  characterNode: Types.PCharRecord;
  effectNode: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  effectScan: Word;
begin
  while GDVars.cloudHead <> nil do begin
    nextNode := GDVars.cloudHead^.next;
    FreeMem(GDVars.cloudHead, SizeOf(Types.TCloudNode));
    GDVars.cloudHead := nextNode;
  end;
  while GDVars.acidPoolHead <> nil do begin
    nextNode := GDVars.acidPoolHead^.next;
    FreeMem(GDVars.acidPoolHead, SizeOf(Types.TCloudNode));
    GDVars.acidPoolHead := nextNode;
  end;
  characterNode := GDVars.partyHead;
  while characterNode <> nil do begin
    if CharHlp.HasEffect(characterNode, 11, effectNode) then
      if characterNode^.status = C_Status.OKAY then
        if GDVars.teamCount[C_Side.ENEMY] > 1 then characterNode^.status := C_Status.RUNNING
        else characterNode^.status := C_Status.OKAY;
    FxEngine.RemoveEffectsHp0(characterNode);
    characterNode := characterNode^.next;
  end;
  FreeMem(GDVars.arena, SizeOf(Types.TArena));
  GDVars.arena := nil;
  Blit.FreePic(GDVars.viewPicture);
  CbtMap.SetNoncombatPalette;
  GDVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
end;

procedure CombatMain;
var
  done: Boolean;
  characterNode: Types.PCharRecord;
begin
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  GDVars.castTargetMenu := CbtActs.SelectCombatTargets;
  CombatSt.CombatStart;
  done := False;
  if (GDVars.teamCount[C_Side.PLAYER] = 0) or (GDVars.teamCount[C_Side.ENEMY] = 0) then
    done := True;
  characterNode := GDVars.partyHead;
  while characterNode <> nil do begin
    FxEngine.TriggerEffectsWithCondition(24, characterNode);
    characterNode := characterNode^.next;
  end;
  while not done do begin
    CharHlp.CountTeams;
    characterNode := GDVars.partyHead;
    while characterNode <> nil do begin
      CbtActs.BeginRound(characterNode);
      characterNode := characterNode^.next;
    end;
    GDVars.zone1^.surpriseMask := 0;
    Combat.OrderCreatures;
    characterNode := GDVars.combatOrder[1];
    GDVars.roundIndex := 1;
    while characterNode <> nil do begin
      Combat.CreatureAction(characterNode);
      FxEngine.ProcessExplodingCreatures;
      Inc(GDVars.roundIndex);
      if GDVars.roundIndex > 72 then characterNode := nil
      else characterNode := GDVars.combatOrder[GDVars.roundIndex];
    end;
    Combat.EndOfRound(done);
  end;
  Combat.CombatDoneCleanup;
  GDVars.slowText := 1;
end;

{ Fills the combat order with the creatures in descending initiative, inserting each and shifting the later ones down; a
  tie goes either way at random. Note: the insertion point is sought only among the first 64 slots, while the shift that
  makes room runs to the end of the order. }
procedure OrderCreatures;
var
  searching: Boolean;
  characterNode: Types.PCharRecord;
  displacedCreature: Types.PCharRecord;
  nextNode: Types.PCharRecord;
  creatureInitiative: ShortInt;
  slotInitiative: ShortInt;
  index: Byte;
  shiftIndex: Byte;
begin
  characterNode := GDVars.partyHead;
  FillChar(GDVars.combatOrder[1], SizeOf(GDVars.combatOrder), 0);
  while characterNode <> nil do begin
    index := 1;
    searching := True;
    creatureInitiative := characterNode^.combatAddr^.initiative;
    while (index < 65) and searching do begin
      if GDVars.combatOrder[index] <> nil then
        slotInitiative := GDVars.combatOrder[index]^.combatAddr^.initiative
      else
        slotInitiative := -1;
      if (creatureInitiative > slotInitiative) or
          ((creatureInitiative = slotInitiative) and (FxEngine.RollDice(1, 2) = 1)) then
        searching := False
      else
        Inc(index);
    end;
    displacedCreature := GDVars.combatOrder[index];
    GDVars.combatOrder[index] := characterNode;
    if displacedCreature <> nil then begin
      shiftIndex := index;
      searching := True;
      while (shiftIndex < 72) and searching do begin
        Inc(shiftIndex);
        nextNode := GDVars.combatOrder[shiftIndex];
        GDVars.combatOrder[shiftIndex] := displacedCreature;
        displacedCreature := nextNode;
        if nextNode = nil then searching := False;
      end;
    end;
    characterNode := characterNode^.next;
  end;
end;

{ Runs one creature's turn: resets its flanking counts and guard and fires its condition-7 effects. If it still has
  initiative (a finished turn's marker becomes 19), it becomes the current character, the map shows when it is friendly
  or a visible hostile, the view centers on it, its statistics are recalculated and shown, and its condition-15 effects
  fire (and its condition-21 effects when it is not casting). If initiative is still left, the AI (quick fight) or the
  player acts. Last, its cell is redrawn to erase the cursor.
  @param(character The creature whose turn it is.) }
procedure CreatureAction(character: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  initiative: Word;
begin
  character^.combatAddr^.flankCount := 0;
  character^.combatAddr^.flankSpread := 0;
  character^.combatAddr^.guarding := 0;
  FxEngine.TriggerEffectsWithCondition(7, character);
  if character^.combatAddr^.initiative > 0 then begin
    if character^.combatAddr^.initiative = C_Init.TURN_FINISHED_INITIATIVE then
      character^.combatAddr^.initiative := 19;
    GDVars.curChar := character;
    GDVars.gfxEnabled := Ord((character^.hostile = C_Side.PLAYER) or
                               CbtMap.CombatIconVisible(Types.PCharRecord(character), 0));
    CbtMap.DisplayMapViewCentered(Types.PCharRecord(character), 2, True);
    CharHlp.RecalcStats(character);
    GDVars.panelDirty := 1;
    CharHlp.CombatPrintCreatureInfo(character);
    FxEngine.TriggerEffectsWithCondition(15, character);
    if character^.combatAddr^.spellCast = 0 then
      FxEngine.TriggerEffectsWithCondition(21, character);
    if character^.combatAddr^.initiative > 0 then begin
      if character^.quickfight <> 0 then CombatAi.CombatAiControl(character)
      else Combat.ManualControl(character);
    end;
    CbtMap.RedrawArenaCell(CbtMap.CombatCellX(Types.PCharRecord(character)),
                           CbtMap.CombatCellY(Types.PCharRecord(character)));
  end;
end;

{ Runs a player-controlled creature's turn. A creature out of play just ends its actions, and a spell begun earlier is
  cast now and ends them. Otherwise the combat menu repeats until an action ends the turn: Move, View, Aim (attack),
  Use, Cast, Turn undead, Yell and Done do what they say, and Space takes each party member that is not an NPC off quick
  fight. Alt-M toggles magic, Alt-Q or Alt-A ends this creature's turn and puts each creature on quick fight, and Alt-X
  tries the victory cheat.
  @param(character The creature whose turn it is.) }
procedure ManualControl(character: Types.PCharRecord);
var
  key: Char;
  done: Boolean;
  partyMember: Types.PCharRecord;
  aimData: array[1..7] of Byte;
  spellId: Byte;
begin
  if character^.inPlay <> 0 then begin
    if character^.combatAddr^.spellCast > 0 then begin
      spellId := character^.combatAddr^.spellCast;
      character^.combatAddr^.spellCast := 0;
      Magic.CastSpell(spellId, 0, 1, done);
      done := CharHlp.EndActions(character);
    end else begin
      done := False;
      while not done do begin
        GDVars.horizontalChoice := 1;
        Combat.CombatMenu(character, key);
        if GDVars.extendedKeyFlag = False then begin
          case key of
            'M': Combat.MoveMenu(character, ' ', done);
            'V': begin
                   ViewChar.ViewCharMenu(done);
                   CbtActs.RecalcAttacksLeft(character);
                   if not done then CharHlp.DisplayCombatInterface;
                 end;
            'A': CbtActs.CombatAimMenu(character, -1, 1, 0, 1, done, aimData);
            'U': begin
                   GDVars.horizontalChoice := 2;
                   ViewChar.UseItemMenu(done);
                   CbtActs.RecalcAttacksLeft(character);
                   if not done then CharHlp.DisplayCombatInterface;
                 end;
            'C': CbtActs.CastSpellCombat(0, 0, done);
            'T': begin
                   CbtActs.CombatTurnUndead(character);
                   done := CharHlp.EndActions(character);
                 end;
            'Y': begin
                   FxEngine.YellTaunt(character);
                   done := CharHlp.EndActions(character);
                 end;
            'D': Combat.DoneMenu(character, done);
            ' ': begin
                   partyMember := GDVars.partyHead;
                   while partyMember <> nil do begin
                     if partyMember^.npc < C_Npc.NON_PLAYER then partyMember^.quickfight := 0;
                     partyMember := partyMember^.next;
                   end;
                 end;
          end;
        end else begin
          case key of
            #50: begin
                   GDVars.magicEnabled := GDVars.magicEnabled = False;
                   if GDVars.magicEnabled then CharHlp.PrintBottomLine('Magic On')
                   else CharHlp.PrintBottomLine('Magic Off');
                 end;
            #16, #30: begin
                   Dec(GDVars.roundIndex);
                   character^.combatAddr^.initiative := C_Init.TURN_FINISHED_INITIATIVE;
                   partyMember := GDVars.partyHead;
                   while partyMember <> nil do begin
                     Combat.TurnOnAuto(partyMember);
                     partyMember := partyMember^.next;
                   end;
                   MenuCore.ClearBottomLine;
                   Delay(200);
                   done := True;
                 end;
            #45: begin
                   if CbtActs.VictoryCheat then begin
                     CbtMap.DisplayMapViewCentered(Types.PCharRecord(character), 3, False);
                     done := True;
                   end else
                     CharHlp.PrintBottomLine('That doesn''t work');
                 end;
          end;
        end;
        if not done then begin
          CbtMap.DisplayMapViewCentered(Types.PCharRecord(character), 2, True);
          GDVars.panelDirty := 1;
          CharHlp.CombatPrintCreatureInfo(character);
        end;
      end;
    end;
  end else
    done := CharHlp.EndActions(character);
end;

{ Builds the combat menu (Move while movement remains, View, Aim, Use with items, Cast with memorized spells when the
  creature may cast and the zone allows it, Turn for a cleric with turnings left against the undead present, Yell for a
  kender while nobody has been taunted, Done, and * in debug mode) and returns the first accepted key. Alt-R is accepted
  but ManualControl ignores it.
  @param(character The creature whose turn it is.)
  @param(key Receives the key; extendedKeyFlag tells whether it is a scan code.) }
procedure CombatMenu(character: Types.PCharRecord; var key: Char);
var
  menu: Types.TStr40;
  index: Byte;
  menuFlag: Boolean;
begin
  menu := '';
  if character^.combatAddr^.movement > 0 then menu := menu + 'Move ';
  menu := menu + 'View Aim ';
  if character^.itemCount > 0 then menu := menu + 'Use ';
  menuFlag := False;
  for index := 0 to 57 do
    if character^.memorized[index] > 0 then menuFlag := True;
  if menuFlag then
    if character^.combatAddr^.castOk <> 0 then
      if GDVars.zone0^.castLock = 0 then
        menu := menu + 'Cast ';
  if (character^.classLevels[C_Class.CLERIC] > 0) or
      ((character^.classLevels2[C_Class.CLERIC] > 0) and
       ClassCal.EarlierClassActive(character)) then
    if character^.combatAddr^.turnUses < GDVars.undeadCount then
      menu := menu + 'Turn ';
  if character^.race = C_Race.KENDER then
    if GDVars.yellTarget = nil then
      menu := menu + 'Yell ';
  menu := menu + 'Done';
  if GDVars.debugActive <> 0 then menu := menu + '*';
  repeat
    key := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, menuFlag);
    if menuFlag then
      if not (key in [#16, #19, #30, #45, #50]) then key := #0;
  until key in [#16, #19, #30, ' ', '-', '2', 'A', 'C', 'D', 'M', 'Q', 'T', 'U', 'V', 'Y'];
  MenuCore.ClearBottomLine;
end;

{ Ends a round: advances the clock a minute, counts the round, refigures the hostiles' hit-point percentage, fires each
  creature's condition-19 effects and terrain effects, bleeds dying creatures (dead past overkill 9), warns when a party
  member is dying, counts the sides and rebuilds the view. The battle is done when a side is empty or the round limit is
  reached; when the party is left alone outside the demo, the player is asked whether to continue the battle.
  @param(done Set when the battle is over, and cleared when the player continues it; otherwise left as it was.) }
procedure EndOfRound(var done: Boolean);
var
  partyMember: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  status: Byte;
  combatantNumber: Byte;
begin
  GameTime.AdvanceTime(1, 1);
  Inc(GDVars.roundNumber);
  CbtActs.UpdateHostileHpPercent;
  partyMember := GDVars.partyHead;
  combatantNumber := 1;
  while partyMember <> nil do begin
    FxEngine.TriggerEffectsWithCondition(19, partyMember);
    FxEngine.ConsiderTerrainEffects(partyMember, 0);
    if partyMember^.status = C_Status.DYING then begin
      Inc(partyMember^.combatAddr^.overkill);
      if partyMember^.combatAddr^.overkill > 9 then partyMember^.status := C_Status.DEAD_STATUS;
    end;
    Inc(combatantNumber);
    partyMember := partyMember^.next;
  end;
  if CharHlp.BandageDying(False) then
    CharHlp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GDVars.arena^.originX + 3, GDVars.arena^.originY + 3, 255, 8);
  if (GDVars.teamCount[C_Side.PLAYER] = 0) or (GDVars.teamCount[C_Side.ENEMY] = 0) or
      (GDVars.roundNumber >= GDVars.roundLimit) then
    done := True;
  if (GDVars.teamCount[C_Side.PLAYER] > 0) and (GDVars.teamCount[C_Side.ENEMY] = 0) and
      (GDVars.demoFlag = 0) then
    if MenuCore.YesNoMenu('Continue Battle:', LightMagenta, LightGreen, White) = 'Y' then
      done := False;
end;

{ Moves the creature with the arrow and diagonal keys, prompting with the movement left. Bumping a creature attacks it;
  stepping off the arena offers to flee; a step costing more than the movement left is refused. Each step allows
  opportunity attacks and terrain effects, and a creature left out of play or helpless ends its actions. Escape undoes
  the whole move; Enter or Done ends it, and movement below 2 half-steps is dropped.
  @param(character The moving creature.)
  @param(initialKey The first key: a direction key, or a space to prompt for one.)
  @param(done Set when the creature's actions are over.) }
procedure MoveMenu(character: Types.PCharRecord; initialKey: Char; var done: Boolean);
var
  startingMovement: Byte;
  startingFacing: Byte;
  cellX: Byte;
  cellY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slot: Word;
  direction: Byte;
  creatureIndex: Byte;
  terrainIndex: Byte;
  key: Char;
  adjacentCorpse: Byte;
  adjacentWater: Byte;
  movementCost: Byte;

  { Puts the creature back where the move began, with its movement and facing restored. }
  procedure UndoMove;
  begin
    character^.combatAddr^.movement := startingMovement;
    CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(Types.PCharRecord(character)));
    done := not CbtMap.IsValidCreatureLoc(Types.PCharRecord(character), cellX, cellY, False);
    CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(character)),
                      CbtMap.CombatCellY(Types.PCharRecord(character)), 0, 8);
    character^.combatAddr^.facing := startingFacing;
    direction := C_Dir.CENTER;
  end;

begin
  GDVars.creatureCursorActive := 1;
  startingMovement := character^.combatAddr^.movement;
  startingFacing := character^.combatAddr^.facing;
  cellX := CbtMap.CombatCellX(Types.PCharRecord(character));
  cellY := CbtMap.CombatCellY(Types.PCharRecord(character));
  key := initialKey;
  done := False;
  direction := C_Dir.CENTER;
  repeat
    while (key <> C_Keys.NONE) and (key <> C_Keys.ENTER) and (key <> 'D') and not done do begin
      Border.ClearBox(24, 24, 39, 24);
      if key = ' ' then
        key := MenuCore.MenuHorizontal('Move/Attack, Move Left = ' +
                                       CharHlp.Uint8Str(character^.combatAddr^.movement div 2), ' Done',
                                       LightMagenta, LightGreen, White, True, False, GDVars.combatExtendedKey);
      case key of
        C_Keys.NONE: UndoMove;
        C_Keys.UP: direction := C_Dir.NORTH;
        C_Keys.PAGE_UP: direction := C_Dir.NORTHEAST;
        C_Keys.RIGHT: direction := C_Dir.EAST;
        C_Keys.PAGE_DOWN: direction := C_Dir.SOUTHEAST;
        C_Keys.DOWN: direction := C_Dir.SOUTH;
        C_Keys.END_KEY: direction := C_Dir.SOUTHWEST;
        C_Keys.LEFT: direction := C_Dir.WEST;
        C_Keys.HOME: direction := C_Dir.NORTHWEST;
      else
        direction := C_Dir.CENTER;
      end;
      if direction < C_Dir.CENTER then begin
        CbtMap.SetCreatureFacing(Types.PCharRecord(character), direction, 0, 0);
        CbtMap.ProbeDirection(Types.PCharRecord(character), direction, creatureIndex, terrainIndex, adjacentCorpse,
                              adjacentWater);
        if creatureIndex > 0 then
          Combat.MeleeAttack(character, GDVars.creatureArr[creatureIndex], done)
        else if terrainIndex = 0 then begin
          case MenuCore.YesNoMenu('Flee:', LightMagenta, LightGreen, White) of
            'Y': done := CbtActs.AttemptFlee(character);
            'N': done := False;
          end;
        end else begin
          if Odd(direction) then movementCost := GDConsts.terrainInfo[terrainIndex].movementCost * 3
          else movementCost := GDConsts.terrainInfo[terrainIndex].movementCost * 2;
          if GDConsts.terrainInfo[terrainIndex].movementCost = C_Terr.TERRAIN_IMPASSABLE then
            movementCost := C_Terr.TERRAIN_IMPASSABLE;
          if movementCost > character^.combatAddr^.movement then
            CharHlp.PrintBottomLine('can''t go there')
          else begin
            CbtActs.AttacksOfOpportunity(character, direction);
            if character^.inPlay = 0 then
              done := CharHlp.EndActions(character)
            else begin
              if character^.combatAddr^.movement > 0 then CbtActs.CombatMoveCreature(character, direction);
              if character^.inPlay = 0 then done := CharHlp.EndActions(character);
              FxEngine.ConsiderTerrainEffects(character, 1);
              if CharHlp.IsHelpless(character) then done := CharHlp.EndActions(character);
            end;
          end;
        end;
      end;
      if (key <> C_Keys.NONE) and (key <> C_Keys.ENTER) and (key <> 'D') then key := ' ';
    end;
  until (key <> ' ') or done;
  if character^.combatAddr^.movement < 2 then character^.combatAddr^.movement := 0;
  GDVars.creatureCursorActive := 0;
end;

{ Makes MoveMenu's attack on a creature in the way, refused with a ranged weapon that cannot be thrown. Once an attack
  on an ally is confirmed, the target is locked, and a sweep is tried before a normal attack.
  @param(character The attacker.)
  @param(targetCharacter The creature attacked.)
  @param(done Receives True when the attacker's actions are over; left as it was when the attack is refused.) }
procedure MeleeAttack(character, targetCharacter: Types.PCharRecord; var done: Boolean);
begin
  if CharHlp.HasRangedWeapon(character) and not CharHlp.HasThrowableWeapon(character) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(character, targetCharacter) then begin
    character^.combatAddr^.target := targetCharacter;
    if CbtActs.SweepAttack(character, targetCharacter) then
      done := True
    else begin
      CbtActs.NoteAttackDirection(character, targetCharacter);
      CbtActs.MakeAttack(character, targetCharacter, 0, nil, done);
    end;
  end;
end;

{ Offers Guard (with a melee or throwable weapon), Delay (initiative 1, moving the creature to the end of the order so
  it acts again later), Quit (end its actions), Bandage (while a party member is dying), Auto (quick fight, with the AI
  acting at once), Speed and Exit, until a choice ends the creature's actions or it leaves with Exit or Escape.
  @param(character The creature whose turn it is.)
  @param(done Set when the choice ends the creature's actions.) }
procedure DoneMenu(character: Types.PCharRecord; var done: Boolean);
var
  menu: Types.TStr40;
  key: Char;
  partyMember: Types.PCharRecord;
  orderIndex: Byte;
begin
  done := False;
  menu := '';
  { Guard is offered unless the weapon is ranged and cannot be thrown, the test MeleeAttack uses to reject a weapon }
  if not CharHlp.HasRangedWeapon(character) or CharHlp.HasThrowableWeapon(character) then
    menu := menu + 'Guard ';
  menu := menu + 'Delay Quit ';
  if CharHlp.BandageDying(False) then menu := menu + 'Bandage ';
  menu := menu + 'Auto Speed Exit';
  key := ' ';
  while not (key in [C_Keys.NONE, 'E']) and not done do begin
    key := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, False, False, GDVars.combatExtendedKey);
    case key of
      'G': done := CharHlp.Guard(character);
      'D': begin
             character^.combatAddr^.initiative := 1;
             orderIndex := GDVars.roundIndex;
             partyMember := GDVars.combatOrder[orderIndex + 1];
             while (partyMember <> nil) and (orderIndex < 72) do begin
               GDVars.combatOrder[orderIndex] := partyMember;
               Inc(orderIndex);
               partyMember := GDVars.combatOrder[orderIndex + 1];
             end;
             GDVars.combatOrder[orderIndex] := character;
             Dec(GDVars.roundIndex);
             done := True;
           end;
      'Q': done := CharHlp.EndActions(character);
      'B': begin
             done := CharHlp.BandageDying(True);
             done := CharHlp.EndActions(character);
           end;
      'S': Combat.SpeedMenu;
      'A': begin
             Combat.TurnOnAuto(character);
             MenuCore.ClearBottomLine;
             GameIo.FlushKeys;
             Delay(200);
             done := True;
             CombatAi.CombatAiControl(character);
           end;
    end;
  end;
end;

{ Adjusts the game delay: Slower (offered below 9) raises it, Faster (offered above 0) lowers it, and Exit or Escape
  leaves. }
procedure SpeedMenu;
var
  menu: Types.TStr40;
  query: Types.TStr40;
  key: Char;
begin
  key := ' ';
  while not (key in [C_Keys.NONE, 'E']) do begin
    query := 'GameSpeed (' + CharHlp.Uint8Str(GDVars.gameDelay) + ') :';
    menu := ' ';
    if GDVars.gameDelay < 9 then menu := menu + 'Slower ';
    if GDVars.gameDelay > 0 then menu := menu + 'Faster ';
    menu := menu + 'Exit';
    key := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, False, False,
                                   GDVars.combatExtendedKey);
    case key of
      'S': Inc(GDVars.gameDelay);
      'F': Dec(GDVars.gameDelay);
    end;
  end;
end;

{ Puts a creature on quick fight and drops a locked target on its own side.
  @param(character The creature to hand to the AI.) }
procedure TurnOnAuto(character: Types.PCharRecord);
begin
  character^.quickfight := 1;
  if character^.combatAddr^.target <> nil then
    if Types.PCharRecord(character^.combatAddr^.target)^.hostile = character^.hostile then
      character^.combatAddr^.target := nil;
end;

begin
end.
