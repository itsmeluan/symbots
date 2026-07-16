## Enemy-DB Story 006 — ContentValidator break-region family.
##
## Covers all six Story-006 checks on [method EnemyValidator._check_enemy_break_regions]:
##
##   AC-1  (TR-edb-002)  stored == derived via BreakHpFormula.derive_break_hp.
##          All 7 AC-ED-08 divergent-input fixtures: authored-correct break_hp passes,
##          off-by-one fails. Key epsilon parity case: structure=180, fraction=0.35,
##          break_hp=63 (62 must fail — proves formula's +0.0001 nudge is in play).
##   AC-2  (EDB-3)       break_hp < structure: 100/100 → error, 100/99 → clean.
##   AC-3  (TR-edb-014)  region_fraction bounds [0.15,0.55] with ±1e-9 tolerance:
##          min and max boundaries → clean; just outside max → error.
##          A naked-`==` or >`/`<` impl without tolerance mis-flags legal boundaries.
##   AC-4  (TR-edb-004, TR-edb-021 / EC-ED-07 / AC-ED-20)
##          Same region_id → error; same break_event distinct region_id → ZERO errors.
##          KEY DISCRIMINATOR: a naive "all region fields unique" impl fails the
##          shared-break_event positive case (AC-ED-20 regression guard).
##   AC-5  (TR-edb-022)  ≥1 region required: break_regions=[] → error.
##   AC-6  (EDB-3 loot_connected) Orphan region: break_event resolves to no
##          loot_pool entry → error.
##
## Deterministic, in-memory catalogs, no file I/O. GUT · Godot 4.7.
##
## GDD source for region_fraction bounds (Tuning Knobs section, enemy-database.md):
##   REGION_FRACTION_MIN = 0.15  (safe range 0.10–0.20)
##   REGION_FRACTION_MAX = 0.55  (safe range 0.45–0.60)
##
## AC-ED-08 7 divergent inputs (python3-verified 2026-07-16):
##   (100, 0.29, 29)  — off-by-one without eps: 28
##   (180, 0.35, 63)  — off-by-one without eps: 62  ← epsilon parity case
##   (200, 0.29, 58)  — off-by-one without eps: 57
##   (300, 0.41, 123) — off-by-one without eps: 122
##   (340, 0.35, 119) — off-by-one without eps: 118
##   (360, 0.35, 126) — off-by-one without eps: 125
##   (400, 0.29, 116) — off-by-one without eps: 115
extends GutTest

const SpyLogSink := preload("res://tests/unit/enemy_database/spy_log_sink.gd")

var _spy: SpyLogSink

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

## Base well-formed WILD enemy, no break regions by default (tests set them).
func _enemy(id: StringName = &"test_enemy") -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Test Enemy"
	e.enemy_class  = EnemyDef.EnemyClass.WILD
	e.tier         = 1
	e.stats        = {
		"structure": 100,
		"armor": 10, "resistance": 10,
		"physical_power": 20, "energy_power": 10,
		"mobility": 15, "processing": 15,
		"cooling": 0, "energy_capacity": 0, "recharge": 0,
		"output_power": 0,
	}
	e.skills       = [&"basic_slash"]
	e.ai_profile   = &"AGGRESSIVE"
	e.flavor_text  = "A test enemy for Story 006."
	e.break_regions = []
	e.loot_pool    = []
	# Story 009: level 1 in range; xp_value = CP-F4 (35 + 1×10) × 1 = 45 (WILD).
	e.level        = 1
	e.xp_value     = XpRewardFormula.derive_xp_value(1, EnemyDef.EnemyClass.WILD)
	return e


## A minimal valid break region linking to `break_event`.
## [param structure] is the enemy's structure stat — break_hp derived via EDB-1.
## [param fraction] is the authored region_fraction (must be in [0.15, 0.55]).
## [param event] is the break_event value (must match a loot_pool entry).
func _region(rid: String, fraction: float, structure: int, event: String = "part_broken") -> Dictionary:
	var break_hp: int = BreakHpFormula.derive_break_hp(structure, fraction)
	return {
		"region_id": rid,
		"region_fraction": fraction,
		"break_hp": break_hp,
		"break_event": event,
	}


