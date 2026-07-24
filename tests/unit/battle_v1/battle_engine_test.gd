## BattleEngine — round flow, resolution, victory, ults (Core Design §3, §3.4b).
##
## The engine is the piece three callers share (manual battle, auto-battle, offline
## expedition), so the tests here pin the CONTRACT those three depend on: that a battle
## always terminates, that a stale action is rejected rather than resolved, and that the
## event log is complete enough for a UI to animate from without reading state.
extends GutTest

const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")
const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")
const StatusEffectScript := preload("res://src/core/battle_v1/status_effect.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log: LogSink
var _rng: RandomNumberGenerator


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345


func _unit(id: String, side: int, hp := 100, role := SpeciesDefScript.Role.DPS,
		mobility := 10, slot := 0) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = StringName(id)
	u.display_name = id
	u.side = side
	u.slot = slot
	u.role = role
	u.max_structure = hp
	u.current_structure = hp
	# targeting 0 keeps crit off, so damage assertions are not variance-dependent.
	u.base_stats = {
		&"mobility": mobility, &"physical_power": 100, &"energy_power": 50,
		&"processing": 60, &"armor": 20, &"resistance": 20, &"targeting": 0,
	}
	u.skills = [&"strike"]
	return u


func _strike() -> SkillDef:
	var s := SkillDef.new()
	s.id = &"strike"
	s.target_mode = SkillDefScript.TargetMode.SINGLE_ENEMY
	s.power_percent = 100
	s.scaling_stat = &"physical_power"
	s.effects = [{"kind": SkillDefScript.EffectKind.DAMAGE}]
	return s


func _skills() -> Dictionary:
	return {&"strike": _strike()}


func _engine(players: Array, enemies: Array, skills := {}) -> BattleEngine:
	var table: Dictionary = _skills()
	table.merge(skills, true)
	return BattleEngineScript.new(players, enemies, table, _cfg, _rng, _log)


func _events_of(e: BattleEngine, kind: StringName) -> Array:
	return e.events.filter(func(ev): return ev.get(&"event") == kind)


# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------

func test_start_puts_the_fastest_unit_on_the_clock() -> void:
	var slow := _unit("slow", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 5)
	var fast := _unit("fast", BattleUnit.Side.ENEMY, 100, SpeciesDefScript.Role.DPS, 30)
	var e := _engine([slow], [fast])
	e.start()
	assert_eq(e.current_actor().unit_id, &"fast")
	assert_eq(e.phase, BattleEngineScript.Phase.AWAITING_ACTION)


func test_the_engine_waits_for_input_instead_of_running_to_completion() -> void:
	var e := _engine([_unit("p", BattleUnit.Side.PLAYER)],
		[_unit("x", BattleUnit.Side.ENEMY)])
	e.start()
	var actor_before := e.current_actor()
	assert_not_null(actor_before, "start() stops AT the first turn — the manual UI needs that seam")
	assert_false(e.is_over())


func test_a_battle_always_terminates_even_when_nobody_can_win() -> void:
	# Two units that cannot hurt each other: without the round cap this loops forever, and
	# the offline expedition simulator would hang rather than resolve.
	_cfg.max_battle_rounds = 5
	var a := _unit("a", BattleUnit.Side.PLAYER, 100000)
	var b := _unit("b", BattleUnit.Side.ENEMY, 100000)
	a.base_stats[&"physical_power"] = 0
	b.base_stats[&"physical_power"] = 0
	var e := _engine([a], [b])
	e.start()
	var guard := 0
	while not e.is_over() and guard < 500:
		e.take_auto_action()
		guard += 1
	assert_true(e.is_over(), "The round cap must end it")
	assert_eq(e.outcome, BattleEngineScript.Outcome.DRAW)


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------

func test_a_strike_damages_the_target_and_logs_it() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 100, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x])
	e.start()

	assert_true(e.submit_action(&"strike", x))

	assert_lt(x.current_structure, 100, "The target took damage")
	assert_eq(_events_of(e, &"damaged").size(), 1, "and the UI can animate it from the log")


func test_wiping_the_enemy_team_wins_the_battle() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 1, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x])
	e.start()
	e.submit_action(&"strike", x)
	assert_true(e.is_over())
	assert_eq(e.outcome, BattleEngineScript.Outcome.PLAYER_WON)
	assert_eq(_events_of(e, &"destroyed").size(), 1)


func test_losing_every_symbot_loses_the_battle() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 1, SpeciesDefScript.Role.DPS, 5)
	var x := _unit("x", BattleUnit.Side.ENEMY, 100, SpeciesDefScript.Role.DPS, 30)
	var e := _engine([p], [x])
	e.start()
	e.take_auto_action()  # the fast enemy acts first
	assert_true(e.is_over())
	assert_eq(e.outcome, BattleEngineScript.Outcome.ENEMY_WON)


# ---------------------------------------------------------------------------
# Illegal actions are refused, not resolved
# ---------------------------------------------------------------------------

