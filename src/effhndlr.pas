{ Effect callback dispatch, combat modifiers, creature transformations, and persistent area-effect cleanup. }
{$O+,F+}
unit EffHndlr;
interface

uses Types, TextRend, ViewChar, FxEngine, CharHlp, ClassCal, Pathing, CbtMap, Debug, GDConsts, GDVars,
  C_Ifc, C_Status, C_Stat, C_Terr, C_Effect, C_Side, C_Class, C_Item, C_Race;

{ Fills the effect handler table with the handler of each effect, and sets the override handler used for items
  (EffGrantItemEffect). }
procedure InitEffectHandlers;

{ Calls the priming entry of each overlay this unit uses, so the overlay manager loads them. }
procedure PrimeEffHndlr;

{ Paralyzes the creature's combat target for the given minutes when it fails a saving throw (type 0). Note: the save
  modifier is never used, so the save has no modifier.
  @param(creature The attacking creature.)
  @param(minutes How long the paralysis lasts.)
  @param(saveMod Unused.) }
procedure ParalyzeTarget(var creature; minutes: Word; saveMod: ShortInt);

{ Cancels the pending effect and the damage when the given effect is 0 or is the effect being applied.
  @param(effectId The effect to cancel, or 0 for whichever effect is pending.) }
procedure NullifyAttack(effectId: Byte);

{ Adds an effect, removed through its handler, unless the effect lock is set.
  @param(creature The creature given the effect.)
  @param(effectId The effect.)
  @param(strength Its strength.)
  @param(minutes Its duration.)
  @returns(True when the effect was added.) }
function AddEffectIfNoLock(var creature; effectId, strength: Byte; minutes: Word): Boolean;

