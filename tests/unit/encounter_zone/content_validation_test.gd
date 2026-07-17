## EZ-8 content-validation linter spec (Encounter Zone Story 008). `ZoneContentLinter`
## is an offline linter over ZoneDef fixtures — no RNG, no scene. Structural/scope
## faults are errors (block content shipping); Rule 2a weight-floor shortfalls are
## warnings. These fixtures ARE the acceptance evidence the real MVP zone `.tres` will
## later be validated against.
##   AC-EZ-10/11/12  density band anchors 0.07 / 0.15 / 0.35 (within 1e-9) + off-band.
##   AC-EZ-13        DENSE/STANDARD pacing ratio >= 1.6.
##   AC-EZ-14        unknown density_class → error + conservative STANDARD fallback.
##   AC-EZ-47        zone scope (valid zone_id + spawn_enabled).
##   AC-EZ-48        patch scope (3–4 patches, non-empty pools, positive weights).
##   AC-EZ-49        MVP boss config (2 bosses / OVERWORLD / WIN_COUNT / LIGHTER_REGATE
##                   / back-reference / escalation gap >= 3).
##   AC-EZ-50        de-duplicated WILD count in [6, 10].
##   AC-EZ-51        every boss_id resolves to a BOSS-class, spawn_enabled entry.
##   AC-EZ-54        terrain identity (A exclusive-enemy error / A2 10% warning / B 20%).
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const StubEnemyReader := preload("res://tests/unit/encounter_zone/stub_enemy_reader.gd")

const BOSS_1 := &"zone_boss_1"
const BOSS_2 := &"zone_boss_2"


# --- fixture builders -------------------------------------------------------

func _entry(id: StringName, weight: int, farmable: bool = false) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = id
	e.spawn_weight = weight
	e.is_farmable_target = farmable
	return e


func _patch(terrain_type: TerrainPatch.TerrainType, density_class: TerrainPatch.DensityClass, rate: float, entries: Array[SpawnEntry]) -> TerrainPatch:
	var p := TerrainPatch.new()
	p.terrain_type = terrain_type
	p.density_class = density_class
	p.encounter_rate = rate
	p.enemy_subpool = entries
	return p


func _boss(boss_id: StringName, required_wins: int, regate: int, requires_defeated: StringName = &"") -> BossEncounter:
	var b := BossEncounter.new()
	b.boss_id = boss_id
	b.placement = BossEncounter.Placement.OVERWORLD
	b.gate_type = BossEncounter.GateType.WIN_COUNT
	b.repeat_policy = BossEncounter.RepeatPolicy.LIGHTER_REGATE
	b.regate_params = {&"required_wins": regate}
	var gp := {&"required_wins": required_wins}
	if requires_defeated != &"":
		gp[&"requires_defeated"] = requires_defeated
	b.gate_params = gp
	return b


func _zone(patches: Array[TerrainPatch], bosses: Array[BossEncounter], zone_id: StringName = &"scrapfield", spawn_enabled: bool = true) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = zone_id
	z.spawn_enabled = spawn_enabled
	z.terrain_patches = patches
	z.boss_encounters = bosses
	return z


func _linter(spy: SpyLogSink, db: Variant = null) -> ZoneContentLinter:
	return ZoneContentLinter.new(spy, db)


