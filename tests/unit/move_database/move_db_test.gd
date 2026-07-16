## Move-DB Story 002 — MoveDB loader / index / read-only getter contract.
##
## Covers QA test cases AC-1 and AC-2:
##   AC-1 (AC-MDB-01): get_move null contract (valid id → def; unknown/"" → null,
##         no crash); has_move mirrors index membership; a known id returns the
##         exact shared instance (identity, not a copy).
##   AC-2: fatal on null entry / duplicate id (spy LogSink records the code);
##         a clean catalog returns true and logs nothing.
##
## The loader is exercised via DI (load_catalog takes catalog + LogSink params) —
## no autoload coupling. No DirAccess in the load path (static grep). Mirrors the
## proven PartDB loader test. Framework: GUT · Godot 4.7.
extends GutTest

const MoveDBScript := preload("res://src/core/content/move_db.gd")
const SpyLogSink := preload("res://tests/unit/move_database/spy_log_sink.gd")

const MOVE_DB_SOURCE := "res://src/core/content/move_db.gd"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Build a MoveDef with just enough shape for loader tests.
func _make_move(id: StringName) -> MoveDef:
	var md := MoveDef.new()
	md.id = id
	md.display_name = String(id).capitalize()
	md.behavior = MoveDef.Behavior.DAMAGE
	md.power_tier = MoveDef.PowerTier.STANDARD
	md.damage_type = PartDef.DamageType.ENERGY
	md.element = PartDef.Element.VOLT
	md.energy_cost = 14
	md.targeting = MoveDef.Targeting.ENEMY
	return md


func _catalog(entries: Array[MoveDef]) -> MoveCatalog:
	var cat := MoveCatalog.new()
	for e in entries:
		cat.entries.append(e)
	return cat


func _loaded_db(entries: Array[MoveDef], spy) -> Node:
	var db: Node = MoveDBScript.new()
	db.load_catalog(_catalog(entries), spy)
	return db


# ---------------------------------------------------------------------------
# AC-1: get_move null contract
# ---------------------------------------------------------------------------

func test_move_db_get_move_returns_def_for_valid_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_move(&"boltwell_arc_bolt")], spy)

	# Act
	var got: MoveDef = db.get_move(&"boltwell_arc_bolt")

	# Assert
	assert_not_null(got, "valid id returns a MoveDef")
	assert_eq(got.id, &"boltwell_arc_bolt", "returned def has the requested id")


func test_move_db_get_move_returns_null_for_unknown_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_move(&"boltwell_arc_bolt")], spy)

	# Act / Assert — an unknown id and the project's null-equivalent &"" both
	# return null with no crash. Per the Story 003 (Part-DB) 4.7 finding, a literal
	# `null` argument is statically rejected at the `id: StringName` call boundary;
	# callers pass &"" for "no move", so the &"" path satisfies the null contract.
	assert_null(db.get_move(&"nonexistent_move_xyz"), "unknown id returns null")
	assert_null(db.get_move(&""), "empty id (null-equivalent) returns null")


func test_move_db_has_move_matches_index_membership() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_move(&"boltwell_arc_bolt")], spy)

	# Assert
	assert_true(db.has_move(&"boltwell_arc_bolt"), "present id → true")
	assert_false(db.has_move(&"nope"), "absent id → false")


func test_move_db_lookup_returns_same_shared_instance() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_move(&"shared")], spy)

	# Act
	var a: MoveDef = db.get_move(&"shared")
	var b: MoveDef = db.get_move(&"shared")

	# Assert — same object identity, proving no defensive copy on lookup.
	assert_true(a == b, "lookups return the same shared def instance")


# ---------------------------------------------------------------------------
# AC-2: fatal on null entry / duplicate id
# ---------------------------------------------------------------------------

func test_move_db_valid_catalog_loads_true_no_errors() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = MoveDBScript.new()

	# Act
	var ok: bool = db.load_catalog(
		_catalog([_make_move(&"a"), _make_move(&"b")]), spy)

	# Assert
	assert_true(ok, "clean catalog returns true")
	assert_eq(spy.total(), 0, "clean catalog logs nothing")


func test_move_db_duplicate_id_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = MoveDBScript.new()

	# Act — two entries share an id.
	var ok: bool = db.load_catalog(
		_catalog([_make_move(&"dup"), _make_move(&"dup")]), spy)

	# Assert
	assert_false(ok, "duplicate id returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_duplicate_id", "logs content_duplicate_id")
	assert_eq(spy.errors[0]["detail"]["id"], &"dup", "error detail carries the offending id")
	assert_eq(spy.errors[0]["detail"]["db"], &"move", "error detail names the move DB")


func test_move_db_null_entry_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = MoveDBScript.new()
	var cat := MoveCatalog.new()
	cat.entries.append(_make_move(&"a"))
	cat.entries.append(null)  # stale/deleted authored slot

	# Act
	var ok: bool = db.load_catalog(cat, spy)

	# Assert
	assert_false(ok, "null entry returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_null_entry", "logs content_null_entry")
	assert_eq(spy.errors[0]["detail"]["db"], &"move", "error detail names the move DB")


# ---------------------------------------------------------------------------
# Read-only contract — lookups return the same shared instance, not a copy
# ---------------------------------------------------------------------------

func test_move_db_returned_def_snapshot_stable_across_reads() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_move(&"stable")], spy)

	# Act — snapshot a field, do more reads, snapshot again.
	var got: MoveDef = db.get_move(&"stable")
	var before: int = got.energy_cost
	var _again: MoveDef = db.get_move(&"stable")
	var after: int = got.energy_cost

	# Assert
	assert_eq(before, after, "def field is stable across lookups (read-only, shared)")


# ---------------------------------------------------------------------------
# No DirAccess in the content load path (static grep)
# ---------------------------------------------------------------------------

func test_move_db_source_has_no_dir_access() -> void:
	# Arrange — read the loader source, then strip comment lines. The doc comment
	# legitimately NAMES DirAccess ("No DirAccess anywhere in the load path"), so a
	# raw substring check would false-positive on the very comment documenting the
	# ban. We assert against actual CODE only.
	var src := FileAccess.get_file_as_string(MOVE_DB_SOURCE)
	var code_lines: PackedStringArray = []
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	var code := "\n".join(code_lines)

	# Assert
	assert_ne(src, "", "loader source is readable")
	assert_false(code.contains("DirAccess"),
		"content load path must never use DirAccess (content_directory_scanning forbidden)")
