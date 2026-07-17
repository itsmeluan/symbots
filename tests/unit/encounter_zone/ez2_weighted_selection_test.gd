## EZ-2 weighted enemy-selection spec (Encounter Zone Story 002).
##
## `EncounterResolver.select_enemy(subpool)` performs the Rule 4 weighted draw:
## `roll = randi_range(1, total_weight)` (inclusive), walked `cumulative += w;
## if roll <= cumulative: return enemy_id`.
##   AC-EZ-04  distribution over 10,000 seeded draws (weight-ignoring impl fails).
##   AC-EZ-05/06/07  boundary rolls 10 / 16 / 20 — the `<=` + inclusive-range
##                   discriminators (a `<` walk or a [0,total-1) draw misplaces them).
##   AC-EZ-08  interior baseline rolls 7 / 13 / 19.
##   AC-EZ-09  single-entry pool — no guard, no divide-by-zero.
##
## Canonical fixture: iron_crawler(w10, cum 10), volt_drone(w6, cum 16),
## rust_hulk(w4, cum 20); total_weight = 20.
extends GutTest

const IntRng := preload("res://tests/unit/encounter_zone/ez_rng_int_doubles.gd")


func _entry(enemy_id: StringName, weight: int) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.enemy_id = enemy_id
	e.spawn_weight = weight
	return e


func _canonical_pool() -> Array[SpawnEntry]:
	return [
		_entry(&"iron_crawler", 10),
		_entry(&"volt_drone", 6),
		_entry(&"rust_hulk", 4),
	] as Array[SpawnEntry]


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- AC-EZ-04: distribution -------------------------------------------------

func test_ez2_distribution_matches_weights() -> void:
	# Arrange
	var pool := _canonical_pool()
	var resolver := EncounterResolver.new(_seeded_rng(99))
	var counts := {&"iron_crawler": 0, &"volt_drone": 0, &"rust_hulk": 0}

	# Act — 10,000 weighted draws.
	for _i in 10000:
		counts[resolver.select_enemy(pool)] += 1

	# Assert — inside the ±bands; a uniform (~3333 each) impl fails all three.
	assert_between(counts[&"iron_crawler"], 4750, 5250, "iron_crawler ~50%")
	assert_between(counts[&"volt_drone"], 2750, 3250, "volt_drone ~30%")
	assert_between(counts[&"rust_hulk"], 1750, 2250, "rust_hulk ~20%")


# --- AC-EZ-05/06/07: boundary rolls (the <= + inclusive-range discriminators) ---

func test_ez2_lower_boundary_roll_ten_selects_iron_crawler() -> void:
	# roll == cum(iron_crawler) == 10 → iron_crawler (a `<` walk falls to volt_drone).
	var resolver := EncounterResolver.new(IntRng.QueuedInt.new([10]))
	assert_eq(resolver.select_enemy(_canonical_pool()), &"iron_crawler", "roll 10 <= cum 10")


func test_ez2_middle_boundary_roll_sixteen_selects_volt_drone() -> void:
	# roll == cum(volt_drone) == 16 → volt_drone (a `<` walk continues to rust_hulk).
	var resolver := EncounterResolver.new(IntRng.QueuedInt.new([16]))
	assert_eq(resolver.select_enemy(_canonical_pool()), &"volt_drone", "roll 16 <= cum 16")


func test_ez2_upper_boundary_roll_twenty_selects_rust_hulk() -> void:
	# roll == total_weight == 20 → rust_hulk. Catches randi_range(0,total-1): max 19
	# would strand rust_hulk. Asserted on 20 specifically.
	var resolver := EncounterResolver.new(IntRng.QueuedInt.new([20]))
	assert_eq(resolver.select_enemy(_canonical_pool()), &"rust_hulk", "roll 20 <= cum 20 (inclusive top)")


# --- AC-EZ-08: interior baseline --------------------------------------------

func test_ez2_interior_rolls_baseline() -> void:
	# Arrange — three interior rolls, one per band.
	var resolver := EncounterResolver.new(IntRng.QueuedInt.new([7, 13, 19]))
	var pool := _canonical_pool()

	# Act / Assert
	assert_eq(resolver.select_enemy(pool), &"iron_crawler", "roll 7 → iron_crawler (<=10)")
	assert_eq(resolver.select_enemy(pool), &"volt_drone", "roll 13 → volt_drone (11..16)")
	assert_eq(resolver.select_enemy(pool), &"rust_hulk", "roll 19 → rust_hulk (17..20)")


# --- AC-EZ-09: single-entry pool --------------------------------------------

func test_ez2_single_entry_pool_returns_sole_member() -> void:
	# Arrange — total_weight == 1, randi_range(1,1) always 1; no special-casing needed.
	var pool := [_entry(&"iron_crawler", 1)] as Array[SpawnEntry]
	var rng := IntRng.QueuedInt.new([1])
	var resolver := EncounterResolver.new(rng)

	# Act
	var picked := resolver.select_enemy(pool)

	# Assert — sole member, one draw, no divide-by-zero / crash.
	assert_eq(picked, &"iron_crawler", "single-entry pool returns its only member")
	assert_eq(rng.call_count, 1, "exactly one weighted draw")