func test_a_dead_target_is_refused() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	var alive := _unit("alive", BattleUnit.Side.ENEMY, 100, SpeciesDefScript.Role.DPS, 5)
	var dead := _unit("dead", BattleUnit.Side.ENEMY, 100, SpeciesDefScript.Role.DPS, 5, 1)
	dead.current_structure = 0
	var e := _engine([p], [alive, dead])
	e.start()
	assert_false(e.submit_action(&"strike", dead),
		"A target that died since the player tapped is refused, not resolved")
	assert_eq(e.current_actor().unit_id, &"p", "and the turn is NOT consumed")


func test_targeting_past_a_taunter_is_refused() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	var tank := _unit("tank", BattleUnit.Side.ENEMY, 200, SpeciesDefScript.Role.TANK, 5)
	tank.add_status(StatusEffectScript.taunt(3))  # opt-in taunt, as if it had cast Provoke
	var squishy := _unit("squishy", BattleUnit.Side.ENEMY, 50, SpeciesDefScript.Role.DPS, 5, 1)
	var e := _engine([p], [tank, squishy])
	e.start()
	assert_false(e.submit_action(&"strike", squishy),
		"The taunt rule is enforced at the engine seam, not only in the UI")
	assert_true(e.submit_action(&"strike", tank))


func test_a_self_skill_lands_on_the_caster_via_the_manual_null_target_path() -> void:
	# Provoke is SELF, and the player's manual path submits a NULL target for any skill that
	# is not single-target. The SELF status must still land on the caster — the bug was that
	# it resolved to an empty target set and applied to nothing.
	var provoke := SkillDefScript.new()
	provoke.id = &"provoke"
	provoke.target_mode = SkillDefScript.TargetMode.SELF
	provoke.effects = [{"kind": SkillDefScript.EffectKind.APPLY_STATUS,
		"status": StatusEffectScript.Kind.FORCED_TAUNT, "turns": 3, "is_debuff": false}]
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.TANK, 30)
	p.skills = [&"provoke"]
	var x := _unit("x", BattleUnit.Side.ENEMY, 100, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x], {&"provoke": provoke})
	e.start()
	assert_eq(e.current_actor().unit_id, &"p", "precondition: the taunter acts first")

	assert_true(e.submit_action(&"provoke", null), "a SELF skill submits with a null target")
	assert_true(p.has_forced_taunt(), "the taunt lands on the caster, not on nothing")


func test_a_provoked_tank_pulls_the_enemy_auto_attack() -> void:
	# End to end: once a player carries a taunt, the enemy's single-target auto action is
	# compelled onto the taunter and never reaches the squishy behind it.
	var tank := _unit("tank", BattleUnit.Side.PLAYER, 300, SpeciesDefScript.Role.TANK, 5)
	var squishy := _unit("squishy", BattleUnit.Side.PLAYER, 80, SpeciesDefScript.Role.DPS, 5, 1)
	tank.add_status(StatusEffectScript.taunt(3))
	var enemy := _unit("enemy", BattleUnit.Side.ENEMY, 100, SpeciesDefScript.Role.DPS, 30)
	var e := _engine([tank, squishy], [enemy])
	e.start()
	assert_eq(e.current_actor().unit_id, &"enemy", "precondition: the enemy is fastest")

	e.take_auto_action()
	assert_lt(tank.current_structure, 300, "the enemy was compelled onto the taunter")
	assert_eq(squishy.current_structure, 80, "and never touched the squishy behind it")


func test_a_skill_on_cooldown_is_refused() -> void:
	var heavy := _strike()
	heavy.id = &"heavy"
	heavy.cooldown = 3
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	p.skills = [&"heavy"]
	var x := _unit("x", BattleUnit.Side.ENEMY, 10000, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x], {&"heavy": heavy})
	e.start()
	assert_true(e.submit_action(&"heavy", x))
	e.take_auto_action()  # enemy turn → next round, p acts again
	assert_false(e.submit_action(&"heavy", x), "Still cooling down")


# ---------------------------------------------------------------------------
# Status effects across turns
# ---------------------------------------------------------------------------

func test_a_burn_ticks_at_the_start_of_the_victims_turn() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 10000, SpeciesDefScript.Role.DPS, 5)
	x.add_status(StatusEffectScript.burn(50, 3))
	var e := _engine([p], [x])
	e.start()
	assert_eq(x.current_structure, 10000, "No tick before its turn comes round")
	e.submit_action(&"strike", x)
	assert_eq(_events_of(e, &"dot_tick").size(), 1, "It ticked when x's turn began")


func test_a_stunned_unit_is_skipped_not_stalled() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 10000, SpeciesDefScript.Role.DPS, 5)
	x.add_status(StatusEffectScript.stun(5))
	var e := _engine([p], [x])
	e.start()
	e.submit_action(&"strike", x)
	assert_eq(_events_of(e, &"stunned").size(), 1)
	assert_eq(e.current_actor().unit_id, &"p", "Play returned to p — the stun did not stall the round")


