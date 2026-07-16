## Passive-DB Story 002 — PassiveDB loader / index / read-only getter contract.
##
## Covers the Story 002 ACs:
##   AC-PDB-01 / EC-PDB-01: get_passive null contract — a valid id returns the def;
##         an unknown id and the null-equivalent &"" both return null with no crash.
##         has_passive mirrors index membership; a known id returns the exact SHARED
##         instance (identity, not a copy).
##   Fatal on null entry / duplicate id (spy LogSink records the code + detail);
##         a clean catalog returns true and logs nothing.
##
## The loader is exercised via DI (load_catalog takes catalog + LogSink params) —
## no autoload coupling. No DirAccess in the load path (static grep). Mirrors the
## proven Move-DB / Part-DB loader tests. Framework: GUT · Godot 4.7.
extends GutTest

const PassiveDBScript := preload("res://src/core/content/passive_db.gd")
const SpyLogSink := preload("res://tests/unit/passive_database/spy_log_sink.gd")

const PASSIVE_DB_SOURCE := "res://src/core/content/passive_db.gd"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Build a PassiveDef with just enough shape for loader tests.
func _make_passive(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = String(id).capitalize()
	pd.trigger_category = PassiveDef.TriggerCategory.ON_HIT
	pd.behavior_class   = PassiveDef.BehaviorClass.STATUS_RIDER
	pd.scope            = PassiveDef.Scope.ANY_DAMAGE
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER
	pd.passive_class    = PassiveDef.PassiveClass.STATUS_RIDER
	pd.behavior_params  = {"status_id": &"shock", "duration": 1}
	return pd


func _catalog(entries: Array[PassiveDef]) -> PassiveCatalog:
	var cat := PassiveCatalog.new()
	for e in entries:
		cat.entries.append(e)
	return cat


func _loaded_db(entries: Array[PassiveDef], spy) -> Node:
	var db: Node = PassiveDBScript.new()
	db.load_catalog(_catalog(entries), spy)
	return db


# ---------------------------------------------------------------------------
# AC-PDB-01: get_passive null contract
# ---------------------------------------------------------------------------

func test_passive_db_get_passive_returns_def_for_valid_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_passive(&"volt_shock_on_hit")], spy)

	# Act
	var got: PassiveDef = db.get_passive(&"volt_shock_on_hit")

	# Assert
	assert_not_null(got, "valid id returns a PassiveDef")
	assert_eq(got.id, &"volt_shock_on_hit", "returned def has the requested id")


func test_passive_db_get_passive_returns_null_for_unknown_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_passive(&"volt_shock_on_hit")], spy)

	# Act / Assert — an unknown id and the project's null-equivalent &"" both return
	# null with no crash (AC-PDB-01 / EC-PDB-01). A literal `null` argument is
	# statically rejected at the `id: StringName` boundary; callers pass &"" for
	# "no passive", so the &"" path satisfies the null contract.
	assert_null(db.get_passive(&"nonexistent_passive_xyz"), "unknown id returns null")
	assert_null(db.get_passive(&""), "empty id (null-equivalent) returns null")


func test_passive_db_get_passive_on_empty_catalog_returns_null() -> void:
	# Arrange — a DB loaded from an empty catalog has no entries.
	var spy := SpyLogSink.new()
	var db := _loaded_db([], spy)

	# Assert — any lookup misses cleanly, no crash.
	assert_null(db.get_passive(&"anything"), "empty DB returns null for any id")
	assert_false(db.has_passive(&"anything"), "empty DB has no ids")


func test_passive_db_has_passive_matches_index_membership() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_passive(&"volt_shock_on_hit")], spy)

	# Assert
	assert_true(db.has_passive(&"volt_shock_on_hit"), "present id → true")
	assert_false(db.has_passive(&"nope"), "absent id → false")


func test_passive_db_lookup_returns_same_shared_instance() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_passive(&"shared")], spy)

	# Act
	var a: PassiveDef = db.get_passive(&"shared")
	var b: PassiveDef = db.get_passive(&"shared")

	# Assert — same object identity, proving no defensive copy on lookup.
	assert_true(a == b, "lookups return the same shared def instance")


func test_passive_db_returned_def_snapshot_stable_across_reads() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_passive(&"stable")], spy)

	# Act — snapshot a field, do more reads, snapshot again.
	var got: PassiveDef = db.get_passive(&"stable")
	var before: int = int(got.trigger_category)
	var _again: PassiveDef = db.get_passive(&"stable")
	var after: int = int(got.trigger_category)

	# Assert
	assert_eq(before, after, "def field is stable across lookups (read-only, shared)")


# ---------------------------------------------------------------------------
# Fatal on null entry / duplicate id
# ---------------------------------------------------------------------------

func test_passive_db_valid_catalog_loads_true_no_errors() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = PassiveDBScript.new()

	# Act
	var ok: bool = db.load_catalog(
		_catalog([_make_passive(&"a"), _make_passive(&"b")]), spy)

	# Assert
	assert_true(ok, "clean catalog returns true")
	assert_eq(spy.total(), 0, "clean catalog logs nothing")


func test_passive_db_duplicate_id_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = PassiveDBScript.new()

	# Act — two entries share an id.
	var ok: bool = db.load_catalog(
		_catalog([_make_passive(&"dup"), _make_passive(&"dup")]), spy)

	# Assert
	assert_false(ok, "duplicate id returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_duplicate_id", "logs content_duplicate_id")
	assert_eq(spy.errors[0]["detail"]["id"], &"dup", "error detail carries the offending id")
	assert_eq(spy.errors[0]["detail"]["db"], &"passive", "error detail names the passive DB")


func test_passive_db_null_entry_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = PassiveDBScript.new()
	var cat := PassiveCatalog.new()
	cat.entries.append(_make_passive(&"a"))
	cat.entries.append(null)  # stale/deleted authored slot

	# Act
	var ok: bool = db.load_catalog(cat, spy)

	# Assert
	assert_false(ok, "null entry returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_null_entry", "logs content_null_entry")
	assert_eq(spy.errors[0]["detail"]["db"], &"passive", "error detail names the passive DB")


# ---------------------------------------------------------------------------
# No DirAccess in the content load path (static grep)
# ---------------------------------------------------------------------------

func test_passive_db_source_has_no_dir_access() -> void:
	# Arrange — read the loader source, strip comment lines (the doc comment
	# legitimately NAMES DirAccess), assert against actual CODE only.
	var src := FileAccess.get_file_as_string(PASSIVE_DB_SOURCE)
	var code_lines: PackedStringArray = []
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	var code := "\n".join(code_lines)

	# Assert
	assert_ne(src, "", "loader source is readable")
	assert_false(code.contains("DirAccess"),
		"content load path must never use DirAccess (content_directory_scanning forbidden)")
