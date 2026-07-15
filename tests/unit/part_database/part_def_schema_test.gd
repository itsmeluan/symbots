## Part-DB Story 002 — PartDef schema + enums + PartCatalog (schema-shape tests).
##
## Covers QA test cases AC-1 through AC-4:
##   AC-1: PartDef declares all Rule 1 fields with correct types and defaults,
##         including all 6 reserved-for-Full-Vision fields (TR-part-025).
##   AC-2: Content enums use explicit integer values from 1; 0 is not a valid
##         member value in any enum; all five enum fields default to 0 on a fresh
##         PartDef (reserved/invalid sentinel per ADR-0003).
##   AC-3: PartCatalog.entries is a typed Array[PartDef], empty by default, and
##         rejects non-PartDef elements (Godot 4.7 typed-array enforcement).
##   AC-4: Both class_name scripts parse cleanly and instantiate without error.
##
## Framework: GUT v9.6.1 · extends GutTest · Godot 4.7
extends GutTest


# ---------------------------------------------------------------------------
# AC-1: PartDef field presence and default types
# ---------------------------------------------------------------------------

## All Rule 1 scalar fields must be present on a fresh PartDef.
func test_part_def_schema_scalar_fields_present() -> void:
	# Arrange
	var pd := PartDef.new()

	# Assert — field presence for all named scalar fields.
	assert_true("id" in pd,               "id field must exist")
	assert_true("display_name" in pd,     "display_name field must exist")
	assert_true("slot_type" in pd,        "slot_type field must exist")
	assert_true("chassis_archetype" in pd,"chassis_archetype field must exist")
	assert_true("rarity" in pd,           "rarity field must exist")
	assert_true("manufacturer" in pd,     "manufacturer field must exist")
	assert_true("element" in pd,          "element field must exist")
	assert_true("damage_type" in pd,      "damage_type field must exist")
	assert_true("active_skill_id" in pd,  "active_skill_id field must exist")
	assert_true("passive_id" in pd,       "passive_id field must exist")
	assert_true("max_upgrade_tier" in pd, "max_upgrade_tier field must exist")
	assert_true("drop_enabled" in pd,     "drop_enabled field must exist")
	assert_true("part_family" in pd,      "part_family field must exist")
	assert_true("heat_generation" in pd,  "heat_generation field must exist")
	assert_true("ammo_cost" in pd,        "ammo_cost field must exist")
	assert_true("flavor_text" in pd,      "flavor_text field must exist")
	assert_true("sprite_id" in pd,        "sprite_id field must exist")
	assert_true("level_requirement" in pd,"level_requirement field must exist")


## Collection fields must exist and have the correct GDScript runtime type.
func test_part_def_schema_collection_fields_correct_types() -> void:
	# Arrange
	var pd := PartDef.new()

	# Assert — typeof() on the default value confirms the runtime container type.
	assert_eq(typeof(pd.stat_bonuses),    TYPE_DICTIONARY, "stat_bonuses is Dictionary")
	assert_eq(typeof(pd.synergy_tags),    TYPE_ARRAY,      "synergy_tags is Array")
	assert_eq(typeof(pd.drop_conditions), TYPE_ARRAY,      "drop_conditions is Array")
	assert_eq(typeof(pd.upgrade_effects), TYPE_ARRAY,      "upgrade_effects is Array")
	assert_eq(typeof(pd.level_growth),    TYPE_DICTIONARY, "level_growth is Dictionary")

	# Collections default to empty (not null).
	assert_eq(pd.stat_bonuses.size(),    0, "stat_bonuses defaults empty")
	assert_eq(pd.synergy_tags.size(),    0, "synergy_tags defaults empty")
	assert_eq(pd.drop_conditions.size(), 0, "drop_conditions defaults empty")
	assert_eq(pd.upgrade_effects.size(), 0, "upgrade_effects defaults empty")
	assert_eq(pd.level_growth.size(),    0, "level_growth defaults empty")


## All 6 reserved-for-Full-Vision fields (TR-part-025) must exist and read as
## their null-equivalent defaults on a fresh PartDef instance.
func test_part_def_schema_reserved_full_vision_fields_present_and_empty() -> void:
	# Arrange
	var pd := PartDef.new()

	# Assert — field presence.
	assert_true("motherboard_slot_type" in pd, "motherboard_slot_type must exist")
	assert_true("ram_cost" in pd,              "ram_cost must exist")
	assert_true("weight_class" in pd,          "weight_class must exist")
	assert_true("modification_slots" in pd,    "modification_slots must exist")
	assert_true("critical_output" in pd,       "critical_output must exist")
	assert_true("firewall" in pd,              "firewall must exist")

	# Assert — null-equivalent defaults.
	assert_eq(pd.motherboard_slot_type, &"", "motherboard_slot_type defaults &\"\"")
	assert_eq(pd.ram_cost,              0,   "ram_cost defaults 0")
	assert_eq(pd.weight_class,          &"", "weight_class defaults &\"\"")
	assert_eq(pd.modification_slots,    0,   "modification_slots defaults 0")
	assert_eq(pd.critical_output,       0,   "critical_output defaults 0")
	assert_eq(pd.firewall,              0,   "firewall defaults 0")


