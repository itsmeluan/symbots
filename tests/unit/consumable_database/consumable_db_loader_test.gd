## Consumable-DB Story 002 — ConsumableDB loader / index / read-only getter contract.
##
## Covers the Story 002 ACs:
##   AC-1: index + lookup — a valid id returns the def; an unknown id and the
##         null-equivalent &"" both return null with no crash.
##   AC-2: null-safe empty load — a null or empty catalog yields an empty index and
##         lookups return null, not a crash.
##   AC-3: shared-instance integrity — a fetched def is the exact same instance as the
##         catalog entry (identity, not a copy); the DB exposes no mutation path.
##   Fatal on null entry / duplicate id (spy LogSink records the code + detail).
##
## The loader is exercised via DI (load_catalog takes catalog + LogSink params) — no
## autoload coupling. Mirrors the proven Passive-DB loader test. GUT · Godot 4.7.
extends GutTest

const ConsumableDBScript := preload("res://src/core/content/consumable_db.gd")
const SpyLogSink := preload("res://tests/unit/consumable_database/spy_log_sink.gd")

var _spy


func before_each() -> void:
	_spy = SpyLogSink.new()


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _make(id: StringName) -> ConsumableDef:
	var cd := ConsumableDef.new()
	cd.consumable_id = id
	cd.display_name = String(id).capitalize()
	cd.rarity = ConsumableDef.Rarity.COMMON
	cd.effect_type = ConsumableDef.EffectType.RESTORE_STRUCTURE
	cd.effect_params = {"amount": 25}
	cd.use_context = ConsumableDef.UseContext.BOTH
	cd.target = ConsumableDef.Target.LIVING_TEAM_MEMBER
	return cd

func _catalog(entries: Array[ConsumableDef]) -> ConsumableCatalog:
	var cat := ConsumableCatalog.new()
	cat.entries = entries
	return cat

func _loaded_db(entries: Array[ConsumableDef]):
	var db = ConsumableDBScript.new()
	db.load_catalog(_catalog(entries), _spy)
	return db


# ---------------------------------------------------------------------------
# AC-1 — index + lookup
# ---------------------------------------------------------------------------

func test_lookup_returns_matching_def() -> void:
	var db = _loaded_db([_make(&"weld_patch"), _make(&"repair_kit"), _make(&"coolant_flush")])
	assert_eq(db.get_consumable(&"repair_kit").consumable_id, &"repair_kit")
	db.free()

func test_unknown_id_returns_null() -> void:
	var db = _loaded_db([_make(&"weld_patch")])
	assert_null(db.get_consumable(&"does_not_exist"), "unknown id -> null")
	assert_null(db.get_consumable(&""), "&\"\" -> null")
	assert_false(db.has_consumable(&"does_not_exist"))
	db.free()

func test_clean_load_returns_true_and_logs_nothing() -> void:
	var db = ConsumableDBScript.new()
	var ok: bool = db.load_catalog(_catalog([_make(&"weld_patch"), _make(&"power_cell")]), _spy)
	assert_true(ok, "clean catalog -> true")
	assert_eq(_spy.total(), 0, "clean load logs nothing")
	db.free()


# ---------------------------------------------------------------------------
# AC-2 — null-safe empty load
# ---------------------------------------------------------------------------

func test_null_catalog_is_null_safe() -> void:
	var db = ConsumableDBScript.new()
	var ok: bool = db.load_catalog(null, _spy)
	assert_true(ok, "null catalog is a null-safe no-op, not a fatal")
	assert_null(db.get_consumable(&"anything"), "empty index -> null lookup")
	assert_eq(_spy.errors.size(), 0, "null catalog is not a loader error")
	db.free()

func test_empty_catalog_is_null_safe() -> void:
	var empty: Array[ConsumableDef] = []
	var db = _loaded_db(empty)
	assert_null(db.get_consumable(&"anything"))
	assert_eq(_spy.total(), 0)
	db.free()


# ---------------------------------------------------------------------------
# AC-3 — shared-instance integrity
# ---------------------------------------------------------------------------

func test_fetched_def_is_same_instance_as_catalog_entry() -> void:
	var original := _make(&"power_cell")
	var db = _loaded_db([original])
	assert_same(db.get_consumable(&"power_cell"), original, "returns the SHARED instance, not a copy")
	db.free()


# ---------------------------------------------------------------------------
# Fatal cases — null entry / duplicate id
# ---------------------------------------------------------------------------

func test_null_entry_is_fatal() -> void:
	var db = ConsumableDBScript.new()
	var entries: Array[ConsumableDef] = [_make(&"weld_patch"), null]
	var ok: bool = db.load_catalog(_catalog(entries), _spy)
	assert_false(ok, "a null catalog slot is fatal")
	assert_eq(_spy.errors[0]["code"], &"content_null_entry")
	assert_eq(_spy.errors[0]["detail"]["db"], &"consumable")
	db.free()

func test_duplicate_id_is_fatal_and_names_id() -> void:
	var db = ConsumableDBScript.new()
	var ok: bool = db.load_catalog(_catalog([_make(&"weld_patch"), _make(&"weld_patch")]), _spy)
	assert_false(ok, "duplicate id within a catalog is fatal")
	assert_eq(_spy.errors[0]["code"], &"content_duplicate_id")
	assert_eq(_spy.errors[0]["detail"]["id"], &"weld_patch")
	db.free()
