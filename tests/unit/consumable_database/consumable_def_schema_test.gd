## Consumable-DB Story 001 — ConsumableDef / ConsumableCatalog schema.
##
## Covers AC-1 (schema shape + bare-instance sentinels), AC-2 (enum integrity —
## 0 reserved, contiguous from 1), AC-3 (.tres round-trip preserves enum ints +
## effect_params dict). Framework: GUT · Godot 4.7.
extends GutTest

const SAVE_PATH := "user://consumable_def_roundtrip_probe.tres"


# ---------------------------------------------------------------------------
# AC-1 — schema shape
# ---------------------------------------------------------------------------

func test_bare_instance_has_invalid_enum_sentinels_and_empty_params() -> void:
	var cd := ConsumableDef.new()
	assert_eq(int(cd.rarity), 0, "rarity defaults to 0 INVALID sentinel")
	assert_eq(int(cd.effect_type), 0, "effect_type defaults to 0 INVALID sentinel")
	assert_eq(int(cd.use_context), 0, "use_context defaults to 0 INVALID sentinel")
	assert_eq(int(cd.target), 0, "target defaults to 0 INVALID sentinel")
	assert_eq(cd.effect_params, {}, "effect_params defaults to empty dict")
	assert_eq(cd.consumable_id, &"", "consumable_id defaults to &\"\"")

func test_all_ten_fields_present_and_typed() -> void:
	var cd := ConsumableDef.new()
	cd.consumable_id = &"weld_patch"
	cd.display_name = "Weld Patch"
	cd.rarity = ConsumableDef.Rarity.COMMON
	cd.effect_type = ConsumableDef.EffectType.RESTORE_STRUCTURE
	cd.effect_params = {"amount": 25}
	cd.use_context = ConsumableDef.UseContext.BOTH
	cd.target = ConsumableDef.Target.LIVING_TEAM_MEMBER
	cd.max_stack = 20
	cd.buy_price = 12
	cd.sell_price = 2
	assert_eq(cd.consumable_id, &"weld_patch")
	assert_eq(cd.display_name, "Weld Patch")
	assert_eq(int(cd.rarity), 1)
	assert_eq(int(cd.effect_type), 1)
	assert_eq(cd.effect_params, {"amount": 25})
	assert_eq(int(cd.use_context), 3)
	assert_eq(int(cd.target), 1)
	assert_eq(cd.max_stack, 20)
	assert_eq(cd.buy_price, 12)
	assert_eq(cd.sell_price, 2)


# ---------------------------------------------------------------------------
# AC-2 — enum integrity (0 reserved, contiguous from 1, APPEND-ONLY)
# ---------------------------------------------------------------------------

func test_rarity_values_contiguous_from_one() -> void:
	assert_eq(int(ConsumableDef.Rarity.COMMON), 1)
	assert_eq(int(ConsumableDef.Rarity.RARE), 2)
	assert_eq(int(ConsumableDef.Rarity.PROTOTYPE), 3)
	assert_eq(int(ConsumableDef.Rarity.BOSS_GRADE), 4, "BOSS_GRADE reserved but present")

func test_effect_type_values_contiguous_from_one() -> void:
	assert_eq(int(ConsumableDef.EffectType.RESTORE_STRUCTURE), 1)
	assert_eq(int(ConsumableDef.EffectType.REDUCE_HEAT), 2)
	assert_eq(int(ConsumableDef.EffectType.RESTORE_ENERGY), 3)
	assert_eq(int(ConsumableDef.EffectType.BOOST_DROP), 4)
	assert_eq(int(ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE), 5)

func test_use_context_and_target_values_contiguous_from_one() -> void:
	assert_eq(int(ConsumableDef.UseContext.BATTLE), 1)
	assert_eq(int(ConsumableDef.UseContext.WORLD), 2)
	assert_eq(int(ConsumableDef.UseContext.BOTH), 3)
	assert_eq(int(ConsumableDef.Target.LIVING_TEAM_MEMBER), 1)
	assert_eq(int(ConsumableDef.Target.CURRENT_BATTLE), 2)
	assert_eq(int(ConsumableDef.Target.OVERWORLD), 3)

func test_no_enum_uses_the_zero_slot() -> void:
	# 0 must stay reserved/INVALID across every enum.
	assert_false(ConsumableDef.Rarity.values().has(0), "Rarity must not use 0")
	assert_false(ConsumableDef.EffectType.values().has(0), "EffectType must not use 0")
	assert_false(ConsumableDef.UseContext.values().has(0), "UseContext must not use 0")
	assert_false(ConsumableDef.Target.values().has(0), "Target must not use 0")


# ---------------------------------------------------------------------------
# AC-3 — .tres round-trip preserves enum ints + effect_params dict
# ---------------------------------------------------------------------------

func test_tres_roundtrip_preserves_int_amount_params() -> void:
	var original := ConsumableDef.new()
	original.consumable_id = &"power_cell"
	original.rarity = ConsumableDef.Rarity.COMMON
	original.effect_type = ConsumableDef.EffectType.RESTORE_ENERGY
	original.effect_params = {"amount": 50}
	original.use_context = ConsumableDef.UseContext.BOTH
	original.target = ConsumableDef.Target.LIVING_TEAM_MEMBER
	var save_err := ResourceSaver.save(original, SAVE_PATH)
	var reloaded: ConsumableDef = ResourceLoader.load(SAVE_PATH, "ConsumableDef", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(save_err, OK, "ResourceSaver.save must succeed")
	assert_eq(int(reloaded.rarity), 1, "rarity int survives round-trip")
	assert_eq(int(reloaded.effect_type), 3, "effect_type int survives round-trip")
	assert_eq(int(reloaded.use_context), 3)
	assert_eq(int(reloaded.target), 1)
	assert_eq(reloaded.effect_params, {"amount": 50}, "int effect_params survives")

func test_tres_roundtrip_preserves_nested_encounter_params() -> void:
	var original := ConsumableDef.new()
	original.consumable_id = &"signal_jammer"
	original.effect_type = ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE
	original.effect_params = {"rate_multiplier": 0.1, "duration_steps": 20}
	var save_err := ResourceSaver.save(original, SAVE_PATH)
	var reloaded: ConsumableDef = ResourceLoader.load(SAVE_PATH, "ConsumableDef", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(save_err, OK)
	assert_eq(reloaded.effect_params.get("rate_multiplier"), 0.1, "float key survives by value")
	assert_eq(reloaded.effect_params.get("duration_steps"), 20, "int key survives by value")
	assert_true(reloaded.effect_params.get("duration_steps") is int, "duration_steps stays int")


# ---------------------------------------------------------------------------
# ConsumableCatalog
# ---------------------------------------------------------------------------

func test_catalog_holds_typed_entries_array() -> void:
	var cat := ConsumableCatalog.new()
	assert_eq(cat.entries, [], "catalog entries defaults to empty array")
	var cd := ConsumableDef.new()
	cd.consumable_id = &"repair_kit"
	cat.entries.append(cd)
	assert_eq(cat.entries.size(), 1)
	assert_eq(cat.entries[0].consumable_id, &"repair_kit")