func test_a_burn_can_destroy_a_unit_before_it_acts() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 10, SpeciesDefScript.Role.DPS, 5)
	x.add_status(StatusEffectScript.burn(999, 3))
	var e := _engine([p], [x])
	e.start()
	e.submit_action(&"strike", x)  # p acts, then x's turn begins and the burn kills it
	assert_true(e.is_over(), "A DOT kill must end the battle like any other kill")
	assert_eq(e.outcome, BattleEngineScript.Outcome.PLAYER_WON)


# ---------------------------------------------------------------------------
# Ultimates (§3.4b)
# ---------------------------------------------------------------------------

func _ult() -> SkillDef:
	var s := _strike()
	s.id = &"overload"
	s.is_ultimate = true
	s.charge_cost = 30
	s.power_percent = 400
	return s


func test_an_ult_cannot_open_the_fight() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	p.ultimate_skill = &"overload"
	var x := _unit("x", BattleUnit.Side.ENEMY, 10000, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x], {&"overload": _ult()})
	e.start()
	assert_false(e.submit_action(&"overload", x),
		"Charge starts at 0 — an ult available on turn one is not an ult")


func test_an_ult_charges_through_the_fight_and_then_fires() -> void:
	# Both sides need enough structure to survive the exchange — the point of the test is
	# the charge accruing over several rounds, not who wins.
	var p := _unit("p", BattleUnit.Side.PLAYER, 100000, SpeciesDefScript.Role.DPS, 30)
	p.ultimate_skill = &"overload"
	var x := _unit("x", BattleUnit.Side.ENEMY, 100000, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x], {&"overload": _ult()})
	e.start()
	# Three actions at 10 charge each reaches the cost of 30.
	for i in 3:
		e.submit_action(&"strike", x)
		e.take_auto_action()
	assert_true(p.is_ultimate_ready(30), "Charge accrued from acting")
	assert_true(e.submit_action(&"overload", x))
	assert_eq(_events_of(e, &"ultimate_fired").size(), 1)


func test_firing_an_ult_spends_charge_rather_than_zeroing_it() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	p.ultimate_skill = &"overload"
	p.ultimate_charge = 50
	var x := _unit("x", BattleUnit.Side.ENEMY, 100000, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x], {&"overload": _ult()})
	e.start()
	e.submit_action(&"overload", x)
	assert_eq(p.ultimate_charge, 30,
		"50 - 30 cost + 10 for acting = 30. Overfill carries, so a long fight never "
		+ "silently wastes charge the player earned")


func test_a_tank_charges_from_being_hit_not_only_from_acting() -> void:
	# Otherwise the role that survives longest reaches its ult slowest — backwards.
	var tank := _unit("tank", BattleUnit.Side.PLAYER, 100000, SpeciesDefScript.Role.TANK, 5)
	tank.ultimate_skill = &"overload"
	var x := _unit("x", BattleUnit.Side.ENEMY, 100000, SpeciesDefScript.Role.DPS, 30)
	var e := _engine([tank], [x], {&"overload": _ult()})
	e.start()
	e.take_auto_action()  # x strikes the tank
	assert_eq(tank.ultimate_charge, BattleUnit.CHARGE_PER_HIT_TAKEN,
		"The tank gained charge without having acted yet")


func test_auto_battle_fires_a_charged_ult_rather_than_hoarding_it() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 100, SpeciesDefScript.Role.DPS, 30)
	p.ultimate_skill = &"overload"
	p.ultimate_charge = 100
	var x := _unit("x", BattleUnit.Side.ENEMY, 100000, SpeciesDefScript.Role.DPS, 5)
	var e := _engine([p], [x], {&"overload": _ult()})
	e.start()
	e.take_auto_action()
	assert_eq(_events_of(e, &"ultimate_fired").size(), 1,
		"A held ult is a wasted resource, and overfill carries anyway")


# ---------------------------------------------------------------------------
# 4v4 shape
# ---------------------------------------------------------------------------

func test_a_full_four_versus_four_resolves_to_a_winner() -> void:
	var players: Array = []
	var enemies: Array = []
	for i in 4:
		players.append(_unit("p%d" % i, BattleUnit.Side.PLAYER, 200,
			SpeciesDefScript.Role.DPS, 10 + i, i))
		enemies.append(_unit("e%d" % i, BattleUnit.Side.ENEMY, 150,
			SpeciesDefScript.Role.DPS, 10 + i, i))
	var e := _engine(players, enemies)
	e.start()
	var guard := 0
	while not e.is_over() and guard < 2000:
		e.take_auto_action()
		guard += 1
	assert_true(e.is_over(), "The full 4v4 shape resolves")
	assert_ne(e.outcome, BattleEngineScript.Outcome.NONE)
	assert_gt(_events_of(e, &"round_started").size(), 0, "and logged its rounds")
