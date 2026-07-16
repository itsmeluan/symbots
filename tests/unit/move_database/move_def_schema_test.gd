## Move-DB Story 001 — MoveDef schema + enums + MoveCatalog (schema-shape tests).
##
## Covers QA test cases AC-1 and AC-2:
##   AC-1 (AC-MDB-18): MoveDef declares every MOVE-CONTRACT-1 field with the
##         correct type and default, and exposes NO heat_generation / ammo_cost
##         property (those stay on the Part). A fresh MoveDef.new() reads all
##         sentinel enums at 0, status_proc == {}, target_profile == [].
##   AC-2: Content enums use explicit integer values from 1; 0 is not a valid
##         member value in any enum.
##
## break_bias is the documented exception to the "enums default to 0" rule — its
## meaningful default is BALANCED (Rule 1 / Rule 4), asserted explicitly below.
##
## Framework: GUT · extends GutTest · Godot 4.7
extends GutTest


# ---------------------------------------------------------------------------
# AC-1: MoveDef field presence, types, and defaults
# ---------------------------------------------------------------------------

## All MOVE-CONTRACT-1 scalar fields must be present on a fresh MoveDef.
func test_move_def_schema_scalar_fields_present() -> void:
	# Arrange
	var md := MoveDef.new()

	# Assert — field presence for every named field.
	assert_true("id" in md,             "id field must exist")
	assert_true("display_name" in md,   "display_name field must exist")
	assert_true("behavior" in md,       "behavior field must exist")
	assert_true("power_tier" in md,     "power_tier field must exist")
	assert_true("damage_type" in md,    "damage_type field must exist")
	assert_true("element" in md,        "element field must exist")
	assert_true("energy_cost" in md,    "energy_cost field must exist")
	assert_true("status_proc" in md,    "status_proc field must exist")
	assert_true("targeting" in md,      "targeting field must exist")
	assert_true("break_bias" in md,     "break_bias field must exist")
	assert_true("scan_payload" in md,   "scan_payload field must exist")
	assert_true("vent_amount" in md,    "vent_amount field must exist")
	assert_true("target_profile" in md, "target_profile field must exist")


## AC-MDB-18: heat_generation and ammo_cost live on the Part, NEVER the move.
## MoveDef must not expose either property.
func test_move_def_schema_excludes_part_only_fields() -> void:
	# Arrange
	var md := MoveDef.new()

	# Assert — the two Part-owned fields must be absent from the move schema.
	assert_false("heat_generation" in md,
		"heat_generation must NOT exist on MoveDef (it lives on the Part) — AC-MDB-18")
	assert_false("ammo_cost" in md,
		"ammo_cost must NOT exist on MoveDef (it lives on the Part) — AC-MDB-18")


## Scalar field default types and values on a fresh instance.
func test_move_def_schema_scalar_defaults() -> void:
	# Arrange
	var md := MoveDef.new()

	# Assert — StringName / String / int defaults.
	assert_eq(md.id,           &"", "id defaults &\"\"")
	assert_eq(md.display_name, "",  "display_name defaults \"\"")
	assert_eq(md.energy_cost,  0,   "energy_cost defaults 0")
	assert_eq(md.vent_amount,  0,   "vent_amount defaults 0")


## Collection fields must exist, have the correct runtime type, and default empty
## (not null) — status_proc == {}, target_profile == [] (AC-1 edge case).
func test_move_def_schema_collection_defaults() -> void:
	# Arrange
	var md := MoveDef.new()

	# Assert — runtime container types.
	assert_eq(typeof(md.status_proc),    TYPE_DICTIONARY, "status_proc is Dictionary")
	assert_eq(typeof(md.target_profile), TYPE_ARRAY,      "target_profile is Array")

	# Assert — empty defaults (the null-equivalents).
	assert_eq(md.status_proc.size(),    0, "status_proc defaults empty {}")
	assert_eq(md.target_profile.size(), 0, "target_profile defaults empty []")


## A fresh MoveDef reads every SENTINEL enum field at 0 (reserved/invalid), so an
## unset .tres entry is caught by the ContentValidator. break_bias is the sole
## exception — its meaningful default is BALANCED (Rule 1 / Rule 4).
func test_move_def_schema_enum_field_defaults() -> void:
	# Arrange
	var md := MoveDef.new()

	# Assert — sentinel enums default to 0 (invalid, never a named member).
	assert_eq(int(md.behavior),     0, "behavior defaults to 0 (invalid sentinel)")
	assert_eq(int(md.power_tier),   0, "power_tier defaults to 0 (null for non-DAMAGE)")
	assert_eq(int(md.damage_type),  0, "damage_type defaults to 0 (null for non-DAMAGE)")
	assert_eq(int(md.element),      0, "element defaults to 0 (invalid sentinel)")
	assert_eq(int(md.targeting),    0, "targeting defaults to 0 (invalid sentinel)")
	assert_eq(int(md.scan_payload), 0, "scan_payload defaults to 0 (null for non-SCAN)")

	# Assert — break_bias is the documented exception: default BALANCED.
	assert_eq(md.break_bias, MoveDef.BreakBias.BALANCED,
		"break_bias defaults to BALANCED (Rule 1 / Rule 4), not the 0 sentinel")


