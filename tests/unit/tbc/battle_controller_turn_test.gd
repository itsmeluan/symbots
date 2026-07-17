## TBC Story 005 / 006 — turn-start anatomy, heat decay, recharge, Burn tick, overheat.
##
## Covers AC-TBC-07/08 (ordered turn-start: cooling decay → TBC-F2 recharge → Burn tick
## LAST; enemies skip decay + recharge), AC-TBC-09 (a move's heat gain trips OVERHEATED
## at the threshold with `floor(max_structure × 10%)` recoil; THERMAL adds +5), AC-TBC-11
## (the overheated turn resets heat flat, still recharges, and SKIPS the action phase).
## begin_turn / apply_move_heat read only cfg — no battle context. Framework: GUT · 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log
var _bc: BattleController


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_bc = BattleController.new(_cfg, _log)


func _player() -> Combatant:
	# cooling 10, recharge 20, energy_capacity 95, structure 155, processing 72.
	var c := Combatant.make_player(0, 0, {&"structure": 155, &"energy_capacity": 95,
		&"cooling": 10, &"recharge": 20, &"processing": 72}, {}, {}, PartDef.Element.KINETIC)
	return c


# ---------------------------------------------------------------------------
# AC-TBC-07/08 — ordered turn-start bookkeeping (players)
# ---------------------------------------------------------------------------

func test_player_turn_start_decays_heat_recharges_then_burns() -> void:
	var c := _player()
	c.current_heat = 30
	c.current_energy = 40
	# Burn applied by a processing-72 attacker → burn_damage = max(2, floor(5.7601)) = 5.
	c.statuses.apply(StatusInstance.Type.BURN, 72, 3, _cfg)

	var r := _bc.begin_turn(c)

	assert_eq(c.current_heat, 20, "(a) heat −= cooling 10: 30 → 20")
	assert_eq(c.current_energy, 70, "(b) TBC-F2 recharge: min(95, 40+10+20) = 70")
	assert_eq(r["burn_damage"], 5, "(c) Burn tick LAST: processing 72 → 5")
	assert_eq(c.current_structure, 150, "Burn reduced structure 155 → 150 (bypasses DF-1)")
	assert_false(r["skipped_action"], "a normal turn does not skip the action phase")


func test_enemy_turn_start_skips_decay_and_recharge() -> void:
	var e := Combatant.make_enemy(&"foe", {&"structure": 100, &"mobility": 30}, PartDef.Element.KINETIC)
	e.current_heat = 30
	e.current_energy = 10

	_bc.begin_turn(e)

	assert_eq(e.current_heat, 30, "enemy heat is NOT decayed (players-only bookkeeping)")
	assert_eq(e.current_energy, 10, "enemy energy is NOT recharged")


# ---------------------------------------------------------------------------
# AC-TBC-09 — move heat gain, overheat trip, self-damage, THERMAL bonus
# ---------------------------------------------------------------------------

func test_move_heat_trips_overheat_with_self_damage() -> void:
	var c := _player()  # max_structure 155
	c.current_heat = 95

	var res := _bc.apply_move_heat(c, 10, false)  # 95 + 10 = 105 → clamp 100 → overheat

	assert_eq(c.current_heat, 100, "heat clamps at the overheat threshold")
	assert_true(res["overheated"], "crossing the threshold trips OVERHEATED")
	assert_eq(res["self_damage"], 15, "recoil floor(155 × 0.10) = floor(15.5001) = 15 (round → 16)")
	assert_eq(c.current_structure, 140, "self-damage reduced structure 155 → 140")
	assert_true(c.is_overheated, "the overheated flag is set for the next turn")


func test_thermal_bonus_is_the_difference_between_safe_and_overheat() -> void:
	var cool := _player()
	cool.current_heat = 92
	var hot := _player()
	hot.current_heat = 92

	# Same base gain 5: non-THERMAL stays at 97 (safe); THERMAL adds +5 → 100 (overheat).
	var safe := _bc.apply_move_heat(cool, 5, false)
	var over := _bc.apply_move_heat(hot, 5, true)

	assert_false(safe["overheated"], "92 + 5 = 97 < 100 — no overheat")
	assert_eq(cool.current_heat, 97, "non-THERMAL heat lands at 97")
	assert_true(over["overheated"], "92 + 5 + THERMAL 5 = 102 → clamp 100 → overheat")


# ---------------------------------------------------------------------------
# AC-TBC-11 — overheated turn resets heat flat, recharges, skips the action
# ---------------------------------------------------------------------------

func test_overheated_turn_resets_heat_and_skips_action() -> void:
	var c := _player()
	c.current_heat = 100
	c.current_energy = 40
	c.is_overheated = true

	var r := _bc.begin_turn(c)

	assert_eq(c.current_heat, 20, "overheated turn resets heat FLAT to 20 (no cooling decay)")
	assert_true(r["skipped_action"], "the action phase is skipped this turn")
	assert_eq(c.current_energy, 70, "still recharges during the overheated turn: min(95, 40+10+20)")
	assert_false(c.is_overheated, "the flag is consumed — the penalty is a single turn")
