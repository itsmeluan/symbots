## Story 003 — eager recompute on equip + passive-read stability.
## Covers AC-SA-05 (chassis swap re-derives every stat), AC-SA-07 (reads never emit).
extends GutTest

const Fixtures = preload("res://tests/unit/symbot_assembly/assembly_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/symbot_assembly/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()


func _chassis(id: StringName, archetype: int, structure: int) -> Object:
	return Fixtures.make_instance(Fixtures.make_part({
		"id": id, "slot_type": PartDef.SlotType.CHASSIS,
		"chassis_archetype": archetype, "stat_bonuses": {&"structure": structure},
	}), 0)


func _light_build() -> SymbotBuild:
	# LEGS mobility=7 + a LIGHT_FRAME chassis (structure=10). Chosen so the archetype
	# swap lands on the exact discriminating values below (all at tier 0).
	var starters := {
		PartDef.SlotType.LEGS: Fixtures.make_instance(Fixtures.make_part({
			"id": &"legs", "slot_type": PartDef.SlotType.LEGS,
			"stat_bonuses": {&"mobility": 7},
		}), 0),
		PartDef.SlotType.CHASSIS: _chassis(
			&"light_frame", PartDef.ChassisArchetype.LIGHT_FRAME, 10),
	}
	return SymbotBuild.with_starters(starters, _cfg, _log)


# --- AC-SA-05: chassis swap re-applies the modifier across every stat -------------

func test_chassis_swap_light_to_heavy_rederives_all_stats() -> void:
	# Arrange: Light build. structure floor(10×0.85)=8, mobility floor(7×1.20)=8.
	var build := _light_build()
	assert_eq(build.get_final_stat()["structure"], 8, "precondition: light structure")
	assert_eq(build.get_final_stat()["mobility"], 8, "precondition: light mobility")
	assert_eq(build.get_final_stat()["targeting"], 0, "precondition: no targeting source")

	# Act: swap CHASSIS to a HEAVY_FRAME part (structure=8 on the part itself).
	var result := build.equip_part(PartDef.SlotType.CHASSIS,
		_chassis(&"heavy_frame", PartDef.ChassisArchetype.HEAVY_FRAME, 8))

	# Assert: the whole vector re-derives — structure floor(8×1.25)=10, mobility
	# floor(7×0.80)=5 — even mobility, which the new chassis contributes nothing to.
	assert_true(result["ok"])
	assert_eq(build.get_final_stat()["structure"], 10, "structure re-derived under HEAVY")
	assert_eq(build.get_final_stat()["mobility"], 5, "mobility drops under HEAVY ×0.80")
	assert_eq(build.get_final_stat()["targeting"], 0, "targeting stays 0")


# --- AC-SA-07: passive reads are stable and never emit stats_changed -------------

func test_reads_do_not_emit_or_mutate_cache() -> void:
	# Arrange
	var build := _light_build()
	watch_signals(build)

	# Act: read repeatedly, and mutate a returned copy.
	var first := build.get_final_stat()
	first["structure"] = 999
	var second := build.get_final_stat()

	# Assert: the cache is unchanged and no read emitted a signal.
	assert_eq(second["structure"], 8, "returned dict is a copy — cache uncorrupted")
	assert_signal_not_emitted(build, "stats_changed")
	assert_signal_not_emitted(build, "part_equipped")