## Canonical 3-patch, 8-WILD, 2-boss zone that passes every linter.
func _canonical_zone() -> ZoneDef:
	var grass := _patch(TerrainPatch.TerrainType.MECHANICAL_GRASS, TerrainPatch.DensityClass.STANDARD, 0.15,
		[_entry(&"rust_hound", 50), _entry(&"grass_skitter", 30), _entry(&"shared_drone", 20)] as Array[SpawnEntry])
	var junk := _patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.SPARSE, 0.07,
		[_entry(&"scrap_crawler", 50), _entry(&"junk_beetle", 30), _entry(&"shared_drone", 20)] as Array[SpawnEntry])
	var cavern := _patch(TerrainPatch.TerrainType.MACHINE_CAVERN, TerrainPatch.DensityClass.DENSE, 0.35,
		[_entry(&"cave_lurker", 50), _entry(&"pylon_crusher", 30), _entry(&"shared_drone", 20)] as Array[SpawnEntry])
	# Unique WILD ids: rust_hound, grass_skitter, shared_drone, scrap_crawler,
	# junk_beetle, cave_lurker, pylon_crusher = 7 ... add one more exclusive to hit 8.
	grass.enemy_subpool.append(_entry(&"grass_borer", 10))
	var bosses := [_boss(BOSS_1, 6, 2), _boss(BOSS_2, 10, 3, BOSS_1)] as Array[BossEncounter]
	return _zone([grass, junk, cavern] as Array[TerrainPatch], bosses)


func _boss_db() -> RefCounted:
	return StubEnemyReader.new() \
		.add(BOSS_1, EnemyDef.EnemyClass.BOSS) \
		.add(BOSS_2, EnemyDef.EnemyClass.BOSS)


# --- AC-EZ-10/11/12: density band anchors -----------------------------------

func test_ez8_density_band_rate_returns_anchors() -> void:
	var linter := _linter(SpyLogSink.new())
	assert_almost_eq(linter.density_band_rate(TerrainPatch.DensityClass.SPARSE), 0.07, 1e-9, "SPARSE anchor")
	assert_almost_eq(linter.density_band_rate(TerrainPatch.DensityClass.STANDARD), 0.15, 1e-9, "STANDARD anchor")
	assert_almost_eq(linter.density_band_rate(TerrainPatch.DensityClass.DENSE), 0.35, 1e-9, "DENSE anchor")


func test_ez8_patch_rate_off_band_fails() -> void:
	var spy := SpyLogSink.new()
	var linter := _linter(spy)
	var on_anchor := _patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.SPARSE, 0.07, [] as Array[SpawnEntry])
	var off_anchor := _patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.SPARSE, 0.15, [] as Array[SpawnEntry])
	assert_true(linter.validate_patch_encounter_rate(on_anchor), "SPARSE @ 0.07 matches its band")
	assert_false(linter.validate_patch_encounter_rate(off_anchor), "SPARSE @ 0.15 is off-band")
	assert_eq(spy.warns.size(), 1, "one off-band warning")
	assert_eq(spy.warns[0]["code"], &"ez_encounter_rate_off_band", "off-band warning code")


# --- AC-EZ-13: pacing ratio -------------------------------------------------

func test_ez8_pacing_ratio_floor() -> void:
	var spy := SpyLogSink.new()
	var linter := _linter(spy)
	assert_true(linter.validate_pacing_ratio(0.35, 0.15), "0.35/0.15 = 2.33 >= 1.6 passes")
	assert_false(linter.validate_pacing_ratio(0.21, 0.15), "0.21/0.15 = 1.4 < 1.6 fails")
	assert_eq(spy.warns.size(), 1, "one pacing-ratio warning")
	assert_eq(spy.warns[0]["code"], &"ez_pacing_ratio_too_low", "pacing-ratio warning code")


# --- AC-EZ-14: unknown density_class → conservative STANDARD fallback --------

func test_ez8_unknown_density_class_falls_back_to_standard() -> void:
	var spy := SpyLogSink.new()
	var linter := _linter(spy)
	# INVALID (0) is unrecognized as a band; a raw out-of-range int likewise.
	var rate := linter.density_band_rate(TerrainPatch.DensityClass.INVALID)
	assert_almost_eq(rate, 0.15, 1e-9, "unknown band falls back to STANDARD 0.15")
	assert_ne(rate, 0.35, "fallback is never DENSE (conservative)")
	assert_eq(spy.errors.size(), 1, "one unknown-band content error")
	assert_eq(spy.errors[0]["code"], &"ez_unknown_density_class", "unknown-band error code")