{ Helpless effect: ends the creature's actions for the round.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffHelpless(var creature; handlerData: Pointer; removed: Boolean);

{ Adds 1 to the saving-throw roll and to the attack roll.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure AddRollBonus(var creature; handlerData: Pointer; removed: Boolean);

{ Applies the bless effect: adds 5 to morale and 1 to the attack roll.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffBless(var creature; handlerData: Pointer; removed: Boolean);

{ Applies the curse effect: takes 5 from morale (not below 0) and 1 from the attack roll.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffCurse(var creature; handlerData: Pointer; removed: Boolean);

{ Applies sticks to snakes: the snakes use up the creature's attacks this round, taking them off the effect's strength
  (the effect ends when it runs out); the creature is shown fighting with snakes and its actions end.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffSticksToSnakes(var creature; handlerData: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrC;

{ Effect 7: replaces the attack's damage and THAC0: in melee 1d6 + 2 plus the Strength damage bonus and the weapon's
  plus with the Strength to-hit bonus, at range 1d4 + 1 plus the plus with the Dexterity missile bonus. Note: without a
  readied weapon the plus is never set.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffSetAttackDamage(var creature; handlerData: Pointer; removed: Boolean);

{ Applies protection from evil: against an evil attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffProtEvil(var creature; handlerData: Pointer; removed: Boolean);

{ Applies protection from good: against a good attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffProtGood(var creature; handlerData: Pointer; removed: Boolean);

{ Applies resist cold: halves cold damage and adds 3 to the saving throw against it.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffResistCold(var creature; handlerData: Pointer; removed: Boolean);

{ Applies charm: the first time (strength bit 5 marks it), saves the creature's side in strength bit 6, moves it to the
  side in bit 7, makes it a quick fighter (NPC value $B3 unless the value is above $7F), drops its target and recounts
  the sides; each call except a removal sets morale to 100. On removal the saved side returns and the NPC value $B3 is
  cleared.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffCharm(var creature; handlerData: Pointer; removed: Boolean);

{ Does nothing for the enlarge and strength effects.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffStrengthBonus(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 13: a creature that is down rises okay with 20 hit points, 'goes mad!', and becomes animated with effects 48,
  57 and 58 (6 minutes), losing this effect and its memorized spells.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffReviveAsMad(var creature; handlerData: Pointer; removed: Boolean);

{ Does nothing for the friends effect.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffFriends(var creature; handlerData: Pointer; removed: Boolean);

{ Applies the poison that slow poison holds back: every ten minutes, unless the effect lock is set, renews itself and
  costs the creature 1 hit point while it has more than 1, redrawing the party display outside combat.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffSlowPoisonHit(var creature; handlerData: Pointer; removed: Boolean);

{ Does nothing for the read magic effect.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffReadMagic(var creature; handlerData: Pointer; removed: Boolean);

{ Applies shield: raises the creature's armor class value to at least 57 (armor class 3), adds 1 to the saving throw,
  and stops Magic Missile.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffShield(var creature; handlerData: Pointer; removed: Boolean);

{ Half-elven resistance: a 30 percent chance to resist sleep and charm.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffHalfElfResistance(var creature; handlerData: Pointer; removed: Boolean);

{ Applies resist fire: halves fire damage and adds 3 to the saving throw against it, except on removal.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistFire(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 21 (Silence): the creature can neither cast nor use items this round, with an 'is silenced' message the first
  time.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffSilence(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 22 (Slow Poison), on ending: a creature still poisoned dies of the poison; the held-back poison damage effect
  is removed under the effect lock.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffSlowPoisonEnd(var creature; handlerData: Pointer; removed: Boolean);

{ Spiritual Hammer effect: adding it gives the creature a +1 spiritual hammer, readied if it has no weapon ready, unless
  it already has one or its pack is full; removing it takes the hammer away. The creature's statistics are then
  recalculated. Note: the search after adding the hammer stops one item past it, so a different item can be readied.
  @param(creature The creature the effect is on.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpiritualHammer(var creature; handlerData: Pointer; removed: Boolean);

{ Applies invisibility: unless the current character can see invisible, it may not target the creature and takes 4 from
  its attack roll, except on removal.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisible(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 26: a dwarf adds 1 to the attack roll against a target of character type bit 7.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffDwarfHitBonus(var creature; handlerData: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrA;

{ Applies mirror image: an attack has a chance (strength div 16 images in strength div 16 + 1) to hit an image instead,
  which cancels it and loses an image; the effect ends with the last one. A spell aimed at an area never strikes an
  image.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffMirrorImage(var creature; handlerData: Pointer; removed: Boolean);

{ Applies ray of enfeeblement: the damage loses a quarter, rounded down.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffEnfeeble(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 30 (coughing in a stinking cloud): the creature can neither cast nor use items this round, with an 'is
  coughing' message the first time, and its armor class worsens by 2 (to AC 10 at worst).
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffCoughing(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 32 (Animate Dead): a creature that is down rises okay with 20 hit points, 'Arises in a new form', with effects
  59, 60 (3 minutes) and 66, and loses this effect and effects 4, 48, 57 and 58.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffTransformOnDeath(var creature; handlerData: Pointer; removed: Boolean);

{ Applies blindness: the attack roll, armor class, armor class from behind and saving throw each lose 4.
  @param(creature The creature with the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffBlind(var creature; handlerData: Pointer; removed: Boolean);

{ Applies disease: runs the handlers of the strength-loss and hit-point-loss diseases.
  @param(creature The creature carrying the effect.)
  @param(handlerData Passed on to the handlers.)
  @param(removed Passed on to the handlers.) }
procedure EffDiseased(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 35 (Confusion): d100 picks a reaction: 1..10 the creature runs away (Fear, effect 111, under computer control),
  11..60 it is helpless, 61..80 it goes berserk (effect 77), 81..100 it is enraged but acts. A saving throw (type 4, -2)
  then ends the confusion.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffConfusion(var creature; handlerData: Pointer; removed: Boolean);

{ Applies bestow curse: takes 4 from the attack roll and the saving throw.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffBestowCurse(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 37 (Blink): while the creature has no initiative left, vetoes targeting and makes the attack roll miss.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffBlinking(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 39 (Haste): doubles movement and attacks; the first time the creature ages a year.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffHasted(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 40, on ending: clears the creature's stinking cloud (strength div 16 picks it), putting back the terrain or the
  bodies under it, and redraws the clouds and acid pools still in place.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffClearStinkingCloud(var creature; handlerData: Pointer; removed: Boolean);

{ Lets a creature avoid a missile: when the current character has a readied weapon and stands more than one cell away, a
  d100 roll within the chance cancels the damage, makes the attack miss and takes the hit back, with 'Avoids it'.
  @param(creature The creature attacked.)
  @param(chance The chance in percent.) }
procedure AvoidMissile(var creature; chance: Byte);

{ Finds the item a creature attacks with: the missile its readied weapon fires or throws, else the readied weapon.
  @param(creature The creature.)
  @returns(The item, or nil with no weapon readied.) }
function FindDamagingWeapon(creature: Types.PCharRecord): Types.PItemRec;

{ Protection from Normal Missiles effect: a missile without a plus is always avoided.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffProtNormalMissiles(var creature; handlerData: Pointer; removed: Boolean);

{ Applies slow: halves movement and attacks.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffSlow(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 43: every hour, unless the effect lock is set, the disease renews itself and weakens the creature by a point of
  Strength, leaving it helpless once Strength is 3.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffDiseaseStrength(var creature; handlerData: Pointer; removed: Boolean);

{ Hit-point disease: unless the effect lock is on, it re-arms for 10 minutes and deals 1 damage, or at 1 hit point the
  creature becomes helpless.
  @param(creature The creature with the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffDiseaseHitPoints(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 47: a dwarf's defense against giants: takes 4 from the attack roll of an attacker (the current character) of
  character type bit 2.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffDwarfGiantDefense(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 48: the creature immolates, dealing 1d6 damage to each creature in play next to it.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffImmolate(var creature; handlerData: Pointer; removed: Boolean);

{ Applies prayer: gives the side named by strength bit 4 a 1 bonus to saving throws and attack rolls and the other side
  a 1 penalty.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Passed on to the bonus routine.) }
procedure EffPrayer(var creature; handlerData: Pointer; removed: Boolean);

{ Applies fire vulnerability: adds 2 to the saving throw against cold, and doubles fire damage when the saving throw
  failed.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffFireVulnerable(var creature; handlerData: Pointer; removed: Boolean);

{ Applies cold vulnerability: adds 2 to the saving throw against fire, and doubles cold damage. Note: the doubling tests
  recentlySaved, the game's save flag, instead of the saving throw's result.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffColdVulnerable(var creature; handlerData: Pointer; removed: Boolean);

{ Does nothing for the poisoned effect.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffPoisoned(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 56: makes the creature invisible again (effect 25) for a minute.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffRenewInvisibility(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 57: adds 2 to the attack roll and to the creature's armor class.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffCombatBonus(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 58, on ending: the animated form gives way to effects 59 and 60 (3 minutes, removed through its handler), and
  effects 4, 32, 48 and 57 are removed.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffEndTransformation(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 59: cancels the pending damage and effect.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffCancelDamage(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 60, on ending: the creature 'explodes!' and is gone; each creature in play next to it takes 3d6 damage and is
  stunned (effect 106) unless it makes a saving throw (type 4).
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffExplodeOnRemoval(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 61 (ring of fire resistance): fire damage loses 2 per die (at least 1 per die), the saving throw gains 4, and
  fire that is not magical has no effect.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffRingFireRes(var creature; handlerData: Pointer; removed: Boolean);

{ Constitution regeneration, for Constitution 20 and over: unless the effect lock is set, renews itself for an hour and
  heals a hit point.
  @param(creature Creature with the effect.)
  @param(handlerData The effect record.)
  @param(removed Unused.) }
procedure EffConRegeneration(var creature; handlerData: Pointer; removed: Boolean);

{ Applies minor globe of invulnerability: cancels spells below level 4.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffMinorGlobe(var creature; handlerData: Pointer; removed: Boolean);

{ Poisons the creature's combat target: unless it makes a saving throw (type 0) with saveMod (and the strength of its
  poison resistance, effect 116, when saveMod is not negative), it is poisoned and killed.
  @param(creature The attacking creature.)
  @param(saveMod Added to the target's saving throw.) }
procedure PoisonTarget(var creature; saveMod: ShortInt);

{ Makes a hit poisonous: the target saves against poison or dies.
  @param(creature The creature the effect is on.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);

{ Makes a hit weakly poisonous: the target saves against poison, at +4, or dies.
  @param(creature The creature the effect is on.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffWeakPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 66: zaps the first enemy next to the creature for 2d6 damage, ending the creature's actions.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffZapNearbyEnemy(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 67: a melee attacker (the current character) whose Dexterity - 3 is at most a d20 loses its uncursed weapon to
  the bank, which gives it back after the battle; the spiritual hammer is kept.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffDisarmAttacker(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 68: a creature out of play is marked exploded and queued for ProcessExplodingCreatures (up to 20), and the
  effect is removed.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffQueueExplosion(var creature; handlerData: Pointer; removed: Boolean);

{ Paralyzing-hit effect: a hit paralyzes the target for 100 minutes unless it saves.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffParalyzingHit(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 70: a creature that falls 'dissolves into acid!', leaving an acid pool on its cell that drains in 1d6 minutes
  (effect 80) and keeps the terrain under it.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffCreateAcidPool(var creature; handlerData: Pointer; removed: Boolean);

{ Reflects a spell back at its caster (the current character): always one of area type above 14, one time in ten one of
  area type below 8.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffReflectSpell(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 72 (dragon fear): each enemy next to the creature without effect 92 that fails a saving throw (type 4) is
  terrified (Fear, effect 111) and turned.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffDragonFear(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 73: breath weapons have no effect: a breath attack is canceled and the creature "is unaffected".
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffImmuneBreath(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 74: one time in twenty casts Dispel Magic.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffRandomDispelMagic(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 75 (dragon slayer weapon): against a dragon (target flag bit 0) the damage becomes 3d12 + 4 plus the Strength
  bonus, and the attack roll gains 2.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffDragonSlayer(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 76: once the creature is below half its hit points, its removed allies gate back in at full hit points on free
  cells around the enemies, then this effect ends. Note: a cell beside an enemy at the arena's edge is retried without
  end.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffGateInDeadAllies(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 77 (berserk): the creature fights under computer control, in combat taking the nearest creature as its target
  and its side as that target's enemy, and cannot cast. On removal it returns to the party's side and to player control.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBerserk(var creature; handlerData: Pointer; removed: Boolean);

{ Applies evil stench: each enemy next to the creature that fails a saving throw (type 4) is affected. Note: the stench
  penalty goes on the creature emitting the stench, not on the enemy affected.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffEvilStench(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 80, on ending: drains the creature's acid pool (strength picks it), putting back the terrain or a body under
  it, and redraws the clouds and pools still in place.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffRemoveAcidPool(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 81: a hit does no damage but paralyzes the target for 100 minutes unless it saves.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffParalyzingStrike(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 82: each enemy without effects 92, 111 and 119 is frightened: one of level 3 or below is terrified (Fear,
  effect 111) and turned; a higher one that fails a saving throw (type 4) is afraid (effect 119).
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffFrightenAllEnemies(var creature; handlerData: Pointer; removed: Boolean);

{ Makes a hit strongly poisonous: the target saves against poison, at -2, or dies.
  @param(creature The creature the effect is on.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffStrongPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 87: a hit poisons the target (PoisonTarget, +1 to the save).
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffSlightPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);

{ Applies ghoul touch: a hit paralyzes a target that is not a Silvanesti or Qualinesti elf for 100 minutes unless it
  saves.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffGhoulPara(var creature; handlerData: Pointer; removed: Boolean);

{ Applies displacement: the first attack on the creature misses; the mark in strength bit 4 is cleared only in round 0
  on a zero attack roll.
  @param(creature Unused.)
  @param(handlerData The effect's node.)
  @param(removed Unused.) }
procedure EffDisplaced(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 91 (taunted by a kender's yell): empty; AcquireTarget and CountTargets read it.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffTaunted(var creature; handlerData: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrD;

{ Effect 93: halves damage from weapons with defense flags $81.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffHalfPierceBash(var creature; handlerData: Pointer; removed: Boolean);

{ Constitution save bonus: adds 1 to 5, for Constitution 4 to 20, to saving throws of types 0, 2 and 4. Note: other
  Constitution values leave the bonus undefined.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffConSpellSave(var creature; handlerData: Pointer; removed: Boolean);

{ Elven resistance: a 90 percent chance to resist sleep and charm.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffElfResistance(var creature; handlerData: Pointer; removed: Boolean);

{ Immunity to sleep and charm: charm and sleep have no effect.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffImmuneSleepCharm(var creature; handlerData: Pointer; removed: Boolean);

{ Immunity to paralysis: paralysis has no effect.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysis(var creature; handlerData: Pointer; removed: Boolean);

{ Applies cold immunity: cancels the effect and the damage of cold attacks.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffImmuneCold(var creature; handlerData: Pointer; removed: Boolean);

{ Immunity to poison and paralysis: poison and paralysis have no effect, and saving throws of type 0 always succeed.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffImmuneParalysisPoison(var creature; handlerData: Pointer; removed: Boolean);

{ Halves the pending damage when the current character's weapon is a slashing or piercing one.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffHalfSlashPierce(var creature; handlerData: Pointer; removed: Boolean);

{ Applies vulnerability to holy water: an attacker (the current character) wielding a holy water vial does 1d6 + 1
  damage.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffHolyWater(var creature; handlerData: Pointer; removed: Boolean);

{ Does nothing.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffNoneB(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 103: damage from a weapon without a plus is canceled, unless the attacker is a monster of level 4 or more.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffNeedMagicWeapon(var creature; handlerData: Pointer; removed: Boolean);

{ Applies the ranger damage bonus: adds the creature's ranger level to the damage when its target has creature-type flag
  bit 3.
  @param(creature The creature that carries the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffRangerDamageBonus(var creature; handlerData: Pointer; removed: Boolean);

{ Ends the creature's actions for the round.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffEndActions(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 107: like EffBerserk, the creature fights under computer control against the nearest creature; on removal its
  side comes back from the effect's strength.
  @param(creature The creature carrying the effect.)
  @param(handlerData The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusedBerserk(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 108: makes the creature invisible (effect 25) for good.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffLastingInvisibility(var creature; handlerData: Pointer; removed: Boolean);

{ Does nothing.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffNoneC(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 110, on removal: recomputes the creature's level bucket from its knight levels, one bucket per five levels.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRecalcLevelBucket(var creature; handlerData: Pointer; removed: Boolean);

{ Applies fear: on removal a $B3 creature leaves AI control and the creature is no longer forced to flee.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFear(var creature; handlerData: Pointer; removed: Boolean);

{ Zaps an adjacent attacker (the current character): it 'gets zapped' for twice the pending damage, as magic.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffZapAttacker(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 113 (Giant Strength): empty; RecalcAbility reads its Strength.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffGiantStrength(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 114 (a dragonlance): against a dragon (target flag bit 0) the damage becomes the wielder's current hit points.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffDragonlance(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 115: adds 3 to the damage against a target of character type bit 5.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffTypeDamageBonus(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 116 (poison resistance): empty; PoisonTarget reads its strength.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffPoisonResistance(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 117 (a mace of disruption): in combat, against a target of character type bit 1, an undead one is disrupted and
  gone, any other takes double damage.
  @param(creature The creature carrying the effect.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffDisruption(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 118: takes 2 from the attack roll.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffAttackPenaltyTwo(var creature; handlerData: Pointer; removed: Boolean);

{ Effect 119: takes 1 from the attack roll.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffAttackPenaltyOne(var creature; handlerData: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrB;

{ Does nothing.
  @param(creature Unused.)
  @param(handlerData Unused.)
  @param(removed Unused.) }
procedure EffNone(var creature; handlerData: Pointer; removed: Boolean);

{ The override handler for an item's special effect: adds the item's effect to the creature (removed through its
  handler) or, on removal, takes it away, and clears the override flag.
  @param(creature The creature readying or unreadying the item.)
  @param(handlerData The item whose effect is granted.)
  @param(removed True when the item is unreadied.) }
procedure EffGrantItemEffect(var creature; handlerData: Pointer; removed: Boolean);

implementation

procedure NoopEffHndlrC;
begin
end;

procedure NoopEffHndlrA;
begin
end;

procedure NoopEffHndlrD;
begin
end;

type
  TNN16 = 0..32767;

procedure ParalyzeTarget(var creature; minutes: Word; saveMod: ShortInt);
begin
  GDVars.effectScratch.other := Types.PCharRecord(creature)^.combatAddr^.target;
  if not FxEngine.RollSavingThrow(GDVars.effectScratch.other, 0, 0) then begin
    CharHlp.PrintNameStringAnim(GDVars.effectScratch.other, 1, 'is Paralyzed');
    FxEngine.AddEffect(GDVars.effectScratch.other, 52, minutes, 12, False);
  end;
end;

procedure PrimeEffHndlr;
begin
  CharHlp.PrimeCharHlp;
  ClassCal.PrimeClassCal;
  Debug.PrimeDebug;
  FxEngine.PrimeFxEngine;
end;

procedure NullifyAttack(effectId: Byte);
begin
  if (effectId = 0) or (GDVars.currentEffectId = effectId) then begin
    GDVars.currentDamage := 0;
    GDVars.currentEffectId := 0
  end
end;

function AddEffectIfNoLock(var creature; effectId, strength: Byte; minutes: Word): Boolean;
begin
  if GDVars.effectBusy <> 0 then
    AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(Pointer(creature), effectId, minutes, strength, True)
  end
end;

procedure EffHelpless(var creature; handlerData: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
begin
  done := CharHlp.EndActions(Pointer(creature))
end;

procedure AddRollBonus(var creature; handlerData: Pointer; removed: Boolean);
begin
  Inc(GDVars.saveRoll);
  Inc(GDVars.gAttackRoll)
end;

procedure EffBless(var creature; handlerData: Pointer; removed: Boolean);
begin
  Inc(GDVars.effectScratch.morale, 5);
  Inc(GDVars.gAttackRoll);
end;

procedure EffCurse(var creature; handlerData: Pointer; removed: Boolean);
begin
  if GDVars.effectScratch.morale < 5 then
    GDVars.effectScratch.morale := 0
  else
    Dec(GDVars.effectScratch.morale, 5);
  Dec(GDVars.gAttackRoll)
end;

procedure EffSticksToSnakes(var creature; handlerData: Pointer; removed: Boolean);
var
  penalty: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
begin
  penalty := Types.PCharRecord(Pointer(creature))^.curAtt[1] + Types.PCharRecord(Pointer(creature))^.curAtt[2];
  if Types.PEffectRec(handlerData)^.strength > penalty then
    Dec(Types.PEffectRec(handlerData)^.strength, penalty)
  else
    FxEngine.RemoveEffect(Pointer(creature), 3, nil);
  CharHlp.PrintNameStringAnim(Pointer(creature), 1, 'is fighting with snakes');
  CharHlp.ClearMessageWindow;
  done := CharHlp.EndActions(Pointer(creature))
end;

procedure EffSetAttackDamage(var creature; handlerData: Pointer; removed: Boolean);
var
  target: Pointer;
  relation: Byte;
  itemPlus: Byte;
begin
  Debug.PrintDebug('bad news', 0, 0, 0);
  if Types.PCharRecord(Pointer(creature))^.equipped[0] <> nil then
    itemPlus := Types.PCharRecord(Pointer(creature))^.equipped[0]^.plus;
  target := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
  relation := CharHlp.CalcDistance(Pointer(creature), target);
  Types.PCharRecord(Pointer(creature))^.thac0Adj := Types.PCharRecord(Pointer(creature))^.thac0Base;
  if relation < 2 then begin
    GDVars.currentDamage := FxEngine.RollDamageDice(1,
                                                      6) + CharHlp.StrDamageAdjust(Pointer(creature)) + 2 +
                                                        itemPlus;
    Types.PCharRecord(Pointer(creature))^.thac0Adj :=
      CharHlp.StrToHitAdjust(Pointer(creature)) + Types.PCharRecord(Pointer(creature))^.thac0Adj
  end else begin
    GDVars.currentDamage := FxEngine.RollDamageDice(1, 4) + 1 + itemPlus;
    Types.PCharRecord(Pointer(creature))^.thac0Adj :=
      CharHlp.DexMissileAdjust(Pointer(creature)) + Types.PCharRecord(Pointer(creature))^.thac0Adj
  end
end;

procedure EffProtEvil(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (Types.PCharRecord(GDVars.curChar)^.alignment = 2) or (Types.PCharRecord(GDVars.curChar)^.alignment = 5) or
      (Types.PCharRecord(GDVars.curChar)^.alignment = 8) then begin
    Inc(GDVars.saveRoll, 2);
    Dec(GDVars.gAttackRoll, 2)
  end
end;

procedure EffProtGood(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (Types.PCharRecord(GDVars.curChar)^.alignment = 0) or (Types.PCharRecord(GDVars.curChar)^.alignment = 3) or
      (Types.PCharRecord(GDVars.curChar)^.alignment = 6) then begin
    Inc(GDVars.saveRoll, 2);
    Dec(GDVars.gAttackRoll, 2)
  end
end;

procedure EffResistCold(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $02) <> 0 then begin
    GDVars.currentDamage := GDVars.currentDamage div 2;
    Inc(GDVars.saveRoll, 3)
  end
end;

procedure EffCharm(var creature; handlerData: Pointer; removed: Boolean);
begin
  if removed then begin
    Types.PCharRecord(Pointer(creature))^.hostile := (Types.PEffectRec(handlerData)^.strength and $40) div 64;
    if Types.PCharRecord(Pointer(creature))^.npc = $B3 then begin
      Types.PCharRecord(Pointer(creature))^.npc := 0;
      Types.PCharRecord(Pointer(creature))^.quickFight := 0
    end
  end else begin
    if (Types.PEffectRec(handlerData)^.strength and $20) = 0 then begin
      Types.PEffectRec(handlerData)^.strength :=
        Types.PEffectRec(handlerData)^.strength + $20 + (Types.PCharRecord(Pointer(creature))^.hostile * 64);
      Types.PCharRecord(Pointer(creature))^.hostile := Types.PEffectRec(handlerData)^.strength div 128;
      Types.PCharRecord(Pointer(creature))^.quickFight := 1;
      if Types.PCharRecord(Pointer(creature))^.npc <= $7F then
        Types.PCharRecord(Pointer(creature))^.npc := $B3;
      Types.PCharRecord(Pointer(creature))^.combatAddr^.target := nil;
      CharHlp.CountTeams
    end;
    GDVars.effectScratch.morale := 100
  end
end;

procedure EffStrengthBonus(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffReviveAsMad(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Types.PCharRecord(Pointer(creature))^.status <> C_Status.OKAY then begin
    Types.PCharRecord(Pointer(creature))^.status := C_Status.OKAY;
    Types.PCharRecord(Pointer(creature))^.inPlay := 1;
    if FxEngine.ReviveDeadCreature(Pointer(creature), 20, 'goes mad!') then
    begin
      FxEngine.AddEffect(Pointer(creature), C_Effect.ANIMATED, 0, 255, False);
      FxEngine.AddEffect(Pointer(creature), 48, 0, 255, False);
      FxEngine.AddEffect(Pointer(creature), 57, 0, 255, False);
      FxEngine.AddEffect(Pointer(creature), 58, 6, 255, True);
      FxEngine.RemoveEffect(Pointer(creature), 13, handlerData);
      FillChar(Types.PCharRecord(Pointer(creature))^.memorized, 58, 0)
    end
  end
end;

procedure EffFriends(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffSlowPoisonHit(var creature; handlerData: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, C_Effect.POISON_DAMAGE, Types.PEffectRec(handlerData)^.strength, 10) and
      (Types.PCharRecord(Pointer(creature))^.hpCur > 1) then begin
    GDVars.elementMask := 0;
    FxEngine.InflictNonWeaponDamage(Pointer(creature), 1, 0, False);
    if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
      CharHlp.DisplayParty(GDVars.curChar)
  end
end;

procedure EffReadMagic(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffShield(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Types.PCharRecord(Pointer(creature))^.acCur[0] < 57 then
    Types.PCharRecord(Pointer(creature))^.acCur[0] := 57;
  Inc(GDVars.saveRoll);
  if GDVars.currentSpell = 15 then GDVars.currentDamage := 0
end;

procedure EffHalfElfResistance(var creature; handlerData: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 30 then begin
    EffHndlr.NullifyAttack(11);
    EffHndlr.NullifyAttack(53)
  end
end;

procedure EffResistFire(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (not removed) and ((GDVars.elementMask and $01) <> 0) then begin
    GDVars.currentDamage := GDVars.currentDamage div 2;
    Inc(GDVars.saveRoll, 3)
  end
end;

procedure EffSilence(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Types.PCharRecord(Pointer(creature))^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(Pointer(creature), 'is silenced', 10, True);
  Types.PCharRecord(Pointer(creature))^.combatAddr^.itemUseAllowed := 0;
  Types.PCharRecord(Pointer(creature))^.combatAddr^.castOk := 0
end;

procedure EffSlowPoisonEnd(var creature; handlerData: Pointer; removed: Boolean);
var
  effectNode: Pointer;
begin
  if CharHlp.HasEffect(Pointer(creature), C_Effect.POISONED, effectNode) then begin
    FxEngine.KillCreature(Pointer(creature), C_Status.DEAD_STATUS, 'dies from poison');
    FxEngine.RemoveEffect(Pointer(creature), C_Effect.POISONED, nil)
  end;
  GDVars.effectBusy := 1;
  FxEngine.RemoveEffect(Pointer(creature), C_Effect.POISON_DAMAGE, nil);
  GDVars.effectBusy := 0
end;

procedure EffSpiritualHammer(var creature; handlerData: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  found: Boolean;
  savedCurrentChar: Types.PCharRecord;
begin
  item := Types.PCharRecord(Pointer(creature))^.itemsAddr;
  found := False;
  while (item <> nil) and not found do
    if (item^.itemType = 6) and (item^.nameIds[3] = 121) then
      found := True
    else
      item := item^.next;

  if removed and (item <> nil) then
    CharHlp.RemoveItem(Pointer(creature), item);

  if (not removed) and (not found) and (Types.PCharRecord(Pointer(creature))^.itemCount < 16) then begin
    GetMem(item, SizeOf(Types.TItemRec));
    FillChar(item^, SizeOf(Types.TItemRec), 0);
    item^.itemType := 6;
    item^.nameIds[2] := 6;
    item^.nameIds[3] := 121;
    item^.plus := 1;
    item^.effect := 23;
    item^.special := $80;
    CharHlp.AddItemCopy(Pointer(creature), item);
    FreeMem(item, SizeOf(Types.TItemRec));

    item := Types.PCharRecord(Pointer(creature))^.itemsAddr;
    found := False;
    while (item <> nil) and not found do begin
      found := (item^.nameIds[3] = 121) and (item^.itemType = 6);
      item := item^.next
    end;

    savedCurrentChar := GDVars.curChar;
    GDVars.curChar := Types.PCharRecord(Pointer(creature));
    if (item <> nil) and (Types.PCharRecord(Pointer(creature))^.equipped[0] = nil) then begin
      ViewChar.ToggleReadyItem(item);
      item^.equipped := 1
    end;
    GDVars.curChar := savedCurrentChar;
    CharHlp.PrintCreatureMessage(Pointer(creature), 'Gains an item', 10, True)
  end;
  CharHlp.RecalcStats(Pointer(creature))
end;

procedure EffInvisible(var creature; handlerData: Pointer; removed: Boolean);
var effectNode: Pointer;
begin
  if (not removed) and (not CharHlp.HasEffect(GDVars.curChar, 24, effectNode)) then begin
    GDVars.movementFlags[1] := 1;
    Dec(GDVars.gAttackRoll, 4)
  end
end;

procedure EffDwarfHitBonus(var creature; handlerData: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Byte;
begin
  GDVars.effectScratch.other := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
  if (Types.PCharRecord(GDVars.effectScratch.other)^.charType and $80) <> 0 then
    Inc(GDVars.gAttackRoll)
end;

procedure EffMirrorImage(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (FxEngine.RollDice(1, (Types.PEffectRec(handlerData)^.strength div 16) + 1) > 1) and
      ((GDVars.currentSpell <= 0) or (GDVars.multiTarget = 0)) then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(Pointer(creature), 'lost an image', 10, True);
    Dec(Types.PEffectRec(handlerData)^.strength);
    if Types.PEffectRec(handlerData)^.strength = 0 then
      FxEngine.RemoveEffect(Pointer(creature), 28, nil)
  end
end;

procedure EffEnfeeble(var creature; handlerData: Pointer; removed: Boolean);
begin
  GDVars.currentDamage := GDVars.currentDamage - (GDVars.currentDamage div 4)
end;

procedure EffCoughing(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Types.PCharRecord(Pointer(creature))^.combatAddr^.itemUseAllowed <> 0 then
    CharHlp.PrintCreatureMessage(Pointer(creature), 'is coughing', 10, True);
  Types.PCharRecord(Pointer(creature))^.combatAddr^.itemUseAllowed := 0;
  Types.PCharRecord(Pointer(creature))^.combatAddr^.castOk := 0;
  CharHlp.RecalcStats(Pointer(creature));
  if Types.PCharRecord(Pointer(creature))^.acCur[1] > 52 then
    Dec(Types.PCharRecord(Pointer(creature))^.acCur[1], 2)
  else
    Types.PCharRecord(Pointer(creature))^.acCur[1] := 50;
  Types.PCharRecord(Pointer(creature))^.acCur[0] := Types.PCharRecord(Pointer(creature))^.acCur[1];
  if Pointer(creature) = GDVars.curChar then
    CharHlp.CombatPrintCreatureInfo(Pointer(creature))
end;

procedure EffTransformOnDeath(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Types.PCharRecord(Pointer(creature))^.status <> C_Status.OKAY then begin
    Types.PCharRecord(Pointer(creature))^.status := C_Status.OKAY;
    Types.PCharRecord(Pointer(creature))^.inPlay := 1;
    if FxEngine.ReviveDeadCreature(Pointer(creature), 20, 'Arises in a new form') then
    begin
      FxEngine.AddEffect(Pointer(creature), 59, 0, 255, False);
      FxEngine.AddEffect(Pointer(creature), 60, 3, 255, False);
      FxEngine.AddEffect(Pointer(creature), 66, 0, 255, False);
      FxEngine.RemoveEffect(Pointer(creature), C_Effect.ANIMATED, nil);
      FxEngine.RemoveEffect(Pointer(creature), 4, nil);
      FxEngine.RemoveEffect(Pointer(creature), 48, nil);
      FxEngine.RemoveEffect(Pointer(creature), 57, nil);
      FxEngine.RemoveEffect(Pointer(creature), 58, nil)
    end
  end
end;

procedure EffBlind(var creature; handlerData: Pointer; removed: Boolean);
begin
  Dec(GDVars.gAttackRoll, 4);
  Dec(Types.PCharRecord(Pointer(creature))^.acCur[0], 4);
  Dec(Types.PCharRecord(Pointer(creature))^.acCur[1], 4);
  Dec(GDVars.saveRoll, 4)
end;

procedure EffDiseased(var creature; handlerData: Pointer; removed: Boolean);
begin
  FxEngine.CallEffectHandler(43, creature, handlerData, removed);
  FxEngine.CallEffectHandler(44, creature, handlerData, removed)
end;

procedure EffConfusion(var creature; handlerData: Pointer; removed: Boolean);
var
  roll: Byte;
  saved: Boolean;
begin
  roll := FxEngine.RollDice(1, 100);
  case roll of
    1..10:
      begin
        FxEngine.RemoveEffect(Pointer(creature), 35, nil);
        Types.PCharRecord(Pointer(creature))^.combatAddr^.turned := 1;
        Types.PCharRecord(Pointer(creature))^.quickFight := 1;
        if Types.PCharRecord(Pointer(creature))^.npc <= $7F then
          Types.PCharRecord(Pointer(creature))^.npc := $B3;
        Types.PCharRecord(Pointer(creature))^.combatAddr^.target := nil;
        FxEngine.AddEffectWithMessage(Pointer(creature), 111, 10, 0, 1, 1, 0, 'runs away')
      end;
    11..60:
      begin
        CharHlp.PrintNameStringAnim(Pointer(creature), 1, 'is confused');
        CharHlp.ClearMessageWindow;
        EffHndlr.EffHelpless(creature, handlerData, False)
      end;
    61..80:
      begin
        FxEngine.AddEffectWithMessage(Pointer(creature), 77, 1, Types.PCharRecord(Pointer(creature))^.hostile, 1, 1, 0,
                                      'goes berserk');
        FxEngine.CallEffectHandler(77, creature, nil, False)
      end;
    81..100:
      begin
        CharHlp.PrintNameStringAnim(Pointer(creature), 1, 'is enraged');
        CharHlp.ClearMessageWindow
      end
  end;
  saved := FxEngine.RollSavingThrow(Pointer(creature), 4, 254);
  if saved then
    FxEngine.RemoveEffect(Pointer(creature), 35, nil)
end;

procedure EffBestowCurse(var creature; handlerData: Pointer; removed: Boolean);
begin
  Dec(GDVars.gAttackRoll, 4);
  Dec(GDVars.saveRoll, 4);
end;

procedure EffBlinking(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Byte(Types.PCharRecord(Pointer(creature))^.combatAddr^.initiative) = 0 then begin
    GDVars.movementFlags[1] := 1;
    GDVars.gAttackRoll := -1
  end
end;

procedure EffHasted(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (Types.PEffectRec(handlerData)^.strength and $10) = 0 then begin
    Types.PEffectRec(handlerData)^.strength := Integer(Types.PEffectRec(handlerData)^.strength) + $10;
    CharHlp.PrintCreatureMessage(Pointer(creature), 'ages', 10, True);
    Inc(Types.PCharRecord(Pointer(creature))^.age)
  end;
  GDVars.moveAttackMultiplier := GDVars.moveAttackMultiplier * 2
end;

procedure NoopEffHndlrB;
begin
end;

procedure EffClearStinkingCloud(var creature; handlerData: Pointer; removed: Boolean);
var
  cloudCursor: Types.PCloudNode;
  node: Types.PCloudNode;
  other: Types.PCloudNode;
  found: Byte;
  slotId: Byte;
  i: Byte;
  cellX: Byte;
  cellY: Byte;
begin
  slotId := Types.PEffectRec(handlerData)^.strength div 16;
  found := 0;
  node := GDVars.cloudHead;
  while (node <> nil) and (found = 0) do
    if (node^.owner = Pointer(creature)) and (node^.instanceId = slotId) then
      found := 1
    else
      node := node^.next;
  if found = 0 then Exit;

  CharHlp.PrintBottomLine('The air clears a little...');
  for i := 1 to 4 do
    if node^.activeCells[i] <> 0 then begin
      cellX := node^.x + GDConsts.dirDeltaX[GDConsts.cloudDirs[i]];
      cellY := node^.y + GDConsts.dirDeltaY[GDConsts.cloudDirs[i]];
      found := 0;
      for slotId := 1 to GDVars.downedCount do
        if GDVars.downedCreatures[slotId].creature <> nil then
          if GDVars.downedCreatures[slotId].x = cellX then
            if GDVars.downedCreatures[slotId].y = cellY then
              found := 1;
      if found <> 0 then
        GDVars.arena^.cells[cellY, cellX] := C_Terr.TERRAIN_CORPSE
      else
        GDVars.arena^.cells[cellY, cellX] := node^.terrainCells[i]
    end;

  cloudCursor := GDVars.cloudHead;
  if cloudCursor = node then
    GDVars.cloudHead := cloudCursor^.next
  else
    while cloudCursor^.next <> node do
      cloudCursor := cloudCursor^.next;
  cloudCursor^.next := node^.next;
  FreeMem(node, SizeOf(Types.TCloudNode));

  cloudCursor := GDVars.cloudHead;
  while cloudCursor <> nil do begin
    for i := 1 to 4 do
      if cloudCursor^.activeCells[i] <> 0 then
        GDVars.arena^.cells[cloudCursor^.y + GDConsts.dirDeltaY[GDConsts.cloudDirs[i]],
                                    cloudCursor^.x +
                                        GDConsts.dirDeltaX[GDConsts.cloudDirs[i]]] := C_Terr.TERRAIN_STINKING_CLOUD;
    cloudCursor := cloudCursor^.next
  end;

  other := GDVars.acidPoolHead;
  while other <> nil do begin
    GDVars.arena^.cells[other^.y, other^.x] := C_Terr.TERRAIN_ACID_POOL;
    other := other^.next
  end
end;

procedure AvoidMissile(var creature; chance: Byte);
begin
  if (GDVars.curChar^.equipped[0] <> nil) and (CharHlp.CalcDistance(GDVars.curChar, Pointer(creature)) > 1) and
      (FxEngine.RollDice(1, 100) <= chance) then begin
    CharHlp.PrintCreatureMessage(Pointer(creature), 'Avoids it', 10, True);
    GDVars.currentDamage := 0;
    GDVars.gAttackRoll := -1;
    Dec(GDVars.hitsMade[1])
  end
end;

function FindDamagingWeapon(creature: Types.PCharRecord): Types.PItemRec;
var
  item: Types.PItemRec;
  found: Boolean;
begin
  item := nil;
  if creature^.equipped[0] <> nil then begin
    found := CharHlp.FindDamagingRangedWeapon(creature, item);
    if (not found) or (item = nil) then item := creature^.equipped[0]
  end;
  FindDamagingWeapon := item
end;

procedure EffProtNormalMissiles(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (EffHndlr.FindDamagingWeapon(GDVars.curChar) <> nil) and
      (EffHndlr.FindDamagingWeapon(GDVars.curChar)^.plus = 0) then EffHndlr.AvoidMissile(creature, 100)
end;

procedure EffSlow(var creature; handlerData: Pointer; removed: Boolean);
begin
  GDVars.moveAttackMultiplier := GDVars.moveAttackMultiplier div 2;
end;

procedure EffDiseaseStrength(var creature; handlerData: Pointer; removed: Boolean);
var
  effectNode: Pointer;
begin
  if EffHndlr.AddEffectIfNoLock(creature, 43, Types.PEffectRec(handlerData)^.strength, 60) then
    if Types.PCharRecord(Pointer(creature))^.stats[C_Stat.STRENGTH].cur > 3 then begin
      CharHlp.PrintCreatureMessage(Pointer(creature), 'is weakened', 10, True);
      Dec(Types.PCharRecord(Pointer(creature))^.stats[C_Stat.STRENGTH].cur)
    end else if not CharHlp.HasEffect(Pointer(creature), 31, effectNode) then
      FxEngine.AddEffect(Pointer(creature), 31, 0, 255, False)
end;

procedure EffDiseaseHitPoints(var creature; handlerData: Pointer; removed: Boolean);
var
  effectNode: Pointer;
begin
  if EffHndlr.AddEffectIfNoLock(creature, 44, Types.PEffectRec(handlerData)^.strength, 10) then
    if Types.PCharRecord(Pointer(creature))^.hpCur > 1 then begin
      GDVars.elementMask := 0;
      FxEngine.InflictNonWeaponDamage(Pointer(creature), 1, 0, False);
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then CharHlp.DisplayParty(GDVars.curChar)
    end else if not CharHlp.HasEffect(Pointer(creature), 31, effectNode) then
      FxEngine.AddEffect(Pointer(creature), 31, 0, 255, False)
end;

procedure EffDwarfGiantDefense(var creature; handlerData: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Byte;
begin
  if (GDVars.curChar^.charType and $04) <> 0 then Dec(GDVars.gAttackRoll, 4)
end;

procedure EffImmolate(var creature; handlerData: Pointer; removed: Boolean);
var
  i: Byte;
  list: array[1..8] of Byte;
  nearbyCount: Byte;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                          CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 1, 255,
                          CbtMap.GetIconSize(Types.PCharRecord(Pointer(creature))), GDVars.arena);
  CharHlp.PrintCreatureMessage(Pointer(creature), 'immolates', 10, True);
  nearbyCount := GDVars.targetCount - 1;
  for i := 2 to GDVars.targetCount do
    list[i - 1] := GDVars.targetList[i].creatureIndex;
  for i := 1 to nearbyCount do
    if GDVars.creatureArr[list[i]]^.inPlay <> 0 then
      FxEngine.InflictNonWeaponDamage(GDVars.creatureArr[list[i]], FxEngine.RollDamageDice(1, 6), 0, False)
end;

procedure EffPrayer(var creature; handlerData: Pointer; removed: Boolean);
var side: Byte;
begin
  side := (Types.PEffectRec(handlerData)^.strength and $10) div 16;
  if Byte(Types.PCharRecord(Pointer(creature))^.hostile) = side then
    EffHndlr.AddRollBonus(creature, handlerData, removed)
  else begin
    Dec(GDVars.gAttackRoll);
    Dec(GDVars.saveRoll)
  end
end;

procedure EffFireVulnerable(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $02) <> 0 then
    Inc(GDVars.saveRoll, 2)
  else if ((GDVars.elementMask and $01) <> 0) and (not GDVars.saveResult) then
    GDVars.currentDamage := GDVars.currentDamage shl 1
end;

procedure EffColdVulnerable(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $01) <> 0 then
    Inc(GDVars.saveRoll, 2)
  else if ((GDVars.elementMask and $02) <> 0) and (GDVars.recentlySaved = 0) then
    GDVars.currentDamage := GDVars.currentDamage shl 1
end;

procedure EffPoisoned(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffRenewInvisibility(var creature; handlerData: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(Pointer(creature), 25, 1, 12, False)
end;

procedure EffCombatBonus(var creature; handlerData: Pointer; removed: Boolean);
begin
  Inc(GDVars.gAttackRoll, 2);
  Inc(Types.PCharRecord(Pointer(creature))^.acCur[0], 2);
  Inc(Types.PCharRecord(Pointer(creature))^.acCur[1], 2)
end;

procedure EffEndTransformation(var creature; handlerData: Pointer; removed: Boolean);
begin
  if removed then begin
    FxEngine.AddEffect(Pointer(creature), 59, 0, 255, False);
    FxEngine.AddEffect(Pointer(creature), 60, 3, 255, True);
    FxEngine.RemoveEffect(Pointer(creature), 4, nil);
    FxEngine.RemoveEffect(Pointer(creature), C_Effect.ANIMATED, nil);
    FxEngine.RemoveEffect(Pointer(creature), 48, nil);
    FxEngine.RemoveEffect(Pointer(creature), 57, nil)
  end
end;

procedure EffCancelDamage(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(0);
  GDVars.currentDamage := 0
end;

procedure EffExplodeOnRemoval(var creature; handlerData: Pointer; removed: Boolean);
var
  nearbyCount: Byte;
  list: array[1..8] of Byte;
begin
  if removed then begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                            CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 1, 255,
                            CbtMap.GetIconSize(Types.PCharRecord(Pointer(creature))), GDVars.arena);
    FxEngine.KillCreature(Pointer(creature), C_Status.GONE, 'explodes!');
    nearbyCount := GDVars.targetCount - 1;
    for GDVars.scratchIndex := 2 to GDVars.targetCount do
      list[GDVars.scratchIndex - 1] := GDVars.targetList[GDVars.scratchIndex].creatureIndex;
    for GDVars.scratchIndex := 1 to nearbyCount do
      if GDVars.creatureArr[list[GDVars.scratchIndex]]^.inPlay <> 0 then begin
        FxEngine.InflictNonWeaponDamage(GDVars.creatureArr[list[GDVars.scratchIndex]], FxEngine.RollDamageDice(3, 6), 0,
                                        False);
        if not FxEngine.RollSavingThrow(GDVars.creatureArr[list[GDVars.scratchIndex]], 4, 0) then begin
          CharHlp.PrintCreatureMessage(GDVars.creatureArr[list[GDVars.scratchIndex]], 'is stunned', 10, True);
          FxEngine.AddEffect(GDVars.creatureArr[list[GDVars.scratchIndex]], 106, 0, 255, False)
        end
      end;
    FxEngine.ProcessExplodingCreatures
  end
end;

procedure EffRingFireRes(var creature; handlerData: Pointer; removed: Boolean);
var i: Byte;
begin
  if (GDVars.elementMask and $01) <> 0 then begin
    for i := 1 to GDVars.diceCount do begin
      Dec(GDVars.currentDamage, 2);
      if GDVars.currentDamage < GDVars.diceCount then GDVars.currentDamage := GDVars.diceCount
    end;
    Inc(GDVars.saveRoll, 4);
    if (GDVars.elementMask and $08) = 0 then EffHndlr.NullifyAttack(0)
  end
end;

procedure EffConRegeneration(var creature; handlerData: Pointer; removed: Boolean);
begin
  if EffHndlr.AddEffectIfNoLock(creature, 62, Types.PEffectRec(handlerData)^.strength, 60) then
    if FxEngine.RestoreHitPoints(Pointer(creature), 1, True) then
      CharHlp.AnnounceHealStatus(Pointer(creature))
end;

procedure EffMinorGlobe(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (GDVars.currentSpell > 0) and (GDConsts.spellTbl[GDVars.currentSpell].level < 4) then
    EffHndlr.NullifyAttack(0)
end;

procedure PoisonTarget(var creature; saveMod: ShortInt);
var
  effectNode: Pointer;
begin
  GDVars.effectScratch.other := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
  if CharHlp.HasEffect(GDVars.effectScratch.other, 116, effectNode) then
    if saveMod < 0 then
      saveMod := 0
    else
      Inc(saveMod, Types.PEffectRec(effectNode)^.strength);
  if not FxEngine.RollSavingThrow(GDVars.effectScratch.other, 0, saveMod) then begin
    CharHlp.PrintCreatureMessage(GDVars.effectScratch.other, 'is Poisoned', 10, False);
    TextRend.pauseOnly;
    FxEngine.AddEffect(GDVars.effectScratch.other, C_Effect.POISONED, 0, 255, False);
    FxEngine.KillCreature(GDVars.effectScratch.other, C_Status.DEAD_STATUS, 'is killed')
  end
end;

procedure EffPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, 0)
end;

procedure EffWeakPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, 4)
end;

procedure EffZapNearbyEnemy(var creature; handlerData: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  turnDone: Boolean;
begin
  target := nil;
  Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                          CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 1, 255,
                          CbtMap.GetIconSize(Types.PCharRecord(Pointer(creature))), GDVars.arena);
  GDVars.scratchFlag := 0;
  GDVars.scratchIndex := 2;
  repeat
  begin
    if GDVars.scratchIndex <= GDVars.targetCount then
      if GDVars.creatureArr[GDVars.targetList[GDVars.scratchIndex].creatureIndex] <> nil then
        if Byte(GDVars.creatureArr[GDVars.targetList[GDVars.scratchIndex].creatureIndex]^.hostile) <>
            Byte(Types.PCharRecord(Pointer(creature))^.hostile) then begin
          target := GDVars.creatureArr[GDVars.targetList[GDVars.scratchIndex].creatureIndex];
          GDVars.scratchFlag := 1
        end;
    Inc(GDVars.scratchIndex)
  end
  until (GDVars.scratchFlag <> 0) or (GDVars.scratchIndex > GDVars.targetCount);
  if target <> nil then begin
    CharHlp.PrintCreatureMessage(target, 'gets zapped!', 10, True);
    FxEngine.InflictNonWeaponDamage(target, FxEngine.RollDamageDice(2, 6), 0, False);
    turnDone := CharHlp.EndActions(Pointer(creature))
  end
end;

procedure EffDisarmAttacker(var creature; handlerData: Pointer; removed: Boolean);
var
  item: Types.PItemRec;
  node: Types.PBankNode;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (GDVars.curChar^.stats[C_Stat.DEXTERITY].cur - 3 <= FxEngine.RollDice(1, 20)) and (GDVars.currentSpell = 0) and
      (item <> nil) and (item^.cursed = 0) and (GDVars.explosionBusy = 0) and
      (CharHlp.CalcDistance(GDVars.curChar, Pointer(creature)) = 1) then begin
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'loses his weapon', 10, True);
    node := GDVars.bankHead;
    if (item^.itemType = 6) and (item^.nameIds[3] = 121) then Exit;
    ViewChar.ToggleReadyItem(item);
    if node = nil then begin
      GetMem(GDVars.bankHead, SizeOf(Types.TBankNode));
      GDVars.bankHead^.item := item^;
      GDVars.bankHead^.owner := GDVars.curChar;
      GDVars.bankHead^.next := nil
    end else begin
      while node^.next <> nil do node := node^.next;
      GetMem(node^.next, SizeOf(Types.TBankNode));
      node := node^.next;
      node^.item := item^;
      node^.owner := GDVars.curChar;
      node^.next := nil
    end;
    CharHlp.RemoveItem(GDVars.curChar, item);
    GDVars.curChar^.equipped[0] := nil;
    CharHlp.CombatPrintCreatureInfo(GDVars.curChar)
  end
end;

procedure EffQueueExplosion(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Types.PCharRecord(Pointer(creature))^.inPlay = 0 then begin
    Types.PCharRecord(Pointer(creature))^.status := C_Status.EXPLODED;
    Inc(GDVars.explosionCount);
    if GDVars.explosionCount < 1 then GDVars.explosionCount := 1;
    if GDVars.explosionCount <= 20 then
      GDVars.explosionQueue[GDVars.explosionCount] := Types.PCharRecord(Pointer(creature))
    else
      GDVars.explosionCount := 20;
    FxEngine.RemoveEffect(Pointer(creature), C_Effect.FEEBLEMINDED, nil)
  end
end;

procedure EffParalyzingHit(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.ParalyzeTarget(creature, 100, 0);
end;

procedure EffCreateAcidPool(var creature; handlerData: Pointer; removed: Boolean);
var
  node: Types.PCloudNode;
  scan: Types.PCloudNode;
  i: Byte;
  ownedPoolCount: Byte;
  terrain: Byte;
  neighborDirections: array[1..5] of Byte;
begin
  if (Types.PCharRecord(Pointer(creature))^.hpCur <= 0) or (Types.PCharRecord(Pointer(creature))^.inPlay = 0) then begin
    ownedPoolCount := 0;
    node := GDVars.acidPoolHead;
    if GDVars.acidPoolHead = nil then begin
      GetMem(GDVars.acidPoolHead, SizeOf(Types.TCloudNode));
      node := GDVars.acidPoolHead
    end else begin
      while node^.next <> nil do begin
        if node^.owner = Pointer(creature) then Inc(ownedPoolCount);
        node := node^.next
      end;
      GetMem(node^.next, SizeOf(Types.TCloudNode));
      node := node^.next
    end;
    FxEngine.AddEffect(Pointer(creature), 80, FxEngine.RollDice(1, 6), ownedPoolCount, True);
    FillChar(node^, SizeOf(Types.TCloudNode), 0);
    node^.next := nil;
    node^.owner := Pointer(creature);
    node^.instanceId := ownedPoolCount;
    node^.x := CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature)));
    node^.y := CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature)));
    CbtMap.GetArenaContents(node^.x, node^.y, neighborDirections[1], terrain);
    if terrain = C_Terr.TERRAIN_STINKING_CLOUD then begin
      scan := GDVars.cloudHead;
      while scan <> nil do begin
        for i := 1 to 4 do
          if scan^.activeCells[i] <> 0 then
            if (scan^.x + GDConsts.dirDeltaX[GDConsts.cloudDirs[i]] = node^.x) and
                (scan^.y + GDConsts.dirDeltaY[GDConsts.cloudDirs[i]] = node^.y) and
                (scan^.terrainCells[i] <> C_Terr.TERRAIN_STINKING_CLOUD) then
              terrain := scan^.terrainCells[i];
        scan := scan^.next
      end
    end else if terrain = C_Terr.TERRAIN_CORPSE then begin
      for i := 1 to GDVars.downedCount do
        if (GDVars.downedCreatures[i].x = GDVars.targetX + GDConsts.dirDeltaX[neighborDirections[3]]) and
            (GDVars.downedCreatures[i].y = GDVars.targetY + GDConsts.dirDeltaY[neighborDirections[3]]) then
          terrain := GDVars.downedCreatures[i].terrain
    end;
    node^.terrainCells[1] := terrain;
    GDVars.arena^.cells[node^.y, node^.x] := C_Terr.TERRAIN_ACID_POOL;
    CbtMap.ScrollView(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                      CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 255, 8);
    CharHlp.PrintCreatureMessage(Pointer(creature), 'dissolves into acid!', 10, False)
  end
end;

procedure EffReflectSpell(var creature; handlerData: Pointer; removed: Boolean);
var i: Byte;
begin
  if ((FxEngine.RollDice(1, 10) = 1) and (GDConsts.spellTbl[GDVars.currentSpell].area < 8)) or
      (GDConsts.spellTbl[GDVars.currentSpell].area > 14) then begin
    CharHlp.PrintCreatureMessage(Pointer(creature), 'reflects the spell', 10, False);
    GDVars.targetX := CbtMap.CombatCellX(Types.PCharRecord(GDVars.curChar));
    GDVars.targetY := CbtMap.CombatCellY(Types.PCharRecord(GDVars.curChar));
    for i := 1 to GDVars.spellTargetCount do
      if GDVars.spellTargets[i] = Pointer(creature) then
        GDVars.spellTargets[i] := GDVars.curChar;
    CharHlp.BuildIconFacings(18);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                                    CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))),
                                    CbtMap.CombatCellX(Types.PCharRecord(GDVars.spellTargets[1])),
                                    CbtMap.CombatCellY(Types.PCharRecord(GDVars.spellTargets[1])), 1, 30);
    Pointer(creature) := GDVars.curChar
  end
end;

procedure EffDragonFear(var creature; handlerData: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
  effectNode: Pointer;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                          CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 1, 255,
                          CbtMap.GetIconSize(Types.PCharRecord(Pointer(creature))), GDVars.arena);
  for GDVars.scratchIndex := 2 to GDVars.targetCount do begin
    target := GDVars.creatureArr[GDVars.targetList[GDVars.scratchIndex].creatureIndex];
    if Byte(target^.hostile) <> Byte(Types.PCharRecord(Pointer(creature))^.hostile) then
      if not CharHlp.HasEffect(target, 92, effectNode) then
        if not FxEngine.RollSavingThrow(target, 4, 0) then begin
          FxEngine.AddEffectWithMessage(target, 111, 0, 0, 1, 1, 0, 'is terrified');
          if CharHlp.HasEffect(target, 111, effectNode) then begin
            Types.PCharRecord(target)^.quickFight := 1;
            if Types.PCharRecord(target)^.npc <= $7F then
              Types.PCharRecord(target)^.npc := $B3;
            Types.PCharRecord(target)^.combatAddr^.target := nil;
            Types.PCharRecord(target)^.combatAddr^.turned := 1
          end
        end
  end
end;

procedure EffImmuneBreath(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $20) > 0 then begin
    EffHndlr.NullifyAttack(0);
    CharHlp.PrintCreatureMessage(Pointer(creature), 'is unaffected', 10, True)
  end
end;

procedure EffRandomDispelMagic(var creature; handlerData: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 20) = 1 then GDVars.spellDispatch[41]
end;

procedure EffDragonSlayer(var creature; handlerData: Pointer; removed: Boolean);
begin
  GDVars.effectScratch.other := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
  if (Types.PCharRecord(GDVars.effectScratch.other)^.targetFlags and $01) <> 0 then begin
    GDVars.currentDamage := FxEngine.RollDice(1, 12) * 3 + 4 + CharHlp.StrDamageAdjust(Pointer(creature));
    Inc(GDVars.gAttackRoll, 2)
  end
end;

procedure EffGateInDeadAllies(var creature; handlerData: Pointer; removed: Boolean);
var
  x: ShortInt;
  y: ShortInt;
  newX: ShortInt;
  newY: ShortInt;
  dir: ShortInt;
  target: Types.PCharRecord;
  walk: Types.PCharRecord;
  done: Boolean;
  revived: Boolean;
  terrain: Byte;
  occupant: Byte;
  slot: Byte;
begin
  if Types.PCharRecord(Pointer(creature))^.hpCur < (Types.PCharRecord(Pointer(creature))^.hpMax div 2) then begin
    walk := GDVars.partyHead;
    target := GDVars.partyHead;
    done := False;
    dir := 0;
    while (target <> nil) and (Byte(target^.hostile) = Byte(Types.PCharRecord(Pointer(creature))^.hostile)) do
      target := target^.next;
    while (walk <> nil) and (walk^.status <> C_Status.REMOVED) do
      walk := walk^.next;
    repeat
      if dir > 7 then begin
        if target = nil then begin
          target := Pointer(creature);
          done := True
        end else begin
          target := target^.next;
          if Byte(target^.hostile) = Byte(Types.PCharRecord(Pointer(creature))^.hostile) then begin
            done := True;
            target := Pointer(creature)
          end
        end;
        dir := 0
      end;
      if walk = nil then
        done := True
      else begin
        x := CbtMap.CombatCellX(Types.PCharRecord(target));
        y := CbtMap.CombatCellY(Types.PCharRecord(target));
        revived := False;
        repeat
        begin
          newX := x + GDConsts.dirDeltaX[dir];
          newY := y + GDConsts.dirDeltaY[dir];
          if (newX <= 49) and (newX >= 0) and (newY <= 24) and (newY >= 0) then begin
            CbtMap.GetArenaContents(newX, newY, occupant, terrain);
            if (occupant = 0) and (terrain = 23) then begin
              slot := CbtMap.CombatSlot(Types.PCharRecord(walk));
              GDVars.arenaLoc[slot].size := walk^.iconDimensions and $07;
              GDVars.arenaLoc[slot].x := newX;
              GDVars.arenaLoc[slot].y := newY;
              revived := FxEngine.ReviveDeadCreature(walk, walk^.hpMax, 'gates in');
              walk := walk^.next;
              if (walk = nil) or (walk^.status <> C_Status.REMOVED) then
                done := True
            end;
            Inc(dir)
          end;
        end
        until revived or (dir > 7)
      end
    until (done <> False) or (target = Pointer(creature));
    FxEngine.RemoveEffect(Pointer(creature), 76, nil)
  end
end;

procedure EffBerserk(var creature; handlerData: Pointer; removed: Boolean);
begin
  if not removed then begin
    Types.PCharRecord(Pointer(creature))^.quickFight := 1;
    if (Types.PCharRecord(Pointer(creature))^.npc <= $7F) or (Types.PCharRecord(Pointer(creature))^.npc = $B3) then
      Types.PCharRecord(Pointer(creature))^.npc := $B3
    else
      Types.PCharRecord(Pointer(creature))^.npc := $B2;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      Types.PCharRecord(Pointer(creature))^.combatAddr^.target := nil;
      Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                              CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 255, 255,
                              CbtMap.GetIconSize(Types.PCharRecord(Pointer(creature))), GDVars.arena);
      Types.PCharRecord(Pointer(creature))^.combatAddr^.target :=
        GDVars.creatureArr[GDVars.targetList[2].creatureIndex];
      Types.PCharRecord(Pointer(creature))^.combatAddr^.castOk := 0;
      Byte(Types.PCharRecord(Pointer(creature))^.hostile) :=
        Types.PCharRecord(Types.PCharRecord(Pointer(creature))^.combatAddr^.target)^.hostile xor 1;
      CharHlp.PrintCreatureMessage(Pointer(creature), 'goes berserk', 10, True)
    end
  end else begin
    if Types.PCharRecord(Pointer(creature))^.npc = $B3 then begin
      Types.PCharRecord(Pointer(creature))^.npc := 0;
      Types.PCharRecord(Pointer(creature))^.quickFight := 0
    end;
    Byte(Types.PCharRecord(Pointer(creature))^.hostile) := C_Side.PLAYER
  end
end;

procedure EffEvilStench(var creature; handlerData: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
  effectNode: Pointer;
begin
  CharHlp.PrintCreatureMessage(Pointer(creature), 'emits an evil stench', 10, False);
  Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                          CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 1, 255,
                          CbtMap.GetIconSize(Types.PCharRecord(Pointer(creature))), GDVars.arena);
  for GDVars.scratchIndex := 2 to GDVars.targetCount do begin
    target := GDVars.creatureArr[GDVars.targetList[GDVars.scratchIndex].creatureIndex];
    if Byte(target^.hostile) <> Byte(Types.PCharRecord(Pointer(creature))^.hostile) then
      if not FxEngine.RollSavingThrow(target, 4, 0) then
        if not CharHlp.HasEffect(target, 118, effectNode) then begin
          CharHlp.PrintNameStringAnim(target, 1, 'is affected');
          FxEngine.AddEffect(Pointer(creature), 118, 0, 255, False)
        end
  end
end;

procedure EffRemoveAcidPool(var creature; handlerData: Pointer; removed: Boolean);
var
  other: Types.PCloudNode;
  node: Types.PCloudNode;
  cloudCursor: Types.PCloudNode;
  found: Byte;
  slotId: Byte;
  i: Byte;
begin
  slotId := Types.PEffectRec(handlerData)^.strength;
  found := 0;
  node := GDVars.acidPoolHead;
  while (node <> nil) and (found = 0) do
    if (node^.owner = Pointer(creature)) and (node^.instanceId = slotId) then
      found := 1
    else
      node := node^.next;
  if found = 0 then Exit;

  found := 0;
  CharHlp.PrintBottomLine('The acid drains away..');
  for slotId := 1 to GDVars.downedCount do
    if GDVars.downedCreatures[slotId].creature <> nil then
      if GDVars.downedCreatures[slotId].x = node^.x then
        if GDVars.downedCreatures[slotId].y = node^.y then
          found := 1;
  if found <> 0 then
    GDVars.arena^.cells[node^.y, node^.x] := C_Terr.TERRAIN_CORPSE
  else
    GDVars.arena^.cells[node^.y, node^.x] := node^.terrainCells[1];

  other := GDVars.acidPoolHead;
  if other = node then
    GDVars.acidPoolHead := other^.next
  else
    while other^.next <> node do
      other := other^.next;
  other^.next := node^.next;

  cloudCursor := GDVars.cloudHead;
  while cloudCursor <> nil do begin
    for i := 1 to 4 do
      if cloudCursor^.activeCells[i] <> 0 then
        GDVars.arena^.cells[cloudCursor^.y + GDConsts.dirDeltaY[GDConsts.cloudDirs[i]],
                                    cloudCursor^.x +
                                        GDConsts.dirDeltaX[GDConsts.cloudDirs[i]]] := C_Terr.TERRAIN_STINKING_CLOUD;
    cloudCursor := cloudCursor^.next
  end;
  FreeMem(node, SizeOf(Types.TCloudNode));

  cloudCursor := GDVars.cloudHead;
  while cloudCursor <> nil do begin
    for i := 1 to 4 do
      if cloudCursor^.activeCells[i] <> 0 then
        GDVars.arena^.cells[cloudCursor^.y + GDConsts.dirDeltaY[GDConsts.cloudDirs[i]],
                                    cloudCursor^.x +
                                        GDConsts.dirDeltaX[GDConsts.cloudDirs[i]]] := C_Terr.TERRAIN_STINKING_CLOUD;
    cloudCursor := cloudCursor^.next
  end;
  other := GDVars.acidPoolHead;
  while other <> nil do begin
    GDVars.arena^.cells[other^.y, other^.x] := C_Terr.TERRAIN_ACID_POOL;
    other := other^.next
  end
end;

procedure EffParalyzingStrike(var creature; handlerData: Pointer; removed: Boolean);
begin
  GDVars.currentDamage := 0;
  EffHndlr.ParalyzeTarget(creature, 100, 0)
end;

procedure EffFrightenAllEnemies(var creature; handlerData: Pointer; removed: Boolean);
var
  target: Types.PCharRecord;
  effectNode: Pointer;
begin
  effectNode := nil;
  target := GDVars.partyHead;
  while target <> nil do begin
    if Byte(target^.hostile) <> Byte(Types.PCharRecord(Pointer(creature))^.hostile) then
      if not CharHlp.HasEffect(target, 92, effectNode) then
        if not CharHlp.HasEffect(target, 111, effectNode) then
          if not CharHlp.HasEffect(target, 119, effectNode) then
            case target^.levelHighest of
              0..3:
              begin
                FxEngine.AddEffectWithMessage(target, 111, 0, 255, 1, 1, 0, 'is terrified');
                if CharHlp.HasEffect(target, 111, effectNode) then begin
                  Types.PCharRecord(target)^.quickFight := 1;
                  if Types.PCharRecord(target)^.npc <= $7F then
                    Types.PCharRecord(target)^.npc := $B3;
                  Types.PCharRecord(target)^.combatAddr^.target := nil;
                  Types.PCharRecord(target)^.combatAddr^.turned := 1
                end
              end else
              if not FxEngine.RollSavingThrow(target, 4, 0) then
                FxEngine.AddEffectWithMessage(target, 119, 0, 255, 1, 1, 0, 'is afraid')
            end;
    target := target^.next
  end
end;

procedure EffStrongPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, -2)
end;

procedure EffSlightPoisonAttack(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.PoisonTarget(creature, 1)
end;

procedure EffGhoulPara(var creature; handlerData: Pointer; removed: Boolean);
begin
  if Types.PCharRecord(Types.PCharRecord(Pointer(creature))^.combatAddr^.target)^.race > C_Race.QUALINESTI_ELF then
    EffHndlr.ParalyzeTarget(creature, 100, 0)
end;

procedure EffDisplaced(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (GDVars.roundNumber = 0) and (GDVars.gAttackRoll = 0) then
    Types.PEffectRec(handlerData)^.strength := Types.PEffectRec(handlerData)^.strength and $0F
  else if (Types.PEffectRec(handlerData)^.strength and $10) = 0 then begin
    GDVars.gAttackRoll := -1;
    Types.PEffectRec(handlerData)^.strength := Types.PEffectRec(handlerData)^.strength or $10
  end
end;

procedure EffTaunted(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffHalfPierceBash(var creature; handlerData: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (item <> nil) and ((GDVars.baseItems[item^.itemType].defenseFlags and $81) <> 0) then
    GDVars.currentDamage := GDVars.currentDamage div 2
end;

procedure EffConSpellSave(var creature; handlerData: Pointer; removed: Boolean);
var bonus: Byte;
begin
  if (GDVars.saveType = 4) or (GDVars.saveType = 2) or (GDVars.saveType = 0) then begin
    case Types.PCharRecord(Pointer(creature))^.stats[C_Stat.CONSTITUTION].cur of
      4..6: bonus := 1;
      7..10: bonus := 2;
      11..13: bonus := 3;
      14..17: bonus := 4;
      18..20: bonus := 5
    end;
    GDVars.saveRoll := GDVars.saveRoll + Word(bonus)
  end
end;

procedure EffElfResistance(var creature; handlerData: Pointer; removed: Boolean);
begin
  if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(53);
    EffHndlr.NullifyAttack(11)
  end
end;

procedure EffImmuneSleepCharm(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(11);
  EffHndlr.NullifyAttack(53)
end;

procedure EffImmuneParalysis(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(52)
end;

procedure EffImmuneCold(var creature; handlerData: Pointer; removed: Boolean);
begin
  if (GDVars.elementMask and $02) <> 0 then EffHndlr.NullifyAttack(0)
end;

procedure EffImmuneParalysisPoison(var creature; handlerData: Pointer; removed: Boolean);
begin
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  EffHndlr.NullifyAttack(52);
  if GDVars.saveType = 0 then GDVars.saveRoll := 100
end;

procedure EffHalfSlashPierce(var creature; handlerData: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if item <> nil then
    if (GDVars.baseItems[item^.itemType].defenseFlags = 0) or
        ((GDVars.baseItems[item^.itemType].defenseFlags and $01) <> 0) then
      GDVars.currentDamage := GDVars.currentDamage div 2
end;

procedure EffHolyWater(var creature; handlerData: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := GDVars.curChar^.equipped[0];
  if (item <> nil) and (item^.itemType = C_Item.HOLY_WATER_VIAL) then
    GDVars.currentDamage := FxEngine.RollDamageDice(1, 6) + 1
end;

procedure EffNoneB(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffNeedMagicWeapon(var creature; handlerData: Pointer; removed: Boolean);
var item: Types.PItemRec;
begin
  item := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (item = nil) or (item^.plus = 0) then
    if (GDVars.curChar^.race < C_Race.MONSTER) or (GDVars.curChar^.levelHighest < 4) then
      GDVars.currentDamage := 0
end;

procedure EffRangerDamageBonus(var creature; handlerData: Pointer; removed: Boolean);
begin
  GDVars.effectScratch.other := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
  if (Types.PCharRecord(GDVars.effectScratch.other)^.charType and $08) <> 0 then
    Inc(GDVars.currentDamage, Types.PCharRecord(Pointer(creature))^.classLevels[C_Class.RANGER])
end;

procedure EffEndActions(var creature; handlerData: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
begin
  done := CharHlp.EndActions(Pointer(creature))
end;

procedure EffConfusedBerserk(var creature; handlerData: Pointer; removed: Boolean);
begin
  if not removed then begin
    Types.PCharRecord(Pointer(creature))^.quickFight := 1;
    if (Types.PCharRecord(Pointer(creature))^.npc <= $7F) or (Types.PCharRecord(Pointer(creature))^.npc = $B3) then
      Types.PCharRecord(Pointer(creature))^.npc := $B3
    else
      Types.PCharRecord(Pointer(creature))^.npc := $B2;
    Types.PCharRecord(Pointer(creature))^.combatAddr^.target := nil;
    Pathing.BuildTargetList(CbtMap.CombatCellX(Types.PCharRecord(Pointer(creature))),
                            CbtMap.CombatCellY(Types.PCharRecord(Pointer(creature))), 255, 255,
                            CbtMap.GetIconSize(Types.PCharRecord(Pointer(creature))), GDVars.arena);
    Types.PCharRecord(Pointer(creature))^.combatAddr^.target := GDVars.creatureArr[GDVars.targetList[2].creatureIndex];
    Byte(Types.PCharRecord(Pointer(creature))^.hostile) :=
      Types.PCharRecord(Types.PCharRecord(Pointer(creature))^.combatAddr^.target)^.hostile xor 1
  end else begin
    if Types.PCharRecord(Pointer(creature))^.npc = $B3 then
      Types.PCharRecord(Pointer(creature))^.npc := 0;
    Byte(Types.PCharRecord(Pointer(creature))^.hostile) := Types.PEffectRec(handlerData)^.strength
  end
end;

procedure EffLastingInvisibility(var creature; handlerData: Pointer; removed: Boolean);
begin
  FxEngine.AddEffect(Pointer(creature), 25, 255, 255, False)
end;

procedure EffNoneC(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffRecalcLevelBucket(var creature; handlerData: Pointer; removed: Boolean);
begin
  if removed then
    Types.PCharRecord(Pointer(creature))^.levelBucket :=
      TNN16(Types.PCharRecord(Pointer(creature))^.classLevels2[C_Class.KNIGHT] *
            ShortInt(ClassCal.EarlierClassActive(Pointer(creature))) +
            Types.PCharRecord(Pointer(creature))^.classLevels[C_Class.KNIGHT] - 1) div 5 + 1
end;

procedure EffFear(var creature; handlerData: Pointer; removed: Boolean);
begin
  if removed then begin
    if Types.PCharRecord(Pointer(creature))^.npc = $B3 then begin
      Types.PCharRecord(Pointer(creature))^.npc := 0;
      Types.PCharRecord(Pointer(creature))^.quickFight := 0
    end;
    Types.PCharRecord(Pointer(creature))^.combatAddr^.turned := 0
  end
end;

procedure EffZapAttacker(var creature; handlerData: Pointer; removed: Boolean);
var
  savedDamage: Byte;
  savedMask: Byte;
begin
  if CharHlp.CalcDistance(GDVars.curChar, Pointer(creature)) < 2 then begin
    savedDamage := GDVars.currentDamage;
    GDVars.currentDamage := GDVars.currentDamage * 2;
    savedMask := GDVars.elementMask;
    GDVars.elementMask := $08;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'gets zapped', 10, True);
    FxEngine.InflictNonWeaponDamage(GDVars.curChar, GDVars.currentDamage, 0, False);
    GDVars.currentDamage := savedDamage;
    GDVars.elementMask := savedMask
  end
end;

procedure EffGiantStrength(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffDragonlance(var creature; handlerData: Pointer; removed: Boolean);
var
  target: Pointer;
begin
  target := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
  if (Types.PCharRecord(target)^.targetFlags and $01) <> 0 then
    GDVars.currentDamage := Types.PCharRecord(Pointer(creature))^.hpCur
end;

procedure EffTypeDamageBonus(var creature; handlerData: Pointer; removed: Boolean);
var
  target: Pointer;
begin
  target := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
  if (Types.PCharRecord(target)^.charType and $20) <> 0 then Inc(GDVars.currentDamage, 3)
end;

procedure EffPoisonResistance(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffDisruption(var creature; handlerData: Pointer; removed: Boolean);
var target: Pointer;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    target := Types.PCharRecord(Pointer(creature))^.combatAddr^.target;
    if (Types.PCharRecord(target)^.charType and $02) <> 0 then
      if Byte(Types.PCharRecord(target)^.levelUndead) <> 0 then
        FxEngine.KillCreature(target, C_Status.GONE, 'is disrupted')
      else
        GDVars.currentDamage := GDVars.currentDamage * 2
  end
end;

procedure EffAttackPenaltyTwo(var creature; handlerData: Pointer; removed: Boolean);
begin
  Dec(GDVars.gAttackRoll, 2);
end;

procedure EffAttackPenaltyOne(var creature; handlerData: Pointer; removed: Boolean);
begin
  Dec(GDVars.gAttackRoll);
end;

procedure EffNone(var creature; handlerData: Pointer; removed: Boolean); begin end;

procedure EffGrantItemEffect(var creature; handlerData: Pointer; removed: Boolean);
var effectNode: Types.PItemRec;
begin
  GDVars.overrideFlag := 0;
  effectNode := handlerData;
  if removed then
    FxEngine.RemoveEffect(Pointer(creature), effectNode^.effect, nil)
  else
    FxEngine.AddEffect(Pointer(creature), effectNode^.effect, 0, 255, True)
end;

procedure InitEffectHandlers;
begin
  GDVars.effectHandlers[1] := EffHndlr.EffBless;
  GDVars.effectHandlers[2] := EffHndlr.EffCurse;
  GDVars.effectHandlers[3] := EffHndlr.EffSticksToSnakes;
  GDVars.effectHandlers[5] := EffHndlr.EffNone;
  GDVars.effectHandlers[7] := EffHndlr.EffSetAttackDamage;
  GDVars.effectHandlers[8] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[9] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[10] := EffHndlr.EffResistCold;
  GDVars.effectHandlers[11] := EffHndlr.EffCharm;
  GDVars.effectHandlers[12] := EffHndlr.EffStrengthBonus;
  GDVars.effectHandlers[13] := EffHndlr.EffReviveAsMad;
  GDVars.effectHandlers[14] := EffHndlr.EffFriends;
  GDVars.effectHandlers[C_Effect.POISON_DAMAGE] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectHandlers[16] := EffHndlr.EffReadMagic;
  GDVars.effectHandlers[17] := EffHndlr.EffShield;
  GDVars.effectHandlers[18] := EffHndlr.EffHalfElfResistance;
  GDVars.effectHandlers[19] := EffHndlr.EffNone;
  GDVars.effectHandlers[20] := EffHndlr.EffResistFire;
  GDVars.effectHandlers[21] := EffHndlr.EffSilence;
  GDVars.effectHandlers[C_Effect.SLOW_POISON] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectHandlers[23] := EffHndlr.EffSpiritualHammer;
  GDVars.effectHandlers[24] := EffHndlr.EffNone;
  GDVars.effectHandlers[25] := EffHndlr.EffInvisible;
  GDVars.effectHandlers[26] := EffHndlr.EffDwarfHitBonus;
  GDVars.effectHandlers[27] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[28] := EffHndlr.EffMirrorImage;
  GDVars.effectHandlers[29] := EffHndlr.EffEnfeeble;
  GDVars.effectHandlers[30] := EffHndlr.EffCoughing;
  GDVars.effectHandlers[31] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[C_Effect.ANIMATED] := EffHndlr.EffTransformOnDeath;
  GDVars.effectHandlers[C_Effect.BLIND] := EffHndlr.EffBlind;
  GDVars.effectHandlers[34] := EffHndlr.EffDiseased;
  GDVars.effectHandlers[35] := EffHndlr.EffConfusion;
  GDVars.effectHandlers[C_Effect.CURSED] := EffHndlr.EffBestowCurse;
  GDVars.effectHandlers[37] := EffHndlr.EffBlinking;
  GDVars.effectHandlers[38] := EffHndlr.EffStrengthBonus;
  GDVars.effectHandlers[C_Effect.HASTED] := EffHndlr.EffHasted;
  GDVars.effectHandlers[40] := EffHndlr.EffClearStinkingCloud;
  GDVars.effectHandlers[41] := EffHndlr.EffProtNormalMissiles;
  GDVars.effectHandlers[C_Effect.SLOWED] := EffHndlr.EffSlow;
  GDVars.effectHandlers[43] := EffHndlr.EffDiseaseStrength;
  GDVars.effectHandlers[44] := EffHndlr.EffDiseaseHitPoints;
  GDVars.effectHandlers[45] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[46] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[47] := EffHndlr.EffDwarfGiantDefense;
  GDVars.effectHandlers[48] := EffHndlr.EffImmolate;
  GDVars.effectHandlers[49] := EffHndlr.EffPrayer;
  GDVars.effectHandlers[50] := EffHndlr.EffFireVulnerable;
  GDVars.effectHandlers[51] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[52] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[53] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[54] := EffHndlr.EffColdVulnerable;
  GDVars.effectHandlers[C_Effect.POISONED] := EffHndlr.EffPoisoned;
  GDVars.effectHandlers[56] := EffHndlr.EffRenewInvisibility;
  GDVars.effectHandlers[57] := EffHndlr.EffCombatBonus;
  GDVars.effectHandlers[58] := EffHndlr.EffEndTransformation;
  GDVars.effectHandlers[59] := EffHndlr.EffCancelDamage;
  GDVars.effectHandlers[60] := EffHndlr.EffExplodeOnRemoval;
  GDVars.effectHandlers[61] := EffHndlr.EffRingFireRes;
  GDVars.effectHandlers[62] := EffHndlr.EffConRegeneration;
  GDVars.effectHandlers[63] := EffHndlr.EffMinorGlobe;
  GDVars.effectHandlers[64] := EffHndlr.EffPoisonAttack;
  GDVars.effectHandlers[65] := EffHndlr.EffWeakPoisonAttack;
  GDVars.effectHandlers[66] := EffHndlr.EffZapNearbyEnemy;
  GDVars.effectHandlers[67] := EffHndlr.EffDisarmAttacker;
  GDVars.effectHandlers[C_Effect.FEEBLEMINDED] := EffHndlr.EffQueueExplosion;
  GDVars.effectHandlers[69] := EffHndlr.EffParalyzingHit;
  GDVars.effectHandlers[70] := EffHndlr.EffCreateAcidPool;
  GDVars.effectHandlers[71] := EffHndlr.EffReflectSpell;
  GDVars.effectHandlers[72] := EffHndlr.EffDragonFear;
  GDVars.effectHandlers[73] := EffHndlr.EffImmuneBreath;
  GDVars.effectHandlers[74] := EffHndlr.EffRandomDispelMagic;
  GDVars.effectHandlers[75] := EffHndlr.EffDragonSlayer;
  GDVars.effectHandlers[76] := EffHndlr.EffGateInDeadAllies;
  GDVars.effectHandlers[77] := EffHndlr.EffBerserk;
  GDVars.effectHandlers[79] := EffHndlr.EffEvilStench;
  GDVars.effectHandlers[80] := EffHndlr.EffRemoveAcidPool;
  GDVars.effectHandlers[81] := EffHndlr.EffParalyzingStrike;
  GDVars.effectHandlers[82] := EffHndlr.EffFrightenAllEnemies;
  GDVars.effectHandlers[86] := EffHndlr.EffStrongPoisonAttack;
  GDVars.effectHandlers[87] := EffHndlr.EffSlightPoisonAttack;
  GDVars.effectHandlers[88] := EffHndlr.EffGhoulPara;
  GDVars.effectHandlers[89] := EffHndlr.EffDisplaced;
  GDVars.effectHandlers[91] := EffHndlr.EffTaunted;
  GDVars.effectHandlers[92] := EffHndlr.EffNone;
  GDVars.effectHandlers[93] := EffHndlr.EffHalfPierceBash;
  GDVars.effectHandlers[94] := EffHndlr.EffConSpellSave;
  GDVars.effectHandlers[95] := EffHndlr.EffElfResistance;
  GDVars.effectHandlers[96] := EffHndlr.EffImmuneSleepCharm;
  GDVars.effectHandlers[97] := EffHndlr.EffImmuneParalysis;
  GDVars.effectHandlers[98] := EffHndlr.EffImmuneCold;
  GDVars.effectHandlers[99] := EffHndlr.EffImmuneParalysisPoison;
  GDVars.effectHandlers[100] := EffHndlr.EffHalfSlashPierce;
  GDVars.effectHandlers[101] := EffHndlr.EffHolyWater;
  GDVars.effectHandlers[102] := EffHndlr.EffNoneB;
  GDVars.effectHandlers[103] := EffHndlr.EffNeedMagicWeapon;
  GDVars.effectHandlers[105] := EffHndlr.EffRangerDamageBonus;
  GDVars.effectHandlers[106] := EffHndlr.EffEndActions;
  GDVars.effectHandlers[107] := EffHndlr.EffConfusedBerserk;
  GDVars.effectHandlers[108] := EffHndlr.EffLastingInvisibility;
  GDVars.effectHandlers[109] := EffHndlr.EffNoneC;
  GDVars.effectHandlers[110] := EffHndlr.EffRecalcLevelBucket;
  GDVars.effectHandlers[111] := EffHndlr.EffFear;
  GDVars.effectHandlers[112] := EffHndlr.EffZapAttacker;
  GDVars.effectHandlers[113] := EffHndlr.EffGiantStrength;
  GDVars.effectHandlers[114] := EffHndlr.EffDragonlance;
  GDVars.effectHandlers[115] := EffHndlr.EffTypeDamageBonus;
  GDVars.effectHandlers[116] := EffHndlr.EffPoisonResistance;
  GDVars.effectHandlers[117] := EffHndlr.EffDisruption;
  GDVars.effectHandlers[118] := EffHndlr.EffAttackPenaltyTwo;
  GDVars.effectHandlers[119] := EffHndlr.EffAttackPenaltyOne;
  GDVars.overrideHandler := EffHndlr.EffGrantItemEffect
end;
begin
end.
