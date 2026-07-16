## Enemy-DB Story 007 — ContentValidator loot-pool, rarity & boss-grade gating family.
##
## Covers [method EnemyValidator._check_enemy_loot] and its sub-checks, all reached
## only when the Part-DB referential seam ([method ContentValidator.set_part_lookup])
## is injected. Every fixture is otherwise fully valid (schema/stat/break-region) so a
## specific loot verdict can be asserted in isolation.
##
##   AC-1 (AC-ED-04a referential): an unresolved loot id → error; all-resolvable → none.
##          An empty Part DB errors every entry (proves the seam is consulted).
##   AC-2 (AC-ED-06 class rarity): WILD carrying Boss-grade → error; BOSS with 1 or 2
##          Boss-grade → ok; BOSS with 0 or 3 → error (all four count boundaries).
##   AC-3 (AC-ED-09 boss-grade gating): product invariant `0.001 × multiplier ≥ 0.5`.
##          multiplier 500 → passes; 499 → errors (boundary python3-verified:
##          0.001*500.0 == 0.5, 0.001*499.0 == 0.499). A gate on a non-break condition
##          also errors (unobtainable).
##   AC-4 (AC-ED-04b/c): all resolved parts disabled → error; some disabled → advisory
##          warn per entry, pool still ok.
##   AC-5 (AC-ED-18/19/dedup ADVISORY): un-gated Rare floor loot → warn; <2 break-gated
##          parts → warn; duplicate id → warn (deduped, pool still ok).
##   Seam-inert: with NO lookup injected, a ghost loot id produces NO loot error — the
##          non-regression contract that keeps every prior-story fixture green.
##
## Deterministic, in-memory catalogs + a fake part index (no file I/O). GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/enemy_database/spy_log_sink.gd")

var _spy: SpyLogSink

# ---------------------------------------------------------------------------
# Fake Part-DB seam
# ---------------------------------------------------------------------------

## Build a PartDef with the fields Story 007 reads. `conditions` is an Array of
## {condition: StringName, multiplier: float} dicts (authored .tres shape).
func _part(id: StringName, rarity: PartDef.Rarity, enabled: bool = true,
		conditions: Array = []) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = rarity
	p.drop_enabled = enabled
	# drop_conditions is typed Array[Dictionary] — coerce the untyped literal.
	var typed: Array[Dictionary] = []
	typed.assign(conditions)
	p.drop_conditions = typed
	return p


## A drop_conditions entry gating on `event` with `multiplier`.
func _cond(event: StringName, multiplier: float) -> Dictionary:
	return {"condition": event, "multiplier": multiplier}


## A lookup Callable over a {StringName: PartDef} index; returns null for unknown ids.
func _lookup_from(index: Dictionary) -> Callable:
	return func(id: StringName) -> PartDef: return index.get(id, null)


# ---------------------------------------------------------------------------
# Enemy fixtures
# ---------------------------------------------------------------------------

func _base_enemy(cls: EnemyDef.EnemyClass, structure: int, id: StringName) -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Loot Test Enemy"
	e.enemy_class  = cls
	e.tier         = 1
	e.stats        = {
		"structure": structure,
		"armor": 10, "resistance": 10,
		"physical_power": 20, "energy_power": 10,
		"mobility": 15, "processing": 15,
		"cooling": 0, "energy_capacity": 0, "recharge": 0,
		"output_power": 0,
	}
	e.skills       = [&"basic_slash"]
	e.ai_profile   = &"AGGRESSIVE"
	e.flavor_text  = "A Story-007 loot fixture."
	# Story 009: level 1 in range; xp_value = CP-F4 derived for this class so the
	# progression family stays clean (WILD → 45, BOSS → 90).
	e.level        = 1
	e.xp_value     = XpRewardFormula.derive_xp_value(1, cls)
	return e


## A break region linking to `event`; break_hp derived via EDB-1 (Story 006 valid).
func _region(rid: String, event: String, structure: int, fraction: float = 0.15) -> Dictionary:
	return {
		"region_id": rid,
		"region_fraction": fraction,
		"break_hp": BreakHpFormula.derive_break_hp(structure, fraction),
		"break_event": event,
	}


## A loot_pool entry. `event` (when non-empty) sets the entry-level drop_condition
## so the region↔loot connectivity (Story 006) is satisfied for that break event.
func _loot(id: String, event: String = "") -> Dictionary:
	var entry := {"id": id, "enabled": true}
	if event != "":
		entry["drop_condition"] = event
	return entry