# --- AC-EZ-47: zone scope ---------------------------------------------------

func test_ez8_zone_scope_valid_passes() -> void:
	var spy := SpyLogSink.new()
	assert_true(_linter(spy).validate_zone_scope(_canonical_zone()), "valid zone scope passes")
	assert_eq(spy.total(), 0, "valid zone scope is silent")


func test_ez8_zone_scope_faults_fail() -> void:
	var spy := SpyLogSink.new()
	var no_id := _zone([] as Array[TerrainPatch], [] as Array[BossEncounter], &"")
	var disabled := _zone([] as Array[TerrainPatch], [] as Array[BossEncounter], &"scrapfield", false)
	assert_false(_linter(spy).validate_zone_scope(no_id), "empty zone_id fails")
	assert_false(_linter(spy).validate_zone_scope(disabled), "spawn_enabled=false fails")
	assert_eq(spy.errors.size(), 2, "one error per fault")


# --- AC-EZ-48: patch scope --------------------------------------------------

func test_ez8_patch_scope_valid_passes() -> void:
	var spy := SpyLogSink.new()
	assert_true(_linter(spy).validate_patch_scope(_canonical_zone()), "3 patches, non-empty, positive weights passes")
	assert_eq(spy.total(), 0, "valid patch scope is silent")


func test_ez8_patch_scope_too_many_patches_fails() -> void:
	var spy := SpyLogSink.new()
	var patches: Array[TerrainPatch] = []
	for i in 5:
		patches.append(_patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.STANDARD, 0.15,
			[_entry(&"e_%d" % i, 10)] as Array[SpawnEntry]))
	var zone := _zone(patches, [] as Array[BossEncounter])
	assert_false(_linter(spy).validate_patch_scope(zone), "5 patches exceeds the 3–4 MVP bound")
	assert_eq(spy.errors[0]["code"], &"ez_patch_count_out_of_range", "patch-count error code")


func test_ez8_patch_scope_empty_pool_and_zero_weight_fail() -> void:
	var spy := SpyLogSink.new()
	var empty_patch := _patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.STANDARD, 0.15, [] as Array[SpawnEntry])
	var zero_weight_patch := _patch(TerrainPatch.TerrainType.PYLON_FIELD, TerrainPatch.DensityClass.STANDARD, 0.15,
		[_entry(&"weightless", 0)] as Array[SpawnEntry])
	var full_patch := _patch(TerrainPatch.TerrainType.MECHANICAL_GRASS, TerrainPatch.DensityClass.STANDARD, 0.15,
		[_entry(&"ok", 5)] as Array[SpawnEntry])
	var zone := _zone([empty_patch, zero_weight_patch, full_patch] as Array[TerrainPatch], [] as Array[BossEncounter])
	assert_false(_linter(spy).validate_patch_scope(zone), "empty pool + weight-0 entry fail")
	var codes: Array = spy.errors.map(func(e): return e["code"])
	assert_true(codes.has(&"ez_patch_subpool_empty"), "empty-pool error logged")
	assert_true(codes.has(&"ez_spawn_weight_non_positive"), "non-positive-weight error logged")


# --- AC-EZ-49: MVP boss config ----------------------------------------------

func test_ez8_boss_config_canonical_passes() -> void:
	var spy := SpyLogSink.new()
	assert_true(_linter(spy).validate_boss_config(_canonical_zone()), "canonical 2-boss config passes")
	assert_eq(spy.total(), 0, "canonical boss config is silent")


func test_ez8_boss_config_missing_prereq_fails() -> void:
	# Boss 2 without the requires_defeated back-reference to Boss 1.
	var spy := SpyLogSink.new()
	var zone := _zone([] as Array[TerrainPatch], [_boss(BOSS_1, 6, 2), _boss(BOSS_2, 10, 3)] as Array[BossEncounter])
	assert_false(_linter(spy).validate_boss_config(zone), "missing back-reference fails")
	var codes: Array = spy.errors.map(func(e): return e["code"])
	assert_true(codes.has(&"ez_boss_prereq_mismatch"), "prereq-mismatch error logged")


