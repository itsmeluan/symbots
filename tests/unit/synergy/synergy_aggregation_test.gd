## Story 002 — SYN-F3 stat_delta aggregation: cumulative + combined + blind sum.
## Covers AC-SYN-02, 03, 09, 15, 17, 27.
extends GutTest

const Fixtures = preload("res://tests/unit/synergy/synergy_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/synergy/spy_log_sink.gd")

var _log


func before_each() -> void:
	_log = SpyLogSink.new()


func _sys(tiers: Array) -> SynergySystem:
	var s := SynergySystem.new(tiers, _log)
	watch_signals(s)
	return s


# Shared VOLT cumulative pair (energy_power 6 + 12).
func _volt_pair() -> Array:
	return [
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {&"energy_power": 12}),
	]


func _volt_parts(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(Fixtures.part([&"VOLT"]))
	return Fixtures.slots(out)


# --- AC-SYN-02: cumulative tiers stack, not replace ------------------------------

func test_aggregate_cumulative_tiers_stack_additively() -> void:
	var sys := _sys(_volt_pair())

	sys.evaluate(_volt_parts(5))  # VOLT=5 → both tiers active

	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 18,
		"6 + 12 cumulative (FAIL 12 = non-cumulative)")


# --- AC-SYN-03: combined synergy stacks on top of constituents --------------------

func test_aggregate_combined_synergy_stacks_with_constituents() -> void:
	var tiers := [
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8}),
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"ironclad_volt_3_piece", [[&"ironclad", 3], [&"VOLT", 3]],
			{&"armor": 5, &"energy_power": 4}),
	]
	var sys := _sys(tiers)
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"KINETIC"]),
		Fixtures.part([&"KINETIC"]), Fixtures.part([&"KINETIC"]),
		Fixtures.part([&"KINETIC"]), Fixtures.part([&"KINETIC"]),
	])

	sys.evaluate(parts)  # ironclad=3, VOLT=3 → all three active

	var delta = sys.cached_bonus_block["stat_delta"]
	assert_eq(delta[&"armor"], 13, "8 + 5 (constituent + combined)")
	assert_eq(delta[&"energy_power"], 10, "6 + 4")


func test_aggregate_combined_inactive_when_second_requirement_unmet() -> void:
	var tiers := [
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8}),
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"ironclad_volt_3_piece", [[&"ironclad", 3], [&"VOLT", 3]],
			{&"armor": 5, &"energy_power": 4}),
	]
	var sys := _sys(tiers)
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"KINETIC"]), Fixtures.part([&"ironclad", &"KINETIC"]),
		Fixtures.part([&"ironclad", &"KINETIC"]),
	])

	sys.evaluate(parts)  # ironclad=3, VOLT=0 → only ironclad_3

	assert_eq(sys.cached_bonus_block["stat_delta"], {&"armor": 8},
		"combined NOT active (VOLT=0); FAIL 13")


# --- AC-SYN-09: 5-piece boundary sits at exactly 5 (off-by-one guard) -------------

func test_aggregate_five_piece_boundary_off_by_one() -> void:
	var sys := _sys(_volt_pair())

	sys.evaluate(_volt_parts(4))
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6, "VOLT=4 → 3-piece only")

	sys.evaluate(_volt_parts(5))
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 18, "VOLT=5 → cumulative")


# --- AC-SYN-15: deactivation via recompute-from-scratch (no stale cache) -----------

func test_aggregate_deactivation_recomputes_without_stale_cache() -> void:
	var sys := _sys(_volt_pair())

	sys.evaluate(_volt_parts(5))
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 18, "VOLT=5")

	sys.evaluate(_volt_parts(4))
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6,
		"VOLT=4 → 5-piece dropped, 3-piece survives (FAIL 18 stale / 0 over-drop)")
	assert_signal_emit_count(sys, "synergy_changed", 2)


# --- AC-SYN-17: unknown stat key survives blind aggregation (EC-SYN-06) ------------

func test_aggregate_unknown_stat_key_passes_through() -> void:
	var sys := _sys([Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"speed": 10})])

	sys.evaluate(_volt_parts(3))

	assert_eq(sys.cached_bonus_block["stat_delta"][&"speed"], 10,
		"unknown key summed verbatim, no schema lookup, no crash")
	assert_signal_emit_count(sys, "synergy_changed", 1)


# --- AC-SYN-27: seven simultaneously active tiers accumulate cleanly (EC-SYN-02) ----

func test_aggregate_seven_active_tiers_no_merge_collision() -> void:
	var tiers := [
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8}),
		Fixtures.tier(&"ironclad_5_piece", [[&"ironclad", 5]], {&"armor": 20}),
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {&"energy_power": 12}),
		Fixtures.tier(&"ironclad_volt_3_piece", [[&"ironclad", 3], [&"VOLT", 3]],
			{&"armor": 5, &"energy_power": 4}),
		Fixtures.tier(&"kinetic_3_piece", [[&"KINETIC", 3]], {&"armor": 3}),
		Fixtures.tier(&"kinetic_volt_3_piece", [[&"KINETIC", 3], [&"VOLT", 3]], {&"armor": 4}),
	]
	var sys := _sys(tiers)
	# ironclad=8, VOLT=5, KINETIC=3 across 8 full slots.
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"KINETIC"]),
		Fixtures.part([&"ironclad", &"KINETIC"]), Fixtures.part([&"ironclad", &"KINETIC"]),
	])

	sys.evaluate(parts)

	var delta = sys.cached_bonus_block["stat_delta"]
	assert_eq(sys.active_synergies.size(), 7, "all 7 tiers active")
	assert_eq(delta[&"armor"], 40, "8+20+5+3+4 (armor written by 5 tiers, no overwrite)")
	assert_eq(delta[&"energy_power"], 22, "6+12+4")