## A clean, fully-valid BOSS: structure 400 / armor 40 (both TTK channels = 14,
## inside the BOSS 12–18 band), two regions (arm_broken / core_exposed), a pool of
## [1 Boss-grade gated ×500, 1 Rare gated, 2 Common floor] — 4 pool parts satisfy
## the Story-008 harvest-decision (4 > 2 regions) and BOSS density (4–6) bands.
## Passes every Story-004/005/006/007/008 check with ZERO warnings. Returns {enemy, index}.
func _clean_boss() -> Dictionary:
	var e := _base_enemy(EnemyDef.EnemyClass.BOSS, 400, &"forge_king")
	# Boss-tier defenses so the EDB-2 TTK band (AC-ED-14) is satisfied: at A_cal 53,
	# armor 40 → dmg 30 → ceil(400/30) = 14 turns (in the 12–18 band); same for resistance.
	e.stats["armor"] = 40
	e.stats["resistance"] = 40
	e.break_regions = [
		_region("arm", "arm_broken", 400),
		_region("core", "core_exposed", 400),
	]
	e.loot_pool = [
		_loot("boss_blade", "arm_broken"),
		_loot("core_shard", "core_exposed"),
		_loot("scrap_plate"),
		_loot("scrap_bolt"),
	]
	var index := {
		&"boss_blade": _part(&"boss_blade", PartDef.Rarity.BOSS_GRADE, true,
			[_cond(&"arm_broken", 500.0)]),
		&"core_shard": _part(&"core_shard", PartDef.Rarity.RARE, true,
			[_cond(&"core_exposed", 3.0)]),
		&"scrap_plate": _part(&"scrap_plate", PartDef.Rarity.COMMON),
		&"scrap_bolt": _part(&"scrap_bolt", PartDef.Rarity.COMMON),
	}
	return {"enemy": e, "index": index}


## A clean, fully-valid WILD: structure 60, two regions, pool of two gated Rares +
## one Common floor. No Boss-grade (Rule 8). Passes with ZERO warnings.
func _clean_wild() -> Dictionary:
	var e := _base_enemy(EnemyDef.EnemyClass.WILD, 60, &"scrap_hound")
	e.break_regions = [
		_region("leg", "leg_broken", 60),
		_region("sensor", "sensor_broken", 60),
	]
	e.loot_pool = [
		_loot("wild_gear", "leg_broken"),
		_loot("wild_coil", "sensor_broken"),
		_loot("scrap_bit"),
	]
	var index := {
		&"wild_gear": _part(&"wild_gear", PartDef.Rarity.RARE, true, [_cond(&"leg_broken", 3.0)]),
		&"wild_coil": _part(&"wild_coil", PartDef.Rarity.RARE, true, [_cond(&"sensor_broken", 3.0)]),
		&"scrap_bit": _part(&"scrap_bit", PartDef.Rarity.COMMON),
	}
	return {"enemy": e, "index": index}


# ---------------------------------------------------------------------------
# Run helpers
# ---------------------------------------------------------------------------

## Validate one enemy WITH the Part-DB seam injected from `index`.
func _run(enemy: EnemyDef, index: Dictionary) -> Dictionary:
	var catalog := EnemyCatalog.new()
	catalog.entries = [enemy]
	var catalogs := ContentCatalogs.new()
	catalogs.parts   = PartCatalog.new()
	catalogs.enemies = catalog
	_spy = SpyLogSink.new()
	var validator := ContentValidator.new()
	validator.set_part_lookup(_lookup_from(index))
	return validator.validate(catalogs, _spy)


## Validate one enemy WITHOUT injecting the seam (proves the family is inert).
func _run_no_seam(enemy: EnemyDef) -> Dictionary:
	var catalog := EnemyCatalog.new()
	catalog.entries = [enemy]
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


func _warned(code: StringName) -> bool:
	for w: Dictionary in _spy.warns:
		if w["code"] == code:
			return true
	return false


func _warn_count(code: StringName) -> int:
	var n := 0
	for w: Dictionary in _spy.warns:
		if w["code"] == code:
			n += 1
	return n


# ---------------------------------------------------------------------------
# Clean baselines — zero errors, zero warnings
# ---------------------------------------------------------------------------

func test_clean_boss_passes_no_errors_no_warnings() -> void:
	var f := _clean_boss()
	var r := _run(f["enemy"], f["index"])
	assert_true(r["ok"], "clean BOSS validates")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")
	assert_eq((r["warnings"] as Array).size(), 0, "no warnings")


func test_clean_wild_passes_no_errors_no_warnings() -> void:
	var f := _clean_wild()
	var r := _run(f["enemy"], f["index"])
	assert_true(r["ok"], "clean WILD validates")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")
	assert_eq((r["warnings"] as Array).size(), 0, "no warnings")


# ---------------------------------------------------------------------------
# AC-1 — referential integrity (AC-ED-04a)
# ---------------------------------------------------------------------------