## A fully-populated DAMAGE record carries all required fields with the right
## types — the well-formed-shape happy path (AC-MDB-18).
func test_move_def_schema_well_formed_damage_record() -> void:
	# Arrange — author a plausible Signature DAMAGE move.
	var md := MoveDef.new()
	md.id            = &"boltwell_arc_bolt"
	md.display_name  = "Arc Bolt"
	md.behavior      = MoveDef.Behavior.DAMAGE
	md.power_tier    = MoveDef.PowerTier.SIGNATURE
	md.damage_type   = PartDef.DamageType.ENERGY
	md.element       = PartDef.Element.VOLT
	md.energy_cost   = 34
	md.targeting     = MoveDef.Targeting.ENEMY
	md.break_bias    = MoveDef.BreakBias.BREAK_HEAVY

	# Assert — all 8 required fields read back as authored and typed.
	assert_eq(md.id,           &"boltwell_arc_bolt", "id round-trips")
	assert_eq(md.display_name, "Arc Bolt",           "display_name round-trips")
	assert_eq(md.behavior,     MoveDef.Behavior.DAMAGE,       "behavior round-trips")
	assert_eq(md.power_tier,   MoveDef.PowerTier.SIGNATURE,   "power_tier round-trips")
	assert_eq(md.damage_type,  PartDef.DamageType.ENERGY,     "damage_type round-trips")
	assert_eq(md.element,      PartDef.Element.VOLT,          "element round-trips")
	assert_eq(md.energy_cost,  34,                            "energy_cost round-trips")
	assert_eq(md.targeting,    MoveDef.Targeting.ENEMY,       "targeting round-trips")


# ---------------------------------------------------------------------------
# AC-2: Enum integer values — explicit from 1; 0 is reserved/invalid sentinel
# ---------------------------------------------------------------------------

## Behavior must have 5 members, values 1–5, and must not contain 0.
func test_move_def_enums_behavior_values_explicit_from_1() -> void:
	assert_eq(MoveDef.Behavior.DAMAGE,  1, "DAMAGE == 1")
	assert_eq(MoveDef.Behavior.STATUS,  2, "STATUS == 2")
	assert_eq(MoveDef.Behavior.REPAIR,  3, "REPAIR == 3")
	assert_eq(MoveDef.Behavior.SCAN,    4, "SCAN == 4")
	assert_eq(MoveDef.Behavior.UTILITY, 5, "UTILITY == 5")
	assert_false(0 in MoveDef.Behavior.values(),
		"Behavior: 0 is reserved/invalid and must not appear in the value set")


## PowerTier must have 5 members (BASIC..SIGNATURE), values 1–5, strictly ordered,
## and must not contain 0. BASIC (the Basic Attack tier) is included per TR-mdb-002.
func test_move_def_enums_power_tier_values_explicit_from_1() -> void:
	assert_eq(MoveDef.PowerTier.BASIC,     1, "BASIC == 1")
	assert_eq(MoveDef.PowerTier.LIGHT,     2, "LIGHT == 2")
	assert_eq(MoveDef.PowerTier.STANDARD,  3, "STANDARD == 3")
	assert_eq(MoveDef.PowerTier.HEAVY,     4, "HEAVY == 4")
	assert_eq(MoveDef.PowerTier.SIGNATURE, 5, "SIGNATURE == 5")
	# Strict ordering underpins the MOVE-F1 tier taxonomy (Tuning-Knob warning 3).
	assert_true(
		MoveDef.PowerTier.BASIC < MoveDef.PowerTier.LIGHT
		and MoveDef.PowerTier.LIGHT < MoveDef.PowerTier.STANDARD
		and MoveDef.PowerTier.STANDARD < MoveDef.PowerTier.HEAVY
		and MoveDef.PowerTier.HEAVY < MoveDef.PowerTier.SIGNATURE,
		"PowerTier values are strictly ordered BASIC < LIGHT < STANDARD < HEAVY < SIGNATURE")
	assert_false(0 in MoveDef.PowerTier.values(),
		"PowerTier: 0 is reserved/invalid and must not appear in the value set")


