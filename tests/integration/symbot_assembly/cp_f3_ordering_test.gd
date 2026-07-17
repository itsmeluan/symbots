## Story 007 — CP-F3 composition ordering (the binding DoD gate = Core Progression
## AC-CP-18). Growth is a FLAT add applied AFTER the SA-F1 chassis floor — NOT summed
## into the pre-multiply total. The discriminator lands on 160, never 168.
## Covers AC-SA-15 + the level-1 boundary + the unknown-growth-key content case.
extends GutTest

const Fixtures = preload("res://tests/unit/symbot_assembly/assembly_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/symbot_assembly/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()


## LEGS mobility=100 under a LIGHT_FRAME chassis (×1.20 mobility); CORE grows
## mobility +10 / level. [param level] drives CP-F3 via the CoreProgression stub.
## [param growth] lets a test inject an unknown growth key.
func _build(level: int, growth: Dictionary = {&"mobility": 10}) -> SymbotBuild:
	var gate := Fixtures.StubCoreProgression.new()
	gate.level = level
	var starters := {
		PartDef.SlotType.LEGS: Fixtures.make_instance(Fixtures.make_part({
			"id": &"legs", "slot_type": PartDef.SlotType.LEGS,
			"stat_bonuses": {&"mobility": 100},
		}), 0),
		PartDef.SlotType.CHASSIS: Fixtures.make_instance(Fixtures.make_part({
			"id": &"light", "slot_type": PartDef.SlotType.CHASSIS,
			"chassis_archetype": PartDef.ChassisArchetype.LIGHT_FRAME,
		}), 0),
		PartDef.SlotType.CORE: Fixtures.make_instance(Fixtures.make_part({
			"id": &"core", "slot_type": PartDef.SlotType.CORE, "level_growth": growth,
		}), 0),
	}
	return SymbotBuild.with_starters(starters, _cfg, _log, null, gate)


# --- AC-SA-15: the 160-not-168 discriminator ------------------------------------

func test_cp_f3_growth_applied_after_chassis_floor() -> void:
	# Arrange: level 5. SA-F1 mobility = floor(100 × 1.20) = 120.
	var build := _build(5)

	# Act
	var mobility: int = build.get_final_stat()["mobility"]

	# Assert: 120 + 10×(5−1) = 160. The wrong (pre-multiply) order would give
	# (100 + 40) × 1.20 = 168 — this test fails loudly if the composition inverts.
	assert_eq(mobility, 160, "CP-F3 is a flat post-floor add: 120 + 40 = 160, not 168")


# --- Boundary: at level 1, CP-F3 contributes nothing -----------------------------

func test_cp_f3_level_one_contributes_zero() -> void:
	# Arrange: level 1 → growth × (1 − 1) = 0.
	var build := _build(1)

	# Act / Assert: pure SA-F1 output, no growth.
	assert_eq(build.get_final_stat()["mobility"], 120, "level 1 adds no growth")


# --- Content case: an unknown growth key is skipped and warned -------------------

func test_unknown_growth_key_skipped_and_warned() -> void:
	# Arrange: CORE growth references a stat outside the canonical 11.
	var build := _build(5, {&"mobility": 10, &"bogus_key": 99})

	# Act
	var final_stat := build.get_final_stat()

	# Assert: the valid growth still lands (160); the bogus key is dropped + warned.
	assert_eq(final_stat["mobility"], 160, "canonical growth unaffected")
	assert_false(final_stat.has(&"bogus_key"), "unknown growth key never enters final_stat")
	var warned := false
	for w in _log.warns:
		if w["code"] == &"content_unknown_growth_key":
			warned = true
	assert_true(warned, "unknown growth key raises a content warning")
