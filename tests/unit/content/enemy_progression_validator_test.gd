## Enemy-DB Story 009 — ContentValidator ELZS progression-field family.
##
## Covers the three Story-009 BLOCKING checks in [EnemyValidator], none seam-gated:
##   AC-1 (TR-edb-017 level range): `level` must be in [1, 10] inclusive. 0 and 11 →
##          error; 1 and 10 → no error (an exclusive-bound impl wrongly rejects the edges).
##   AC-2 (TR-edb-015 / CP-F4 stored-equals-derived): authored `xp_value` must equal
##          `XpRewardFormula.derive_xp_value(level, class)`. Correct → no error; a value
##          off by the role multiplier (wrong-role / no-multiplier bug) → error naming
##          id + stored + derived. python3-verified: WILD lvl3 = 65, BOSS lvl3 = 130.
##   AC-3 (TR-edb-016 completion bonus): `completion_bonus_xp` must be `>= 0` AND `0`
##          unless the enemy is a BOSS. non-BOSS positive → error (a class-blind impl
##          passes it); BOSS positive → no error; zero → no error; negative → error.
##
## Every fixture is otherwise schema/stat/break/harvest/density/TTK clean, so a single
## progression verdict is asserted in isolation. Assertions target the specific Story-009
## codes. Deterministic in-memory catalogs, no seam, no file I/O. GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/enemy_database/spy_log_sink.gd")

var _spy: SpyLogSink

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## A schema/stat/break/harvest/density/TTK-clean enemy of the given class at `level`,
## with `xp_value` CP-F4-derived (so the progression family is silent by default) and
## `completion_bonus_xp` 0. Tests mutate level / xp_value / completion_bonus_xp to
## isolate one progression rule. WILD: structure 60 (TTK 3, early band); BOSS: structure
## 400 / armor 40 (TTK 14, in band). Region/pool counts sit inside every Story-008 band.
func _prog_enemy(cls: EnemyDef.EnemyClass, level: int, id: StringName) -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Progression Test Enemy"
	e.enemy_class  = cls
	e.tier         = 1
	e.core_element = PartDef.Element.VOLT
	var is_boss := cls == EnemyDef.EnemyClass.BOSS
	var structure: int = 400 if is_boss else 60
	var defense: int = 40 if is_boss else 10
	e.stats        = {
		"structure": structure,
		"armor": defense, "resistance": defense,
		"physical_power": 20, "energy_power": 10,
		"mobility": 15, "processing": 15,
		"cooling": 0, "energy_capacity": 0, "recharge": 0,
		"output_power": 0,
	}
	e.skills       = [&"basic_slash"]
	e.ai_profile   = &"AGGRESSIVE"
	e.flavor_text  = "A Story-009 progression fixture."
	# Two distinct regions; pool sized to the class density band (WILD 3, BOSS 4) and
	# strictly greater than the region count (harvest-decision clean).
	e.break_regions = [_region("r0", "event_0", structure), _region("r1", "event_1", structure)]
	var pool_size := 4 if is_boss else 3
	var pool: Array[Dictionary] = []
	for i in pool_size:
		pool.append({"id": "floor_%d" % i, "enabled": true})
	e.loot_pool     = pool
	# Progression fields — clean by default.
	e.level         = level
	e.xp_value      = XpRewardFormula.derive_xp_value(level, cls)
	e.completion_bonus_xp = 0
	return e


func _region(rid: String, event: String, structure: int) -> Dictionary:
	return {
		"region_id": rid,
		"region_fraction": 0.15,
		"break_hp": BreakHpFormula.derive_break_hp(structure, 0.15),
		"break_event": event,
	}


# ---------------------------------------------------------------------------
# Run + assertion helpers
# ---------------------------------------------------------------------------

func _run(enemy: EnemyDef) -> Dictionary:
	var catalog := EnemyCatalog.new()
	catalog.entries = [enemy] as Array[EnemyDef]
	var catalogs := ContentCatalogs.new()
	catalogs.parts   = PartCatalog.new()
	catalogs.enemies = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _logged(code: StringName) -> bool:
	for e: Dictionary in _spy.errors:
		if e["code"] == code:
			return true
	return false


func _error_data(code: StringName) -> Dictionary:
	for e: Dictionary in _spy.errors:
		if e["code"] == code:
			return e.get("detail", {})
	return {}


# ===========================================================================
# AC-1 — level range [1, 10] (BLOCKING)
# ===========================================================================

func test_level_zero_errors() -> void:
	# Arrange — level 0 is below the floor; xp kept derived so ONLY the range check fires.
	var e := _prog_enemy(EnemyDef.EnemyClass.WILD, 0, &"lvl_zero")
	# Act
	_run(e)
	# Assert
	assert_true(_logged(&"content_enemy_progression_level_range"), "level 0 → range error")


func test_level_eleven_errors() -> void:
	# Arrange — level 11 is above the roof.
	var e := _prog_enemy(EnemyDef.EnemyClass.WILD, 11, &"lvl_eleven")
	# Act
	_run(e)
	# Assert
	assert_true(_logged(&"content_enemy_progression_level_range"), "level 11 → range error")


