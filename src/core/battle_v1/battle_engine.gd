## BattleEngine — orchestrates one 4v4 battle (Core Design §3).
##
## Pure RefCounted with everything injected: units, the skill table, tuning config, RNG
## and the log channel. No autoload, no scene, no signals. That is what lets the same
## engine drive the on-screen battle, the auto-battler, and the offline expedition
## simulator — three callers that must never disagree about an outcome.
##
## The engine is a STATE MACHINE the caller pumps, not a loop that runs to completion.
## It stops at each unit's turn and waits for [method submit_action], because a manual
## battle needs to stop there for input. Auto-battle just calls [method take_auto_action]
## at the same seam, so "auto" is not a second code path — it is the same path with the
## choice made by [BattleTargeting] instead of by a finger.
##
## Every mutation appends to [member events]: the UI animates from that list rather than
## observing state, so a replay of the same seed produces the identical animation.
class_name BattleEngine
extends RefCounted

const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")
const StatusEffectScript := preload("res://src/core/battle_v1/status_effect.gd")
const TurnOrderScript := preload("res://src/core/battle_v1/turn_order.gd")
const BattleTargetingScript := preload("res://src/core/battle_v1/targeting.gd")

## Battle lifecycle. Values are APPEND-ONLY.
enum Phase {
	NOT_STARTED = 0,
	AWAITING_ACTION = 1,  ## a unit's turn is up; caller must submit or auto
	FINISHED = 2,
}

## How the battle ended.
enum Outcome { NONE = 0, PLAYER_WON = 1, ENEMY_WON = 2, DRAW = 3 }

var phase: Phase = Phase.NOT_STARTED
var outcome: Outcome = Outcome.NONE

var player_units: Array = []
var enemy_units: Array = []

var round_number: int = 0

## Ordered log of everything that happened, oldest first. See class docstring.
var events: Array[Dictionary] = []

var _skills: Dictionary = {}          ## skill_id -> SkillDef
var _cfg: BalanceConfig = null
var _rng: RandomNumberGenerator = null
var _log: LogSink = null

## This round's acting order and where we are in it.
var _order: Array = []
var _cursor: int = 0


## [param skills] maps skill_id -> [SkillDef]; [param rng] must come from RngService so
## the battle is reproducible from its seed (ADR-0006).
func _init(p_player: Array, p_enemy: Array, skills: Dictionary,
		cfg: BalanceConfig, rng: RandomNumberGenerator, log: LogSink) -> void:
	player_units = p_player
	enemy_units = p_enemy
	_skills = skills
	_cfg = cfg
	_rng = rng
	_log = log


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Begin the battle and advance to the first unit that can act.
func start() -> void:
	phase = Phase.AWAITING_ACTION
	round_number = 0
	_emit(&"battle_started", {})
	_begin_round()


## The unit whose turn it is, or null when the battle is over.
func current_actor() -> BattleUnit:
	if phase != Phase.AWAITING_ACTION or _cursor >= _order.size():
		return null
	return _order[_cursor]


func is_over() -> bool:
	return phase == Phase.FINISHED


# ---------------------------------------------------------------------------
# The action seam
# ---------------------------------------------------------------------------

## Skills the current actor may use right now — cooldown-ready, charged if an ult, and
## with at least one legal target. A skill with no legal target is filtered out HERE so
## neither the UI nor the auto-battler has to re-derive the rule.
func available_skills(unit: BattleUnit) -> Array:
	var out: Array = []
	for sid in unit.skills:
		var s := _skill(sid)
		if s == null or not unit.is_skill_ready(sid):
			continue
		if not legal_targets(unit, s).is_empty():
			out.append(s)
	if unit.has_ultimate():
		var ult := _skill(unit.ultimate_skill)
		if ult != null and unit.is_ultimate_ready(ult.charge_cost) \
				and not legal_targets(unit, ult).is_empty():
			out.append(ult)
	return out


