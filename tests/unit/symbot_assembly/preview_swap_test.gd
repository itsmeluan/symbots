## Story 006 — SA-F2 preview (compute_stat_delta / preview_swap).
## Covers AC-SA-08 (per-stat delta + purity), EC-SA-09 (chassis swap yields non-zero
## deltas for stats the candidate itself does not contribute to).
extends GutTest

const Fixtures = preload("res://tests/unit/symbot_assembly/assembly_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/symbot_assembly/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()


# --- AC-SA-08: delta = hypothetical − current, with zero side effects -------------

func test_preview_swap_reports_delta_without_mutating() -> void:
	# Arrange: LEGS mobility=8, no chassis (neutral ×1.0). Candidate LEGS gives
	# structure=2 / mobility=5 → delta structure +2, mobility −3, targeting 0.
	var starters := {
		PartDef.SlotType.LEGS: Fixtures.make_instance(Fixtures.make_part({
			"id": &"cur_legs", "slot_type": PartDef.SlotType.LEGS,
			"stat_bonuses": {&"mobility": 8},
		}), 0),
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log)
	watch_signals(build)
	var candidate := Fixtures.make_part({
		"id": &"cand_legs", "slot_type": PartDef.SlotType.LEGS,
		"stat_bonuses": {&"structure": 2, &"mobility": 5},
	})

	# Act
	var delta := build.compute_stat_delta(PartDef.SlotType.LEGS, candidate)

	# Assert: the delta vector.
	assert_eq(delta["structure"], 2, "candidate adds structure +2")
	assert_eq(delta["mobility"], -3, "mobility drops 8 → 5")
	assert_eq(delta["targeting"], 0, "unaffected stat has zero delta")

	# Assert purity: live cache, signals and manifest all untouched.
	assert_eq(build.get_final_stat()["mobility"], 8, "live cache unchanged by preview")
	assert_eq(build.get_equipped(PartDef.SlotType.LEGS).part.id, &"cur_legs",
		"manifest still holds the original part")
	assert_signal_not_emitted(build, "stats_changed")
	assert_signal_not_emitted(build, "part_equipped")


# --- EC-SA-09: previewing a chassis swap re-derives the whole vector --------------

func test_preview_chassis_swap_yields_nonzero_mobility_delta() -> void:
	# Arrange: LEGS mobility=7 under a LIGHT_FRAME chassis → live mobility
	# floor(7×1.20)=8. Preview swapping to a HEAVY_FRAME chassis (×0.80).
	var starters := {
		PartDef.SlotType.LEGS: Fixtures.make_instance(Fixtures.make_part({
			"id": &"legs", "slot_type": PartDef.SlotType.LEGS,
			"stat_bonuses": {&"mobility": 7},
		}), 0),
		PartDef.SlotType.CHASSIS: Fixtures.make_instance(Fixtures.make_part({
			"id": &"light", "slot_type": PartDef.SlotType.CHASSIS,
			"chassis_archetype": PartDef.ChassisArchetype.LIGHT_FRAME,
		}), 0),
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log)
	var heavy := Fixtures.make_part({
		"id": &"heavy", "slot_type": PartDef.SlotType.CHASSIS,
		"chassis_archetype": PartDef.ChassisArchetype.HEAVY_FRAME,
	})

	# Act
	var delta := build.compute_stat_delta(PartDef.SlotType.CHASSIS, heavy)

	# Assert: mobility floor(7×0.80)=5 vs live 8 → −3, though `heavy` adds no mobility.
	assert_eq(delta["mobility"], -3,
		"chassis swap re-applies the archetype modifier to mobility")
