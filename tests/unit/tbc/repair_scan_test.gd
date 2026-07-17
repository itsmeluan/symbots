## TBC Story 010 — Repair (TBC-F6) & SCAN turn-consuming no-op.
##
## Covers AC-TBC-27 (repair floor discriminators), AC-TBC-16 (overheal caps at
## max_structure, Energy + heat costs ALWAYS paid — even at exactly full), AC-TBC-39
## (SCAN pays costs, consumes the turn, applies no damage/status, never crashes).
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log
var _resolver: BattleResolver


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_resolver = BattleResolver.new(_cfg, _log)


func _repair_move(energy_cost: int) -> MoveDef:
	var m := MoveDef.new()
	m.behavior = MoveDef.Behavior.REPAIR
	m.energy_cost = energy_cost
	return m


# ---------------------------------------------------------------------------
# AC-TBC-27 — TBC-F6 repair floor (discriminating extremes)
# ---------------------------------------------------------------------------

func test_repair_amount_floor_discriminators() -> void:
	assert_eq(BattleFormulas.repair_amount(45, _cfg), 12, "ep 45 → floor(12.6501)=12 (round → 13)")
	assert_eq(BattleFormulas.repair_amount(150, _cfg), 30, "ep 150 → floor(30.5001)=30 (round → 31)")
	assert_eq(BattleFormulas.repair_amount(0, _cfg), 5, "REPAIR_MIN = 5 for zero-investment")


# ---------------------------------------------------------------------------
# AC-TBC-16 — cap at max_structure, costs still paid (EC-TBC-10)
# ---------------------------------------------------------------------------

func test_repair_caps_at_max_structure_and_pays_costs() -> void:
	var user := Combatant.make_player(0, 0, {&"energy_power": 45, &"structure": 100}, {}, {}, null)
	user.current_structure = 98
	user.current_energy = 60
	user.current_heat = 20

	var amount := _resolver.resolve_repair_move(user, _repair_move(15), 8)

	assert_eq(amount, 12, "TBC-F6 repair amount at ep 45 = 12")
	assert_eq(user.current_structure, 100, "min(100, 98+12) = 100 — overheal discarded, not rejected")
	assert_eq(user.current_energy, 45, "Energy cost 15 still paid: 60 → 45")
	assert_eq(user.current_heat, 28, "heat gain 8 still applied: 20 → 28")


func test_repair_at_exactly_full_is_legal_and_still_costs() -> void:
	var user := Combatant.make_player(0, 0, {&"energy_power": 45, &"structure": 100}, {}, {}, null)
	# current_structure already == max_structure (100) from the factory.
	user.current_energy = 60
	user.current_heat = 20

	_resolver.resolve_repair_move(user, _repair_move(15), 8)

	assert_eq(user.current_structure, 100, "still full — no overflow past max_structure")
	assert_eq(user.current_energy, 45, "wasteful but the Energy cost still applies")
	assert_eq(user.current_heat, 28, "heat still generated at full structure")


func test_repair_scales_on_effective_energy_power() -> void:
	# ep 150 (SYN-F4 max: base 110 + synergy 40) → repair 30, capped into a damaged pool.
	var user := Combatant.make_player(0, 0, {&"energy_power": 110, &"structure": 300},
		{&"energy_power": 40}, {}, null)
	user.current_structure = 100
	user.current_energy = 80

	var amount := _resolver.resolve_repair_move(user, _repair_move(0), 0)

	assert_eq(amount, 30, "effective ep 150 → repair 30 (SYN-F4 composed, not base 110→23)")
	assert_eq(user.current_structure, 130, "100 + 30, well under the 300 cap")


# ---------------------------------------------------------------------------
# AC-TBC-39 — SCAN turn-consuming no-op (EC-TBC-16)
# ---------------------------------------------------------------------------

func test_scan_pays_costs_and_is_a_harmless_no_op() -> void:
	var user := Combatant.make_player(0, 0, {&"structure": 100}, {}, {}, null)
	user.current_energy = 50
	user.current_heat = 10
	var structure_before := user.current_structure

	var scan := MoveDef.new()
	scan.behavior = MoveDef.Behavior.SCAN
	scan.energy_cost = 8

	_resolver.resolve_scan_move(user, scan, 6)  # part heat_generation 6

	assert_eq(user.current_energy, 42, "Energy paid: 50 → 42 (a free SCAN would be a FAIL)")
	assert_eq(user.current_heat, 16, "heat gained: 10 → 16")
	assert_eq(user.current_structure, structure_before, "no damage — structure unchanged")
	assert_eq(user.statuses.count(), 0, "no status applied by a SCAN")