func test_ez8_boss_config_small_gap_fails() -> void:
	# Escalation gap 8 − 6 = 2 < 3.
	var spy := SpyLogSink.new()
	var zone := _zone([] as Array[TerrainPatch], [_boss(BOSS_1, 6, 2), _boss(BOSS_2, 8, 3, BOSS_1)] as Array[BossEncounter])
	assert_false(_linter(spy).validate_boss_config(zone), "escalation gap < 3 fails")
	var codes: Array = spy.errors.map(func(e): return e["code"])
	assert_true(codes.has(&"ez_boss_escalation_gap_too_small"), "escalation-gap error logged")


func test_ez8_boss_config_reserved_gate_fails() -> void:
	# A WAVE boss must not pass the MVP boss config.
	var spy := SpyLogSink.new()
	var wave_boss := _boss(BOSS_2, 10, 3, BOSS_1)
	wave_boss.gate_type = BossEncounter.GateType.WAVE
	var zone := _zone([] as Array[TerrainPatch], [_boss(BOSS_1, 6, 2), wave_boss] as Array[BossEncounter])
	assert_false(_linter(spy).validate_boss_config(zone), "a reserved WAVE gate fails MVP boss config")
	var codes: Array = spy.errors.map(func(e): return e["code"])
	assert_true(codes.has(&"ez_boss_gate_type_invalid"), "reserved-gate error logged")


# --- AC-EZ-50: de-duplicated WILD count -------------------------------------

func test_ez8_wild_count_in_band_passes() -> void:
	var spy := SpyLogSink.new()
	assert_true(_linter(spy).validate_wild_count(_canonical_zone()), "8 unique WILDs is within [6, 10]")
	assert_eq(spy.total(), 0, "in-band WILD count is silent")


func test_ez8_wild_count_out_of_band_fails() -> void:
	var spy := SpyLogSink.new()
	# 5 unique enemies (below 6).
	var low_entries: Array[SpawnEntry] = []
	for i in 5:
		low_entries.append(_entry(&"e_%d" % i, 10))
	var low := _zone([_patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.STANDARD, 0.15, low_entries)] as Array[TerrainPatch], [] as Array[BossEncounter])
	# 11 unique enemies (above 10).
	var high_entries: Array[SpawnEntry] = []
	for i in 11:
		high_entries.append(_entry(&"h_%d" % i, 10))
	var high := _zone([_patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.STANDARD, 0.15, high_entries)] as Array[TerrainPatch], [] as Array[BossEncounter])
	assert_false(_linter(spy).validate_wild_count(low), "5 < 6 fails")
	assert_false(_linter(spy).validate_wild_count(high), "11 > 10 fails")
	assert_eq(spy.errors.size(), 2, "one out-of-range error per zone")


# --- AC-EZ-51: boss_id resolution -------------------------------------------

func test_ez8_boss_ids_resolve_valid_passes() -> void:
	var spy := SpyLogSink.new()
	assert_true(_linter(spy, _boss_db()).validate_boss_ids_resolve(_canonical_zone()), "BOSS-class enabled ids resolve")
	assert_eq(spy.total(), 0, "valid boss id resolution is silent")


func test_ez8_boss_ids_resolve_faults_fail() -> void:
	var spy := SpyLogSink.new()
	# Boss 1 resolves to a WILD-class enemy; Boss 2 is missing entirely.
	var db: RefCounted = StubEnemyReader.new().add(BOSS_1, EnemyDef.EnemyClass.WILD)
	var zone := _zone([] as Array[TerrainPatch], [_boss(BOSS_1, 6, 2), _boss(BOSS_2, 10, 3, BOSS_1)] as Array[BossEncounter])
	assert_false(_linter(spy, db).validate_boss_ids_resolve(zone), "wrong-class + missing boss ids fail")
	var codes: Array = spy.errors.map(func(e): return e["code"])
	assert_true(codes.has(&"ez_boss_enemy_wrong_class"), "wrong-class error logged")
	assert_true(codes.has(&"ez_boss_enemy_missing"), "missing-id error logged")