func test_level_one_boundary_no_error() -> void:
	# Arrange — level 1 is the inclusive lower bound.
	var e := _prog_enemy(EnemyDef.EnemyClass.WILD, 1, &"lvl_one")
	# Act
	_run(e)
	# Assert — an exclusive-bound impl would wrongly reject this.
	assert_false(_logged(&"content_enemy_progression_level_range"), "level 1 is in range")


func test_level_ten_boundary_no_error() -> void:
	# Arrange — level 10 is the inclusive upper bound.
	var e := _prog_enemy(EnemyDef.EnemyClass.WILD, 10, &"lvl_ten")
	# Act
	_run(e)
	# Assert
	assert_false(_logged(&"content_enemy_progression_level_range"), "level 10 is in range")


# ===========================================================================
# AC-2 — xp_value stored-equals-derived (CP-F4, BLOCKING)
# ===========================================================================

func test_xp_value_correct_no_error() -> void:
	# Arrange — level 3 WILD, xp_value = CP-F4 derived (65). _prog_enemy derives it.
	var e := _prog_enemy(EnemyDef.EnemyClass.WILD, 3, &"xp_ok")
	# Act
	_run(e)
	# Assert
	assert_false(_logged(&"content_enemy_progression_xp_mismatch"), "derived xp 65 matches → no error")


func test_xp_value_off_by_role_multiplier_errors() -> void:
	# Arrange — a BOSS level 3 should derive 130; author mistakenly stores the WILD
	# value 65 (a no-multiplier / wrong-role bug). This is the canonical discriminator.
	var e := _prog_enemy(EnemyDef.EnemyClass.BOSS, 3, &"xp_wrong_role")
	e.xp_value = 65  # WILD-multiplier value on a BOSS — should be 130
	# Act
	_run(e)
	# Assert — error names both the stored and derived values.
	assert_true(_logged(&"content_enemy_progression_xp_mismatch"), "wrong-role xp → error")
	var data := _error_data(&"content_enemy_progression_xp_mismatch")
	assert_eq(data.get("stored"), 65, "stored value reported")
	assert_eq(data.get("derived"), 130, "derived BOSS value is 130")


func test_xp_value_boss_correct_no_error() -> void:
	# Arrange — BOSS level 3 with the correct derived value 130.
	var e := _prog_enemy(EnemyDef.EnemyClass.BOSS, 3, &"xp_boss_ok")
	# Act
	_run(e)
	# Assert
	assert_false(_logged(&"content_enemy_progression_xp_mismatch"), "derived BOSS xp 130 matches → no error")


# ===========================================================================
# AC-3 — completion_bonus_xp: sign + BOSS-only (BLOCKING)
# ===========================================================================

func test_completion_bonus_non_boss_positive_errors() -> void:
	# Arrange — a WILD with a positive completion bonus violates the boss-only rule.
	var e := _prog_enemy(EnemyDef.EnemyClass.WILD, 1, &"wild_bonus")
	e.completion_bonus_xp = 5
	# Act
	_run(e)
	# Assert — a class-blind impl would wrongly pass this.
	assert_true(_logged(&"content_enemy_progression_bonus_non_boss"), "WILD positive bonus → error")


func test_completion_bonus_boss_positive_no_error() -> void:
	# Arrange — a BOSS may carry a positive completion bonus (the gate reward vector).
	var e := _prog_enemy(EnemyDef.EnemyClass.BOSS, 1, &"boss_bonus")
	e.completion_bonus_xp = 310  # MVP Boss 1 value
	# Act
	_run(e)
	# Assert
	assert_false(_logged(&"content_enemy_progression_bonus_non_boss"), "BOSS positive bonus is legal")
	assert_false(_logged(&"content_enemy_progression_bonus_negative"), "positive is not negative")


func test_completion_bonus_zero_non_boss_no_error() -> void:
	# Arrange — a WILD with 0 bonus (the default) is always legal.
	var e := _prog_enemy(EnemyDef.EnemyClass.WILD, 1, &"wild_zero")
	e.completion_bonus_xp = 0
	# Act
	_run(e)
	# Assert
	assert_false(_logged(&"content_enemy_progression_bonus_non_boss"), "zero bonus is class-agnostic")
	assert_false(_logged(&"content_enemy_progression_bonus_negative"), "zero is not negative")


func test_completion_bonus_negative_errors() -> void:
	# Arrange — a negative bonus is nonsense regardless of class (here a BOSS, so the
	# boss-only rule is NOT the trigger — the sign rule is).
	var e := _prog_enemy(EnemyDef.EnemyClass.BOSS, 1, &"boss_negative")
	e.completion_bonus_xp = -1
	# Act
	_run(e)
	# Assert
	assert_true(_logged(&"content_enemy_progression_bonus_negative"), "negative bonus → error")
	assert_false(_logged(&"content_enemy_progression_bonus_non_boss"), "BOSS: boss-only rule not tripped")