## A minimal loot_pool entry that satisfies connectivity for `event`.
func _loot_entry(event: String = "part_broken") -> Dictionary:
	return {"id": "some_part", "drop_condition": event, "enabled": true}


## An always-eligible (floor) loot entry with a distinct id and no break gating.
## Used to pad pools past the Story-008 harvest-decision floor (loot > regions)
## without adding another break-region dependency.
func _floor_loot(id: String) -> Dictionary:
	return {"id": id, "drop_condition": "", "enabled": true}


## Run validation against one enemy. Provides a stub PartCatalog to satisfy
## the validator's mandatory catalog check.
func _run(enemy: EnemyDef) -> Dictionary:
	var catalog := EnemyCatalog.new()
	catalog.entries = [enemy]
	var catalogs := ContentCatalogs.new()
	catalogs.parts   = PartCatalog.new()
	catalogs.enemies = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


## True if any error with the given code was logged.
func _logged(code: StringName) -> bool:
	for e: Dictionary in _spy.errors:
		if e["code"] == code:
			return true
	return false


## True if any warning with the given code was logged.
func _warned(code: StringName) -> bool:
	for w: Dictionary in _spy.warns:
		if w["code"] == code:
			return true
	return false


## Count errors matching the given code.
func _error_count(code: StringName) -> int:
	var n := 0
	for e: Dictionary in _spy.errors:
		if e["code"] == code:
			n += 1
	return n


# ---------------------------------------------------------------------------
# Clean baseline — a well-formed enemy with one valid region passes
# ---------------------------------------------------------------------------

func test_clean_enemy_one_valid_region_passes() -> void:
	var e := _enemy()
	e.break_regions = [_region("arm", 0.35, 100)]
	# Two loot entries so loot (2) > regions (1) satisfies the Story-008
	# harvest-decision rule; the first connects the region, the second is a floor drop.
	e.loot_pool     = [_loot_entry("part_broken"), _floor_loot("filler_a")]
	var r := _run(e)
	assert_true(r["ok"], "well-formed enemy with one valid break region validates")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")


# ---------------------------------------------------------------------------
# AC-5 (TR-edb-022) — ≥1 region required
# ---------------------------------------------------------------------------

func test_break_regions_empty_errors() -> void:
	var e := _enemy()
	e.break_regions = []
	e.loot_pool     = []
	var r := _run(e)
	assert_true(_logged(&"content_enemy_break_no_regions"),
		"empty break_regions → content_enemy_break_no_regions")
	assert_false(r["ok"], "empty break_regions is a BLOCKING error")


# ---------------------------------------------------------------------------
# AC-1 (TR-edb-002) — stored == derived (epsilon parity cases)
#
# 7 AC-ED-08 divergent inputs — each authored-correct break_hp passes;
# off-by-one (authored_correct - 1) fails.
# ---------------------------------------------------------------------------

## Helper for the discriminating pair: correct → clean, wrong → error.
func _run_mismatch_pair(structure: int, fraction: float, correct_hp: int) -> void:
	# Correct break_hp → no mismatch error
	var good := _enemy()
	good.stats["structure"] = structure
	good.break_regions = [{
		"region_id": "r1", "region_fraction": fraction,
		"break_hp": correct_hp, "break_event": "part_broken",
	}]
	good.loot_pool = [_loot_entry("part_broken")]
	_run(good)
	assert_false(_logged(&"content_enemy_break_hp_mismatch"),
		"structure=%d, fraction=%s, break_hp=%d (correct) → no mismatch" % [structure, fraction, correct_hp])

	# off-by-one below → mismatch error
	var bad := _enemy()
	bad.stats["structure"] = structure
	bad.break_regions = [{
		"region_id": "r1", "region_fraction": fraction,
		"break_hp": correct_hp - 1, "break_event": "part_broken",
	}]
	bad.loot_pool = [_loot_entry("part_broken")]
	_run(bad)
	assert_true(_logged(&"content_enemy_break_hp_mismatch"),
		"structure=%d, fraction=%s, break_hp=%d (off-by-one low) → mismatch error" % [structure, fraction, correct_hp - 1])


func test_ac_ed08_fixture_1_structure100_fraction029_bp29() -> void:
	# (100, 0.29, 29) — without epsilon floor()=28, correct=29.
	_run_mismatch_pair(100, 0.29, 29)