## Targeting must have 2 members, values 1–2, and must not contain 0.
func test_move_def_enums_targeting_values_explicit_from_1() -> void:
	assert_eq(MoveDef.Targeting.ENEMY, 1, "ENEMY == 1")
	assert_eq(MoveDef.Targeting.SELF,  2, "SELF == 2")
	assert_false(0 in MoveDef.Targeting.values(),
		"Targeting: 0 is reserved/invalid and must not appear in the value set")


## BreakBias must have 3 members, values 1–3, and must not contain 0.
func test_move_def_enums_break_bias_values_explicit_from_1() -> void:
	assert_eq(MoveDef.BreakBias.STRUCTURE_HEAVY, 1, "STRUCTURE_HEAVY == 1")
	assert_eq(MoveDef.BreakBias.BALANCED,        2, "BALANCED == 2")
	assert_eq(MoveDef.BreakBias.BREAK_HEAVY,     3, "BREAK_HEAVY == 3")
	assert_false(0 in MoveDef.BreakBias.values(),
		"BreakBias: 0 is reserved/invalid and must not appear in the value set")


## ScanPayload must start at 1; 0 must not appear (BREAK_REGIONS is the only MVP member).
func test_move_def_enums_scan_payload_values_explicit_from_1() -> void:
	assert_eq(MoveDef.ScanPayload.BREAK_REGIONS, 1, "BREAK_REGIONS == 1")
	assert_false(0 in MoveDef.ScanPayload.values(),
		"ScanPayload: 0 is reserved/invalid and must not appear in the value set")


# ---------------------------------------------------------------------------
# MoveCatalog — typed Array[MoveDef]
# ---------------------------------------------------------------------------

## Fresh MoveCatalog must have an empty Array[MoveDef] for entries.
func test_move_catalog_schema_entries_empty_by_default() -> void:
	# Arrange / Act
	var cat := MoveCatalog.new()

	# Assert
	assert_eq(cat.entries.size(), 0, "entries defaults to empty array")
	assert_eq(typeof(cat.entries), TYPE_ARRAY, "entries is an Array")


## A valid MoveDef element appends successfully.
func test_move_catalog_schema_accepts_valid_move_def() -> void:
	# Arrange
	var cat := MoveCatalog.new()
	var md := MoveDef.new()

	# Act
	cat.entries.append(md)

	# Assert
	assert_eq(cat.entries.size(), 1, "MoveDef appends successfully into entries")
	assert_true(cat.entries[0] is MoveDef, "Appended element is a MoveDef")


## Appending a non-MoveDef to a typed Array[MoveDef] is rejected at runtime.
##
## Godot 4.7 typed-array enforcement: calling append() with an incompatible
## element pushes TWO engine errors and does NOT add the element.
## assert_engine_error_count(2) tells GUT these errors are expected, preventing
## them from being reported as "Unexpected Errors" and failing the test.
func test_move_catalog_schema_rejects_non_move_def_element() -> void:
	# Arrange
	var cat := MoveCatalog.new()
	var wrong := Resource.new()  # Plain Resource, not a MoveDef.

	# Act — the typed array will push 2 engine errors and silently reject.
	_quiet_typed_array_rejection(cat.entries, wrong)

	# Assert — exactly 2 engine errors pushed, and the element was NOT added.
	assert_engine_error_count(2,
		"Typed Array[MoveDef] pushes exactly 2 engine errors on invalid append")
	assert_eq(cat.entries.size(), 0,
		"Typed Array[MoveDef] rejects a non-MoveDef element — size stays 0")


## Helper: attempt to append an incompatible element to a typed array.
## Isolated so the engine-pushed errors are scoped to the call site.
func _quiet_typed_array_rejection(arr: Array[MoveDef], wrong: Variant) -> void:
	arr.append(wrong)


# ---------------------------------------------------------------------------
# Class registration — parse-clean gate
# ---------------------------------------------------------------------------

## Both class_name scripts must parse cleanly and register with the engine so
## that `is` checks work. A parse-broken class silently fails registration,
## making MoveDef.new() return null or error.
func test_move_def_schema_class_registration_parses_cleanly() -> void:
	# Arrange / Act
	var md := MoveDef.new()
	var cat := MoveCatalog.new()

	# Assert
	assert_true(md is MoveDef,      "MoveDef.new() instantiates as MoveDef")
	assert_true(cat is MoveCatalog, "MoveCatalog.new() instantiates as MoveCatalog")
	assert_true(md is Resource,     "MoveDef is a Resource")
	assert_true(cat is Resource,    "MoveCatalog is a Resource")
	assert_not_null(md,  "MoveDef.new() must not return null")
	assert_not_null(cat, "MoveCatalog.new() must not return null")