func legal_targets(unit: BattleUnit, skill: SkillDef) -> Array:
	return BattleTargetingScript.legal_targets(
		unit, skill, _allies_of(unit), _enemies_of(unit))


## Resolve the current actor's turn with an explicit choice.
##
## Returns false and changes nothing if the action is illegal — a stale target that died
## to a damage-over-time tick since the player tapped is the common case, not an error, so
## the caller re-reads [method legal_targets] rather than trusting its cached list.
func submit_action(skill_id: StringName, target: BattleUnit) -> bool:
	var actor := current_actor()
	if actor == null:
		return false
	var skill := _skill(skill_id)
	if skill == null:
		return false
	var is_ult := skill.is_ultimate and skill_id == actor.ultimate_skill
	if not is_ult and not actor.skills.has(skill_id):
		return false
	if is_ult and not actor.is_ultimate_ready(skill.charge_cost):
		return false
	if not is_ult and not actor.is_skill_ready(skill_id):
		return false

	var legal := legal_targets(actor, skill)
	if legal.is_empty():
		return false
	# Multi-target skills carry no single target; single-target ones must name a living,
	# legal one.
	if skill.is_single_target() and not legal.has(target):
		return false

	_resolve_skill(actor, skill, target, legal)
	_end_turn(actor)
	return true


## Resolve the current actor's turn by letting the engine choose — auto-battle, enemy AI
## and the offline simulator all enter here.
func take_auto_action() -> bool:
	var actor := current_actor()
	if actor == null:
		return false
	var options := available_skills(actor)
	if options.is_empty():
		# Nothing usable at all: pass rather than stall. A unit with no legal action is
		# rare (fully stunned team, healer with everyone at full) but must not deadlock.
		_emit(&"passed", {&"unit": actor.unit_id})
		_end_turn(actor)
		return true
	var skill: SkillDef = _pick_auto_skill(actor, options)
	var target: BattleUnit = BattleTargetingScript.auto_pick(
		actor, skill, _allies_of(actor), _enemies_of(actor))
	_resolve_skill(actor, skill, target, legal_targets(actor, skill))
	_end_turn(actor)
	return true


## Auto-battle's skill choice. Ult first when it is up — a charged ult held back is a
## wasted resource, and the meter carries overfill anyway. Otherwise the highest-power
## ready skill, so cooldowns get spent rather than hoarded.
func _pick_auto_skill(_actor: BattleUnit, options: Array) -> SkillDef:
	var best: SkillDef = options[0]
	for s in options:
		if s.is_ultimate:
			return s
		if s.power_percent > best.power_percent:
			best = s
	return best


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

func _resolve_skill(actor: BattleUnit, skill: SkillDef, target: BattleUnit,
		legal: Array) -> void:
	var targets := _resolve_targets(skill, target, legal)

	if skill.is_ultimate:
		actor.spend_charge(skill.charge_cost)
		_emit(&"ultimate_fired", {&"unit": actor.unit_id, &"skill": skill.id})
	else:
		actor.put_on_cooldown(skill.id, skill.cooldown)

	_emit(&"skill_used", {
		&"unit": actor.unit_id, &"skill": skill.id,
		&"targets": targets.map(func(t): return t.unit_id),
	})

	for t in targets:
		_apply_effects(actor, skill, t)

	# Acting charges the meter. Placed after resolution so a killing blow still pays out.
	actor.gain_charge(BattleUnit.CHARGE_PER_ACTION)


## Which units a cast actually lands on. RANDOM_ENEMY rolls here rather than in
## [BattleTargeting] so targeting stays pure and only the engine touches the RNG.
func _resolve_targets(skill: SkillDef, chosen: BattleUnit, legal: Array) -> Array:
	match skill.target_mode:
		SkillDefScript.TargetMode.ALL_ALLIES, SkillDefScript.TargetMode.ALL_ENEMIES:
			return legal
		SkillDefScript.TargetMode.RANDOM_ENEMY:
			if legal.is_empty():
				return []
			return [legal[_rng.call(&"randi") % legal.size()]]
		SkillDefScript.TargetMode.LOWEST_HP_ALLY:
			return legal  # already resolved to exactly one
	return [chosen] if chosen != null else []


