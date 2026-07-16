## Passive-DB Story 001 — PassiveDef schema + enums + PassiveCatalog (schema-shape).
##
## Covers the Story 001 ACs:
##   AC-PDB-03: PassiveDef declares every PASSIVE-CONTRACT-1 field with the correct
##         type and default, and exposes NO heat_generation / energy_cost property
##         (those live on the Part — passives fire automatically, cost nothing). A
##         fresh PassiveDef.new() reads all enum fields at the 0 sentinel and
##         behavior_params == {}.
##   Enum discipline (ADR-0003): every content enum uses explicit integer values
##         from 1; 0 is never a valid member value (it is the reserved/invalid
##         sentinel a stale/unset .tres slot reads as).
##
## Unlike MoveDef.break_bias there is NO "meaningful default" exception here — every
## PassiveDef enum defaults to the 0 sentinel so the validator (Stories 004/005)
## catches an unset field.
##
## Framework: GUT · extends GutTest · Godot 4.7
extends GutTest


# ---------------------------------------------------------------------------
# AC-PDB-03: PassiveDef field presence, types, and defaults
# ---------------------------------------------------------------------------

## All PASSIVE-CONTRACT-1 fields must be present on a fresh PassiveDef.
func test_passive_def_schema_fields_present() -> void:
	# Arrange
	var pd := PassiveDef.new()

	# Assert — field presence for every named field.
	assert_true("id" in pd,                "id field must exist")
	assert_true("display_name" in pd,      "display_name field must exist")
	assert_true("short_description" in pd, "short_description field must exist")
	assert_true("trigger_category" in pd,  "trigger_category field must exist")
	assert_true("behavior_class" in pd,    "behavior_class field must exist")
	assert_true("scope" in pd,             "scope field must exist")
	assert_true("stacking_policy" in pd,   "stacking_policy field must exist")
	assert_true("passive_class" in pd,     "passive_class field must exist")
	assert_true("behavior_params" in pd,   "behavior_params field must exist")


## AC-PDB-03: passives fire automatically and consume no player resources —
## heat_generation and energy_cost live on the Part, NEVER the passive.
func test_passive_def_schema_excludes_part_only_fields() -> void:
	# Arrange
	var pd := PassiveDef.new()

	# Assert — the two Part-owned resource fields must be absent from the schema.
	assert_false("heat_generation" in pd,
		"heat_generation must NOT exist on PassiveDef (it lives on the Part) — AC-PDB-03")
	assert_false("energy_cost" in pd,
		"energy_cost must NOT exist on PassiveDef (it lives on the Part) — AC-PDB-03")


## Identity/display scalar defaults on a fresh instance.
func test_passive_def_schema_scalar_defaults() -> void:
	# Arrange
	var pd := PassiveDef.new()

	# Assert — StringName / String defaults.
	assert_eq(pd.id,                &"", "id defaults &\"\"")
	assert_eq(pd.display_name,      "",  "display_name defaults \"\"")
	assert_eq(pd.short_description, "",  "short_description defaults \"\"")


## behavior_params must exist, be a Dictionary, and default empty (not null).
func test_passive_def_schema_behavior_params_default_empty() -> void:
	# Arrange
	var pd := PassiveDef.new()

	# Assert
	assert_eq(typeof(pd.behavior_params), TYPE_DICTIONARY, "behavior_params is Dictionary")
	assert_eq(pd.behavior_params.size(), 0, "behavior_params defaults empty {}")


## Every enum field on a fresh PassiveDef reads the 0 sentinel (reserved/invalid),
## so an unset .tres entry is caught by the ContentValidator. No exceptions.
func test_passive_def_schema_enum_field_defaults_sentinel() -> void:
	# Arrange
	var pd := PassiveDef.new()

	# Assert — every enum defaults to 0 (invalid, never a named member).
	assert_eq(int(pd.trigger_category), 0, "trigger_category defaults 0 (invalid sentinel)")
	assert_eq(int(pd.behavior_class),   0, "behavior_class defaults 0 (invalid sentinel)")
	assert_eq(int(pd.scope),            0, "scope defaults 0 (null for non-ON_HIT)")
	assert_eq(int(pd.stacking_policy),  0, "stacking_policy defaults 0 (invalid sentinel)")
	assert_eq(int(pd.passive_class),    0, "passive_class defaults 0 (invalid sentinel)")


