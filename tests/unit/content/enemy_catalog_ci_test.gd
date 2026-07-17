## Enemy-DB Story 010 — shipping-content CI gate.
##
## The blocking gate that proves the REAL authored enemy roster — the 10 MVP
## EnemyDefs and the EnemyCatalog manifest — passes the full enemy ContentValidator
## (schema / stat / break-region / progression / density families) with zero errors.
## It loads every resource fresh from disk (CACHE_MODE_REPLACE) so it doubles as the
## on-real-content verification of the typed/untyped `.tres` round-trip the enemy
## schema depends on.
##
## The loot family (Story 007) is INERT until the Part-DB referential seam is
## injected. This gate mounts the seam explicitly — an index built from the shipped
## `part_catalog.tres` — so the loot-connectivity, floor-loot (AC-ED-18), and
## min-break-gated (AC-ED-19) checks run against the real authored parts. A typo in
## any enemy `loot_pool` id, an un-gated Rare/Boss drop, or a region with no matching
## drop fails this gate.
##
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

const ENEMY_CATALOG_PATH := "res://assets/data/catalogs/enemy_catalog.tres"
const PART_CATALOG_PATH := "res://assets/data/catalogs/part_catalog.tres"
const ENEMIES_DIR := "res://assets/data/enemies"

## The only warning codes the shipped roster is allowed to emit. The roster is
## designed to land clean (all TTK bands, pool sizes, and gating satisfied), so this
## set is EMPTY — any warning is a regression to investigate.
const ALLOWED_WARNING_CODES: Array[StringName] = []

var _catalog: EnemyCatalog
var _report: Dictionary
var _spy


func before_all() -> void:
	# Fresh disk parse (not the cached save-time instance) — what CI and the dev-boot
	# loader actually read, exercising the real serializer.
	_catalog = ResourceLoader.load(ENEMY_CATALOG_PATH, "EnemyCatalog", ResourceLoader.CACHE_MODE_REPLACE)
	var part_catalog: PartCatalog = ResourceLoader.load(PART_CATALOG_PATH, "PartCatalog", ResourceLoader.CACHE_MODE_REPLACE)

	var catalogs := ContentCatalogs.new()
	catalogs.enemies = _catalog
	catalogs.parts = PartCatalog.new()  # empty — the Part CI gate validates the parts

	_spy = SpyLogSink.new()
	var validator := ContentValidator.new()
	validator.set_part_lookup(_lookup_from(_part_index(part_catalog)))  # mounts the loot family
	_report = validator.validate(catalogs, _spy)


## A {StringName id: PartDef} index over a loaded PartCatalog.
func _part_index(part_catalog: PartCatalog) -> Dictionary:
	var index := {}
	for part in part_catalog.entries:
		index[part.id] = part
	return index


## A lookup Callable over a {StringName: PartDef} index; null for unknown ids.
func _lookup_from(index: Dictionary) -> Callable:
	return func(id: StringName) -> PartDef: return index.get(id, null)


# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------

func test_shipped_enemy_catalog_loads_from_disk() -> void:
	assert_not_null(_catalog, "enemy_catalog.tres loads from disk")
	assert_true(_catalog is EnemyCatalog, "loaded resource is an EnemyCatalog")
	assert_eq(_catalog.entries.size(), 10, "the catalog ships all 10 MVP enemies")


func test_shipped_roster_passes_full_validator() -> void:
	# The blocking assertion: real content, all enemy families active + loot seam.
	assert_true(_report["ok"], "the shipped roster validates ok==true")
	assert_eq((_report["errors"] as Array).size(), 0,
		"the shipped roster produces zero validator errors: %s" % [_report["errors"]])


func test_no_unexpected_warnings_emitted() -> void:
	var unexpected: Array = []
	for w in _report["warnings"]:
		if not ALLOWED_WARNING_CODES.has(w["code"]):
			unexpected.append(w)
	assert_eq(unexpected.size(), 0,
		"the shipped roster emits no unexpected warnings: %s" % [unexpected])


func test_no_errors_routed_through_log_sink() -> void:
	assert_eq(_spy.errors.size(), 0, "no diagnostics reached the LogSink error channel")


# ---------------------------------------------------------------------------
# Catalog-completeness — the manifest matches the files on disk
# ---------------------------------------------------------------------------

func test_catalog_entry_count_matches_enemy_files_on_disk() -> void:
	var files := _tres_files(ENEMIES_DIR)
	assert_eq(files.size(), _catalog.entries.size(),
		"enemy .tres file count (%d) equals catalog entry count (%d)" % [files.size(), _catalog.entries.size()])


func test_every_catalog_entry_has_a_unique_id() -> void:
	var seen := {}
	for enemy in _catalog.entries:
		assert_not_null(enemy, "no null entry in the catalog")
		assert_false(seen.has(enemy.id), "duplicate catalog id: %s" % [enemy.id])
		seen[enemy.id] = true


func _tres_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir_path)
	assert_not_null(da, "enemies directory opens: %s" % dir_path)
	for f in da.get_files():
		if f.ends_with(".tres"):
			out.append(f)
	return out


# ---------------------------------------------------------------------------
# Roster structural sanity — the content covers what Story 010 promised
# ---------------------------------------------------------------------------

func test_roster_has_eight_wild_and_two_boss() -> void:
	var wild := 0
	var boss := 0
	for enemy in _catalog.entries:
		if enemy.enemy_class == EnemyDef.EnemyClass.WILD:
			wild += 1
		elif enemy.enemy_class == EnemyDef.EnemyClass.BOSS:
			boss += 1
	assert_eq(wild, 8, "roster ships 8 WILD enemies")
	assert_eq(boss, 2, "roster ships 2 BOSS enemies")


func test_roster_covers_all_three_elements_and_null() -> void:
	var elements := {}
	for enemy in _catalog.entries:
		elements[enemy.core_element] = true
	for e in [PartDef.Element.VOLT, PartDef.Element.THERMAL, PartDef.Element.KINETIC]:
		assert_true(elements.has(e), "element %d is represented in the roster" % e)
	# PartDef.Element has no 0 member; the null-element is the raw int 0 (the enemy_def
	# default sentinel, a legal authored state), so check for it directly.
	assert_true(elements.has(0), "roster includes a null-element enemy")
