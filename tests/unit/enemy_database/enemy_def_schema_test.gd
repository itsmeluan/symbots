## Enemy-DB Story 001 — EnemyDef / EnemyCatalog schema.
##
## Covers:
##   AC-1 — all 15 fields present with correct static types; default sentinels.
##   AC-2 — EnemyClass enum: INVALID==0, WILD==1, BOSS==2; ELITE/RIVAL absent.
##   AC-3 — .tres round-trip: nested break_regions + loot_pool dicts and StringName
##           id/skills survive serialisation intact (HIGH-risk 4.7 path).
##
## Framework: GUT · Godot 4.7.
extends GutTest

const SAVE_PATH := "user://enemy_def_roundtrip_probe.tres"


# ---------------------------------------------------------------------------
# Teardown — remove probe file after each test that may create it
# ---------------------------------------------------------------------------

func after_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SAVE_PATH)
		)


func after_all() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SAVE_PATH)
		)


# ---------------------------------------------------------------------------
# AC-1 — schema shape: all 15 fields present, correct types, correct defaults
# ---------------------------------------------------------------------------

func test_bare_instance_has_invalid_enemy_class_sentinel() -> void:
	# Arrange / Act
	var def := EnemyDef.new()
	# Assert
	assert_eq(int(def.enemy_class), 0, "enemy_class defaults to INVALID (0) sentinel")

func test_bare_instance_id_defaults_to_empty_stringname() -> void:
	var def := EnemyDef.new()
	assert_eq(def.id, &"", "id defaults to &\"\" (null-equivalent StringName)")
	assert_true(def.id is StringName, "id must be a StringName, not a String")

func test_bare_instance_stats_defaults_to_empty_dict() -> void:
	var def := EnemyDef.new()
	assert_eq(def.stats, {}, "stats defaults to empty Dictionary")

func test_bare_instance_skills_defaults_to_empty_array() -> void:
	var def := EnemyDef.new()
	assert_eq(def.skills, [], "skills defaults to empty Array")

func test_bare_instance_break_regions_defaults_to_empty_array() -> void:
	var def := EnemyDef.new()
	assert_eq(def.break_regions, [], "break_regions defaults to empty Array")

func test_bare_instance_loot_pool_defaults_to_empty_array() -> void:
	var def := EnemyDef.new()
	assert_eq(def.loot_pool, [], "loot_pool defaults to empty Array")

func test_bare_instance_ai_profile_defaults_to_empty_stringname() -> void:
	var def := EnemyDef.new()
	assert_eq(def.ai_profile, &"", "ai_profile defaults to &\"\" StringName")
	assert_true(def.ai_profile is StringName, "ai_profile must be a StringName")

func test_bare_instance_spawn_enabled_defaults_true() -> void:
	var def := EnemyDef.new()
	assert_true(def.spawn_enabled, "spawn_enabled defaults to true")

func test_bare_instance_numeric_fields_have_correct_defaults() -> void:
	var def := EnemyDef.new()
	assert_eq(def.tier, 1, "tier defaults to 1 (only legal MVP value)")
	assert_eq(def.level, 1, "level defaults to 1")
	assert_eq(def.xp_value, 0, "xp_value defaults to 0 sentinel")
	assert_eq(def.completion_bonus_xp, 0, "completion_bonus_xp defaults to 0")