## A fully-populated STATUS_RIDER record carries all fields with the right types —
## the well-formed-shape happy path.
func test_passive_def_schema_well_formed_status_rider_record() -> void:
	# Arrange — author a plausible volt shock rider.
	var pd := PassiveDef.new()
	pd.id                = &"volt_shock_on_hit"
	pd.display_name      = "Overcharge"
	pd.short_description = "Damaging hits shock the target."
	pd.trigger_category  = PassiveDef.TriggerCategory.ON_HIT
	pd.behavior_class    = PassiveDef.BehaviorClass.STATUS_RIDER
	pd.scope             = PassiveDef.Scope.ANY_DAMAGE
	pd.stacking_policy   = PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER
	pd.passive_class     = PassiveDef.PassiveClass.STATUS_RIDER
	pd.behavior_params   = {"status_id": &"shock", "duration": 1}

	# Assert — all fields read back as authored and typed.
	assert_eq(pd.id,               &"volt_shock_on_hit",                        "id round-trips")
	assert_eq(pd.display_name,     "Overcharge",                               "display_name round-trips")
	assert_eq(pd.trigger_category, PassiveDef.TriggerCategory.ON_HIT,          "trigger round-trips")
	assert_eq(pd.behavior_class,   PassiveDef.BehaviorClass.STATUS_RIDER,      "behavior_class round-trips")
	assert_eq(pd.scope,            PassiveDef.Scope.ANY_DAMAGE,                "scope round-trips")
	assert_eq(pd.stacking_policy,  PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER, "stacking round-trips")
	assert_eq(pd.passive_class,    PassiveDef.PassiveClass.STATUS_RIDER,       "passive_class round-trips")
	assert_eq(pd.behavior_params["status_id"], &"shock", "behavior_params status_id round-trips")
	assert_eq(pd.behavior_params["duration"],  1,        "behavior_params duration round-trips")


# ---------------------------------------------------------------------------
# Enum integer values — explicit from 1; 0 is reserved/invalid sentinel
# ---------------------------------------------------------------------------

## BehaviorClass must have 4 members, values 1–4, and must not contain 0.
func test_passive_def_enums_behavior_class_values_explicit_from_1() -> void:
	assert_eq(PassiveDef.BehaviorClass.STATUS_RIDER,      1, "STATUS_RIDER == 1")
	assert_eq(PassiveDef.BehaviorClass.STAT_AURA,         2, "STAT_AURA == 2")
	assert_eq(PassiveDef.BehaviorClass.RESOURCE_EFFECT,   3, "RESOURCE_EFFECT == 3")
	assert_eq(PassiveDef.BehaviorClass.STRUCTURAL_EFFECT, 4, "STRUCTURAL_EFFECT == 4")
	assert_false(0 in PassiveDef.BehaviorClass.values(),
		"BehaviorClass: 0 is reserved/invalid and must not appear in the value set")


## TriggerCategory must have 5 members, values 1–5, and must not contain 0.
func test_passive_def_enums_trigger_category_values_explicit_from_1() -> void:
	assert_eq(PassiveDef.TriggerCategory.ON_HIT,          1, "ON_HIT == 1")
	assert_eq(PassiveDef.TriggerCategory.ON_TURN_START,   2, "ON_TURN_START == 2")
	assert_eq(PassiveDef.TriggerCategory.ON_BATTLE_START, 3, "ON_BATTLE_START == 3")
	assert_eq(PassiveDef.TriggerCategory.ON_OVERHEAT,     4, "ON_OVERHEAT == 4")
	assert_eq(PassiveDef.TriggerCategory.PERSISTENT,      5, "PERSISTENT == 5")
	assert_false(0 in PassiveDef.TriggerCategory.values(),
		"TriggerCategory: 0 is reserved/invalid and must not appear in the value set")


## Scope must have 2 members, values 1–2, and must not contain 0.
func test_passive_def_enums_scope_values_explicit_from_1() -> void:
	assert_eq(PassiveDef.Scope.ANY_DAMAGE,  1, "ANY_DAMAGE == 1")
	assert_eq(PassiveDef.Scope.WEAPON_ONLY, 2, "WEAPON_ONLY == 2")
	assert_false(0 in PassiveDef.Scope.values(),
		"Scope: 0 is reserved/invalid and must not appear in the value set")


## StackingPolicy must have 3 members, values 1–3, and must not contain 0.
func test_passive_def_enums_stacking_policy_values_explicit_from_1() -> void:
	assert_eq(PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER, 1, "UNIQUE_PER_TRIGGER == 1")
	assert_eq(PassiveDef.StackingPolicy.UNIQUE,             2, "UNIQUE == 2")
	assert_eq(PassiveDef.StackingPolicy.STACKABLE,          3, "STACKABLE == 3")
	assert_false(0 in PassiveDef.StackingPolicy.values(),
		"StackingPolicy: 0 is reserved/invalid and must not appear in the value set")


## PassiveClass must have 3 members, values 1–3, and must not contain 0.
func test_passive_def_enums_passive_class_values_explicit_from_1() -> void:
	assert_eq(PassiveDef.PassiveClass.STATUS_RIDER,    1, "STATUS_RIDER == 1")
	assert_eq(PassiveDef.PassiveClass.CORE_TRAIT,      2, "CORE_TRAIT == 2")
	assert_eq(PassiveDef.PassiveClass.UPGRADE_PASSIVE, 3, "UPGRADE_PASSIVE == 3")
	assert_false(0 in PassiveDef.PassiveClass.values(),
		"PassiveClass: 0 is reserved/invalid and must not appear in the value set")


