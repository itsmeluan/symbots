## TBC Story 001 / 014 — FSM host, teardown, and the battle_ended contract.
##
## Covers AC-TBC-35 (is_battle_active gating; submit_action is a guarded no-op outside a
## player decision point; synchronous teardown drops the context — WeakRef-verified),
## AC-TBC-31 (the 8-field battle_ended fires on VICTORY, non-confusable with the 2-field
## WORLD signal), AC-TBC-32 (fired_break_events is a de-duplicated set — VICTORY carries
## it, DEFEAT/FLED carry {}). Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeSynergy := preload("res://tests/unit/tbc/fake_synergy_system.gd")

var _cfg: BalanceConfig
var _log
var _bc: BattleController


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_bc = BattleController.new(_cfg, _log)


func _killer_loadout() -> SymbotLoadout:
	# physical_power 100 so a STANDARD basic attack lands 100 on a 0-armor foe.
	var m := MoveDef.new()
	m.id = &"basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = PartDef.Element.KINETIC
	m.energy_cost = 0
	return SymbotLoadout.make(0, {&"structure": 120, &"energy_capacity": 80, &"mobility": 50,
		&"physical_power": 100}, [m, null, null, null], [], PartDef.Element.KINETIC, [&"p0"])


func _fragile_enemy() -> Dictionary:
	# structure 10, armor 0, mobility 5 → the player leads and one 100-hit kills it.
	return {"id": &"husk_walker", "stats": {&"structure": 10, &"armor": 0, &"mobility": 5},
		"core_element": PartDef.Element.KINETIC, "level": 4, "xp_value": 55,
		"completion_bonus_xp": 12, "is_first_boss_defeat": false}


func _kill_action() -> Dictionary:
	var m := MoveDef.new()
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = PartDef.Element.KINETIC
	m.energy_cost = 0
	return {"type": BattleController.ActionType.MOVE, "move": m, "part_heat_generation": 0}


# ---------------------------------------------------------------------------
# AC-TBC-35 — is_battle_active gating + submit_action guard
# ---------------------------------------------------------------------------

func test_is_battle_active_toggles_and_submit_action_is_guarded() -> void:
	assert_false(_bc.is_battle_active(), "no battle before start")

	# Guarded no-op: submit before any battle must not crash or change state.
	_bc.submit_action({"type": BattleController.ActionType.MOVE})
	assert_false(_bc.is_battle_active(), "a stray submit_action before start is ignored")

	_bc.start_battle([_killer_loadout()], _fragile_enemy(), BattleController.EncounterType.WILD, FakeSynergy.new())
	assert_true(_bc.is_battle_active(), "active after a successful start")
	assert_eq(_bc.state(), BattleController.BattleState.ACTION_PENDING, "parked on the player's action")


# ---------------------------------------------------------------------------
# AC-TBC-31 — victory fires the 8-field battle_ended
# ---------------------------------------------------------------------------

func test_victory_emits_eight_field_battle_ended() -> void:
	watch_signals(_bc)
	_bc.start_battle([_killer_loadout()], _fragile_enemy(), BattleController.EncounterType.WILD, FakeSynergy.new())

	_bc.submit_action(_kill_action())

	assert_signal_emitted(_bc, "battle_ended", "the killing blow ends the battle")
	var p: Array = get_signal_parameters(_bc, "battle_ended")
	assert_eq(p.size(), 8, "8-field COMBAT payload (non-confusable with the 2-field WORLD signal)")
	assert_eq(p[0], BattleController.Outcome.VICTORY, "outcome VICTORY")
	assert_eq(p[1], &"husk_walker", "enemy_id")
	assert_eq(p[3], 55, "xp_value")
	assert_eq(p[4], 12, "completion_bonus_xp")
	assert_eq(p[6], 4, "enemy_level")
	assert_eq(p[7], [0], "deployed_symbot_ids")
	assert_false(_bc.is_battle_active(), "battle deactivated after the cascade")


# ---------------------------------------------------------------------------
# AC-TBC-32 — fired_break_events dedup; VICTORY carries the set
# ---------------------------------------------------------------------------

func test_break_events_are_deduplicated_on_victory() -> void:
	watch_signals(_bc)
	_bc.start_battle([_killer_loadout()], _fragile_enemy(), BattleController.EncounterType.WILD, FakeSynergy.new())

	# 2 × arm_broken + 1 × head_cracked → a 2-element set (Dictionary-as-set dedup).
	_bc.note_break_event(&"arm_broken")
	_bc.note_break_event(&"arm_broken")
	_bc.note_break_event(&"head_cracked")

	_bc.submit_action(_kill_action())

	var p: Array = get_signal_parameters(_bc, "battle_ended")
	var breaks: Dictionary = p[2]
	assert_eq(breaks.size(), 2, "arm_broken deduped: {arm_broken, head_cracked}")
	assert_true(breaks.has(&"arm_broken") and breaks.has(&"head_cracked"), "both distinct events present")


# ---------------------------------------------------------------------------
# AC-TBC-35 — synchronous teardown frees the BattleContext (no cycle)
# ---------------------------------------------------------------------------

func test_teardown_frees_context_after_battle_ends() -> void:
	_bc.start_battle([_killer_loadout()], _fragile_enemy(), BattleController.EncounterType.WILD, FakeSynergy.new())
	var wr: WeakRef = weakref(_bc.context())  # do NOT retain the context in a lingering local

	_bc.submit_action(_kill_action())

	assert_null(_bc.context(), "the controller dropped its context reference")
	assert_null(wr.get_ref(), "the BattleContext was freed — no back-reference cycle")
	assert_false(_bc.is_battle_active(), "is_battle_active cleared after _ctx (Story 001 order)")
