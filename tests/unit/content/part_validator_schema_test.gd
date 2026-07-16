## Part-DB Story 007 — ContentValidator schema & enum-integrity family.
##
## Covers GDD AC-01/02/03/17/18/20/21/22/24. Per ADR-0003's validation criteria
## every family pairs a CLEAN fixture (passes) with a deliberately-CORRUPTED one
## (must fail) — proving the validator discriminates. Diagnostics are asserted on
## the injected spy [LogSink] (never `push_error`). Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## A fully-valid Common HEAD part — the baseline every corruption mutates from.
func _valid_part(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Test %s" % id
	p.slot_type = PartDef.SlotType.HEAD
	p.rarity = PartDef.Rarity.COMMON
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.damage_type = 0  # no skill on a Common part → damage_type unset is valid
	p.sprite_id = &"spr_test"
	return p


## A valid Rare non-Core part: skill required → damage_type must be a real MVP type.
func _valid_rare(id: StringName) -> PartDef:
	var p := _valid_part(id)
	p.rarity = PartDef.Rarity.RARE
	p.active_skill_id = &"skill_%s" % id
	p.damage_type = PartDef.DamageType.ENERGY
	return p


## A valid Core part at the given rarity (Core never has an active skill;
## Rare+ Core requires a passive; recharge is permitted on Core).
func _valid_core(id: StringName, rarity: PartDef.Rarity) -> PartDef:
	var p := _valid_part(id)
	p.slot_type = PartDef.SlotType.CORE
	p.rarity = rarity
	if rarity != PartDef.Rarity.COMMON:
		p.passive_id = &"passive_%s" % id
	return p


## Assign a single `recharge` bonus via a properly-typed dictionary.
func _with_recharge(part: PartDef, value: int) -> PartDef:
	var sb: Dictionary[StringName, int] = {}
	sb[RECHARGE_KEY_LOCAL] = value
	part.stat_bonuses = sb
	return part


const RECHARGE_KEY_LOCAL := &"recharge"


## Run the validator over the given parts; stash the spy for diagnostic asserts.
func _run(parts: Array[PartDef]) -> Dictionary:
	var catalog := PartCatalog.new()
	catalog.entries = parts
	var catalogs := ContentCatalogs.new()
	catalogs.parts = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


## True if the spy recorded an error with the given code.
func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


func _one(part: PartDef) -> Dictionary:
	var parts: Array[PartDef] = [part]
	return _run(parts)


# ---------------------------------------------------------------------------
# Baseline: a fully-valid, diverse catalog passes cleanly
# ---------------------------------------------------------------------------

func test_valid_catalog_ok_true_and_no_logged_errors() -> void:
	var parts: Array[PartDef] = [
		_valid_part(&"head_a"),
		_valid_rare(&"arm_b"),
		_valid_core(&"core_common", PartDef.Rarity.COMMON),
		_valid_core(&"core_rare", PartDef.Rarity.RARE),
		_with_recharge(func_energy_cell(&"cell_d"), 15),
		func_chassis(&"chassis_e"),
	]
	var r := _run(parts)
	assert_true(r["ok"], "a diverse fully-valid catalog validates ok==true")
	assert_eq((r["errors"] as Array).size(), 0, "no errors on a valid catalog")
	assert_eq(_spy.errors.size(), 0, "nothing routed through the LogSink on a valid catalog")


## A valid ENERGY_CELL (may carry recharge).
func func_energy_cell(id: StringName) -> PartDef:
	var p := _valid_part(id)
	p.slot_type = PartDef.SlotType.ENERGY_CELL
	return p


## A valid CHASSIS part (requires a non-null archetype).
func func_chassis(id: StringName) -> PartDef:
	var p := _valid_part(id)
	p.slot_type = PartDef.SlotType.CHASSIS
	p.chassis_archetype = PartDef.ChassisArchetype.BALANCED_FRAME
	return p


# ---------------------------------------------------------------------------
# AC-01 — required fields + rarity-gated nullability (incl. CORE exception)
# ---------------------------------------------------------------------------

func test_ac_01_common_noncore_with_active_skill_errors() -> void:
	var p := _valid_part(&"bad")
	p.active_skill_id = &"illegal_skill"  # Common ceiling is 0 effects; a skill exceeds it
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_effect_capacity_exceeded"), "a Common carrying any effect exceeds its 0-effect ceiling")


func test_ac_01_core_with_active_skill_errors() -> void:
	var p := _valid_core(&"bad_core", PartDef.Rarity.RARE)
	p.active_skill_id = &"illegal_core_skill"  # Core is a support slot — never a skill
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_active_skill_forbidden"), "Core with a skill is flagged at any rarity")


func test_ac_01_rare_core_missing_passive_errors() -> void:
	var p := _valid_core(&"bad_core", PartDef.Rarity.RARE)
	p.passive_id = &""  # Core can't hold a skill, so its one required effect must be a passive
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_effect_missing"), "Rare Core with no passive fails the Rare+ effect floor")


func test_ac_01_rare_noncore_no_effect_errors() -> void:
	var p := _valid_part(&"rare_arm")
	p.rarity = PartDef.Rarity.RARE  # 0 effects; every Rare+ part must bring at least one
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_effect_missing"), "Rare non-Core with no skill or passive fails the effect floor")


func test_ac_01_rare_noncore_passive_only_passes() -> void:
	# Passives are now legal on any slot — a Rare with a passive and no skill is valid.
	var p := _valid_part(&"rare_pass")
	p.rarity = PartDef.Rarity.RARE
	p.passive_id = &"passive_rare_pass"
	var r := _one(p)
	assert_true(r["ok"], "a Rare non-Core carrying only a passive satisfies the effect floor")


func test_ac_01_boss_noncore_single_effect_passes() -> void:
	var p := _valid_rare(&"boss_arm")
	p.rarity = PartDef.Rarity.BOSS_GRADE  # skill only = 1 effect; within Boss band [1..2]
	var r := _one(p)
	assert_true(r["ok"], "Boss-grade non-Core with a single effect (skill only) is valid — passive no longer required")


func test_ac_01_skill_on_chipset_passes() -> void:
	# Chipset is a skill-capable slot under Rule 8.
	var p := _valid_part(&"chip")
	p.slot_type = PartDef.SlotType.CHIPSET
	p.rarity = PartDef.Rarity.RARE
	p.active_skill_id = &"skill_chip"
	p.damage_type = PartDef.DamageType.ENERGY
	var r := _one(p)
	assert_true(r["ok"], "an active skill on a Chipset is permitted (skill-capable slot)")


func test_ac_01_skill_on_energy_cell_errors() -> void:
	# Energy Cell is a support slot — never an active skill.
	var p := _valid_part(&"cell_skill")
	p.slot_type = PartDef.SlotType.ENERGY_CELL
	p.rarity = PartDef.Rarity.RARE
	p.active_skill_id = &"skill_cell"
	p.damage_type = PartDef.DamageType.ENERGY
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_active_skill_forbidden"), "an active skill on an Energy Cell (support slot) is forbidden")


func test_ac_01_rare_two_effects_exceeds_ceiling_errors() -> void:
	# Rare ceiling is 1 effect; a skill AND a passive is two.
	var p := _valid_part(&"rare_two")
	p.rarity = PartDef.Rarity.RARE
	p.active_skill_id = &"skill_two"
	p.passive_id = &"passive_two"
	p.damage_type = PartDef.DamageType.ENERGY
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_effect_capacity_exceeded"), "a Rare carrying both a skill and a passive exceeds its 1-effect ceiling")


func test_ac_01_boss_chassis_skill_and_passive_passes() -> void:
	# Chassis is skill-capable; Boss ceiling is 2 → skill + passive is valid.
	var p := func_chassis(&"boss_chassis")
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.active_skill_id = &"skill_bc"
	p.passive_id = &"passive_bc"
	p.damage_type = PartDef.DamageType.ENERGY
	var r := _one(p)
	assert_true(r["ok"], "a Boss Chassis with both a skill and a passive is valid (2 effects within Boss band)")


func test_ac_01_common_core_neither_skill_nor_passive_passes() -> void:
	var r := _one(_valid_core(&"cc", PartDef.Rarity.COMMON))
	assert_true(r["ok"], "Common Core with neither skill nor passive is valid")


# AC-01 sub-check (d) — a support slot must not gain an active skill via an upgrade.
# SKILL_UNLOCK on a Core/Energy Cell bypasses the static active_skill_id gate (c).
func test_ac_01_core_skill_unlock_upgrade_effect_errors() -> void:
	# Arrange: a valid Rare Core (passive satisfies the floor) that tries to unlock a
	# skill at +4 through upgrade_effects — illegal on a support slot.
	var p := _valid_core(&"unlock_core", PartDef.Rarity.RARE)
	var effects: Array[Dictionary] = [
		{"tier": 4, "effect_type": &"SKILL_UNLOCK", "description": "", "skill_id": &"skill_sneaky"},
	]
	p.upgrade_effects = effects

	# Act
	var r := _one(p)

	# Assert
	assert_false(r["ok"])
	assert_true(_logged(&"content_upgrade_skill_unlock_forbidden"), "a SKILL_UNLOCK upgrade on a support slot (Core) is forbidden")


# AC-01 sub-check (d) — SKILL_ENHANCE tunes an existing passive and stays legal on Core.
func test_ac_01_core_skill_enhance_upgrade_effect_passes() -> void:
	# Arrange: same valid Rare Core, but the +4 upgrade enhances its passive rather
	# than unlocking a new active skill.
	var p := _valid_core(&"enhance_core", PartDef.Rarity.RARE)
	var effects: Array[Dictionary] = [
		{"tier": 4, "effect_type": &"SKILL_ENHANCE", "description": "", "skill_id": &"passive_enhance_core"},
	]
	p.upgrade_effects = effects

	# Act
	var r := _one(p)

	# Assert
	assert_true(r["ok"], "a SKILL_ENHANCE upgrade on a support slot (Core) is permitted")


func test_ac_01_missing_id_errors() -> void:
	var p := _valid_part(&"tmp")
	p.id = &""
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_missing_id"), "empty id is flagged")


func test_ac_01_missing_display_name_errors() -> void:
	var p := _valid_part(&"noname")
	p.display_name = ""
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_missing_display_name"), "empty display_name is flagged")


# ---------------------------------------------------------------------------
# AC-02 — global id uniqueness
# ---------------------------------------------------------------------------

func test_ac_02_duplicate_id_errors() -> void:
	var parts: Array[PartDef] = [_valid_part(&"dup"), _valid_part(&"dup")]
	var r := _run(parts)
	assert_false(r["ok"])
	assert_true(_logged(&"content_duplicate_id"), "two entries sharing an id are flagged")


func test_ac_02_unique_ids_pass() -> void:
	var parts: Array[PartDef] = [_valid_part(&"a"), _valid_part(&"b")]
	var r := _run(parts)
	assert_true(r["ok"], "distinct ids validate cleanly")


# ---------------------------------------------------------------------------
# AC-03 — slot_type enum membership
# ---------------------------------------------------------------------------

func test_ac_03_invalid_slot_type_errors() -> void:
	var p := _valid_part(&"bad_slot")
	p.slot_type = 99  # not one of the 8 MVP slots
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_invalid_slot_type"), "out-of-set slot_type is flagged")


func test_ac_03_zero_slot_type_sentinel_errors() -> void:
	var p := _valid_part(&"unset_slot")
	p.slot_type = 0  # the reserved/invalid sentinel
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_invalid_slot_type"), "the 0 sentinel is caught as invalid")


# ---------------------------------------------------------------------------
# AC-17 / AC-18 — recharge range + slot gating
# ---------------------------------------------------------------------------

func test_ac_17_recharge_above_range_errors() -> void:
	var p := _with_recharge(func_energy_cell(&"cell"), 20)  # > 15
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_recharge_out_of_range"), "recharge 20 exceeds [0,15]")


func test_ac_17_recharge_at_boundary_15_passes() -> void:
	var r := _one(_with_recharge(func_energy_cell(&"cell"), 15))
	assert_true(r["ok"], "recharge exactly 15 is in range on an ENERGY_CELL")


func test_ac_18_noncell_noncore_recharge_errors() -> void:
	var p := _with_recharge(_valid_part(&"head_rc"), 5)  # HEAD may not carry recharge
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_recharge_slot_gating"), "a HEAD carrying recharge is flagged")


func test_ac_18_missing_recharge_key_treated_as_zero_passes() -> void:
	var r := _one(_valid_part(&"no_rc"))  # empty stat_bonuses → recharge reads 0
	assert_true(r["ok"], "absent recharge key reads as 0 and passes")


# ---------------------------------------------------------------------------
# AC-20 — chassis_archetype presence/absence by slot
# ---------------------------------------------------------------------------

func test_ac_20_chassis_missing_archetype_errors() -> void:
	var p := func_chassis(&"ch")
	p.chassis_archetype = 0  # CHASSIS must carry a real archetype
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_chassis_missing_archetype"), "CHASSIS without an archetype is flagged")


func test_ac_20_nonchassis_with_archetype_errors() -> void:
	var p := _valid_part(&"head_arch")
	p.chassis_archetype = PartDef.ChassisArchetype.LIGHT_FRAME  # HEAD must leave it 0
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_nonchassis_has_archetype"), "non-CHASSIS carrying an archetype is flagged")


func test_ac_20_core_null_archetype_passes() -> void:
	var r := _one(_valid_core(&"core_z", PartDef.Rarity.COMMON))  # archetype 0
	assert_true(r["ok"], "CORE with archetype 0 is valid")


# ---------------------------------------------------------------------------
# AC-21 — enum-set membership + Full-Vision-reserved rejection
# ---------------------------------------------------------------------------

func test_ac_21_reserved_element_cryo_errors() -> void:
	var p := _valid_part(&"cryo")
	p.element = PartDef.Element.CRYO  # reserved for Full Vision
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_invalid_element"), "reserved element CRYO is rejected in MVP content")


func test_ac_21_invalid_manufacturer_errors() -> void:
	var p := _valid_part(&"nomaker")
	p.manufacturer = &"acme"  # not an authored manufacturer
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_invalid_manufacturer"), "unknown manufacturer is flagged")


func test_ac_21_reserved_damage_type_errors() -> void:
	var p := _valid_rare(&"truedmg")
	p.damage_type = PartDef.DamageType.TRUE  # reserved — rejected even with a skill
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_reserved_damage_type"), "reserved damage type TRUE is rejected")


func test_ac_21_skilled_part_unset_damage_type_errors() -> void:
	var p := _valid_rare(&"skill_nodmg")
	p.damage_type = 0  # a part that delivers a skill must name a real damage type
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_invalid_damage_type"), "a skilled part with unset damage_type is flagged")


func test_ac_21_invalid_rarity_sentinel_errors() -> void:
	var p := _valid_part(&"norarity")
	p.rarity = 0  # reserved/invalid sentinel
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_invalid_rarity"), "the 0 rarity sentinel is caught")


# ---------------------------------------------------------------------------
# AC-22 / AC-24 — heat range, null-skill heat, sprite_id
# ---------------------------------------------------------------------------

func test_ac_22_heat_above_range_errors() -> void:
	var p := _valid_rare(&"hot")
	p.heat_generation = 41  # > 40
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_heat_out_of_range"), "heat 41 exceeds [0,40]")


func test_ac_22_null_skill_with_heat_errors() -> void:
	var p := _valid_part(&"cold_heat")  # no active skill
	p.heat_generation = 5
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_heat_without_skill"), "a skill-less part generating heat is flagged")


func test_ac_22_null_skill_zero_heat_passes() -> void:
	var r := _one(_valid_part(&"cool"))  # no skill, heat 0
	assert_true(r["ok"], "a skill-less part with zero heat is valid")


func test_ac_24_empty_sprite_id_errors() -> void:
	var p := _valid_part(&"nospr")
	p.sprite_id = &""
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_missing_sprite_id"), "empty sprite_id is flagged")


# ---------------------------------------------------------------------------
# Scaffold contract — errors are mirrored to the LogSink in lock-step
# ---------------------------------------------------------------------------

func test_errors_are_routed_through_log_sink_in_lockstep() -> void:
	var p := _valid_part(&"multi")
	p.sprite_id = &""       # → content_missing_sprite_id
	p.slot_type = 0         # → content_invalid_slot_type
	var r := _one(p)
	assert_false(r["ok"])
	assert_eq((r["errors"] as Array).size(), _spy.errors.size(),
		"every returned error is mirrored through the injected LogSink")
	assert_gt(_spy.errors.size(), 1, "multiple independent corruptions each surface")


func test_missing_part_catalog_is_reported_not_crashed() -> void:
	var catalogs := ContentCatalogs.new()
	catalogs.parts = null
	_spy = SpyLogSink.new()
	var r := ContentValidator.new().validate(catalogs, _spy)
	assert_false(r["ok"])
	assert_true(_logged(&"content_missing_part_catalog"), "a null part catalog is reported, not a crash")
