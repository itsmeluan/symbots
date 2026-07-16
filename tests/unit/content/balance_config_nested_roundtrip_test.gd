## Part-DB Story 010 spike — nested untyped `Dictionary` `.tres` round-trip.
##
## Story 001 verified only a FLAT typed `Dictionary[StringName, int]`. `BalanceConfig`
## ships two UNTYPED nested dictionaries whose round-trip fidelity was never proven on
## 4.7 and blocks authoring `assets/data/balance_config.tres`:
##   - `chassis_modifiers`: {int-enum → {StringName → float}}
##   - `stat_budgets`:      {int-enum → {int-enum → Array[int]}}
##
## The load-bearing risk is StringName-key degradation: the validator reads these with
## `.get(&"structure", 1.0)`, so if `ResourceSaver.save`→reload turns `&"structure"`
## into a plain String key, the lookup would silently miss on shipped `.tres` while
## passing on a bare `BalanceConfig.new()`. This spike saves a real BalanceConfig to
## `user://` and reloads it, asserting the nested keys/values survive by TYPE and VALUE.
## Framework: GUT · Godot 4.7.
extends GutTest

const SAVE_PATH := "user://spike_balance_config_roundtrip.tres"

var _reloaded: BalanceConfig


func before_all() -> void:
	# Save a defaults-populated BalanceConfig, then reload it from disk (not the
	# in-memory instance) so we exercise the real serializer, not object identity.
	var cfg := BalanceConfig.new()
	var save_err := ResourceSaver.save(cfg, SAVE_PATH)
	assert_eq(save_err, OK, "BalanceConfig saves to .tres without error")
	# cache_mode REPLACE forces a fresh parse from disk rather than returning the
	# cached instance we just saved.
	_reloaded = ResourceLoader.load(SAVE_PATH, "BalanceConfig", ResourceLoader.CACHE_MODE_REPLACE)


func after_all() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_reloaded_is_a_balance_config() -> void:
	assert_not_null(_reloaded, "the saved BalanceConfig reloads")
	assert_true(_reloaded is BalanceConfig, "reloaded resource keeps its BalanceConfig type")


# ---------------------------------------------------------------------------
# chassis_modifiers — {int-enum → {StringName → float}}
# ---------------------------------------------------------------------------

func test_chassis_modifiers_outer_int_keys_survive() -> void:
	# Outer keys are ChassisArchetype enum ints; .tres stores them as raw ints.
	var cm: Dictionary = _reloaded.chassis_modifiers
	assert_true(cm.has(PartDef.ChassisArchetype.LIGHT_FRAME),
		"outer int-enum key LIGHT_FRAME survives the round-trip")
	assert_true(cm.has(PartDef.ChassisArchetype.ARTILLERY_FRAME),
		"outer int-enum key ARTILLERY_FRAME survives the round-trip")
	assert_eq(cm.size(), 5, "all 5 archetype entries survive")


func test_chassis_modifiers_inner_stringname_key_lookup_holds() -> void:
	# The load-bearing check: the validator/formula reads inner keys as StringName via
	# .get(&"structure", 1.0). If the key degraded to String, this lookup would miss.
	var light: Dictionary = _reloaded.chassis_modifiers[PartDef.ChassisArchetype.LIGHT_FRAME]
	assert_true(light.has(&"structure"),
		"inner StringName key &\"structure\" is still resolvable after reload")
	assert_almost_eq(float(light.get(&"structure", -1.0)), 0.85, 0.0001,
		"the .get(&\"structure\", 1.0) read the validator/formula relies on returns 0.85")
	assert_almost_eq(float(light.get(&"mobility", -1.0)), 1.20, 0.0001,
		"inner &\"mobility\" → 1.20 survives by value")


func test_chassis_modifiers_absent_key_defaults_to_one() -> void:
	# Sparse storage contract: a stat absent from an archetype resolves to ×1.0.
	var balanced: Dictionary = _reloaded.chassis_modifiers[PartDef.ChassisArchetype.BALANCED_FRAME]
	assert_almost_eq(float(balanced.get(&"structure", 1.0)), 1.0, 0.0001,
		"a stat absent from an archetype's inner dict still defaults to ×1.0 after reload")


# ---------------------------------------------------------------------------
# stat_budgets — {int-enum → {int-enum → Array[int]}}
# ---------------------------------------------------------------------------

func test_stat_budgets_two_level_int_keys_survive() -> void:
	var sb: Dictionary = _reloaded.stat_budgets
	assert_true(sb.has(PartDef.SlotType.CHASSIS), "outer SlotType key survives")
	var chassis: Dictionary = sb[PartDef.SlotType.CHASSIS]
	assert_true(chassis.has(PartDef.Rarity.BOSS_GRADE), "inner Rarity key survives")


func test_stat_budgets_array_value_survives_by_type_and_value() -> void:
	# The value is an Array[int] pair [min, max]; the validator indexes [0]/[1].
	var chassis: Dictionary = _reloaded.stat_budgets[PartDef.SlotType.CHASSIS]
	var boss_budget = chassis[PartDef.Rarity.BOSS_GRADE]
	assert_true(boss_budget is Array, "the [min,max] budget value stays an Array after reload")
	assert_eq(boss_budget.size(), 2, "the budget pair keeps both bounds")
	assert_eq(int(boss_budget[0]), 55, "Chassis Boss-grade min bound survives as 55")
	assert_eq(int(boss_budget[1]), 68, "Chassis Boss-grade max bound survives as 68")


# ---------------------------------------------------------------------------
# Flat companion tables — sanity that simpler tables also survive
# ---------------------------------------------------------------------------

func test_flat_float_arrays_survive() -> void:
	assert_almost_eq(_reloaded.upgrade_multipliers[5], 2.00, 0.0001,
		"upgrade_multipliers[+5] survives as 2.00")
	assert_almost_eq(_reloaded.drop_rate_by_rarity[PartDef.Rarity.BOSS_GRADE], 0.001, 0.00001,
		"drop_rate_by_rarity Boss-grade stays 0.001 (never collapses to 0.0)")


func test_primary_cap_and_floor_int_maps_survive() -> void:
	assert_eq(int(_reloaded.primary_stat_common_caps[PartDef.SlotType.WEAPON]), 14,
		"Common primary CAP for WEAPON survives as 14")
	assert_eq(int(_reloaded.primary_stat_rare_floors[PartDef.SlotType.WEAPON]), 22,
		"Rare primary FLOOR for WEAPON survives as 22")
