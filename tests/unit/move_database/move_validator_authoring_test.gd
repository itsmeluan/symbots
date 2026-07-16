## Move-DB Story 005 — ContentValidator Move authoring-rule family.
##
## Covers the cross-field rules layered onto the Story 004 schema dispatch:
##   AC-1 (AC-MDB-14): DAMAGE energy_cost must fall in its PowerTier band.
##   AC-2 (AC-MDB-15): REPAIR energy_cost must exceed BASE_ENERGY_REGEN (anti-stall).
##   AC-3 (AC-MDB-16): STATUS status_id must match its element (VOLT→shock, …).
##   AC-4 (TR-mdb-009): DAMAGE may carry no innate status_proc; STATUS requires one.
##   AC-5 (AC-MDB-17): Core SKILL_UNLOCK upgrade is still rejected Part-DB-side
##         (regression — coverage shared with the Part validator, no new Move code).
## Per ADR-0003 every rule pairs a CLEAN fixture with a CORRUPTED one. Framework:
## GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/move_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## In-band DAMAGE move at a given tier/cost — the baseline for the band tests.
func _damage(id: StringName, tier: MoveDef.PowerTier, energy_cost: int) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Test %s" % id
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = tier
	m.damage_type = PartDef.DamageType.ENERGY
	m.element = PartDef.Element.VOLT
	m.energy_cost = energy_cost
	m.targeting = MoveDef.Targeting.ENEMY
	return m


## REPAIR move at a given cost (targets SELF, per AC-MDB-21).
func _repair(id: StringName, energy_cost: int) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Test %s" % id
	m.behavior = MoveDef.Behavior.REPAIR
	m.energy_cost = energy_cost
	m.targeting = MoveDef.Targeting.SELF
	return m


## STATUS move with an explicit element + status_id rider.
func _status(id: StringName, element: PartDef.Element, status_id: StringName) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Test %s" % id
	m.behavior = MoveDef.Behavior.STATUS
	m.element = element
	if status_id != &"":
		m.status_proc = {"status_id": status_id, "duration": 2}
	m.targeting = MoveDef.Targeting.ENEMY
	return m


func _run_moves(moves: Array[MoveDef]) -> Dictionary:
	var move_catalog := MoveCatalog.new()
	move_catalog.entries = moves
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty → Part families clean
	catalogs.moves = move_catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _one(move: MoveDef) -> Dictionary:
	var moves: Array[MoveDef] = [move]
	return _run_moves(moves)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# AC-1 (AC-MDB-14): DAMAGE energy_cost band per power tier
# ---------------------------------------------------------------------------

func test_signature_energy_below_band_errors() -> void:
	# SIGNATURE band is 32–40; energy_cost 10 is far below → error.
	var result := _one(_damage(&"mv_cheap_sig", MoveDef.PowerTier.SIGNATURE, 10))
	assert_false(result["ok"], "a SIGNATURE move at cost 10 fails the band")
	assert_true(_logged(&"content_move_energy_band"), "logs content_move_energy_band")


func test_energy_band_boundaries_pass() -> void:
	# The inclusive band edges must pass: SIGNATURE 32 and 40.
	assert_true(_one(_damage(&"mv_sig_lo", MoveDef.PowerTier.SIGNATURE, 32))["ok"], "cost 32 is in-band (lower edge)")
	assert_true(_one(_damage(&"mv_sig_hi", MoveDef.PowerTier.SIGNATURE, 40))["ok"], "cost 40 is in-band (upper edge)")


func test_energy_band_just_outside_edges_fail() -> void:
	# One below and one above the SIGNATURE band must each fail (31 and 41).
	assert_false(_one(_damage(&"mv_sig_31", MoveDef.PowerTier.SIGNATURE, 31))["ok"], "cost 31 is below band")
	assert_false(_one(_damage(&"mv_sig_41", MoveDef.PowerTier.SIGNATURE, 41))["ok"], "cost 41 is above band")


func test_all_tier_bands_midpoints_pass() -> void:
	# A representative in-band cost for every keyed tier passes cleanly.
	assert_true(_one(_damage(&"mv_light", MoveDef.PowerTier.LIGHT, 6))["ok"], "LIGHT 6 in band 5–8")
	assert_true(_one(_damage(&"mv_std", MoveDef.PowerTier.STANDARD, 15))["ok"], "STANDARD 15 in band 12–18")
	assert_true(_one(_damage(&"mv_heavy", MoveDef.PowerTier.HEAVY, 26))["ok"], "HEAVY 26 in band 22–30")
	assert_true(_one(_damage(&"mv_sig", MoveDef.PowerTier.SIGNATURE, 36))["ok"], "SIGNATURE 36 in band 32–40")


