## EZ-3 sub-pool-validation & empty-pool-sentinel spec (Encounter Zone Story 003).
##
## `EncounterResolver.filter_valid(raw, terrain_type)` excludes invalid entries with
## DELIBERATELY DISTINCT severities before EZ-2; `resolve_enemy(zone, patch)` chains
## filter → select and returns the empty-pool sentinel `StringName("")` + content error.
##   AC-EZ-26  empty sub-pool → sentinel + error naming zone_id + terrain_type.
##   AC-EZ-27  disabled enemy excluded silently (no error for the survivor).
##   AC-EZ-28  missing enemy excluded + error naming it; total_weight drops.
##   AC-EZ-29  all-disabled drains to empty → sentinel + error (EC-EZ-02 → EC-EZ-01).
##   AC-EZ-30  BOSS in a terrain pool excluded + error naming it + slot.
##   AC-EZ-32  spawn_weight == 0 excluded with WARNING (severity assert).
##   AC-EZ-33  spawn_weight < 0 excluded with ERROR (severity distinct from w0).
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const StubEnemyReader := preload("res://tests/unit/encounter_zone/stub_enemy_reader.gd")
const IntRng := preload("res://tests/unit/encounter_zone/ez_rng_int_doubles.gd")

const WILD := EnemyDef.EnemyClass.WILD
const BOSS := EnemyDef.EnemyClass.BOSS


func _entry(enemy_id: StringName, weight: int) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = enemy_id
	e.spawn_weight = weight
	return e


func _total_weight(pool: Array[SpawnEntry]) -> int:
	var t := 0
	for e in pool:
		t += e.spawn_weight
	return t


func _patch(subpool: Array[SpawnEntry]) -> TerrainPatch:
	var p := TerrainPatch.new()
	p.terrain_type = TerrainPatch.TerrainType.JUNKYARD
	p.enemy_subpool = subpool
	return p


func _zone(patch: TerrainPatch) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = &"scrapfield"
	z.terrain_patches = [patch]
	return z


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- AC-EZ-26: empty sub-pool → sentinel + error ----------------------------

func test_ez3_empty_subpool_returns_sentinel_and_errors() -> void:
	# Arrange — authored empty pool; a forced trigger would call resolve_enemy.
	var spy := SpyLogSink.new()
	var patch := _patch([] as Array[SpawnEntry])
	var zone := _zone(patch)
	var resolver := EncounterResolver.new(_seeded_rng(1), spy, StubEnemyReader.new())

	# Act
	var picked := resolver.resolve_enemy(zone, patch)

	# Assert — sentinel (no battle), content error naming zone_id + terrain_type.
	assert_eq(picked, StringName(""), "empty pool returns the no-encounter sentinel")
	assert_eq(spy.errors.size(), 1, "one EC-EZ-01 content error")
	assert_eq(spy.errors[0]["code"], &"ez_empty_subpool", "empty-subpool error code")
	assert_eq(spy.errors[0]["detail"]["zone_id"], &"scrapfield", "names the zone")
	assert_eq(spy.errors[0]["detail"]["terrain_type"], TerrainPatch.TerrainType.JUNKYARD, "names the terrain")


# --- AC-EZ-27: disabled enemy excluded silently -----------------------------

func test_ez3_disabled_enemy_excluded_without_error() -> void:
	# Arrange — retired_bot disabled; iron_crawler enabled.
	var spy := SpyLogSink.new()
	var db := StubEnemyReader.new()
	db.add(&"iron_crawler", WILD, true)
	db.add(&"retired_bot", WILD, false)
	var raw := [_entry(&"iron_crawler", 10), _entry(&"retired_bot", 10)] as Array[SpawnEntry]
	var resolver := EncounterResolver.new(_seeded_rng(3), spy, db)

	# Act
	var filtered := resolver.filter_valid(raw)

	# Assert — retired_bot gone, iron_crawler kept, and crucially NO diagnostic at all.
	assert_eq(filtered.size(), 1, "only the enabled enemy survives")
	assert_eq(filtered[0].enemy_id, &"iron_crawler", "iron_crawler retained")
	assert_eq(spy.total(), 0, "retirement is graceful — no error/warn for either enemy")
	# 1,000 selections never return the disabled enemy.
	var pool_resolver := EncounterResolver.new(_seeded_rng(3), spy, db)
	var iron_count := 0
	for _i in 1000:
		if pool_resolver.select_enemy(filtered) == &"iron_crawler":
			iron_count += 1
	assert_eq(iron_count, 1000, "iron_crawler returned every draw; retired_bot never")


# --- AC-EZ-28: missing enemy excluded + error -------------------------------

func test_ez3_missing_enemy_excluded_and_errored() -> void:
	# Arrange — ghost_id absent from the stub DB.
	var spy := SpyLogSink.new()
	var db := StubEnemyReader.new()
	db.add(&"known_enemy", WILD, true)
	var raw := [_entry(&"known_enemy", 10), _entry(&"ghost_id", 5)] as Array[SpawnEntry]
	var resolver := EncounterResolver.new(_seeded_rng(1), spy, db)

	# Act
	var filtered := resolver.filter_valid(raw)

	# Assert — error names ghost_id; it contributes 0 to total_weight.
	assert_eq(_total_weight(filtered), 10, "ghost_id contributes nothing to total_weight")
	assert_eq(filtered.size(), 1, "only known_enemy survives")
	assert_eq(spy.errors.size(), 1, "one missing-enemy error")
	assert_eq(spy.errors[0]["code"], &"ez_spawn_enemy_missing", "missing-enemy error code")
	assert_eq(spy.errors[0]["detail"]["enemy_id"], &"ghost_id", "names the missing id")


