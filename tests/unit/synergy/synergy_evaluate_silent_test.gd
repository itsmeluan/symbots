## Story 004 — evaluate_silent(): same compute + cache as evaluate(), NO emit; no self-lock.
## Covers AC-SYN-14 (Scenario A + B), 25.
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


func _volt_parts(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(Fixtures.part([&"VOLT"]))
	return Fixtures.slots(out)


# --- AC-SYN-14 Scenario A: single-tag cumulative via silent path, no emit -----------

func test_evaluate_silent_computes_cumulative_without_emitting() -> void:
	var tiers := [
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {&"energy_power": 12}, [&"volt_test"]),
	]
	var sys := _sys(tiers)

	sys.evaluate_silent(_volt_parts(5))

	assert_signal_emit_count(sys, "synergy_changed", 0, "silent path NEVER emits")
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 18, "cached (6+12)")
	var effects: Array[StringName] = [&"volt_test"]
	assert_eq(sys.cached_bonus_block["effects"], effects)


# --- AC-SYN-14 Scenario B: combined path identical to evaluate() (no divergence) ----

func test_evaluate_silent_combined_matches_evaluate() -> void:
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

	sys.evaluate_silent(parts)

	assert_signal_emit_count(sys, "synergy_changed", 0)
	var delta = sys.cached_bonus_block["stat_delta"]
	assert_eq(delta[&"armor"], 13, "identical to evaluate() (8+5)")
	assert_eq(delta[&"energy_power"], 10, "identical to evaluate() (6+4)")


# --- AC-SYN-25: evaluate() after evaluate_silent() overwrites cache (no self-lock) --

func test_evaluate_after_silent_overwrites_cache_not_frozen() -> void:
	var sys := _sys([
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {&"energy_power": 12}),
	])

	sys.evaluate_silent(_volt_parts(5))
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 18, "silent cached VOLT=5")

	sys.evaluate(Fixtures.slots([]))  # empty build

	assert_true(sys.cached_bonus_block["stat_delta"].is_empty(),
		"cache replaced, NOT frozen (FAIL 18 = self-locked)")
	assert_signal_emit_count(sys, "synergy_changed", 1, "the evaluate() emitted; silent did not")
