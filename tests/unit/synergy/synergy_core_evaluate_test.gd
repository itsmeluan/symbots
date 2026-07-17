## Story 001 — SynergySystem core: SYN-F1 counting, SYN-F2 activation, evaluate() + signal.
## Covers AC-SYN-01, 04, 07, 11, 18, 19, 21, 22, 23.
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


# --- AC-SYN-01: single-tag 3-piece activation -------------------------------------

func test_evaluate_single_tag_three_piece_activates() -> void:
	# Arrange
	var tiers := [
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8}),
	]
	var sys := _sys(tiers)
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"KINETIC"]), Fixtures.part([&"ironclad", &"KINETIC"]),
		Fixtures.part([&"ironclad", &"KINETIC"]), Fixtures.part([&"KINETIC"]),
		Fixtures.part([&"KINETIC"]), Fixtures.part([&"KINETIC"]),
		Fixtures.part([&"KINETIC"]), Fixtures.part([&"KINETIC"]),
	])

	# Act
	sys.evaluate(parts)

	# Assert
	assert_eq(sys.cached_bonus_block["stat_delta"][&"armor"], 8, "Ironclad 3-piece armor +8")
	assert_eq(sys.cached_bonus_block["stat_delta"].size(), 1, "no other stat key present")
	assert_signal_emitted(sys, "synergy_changed")


# --- AC-SYN-04: wild parts contribute to element tag only -------------------------

func test_evaluate_wild_parts_count_element_tag_only() -> void:
	# Registry HAS a manufacturer + combined tier so their ABSENCE from active_synergies
	# proves manufacturer tags were never counted (they are absent from every part).
	var tiers := [
		Fixtures.tier(&"thermal_3_piece", [[&"THERMAL", 3]], {&"armor": 8}),
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 99}),
		Fixtures.tier(&"ironclad_volt_3_piece", [[&"ironclad", 3], [&"VOLT", 3]], {&"armor": 99}),
	]
	var sys := _sys(tiers)
	var parts := Fixtures.slots([
		Fixtures.part([&"THERMAL"]), Fixtures.part([&"THERMAL"]),
		Fixtures.part([&"THERMAL"]), Fixtures.part([&"THERMAL"]),
	])

	sys.evaluate(parts)

	assert_eq(sys.active_synergies, [&"thermal_3_piece"] as Array[StringName],
		"only the element tier — no manufacturer/combined id")
	assert_eq(sys.active_synergies.size(), 1)
	assert_eq(sys.cached_bonus_block["stat_delta"], {&"armor": 8})


# --- AC-SYN-07: empty build emits signal with empty, never-null block --------------

func test_evaluate_empty_build_emits_empty_nonnull_block() -> void:
	var sys := _sys([Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8})])

	sys.evaluate(Fixtures.slots([]))

	assert_signal_emit_count(sys, "synergy_changed", 1, "always-emit once")
	var payload = get_signal_parameters(sys, "synergy_changed")
	assert_not_null(payload[0], "received active_synergies is not null (Rule 7)")
	assert_typeof(payload[0], TYPE_ARRAY)
	assert_eq(payload[0].size(), 0, "empty build → empty active list")
	assert_true(payload[1]["stat_delta"].is_empty(), "empty stat_delta")
	assert_true(payload[1]["effects"].is_empty(), "empty effects")


# --- AC-SYN-11: evaluate() always emits, even on identical input -------------------

func test_evaluate_always_emits_on_repeat_call() -> void:
	var sys := _sys([Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6})])
	var parts := Fixtures.slots([
		Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]),
	])

	sys.evaluate(parts)
	var block_after_first = sys.cached_bonus_block["stat_delta"].duplicate()
	sys.evaluate(parts)

	assert_signal_emit_count(sys, "synergy_changed", 2, "emitted on both identical calls")
	assert_eq(sys.cached_bonus_block["stat_delta"], block_after_first, "cache unchanged")


# --- AC-SYN-18: wrong-length arrays tolerated (EC-SYN-10) -------------------------

