## Part-DB Story 010 — shipping-content CI gate.
##
## The blocking gate that proves the REAL authored content — the 14 MVP PartDefs,
## the PartCatalog manifest, and the BalanceConfig — passes the full ContentValidator
## (all three families: schema/007, budget-composition/008, referential-level/009)
## with `ok == true` and zero errors. It loads every resource fresh from disk
## (CACHE_MODE_REPLACE) so it doubles as the on-real-content verification of the
## nested untyped-Dictionary `.tres` round-trip that `balance_config.tres` depends on
## (the isolated spike lives in `balance_config_nested_roundtrip_test.gd`).
##
## Referential integrity (009) is exercised against an explicit MANIFEST of the
## skill / passive IDs the shipped parts forward-reference. That manifest is the
## contract the future Move DB and Passive DB epics owe: a typo in a part's
## `active_skill_id`/`passive_id`, or a part referencing an ID not on the manifest,
## fails this gate. When those DBs land, swap the manifest for their real id sets.
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

const CATALOG_PATH := "res://assets/data/catalogs/part_catalog.tres"
const BALANCE_PATH := "res://assets/data/balance_config.tres"
const PARTS_DIR := "res://assets/data/parts"

## Forward-reference manifest: the Move DB skill IDs the shipped parts declare.
## The Move DB epic must provide exactly these (or a superset).
const SHIPPED_SKILL_IDS: Array[StringName] = [
	&"skill_deep_scan", &"skill_servo_strike", &"skill_crusher_claw",
	&"skill_arc_bolt", &"skill_overdrive_blast",
]

## Forward-reference manifest: the Passive DB IDs the shipped parts declare.
const SHIPPED_PASSIVE_IDS: Array[StringName] = [
	&"pass_overclock", &"pass_rend", &"pass_meltdown",
]

## The only warning codes the shipped set is allowed to emit — advisory AC-23
## coverage gaps for slots/subgroups that (by MVP-minimum-set design) lack a
## Common or a Rare variant. Any OTHER warning code is a regression.
const ALLOWED_WARNING_CODES: Array[StringName] = [
	&"content_primary_group_no_common", &"content_primary_group_no_rare",
]

var _catalog: PartCatalog
var _report: Dictionary
var _spy


func before_all() -> void:
	# Fresh disk parse (not the cached save-time instance) — this is what CI and the
	# dev-boot loader will actually read, and it exercises the real serializer.
	_catalog = ResourceLoader.load(CATALOG_PATH, "PartCatalog", ResourceLoader.CACHE_MODE_REPLACE)
	var balance: BalanceConfig = ResourceLoader.load(BALANCE_PATH, "BalanceConfig", ResourceLoader.CACHE_MODE_REPLACE)

	var catalogs := ContentCatalogs.new()
	catalogs.parts = _catalog
	catalogs.balance = balance                      # mounts the 008 budget family
	catalogs.move_ids = _id_set(SHIPPED_SKILL_IDS)
	catalogs.passive_ids = _id_set(SHIPPED_PASSIVE_IDS)
	catalogs.references_mounted = true              # mounts the 009 referential family

	_spy = SpyLogSink.new()
	_report = ContentValidator.new().validate(catalogs, _spy)


func _id_set(ids: Array[StringName]) -> Dictionary:
	var d := {}
	for id in ids:
		d[id] = true
	return d


# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------

func test_shipped_catalog_and_balance_load_from_disk() -> void:
	assert_not_null(_catalog, "part_catalog.tres loads from disk")
	assert_true(_catalog is PartCatalog, "loaded resource is a PartCatalog")
	assert_eq(_catalog.entries.size(), 14, "the catalog ships all 14 MVP parts")


func test_shipped_content_passes_full_validator() -> void:
	# The blocking assertion: real content, all three validator families active.
	assert_true(_report["ok"], "the shipped catalog validates ok==true under all three families")
	assert_eq((_report["errors"] as Array).size(), 0,
		"the shipped catalog produces zero validator errors: %s" % [_report["errors"]])


func test_only_expected_coverage_warnings_emitted() -> void:
	# Warnings never fail the gate, but an UNEXPECTED warning code is a regression.
	for w in _report["warnings"]:
		assert_true(ALLOWED_WARNING_CODES.has(w["code"]),
			"warning %s is an allowed advisory coverage code" % [w["code"]])


func test_no_errors_routed_through_log_sink() -> void:
	# The report and the injected sink stay in lock-step (ADR-0002 §5 routing).
	assert_eq(_spy.errors.size(), 0, "no diagnostics reached the LogSink error channel")


# ---------------------------------------------------------------------------
# Catalog-completeness — the manifest matches the files on disk
# ---------------------------------------------------------------------------

func test_catalog_entry_count_matches_part_files_on_disk() -> void:
	# Every .tres under parts/ must be in the catalog and vice-versa: no orphan file
	# silently shipped and no manifest entry pointing at a deleted file. DirAccess is
	# used here in a TEST (not the load path, where ADR-0003 forbids it).
	var files := _tres_files(PARTS_DIR)
	assert_eq(files.size(), _catalog.entries.size(),
		"part .tres file count (%d) equals catalog entry count (%d)" % [files.size(), _catalog.entries.size()])


func test_every_catalog_entry_has_a_unique_id() -> void:
	var seen := {}
	for part in _catalog.entries:
		assert_not_null(part, "no null entry in the catalog")
		assert_false(seen.has(part.id), "duplicate catalog id: %s" % [part.id])
		seen[part.id] = true


func _tres_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir_path)
	assert_not_null(da, "parts directory opens: %s" % dir_path)
	for f in da.get_files():
		if f.ends_with(".tres"):
			out.append(f)
	return out


# ---------------------------------------------------------------------------
# Roster structural sanity — the content covers what Story 010 promised
# ---------------------------------------------------------------------------

func test_all_four_rarities_present() -> void:
	var rarities := {}
	for part in _catalog.entries:
		rarities[part.rarity] = true
	for r in [PartDef.Rarity.COMMON, PartDef.Rarity.RARE, PartDef.Rarity.BOSS_GRADE, PartDef.Rarity.PROTOTYPE]:
		assert_true(rarities.has(r), "rarity %d is represented in the shipped set" % r)


func test_all_eight_slots_have_a_starter() -> void:
	var slots := {}
	for part in _catalog.entries:
		if part.rarity == PartDef.Rarity.COMMON:
			slots[part.slot_type] = true
	for s in PartDef.SlotType.values():
		assert_true(slots.has(s), "slot %d has a Common starter part" % s)


func test_part_family_chain_spans_at_least_two_rarities() -> void:
	# TR-part-019 / EC-06: at least one part_family with variants across rarities.
	var families := {}
	for part in _catalog.entries:
		if part.part_family == &"":
			continue
		if not families.has(part.part_family):
			families[part.part_family] = {}
		families[part.part_family][part.rarity] = true
	var found_chain := false
	for fam in families:
		if (families[fam] as Dictionary).size() >= 2:
			found_chain = true
	assert_true(found_chain, "at least one part_family spans >= 2 rarities (a variant chain)")
