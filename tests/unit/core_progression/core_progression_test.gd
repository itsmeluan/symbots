## CoreProgression — CP-F1 threshold derivation, XP award, equip gate, CP-F3 growth,
## and save round-trip (Symbot Core Progression GDD).
##
## The boundary cases here are the point: level derivation is a threshold lookup, so
## every assertion sits ON a threshold or one XP below it. A test that only checked
## midpoints would pass against an off-by-one in the comparison.
extends GutTest

const CoreProgressionScript := preload("res://src/core/progression/core_progression.gd")


class SpyLog:
	extends LogSink
	var warns: Array = []
	func info(_code: StringName, _detail: Dictionary) -> void:
		pass
	func warn(code: StringName, detail: Dictionary) -> void:
		warns.append({code = code, detail = detail})
	func error(_code: StringName, _detail: Dictionary) -> void:
		pass


func _make(log = null) -> CoreProgression:
	return CoreProgressionScript.new(log)


# ---------------------------------------------------------------------------
# CP-F1 — level derivation
# ---------------------------------------------------------------------------

func test_new_core_starts_at_level_one_with_no_xp() -> void:
	var cp := _make()
	cp.register_core(&"core_a")
	assert_eq(cp.get_level(&"core_a"), 1, "A freshly registered core is level 1")
	assert_eq(cp.get_xp(&"core_a"), 0, "and has earned no XP")


func test_level_boundaries_match_the_gdd_threshold_table() -> void:
	# Each pair is (cumulative_xp, expected_level). Values sit exactly ON the published
	# threshold and one XP below it — an off-by-one in the comparison fails here.
	var cases := [
		[0, 1], [99, 1], [100, 2], [219, 2], [220, 3], [363, 3], [364, 4],
		[536, 4], [537, 5], [743, 5], [744, 6], [992, 6], [993, 7],
		[1291, 7], [1292, 8], [1649, 8], [1650, 9], [2079, 9], [2080, 10],
	]
	for c in cases:
		var cp := _make()
		cp.register_core(&"c")
		cp.add_xp(&"c", c[0])
		assert_eq(cp.get_level(&"c"), c[1],
			"cumulative_xp %d must derive level %d (CP-F1 table)" % [c[0], c[1]])


func test_level_is_capped_and_xp_keeps_accumulating_past_it() -> void:
	var cp := _make()
	cp.register_core(&"c")
	cp.add_xp(&"c", 99999)
	assert_eq(cp.get_level(&"c"), 10, "MAX_CORE_LEVEL caps the derived level")
	assert_eq(cp.get_xp(&"c"), 99999, "but cumulative XP is never clamped — it is the fact")


func test_multiple_levels_in_one_award_emit_once_with_the_full_span() -> void:
	var cp := _make()
	cp.register_core(&"c")
	var seen: Array = []
	cp.core_leveled_up.connect(func(id, old, new): seen.append([id, old, new]))
	cp.add_xp(&"c", 744)  # 1 -> 6 in a single award
	assert_eq(seen.size(), 1, "A multi-level gain emits ONCE, not once per level (Rule 2)")
	assert_eq(seen[0][1], 1, "old_level is the level before the award")
	assert_eq(seen[0][2], 6, "new_level is the final level, not an intermediate step")


func test_no_signal_when_xp_does_not_cross_a_threshold() -> void:
	var cp := _make()
	cp.register_core(&"c")
	cp.add_xp(&"c", 50)
	var seen := 0
	cp.core_leveled_up.connect(func(_i, _o, _n): seen += 1)
	cp.add_xp(&"c", 20)  # 70 total, still level 1
	assert_eq(seen, 0, "Gaining XP without crossing a threshold emits nothing")


# ---------------------------------------------------------------------------
# Award guards
# ---------------------------------------------------------------------------

func test_non_positive_xp_is_ignored() -> void:
	var cp := _make()
	cp.register_core(&"c")
	cp.add_xp(&"c", 150)
	cp.add_xp(&"c", 0)
	cp.add_xp(&"c", -500)
	assert_eq(cp.get_xp(&"c"), 150, "Zero and negative awards never change cumulative XP")


func test_xp_for_an_unregistered_core_is_kept_not_dropped() -> void:
	var log := SpyLog.new()
	var cp := _make(log)
	cp.add_xp(&"ghost", 120)
	assert_eq(cp.get_level(&"ghost"), 2, "The award lands rather than being discarded")
	assert_eq(log.warns.size(), 1, "and the wiring gap is still surfaced as a warning")
	assert_eq(log.warns[0]["code"], &"core_xp_unregistered")