func test_evaluate_short_array_treats_missing_as_null() -> void:
	var sys := _sys([Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6})])

	# 5 entries — indices 5–7 missing, treated null.
	sys.evaluate([
		Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]),
		null, null,
	])

	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6, "VOLT=3 → 3-piece")
	assert_gt(_log.warns.size(), 0, "wrong-length logged")


func test_evaluate_long_array_ignores_indices_beyond_seven() -> void:
	var sys := _sys([Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6})])

	# 10 entries — VOLT parts at 8–9 must NOT count (would tip VOLT to 5).
	sys.evaluate([
		Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]),
		null, null, null, null, null,
		Fixtures.part([&"VOLT"]), Fixtures.part([&"VOLT"]),
	])

	assert_eq(sys.cached_bonus_block["stat_delta"][&"energy_power"], 6, "only 0–7 counted → VOLT=3")
	assert_gt(_log.warns.size(), 0, "wrong-length logged")


# --- AC-SYN-19: empty / null synergy_tags contributes no counts (EC-SYN-07) --------

func test_evaluate_empty_tag_array_contributes_nothing() -> void:
	var sys := _sys([Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8})])
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([]),  # slot 3: empty tags
	])

	sys.evaluate(parts)

	assert_eq(sys.cached_bonus_block["stat_delta"][&"armor"], 8, "ironclad=3 (slot 3 inert)")
	assert_eq(sys.cached_bonus_block["stat_delta"].size(), 1)
	assert_eq(sys.active_synergies.size(), 1)


func test_evaluate_null_tag_field_treated_as_empty() -> void:
	var sys := _sys([Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8})])
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part(null),  # slot 3: null field
	])

	sys.evaluate(parts)

	assert_eq(sys.cached_bonus_block["stat_delta"][&"armor"], 8, "null tags == [] (no crash)")
	assert_eq(sys.active_synergies.size(), 1)


# --- AC-SYN-21: duplicate tags within a part inflate the count (EC-SYN-11) ----------

func test_evaluate_duplicate_within_part_tags_inflate_count() -> void:
	var sys := _sys([
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {&"armor": 8}),
		Fixtures.tier(&"ironclad_5_piece", [[&"ironclad", 5]], {&"armor": 20}),
	])
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"ironclad", &"VOLT"]),
	])

	# ironclad = 6 (2 per part × 3 parts) → both tiers active.
	sys.evaluate(parts)

	assert_true(sys.active_synergies.has(&"ironclad_5_piece"), "count 6 ≥ 5")
	assert_eq(sys.cached_bonus_block["stat_delta"][&"armor"], 28, "8 + 20, no within-part dedup")


# --- AC-SYN-22 / 23: vacuous tiers skipped and logged (EC-SYN-12 / 13) -------------

func test_evaluate_tier_with_empty_requirements_skipped_and_logged() -> void:
	var sys := _sys([Fixtures.tier(&"bad_tier", [], {&"armor": 8})])

	sys.evaluate(Fixtures.slots([]))  # the empty build — the strongest fixture

	assert_eq(sys.active_synergies.size(), 0, "bad_tier NOT activated (no vacuous truth)")
	assert_true(sys.cached_bonus_block["stat_delta"].is_empty())
	assert_signal_emit_count(sys, "synergy_changed", 1)
	assert_true(_log.warned_tier(&"bad_tier"), "content error names bad_tier")


func test_evaluate_tier_with_zero_min_count_skipped_and_logged() -> void:
	var sys := _sys([Fixtures.tier(&"zero_tier", [[&"VOLT", 0]], {&"armor": 8})])

	sys.evaluate(Fixtures.slots([]))

	assert_eq(sys.active_synergies.size(), 0, "zero_tier NOT activated despite 0 ≥ 0")
	assert_true(sys.cached_bonus_block["stat_delta"].is_empty())
	assert_signal_emit_count(sys, "synergy_changed", 1)
	assert_true(_log.warned_tier(&"zero_tier"), "content error names zero_tier")