func test_all_fifteen_fields_accept_authored_values() -> void:
	# Arrange: populate every field with a non-default value.
	var def := EnemyDef.new()
	def.id = &"rust_hound"
	def.display_name = "Rust Hound"
	def.enemy_class = EnemyDef.EnemyClass.WILD
	def.tier = 1
	def.core_element = PartDef.Element.KINETIC
	def.stats = {
		"structure": 60, "armor": 10, "resistance": 5,
		"physical_power": 30, "energy_power": 0,
		"mobility": 20, "processing": 15,
		"cooling": 0, "energy_capacity": 0, "recharge": 0, "output_power": 0
	}
	def.skills = [&"bite_strike"]
	def.ai_profile = &"wild_basic"
	def.break_regions = [{"region_id": "jaw", "region_fraction": 0.25,
		"break_hp": 15, "break_event": "jaw_break"}]
	def.loot_pool = [{"id": "scrapjaw_fang", "drop_condition": "",
		"break_event": "", "enabled": true}]
	def.spawn_enabled = true
	def.flavor_text = "A corroded automaton lurking in scrapfields."
	def.level = 3
	def.xp_value = 65
	def.completion_bonus_xp = 20

	# Assert every field round-trips through assignment.
	assert_eq(def.id, &"rust_hound")
	assert_eq(def.display_name, "Rust Hound")
	assert_eq(int(def.enemy_class), 1)
	assert_eq(def.tier, 1)
	assert_eq(int(def.core_element), 3, "KINETIC == 3")
	assert_eq(def.stats.get("structure"), 60)
	assert_eq(def.skills.size(), 1)
	assert_eq(def.skills[0], &"bite_strike")
	assert_eq(def.ai_profile, &"wild_basic")
	assert_eq(def.break_regions.size(), 1)
	assert_eq(def.loot_pool.size(), 1)
	assert_true(def.spawn_enabled)
	assert_eq(def.flavor_text, "A corroded automaton lurking in scrapfields.")
	assert_eq(def.level, 3)
	assert_eq(def.xp_value, 65)
	assert_eq(def.completion_bonus_xp, 20)


# ---------------------------------------------------------------------------
# AC-2 — EnemyClass enum contract
# ---------------------------------------------------------------------------

func test_enemy_class_invalid_is_zero() -> void:
	assert_eq(int(EnemyDef.EnemyClass.INVALID), 0, "INVALID must be 0")

func test_enemy_class_wild_is_one() -> void:
	assert_eq(int(EnemyDef.EnemyClass.WILD), 1, "WILD must be 1")

func test_enemy_class_boss_is_two() -> void:
	assert_eq(int(EnemyDef.EnemyClass.BOSS), 2, "BOSS must be 2")

func test_enemy_class_elite_is_absent() -> void:
	# ELITE must NOT be in EnemyClass (reserved for Full Vision, not yet declared).
	assert_false(
		EnemyDef.EnemyClass.keys().has("ELITE"),
		"ELITE must not be declared in EnemyClass"
	)

func test_enemy_class_rival_is_absent() -> void:
	# RIVAL must NOT be in EnemyClass (reserved for Full Vision, not yet declared).
	assert_false(
		EnemyDef.EnemyClass.keys().has("RIVAL"),
		"RIVAL must not be declared in EnemyClass"
	)

func test_enemy_class_has_exactly_three_members() -> void:
	# INVALID, WILD, BOSS — no more, no less for MVP.
	assert_eq(
		EnemyDef.EnemyClass.size(), 3,
		"EnemyClass must have exactly 3 members: INVALID, WILD, BOSS"
	)

func test_enemy_class_zero_is_not_a_named_value_other_than_invalid() -> void:
	# Only INVALID maps to 0; no other member should shadow it.
	assert_eq(EnemyDef.EnemyClass.find_key(0), "INVALID")


# ---------------------------------------------------------------------------
# AC-3 — .tres round-trip (HIGH-RISK 4.7 path)
#
# An EnemyDef with ≥2 break_regions, ≥3 loot_pool entries, a full 11-key
# stats dict, a StringName id, and Array[StringName] skills is saved with
# ResourceSaver and reloaded headless. Every scalar, nested dict value, and
# StringName key/type is asserted individually.
# ---------------------------------------------------------------------------