## Effect dictionaries use STRING keys, not StringName. Godot 4 hashes `"kind"` and
## `&"kind"` as different keys, and a `.tres` authored in the editor writes String keys —
## so a StringName lookup here would silently read the default off every authored skill and
## every skill in the game would do nothing. Matches the existing `PartDef.drop_conditions`
## convention.
func _apply_effects(actor: BattleUnit, skill: SkillDef, target: BattleUnit) -> void:
	for effect in skill.effects:
		var kind: int = int(effect.get("kind", SkillDefScript.EffectKind.INVALID))
		match kind:
			SkillDefScript.EffectKind.DAMAGE:
				_apply_damage(actor, skill, target)
			SkillDefScript.EffectKind.HEAL:
				var amount := _magnitude(actor, skill)
				var healed := target.heal(amount)
				_emit(&"healed", {&"unit": target.unit_id, &"amount": healed})
			SkillDefScript.EffectKind.SHIELD:
				var amount := _magnitude(actor, skill)
				target.add_shield(amount)
				_emit(&"shielded", {&"unit": target.unit_id, &"amount": amount})
			SkillDefScript.EffectKind.APPLY_STATUS:
				_apply_status(actor, effect, target)
			SkillDefScript.EffectKind.CLEANSE:
				var removed := target.cleanse()
				_emit(&"cleansed", {&"unit": target.unit_id, &"removed": removed})
			SkillDefScript.EffectKind.REVIVE:
				if not target.is_alive():
					target.current_structure = maxi(1, target.max_structure
						* int(effect.get("percent", 25)) / 100)
					_emit(&"revived", {&"unit": target.unit_id,
						&"structure": target.current_structure})


func _apply_damage(actor: BattleUnit, skill: SkillDef, target: BattleUnit) -> void:
	var attack := _magnitude(actor, skill)
	var defense := target.stat(_defense_key_for(skill))
	var crit := _roll_crit(actor)
	var raw := DamageFormula.compute_damage(
		attack, defense, 1.0, _cfg, _log,
		_cfg.crit_damage_multiplier if crit else 1.0)
	var lost := target.take_damage(raw)

	# The victim charges from being hit, so a tank that never lands a blow still reaches
	# its ult — otherwise the role that survives longest charges slowest.
	target.gain_charge(BattleUnit.CHARGE_PER_HIT_TAKEN)

	_emit(&"damaged", {
		&"unit": target.unit_id, &"source": actor.unit_id,
		&"amount": raw, &"structure_lost": lost, &"crit": crit,
	})
	if not target.is_alive():
		_emit(&"destroyed", {&"unit": target.unit_id})


func _apply_status(actor: BattleUnit, effect: Dictionary, target: BattleUnit) -> void:
	var s := StatusEffectScript.new(
		int(effect.get("status", StatusEffectScript.Kind.INVALID)),
		int(effect.get("turns", 1)),
		bool(effect.get("is_debuff", true)))
	s.tick_amount = int(effect.get("tick_amount", 0))
	s.flat_mods = effect.get("flat_mods", {})
	s.percent_mods = effect.get("percent_mods", {})
	s.source_id = actor.unit_id
	target.add_status(s)
	_emit(&"status_applied", {
		&"unit": target.unit_id, &"kind": s.kind, &"turns": s.remaining})


## Damage/heal magnitude: the caster's scaling stat times the skill's percent.
func _magnitude(actor: BattleUnit, skill: SkillDef) -> int:
	return actor.stat(skill.scaling_stat) * skill.power_percent / 100


## Physical attacks are met by armor, energy attacks by resistance.
func _defense_key_for(skill: SkillDef) -> StringName:
	return &"resistance" if skill.scaling_stat == &"energy_power" else &"armor"


