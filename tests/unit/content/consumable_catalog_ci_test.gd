## Consumable-DB Story 008 — shipping-content CI gate.
##
## The blocking gate that proves the REAL authored content — the 8 MVP ConsumableDefs
## and the ConsumableCatalog manifest — passes the full ContentValidator consumable
## family (schema/params/economy/coherence/coverage, Story 007) with `ok == true`,
## zero errors, AND zero warnings (the designed roster is coherent and covers every
## effect family). Loads every resource fresh from disk (CACHE_MODE_REPLACE) so it
## doubles as the on-real-content verification of the typed/untyped `.tres` round-trip.
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/passive_database/spy_log_sink.gd")

const CATALOG_PATH := "res://assets/data/catalogs/consumable_catalog.tres"
const CONSUMABLES_DIR := "res://assets/data/consumables"

var _catalog: ConsumableCatalog
var _report: Dictionary
var _spy


func before_all() -> void:
	# Fresh disk parse (not the cached save-time instance) — what CI and the dev-boot
	# loader actually read, exercising the real serializer.
	_catalog = ResourceLoader.load(CATALOG_PATH, "ConsumableCatalog", ResourceLoader.CACHE_MODE_REPLACE)

	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty but present — the validator always checks Parts
	catalogs.consumables = _catalog

	_spy = SpyLogSink.new()
	_report = ContentValidator.new().validate(catalogs, _spy)


# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------

func test_shipped_catalog_loads_from_disk() -> void:
	assert_not_null(_catalog, "consumable_catalog.tres loads from disk")
	assert_true(_catalog is ConsumableCatalog, "loaded resource is a ConsumableCatalog")
	assert_eq(_catalog.entries.size(), 8, "the catalog ships all 8 MVP consumables")


func test_shipped_content_passes_validator_clean() -> void:
	# The blocking assertion: real content, zero errors AND zero warnings.
	assert_true(_report["ok"], "the shipped catalog validates ok==true")
	assert_eq((_report["errors"] as Array).size(), 0,
		"the shipped catalog produces zero validator errors: %s" % [_report["errors"]])
	assert_eq((_report["warnings"] as Array).size(), 0,
		"the designed roster is coherent + covers every family — zero warnings: %s" % [_report["warnings"]])


func test_no_diagnostics_routed_through_log_sink() -> void:
	assert_eq(_spy.errors.size(), 0, "no diagnostics reached the LogSink error channel")
	assert_eq(_spy.warns.size(), 0, "no diagnostics reached the LogSink warn channel")


# ---------------------------------------------------------------------------
# Catalog-completeness — the manifest matches the files on disk
# ---------------------------------------------------------------------------

func test_catalog_entry_count_matches_files_on_disk() -> void:
	# Every .tres under consumables/ must be in the catalog and vice-versa: no orphan
	# file shipped, no manifest entry pointing at a deleted file. DirAccess is used
	# here in a TEST only (ADR-0003 forbids it on the load path).
	var files := _tres_files(CONSUMABLES_DIR)
	assert_eq(files.size(), _catalog.entries.size(),
		"consumable .tres file count (%d) equals catalog entry count (%d)" % [files.size(), _catalog.entries.size()])


func test_every_catalog_entry_has_a_unique_id() -> void:
	var seen := {}
	for c in _catalog.entries:
		assert_not_null(c, "no null entry in the catalog")
		assert_false(seen.has(c.consumable_id), "duplicate catalog id: %s" % [c.consumable_id])
		seen[c.consumable_id] = true


func _tres_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir_path)
	assert_not_null(da, "consumables directory opens: %s" % dir_path)
	for f in da.get_files():
		if f.ends_with(".tres"):
			out.append(f)
	return out


# ---------------------------------------------------------------------------
# Roster structural sanity — the content covers what Story 008 promised
# ---------------------------------------------------------------------------

func test_all_five_effect_families_present() -> void:
	var families := {}
	for c in _catalog.entries:
		families[c.effect_type] = true
	for e in ConsumableDef.EffectType.values():
		assert_true(families.has(e), "effect family %d is represented in the shipped set" % e)


func test_rarity_spread_includes_common_rare_prototype() -> void:
	var rarities := {}
	for c in _catalog.entries:
		rarities[c.rarity] = true
	for r in [ConsumableDef.Rarity.COMMON, ConsumableDef.Rarity.RARE, ConsumableDef.Rarity.PROTOTYPE]:
		assert_true(rarities.has(r), "rarity %d is represented in the shipped set" % r)


func test_every_consumable_has_strict_positive_margin() -> void:
	# The economy invariant, re-asserted on the real content: buy strictly above sell.
	for c in _catalog.entries:
		assert_gt(c.buy_price, c.sell_price, "%s: buy must exceed sell" % [c.consumable_id])
		assert_true(c.sell_price >= 0, "%s: sell price non-negative" % [c.consumable_id])