func test_tres_roundtrip_preserves_all_scalars_and_nested_dicts() -> void:
	# ---- Arrange --------------------------------------------------------
	var original := EnemyDef.new()
	original.id = &"slag_crusher"
	original.display_name = "Slag Crusher"
	original.enemy_class = EnemyDef.EnemyClass.BOSS
	original.tier = 1
	original.core_element = PartDef.Element.THERMAL
	original.stats = {
		"structure": 110,
		"armor": 40,
		"resistance": 35,
		"physical_power": 60,
		"energy_power": 45,
		"mobility": 25,
		"processing": 30,
		"cooling": 0,
		"energy_capacity": 0,
		"recharge": 0,
		"output_power": 0,
	}
	original.skills = [&"molten_slam", &"heat_wave", &"slag_barrage"]
	original.ai_profile = &"boss_aggressive"
	original.break_regions = [
		{
			"region_id": "left_arm",
			"region_fraction": 0.30,
			"break_hp": 33,
			"break_event": "arm_break",
			"loot_min": 1,
			"loot_max": 2,
		},
		{
			"region_id": "core_plate",
			"region_fraction": 0.45,
			"break_hp": 49,
			"break_event": "core_exposed",
			"loot_min": 2,
			"loot_max": 3,
		},
	]
	original.loot_pool = [
		{
			"id": "ironclad_slag_arm",
			"drop_condition": "",
			"break_event": "",
			"enabled": true,
		},
		{
			"id": "ironclad_heat_core",
			"drop_condition": "arm_break",
			"break_event": "arm_break",
			"enabled": true,
		},
		{
			"id": "thermal_chip_alpha",
			"drop_condition": "core_exposed",
			"break_event": "core_exposed",
			"enabled": true,
		},
	]
	original.spawn_enabled = true
	original.flavor_text = "A volcanic foundry colossus."
	original.level = 8
	original.xp_value = 215
	original.completion_bonus_xp = 100

	# ---- Act: save then reload -------------------------------------------
	var save_err: int = ResourceSaver.save(original, SAVE_PATH)
	assert_eq(save_err, OK, "ResourceSaver.save must return OK")

	var reloaded: EnemyDef = ResourceLoader.load(
		SAVE_PATH, "EnemyDef", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_not_null(reloaded, "ResourceLoader.load must return a non-null EnemyDef")

	# ---- Assert: scalars ------------------------------------------------
	assert_eq(reloaded.display_name, "Slag Crusher", "display_name survives")
	assert_eq(int(reloaded.enemy_class), 2, "enemy_class BOSS==2 survives")
	assert_eq(reloaded.tier, 1, "tier survives")
	assert_eq(int(reloaded.core_element), 2, "core_element THERMAL==2 survives")
	assert_true(reloaded.spawn_enabled, "spawn_enabled survives")
	assert_eq(reloaded.flavor_text, "A volcanic foundry colossus.", "flavor_text survives")
	assert_eq(reloaded.level, 8, "level survives")
	assert_eq(reloaded.xp_value, 215, "xp_value survives")
	assert_eq(reloaded.completion_bonus_xp, 100, "completion_bonus_xp survives")

	# ---- Assert: StringName id (CRITICAL — must not deserialise as String) ----
	assert_eq(reloaded.id, &"slag_crusher", "id value survives round-trip")
	assert_true(
		reloaded.id is StringName,
		"id must remain a StringName after round-trip (not coerced to String)"
	)

	# ---- Assert: ai_profile StringName ----------------------------------
	assert_eq(reloaded.ai_profile, &"boss_aggressive", "ai_profile value survives")
	assert_true(reloaded.ai_profile is StringName, "ai_profile stays StringName")

	# ---- Assert: skills Array[StringName] --------------------------------
	assert_eq(reloaded.skills.size(), 3, "skills array size survives")
	assert_eq(reloaded.skills[0], &"molten_slam", "skills[0] value survives")
	assert_eq(reloaded.skills[1], &"heat_wave", "skills[1] value survives")
	assert_eq(reloaded.skills[2], &"slag_barrage", "skills[2] value survives")
	assert_true(reloaded.skills[0] is StringName, "skills[0] stays StringName")
	assert_true(reloaded.skills[1] is StringName, "skills[1] stays StringName")
	assert_true(reloaded.skills[2] is StringName, "skills[2] stays StringName")

	# ---- Assert: stats Dictionary (all 11 keys) --------------------------
	assert_eq(reloaded.stats.size(), 11, "stats dict has 11 keys after round-trip")
	assert_eq(reloaded.stats.get("structure"), 110, "stats.structure survives")
	assert_eq(reloaded.stats.get("armor"), 40, "stats.armor survives")
	assert_eq(reloaded.stats.get("resistance"), 35, "stats.resistance survives")
	assert_eq(reloaded.stats.get("physical_power"), 60, "stats.physical_power survives")
	assert_eq(reloaded.stats.get("energy_power"), 45, "stats.energy_power survives")
	assert_eq(reloaded.stats.get("mobility"), 25, "stats.mobility survives")
	assert_eq(reloaded.stats.get("processing"), 30, "stats.processing survives")
	assert_eq(reloaded.stats.get("cooling"), 0, "stats.cooling (dead-data) survives")
	assert_eq(reloaded.stats.get("energy_capacity"), 0, "stats.energy_capacity (dead-data) survives")
	assert_eq(reloaded.stats.get("recharge"), 0, "stats.recharge (dead-data) survives")
	assert_eq(reloaded.stats.get("output_power"), 0, "stats.output_power survives")

	# ---- Assert: break_regions (≥2) -------------------------------------
	assert_eq(reloaded.break_regions.size(), 2, "break_regions size survives")

	var r0: Dictionary = reloaded.break_regions[0]
	assert_eq(r0.get("region_id"), "left_arm", "break_regions[0].region_id survives")
	assert_eq(r0.get("region_fraction"), 0.30, "break_regions[0].region_fraction survives")
	assert_eq(r0.get("break_hp"), 33, "break_regions[0].break_hp survives")
	assert_eq(r0.get("break_event"), "arm_break", "break_regions[0].break_event survives")
	assert_eq(r0.get("loot_min"), 1, "break_regions[0].loot_min survives")
	assert_eq(r0.get("loot_max"), 2, "break_regions[0].loot_max survives")

	var r1: Dictionary = reloaded.break_regions[1]
	assert_eq(r1.get("region_id"), "core_plate", "break_regions[1].region_id survives")
	assert_eq(r1.get("region_fraction"), 0.45, "break_regions[1].region_fraction survives")
	assert_eq(r1.get("break_hp"), 49, "break_regions[1].break_hp survives")
	assert_eq(r1.get("break_event"), "core_exposed", "break_regions[1].break_event survives")
	assert_eq(r1.get("loot_min"), 2, "break_regions[1].loot_min survives")
	assert_eq(r1.get("loot_max"), 3, "break_regions[1].loot_max survives")

	# ---- Assert: loot_pool (≥3) -----------------------------------------
	assert_eq(reloaded.loot_pool.size(), 3, "loot_pool size survives")

	var l0: Dictionary = reloaded.loot_pool[0]
	assert_eq(l0.get("id"), "ironclad_slag_arm", "loot_pool[0].id survives")
	assert_eq(l0.get("drop_condition"), "", "loot_pool[0].drop_condition survives")
	assert_eq(l0.get("break_event"), "", "loot_pool[0].break_event survives")
	assert_eq(l0.get("enabled"), true, "loot_pool[0].enabled survives")

	var l1: Dictionary = reloaded.loot_pool[1]
	assert_eq(l1.get("id"), "ironclad_heat_core", "loot_pool[1].id survives")
	assert_eq(l1.get("drop_condition"), "arm_break", "loot_pool[1].drop_condition survives")
	assert_eq(l1.get("break_event"), "arm_break", "loot_pool[1].break_event survives")
	assert_eq(l1.get("enabled"), true, "loot_pool[1].enabled survives")

	var l2: Dictionary = reloaded.loot_pool[2]
	assert_eq(l2.get("id"), "thermal_chip_alpha", "loot_pool[2].id survives")
	assert_eq(l2.get("drop_condition"), "core_exposed", "loot_pool[2].drop_condition survives")
	assert_eq(l2.get("break_event"), "core_exposed", "loot_pool[2].break_event survives")
	assert_eq(l2.get("enabled"), true, "loot_pool[2].enabled survives")


# ---------------------------------------------------------------------------
# EnemyCatalog — typed entries array
# ---------------------------------------------------------------------------

func test_catalog_entries_defaults_to_empty_typed_array() -> void:
	var cat := EnemyCatalog.new()
	assert_eq(cat.entries, [], "EnemyCatalog entries defaults to []")

func test_catalog_accepts_enemy_def_entries() -> void:
	var cat := EnemyCatalog.new()
	var def := EnemyDef.new()
	def.id = &"scrap_drone"
	cat.entries.append(def)
	assert_eq(cat.entries.size(), 1)
	assert_eq(cat.entries[0].id, &"scrap_drone")
