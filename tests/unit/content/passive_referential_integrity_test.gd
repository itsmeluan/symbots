## Passive-DB Story 006 — Part↔Passive referential integrity & catalog wiring.
##
## Builds a Part catalog and a Passive catalog TOGETHER and drives the full
## ContentValidator with the passive resolution index mounted, proving the
## cross-DB link end-to-end:
##   AC-2 (builder): ContentCatalogs.passive_ids_from() builds a {StringName: true}
##         set — null catalog / null entry contribute nothing.
##   AC-1 (resolve): a part.passive_id matching a real passive → validator clean.
##   AC-1 (dangling): a part.passive_id absent from the Passive catalog →
##         content_dangling_passive_ref naming the part + passive id (AC-PDB-13).
##   Edge: passive_id == &"" is never flagged; references_mounted == false skips
##         the whole check (prior-story fixtures stay green).
## The passive_ids seam is populated from the real PassiveCatalog via the one
## canonical builder ContentCatalogs.passive_ids_from() — the same path the real
## boot uses. Mirrors the Part↔Move sibling (move_referential_integrity_test.gd).
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/passive_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## A fully-valid STATUS_RIDER passive with the given id — a resolution target for
## a part's passive_id. Mirrors the schema-test baseline rider (Rule 3 legal:
## STATUS_RIDER fires ON_HIT).
func _passive(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Passive %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.ON_HIT
	pd.behavior_class   = PassiveDef.BehaviorClass.STATUS_RIDER
	pd.scope            = PassiveDef.Scope.ANY_DAMAGE
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER
	pd.passive_class    = PassiveDef.PassiveClass.STATUS_RIDER
	pd.behavior_params  = {"status_id": &"shock", "duration": 1}
	return pd


## A valid Rare HEAD part carrying the given passive_id. Rare (not Common) is
## required: a passive is one effect, and Rule 8's effect-capacity ceiling is 0 for
## Common but ≥1 for Rare+ (a Common carrying any effect trips
## content_effect_capacity_exceeded). `level_requirement` 3 meets the RARE floor so
## the Story-009 level family (which runs whenever the resolution index is mounted)
## stays clean and only the referential check speaks.
func _part_with_passive(id: StringName, passive_id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Part %s" % id
	p.slot_type = PartDef.SlotType.HEAD
	p.rarity = PartDef.Rarity.RARE
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.sprite_id = &"spr_%s" % id
	p.passive_id = passive_id
	p.level_requirement = 3
	return p


## A valid Common HEAD part with no passive reference — the &"" case. Common carries
## zero effects, so it needs no passive and sits at the level-1 floor.
func _part_bare(id: StringName) -> PartDef:
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
# Harness — mounts Part + Passive catalogs together with the resolution index live
# ---------------------------------------------------------------------------

## Validate the given parts against the given passives with references mounted. The
## passive_ids seam is built from the real PassiveCatalog via the canonical builder.
func _run(parts: Array[PartDef], passives: Array[PassiveDef], mount_refs: bool = true) -> Dictionary:
	var part_catalog := PartCatalog.new()
	part_catalog.entries = parts
	var passive_catalog := PassiveCatalog.new()
	passive_catalog.entries = passives

	var catalogs := ContentCatalogs.new()
	catalogs.parts = part_catalog
	catalogs.passives = passive_catalog
	if mount_refs:
		catalogs.passive_ids = ContentCatalogs.passive_ids_from(passive_catalog)
		catalogs.references_mounted = true

	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# AC-2 — the canonical builder itself
# ---------------------------------------------------------------------------

func test_passive_ids_from_builds_membership_set() -> void:
	var catalog := PassiveCatalog.new()
	var passives: Array[PassiveDef] = [_passive(&"pas_x"), _passive(&"pas_y")]
	catalog.entries = passives
	var ids := ContentCatalogs.passive_ids_from(catalog)
	assert_true(ids.has(&"pas_x"), "pas_x is in the set")
	assert_true(ids.has(&"pas_y"), "pas_y is in the set")
	assert_eq(ids.size(), 2, "exactly the catalog's ids, nothing else")
	assert_eq(ids[&"pas_x"], true, "each id maps to true (membership set)")


func test_passive_ids_from_null_catalog_is_empty() -> void:
	assert_eq(ContentCatalogs.passive_ids_from(null).size(), 0, "null catalog → empty set, no crash")


func test_passive_ids_from_empty_catalog_is_empty() -> void:
	assert_eq(ContentCatalogs.passive_ids_from(PassiveCatalog.new()).size(), 0, "empty catalog → empty set")


func test_passive_ids_from_skips_null_entries() -> void:
	var catalog := PassiveCatalog.new()
	var passives: Array[PassiveDef] = [_passive(&"pas_x"), null]
	catalog.entries = passives
	var ids := ContentCatalogs.passive_ids_from(catalog)
	assert_eq(ids.size(), 1, "a null entry contributes nothing")
	assert_true(ids.has(&"pas_x"))


# ---------------------------------------------------------------------------
# AC-1 — every passive_id resolves → clean
# ---------------------------------------------------------------------------

func test_ac1_all_passive_refs_resolve_clean() -> void:
	var parts: Array[PartDef] = [
		_part_with_passive(&"part_a", &"pas_x"),
		_part_with_passive(&"part_b", &"pas_y"),
	]
	var passives: Array[PassiveDef] = [_passive(&"pas_x"), _passive(&"pas_y")]
	var result := _run(parts, passives)
	assert_true(result["ok"], "every passive_id resolves against the Passive catalog")
	assert_false(_logged(&"content_dangling_passive_ref"), "no dangling-passive error on a clean set")


# ---------------------------------------------------------------------------
# AC-1 — a dangling passive_id errors, naming part + passive (AC-PDB-13)
# ---------------------------------------------------------------------------

func test_ac1_dangling_passive_ref_errors_naming_part_and_passive() -> void:
	var parts: Array[PartDef] = [_part_with_passive(&"part_ghosted", &"ghost_passive")]
	var passives: Array[PassiveDef] = [_passive(&"pas_x")]  # ghost_passive is absent
	var result := _run(parts, passives)
	assert_false(result["ok"], "a dangling passive_id fails validation")
	assert_true(_logged(&"content_dangling_passive_ref"), "logs content_dangling_passive_ref")
	# The finding names BOTH the offending part and the unresolved passive id.
	var named := false
	for e in _spy.errors:
		if e["code"] == &"content_dangling_passive_ref":
			assert_eq(e["detail"]["id"], &"part_ghosted", "names the part")
			assert_eq(e["detail"]["passive_id"], &"ghost_passive", "names the unresolved passive")
			named = true
	assert_true(named, "the dangling-passive error carries part + passive detail")


func test_ac1_partial_dangling_only_the_bad_part_errors() -> void:
	# One resolving part + one dangling part: exactly one error, for the dangling one.
	var parts: Array[PartDef] = [
		_part_with_passive(&"part_ok", &"pas_x"),
		_part_with_passive(&"part_bad", &"ghost_passive"),
	]
	var passives: Array[PassiveDef] = [_passive(&"pas_x")]
	var result := _run(parts, passives)
	assert_false(result["ok"], "the catalog fails because one ref dangles")
	var unresolved := []
	for e in _spy.errors:
		if e["code"] == &"content_dangling_passive_ref":
			unresolved.append(e["detail"]["id"])
	assert_eq(unresolved, [&"part_bad"], "only the dangling part is flagged")


# ---------------------------------------------------------------------------
# Edge — empty ref never flagged; unmounted index skips the whole check
# ---------------------------------------------------------------------------

func test_empty_passive_id_never_flagged() -> void:
	var parts: Array[PartDef] = [_part_bare(&"part_bare")]
	var passives: Array[PassiveDef] = [_passive(&"pas_x")]
	var result := _run(parts, passives)
	assert_true(result["ok"], "a part with passive_id == &\"\" carries no reference to resolve")
	assert_false(_logged(&"content_dangling_passive_ref"), "&\"\" is 'none', never a dangling ref")


func test_unmounted_references_skip_the_check() -> void:
	# A dangling ref with the resolution index NOT mounted must pass — the Part↔Passive
	# family is dormant until references_mounted is true (prior-story fixtures stay green).
	var parts: Array[PartDef] = [_part_with_passive(&"part_unmounted", &"ghost_passive")]
	var passives: Array[PassiveDef] = [_passive(&"pas_x")]
	var result := _run(parts, passives, false)
	assert_true(result["ok"], "with references unmounted, the dangling ref is not checked")
	assert_false(_logged(&"content_dangling_passive_ref"), "check is skipped when unmounted")