func test_re_registering_warns_and_never_resets_progress() -> void:
	var log := SpyLog.new()
	var cp := _make(log)
	cp.register_core(&"c")
	cp.add_xp(&"c", 500)
	cp.register_core(&"c")
	assert_eq(cp.get_xp(&"c"), 500, "A duplicate register must NOT zero earned XP")
	assert_eq(log.warns[0]["code"], &"core_already_registered")


# ---------------------------------------------------------------------------
# Equip gate + CP-F3
# ---------------------------------------------------------------------------

func _part(level_req: int, growth: Dictionary = {}) -> PartDef:
	var p := PartDef.new()
	p.level_requirement = level_req
	for k in growth:
		p.level_growth[k] = growth[k]
	return p


func test_equip_gate_blocks_only_above_the_current_level() -> void:
	var cp := _make()
	cp.register_core(&"c")
	cp.add_xp(&"c", 220)  # level 3
	assert_true(cp.can_equip(_part(0)), "No requirement is always equippable")
	assert_true(cp.can_equip(_part(3)), "Requirement equal to level passes")
	assert_false(cp.can_equip(_part(4)), "Requirement above level is refused")


func test_equip_gate_allows_unrequired_parts_with_no_cores_at_all() -> void:
	assert_true(_make().can_equip(_part(0)),
		"An empty progression must not block ordinary parts")


func test_level_growth_is_zero_at_level_one_and_scales_by_steps() -> void:
	var cp := _make()
	cp.register_core(&"c")
	var core := _part(0, {&"structure": 2, &"energy_capacity": 3})
	assert_eq(cp.level_contribution(core, &"c"), {},
		"CP-F3 contributes nothing at level 1 — (level - 1) is zero")
	cp.add_xp(&"c", 220)  # level 3 -> 2 steps
	var got := cp.level_contribution(core, &"c")
	assert_eq(got[&"structure"], 4, "2 growth x 2 steps")
	assert_eq(got[&"energy_capacity"], 6, "3 growth x 2 steps")


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func test_snapshot_restore_round_trip_preserves_xp_and_rederives_level() -> void:
	var cp := _make()
	cp.register_core(&"c1")
	cp.register_core(&"c2")
	cp.add_xp(&"c1", 1000)
	cp.add_xp(&"c2", 100)
	var blob := cp.snapshot()

	var loaded := _make()
	loaded.restore(blob)
	assert_eq(loaded.get_xp(&"c1"), 1000, "XP survives the round trip")
	assert_eq(loaded.get_level(&"c1"), 7, "and level is re-derived from it")
	assert_eq(loaded.get_level(&"c2"), 2)


func test_restore_coerces_json_floats_back_to_int() -> void:
	var loaded := _make()
	loaded.restore({"c": 537.0})   # JSON.parse_string hands back every number as float
	assert_eq(typeof(loaded.get_xp(&"c")), TYPE_INT, "XP must be an int, not a float")
	assert_eq(loaded.get_level(&"c"), 5)


func test_restore_clamps_negative_xp_and_warns() -> void:
	var log := SpyLog.new()
	var loaded := _make(log)
	loaded.restore({"c": -40})
	assert_eq(loaded.get_xp(&"c"), 0, "Corrupt negative XP clamps to zero")
	assert_eq(log.warns[0]["code"], &"core_xp_negative")


func test_progress_reports_the_span_into_the_current_level() -> void:
	var cp := _make()
	cp.register_core(&"c")
	cp.add_xp(&"c", 150)              # level 2, floor 100, next 220
	var p := cp.progress(&"c")
	assert_eq(p["level"], 2)
	assert_eq(p["into"], 50, "50 XP into level 2")
	assert_eq(p["needed"], 120, "and 120 needed to reach level 3")
	assert_false(p["is_max"])


func test_progress_at_cap_reports_max_without_dividing_by_zero() -> void:
	var cp := _make()
	cp.register_core(&"c")
	cp.add_xp(&"c", 5000)
	var p := cp.progress(&"c")
	assert_true(p["is_max"], "At MAX_CORE_LEVEL the readout flags the cap")
	assert_eq(p["needed"], 0, "and reports 0 needed so a UI bar has no zero divisor")