func test_ac_ed08_fixture_2_structure180_fraction035_bp63_epsilon_parity() -> void:
	# (180, 0.35, 63) — THE epsilon parity case from Story 003.
	# 180*0.35 = 62.9999...; without +0.0001 nudge floor()=62 (wrong).
	# This ties directly to Story 003's AC-1 regression case.
	_run_mismatch_pair(180, 0.35, 63)


func test_ac_ed08_fixture_3_structure200_fraction029_bp58() -> void:
	_run_mismatch_pair(200, 0.29, 58)


func test_ac_ed08_fixture_4_structure300_fraction041_bp123() -> void:
	_run_mismatch_pair(300, 0.41, 123)


func test_ac_ed08_fixture_5_structure340_fraction035_bp119() -> void:
	_run_mismatch_pair(340, 0.35, 119)


func test_ac_ed08_fixture_6_structure360_fraction035_bp126() -> void:
	_run_mismatch_pair(360, 0.35, 126)


func test_ac_ed08_fixture_7_structure400_fraction029_bp116() -> void:
	_run_mismatch_pair(400, 0.29, 116)


func test_stored_break_hp_off_by_one_above_also_errors() -> void:
	# off-by-one above the correct value also mismatches (distinct code path check).
	var structure := 180
	var fraction := 0.35
	var correct_hp := 63   # EDB-1 result
	var e := _enemy()
	e.stats["structure"] = structure
	e.break_regions = [{
		"region_id": "r1", "region_fraction": fraction,
		"break_hp": correct_hp + 1, "break_event": "part_broken",
	}]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_true(_logged(&"content_enemy_break_hp_mismatch"),
		"structure=180, fraction=0.35, break_hp=64 (off-by-one high) → mismatch error")


# ---------------------------------------------------------------------------
# AC-2 (EDB-3) — break_hp < structure
# ---------------------------------------------------------------------------

func test_break_hp_equals_structure_errors() -> void:
	# structure=100, break_hp=100 → break_hp >= structure → error.
	var e := _enemy()
	e.stats["structure"] = 100
	var fraction := 0.35
	# Force a stored value equal to structure (ignore derived for this test).
	e.break_regions = [{
		"region_id": "r1", "region_fraction": fraction,
		"break_hp": 100, "break_event": "part_broken",
	}]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_true(_logged(&"content_enemy_break_hp_exceeds_structure"),
		"break_hp=100 == structure=100 → content_enemy_break_hp_exceeds_structure")


func test_break_hp_one_below_structure_passes() -> void:
	# structure=100, break_hp=99 → break_hp < structure → clean (for this check).
	# To isolate the structure check we also need stored==derived to pass, so we
	# use a fraction that derives 99 or just note that mismatch fires independently.
	# We set break_hp=99 and accept a mismatch error may also fire — the key
	# assertion is that the exceeds_structure error does NOT fire.
	var e := _enemy()
	e.stats["structure"] = 100
	e.break_regions = [{
		"region_id": "r1", "region_fraction": 0.35,
		"break_hp": 99, "break_event": "part_broken",
	}]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_false(_logged(&"content_enemy_break_hp_exceeds_structure"),
		"break_hp=99 < structure=100 → no exceeds_structure error")


func test_break_hp_strictly_below_structure_clean() -> void:
	# Well-formed case: structure=100, fraction=0.35 → derived=35 < 100 → clean.
	var e := _enemy()
	e.stats["structure"] = 100
	e.break_regions = [_region("r1", 0.35, 100)]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_false(_logged(&"content_enemy_break_hp_exceeds_structure"),
		"break_hp=35 < structure=100 → no exceeds_structure error")


# ---------------------------------------------------------------------------
# AC-3 (TR-edb-014) — region_fraction bounds [0.15, 0.55] with ±1e-9 tolerance
# ---------------------------------------------------------------------------

func test_region_fraction_at_min_015_passes() -> void:
	# 0.15 is the inclusive lower bound — must pass even if IEEE 754 rounds inward.
	var e := _enemy()
	e.break_regions = [_region("r1", 0.15, 100)]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_false(_logged(&"content_enemy_break_fraction_out_of_range"),
		"region_fraction=0.15 (GDD min) → no out-of-range error")


