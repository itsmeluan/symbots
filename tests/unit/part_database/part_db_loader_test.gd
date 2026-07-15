## Part-DB Story 003 — PartDB loader / index / read-only getter contract.
##
## Covers QA test cases AC-1 through AC-5:
##   AC-1: get_part null contract (valid id → def; unknown/""/null → null, no crash)
##   AC-2: fatal on duplicate id / null entry; valid catalog → true, no error logged
##   AC-3: drop_enabled=false part still returned in full (TR-part-018 / EC-04)
##   AC-4: def immutability; duplicate() is NOT a safe copy (shares nested refs)
##   AC-5: no DirAccess anywhere in the content load path (static source grep)
##
## The loader is exercised via DI (load_catalog takes catalog + LogSink params) —
## no autoload coupling. Framework: GUT · Godot 4.7.
extends GutTest

const PartDBScript := preload("res://src/core/content/part_db.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

const PART_DB_SOURCE := "res://src/core/content/part_db.gd"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Build a PartDef with just enough shape for loader tests.
func _make_part(id: StringName, drop_enabled: bool = true) -> PartDef:
	var pd := PartDef.new()
	pd.id = id
	pd.display_name = String(id).capitalize()
	pd.slot_type = PartDef.SlotType.CORE
	pd.rarity = PartDef.Rarity.COMMON
	pd.drop_enabled = drop_enabled
	pd.stat_bonuses = {&"structure": 10, &"armor": 4}
	pd.synergy_tags = [&"volt"]
	return pd


func _catalog(entries: Array[PartDef]) -> PartCatalog:
	var cat := PartCatalog.new()
	for e in entries:
		cat.entries.append(e)
	return cat


func _loaded_db(entries: Array[PartDef], spy) -> Node:
	var db: Node = PartDBScript.new()
	db.load_catalog(_catalog(entries), spy)
	return db


# ---------------------------------------------------------------------------
# AC-1: get_part null contract
# ---------------------------------------------------------------------------

func test_part_db_get_part_returns_def_for_valid_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_part(&"boltwell_spark_core")], spy)

	# Act
	var got: PartDef = db.get_part(&"boltwell_spark_core")

	# Assert
	assert_not_null(got, "valid id returns a PartDef")
	assert_eq(got.id, &"boltwell_spark_core", "returned def has the requested id")


func test_part_db_get_part_returns_null_for_unknown_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_part(&"boltwell_spark_core")], spy)

	# Act / Assert — unknown, empty, and null argument all return null, no crash.
	assert_null(db.get_part(&"nonexistent_id_xyz"), "unknown id returns null")
	assert_null(db.get_part(&""), "empty id returns null")
	var nothing: Variant = null
	assert_null(db.get_part(nothing), "null argument returns null (no crash)")


func test_part_db_has_part_matches_index_membership() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_part(&"boltwell_spark_core")], spy)

	# Assert
	assert_true(db.has_part(&"boltwell_spark_core"), "present id → true")
	assert_false(db.has_part(&"nope"), "absent id → false")


# ---------------------------------------------------------------------------
# AC-2: fatal on duplicate id / null entry
# ---------------------------------------------------------------------------

func test_part_db_valid_catalog_loads_true_no_errors() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = PartDBScript.new()

	# Act
	var ok: bool = db.load_catalog(
		_catalog([_make_part(&"a"), _make_part(&"b")]), spy)

	# Assert
	assert_true(ok, "clean catalog returns true")
	assert_eq(spy.total(), 0, "clean catalog logs nothing")


func test_part_db_duplicate_id_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = PartDBScript.new()

	# Act — two entries share an id.
	var ok: bool = db.load_catalog(
		_catalog([_make_part(&"dup"), _make_part(&"dup")]), spy)

	# Assert
	assert_false(ok, "duplicate id returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_duplicate_id", "logs content_duplicate_id")
	assert_eq(spy.errors[0]["detail"]["id"], &"dup", "error detail carries the offending id")


func test_part_db_null_entry_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = PartDBScript.new()
	var cat := PartCatalog.new()
	cat.entries.append(_make_part(&"a"))
	cat.entries.append(null)  # stale/deleted authored slot

	# Act
	var ok: bool = db.load_catalog(cat, spy)

	# Assert
	assert_false(ok, "null entry returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_null_entry", "logs content_null_entry")


# ---------------------------------------------------------------------------
# AC-3: drop_enabled = false part remains valid (TR-part-018 / EC-04)
# ---------------------------------------------------------------------------

func test_part_db_disabled_part_still_returned_in_full() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_part(&"retired_part", false)], spy)

	# Act
	var got: PartDef = db.get_part(&"retired_part")

	# Assert — not deleted; fully readable; drop_enabled reads false.
	assert_not_null(got, "disabled part is still indexed and returned")
	assert_false(got.drop_enabled, "drop_enabled reads false")
	assert_eq(got.stat_bonuses[&"structure"], 10, "full def data intact")


# ---------------------------------------------------------------------------
# AC-4: def immutability; duplicate() is NOT a safe copy
# ---------------------------------------------------------------------------

func test_part_db_returned_def_snapshot_stable_across_reads() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_part(&"stable")], spy)

	# Act — snapshot a field, do more reads, snapshot again.
	var got: PartDef = db.get_part(&"stable")
	var before: int = got.stat_bonuses[&"structure"]
	var _again: PartDef = db.get_part(&"stable")
	var after: int = got.stat_bonuses[&"structure"]

	# Assert
	assert_eq(before, after, "def field is stable across lookups (read-only, shared)")


func test_part_db_lookup_returns_same_shared_instance() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_part(&"shared")], spy)

	# Act
	var a: PartDef = db.get_part(&"shared")
	var b: PartDef = db.get_part(&"shared")

	# Assert — same object identity, proving no defensive copy on lookup.
	assert_true(a == b, "lookups return the same shared def instance")


func test_part_db_duplicate_is_not_a_safe_copy() -> void:
	# Arrange — a def with a nested Dictionary.
	var def := _make_part(&"trap")

	# Act — duplicate() (shallow) then mutate the copy's nested Dictionary.
	var dup: PartDef = def.duplicate()
	dup.stat_bonuses[&"injected"] = 999

	# Assert — the mutation leaks back into the original, proving duplicate() is
	# NOT a safe working copy (the runtime_content_mutation ban is load-bearing).
	assert_true(def.stat_bonuses.has(&"injected"),
		"duplicate() shares the nested Dictionary — mutation leaked to the original")


# ---------------------------------------------------------------------------
# AC-5: no DirAccess in the content load path (static grep)
# ---------------------------------------------------------------------------

func test_part_db_source_has_no_dir_access() -> void:
	# Arrange — read the loader source directly.
	var src := FileAccess.get_file_as_string(PART_DB_SOURCE)

	# Assert
	assert_ne(src, "", "loader source is readable")
	assert_false(src.contains("DirAccess"),
		"content load path must never use DirAccess (content_directory_scanning forbidden)")