func test_unresolved_part_id_errors() -> void:
	var f := _clean_wild()
	var e: EnemyDef = f["enemy"]
	e.loot_pool.append(_loot("part_ghost"))  # absent from the index
	var r := _run(e, f["index"])
	assert_true(_logged(&"content_enemy_loot_unresolved_part"), "ghost id errors")
	assert_false(r["ok"], "unresolved part is BLOCKING")


func test_all_resolvable_no_unresolved_error() -> void:
	var f := _clean_boss()
	_run(f["enemy"], f["index"])
	assert_false(_logged(&"content_enemy_loot_unresolved_part"), "all ids resolve")


func test_empty_part_db_errors_every_entry() -> void:
	var f := _clean_boss()
	var r := _run(f["enemy"], {})  # empty index — nothing resolves
	assert_eq(_error_count(&"content_enemy_loot_unresolved_part"), 4,
		"an empty Part DB errors all 4 pool entries — the seam is consulted")
	assert_false(r["ok"])


func _error_count(code: StringName) -> int:
	var n := 0
	for e: Dictionary in _spy.errors:
		if e["code"] == code:
			n += 1
	return n


# ---------------------------------------------------------------------------
# AC-2 — class/pool rarity (AC-ED-06)
# ---------------------------------------------------------------------------

func test_wild_carrying_boss_grade_errors() -> void:
	var f := _clean_wild()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	# Promote a resolvable WILD part to Boss-grade rarity.
	index[&"wild_gear"] = _part(&"wild_gear", PartDef.Rarity.BOSS_GRADE, true,
		[_cond(&"leg_broken", 500.0)])
	var r := _run(e, index)
	assert_true(_logged(&"content_enemy_loot_rarity_violation"),
		"a WILD carrying a Boss-grade part errors (Rule 8)")
	assert_false(r["ok"])


func test_boss_one_boss_grade_ok() -> void:
	var f := _clean_boss()  # exactly 1 Boss-grade by construction
	_run(f["enemy"], f["index"])
	assert_false(_logged(&"content_enemy_loot_rarity_violation"),
		"BOSS with 1 Boss-grade is valid")


func test_boss_two_boss_grade_ok() -> void:
	var f := _clean_boss()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	# Make core_shard a second Boss-grade, gated ×500 so AC-ED-09 stays clean.
	index[&"core_shard"] = _part(&"core_shard", PartDef.Rarity.BOSS_GRADE, true,
		[_cond(&"core_exposed", 500.0)])
	_run(e, index)
	assert_false(_logged(&"content_enemy_loot_rarity_violation"),
		"BOSS with 2 Boss-grade is valid")


func test_boss_zero_boss_grade_errors() -> void:
	var f := _clean_boss()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	# Demote the only Boss-grade to Rare → BOSS now has 0.
	index[&"boss_blade"] = _part(&"boss_blade", PartDef.Rarity.RARE, true,
		[_cond(&"arm_broken", 3.0)])
	var r := _run(e, index)
	assert_true(_logged(&"content_enemy_loot_rarity_violation"),
		"BOSS with 0 Boss-grade errors (Rule 2)")
	assert_false(r["ok"])


func test_boss_three_boss_grade_errors() -> void:
	var f := _clean_boss()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	# Add a third Boss-grade part to the pool, gated ×500.
	e.loot_pool.append(_loot("boss_core", "arm_broken"))
	index[&"boss_core"] = _part(&"boss_core", PartDef.Rarity.BOSS_GRADE, true,
		[_cond(&"arm_broken", 500.0)])
	index[&"core_shard"] = _part(&"core_shard", PartDef.Rarity.BOSS_GRADE, true,
		[_cond(&"core_exposed", 500.0)])
	var r := _run(e, index)
	assert_true(_logged(&"content_enemy_loot_rarity_violation"),
		"BOSS with 3 Boss-grade errors (>2)")
	assert_false(r["ok"])


# ---------------------------------------------------------------------------
# AC-3 — boss-grade break gating product invariant (AC-ED-09)
# ---------------------------------------------------------------------------

func test_boss_grade_multiplier_500_passes() -> void:
	var f := _clean_boss()  # boss_blade gated ×500 by construction
	_run(f["enemy"], f["index"])
	assert_false(_logged(&"content_enemy_loot_boss_grade_ungated"),
		"multiplier 500 → product 0.5 ≥ 0.5 passes")


func test_boss_grade_multiplier_499_errors() -> void:
	var f := _clean_boss()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	index[&"boss_blade"] = _part(&"boss_blade", PartDef.Rarity.BOSS_GRADE, true,
		[_cond(&"arm_broken", 499.0)])  # product 0.499 < 0.5
	var r := _run(e, index)
	assert_true(_logged(&"content_enemy_loot_boss_grade_ungated"),
		"multiplier 499 → product 0.499 < 0.5 errors")
	assert_false(r["ok"])


