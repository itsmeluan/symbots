## Story 001 — StatPipeline SA-F1 execution core (steps 1–4).
## Covers AC-SA-02 (a/b/c), AC-SA-11, AC-SA-13.
extends GutTest

const Fixtures = preload("res://tests/unit/symbot_assembly/assembly_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/symbot_assembly/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()


# --- AC-SA-02 (a): F2 floor discrimination -------------------------------------

func test_saf1_f2_floor_yields_9_not_10() -> void:
	# Arrange: LEGS mobility=7 at tier +1, Light Frame chassis (×1.20 mobility).
	var part_a := Fixtures.make_part({
		"id": &"swift_legs", "slot_type": PartDef.SlotType.LEGS,
		"stat_bonuses": {&"mobility": 7},
	})
	var equipped := {PartDef.SlotType.LEGS: Fixtures.make_instance(part_a, 1)}

	# Act
	var final_stat := StatPipeline.derive(
		equipped, PartDef.ChassisArchetype.LIGHT_FRAME, 1, {}, _cfg, _log)

	# Assert: floor(floor(7×1.15)=8 × 1.20 = 9.6) = 9 — NOT round() → 10.
	assert_eq(final_stat["mobility"], 9, "SA-F1 must floor to 9, not round to 10")
	assert_eq(StatPipeline.compute_upgraded_stat(part_a, &"mobility", 1, _cfg), 8,
		"intermediate F2 output must be the integer 8, not 8.05")


# --- AC-SA-02 (b): F2b epsilon (load-bearing) ----------------------------------

func test_saf1_f2b_epsilon_yields_negative_5_not_6() -> void:
	# Arrange: a negative base stat -15 at tier +2.
	var part := Fixtures.make_part({
		"id": &"proto_part", "slot_type": PartDef.SlotType.WEAPON,
		"stat_bonuses": {&"resistance": -15},
	})

	# Act / Assert: −ceil(15 × 0.3333… − ε) = −5, not −6 (IEEE-754 5.000000000000001).
	assert_eq(StatPipeline.compute_upgraded_stat(part, &"resistance", 2, _cfg), -5,
		"F2b epsilon nudge must yield −5, not −6")


# --- AC-SA-02 (c): F1 chassis floor --------------------------------------------

func test_saf1_balanced_frame_structure_passthrough() -> void:
	# Arrange: single CHASSIS structure=10, Balanced Frame (×1.00 structure).
	var chassis := Fixtures.make_part({
		"id": &"balanced_frame", "slot_type": PartDef.SlotType.CHASSIS,
		"chassis_archetype": PartDef.ChassisArchetype.BALANCED_FRAME,
		"stat_bonuses": {&"structure": 10},
	})
	var equipped := {PartDef.SlotType.CHASSIS: Fixtures.make_instance(chassis, 0)}

	# Act
	var final_stat := StatPipeline.derive(
		equipped, PartDef.ChassisArchetype.BALANCED_FRAME, 1, {}, _cfg, _log)

	# Assert
	assert_eq(final_stat["structure"], 10)


func test_final_stat_carries_all_11_canonical_keys() -> void:
	var equipped := {}
	var final_stat := StatPipeline.derive(equipped, 0 as PartDef.ChassisArchetype, 1, {}, _cfg, _log)
	assert_eq(final_stat.size(), 11, "every canonical key present even with no parts")
	assert_true(final_stat.has(&"targeting") and final_stat[&"targeting"] == 0)


# --- AC-SA-11: unknown stat key skipped ----------------------------------------

func test_unknown_stat_key_skipped_with_warning() -> void:
	# Arrange: a part carrying a key outside the canonical 11.
	var part := Fixtures.make_part({
		"id": &"weird_part", "slot_type": PartDef.SlotType.HEAD,
		"stat_bonuses": {&"structure": 10, &"unknown_key": 5},
	})
	var equipped := {PartDef.SlotType.HEAD: Fixtures.make_instance(part, 0)}

	# Act
	var final_stat := StatPipeline.derive(equipped, 0 as PartDef.ChassisArchetype, 1, {}, _cfg, _log)

	# Assert
	assert_eq(final_stat["structure"], 10, "known stat computed normally")
	assert_false(final_stat.has(&"unknown_key"), "unknown key must not enter final_stat")
	assert_eq(_log.warns.size(), 1, "exactly one content warning logged")
	assert_eq(_log.warns[0]["code"], &"content_unknown_stat_key")


# --- AC-SA-13: recharge sum > 30 reported, not clamped -------------------------

func test_recharge_sum_over_30_reported_not_clamped() -> void:
	# Arrange: three parts each recharge=15 (content violation → sum 45).
	var mk := func(id: StringName, slot: int) -> Object:
		return Fixtures.make_instance(Fixtures.make_part({
			"id": id, "slot_type": slot, "stat_bonuses": {&"recharge": 15},
		}), 0)
	var equipped := {
		PartDef.SlotType.ENERGY_CELL: mk.call(&"cell", PartDef.SlotType.ENERGY_CELL),
		PartDef.SlotType.CORE: mk.call(&"core", PartDef.SlotType.CORE),
		PartDef.SlotType.WEAPON: mk.call(&"weapon", PartDef.SlotType.WEAPON),
	}

	# Act
	var final_stat := StatPipeline.derive(equipped, 0 as PartDef.ChassisArchetype, 1, {}, _cfg, _log)

	# Assert: reported on the pre-multiply sum, NOT clamped to 30.
	assert_eq(final_stat["recharge"], 45, "final recharge is not clamped")
	assert_eq(_log.errors.size(), 1, "one content error for the >30 breach")
	assert_eq(_log.errors[0]["code"], &"content_recharge_sum_exceeded")
	assert_eq(_log.errors[0]["detail"]["sum"], 45)


func test_recharge_sum_exactly_30_no_error() -> void:
	# Arrange: two parts recharge=15 → boundary sum 30 (inclusive max allowed).
	var mk := func(id: StringName, slot: int) -> Object:
		return Fixtures.make_instance(Fixtures.make_part({
			"id": id, "slot_type": slot, "stat_bonuses": {&"recharge": 15},
		}), 0)
	var equipped := {
		PartDef.SlotType.ENERGY_CELL: mk.call(&"cell", PartDef.SlotType.ENERGY_CELL),
		PartDef.SlotType.CORE: mk.call(&"core", PartDef.SlotType.CORE),
	}

	# Act
	var final_stat := StatPipeline.derive(equipped, 0 as PartDef.ChassisArchetype, 1, {}, _cfg, _log)

	# Assert
	assert_eq(final_stat["recharge"], 30)
	assert_eq(_log.errors.size(), 0, "sum == 30 is within the design max, no error")