# ---------------------------------------------------------------------------
# AC-2: Enum integer values — explicit from 1; 0 is reserved/invalid sentinel
# ---------------------------------------------------------------------------

## SlotType must have 8 members, values 1–8, and must not contain 0.
func test_part_def_enums_slot_type_values_explicit_from_1() -> void:
	assert_eq(PartDef.SlotType.CORE,        1, "CORE == 1")
	assert_eq(PartDef.SlotType.CHASSIS,     2, "CHASSIS == 2")
	assert_eq(PartDef.SlotType.CHIPSET,     3, "CHIPSET == 3")
	assert_eq(PartDef.SlotType.ENERGY_CELL, 4, "ENERGY_CELL == 4")
	assert_eq(PartDef.SlotType.HEAD,        5, "HEAD == 5")
	assert_eq(PartDef.SlotType.ARMS,        6, "ARMS == 6")
	assert_eq(PartDef.SlotType.LEGS,        7, "LEGS == 7")
	assert_eq(PartDef.SlotType.WEAPON,      8, "WEAPON == 8")
	assert_false(0 in PartDef.SlotType.values(),
		"SlotType: 0 is reserved/invalid and must not appear in the value set")


## Rarity must have 4 members, values 1–4, and must not contain 0.
func test_part_def_enums_rarity_values_explicit_from_1() -> void:
	assert_eq(PartDef.Rarity.COMMON,     1, "COMMON == 1")
	assert_eq(PartDef.Rarity.RARE,       2, "RARE == 2")
	assert_eq(PartDef.Rarity.BOSS_GRADE, 3, "BOSS_GRADE == 3")
	assert_eq(PartDef.Rarity.PROTOTYPE,  4, "PROTOTYPE == 4")
	assert_false(0 in PartDef.Rarity.values(),
		"Rarity: 0 is reserved/invalid and must not appear in the value set")


## Element must start at 1; 0 must not appear. MVP values are 1–3;
## Full-Vision-reserved values 4–6 are present but must never be used in MVP content.
func test_part_def_enums_element_values_explicit_from_1() -> void:
	assert_eq(PartDef.Element.VOLT,      1, "VOLT == 1")
	assert_eq(PartDef.Element.THERMAL,   2, "THERMAL == 2")
	assert_eq(PartDef.Element.KINETIC,   3, "KINETIC == 3")
	assert_eq(PartDef.Element.CRYO,      4, "CRYO == 4 (Full Vision reserved)")
	assert_eq(PartDef.Element.CORROSIVE, 5, "CORROSIVE == 5 (Full Vision reserved)")
	assert_eq(PartDef.Element.DATA,      6, "DATA == 6 (Full Vision reserved)")
	assert_false(0 in PartDef.Element.values(),
		"Element: 0 is reserved/invalid and must not appear in the value set")


## DamageType must start at 1; 0 must not appear. MVP values 1–2; reserved 3–4.
func test_part_def_enums_damage_type_values_explicit_from_1() -> void:
	assert_eq(PartDef.DamageType.PHYSICAL, 1, "PHYSICAL == 1")
	assert_eq(PartDef.DamageType.ENERGY,   2, "ENERGY == 2")
	assert_eq(PartDef.DamageType.DATA,     3, "DATA == 3 (Full Vision reserved)")
	assert_eq(PartDef.DamageType.TRUE,     4, "TRUE == 4 (Full Vision reserved)")
	assert_false(0 in PartDef.DamageType.values(),
		"DamageType: 0 is reserved/invalid and must not appear in the value set")


## ChassisArchetype must have 5 members, values 1–5, and must not contain 0.
func test_part_def_enums_chassis_archetype_values_explicit_from_1() -> void:
	assert_eq(PartDef.ChassisArchetype.LIGHT_FRAME,     1, "LIGHT_FRAME == 1")
	assert_eq(PartDef.ChassisArchetype.HEAVY_FRAME,     2, "HEAVY_FRAME == 2")
	assert_eq(PartDef.ChassisArchetype.BALANCED_FRAME,  3, "BALANCED_FRAME == 3")
	assert_eq(PartDef.ChassisArchetype.GUARDIAN_FRAME,  4, "GUARDIAN_FRAME == 4")
	assert_eq(PartDef.ChassisArchetype.ARTILLERY_FRAME, 5, "ARTILLERY_FRAME == 5")
	assert_false(0 in PartDef.ChassisArchetype.values(),
		"ChassisArchetype: 0 is reserved/invalid and must not appear in the value set")


