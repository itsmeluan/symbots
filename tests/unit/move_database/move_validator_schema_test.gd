## Move-DB Story 004 — ContentValidator Move schema family.
##
## Covers GDD AC-MDB-18 (required fields), the DAMAGE→power_tier invariant
## (EC-MDB-04 authoring side), and AC-MDB-21 (REPAIR/UTILITY → SELF targeting).
## Per ADR-0003 every check pairs a CLEAN fixture (passes) with a deliberately
## CORRUPTED one (must fail). Diagnostics are asserted on the injected spy
## [LogSink] (never `push_error`). The Move family runs only when a MoveCatalog
## is mounted on ContentCatalogs — a null/empty part catalog is provided so the
## Move checks are exercised in isolation. Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/move_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## A fully-valid DAMAGE move — the baseline every corruption mutates from.
## `energy_cost` 15 sits in the STANDARD band (12–18) so the Story 005 family
## passes it too; no innate `status_proc` (DAMAGE riders come via passives).
func _valid_damage(id: StringName) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Test %s" % id
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.ENERGY
	m.element = PartDef.Element.VOLT
	m.energy_cost = 15
	m.targeting = MoveDef.Targeting.ENEMY
	return m


## A valid STATUS move (targets an ENEMY). Carries the element-matched rider
## (VOLT → shock) the Story 005 family requires of every STATUS move.
func _valid_status(id: StringName) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Test %s" % id
	m.behavior = MoveDef.Behavior.STATUS
	m.element = PartDef.Element.VOLT
	m.status_proc = {"status_id": &"shock", "duration": 2}
	m.targeting = MoveDef.Targeting.ENEMY
	return m


## A valid REPAIR move — heals the caster, so it targets SELF. `energy_cost` 11
## clears the Story 005 anti-stall brake (must exceed BASE_ENERGY_REGEN 10).
func _valid_repair(id: StringName) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Test %s" % id
	m.behavior = MoveDef.Behavior.REPAIR
	m.energy_cost = 11
	m.targeting = MoveDef.Targeting.SELF
	return m


## A valid UTILITY (Vent) move — cools the caster, so it targets SELF.
func _valid_utility(id: StringName) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Test %s" % id
	m.behavior = MoveDef.Behavior.UTILITY
	m.targeting = MoveDef.Targeting.SELF
	m.vent_amount = 20
	return m


## Run the validator over the given moves; stash the spy for diagnostic asserts.
## An empty part catalog is mounted so the Part families pass cleanly and only the
## Move family produces diagnostics.
func _run(moves: Array[MoveDef]) -> Dictionary:
	var move_catalog := MoveCatalog.new()
	move_catalog.entries = moves
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty → Part families clean
	catalogs.moves = move_catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _one(move: MoveDef) -> Dictionary:
	var moves: Array[MoveDef] = [move]
	return _run(moves)


## True if the spy recorded an error with the given code.
func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# Baseline: one well-formed move per behavior class → zero errors/warnings
# ---------------------------------------------------------------------------

func test_move_clean_catalog_all_behaviors_no_errors() -> void:
	var moves: Array[MoveDef] = [
		_valid_damage(&"mv_strike"),
		_valid_status(&"mv_corrode"),
		_valid_repair(&"mv_mend"),
		_valid_utility(&"mv_vent"),
	]
	var result := _run(moves)
	assert_true(result["ok"], "clean multi-behavior move catalog validates ok")
	assert_eq(_spy.errors.size(), 0, "no errors on a clean move catalog")
	assert_eq(_spy.warns.size(), 0, "no warnings on a clean move catalog")


func test_move_family_skipped_when_no_catalog_mounted() -> void:
	# A Part-only aggregate (moves == null) must not touch the Move family.
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()
	_spy = SpyLogSink.new()
	var result := ContentValidator.new().validate(catalogs, _spy)
	assert_true(result["ok"], "Part-only aggregate is clean")
	assert_eq(_spy.total(), 0, "moves==null → Move family never runs")


# ---------------------------------------------------------------------------
# AC-1 (AC-MDB-18): required fields — missing field errors naming the id
# ---------------------------------------------------------------------------

func test_move_missing_display_name_errors_naming_id() -> void:
	var m := _valid_damage(&"mv_nameless")
	m.display_name = ""
	var result := _one(m)
	assert_false(result["ok"], "a move missing display_name fails")
	assert_true(_logged(&"content_move_missing_field"), "logs content_move_missing_field")
	# The finding names the offending move id (AC requirement).
	var found_field := &""
	for e in _spy.errors:
		if e["code"] == &"content_move_missing_field" and e["detail"]["field"] == &"display_name":
			assert_eq(e["detail"]["id"], &"mv_nameless", "finding names the move id")
			found_field = e["detail"]["field"]
	assert_eq(found_field, &"display_name", "the missing field is reported as display_name")


func test_move_missing_behavior_and_targeting_each_flagged() -> void:
	# behavior + targeting both left at the 0 sentinel → two required-field errors.
	var m := MoveDef.new()
	m.id = &"mv_blank"
	m.display_name = "Blank"
	# behavior = 0, targeting = 0 (defaults)
	var result := _one(m)
	assert_false(result["ok"], "missing behavior & targeting fails")
	var missing_fields := {}
	for e in _spy.errors:
		if e["code"] == &"content_move_missing_field":
			missing_fields[e["detail"]["field"]] = true
	assert_true(missing_fields.has(&"behavior"), "behavior flagged missing")
	assert_true(missing_fields.has(&"targeting"), "targeting flagged missing")


