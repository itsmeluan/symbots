## BattleScreen — the view contract (ADR-0008, Core Design §3.1).
##
## A UI test that runs headless, because the things worth pinning here are not pixels:
## that the screen never offers an action the engine would refuse, that the taunt rule is
## VISIBLE before the tap rather than a rejection after it, and that a battle driven purely
## through the screen still reaches an outcome.
extends GutTest

const BattleScreenScript := preload("res://src/ui/battle/battle_screen.gd")
const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")
const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _screen: BattleScreen
var _cfg: BalanceConfig
var _rng: RandomNumberGenerator
var _ctx: ServiceContext


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 4242
	_ctx = ServiceContext.new()
	_ctx.log = SpyLogSink.new()
	_ctx.balance = _cfg

	_screen = BattleScreenScript.new()
	add_child_autofree(_screen)
	_screen.setup(_ctx)


func after_each() -> void:
	_screen = null


func _unit(id: String, side: int, hp := 200, role := SpeciesDefScript.Role.DPS,
		mobility := 10, slot := 0) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = StringName(id)
	u.display_name = id
	u.side = side
	u.slot = slot
	u.role = role
	u.max_structure = hp
	u.current_structure = hp
	u.base_stats = {&"mobility": mobility, &"physical_power": 40, &"armor": 20,
		&"resistance": 20, &"targeting": 0, &"processing": 30}
	u.skills = [&"strike"]
	return u


func _strike() -> SkillDef:
	var s := SkillDef.new()
	s.id = &"strike"
	s.display_name = "Strike"
	s.target_mode = SkillDefScript.TargetMode.SINGLE_ENEMY
	s.power_percent = 100
	s.scaling_stat = &"physical_power"
	s.effects = [{"kind": SkillDefScript.EffectKind.DAMAGE}]
	return s


func _sweep() -> SkillDef:
	var s := _strike()
	s.id = &"sweep"
	s.display_name = "Sweep"
	s.target_mode = SkillDefScript.TargetMode.ALL_ENEMIES
	return s


func _table() -> Dictionary:
	return {&"strike": _strike(), &"sweep": _sweep()}


func _start(players: Array, enemies: Array) -> BattleEngine:
	var e := BattleEngineScript.new(players, enemies, _table(), _cfg, _rng, _ctx.log)
	_screen.begin_battle(e, _table())
	return e


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func test_the_screen_lays_out_four_rows_a_side() -> void:
	_start([_unit("p", BattleUnit.Side.PLAYER)], [_unit("x", BattleUnit.Side.ENEMY)])
	assert_eq(_screen._player_panels.size(), BattleScreenScript.SQUAD_SIZE)
	assert_eq(_screen._enemy_panels.size(), BattleScreenScript.SQUAD_SIZE)


func test_unused_rows_are_hidden_rather_than_drawn_empty() -> void:
	# Enemies number 1-4 (§3.1), so empty rows are the normal case, not an error.
	_start([_unit("p", BattleUnit.Side.PLAYER)], [_unit("x", BattleUnit.Side.ENEMY)])
	assert_true(_screen._enemy_panels[0].visible)
	assert_false(_screen._enemy_panels[1].visible)


func test_every_tap_target_meets_the_touch_minimum() -> void:
	_start([_unit("p", BattleUnit.Side.PLAYER)], [_unit("x", BattleUnit.Side.ENEMY)])
	for panel in _screen._player_panels:
		assert_gte(panel.custom_minimum_size.y, float(UnitPanel.MIN_TAP_HEIGHT),
			"a card below the touch minimum is unusable on the target platform")


# ---------------------------------------------------------------------------
# The screen never offers what the engine would refuse
# ---------------------------------------------------------------------------

func test_the_taunt_rule_is_visible_before_the_tap() -> void:
	# The whole point: highlighting comes from the engine's legal set, so the player is
	# never shown a target they are then not allowed to hit.
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var tank := _unit("tank", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.TANK, 5)
	var squishy := _unit("squishy", BattleUnit.Side.ENEMY, 100,
		SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [tank, squishy])

	_screen._on_skill_pressed(&"strike")

	assert_true(_screen._enemy_panels[0].is_targetable, "the tank is highlighted")
	assert_false(_screen._enemy_panels[1].is_targetable,
		"the protected unit is NOT — the rule is shown, not enforced by rejection")


func test_tapping_a_protected_unit_changes_nothing() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var tank := _unit("tank", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.TANK, 5)
	var squishy := _unit("squishy", BattleUnit.Side.ENEMY, 100,
		SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [tank, squishy])

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(squishy)

	assert_eq(squishy.current_structure, 100, "the protected unit took nothing")
	assert_eq(tank.current_structure, 400, "and the turn was not spent elsewhere either")