func test_boss_grade_condition_not_a_break_event_errors() -> void:
	var f := _clean_boss()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	# High multiplier, but gated on a condition this enemy never breaks.
	index[&"boss_blade"] = _part(&"boss_blade", PartDef.Rarity.BOSS_GRADE, true,
		[_cond(&"never_happens", 500.0)])
	var r := _run(e, index)
	assert_true(_logged(&"content_enemy_loot_boss_grade_ungated"),
		"a Boss-grade gate on a non-break condition is unobtainable → error")
	assert_false(r["ok"])


# ---------------------------------------------------------------------------
# AC-4 — disabled entries (AC-ED-04b/c)
# ---------------------------------------------------------------------------

func test_all_disabled_pool_errors() -> void:
	var f := _clean_wild()
	var index: Dictionary = f["index"]
	for key: StringName in index.keys():
		var p: PartDef = index[key]
		p.drop_enabled = false
	var r := _run(f["enemy"], index)
	assert_true(_logged(&"content_enemy_loot_all_disabled"),
		"every part disabled → the enemy drops nothing → error")
	assert_false(r["ok"])


func test_some_disabled_warns_not_errors() -> void:
	var f := _clean_wild()
	var index: Dictionary = f["index"]
	# Disable only the Common floor part — pool still has enabled drops.
	index[&"scrap_bit"] = _part(&"scrap_bit", PartDef.Rarity.COMMON, false)
	var r := _run(f["enemy"], index)
	assert_true(_warned(&"content_enemy_loot_disabled_entry"),
		"a disabled entry among enabled ones is ADVISORY")
	assert_false(_logged(&"content_enemy_loot_all_disabled"),
		"some-disabled is NOT all-disabled")
	assert_true(r["ok"], "advisory-only pool is still valid")


# ---------------------------------------------------------------------------
# AC-5 — advisory harvest/dedup warnings (AC-ED-18/19, TR-edb-024)
# ---------------------------------------------------------------------------

func test_floor_loot_rare_ungated_warns() -> void:
	var f := _clean_wild()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	# Add a Rare floor part with NO break-matching drop conditions.
	e.loot_pool.append(_loot("ungated_rare"))
	index[&"ungated_rare"] = _part(&"ungated_rare", PartDef.Rarity.RARE, true, [])
	var r := _run(e, index)
	assert_true(_warned(&"content_enemy_loot_floor_rarity"),
		"an un-gated Rare floor part is ADVISORY")
	assert_true(r["ok"], "floor-rarity is advisory-only")


func test_min_break_gated_below_two_warns() -> void:
	var f := _clean_wild()
	var e: EnemyDef = f["enemy"]
	var index: Dictionary = f["index"]
	# Ungate wild_coil (Common, no conditions) so only wild_gear stays break-gated.
	index[&"wild_coil"] = _part(&"wild_coil", PartDef.Rarity.COMMON)
	# Re-point sensor region's connectivity onto wild_gear so Story 006 stays clean.
	e.break_regions = [
		_region("leg", "leg_broken", 60),
	]
	e.loot_pool = [
		_loot("wild_gear", "leg_broken"),
		_loot("wild_coil"),
		_loot("scrap_bit"),
	]
	var r := _run(e, index)
	assert_true(_warned(&"content_enemy_loot_min_break_gated"),
		"only 1 break-gated part (< 2) is ADVISORY")
	assert_true(r["ok"], "min-break-gated is advisory-only")


func test_duplicate_part_id_warns_and_pool_ok() -> void:
	var f := _clean_wild()
	var e: EnemyDef = f["enemy"]
	# Duplicate an existing resolvable id.
	e.loot_pool.append(_loot("scrap_bit"))
	var r := _run(e, f["index"])
	assert_eq(_warn_count(&"content_enemy_loot_duplicate_part"), 1,
		"a duplicate id warns exactly once (deduped)")
	assert_true(r["ok"], "dedup is advisory-only")


# ---------------------------------------------------------------------------
# Seam-inert — the non-regression contract
# ---------------------------------------------------------------------------

func test_loot_family_inert_without_part_lookup() -> void:
	var f := _clean_boss()
	var e: EnemyDef = f["enemy"]
	e.loot_pool.append(_loot("part_ghost"))  # would error IF the seam were live
	var r := _run_no_seam(e)
	assert_false(_logged(&"content_enemy_loot_unresolved_part"),
		"with no Part-DB seam injected the loot family is inert (prior-story fixtures stay green)")
	assert_true(r["ok"], "no loot verdict without the seam")