func test_basic_tier_free_move_is_exempt_from_band() -> void:
	# BASIC (the built-in free Basic Attack) is exempt: cost 0 must pass.
	var result := _one(_damage(&"mv_basic", MoveDef.PowerTier.BASIC, 0))
	assert_true(result["ok"], "BASIC-tier cost 0 is exempt from the energy band")
	assert_false(_logged(&"content_move_energy_band"), "band check never fires on BASIC")


# ---------------------------------------------------------------------------
# AC-2 (AC-MDB-15): REPAIR anti-stall brake
# ---------------------------------------------------------------------------

func test_repair_at_regen_value_errors() -> void:
	# energy_cost exactly == BASE_ENERGY_REGEN (10) is free healing → error.
	var result := _one(_repair(&"mv_free_heal", 10))
	assert_false(result["ok"], "REPAIR at cost 10 (== regen) fails the brake")
	assert_true(_logged(&"content_move_repair_brake"), "logs content_move_repair_brake")


func test_repair_one_above_regen_is_clean() -> void:
	# +1 over the regen clears the brake.
	var result := _one(_repair(&"mv_braked_heal", 11))
	assert_true(result["ok"], "REPAIR at cost 11 clears the brake")
	assert_false(_logged(&"content_move_repair_brake"), "no brake error at cost 11")


# ---------------------------------------------------------------------------
# AC-3 (AC-MDB-16): STATUS status_id ↔ element
# ---------------------------------------------------------------------------

func test_status_element_mismatch_errors() -> void:
	# A VOLT STATUS move carrying `burn` (THERMAL's status) mismatches → error.
	var result := _one(_status(&"mv_bad_status", PartDef.Element.VOLT, &"burn"))
	assert_false(result["ok"], "VOLT move with a burn rider mismatches")
	assert_true(_logged(&"content_move_status_element_mismatch"), "logs the mismatch code")


func test_each_element_status_pair_is_clean() -> void:
	# The three canonical pairs must all validate: VOLT→shock, THERMAL→burn, KINETIC→stagger.
	assert_true(_one(_status(&"mv_volt", PartDef.Element.VOLT, &"shock"))["ok"], "VOLT→shock clean")
	assert_true(_one(_status(&"mv_therm", PartDef.Element.THERMAL, &"burn"))["ok"], "THERMAL→burn clean")
	assert_true(_one(_status(&"mv_kin", PartDef.Element.KINETIC, &"stagger"))["ok"], "KINETIC→stagger clean")


# ---------------------------------------------------------------------------
# AC-4 (TR-mdb-009): innate rider presence rules
# ---------------------------------------------------------------------------

func test_damage_move_with_innate_status_proc_errors() -> void:
	# DAMAGE riders come only via passives — an innate status_proc is illegal.
	var m := _damage(&"mv_riderful", MoveDef.PowerTier.STANDARD, 15)
	m.status_proc = {"status_id": &"shock", "duration": 2}
	var result := _one(m)
	assert_false(result["ok"], "a DAMAGE move with an innate status_proc fails")
	assert_true(_logged(&"content_move_innate_rider"), "logs content_move_innate_rider")


func test_status_move_without_rider_errors() -> void:
	# A STATUS move REQUIRES a rider — an empty status_proc can't carry the element's
	# status, so it surfaces as the element-mismatch code (status_id &"" ≠ shock).
	var result := _one(_status(&"mv_riderless", PartDef.Element.VOLT, &""))
	assert_false(result["ok"], "a STATUS move with no status_proc fails")
	assert_true(_logged(&"content_move_status_element_mismatch"),
		"a missing rider surfaces as an element mismatch (empty status_id)")


# ---------------------------------------------------------------------------
# AC-5 (AC-MDB-17): Core SKILL_UNLOCK still rejected (Part-DB shared coverage)
# ---------------------------------------------------------------------------

func test_core_skill_unlock_upgrade_still_forbidden() -> void:
	# Regression: the Part validator already forbids injecting an active skill onto a
	# support (CORE) slot via a SKILL_UNLOCK upgrade_effect. Confirm from the Move-DB
	# angle that the shared check still fires — no new Move-side code implements this.
	var p := PartDef.new()
	p.id = &"core_sneaky"
	p.display_name = "Sneaky Core"
	p.slot_type = PartDef.SlotType.CORE
	p.rarity = PartDef.Rarity.COMMON
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.sprite_id = &"spr_core"
	var effects: Array[Dictionary] = [{"effect_type": &"SKILL_UNLOCK", "tier": 1}]
	p.upgrade_effects = effects

	var catalog := PartCatalog.new()
	var parts: Array[PartDef] = [p]
	catalog.entries = parts
	var catalogs := ContentCatalogs.new()
	catalogs.parts = catalog
	_spy = SpyLogSink.new()
	var result := ContentValidator.new().validate(catalogs, _spy)

	assert_false(result["ok"], "a Core part with a SKILL_UNLOCK upgrade fails")
	assert_true(_logged(&"content_upgrade_skill_unlock_forbidden"),
		"the shared Part-DB check still rejects Core skill-unlock (AC-MDB-17)")
