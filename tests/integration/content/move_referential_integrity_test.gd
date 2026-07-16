## Move-DB Story 006 — Part↔Move referential integrity (Integration).
##
## Builds a Part catalog and a Move catalog TOGETHER and drives the full
## ContentValidator with the resolution index mounted, proving the cross-DB link
## end-to-end:
##   AC-1 (resolve): every active_skill_id matching a real move → validator clean.
##   AC-2 (dangling): an active_skill_id absent from the Move catalog →
##         content_active_skill_unresolved naming the part + skill id.
##   Edge: active_skill_id == &"" is never flagged; references_mounted == false
##         skips the whole check.
## The move_ids seam is populated from the real MoveCatalog via the one canonical
## builder ContentCatalogs.move_ids_from() — the same path the real boot uses.
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/move_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## A fully-valid DAMAGE move (in STANDARD band) with the given id — a resolution
## target for a part's active_skill_id.
func _move(id: StringName) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.display_name = "Move %s" % id
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.ENERGY
	m.element = PartDef.Element.VOLT
	m.energy_cost = 15
	m.targeting = MoveDef.Targeting.ENEMY
	return m


## A fully-valid Rare HEAD part carrying an active skill. `level_requirement` 3
## meets the RARE floor so the Story-009 level family (which runs whenever the
## resolution index is mounted) stays clean and only the referential check speaks.
func _skilled_part(id: StringName, skill_id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Part %s" % id
	p.slot_type = PartDef.SlotType.HEAD
	p.rarity = PartDef.Rarity.RARE
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.damage_type = PartDef.DamageType.ENERGY  # a skill-bearing part needs an MVP type
	p.sprite_id = &"spr_%s" % id
	p.active_skill_id = skill_id
	p.level_requirement = 3
	return p


## A valid Common HEAD part with no active skill — the &"" reference case.
func _skilless_part(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Part %s" % id
	p.slot_type = PartDef.SlotType.HEAD
	p.rarity = PartDef.Rarity.COMMON
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.sprite_id = &"spr_%s" % id
	p.level_requirement = 1
	return p


# ---------------------------------------------------------------------------
# Harness — mounts Part + Move catalogs together with the resolution index live
# ---------------------------------------------------------------------------

## Validate the given parts against the given moves with references mounted. The
## move_ids seam is built from the real MoveCatalog via the canonical builder.
func _run(parts: Array[PartDef], moves: Array[MoveDef], mount_refs: bool = true) -> Dictionary:
	var part_catalog := PartCatalog.new()
	part_catalog.entries = parts
	var move_catalog := MoveCatalog.new()
	move_catalog.entries = moves

	var catalogs := ContentCatalogs.new()
	catalogs.parts = part_catalog
	catalogs.moves = move_catalog
	if mount_refs:
		catalogs.move_ids = ContentCatalogs.move_ids_from(move_catalog)
		catalogs.references_mounted = true

	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# The canonical builder itself
# ---------------------------------------------------------------------------

func test_move_ids_from_builds_membership_set() -> void:
	var catalog := MoveCatalog.new()
	var moves: Array[MoveDef] = [_move(&"skill_x"), _move(&"skill_y")]
	catalog.entries = moves
	var ids := ContentCatalogs.move_ids_from(catalog)
	assert_true(ids.has(&"skill_x"), "skill_x is in the set")
	assert_true(ids.has(&"skill_y"), "skill_y is in the set")
	assert_eq(ids.size(), 2, "exactly the catalog's ids, nothing else")


func test_move_ids_from_null_catalog_is_empty() -> void:
	assert_eq(ContentCatalogs.move_ids_from(null).size(), 0, "null catalog → empty set, no crash")


func test_move_ids_from_skips_null_entries() -> void:
	var catalog := MoveCatalog.new()
	var moves: Array[MoveDef] = [_move(&"skill_x"), null]
	catalog.entries = moves
	var ids := ContentCatalogs.move_ids_from(catalog)
	assert_eq(ids.size(), 1, "a null entry contributes nothing")
	assert_true(ids.has(&"skill_x"))


# ---------------------------------------------------------------------------
# AC-1 — every active_skill_id resolves → clean
# ---------------------------------------------------------------------------

func test_ac1_all_skill_refs_resolve_clean() -> void:
	var parts: Array[PartDef] = [
		_skilled_part(&"part_a", &"skill_x"),
		_skilled_part(&"part_b", &"skill_y"),
	]
	var moves: Array[MoveDef] = [_move(&"skill_x"), _move(&"skill_y")]
	var result := _run(parts, moves)
	assert_true(result["ok"], "every active_skill_id resolves against the Move catalog")
	assert_false(_logged(&"content_active_skill_unresolved"), "no unresolved-skill error on a clean set")


# ---------------------------------------------------------------------------
# AC-2 — a dangling active_skill_id errors, naming part + skill
# ---------------------------------------------------------------------------

func test_ac2_dangling_skill_ref_errors_naming_part_and_skill() -> void:
	var parts: Array[PartDef] = [_skilled_part(&"part_ghosted", &"skill_ghost")]
	var moves: Array[MoveDef] = [_move(&"skill_x")]  # skill_ghost is absent
	var result := _run(parts, moves)
	assert_false(result["ok"], "a dangling active_skill_id fails validation")
	assert_true(_logged(&"content_active_skill_unresolved"), "logs content_active_skill_unresolved")
	# The finding names BOTH the offending part and the unresolved skill id.
	var named := false
	for e in _spy.errors:
		if e["code"] == &"content_active_skill_unresolved":
			assert_eq(e["detail"]["id"], &"part_ghosted", "names the part")
			assert_eq(e["detail"]["active_skill_id"], &"skill_ghost", "names the unresolved skill")
			named = true
	assert_true(named, "the unresolved-skill error carries part + skill detail")


func test_ac2_partial_dangling_only_the_bad_part_errors() -> void:
	# One resolving part + one dangling part: exactly one error, for the dangling one.
	var parts: Array[PartDef] = [
		_skilled_part(&"part_ok", &"skill_x"),
		_skilled_part(&"part_bad", &"skill_ghost"),
	]
	var moves: Array[MoveDef] = [_move(&"skill_x")]
	var result := _run(parts, moves)
	assert_false(result["ok"], "the catalog fails because one ref dangles")
	var unresolved := []
	for e in _spy.errors:
		if e["code"] == &"content_active_skill_unresolved":
			unresolved.append(e["detail"]["id"])
	assert_eq(unresolved, [&"part_bad"], "only the dangling part is flagged")


# ---------------------------------------------------------------------------
# Edge — empty ref never flagged; unmounted index skips the whole check
# ---------------------------------------------------------------------------

func test_empty_active_skill_id_never_flagged() -> void:
	var parts: Array[PartDef] = [_skilless_part(&"part_bare")]
	var moves: Array[MoveDef] = [_move(&"skill_x")]
	var result := _run(parts, moves)
	assert_true(result["ok"], "a part with active_skill_id == &\"\" carries no reference to resolve")
	assert_false(_logged(&"content_active_skill_unresolved"), "&\"\" is 'none', never a dangling ref")


func test_unmounted_references_skip_the_check() -> void:
	# A dangling ref with the resolution index NOT mounted must pass — the Part↔Move
	# family is dormant until references_mounted is true (prior-story fixtures stay green).
	var parts: Array[PartDef] = [_skilled_part(&"part_unmounted", &"skill_ghost")]
	var moves: Array[MoveDef] = [_move(&"skill_x")]
	var result := _run(parts, moves, false)
	assert_true(result["ok"], "with references unmounted, the dangling ref is not checked")
	assert_false(_logged(&"content_active_skill_unresolved"), "check is skipped when unmounted")