func test_move_damage_missing_damage_type_and_element_flagged() -> void:
	# A DAMAGE move requires damage_type + element; leaving them at 0 flags both.
	var m := _valid_damage(&"mv_partial")
	m.damage_type = 0
	m.element = 0
	_one(m)
	var missing := {}
	for e in _spy.errors:
		if e["code"] == &"content_move_missing_field":
			missing[e["detail"]["field"]] = true
	assert_true(missing.has(&"damage_type"), "DAMAGE move flags missing damage_type")
	assert_true(missing.has(&"element"), "DAMAGE move flags missing element")


func test_move_zero_energy_cost_not_flagged_as_missing_field() -> void:
	# energy_cost 0 must never be reported as a MISSING required field (the Story 004
	# concern). At BASIC tier (the free Basic Attack) it is also fully in-band, so the
	# whole move is clean — proving 0 is a legitimate cost, not a schema gap.
	var m := _valid_damage(&"mv_free")
	m.power_tier = MoveDef.PowerTier.BASIC  # the exempt Basic Attack tier
	m.energy_cost = 0
	var result := _one(m)
	assert_true(result["ok"], "a BASIC-tier free move is clean; energy_cost 0 is not a missing field")
	assert_false(_logged(&"content_move_missing_field"), "energy_cost 0 is never a missing-field error")


func test_move_non_damage_needs_no_damage_type_or_element() -> void:
	# STATUS carries no damage_type/element (both 0) and must still validate — the
	# damage_type/element requirement is DAMAGE-only.
	var result := _one(_valid_status(&"mv_status_clean"))
	assert_true(result["ok"], "a non-DAMAGE move needs no damage_type/element")


# ---------------------------------------------------------------------------
# AC-2 (EC-MDB-04): DAMAGE move must declare a real power_tier
# ---------------------------------------------------------------------------

func test_damage_move_missing_power_tier_errors() -> void:
	var m := _valid_damage(&"mv_untiered")
	m.power_tier = 0  # the reserved sentinel
	var result := _one(m)
	assert_false(result["ok"], "a DAMAGE move with power_tier=0 fails")
	assert_true(_logged(&"content_damage_move_missing_power_tier"), "logs the dedicated code")


func test_non_damage_move_null_power_tier_is_clean() -> void:
	# A STATUS move never has a power_tier — power_tier=0 there is legitimate.
	var m := _valid_status(&"mv_status_untiered")
	assert_eq(int(m.power_tier), 0, "sanity: STATUS fixture leaves power_tier unset")
	var result := _one(m)
	assert_true(result["ok"], "non-DAMAGE move with null power_tier is clean")
	assert_false(_logged(&"content_damage_move_missing_power_tier"),
		"the power_tier check never fires on a non-DAMAGE move")


# ---------------------------------------------------------------------------
# AC-3 (AC-MDB-21): REPAIR / UTILITY must target SELF
# ---------------------------------------------------------------------------

func test_repair_targeting_enemy_errors() -> void:
	var m := _valid_repair(&"mv_bad_repair")
	m.targeting = MoveDef.Targeting.ENEMY
	var result := _one(m)
	assert_false(result["ok"], "a REPAIR move targeting ENEMY fails")
	assert_true(_logged(&"content_move_bad_targeting"), "logs content_move_bad_targeting")


func test_utility_vent_targeting_enemy_errors() -> void:
	var m := _valid_utility(&"mv_bad_vent")
	m.targeting = MoveDef.Targeting.ENEMY
	var result := _one(m)
	assert_false(result["ok"], "a UTILITY(Vent) move targeting ENEMY fails")
	assert_true(_logged(&"content_move_bad_targeting"), "logs content_move_bad_targeting")


func test_repair_and_utility_self_targeting_clean() -> void:
	# The same behaviours with SELF targeting are clean — proving the check
	# discriminates on the targeting value, not the behaviour alone.
	var repair_ok := _one(_valid_repair(&"mv_good_repair"))
	assert_true(repair_ok["ok"], "REPAIR targeting SELF is clean")
	assert_false(_logged(&"content_move_bad_targeting"), "no bad-targeting error on SELF REPAIR")
	var utility_ok := _one(_valid_utility(&"mv_good_vent"))
	assert_true(utility_ok["ok"], "UTILITY targeting SELF is clean")


func test_damage_move_targeting_enemy_is_allowed() -> void:
	# DAMAGE is NOT a self-target behaviour — targeting ENEMY must pass (proves the
	# SELF constraint is scoped to REPAIR/UTILITY only).
	var result := _one(_valid_damage(&"mv_enemy_ok"))
	assert_true(result["ok"], "a DAMAGE move targeting ENEMY is allowed")


# ---------------------------------------------------------------------------
# Null-entry contract: a null MoveDef in the catalog is fatal
# ---------------------------------------------------------------------------

func test_null_move_entry_is_fatal() -> void:
	var moves: Array[MoveDef] = [null]
	var result := _run(moves)
	assert_false(result["ok"], "a null move entry fails validation")
	assert_true(_logged(&"content_null_entry"), "logs content_null_entry for a null move")