## Crit chance derives from `targeting` rather than being its own stat, capped so a late
## targeting stack cannot reach guaranteed crits (see BalanceConfig).
func _roll_crit(actor: BattleUnit) -> bool:
	var chance: int = mini(
		actor.stat(&"targeting") / maxi(1, _cfg.crit_targeting_divisor),
		_cfg.crit_chance_cap_percent)
	if chance <= 0:
		return false
	# Drawn via call() because a statically-typed randi() call is dispatched by ptrcall
	# and bypasses a test double's override.
	return int(_rng.call(&"randi") % 100) < chance


# ---------------------------------------------------------------------------
# Turn and round flow
# ---------------------------------------------------------------------------

func _begin_round() -> void:
	round_number += 1
	if round_number > _cfg.max_battle_rounds:
		_finish(Outcome.DRAW)
		return
	_order = TurnOrderScript.for_round(player_units, enemy_units)
	_cursor = 0
	_emit(&"round_started", {&"round": round_number})
	_prepare_actor()


## Advance past units that cannot act, and start the turn of the one that can.
##
## Status ticks and cooldown ticks happen at the START of a unit's own turn, not at the
## end of the round. Per-round ticking would make a fast unit and a slow unit recover at
## different real rates — invisible to the player and impossible to reason about.
func _prepare_actor() -> void:
	while _cursor < _order.size():
		var unit: BattleUnit = _order[_cursor]
		if not unit.is_alive():
			_cursor += 1
			continue

		_tick_unit(unit)
		# A damage-over-time tick can destroy the unit before it acts.
		if not unit.is_alive():
			if _check_end():
				return
			_cursor += 1
			continue
		if unit.is_stunned():
			_emit(&"stunned", {&"unit": unit.unit_id})
			_cursor += 1
			continue
		return  # this unit acts; wait for the caller

	_begin_round()


## One unit's start-of-turn upkeep: cooldowns, damage-over-time, regen, expiry.
func _tick_unit(unit: BattleUnit) -> void:
	unit.tick_cooldowns()
	for s in unit.statuses:
		var dot: int = s.damage_per_tick()
		if dot > 0:
			var lost := unit.take_damage(dot)
			_emit(&"dot_tick", {&"unit": unit.unit_id, &"kind": s.kind, &"amount": lost})
			if not unit.is_alive():
				_emit(&"destroyed", {&"unit": unit.unit_id})
				break
		var hot: int = s.heal_per_tick()
		if hot > 0:
			var healed := unit.heal(hot)
			_emit(&"hot_tick", {&"unit": unit.unit_id, &"amount": healed})
	for expired in unit.tick_statuses():
		_emit(&"status_expired", {&"unit": unit.unit_id, &"kind": expired.kind})


func _end_turn(_actor: BattleUnit) -> void:
	if _check_end():
		return
	_cursor += 1
	_prepare_actor()


## Declare a winner if either side is wiped. Returns true when the battle ended.
func _check_end() -> bool:
	var players_left := _any_alive(player_units)
	var enemies_left := _any_alive(enemy_units)
	if players_left and enemies_left:
		return false
	# Both sides wiped in the same resolution (a reflected killing blow) reads as a loss:
	# the player did not clear the stage.
	_finish(Outcome.PLAYER_WON if players_left else Outcome.ENEMY_WON)
	return true


func _finish(result: Outcome) -> void:
	outcome = result
	phase = Phase.FINISHED
	_emit(&"battle_ended", {&"outcome": result, &"rounds": round_number})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _skill(id: StringName) -> SkillDef:
	return _skills.get(id, null)


func _allies_of(unit: BattleUnit) -> Array:
	return player_units if unit.side == BattleUnit.Side.PLAYER else enemy_units


func _enemies_of(unit: BattleUnit) -> Array:
	return enemy_units if unit.side == BattleUnit.Side.PLAYER else player_units


func _any_alive(units: Array) -> bool:
	for u in units:
		if u.is_alive():
			return true
	return false


func _emit(kind: StringName, data: Dictionary) -> void:
	data[&"event"] = kind
	events.append(data)
