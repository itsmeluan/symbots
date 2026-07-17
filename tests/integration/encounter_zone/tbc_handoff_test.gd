## EZ-4 WILD/BOSS → TBC handoff seam spec (Encounter Zone Story 004, Integration).
##
## `EncounterResolver.start_wild_encounter(zone, patch)` composes EZ-3 filter + EZ-2
## select and hands the pick to an injected, duck-typed TBC seam ONCE as a WILD
## encounter; `start_boss_encounter(boss)` hands an accessible boss ONCE as a boss
## encounter. The handoff carries `(enemy_id, is_boss, fleeable)` where `fleeable`
## is derived structurally from class (`not is_boss`) in one place.
##   AC-EZ-15 A  WILD  → ("bolt_skitter", false, true)  — WILD is fleeable.
##   AC-EZ-15 B  BOSS  → ("zone_boss",   true,  false)  — boss NOT fleeable
##                       (the discriminator against a hardcoded `fleeable = true`).
##   guard       sentinel (empty pool) → NO handoff (impl note; deferred live AC-EZ-42).
##
## Stub TBC (inner class) records the triple — no live BattleController, no scene.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const StubEnemyReader := preload("res://tests/unit/encounter_zone/stub_enemy_reader.gd")
const IntRng := preload("res://tests/unit/encounter_zone/ez_rng_int_doubles.gd")

const WILD := EnemyDef.EnemyClass.WILD


## Duck-typed TBC battle-start seam. Mirrors the single call EncounterResolver makes;
## records each triple so tests can assert the exact handoff (and that it fires once).
class StubTbc extends RefCounted:
	var calls: Array = []

	func start_battle(enemy_id: StringName, is_boss: bool, fleeable: bool) -> void:
		calls.append({&"enemy_id": enemy_id, &"is_boss": is_boss, &"fleeable": fleeable})


func _entry(enemy_id: StringName, weight: int) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = enemy_id
	e.spawn_weight = weight
	return e


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


# --- AC-EZ-15 A: WILD handoff (fleeable) -------------------------------------

func test_ez4_wild_encounter_hands_off_fleeable() -> void:
	# Arrange — pool {bolt_skitter w8, iron_crawler w2}; EZ-2 forced to roll into the
	# bolt_skitter band [1,8]; both WILD + enabled so the filter keeps them.
	var tbc := StubTbc.new()
	var db := StubEnemyReader.new()
	db.add(&"bolt_skitter", WILD, true)
	db.add(&"iron_crawler", WILD, true)
	var patch := _patch([_entry(&"bolt_skitter", 8), _entry(&"iron_crawler", 2)] as Array[SpawnEntry])
	var zone := _zone(patch)
	var resolver := EncounterResolver.new(IntRng.QueuedInt.new([4]), SpyLogSink.new(), db, tbc)

	# Act — one resolved WILD encounter (EZ-1 assumed already fired).
	var picked := resolver.start_wild_encounter(zone, patch)

	# Assert — exactly one handoff, WILD is fleeable, no double-dispatch.
	assert_eq(picked, &"bolt_skitter", "EZ-2 selected bolt_skitter (roll 4 <= cum 8)")
	assert_eq(tbc.calls.size(), 1, "exactly one TBC handoff (no double-dispatch)")
	assert_eq(tbc.calls[0]["enemy_id"], &"bolt_skitter", "handoff carries the resolved enemy_id")
	assert_eq(tbc.calls[0]["is_boss"], false, "WILD encounter is not a boss")
	assert_eq(tbc.calls[0]["fleeable"], true, "WILD is fleeable (TBC Rule 7)")


# --- AC-EZ-15 B: BOSS handoff (NOT fleeable) --------------------------------

func test_ez4_boss_encounter_hands_off_not_fleeable() -> void:
	# Arrange — an OPEN (accessible) boss; gate accessibility is Stories 005–007.
	var tbc := StubTbc.new()
	var boss := BossEncounter.new()
	boss.boss_id = &"zone_boss"
	boss.gate_type = BossEncounter.GateType.OPEN
	var resolver := EncounterResolver.new(_seeded_rng(1), SpyLogSink.new(), StubEnemyReader.new(), tbc)

	# Act — player initiates the boss encounter.
	resolver.start_boss_encounter(boss)

	# Assert — one handoff; fleeable == false is the discriminator against a
	# hardcoded-true flag that Scenario A alone cannot catch.
	assert_eq(tbc.calls.size(), 1, "exactly one TBC handoff for the boss")
	assert_eq(tbc.calls[0]["enemy_id"], &"zone_boss", "handoff carries the boss_id")
	assert_eq(tbc.calls[0]["is_boss"], true, "boss encounter flagged is_boss")
	assert_eq(tbc.calls[0]["fleeable"], false, "a boss is NEVER fleeable")


# --- guard: sentinel → no handoff (impl note; live AC-EZ-42 deferred) --------

func test_ez4_sentinel_pool_produces_no_handoff() -> void:
	# Arrange — authored-empty pool → resolve_enemy returns the sentinel.
	var tbc := StubTbc.new()
	var patch := _patch([] as Array[SpawnEntry])
	var zone := _zone(patch)
	var resolver := EncounterResolver.new(_seeded_rng(1), SpyLogSink.new(), StubEnemyReader.new(), tbc)

	# Act
	var picked := resolver.start_wild_encounter(zone, patch)

	# Assert — sentinel returned AND no battle started ("no encounter" starts nothing).
	assert_eq(picked, StringName(""), "empty pool yields the no-encounter sentinel")
	assert_eq(tbc.calls.size(), 0, "a sentinel result must NOT hand off to TBC")
