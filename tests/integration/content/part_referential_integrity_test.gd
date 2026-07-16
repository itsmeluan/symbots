## Part-DB Story 009 — ContentValidator cross-DB referential integrity + level fields.
##
## Integration: the validator crosses catalog boundaries (Part→Move / Part→Passive,
## AC-13 / TR-part-013) and enforces the two Core-Progression-erratum structural
## fields hosted on [PartDef] — `level_requirement` rarity floors (TR-part-011) and
## `level_growth` CORE-only (TR-part-012). This family runs ONLY when a Move/Passive
## resolution index is mounted (`ContentCatalogs.references_mounted`); references are
## resolved against injected `{StringName: true}` id sets (ADR-0003 — DI, StringName
## IDs, never Resource links), so no Move/Passive DB epic is required. Every fixture
## here is schema-valid (Story 007 always runs) so the only diagnostics come from the
## Story 009 family. Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

## Fixture resolution index: one valid Move id and one valid Passive id.
const VALID_SKILL := &"skill_zap"
const VALID_PASSIVE := &"pass_guard"

var _spy


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## A schema-valid RARE HEAD carrying a resolved skill + passive. RARE (non-Core)
## requires an active skill → a real damage_type; a passive is allowed. Baseline for
## the referential and level corruptions.
func _rare_head(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Test %s" % id
	p.slot_type = PartDef.SlotType.HEAD
	p.rarity = PartDef.Rarity.RARE
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.damage_type = PartDef.DamageType.ENERGY
	p.sprite_id = &"spr_%s" % id
	p.synergy_tags = [&"volt", &"boltwell"]
	p.active_skill_id = VALID_SKILL
	p.passive_id = VALID_PASSIVE
	p.level_requirement = 3  # meets the RARE floor
	return p


## A schema-valid COMMON HEAD: no skill, no passive (Common forbids both), no refs.
func _common_head(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Test %s" % id
	p.slot_type = PartDef.SlotType.HEAD
	p.rarity = PartDef.Rarity.COMMON
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.sprite_id = &"spr_%s" % id
	p.synergy_tags = [&"volt", &"boltwell"]
	return p


## A schema-valid RARE CORE: Core forbids an active skill at any rarity and (Rare+)
## requires a passive. The only slot allowed a non-empty `level_growth`.
func _rare_core(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Test %s" % id
	p.slot_type = PartDef.SlotType.CORE
	p.rarity = PartDef.Rarity.RARE
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.sprite_id = &"spr_%s" % id
	p.synergy_tags = [&"volt", &"boltwell"]
	p.passive_id = VALID_PASSIVE
	p.level_requirement = 3
	return p


## Run the validator with the Move/Passive resolution index mounted (Story 009
## active). Balance is left unmounted so the Story 008 families stay dormant and the
## only findings are schema (007) + referential/level (009).
func _run(parts: Array[PartDef]) -> Dictionary:
	var catalog := PartCatalog.new()
	catalog.entries = parts
	var catalogs := ContentCatalogs.new()
	catalogs.parts = catalog
	catalogs.move_ids = {VALID_SKILL: true}
	catalogs.passive_ids = {VALID_PASSIVE: true}
	catalogs.references_mounted = true
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


## Run WITHOUT mounting the resolution index — the Story 009 family must be skipped.
func _run_unmounted(parts: Array[PartDef]) -> Dictionary:
	var catalog := PartCatalog.new()
	catalog.entries = parts
	var catalogs := ContentCatalogs.new()
	catalogs.parts = catalog  # references_mounted stays false
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _one(part: PartDef) -> Dictionary:
	var parts: Array[PartDef] = [part]
	return _run(parts)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# Baseline
# ---------------------------------------------------------------------------

func test_valid_resolved_catalog_passes() -> void:
	var parts: Array[PartDef] = [_rare_head(&"h_r"), _common_head(&"h_c"), _rare_core(&"c_r")]
	var r := _run(parts)
	assert_true(r["ok"], "a fully-resolved, floor-respecting catalog validates ok==true")
	assert_eq(_spy.errors.size(), 0, "no errors on a valid Story 009 catalog")


# ---------------------------------------------------------------------------
# AC-13 — referential integrity Part→Move / Part→Passive
# ---------------------------------------------------------------------------

func test_ac_13_dangling_skill_ref_errors() -> void:
	var p := _rare_head(&"dangling_skill")
	p.active_skill_id = &"skill_missing"  # not in the mounted Move index
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_dangling_skill_ref"), "an unresolved active_skill_id is flagged")


func test_ac_13_dangling_passive_ref_errors() -> void:
	var p := _rare_head(&"dangling_passive")
	p.passive_id = &"pass_missing"  # not in the mounted Passive index
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_dangling_passive_ref"), "an unresolved passive_id is flagged")


func test_ac_13_empty_refs_are_skipped_not_flagged() -> void:
	# A Common part carries neither reference — &"" is "none", never a dangling ref.
	var p := _common_head(&"no_refs")
	var r := _one(p)
	assert_true(r["ok"], "a part with both references &\"\" passes")
	assert_false(_logged(&"content_dangling_skill_ref"))
	assert_false(_logged(&"content_dangling_passive_ref"))


func test_ac_13_dangling_passive_on_core_errors() -> void:
	# The Core-exception passive path still resolves against the Passive index.
	var p := _rare_core(&"core_dangling")
	p.passive_id = &"pass_missing"
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_dangling_passive_ref"), "a dangling Core passive_id is flagged")


# ---------------------------------------------------------------------------
# TR-part-011 — level_requirement rarity floors
# ---------------------------------------------------------------------------

func test_level_requirement_below_floor_errors() -> void:
	var p := _rare_head(&"below_floor")
	p.level_requirement = 2  # RARE floor is 3
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_level_requirement_below_floor"), "a RARE below floor 3 is flagged")


func test_level_requirement_zero_on_nonfloor_rarity_errors() -> void:
	# 0 is the unset sentinel → defaults to 1; a RARE at 1 is still below floor 3, so
	# a non-Common part left at 0 must be flagged (authoring must set it explicitly).
	var p := _rare_head(&"zero_req")
	p.level_requirement = 0
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_level_requirement_below_floor"),
		"a RARE left at the unset 0 (→1) is below floor 3 and flagged")


func test_level_requirement_at_floor_passes() -> void:
	var p := _rare_head(&"at_floor")
	p.level_requirement = 3  # exactly the RARE floor
	var r := _one(p)
	assert_true(r["ok"], "a RARE exactly at floor 3 passes")


func test_level_requirement_above_floor_passes() -> void:
	var p := _rare_head(&"above_floor")
	p.level_requirement = 8  # a part may exceed its floor
	var r := _one(p)
	assert_true(r["ok"], "a RARE above its floor passes (may exceed, never go below)")


func test_level_requirement_common_zero_passes() -> void:
	# COMMON floor is 1; unset 0 → 1 meets it (the QA AC-2 null-defaults-to-1 case).
	var p := _common_head(&"common_zero")
	var r := _one(p)
	assert_true(r["ok"], "a COMMON at the unset 0 (→1) meets floor 1 and passes")


func test_level_requirement_boss_floor_enforced() -> void:
	# A BOSS_GRADE HEAD (skill+passive+drop condition) at 5 is below floor 6.
	var p := _rare_head(&"boss_low")
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.level_requirement = 5
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_level_requirement_below_floor"), "a BOSS_GRADE at 5 is below floor 6")


# ---------------------------------------------------------------------------
# TR-part-012 — level_growth CORE-only
# ---------------------------------------------------------------------------

func test_level_growth_on_non_core_errors() -> void:
	var p := _rare_head(&"growth_noncore")
	p.level_growth = {"structure": 2}  # non-empty on a HEAD is illegal
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_level_growth_non_core"), "a non-CORE part with level_growth is flagged")


func test_level_growth_on_core_passes() -> void:
	var p := _rare_core(&"growth_core")
	p.level_growth = {"energy_capacity": 3}  # CORE may carry growth
	var r := _one(p)
	assert_true(r["ok"], "a CORE part with a non-empty level_growth passes")


func test_level_growth_empty_on_core_passes() -> void:
	var p := _rare_core(&"nogrowth_core")  # empty level_growth on CORE is allowed
	var r := _one(p)
	assert_true(r["ok"], "a CORE part with an empty level_growth passes (growth is optional)")


# ---------------------------------------------------------------------------
# Gating — the Story 009 family is inert until a resolution index is mounted
# ---------------------------------------------------------------------------

func test_family_skipped_when_references_unmounted() -> void:
	# A part with BOTH a dangling ref and a sub-floor level: with no resolution index
	# mounted, the whole Story 009 family is dormant, so this schema-valid part passes.
	var p := _rare_head(&"unmounted")
	p.active_skill_id = &"skill_missing"
	p.level_requirement = 1  # below RARE floor 3
	var r := _run_unmounted([p] as Array[PartDef])
	assert_true(r["ok"], "with references unmounted, the referential + level family is skipped")
	assert_false(_logged(&"content_dangling_skill_ref"))
	assert_false(_logged(&"content_level_requirement_below_floor"))