# --- AC-EZ-29: all-disabled drains to empty ---------------------------------

func test_ez3_all_disabled_drains_to_empty_sentinel() -> void:
	# Arrange — every entry disabled (composition of EC-EZ-02 into EC-EZ-01).
	var spy := SpyLogSink.new()
	var db := StubEnemyReader.new()
	db.add(&"retired_a", WILD, false)
	db.add(&"retired_b", WILD, false)
	var patch := _patch([_entry(&"retired_a", 10), _entry(&"retired_b", 5)] as Array[SpawnEntry])
	var zone := _zone(patch)
	var resolver := EncounterResolver.new(_seeded_rng(1), spy, db)

	# Act
	var picked := resolver.resolve_enemy(zone, patch)

	# Assert — drained pool yields the sentinel + the EC-EZ-01 error (disabled exclusion
	# itself stays silent, so the ONLY diagnostic is the empty-pool error).
	assert_eq(picked, StringName(""), "drained pool returns the sentinel")
	assert_eq(spy.errors.size(), 1, "only the empty-pool error (disabled exclusion is silent)")
	assert_eq(spy.errors[0]["code"], &"ez_empty_subpool", "empty-subpool error after drain")


# --- AC-EZ-30: BOSS in terrain pool excluded --------------------------------

func test_ez3_boss_in_terrain_pool_excluded_and_errored() -> void:
	# Arrange — zone_boss_1 is a BOSS mistakenly placed in a WILD terrain pool.
	var spy := SpyLogSink.new()
	var db := StubEnemyReader.new()
	db.add(&"iron_crawler", WILD, true)
	db.add(&"zone_boss_1", BOSS, true)
	var raw := [_entry(&"iron_crawler", 10), _entry(&"zone_boss_1", 5)] as Array[SpawnEntry]
	var resolver := EncounterResolver.new(_seeded_rng(1), spy, db)

	# Act
	var filtered := resolver.filter_valid(raw, TerrainPatch.TerrainType.JUNKYARD)

	# Assert — BOSS excluded from total_weight + error names it and the slot.
	assert_eq(_total_weight(filtered), 10, "BOSS excluded from total_weight")
	assert_eq(filtered.size(), 1, "only the WILD enemy survives")
	assert_eq(spy.errors.size(), 1, "one wrong-class error")
	assert_eq(spy.errors[0]["code"], &"ez_spawn_enemy_wrong_class", "wrong-class error code")
	assert_eq(spy.errors[0]["detail"]["enemy_id"], &"zone_boss_1", "names the boss")
	assert_eq(spy.errors[0]["detail"]["terrain_type"], TerrainPatch.TerrainType.JUNKYARD, "names the slot")


# --- AC-EZ-32: zero weight → WARNING ----------------------------------------

func test_ez3_zero_weight_excluded_with_warning() -> void:
	# Arrange — empty_shell at weight 0.
	var spy := SpyLogSink.new()
	var db := StubEnemyReader.new()
	db.add(&"iron_crawler", WILD, true)
	db.add(&"empty_shell", WILD, true)
	db.add(&"volt_drone", WILD, true)
	var raw := [_entry(&"iron_crawler", 10), _entry(&"empty_shell", 0), _entry(&"volt_drone", 5)] as Array[SpawnEntry]
	var resolver := EncounterResolver.new(_seeded_rng(1), spy, db)

	# Act
	var filtered := resolver.filter_valid(raw)

	# Assert — WARNING (not error) severity, excluded, total_weight == 15.
	assert_eq(_total_weight(filtered), 15, "zero-weight entry excluded from total_weight")
	assert_eq(spy.warns.size(), 1, "zero weight is a WARNING")
	assert_eq(spy.errors.size(), 0, "zero weight is NOT an error")
	assert_eq(spy.warns[0]["code"], &"ez_spawn_weight_zero", "zero-weight warning code")
	assert_eq(spy.warns[0]["detail"]["enemy_id"], &"empty_shell", "names the zero-weight entry")


# --- AC-EZ-33: negative weight → ERROR (distinct severity from w0) -----------

func test_ez3_negative_weight_excluded_with_error() -> void:
	# Arrange — corrupt_entry at weight -3.
	var spy := SpyLogSink.new()
	var db := StubEnemyReader.new()
	db.add(&"iron_crawler", WILD, true)
	db.add(&"corrupt_entry", WILD, true)
	var raw := [_entry(&"iron_crawler", 10), _entry(&"corrupt_entry", -3)] as Array[SpawnEntry]
	var resolver := EncounterResolver.new(_seeded_rng(1), spy, db)

	# Act
	var filtered := resolver.filter_valid(raw)

	# Assert — ERROR severity (distinct from the w0 warning), excluded, total_weight == 10.
	assert_eq(_total_weight(filtered), 10, "negative-weight entry excluded from total_weight")
	assert_eq(spy.errors.size(), 1, "negative weight is an ERROR")
	assert_eq(spy.warns.size(), 0, "negative weight is NOT a warning (distinct from w0)")
	assert_eq(spy.errors[0]["code"], &"ez_spawn_weight_negative", "negative-weight error code")
	assert_eq(spy.errors[0]["detail"]["enemy_id"], &"corrupt_entry", "names the corrupt entry")
