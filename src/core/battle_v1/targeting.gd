## BattleTargeting — who a skill may legally hit, and the Taunt rule (Core Design §3.3).
##
## This is the system that makes TANK a role rather than a stat spread: while a living,
## untaunt-broken tank stands on the defending side, single-target attacks must go to a
## tank. Everything interesting about the battle layer hangs off the exceptions.
##
## Pure static functions over arrays of [BattleUnit] — no state, no side effects, so the
## same question always has the same answer and the auto-battler and the manual UI cannot
## disagree about what is legal.
class_name BattleTargeting
extends RefCounted

const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")


## Every unit a [param skill] cast by [param caster] may legally be aimed at.
##
## Returns an EMPTY array when the skill has no legal target (every enemy dead, no ally
## to heal). Callers must treat empty as "this skill cannot be used right now" rather
## than assuming at least one target — a healer with no wounded ally is the common case,
## not an error.
##
## Example:
##     var legal := BattleTargeting.legal_targets(caster, skill, allies, enemies)
##     if legal.is_empty():
##         return  # skill unusable this turn
static func legal_targets(caster: BattleUnit, skill: SkillDef,
		allies: Array, enemies: Array) -> Array:
	match skill.target_mode:
		SkillDefScript.TargetMode.SELF:
			return [caster] if caster.is_alive() else []
		SkillDefScript.TargetMode.SINGLE_ALLY, SkillDefScript.TargetMode.ALL_ALLIES:
			return _living(allies)
		SkillDefScript.TargetMode.LOWEST_HP_ALLY:
			var hurt := _living(allies)
			return [] if hurt.is_empty() else [_lowest_structure(hurt)]
		SkillDefScript.TargetMode.ALL_ENEMIES, SkillDefScript.TargetMode.RANDOM_ENEMY:
			# Multi-target and random effects are not CHOOSING a target, so there is
			# nothing for taunt to redirect (§3.3). This is deliberate, not an oversight:
			# it is what makes an AoE the answer to a tank wall.
			return _living(enemies)
		SkillDefScript.TargetMode.SINGLE_ENEMY:
			return _single_enemy_targets(caster, skill, enemies)
	return []


## The taunt rule proper. A single-target attack sees only the living tanks — unless the
## caster or the skill pierces, or every tank's taunt is suppressed.
static func _single_enemy_targets(caster: BattleUnit, skill: SkillDef,
		enemies: Array) -> Array:
	var living := _living(enemies)
	if living.is_empty():
		return []
	# Pierce from either source: the skill is flagged, or the caster holds the effect.
	if skill.ignores_taunt or caster.ignores_taunt():
		return living
	var tanks := active_taunters(living)
	# No tank, or every tank taunt-broken → the whole line is open.
	return tanks if not tanks.is_empty() else living


## Living tanks whose taunt is actually in force. A tank under TAUNT_BREAK is still a
## tank and still a legal target — it just stops COMPELLING attacks toward itself.
static func active_taunters(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u.is_alive() and u.is_tank() and not u.is_taunt_suppressed():
			out.append(u)
	return out


## True when [param target] is a legal choice for this cast. The UI calls this to grey
## out illegal picks; the engine calls it again before resolving, because a target legal
## when the player tapped may have died to a damage-over-time tick since.
static func is_legal_target(caster: BattleUnit, skill: SkillDef, target: BattleUnit,
		allies: Array, enemies: Array) -> bool:
	return legal_targets(caster, skill, allies, enemies).has(target)


## Auto-battle's pick from the legal set. Deliberately simple and readable rather than
## clever: heal the most hurt ally, otherwise attack the enemy closest to dying, so a
## player watching auto-battle can predict it. An auto-battler whose choices look random
## reads as broken even when it is optimal.
static func auto_pick(caster: BattleUnit, skill: SkillDef,
		allies: Array, enemies: Array) -> BattleUnit:
	var legal := legal_targets(caster, skill, allies, enemies)
	if legal.is_empty():
		return null
	if skill.targets_enemies():
		return _lowest_structure(legal)
	# Support and healing: the ally furthest from full, so an overheal is never the pick.
	var best: BattleUnit = legal[0]
	var best_missing := -1
	for u in legal:
		var missing: int = u.max_structure - u.current_structure
		if missing > best_missing:
			best_missing = missing
			best = u
	return best


static func _living(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u.is_alive():
			out.append(u)
	return out


## Lowest current structure, ties going to the earliest slot so the choice is stable
## across identical states — an unstable pick makes a replay diverge from its seed.
static func _lowest_structure(units: Array) -> BattleUnit:
	var best: BattleUnit = units[0]
	for u in units:
		if u.current_structure < best.current_structure:
			best = u
	return best