func test_region_fraction_at_max_055_passes() -> void:
	# 0.55 is the inclusive upper bound — must pass.
	var e := _enemy()
	e.break_regions = [_region("r1", 0.55, 100)]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_false(_logged(&"content_enemy_break_fraction_out_of_range"),
		"region_fraction=0.55 (GDD max) → no out-of-range error")


func test_region_fraction_just_above_max_errors() -> void:
	# Just outside the upper bound — must error.
	# 0.56 is clearly outside [0.15, 0.55] even with tolerance.
	var e := _enemy()
	e.stats["structure"] = 100
	e.break_regions = [{
		"region_id": "r1", "region_fraction": 0.56,
		"break_hp": BreakHpFormula.derive_break_hp(100, 0.56),
		"break_event": "part_broken",
	}]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_true(_logged(&"content_enemy_break_fraction_out_of_range"),
		"region_fraction=0.56 > 0.55 → content_enemy_break_fraction_out_of_range")


func test_region_fraction_just_below_min_errors() -> void:
	# 0.14 is clearly below 0.15 — must error.
	var e := _enemy()
	e.stats["structure"] = 100
	e.break_regions = [{
		"region_id": "r1", "region_fraction": 0.14,
		"break_hp": BreakHpFormula.derive_break_hp(100, 0.14),
		"break_event": "part_broken",
	}]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_true(_logged(&"content_enemy_break_fraction_out_of_range"),
		"region_fraction=0.14 < 0.15 → content_enemy_break_fraction_out_of_range")


func test_region_fraction_midrange_025_passes() -> void:
	# A fraction well within bounds — must be clean.
	var e := _enemy()
	e.break_regions = [_region("r1", 0.25, 100)]
	e.loot_pool = [_loot_entry("part_broken")]
	_run(e)
	assert_false(_logged(&"content_enemy_break_fraction_out_of_range"),
		"region_fraction=0.25 → no out-of-range error")


# ---------------------------------------------------------------------------
# AC-4 (TR-edb-004 / TR-edb-021) — region_id uniqueness vs shared break_event
#
# KEY DISCRIMINATOR / AC-ED-20 regression guard:
#   Same region_id → error.
#   Same break_event, distinct region_id → ZERO errors (set semantics).
# A naive "all region fields unique" impl fails the shared-break_event case.
# ---------------------------------------------------------------------------

func test_duplicate_region_id_errors() -> void:
	# Two regions with the same region_id on one enemy → error (EC-ED-08).
	var e := _enemy()
	e.stats["structure"] = 100
	e.break_regions = [
		_region("left_arm", 0.30, 100, "arm_broken"),
		_region("left_arm", 0.40, 100, "shoulder_broken"),  # same region_id
	]
	e.loot_pool = [
		_loot_entry("arm_broken"),
		_loot_entry("shoulder_broken"),
	]
	_run(e)
	assert_true(_logged(&"content_enemy_break_region_id_duplicate"),
		"two regions with same region_id=left_arm → content_enemy_break_region_id_duplicate")


func test_shared_break_event_distinct_region_id_zero_errors() -> void:
	# AC-ED-20: two regions sharing the SAME break_event but with DISTINCT
	# region_ids → ZERO errors. This is valid set semantics (EC-ED-07, TR-edb-021).
	# A naive "all fields unique" impl would wrongly error the break_event.
	var structure := 100
	var e := _enemy()
	e.stats["structure"] = structure
	e.break_regions = [
		# Same break_event "arm_broken", distinct region_ids
		{
			"region_id": "left_arm",
			"region_fraction": 0.30,
			"break_hp": BreakHpFormula.derive_break_hp(structure, 0.30),
			"break_event": "arm_broken",
		},
		{
			"region_id": "right_arm",
			"region_fraction": 0.30,
			"break_hp": BreakHpFormula.derive_break_hp(structure, 0.30),
			"break_event": "arm_broken",  # same break_event — LEGAL
		},
	]
	# Loot pool connected to the shared event, padded past the harvest-decision
	# floor (3 loot > 2 regions) so result.ok reflects only the AC-ED-20 case.
	e.loot_pool = [_loot_entry("arm_broken"), _floor_loot("filler_a"), _floor_loot("filler_b")]
	var r := _run(e)
	# The ONLY assertion that matters for the AC-ED-20 guard:
	assert_eq(_error_count(&"content_enemy_break_region_id_duplicate"), 0,
		"shared break_event with distinct region_ids → zero duplicate-id errors")
	assert_eq(_error_count(&"content_enemy_break_hp_mismatch"), 0,
		"shared break_event AC-ED-20 case → zero mismatch errors")
	assert_eq(_error_count(&"content_enemy_break_region_orphan"), 0,
		"shared break_event AC-ED-20 case → zero orphan errors")
	assert_eq(_error_count(&"content_enemy_break_hp_exceeds_structure"), 0,
		"shared break_event AC-ED-20 case → zero exceeds-structure errors")
	assert_eq(_error_count(&"content_enemy_break_fraction_out_of_range"), 0,
		"shared break_event AC-ED-20 case → zero out-of-range errors")
	assert_true(r["ok"],
		"two regions with same break_event, distinct region_id → result is ok (AC-ED-20)")