## A fresh PartDef.new() must read ALL five enum fields as 0 — the reserved/invalid
## sentinel (ADR-0003: "0 stays reserved/invalid to catch stale defaults").
## This ensures an unset .tres entry is distinguishable from any valid authored value.
func test_part_def_enums_all_enum_fields_default_to_zero_sentinel() -> void:
	# Arrange
	var pd := PartDef.new()

	# Assert — every enum field reads as 0 on a fresh (never-authored) instance.
	assert_eq(int(pd.slot_type),        0, "slot_type defaults to 0 (invalid sentinel)")
	assert_eq(int(pd.chassis_archetype),0, "chassis_archetype defaults to 0 (invalid sentinel)")
	assert_eq(int(pd.rarity),           0, "rarity defaults to 0 (invalid sentinel)")
	assert_eq(int(pd.element),          0, "element defaults to 0 (invalid sentinel)")
	assert_eq(int(pd.damage_type),      0, "damage_type defaults to 0 (invalid sentinel)")

	# Confirm 0 does not match any named member in any enum — it is truly invalid.
	assert_false(0 in PartDef.SlotType.values(),
		"0 is not a named SlotType value (sentinel only)")
	assert_false(0 in PartDef.ChassisArchetype.values(),
		"0 is not a named ChassisArchetype value (sentinel only)")
	assert_false(0 in PartDef.Rarity.values(),
		"0 is not a named Rarity value (sentinel only)")
	assert_false(0 in PartDef.Element.values(),
		"0 is not a named Element value (sentinel only)")
	assert_false(0 in PartDef.DamageType.values(),
		"0 is not a named DamageType value (sentinel only)")


# ---------------------------------------------------------------------------
# AC-3: PartCatalog entries — typed Array[PartDef]
# ---------------------------------------------------------------------------

## Fresh PartCatalog must have an empty Array[PartDef] for entries.
func test_part_catalog_schema_entries_empty_by_default() -> void:
	# Arrange / Act
	var cat := PartCatalog.new()

	# Assert
	assert_eq(cat.entries.size(), 0, "entries defaults to empty array")
	assert_eq(typeof(cat.entries), TYPE_ARRAY, "entries is an Array")


## A valid PartDef element appends successfully.
func test_part_catalog_schema_accepts_valid_part_def() -> void:
	# Arrange
	var cat := PartCatalog.new()
	var pd := PartDef.new()

	# Act
	cat.entries.append(pd)

	# Assert
	assert_eq(cat.entries.size(), 1, "PartDef appends successfully into entries")
	assert_true(cat.entries[0] is PartDef, "Appended element is a PartDef")


## Appending a non-PartDef to a typed Array[PartDef] is rejected at runtime.
##
## Godot 4.7 typed-array enforcement behavior: calling append() with an
## incompatible element pushes TWO engine errors and does NOT add the element.
## Error 1: "Attempted to push_back an object into a TypedArray that does not
##           inherit from 'GDScript'."
## Error 2: "Condition '!_p->typed.validate(value, "push_back")' is true."
## assert_engine_error_count(2) tells GUT these errors are expected, preventing
## them from being reported as "Unexpected Errors" and failing the test.
func test_part_catalog_schema_rejects_non_part_def_element() -> void:
	# Arrange
	var cat := PartCatalog.new()
	var wrong := Resource.new()  # Plain Resource, not a PartDef.

	# Act — the typed array will push 2 engine errors and silently reject the
	# element. The helper call isolates the engine-pushed errors.
	_quiet_typed_array_rejection(cat.entries, wrong)

	# Assert — exactly 2 engine errors were pushed (Godot 4.7 typed-array
	# enforcement), and the element was NOT added.
	assert_engine_error_count(2,
		"Typed Array[PartDef] pushes exactly 2 engine errors on invalid append")
	assert_eq(cat.entries.size(), 0,
		"Typed Array[PartDef] rejects a non-PartDef element — size stays 0")


## Helper: attempt to append an incompatible element to a typed array.
## Isolated so the engine-pushed errors are scoped to the call site.
func _quiet_typed_array_rejection(arr: Array[PartDef], wrong: Variant) -> void:
	arr.append(wrong)


# ---------------------------------------------------------------------------
# AC-4: Class registration — parse-clean gate
# ---------------------------------------------------------------------------

## Both class_name scripts must parse cleanly and register with the engine so
## that is_instance_of() and is Resource work. A parse-broken class silently
## fails class registration, making PartDef.new() return null or error.
func test_part_def_schema_class_registration_parses_cleanly() -> void:
	# Arrange / Act
	var pd := PartDef.new()
	var cat := PartCatalog.new()

	# Assert
	assert_true(pd is PartDef,      "PartDef.new() instantiates as PartDef")
	assert_true(cat is PartCatalog, "PartCatalog.new() instantiates as PartCatalog")
	assert_true(pd is Resource,     "PartDef is a Resource")
	assert_true(cat is Resource,    "PartCatalog is a Resource")
	assert_not_null(pd,  "PartDef.new() must not return null")
	assert_not_null(cat, "PartCatalog.new() must not return null")