# --- AC-EZ-54: terrain identity ---------------------------------------------

func test_ez8_terrain_identity_valid_passes() -> void:
	var spy := SpyLogSink.new()
	assert_true(_linter(spy).validate_terrain_identity(_canonical_zone()), "each patch has a weighty exclusive enemy")
	assert_eq(spy.total(), 0, "valid terrain identity is silent")


func test_ez8_terrain_identity_cosmetic_pool_fails() -> void:
	# All patches share ONE identical pool → no patch has an exclusive enemy (A).
	var spy := SpyLogSink.new()
	var patches: Array[TerrainPatch] = []
	for t in [TerrainPatch.TerrainType.MECHANICAL_GRASS, TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.TerrainType.MACHINE_CAVERN]:
		patches.append(_patch(t, TerrainPatch.DensityClass.STANDARD, 0.15,
			[_entry(&"shared_a", 50), _entry(&"shared_b", 50)] as Array[SpawnEntry]))
	var zone := _zone(patches, [] as Array[BossEncounter])
	assert_false(_linter(spy).validate_terrain_identity(zone), "cosmetic terrain (shared pool) fails A")
	var codes: Array = spy.errors.map(func(e): return e["code"])
	assert_true(codes.has(&"ez_terrain_no_identity_enemy"), "no-identity-enemy error logged")


func test_ez8_token_exclusive_warns_on_weight_floor() -> void:
	# Each patch has an exclusive enemy but only at weight 1 in a 100-weight pool →
	# passes A, warns on A2 (below the 10% identity weight floor).
	var spy := SpyLogSink.new()
	var grass := _patch(TerrainPatch.TerrainType.MECHANICAL_GRASS, TerrainPatch.DensityClass.STANDARD, 0.15,
		[_entry(&"token_grass", 1), _entry(&"shared", 99)] as Array[SpawnEntry])
	var junk := _patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.STANDARD, 0.15,
		[_entry(&"token_junk", 1), _entry(&"shared", 99)] as Array[SpawnEntry])
	var zone := _zone([grass, junk] as Array[TerrainPatch], [] as Array[BossEncounter])
	assert_true(_linter(spy).validate_terrain_identity(zone), "A passes — each patch has an exclusive")
	assert_eq(spy.warns.size(), 2, "A2 warns per patch below the 10% identity floor")
	assert_eq(spy.warns[0]["code"], &"ez_identity_enemy_below_weight_floor", "identity weight-floor warning code")


func test_ez8_farmable_below_floor_warns() -> void:
	# A farmable-target entry at 15% of its patch (< 20%) → B warning.
	var spy := SpyLogSink.new()
	var grass := _patch(TerrainPatch.TerrainType.MECHANICAL_GRASS, TerrainPatch.DensityClass.STANDARD, 0.15,
		[_entry(&"grass_id", 85), _entry(&"farm_target", 15, true)] as Array[SpawnEntry])
	var junk := _patch(TerrainPatch.TerrainType.JUNKYARD, TerrainPatch.DensityClass.STANDARD, 0.15,
		[_entry(&"junk_id", 100)] as Array[SpawnEntry])
	var zone := _zone([grass, junk] as Array[TerrainPatch], [] as Array[BossEncounter])
	_linter(spy).validate_terrain_identity(zone)
	var codes: Array = spy.warns.map(func(w): return w["code"])
	assert_true(codes.has(&"ez_farmable_below_weight_floor"), "farmable-below-floor warning logged")