func test_the_skill_bar_only_offers_usable_skills() -> void:
	var heavy := _strike()
	heavy.id = &"heavy"
	heavy.display_name = "Heavy"
	heavy.cooldown = 3

	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.skills = [&"strike", &"heavy"]
	var x := _unit("x", BattleUnit.Side.ENEMY, 9999, SpeciesDefScript.Role.DPS, 5)
	var table := _table()
	table[&"heavy"] = heavy
	var e := BattleEngineScript.new([p], [x], table, _cfg, _rng, _ctx.log)
	_screen.begin_battle(e, table)

	_screen._on_skill_pressed(&"heavy")
	_screen._on_unit_tapped(x)

	# p acts again next round; Heavy is still cooling down, so its button must be disabled.
	var disabled := 0
	for child in _screen._skill_bar.get_children():
		if child is Button and child.disabled:
			disabled += 1
	assert_gt(disabled, 0, "a button that lies about being usable is worse than no button")


func test_a_multi_target_skill_resolves_without_a_second_tap() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.skills = [&"sweep"]
	var a := _unit("a", BattleUnit.Side.ENEMY, 300, SpeciesDefScript.Role.DPS, 5)
	var b := _unit("b", BattleUnit.Side.ENEMY, 300, SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [a, b])

	_screen._on_skill_pressed(&"sweep")

	assert_lt(a.current_structure, 300, "an AoE has nothing to aim, so it fires at once")
	assert_lt(b.current_structure, 300)
	assert_null(_screen._pending_skill, "and leaves no armed skill behind")


# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------

func test_enemy_turns_resolve_without_player_input() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 5)
	var fast := _unit("fast", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.DPS, 40)
	_start([p], [fast])
	# The fast enemy acted during begin_battle, so control is already back with the player.
	assert_eq(_screen.engine.current_actor(), p)
	assert_lt(p.current_structure, 400, "the enemy took its turn on its own")


func test_auto_battle_runs_the_fight_to_an_outcome() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 20)
	var x := _unit("x", BattleUnit.Side.ENEMY, 60, SpeciesDefScript.Role.DPS, 5)
	_start([p], [x])

	_screen._on_auto_toggled(true)

	assert_true(_screen.engine.is_over(), "auto plays both sides through to the end")
	assert_eq(_screen.engine.outcome, BattleEngineScript.Outcome.PLAYER_WON)


func test_the_screen_reports_the_outcome_once_the_battle_ends() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 20)
	var x := _unit("x", BattleUnit.Side.ENEMY, 60, SpeciesDefScript.Role.DPS, 5)
	_start([p], [x])
	watch_signals(_screen)

	_screen._on_auto_toggled(true)

	assert_signal_emitted(_screen, "battle_finished")
	assert_eq(_screen._banner.text, "VICTORY")


func test_the_log_renders_only_new_events() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 9999, SpeciesDefScript.Role.DPS, 5)
	_start([p], [x])
	var drawn_after_start := _screen._events_drawn

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(x)

	assert_gt(_screen._events_drawn, drawn_after_start,
		"the drain advances so a battle is never replayed from the top")
	assert_eq(_screen._events_drawn, _screen.engine.events.size(),
		"and consumes everything the engine has emitted")


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

func test_a_panel_shows_the_charge_meter_only_for_a_unit_with_an_ult() -> void:
	var ult := _strike()
	ult.id = &"ult"
	ult.is_ultimate = true
	ult.charge_cost = 50

	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.ultimate_skill = &"ult"
	var x := _unit("x", BattleUnit.Side.ENEMY, 200, SpeciesDefScript.Role.DPS, 5)
	var table := _table()
	table[&"ult"] = ult
	var e := BattleEngineScript.new([p], [x], table, _cfg, _rng, _ctx.log)
	_screen.begin_battle(e, table)

	assert_true(_screen._player_panels[0]._charge_bar.visible)
	assert_false(_screen._enemy_panels[0]._charge_bar.visible,
		"a unit with no ult must not show an empty meter that never fills")


func test_a_destroyed_unit_is_dimmed_rather_than_removed() -> void:
	# Removing it would reflow the column mid-fight and move every other tap target.
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 30)
	var a := _unit("a", BattleUnit.Side.ENEMY, 1, SpeciesDefScript.Role.DPS, 5)
	var b := _unit("b", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [a, b])

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(a)

	assert_true(_screen._enemy_panels[0].visible, "still on screen")
	assert_lt(_screen._enemy_panels[0].modulate.r, 1.0, "but visibly out of the fight")
