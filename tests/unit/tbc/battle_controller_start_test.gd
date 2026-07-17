## TBC Story 002 — start sequence (Rule 2 order) & build-validity gate.
##
## Covers AC-TBC-42 (an invalid fielded build refuses the WHOLE battle via
## battle_start_refused BEFORE any snapshot/context), AC-TBC-01 (evaluate_silent called
## exactly once per fielded Symbot, SILENT — zero synergy_changed), AC-TBC-19 (the enemy
## is instantiated with NO synergy, Rule 8), AC-TBC-02 (the frozen snapshot seeds runtime
## pools from the effective stats). Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeSynergy := preload("res://tests/unit/tbc/fake_synergy_system.gd")

var _cfg: BalanceConfig
var _log
var _controller: BattleController
var _synergy


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_controller = BattleController.new(_cfg, _log)
	_synergy = FakeSynergy.new()


func _player_stats() -> Dictionary:
	# High mobility so a player leads initiative and the loop parks before any enemy acts.
	return {&"structure": 120, &"energy_capacity": 80, &"mobility": 50,
		&"physical_power": 60, &"cooling": 10, &"recharge": 20}


func _loadout(symbot_id: int) -> SymbotLoadout:
	return SymbotLoadout.make(symbot_id, _player_stats(),
		[_basic_move(), null, null, null], [], PartDef.Element.KINETIC, [&"frame_%d" % symbot_id])


func _basic_move() -> MoveDef:
	var m := MoveDef.new()
	m.id = &"basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.energy_cost = 0
	return m


func _enemy_spec() -> Dictionary:
	return {"id": &"husk_walker", "stats": {&"structure": 200, &"armor": 30, &"mobility": 10},
		"core_element": PartDef.Element.KINETIC, "level": 4, "xp_value": 55,
		"completion_bonus_xp": 0, "is_first_boss_defeat": false}


func _three_valid() -> Array:
	return [_loadout(0), _loadout(1), _loadout(2)]


# ---------------------------------------------------------------------------
# AC-TBC-42 — invalid build refuses the whole battle, no context created
# ---------------------------------------------------------------------------

func test_invalid_build_refuses_before_any_snapshot() -> void:
	watch_signals(_controller)
	var bad := _loadout(2)
	bad.is_build_valid = false
	bad.offending_parts = [&"overtier_frame"]

	var started := _controller.start_battle([_loadout(0), bad], _enemy_spec(), BattleController.EncounterType.WILD, _synergy)

	assert_false(started, "start_battle returns false on an invalid fielded build")
	assert_signal_emitted(_controller, "battle_start_refused", "the ONLY invalid-build exit fired")
	var params: Array = get_signal_parameters(_controller, "battle_start_refused")
	assert_eq(params[0], [2], "invalid_symbot_ids carries the offending Symbot id")
	assert_eq(params[1], [&"overtier_frame"], "offending_parts echoed for the UI")
	assert_false(_controller.is_battle_active(), "no battle became active")
	assert_null(_controller.context(), "no BattleContext was created before the gate passed")
	assert_eq(_synergy.evaluate_silent_calls, 0, "refused before ANY synergy snapshot")


# ---------------------------------------------------------------------------
# AC-TBC-01 — evaluate_silent once per Symbot, SILENT (no synergy_changed)
# ---------------------------------------------------------------------------

func test_start_evaluates_silent_once_per_symbot_without_emitting() -> void:
	watch_signals(_synergy)

	var started := _controller.start_battle(_three_valid(), _enemy_spec(), BattleController.EncounterType.WILD, _synergy)

	assert_true(started, "a fully-valid team starts")
	assert_eq(_synergy.evaluate_silent_calls, 3, "evaluate_silent called once per fielded Symbot")
	assert_signal_not_emitted(_synergy, "synergy_changed", "the start pass is SILENT (Rule 2 step 2)")
	assert_true(_controller.is_battle_active(), "battle is active after a successful start")
	assert_eq(_controller.state(), BattleController.BattleState.ACTION_PENDING,
		"the loop parked on the leading player's action")


# ---------------------------------------------------------------------------
# AC-TBC-19 — enemy carries no synergy (Rule 8)
# ---------------------------------------------------------------------------

func test_enemy_instantiated_without_synergy() -> void:
	_controller.start_battle(_three_valid(), _enemy_spec(), BattleController.EncounterType.WILD, _synergy)
	var enemy: Combatant = _controller.context().enemy

	assert_true(enemy.is_enemy, "the enemy Combatant is flagged enemy")
	assert_eq(enemy.synergy_delta, {}, "enemy has an EMPTY synergy delta (Rule 8)")
	assert_eq(enemy.enemy_id, &"husk_walker", "enemy id captured for the payload")
	assert_eq(enemy.max_structure, 200, "enemy structure seeded from its Enemy DB stats")


# ---------------------------------------------------------------------------
# AC-TBC-02 — frozen snapshot seeds full runtime pools
# ---------------------------------------------------------------------------

func test_snapshot_seeds_runtime_pools_at_full() -> void:
	# Symbot 0 gets a synergy delta so the effective pools differ from base (discriminator).
	_synergy.set_canned_delta({&"structure": 30})
	_controller.start_battle(_three_valid(), _enemy_spec(), BattleController.EncounterType.WILD, _synergy)
	var c: Combatant = _controller.context().team[0]

	assert_eq(c.max_structure, 150, "SYN-F4 structure 120 + synergy 30 = 150 (frozen)")
	assert_eq(c.current_structure, 150, "structure pool starts full")
	assert_eq(c.max_energy_capacity, 80, "energy capacity from the frozen snapshot")
	assert_eq(c.current_energy, 80, "energy pool starts full")
	assert_eq(c.current_heat, 0, "heat starts at 0")
