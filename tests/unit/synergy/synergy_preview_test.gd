## Story 005 — preview(): pure read-only hypothetical. No cache write, no emit.
## Covers AC-SYN-08, 13 (A + B), 20 (A + B), 24.
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


# --- AC-SYN-08: preview() is strictly read-only -----------------------------------

func test_preview_does_not_mutate_cache_or_emit() -> void:
	var sys := _sys([Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8})])
	var current := Fixtures.slots([
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]),
	])
	sys.evaluate(current)  # ironclad=3 → armor 8, counter 1

	# Replace slot 0's ironclad part with a kinetic one → hypothetical ironclad=2 → no tier.
	var result := sys.preview(Fixtures.part([&"KINETIC"]), 0, current)

	assert_true(result["stat_delta"].is_empty(), "hypothetical loses the 3-piece")
	assert_true(result["effects"].is_empty())
	assert_eq(sys.cached_bonus_block["stat_delta"][&"armor"], 8, "real cache untouched")
	assert_signal_emit_count(sys, "synergy_changed", 1, "preview emitted nothing")


# --- AC-SYN-13: preview() models both threshold directions ------------------------

func test_preview_models_activation_direction() -> void:
	var sys := _sys([Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6})])
	var current := Fixtures.slots([
		Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]), Fixtures.part([&"KINETIC"]),
	])  # VOLT=2 (below threshold)
	sys.evaluate(current)  # empty cache, counter 1

	# Replace slot 2's KINETIC with a VOLT part → hypothetical VOLT=3 → activates.
	var result := sys.preview(Fixtures.part([&"VOLT"]), 2, current)

	assert_eq(result["stat_delta"][&"energy_power"], 6, "hypothetical VOLT=3 activates 3-piece")
	assert_true(sys.cached_bonus_block["stat_delta"].is_empty(), "real cache still empty")
	assert_signal_emit_count(sys, "synergy_changed", 1)


func test_preview_models_deactivation_direction_subtracts_displaced_tags() -> void:
	var sys := _sys([Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6})])
	var current := _volt_parts(3)  # VOLT=3 active
	sys.evaluate(current)
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6)

	# Replace slot 0's VOLT with KINETIC → hypothetical VOLT=2 → deactivates.
	var result := sys.preview(Fixtures.part([&"KINETIC"]), 0, current)

	assert_true(result["stat_delta"].is_empty(),
		"displaced part's tags subtracted (FAIL energy_power==6 = add-only delta shortcut)")
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6, "real cache untouched")
	assert_signal_emit_count(sys, "synergy_changed", 1)


# --- AC-SYN-20: out-of-range target_slot returns empty + logs (Rule 9) -------------

func test_preview_negative_slot_returns_empty_and_logs() -> void:
	var sys := _sys([
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {&"energy_power": 12}),
	])
	var current := _volt_parts(5)
	sys.evaluate(current)  # energy_power 18
	var warns_before: int = _log.warns.size()

	var result := sys.preview(Fixtures.part([&"KINETIC"]), -1, current)

	assert_true(result["stat_delta"].is_empty(), "negative index does NOT wrap to slot 7")
	assert_true(result["effects"].is_empty())
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 18, "cache intact")
	assert_signal_emit_count(sys, "synergy_changed", 1)
	assert_gt(_log.warns.size(), warns_before, "content error logged")


func test_preview_slot_past_last_returns_empty_and_logs() -> void:
	var sys := _sys([
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {&"energy_power": 12}),
	])
	var current := _volt_parts(5)
	sys.evaluate(current)
	var warns_before: int = _log.warns.size()

	var result := sys.preview(Fixtures.part([&"KINETIC"]), 8, current)

	assert_true(result["stat_delta"].is_empty())
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 18, "cache intact")
	assert_gt(_log.warns.size(), warns_before, "content error logged")


# --- AC-SYN-24: null candidate models unequip, valid input, no error (EC-SYN-14) ----

func test_preview_null_candidate_models_unequip_without_logging() -> void:
	var sys := _sys([Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6})])
	var current := _volt_parts(3)  # VOLT=3 active
	sys.evaluate(current)
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6)
	var warns_before: int = _log.warns.size()

	# null at slot 0 → unequip → hypothetical VOLT=2 → deactivates.
	var result := sys.preview(null, 0, current)

	assert_true(result["stat_delta"].is_empty(), "null candidate honored (not ignored)")
	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6, "real cache untouched")
	assert_signal_emit_count(sys, "synergy_changed", 1)
	assert_eq(_log.warns.size(), warns_before, "null candidate is VALID — no content error")