# ---------------------------------------------------------------------------
# .tres round-trip — enum ints + behavior_params survive save/reload
# ---------------------------------------------------------------------------

## A saved + reloaded PassiveDef preserves its enum integer values and
## behavior_params contents. Guards against silent schema drift on serialization.
func test_passive_def_tres_round_trips_enums_and_params() -> void:
	# Arrange — author, then save to a user:// temp and reload with cache bypassed.
	var pd := PassiveDef.new()
	pd.id               = &"kinetic_stagger_on_hit"
	pd.trigger_category = PassiveDef.TriggerCategory.ON_HIT
	pd.behavior_class   = PassiveDef.BehaviorClass.STATUS_RIDER
	pd.scope            = PassiveDef.Scope.ANY_DAMAGE
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER
	pd.passive_class    = PassiveDef.PassiveClass.STATUS_RIDER
	pd.behavior_params  = {"status_id": &"stagger", "duration": 1}
	var tmp_path := "user://passive_roundtrip_probe.tres"

	# Act
	var save_err := ResourceSaver.save(pd, tmp_path)
	var reloaded: PassiveDef = ResourceLoader.load(tmp_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Assert — save succeeded and every enum int + params entry survived.
	assert_eq(save_err, OK, "PassiveDef saves to .tres without error")
	assert_not_null(reloaded, "PassiveDef reloads from .tres")
	assert_eq(reloaded.id, &"kinetic_stagger_on_hit", "id survives round-trip")
	assert_eq(int(reloaded.trigger_category), PassiveDef.TriggerCategory.ON_HIT, "trigger int survives")
	assert_eq(int(reloaded.behavior_class), PassiveDef.BehaviorClass.STATUS_RIDER, "behavior_class int survives")
	assert_eq(int(reloaded.stacking_policy), PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER, "stacking int survives")
	assert_eq(reloaded.behavior_params["status_id"], &"stagger", "params status_id survives")
	assert_eq(reloaded.behavior_params["duration"], 1, "params duration survives")


# ---------------------------------------------------------------------------
# PassiveCatalog — typed Array[PassiveDef]
# ---------------------------------------------------------------------------

## Fresh PassiveCatalog must have an empty Array[PassiveDef] for entries.
func test_passive_catalog_schema_entries_empty_by_default() -> void:
	# Arrange / Act
	var cat := PassiveCatalog.new()

	# Assert
	assert_eq(cat.entries.size(), 0, "entries defaults to empty array")
	assert_eq(typeof(cat.entries), TYPE_ARRAY, "entries is an Array")


## A valid PassiveDef element appends successfully.
func test_passive_catalog_schema_accepts_valid_passive_def() -> void:
	# Arrange
	var cat := PassiveCatalog.new()
	var pd := PassiveDef.new()

	# Act
	cat.entries.append(pd)

	# Assert
	assert_eq(cat.entries.size(), 1, "PassiveDef appends successfully into entries")
	assert_true(cat.entries[0] is PassiveDef, "Appended element is a PassiveDef")


## Appending a non-PassiveDef to a typed Array[PassiveDef] is rejected at runtime.
## Godot 4.7 typed-array enforcement pushes TWO engine errors and rejects the element.
func test_passive_catalog_schema_rejects_non_passive_def_element() -> void:
	# Arrange
	var cat := PassiveCatalog.new()
	var wrong := Resource.new()  # Plain Resource, not a PassiveDef.

	# Act — the typed array will push 2 engine errors and silently reject.
	_quiet_typed_array_rejection(cat.entries, wrong)

	# Assert — exactly 2 engine errors pushed, and the element was NOT added.
	assert_engine_error_count(2,
		"Typed Array[PassiveDef] pushes exactly 2 engine errors on invalid append")
	assert_eq(cat.entries.size(), 0,
		"Typed Array[PassiveDef] rejects a non-PassiveDef element — size stays 0")


## Helper: attempt to append an incompatible element to a typed array.
func _quiet_typed_array_rejection(arr: Array[PassiveDef], wrong: Variant) -> void:
	arr.append(wrong)


# ---------------------------------------------------------------------------
# Class registration — parse-clean gate
# ---------------------------------------------------------------------------

## Both class_name scripts must parse cleanly and register with the engine so
## `is` checks work. A parse-broken class silently fails registration.
func test_passive_def_schema_class_registration_parses_cleanly() -> void:
	# Arrange / Act
	var pd := PassiveDef.new()
	var cat := PassiveCatalog.new()

	# Assert
	assert_true(pd is PassiveDef,     "PassiveDef.new() instantiates as PassiveDef")
	assert_true(cat is PassiveCatalog, "PassiveCatalog.new() instantiates as PassiveCatalog")
	assert_true(pd is Resource,       "PassiveDef is a Resource")
	assert_true(cat is Resource,      "PassiveCatalog is a Resource")
	assert_not_null(pd,  "PassiveDef.new() must not return null")
	assert_not_null(cat, "PassiveCatalog.new() must not return null")