func test_distinct_region_ids_different_events_passes() -> void:
	# Both distinct region_ids and distinct break_events — must be clean.
	var structure := 100
	var e := _enemy()
	e.stats["structure"] = structure
	e.break_regions = [
		_region("arm", 0.30, structure, "arm_broken"),
		_region("leg", 0.40, structure, "leg_broken"),
	]
	# 3 loot > 2 regions satisfies the Story-008 harvest-decision floor.
	e.loot_pool = [_loot_entry("arm_broken"), _loot_entry("leg_broken"), _floor_loot("filler_a")]
	var r := _run(e)
	assert_true(r["ok"], "two regions with distinct ids and events → clean")
	assert_false(_logged(&"content_enemy_break_region_id_duplicate"),
		"distinct region_ids → no duplicate error")


# ---------------------------------------------------------------------------
# AC-6 (EDB-3 loot_connected) — orphan region
# ---------------------------------------------------------------------------

func test_orphan_region_no_matching_loot_entry_errors() -> void:
	# Region break_event "plate_cracked" has no matching loot_pool entry.
	var e := _enemy()
	e.break_regions = [{
		"region_id": "chest_plate",
		"region_fraction": 0.30,
		"break_hp": BreakHpFormula.derive_break_hp(100, 0.30),
		"break_event": "plate_cracked",
	}]
	# loot_pool entry references a DIFFERENT event — no connectivity
	e.loot_pool = [_loot_entry("arm_broken")]
	_run(e)
	assert_true(_logged(&"content_enemy_break_region_orphan"),
		"break_event=plate_cracked not in loot_pool → content_enemy_break_region_orphan")


func test_region_with_matching_loot_entry_passes() -> void:
	# Region break_event "arm_broken" matches a loot_pool entry → clean.
	var e := _enemy()
	e.break_regions = [_region("arm", 0.30, 100, "arm_broken")]
	e.loot_pool     = [_loot_entry("arm_broken")]
	_run(e)
	assert_false(_logged(&"content_enemy_break_region_orphan"),
		"break_event=arm_broken found in loot_pool → no orphan error")


func test_region_loot_connected_via_break_event_key_passes() -> void:
	# Connectivity via the "break_event" linkage key on the loot_pool entry
	# (alternative to "drop_condition" per EnemyDef.loot_pool doc shape).
	var e := _enemy()
	e.break_regions = [{
		"region_id": "head",
		"region_fraction": 0.20,
		"break_hp": BreakHpFormula.derive_break_hp(100, 0.20),
		"break_event": "sensor_cracked",
	}]
	e.loot_pool = [
		{"id": "sensor_part", "break_event": "sensor_cracked", "enabled": true}
	]
	_run(e)
	assert_false(_logged(&"content_enemy_break_region_orphan"),
		"break_event key in loot_pool entry satisfies loot connectivity")


func test_empty_loot_pool_with_region_produces_orphan_error() -> void:
	# A region with no loot_pool entries at all → orphan error.
	var e := _enemy()
	e.break_regions = [{
		"region_id": "r1",
		"region_fraction": 0.30,
		"break_hp": BreakHpFormula.derive_break_hp(100, 0.30),
		"break_event": "part_broken",
	}]
	e.loot_pool = []
	_run(e)
	assert_true(_logged(&"content_enemy_break_region_orphan"),
		"empty loot_pool with one region → content_enemy_break_region_orphan")
