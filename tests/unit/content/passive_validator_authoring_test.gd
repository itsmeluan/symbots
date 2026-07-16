## Passive-DB Story 005 — ContentValidator Passive authoring rules.
##
## Covers the Story 005 ACs (GDD Rule 3a params + Formulas STRUCTURAL non-negative
## + Rule 6 Core doctrine + AC-PDB-12/14/16, TR-pdb-006/007/008). Every rule pairs
## a clean fixture with a corrupted one. The AC-PDB-14 Core-uniqueness check must be
## inert on an all-rider MVP catalog (zero Core passives). Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/passive_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

func _valid_rider(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Test %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.ON_HIT
	pd.behavior_class   = PassiveDef.BehaviorClass.STATUS_RIDER
	pd.scope            = PassiveDef.Scope.ANY_DAMAGE
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER
	pd.passive_class    = PassiveDef.PassiveClass.STATUS_RIDER
	pd.behavior_params  = {"status_id": &"shock", "duration": 1}
	return pd


func _valid_aura(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Aura %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.PERSISTENT
	pd.behavior_class   = PassiveDef.BehaviorClass.STAT_AURA
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE
	pd.passive_class    = PassiveDef.PassiveClass.CORE_TRAIT
	pd.behavior_params  = {"stat": &"processing", "delta": 5}
	return pd


func _valid_resource(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Vent %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.ON_OVERHEAT
	pd.behavior_class   = PassiveDef.BehaviorClass.RESOURCE_EFFECT
	pd.stacking_policy  = PassiveDef.StackingPolicy.STACKABLE
	pd.passive_class    = PassiveDef.PassiveClass.CORE_TRAIT
	pd.behavior_params  = {"resource": &"heat", "amount": -10}
	return pd


func _valid_structural(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Bulwark %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.ON_BATTLE_START
	pd.behavior_class   = PassiveDef.BehaviorClass.STRUCTURAL_EFFECT
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE
	pd.passive_class    = PassiveDef.PassiveClass.CORE_TRAIT
	pd.behavior_params  = {"target": &"current_structure", "amount": 20}
	return pd


func _run(passives: Array[PassiveDef]) -> Dictionary:
	var catalog := PassiveCatalog.new()
	catalog.entries = passives
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty but present — the validator always checks the Part catalog
	catalogs.passives = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _one(passive: PassiveDef) -> Dictionary:
	var passives: Array[PassiveDef] = [passive]
	return _run(passives)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


func _count(code: StringName) -> int:
	var n := 0
	for e in _spy.errors:
		if e["code"] == code:
			n += 1
	return n


func _detail(code: StringName) -> Dictionary:
	for e in _spy.errors:
		if e["code"] == code:
			return e["detail"]
	return {}


func _fields(code: StringName) -> Dictionary:
	var f := {}
	for e in _spy.errors:
		if e["code"] == code:
			f[e["detail"]["field"]] = true
	return f


# ---------------------------------------------------------------------------
# AC-1 (AC-PDB-16 params / TR-pdb-006): behavior_params matches behavior_class
# ---------------------------------------------------------------------------

## A well-formed payload for every class passes the params check.
func test_well_formed_params_pass_for_every_class() -> void:
	_run([
		_valid_rider(&"r"), _valid_aura(&"a"),
		_valid_resource(&"res"), _valid_structural(&"s"),
	] as Array[PassiveDef])
	assert_false(_logged(&"content_passive_params_mismatch"),
		"well-formed behavior_params for each class produce no mismatch")


func test_stat_aura_missing_delta_is_params_mismatch() -> void:
	# Arrange — STAT_AURA requires {stat, delta}; drop delta.
	var bad := _valid_aura(&"bad_aura")
	bad.behavior_params = {"stat": &"processing"}

	# Act
	_one(bad)

	# Assert — one mismatch naming the missing field.
	assert_eq(_count(&"content_passive_params_mismatch"), 1, "one params mismatch")
	var d := _detail(&"content_passive_params_mismatch")
	assert_eq(d["id"], &"bad_aura", "names the id")
	assert_eq(d["field"], "delta", "names the missing 'delta' key")


func test_resource_effect_extra_key_is_params_mismatch() -> void:
	# Arrange — RESOURCE_EFFECT wants exactly {resource, amount}; add an unknown key.
	var bad := _valid_resource(&"bad_res")
	bad.behavior_params = {"resource": &"heat", "amount": -10, "bogus": 1}

	# Act
	_one(bad)

	# Assert — the extra key is flagged.
	assert_true(_logged(&"content_passive_params_mismatch"), "unknown extra key flagged")
	assert_true(_fields(&"content_passive_params_mismatch").has("bogus"), "'bogus' named as offending field")


# ---------------------------------------------------------------------------
# AC-2 (AC-PDB-16 structural / TR-pdb-007): negative STRUCTURAL amount rejected
# ---------------------------------------------------------------------------

func test_negative_current_structure_amount_is_rejected() -> void:
	# Arrange — a negative amount on CURRENT_STRUCTURE (EC-PDB-08 authoring error).
	var bad := _valid_structural(&"bad_struct")
	bad.behavior_params = {"target": &"current_structure", "amount": -20}

	# Act
	_one(bad)

	# Assert — one negative-structural error naming id + target.
	assert_eq(_count(&"content_passive_negative_structural"), 1, "one negative-structural error")
	var d := _detail(&"content_passive_negative_structural")
	assert_eq(d["id"], &"bad_struct", "names the id")
	assert_eq(d["target"], &"current_structure", "names the offending target")


func test_negative_max_structure_amount_is_rejected() -> void:
	# Arrange — negative on MAX_STRUCTURE is also illegal (both targets).
	var bad := _valid_structural(&"bad_max")
	bad.behavior_params = {"target": &"max_structure", "amount": -5}

	# Act
	_one(bad)

	# Assert
	assert_eq(_count(&"content_passive_negative_structural"), 1, "negative MAX_STRUCTURE rejected")
	assert_eq(_detail(&"content_passive_negative_structural")["target"], &"max_structure", "names max_structure")


func test_zero_and_positive_structural_amounts_pass() -> void:
	# Arrange — amount 0 and positive are both legal.
	var zero := _valid_structural(&"zero")
	zero.behavior_params = {"target": &"current_structure", "amount": 0}
	var pos := _valid_structural(&"pos")
	pos.behavior_params = {"target": &"max_structure", "amount": 15}

	# Act
	_run([zero, pos] as Array[PassiveDef])

	# Assert
	assert_false(_logged(&"content_passive_negative_structural"),
		"amount 0 and positive amounts produce no negative-structural error")


# ---------------------------------------------------------------------------
# AC-3 (AC-PDB-12 / TR-pdb-008): Core trigger whitelist
# ---------------------------------------------------------------------------

func test_core_trait_on_hit_is_illegal_core_trigger() -> void:
	# Arrange — a CORE_TRAIT passive using ON_HIT (violates Rule 6 constraint 2).
	# Use a STATUS_RIDER behavior so the pairing itself is legal — isolating the
	# Core-trigger rule from the legality-matrix rule.
	var bad := _valid_rider(&"bad_core")
	bad.passive_class = PassiveDef.PassiveClass.CORE_TRAIT

	# Act
	_one(bad)

	# Assert — one Core-trigger error naming the id.
	assert_eq(_count(&"content_core_illegal_trigger"), 1, "one Core illegal-trigger error")
	var d := _detail(&"content_core_illegal_trigger")
	assert_eq(d["id"], &"bad_core", "names the id")
	assert_eq(d["trigger"], PassiveDef.TriggerCategory.ON_HIT, "carries the illegal trigger")


func test_core_trait_whitelisted_triggers_pass() -> void:
	# Arrange — CORE_TRAIT with each whitelisted trigger (via legal pairings).
	_run([
		_valid_aura(&"core_persistent"),        # PERSISTENT
		_valid_resource(&"core_overheat"),      # ON_OVERHEAT
		_valid_structural(&"core_battlestart"), # ON_BATTLE_START
	] as Array[PassiveDef])

	# Assert
	assert_false(_logged(&"content_core_illegal_trigger"),
		"CORE_TRAIT + {ON_BATTLE_START, ON_OVERHEAT, PERSISTENT} all pass")


## A non-Core (STATUS_RIDER passive_class) passive using ON_HIT must NOT be flagged
## by the Core-trigger rule — ON_HIT is legal for a rider.
func test_non_core_on_hit_is_not_flagged_by_core_rule() -> void:
	_one(_valid_rider(&"plain_rider"))
	assert_false(_logged(&"content_core_illegal_trigger"),
		"a non-Core ON_HIT rider is not a Core-trigger violation")


# ---------------------------------------------------------------------------
# AC-4 (AC-PDB-14): Core combo duplication
# ---------------------------------------------------------------------------

func test_duplicate_core_combo_is_flagged() -> void:
	# Arrange — two CORE_TRAIT passives sharing PERSISTENT × STAT_AURA.
	var a := _valid_aura(&"core_a")
	var b := _valid_aura(&"core_b")

	# Act
	_run([a, b] as Array[PassiveDef])

	# Assert — one duplicate-combo error naming both ids.
	assert_eq(_count(&"content_core_duplicate_combo"), 1, "one Core duplicate-combo error")
	var d := _detail(&"content_core_duplicate_combo")
	assert_eq(d["id_a"], &"core_a", "names the first id")
	assert_eq(d["id_b"], &"core_b", "names the second id")
	assert_eq(d["trigger"], PassiveDef.TriggerCategory.PERSISTENT, "carries the shared trigger")
	assert_eq(d["behavior"], PassiveDef.BehaviorClass.STAT_AURA, "carries the shared behavior")


## Distinct Core combos do not collide.
func test_distinct_core_combos_produce_no_duplicate() -> void:
	# Arrange — three CORE_TRAIT passives, each a different (trigger, behavior) combo.
	_run([
		_valid_aura(&"core_aura"),          # PERSISTENT × STAT_AURA
		_valid_resource(&"core_resource"),  # ON_OVERHEAT × RESOURCE_EFFECT
		_valid_structural(&"core_struct"),  # ON_BATTLE_START × STRUCTURAL_EFFECT
	] as Array[PassiveDef])

	# Assert
	assert_false(_logged(&"content_core_duplicate_combo"),
		"three distinct Core combos produce no duplicate error")


## AC-4 edge case: an all-rider MVP catalog (zero CORE_TRAIT entries) produces NO
## Core errors of any kind — the uniqueness check is inert until OQ-PDB-1 lands.
func test_all_rider_catalog_produces_no_core_errors() -> void:
	_run([
		_valid_rider(&"volt_shock_on_hit"),
		_valid_rider(&"thermal_burn_on_weapon"),
		_valid_rider(&"kinetic_stagger_on_hit"),
	] as Array[PassiveDef])

	assert_false(_logged(&"content_core_duplicate_combo"), "no duplicate-combo on rider-only catalog")
	assert_false(_logged(&"content_core_illegal_trigger"), "no Core-trigger error on rider-only catalog")
