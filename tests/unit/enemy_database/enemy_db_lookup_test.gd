## Enemy-DB Story 002 — EnemyDB loader / index / read-only getter contract.
##
## Covers every acceptance criterion from Story 002 (AC-ED-10):
##   AC-1 (known lookup): get_enemy resolves an authored id; two distinct ids
##         both resolve independently; a known id returns the exact SHARED
##         instance (identity, not a copy).
##   AC-2 (null-safe unknowns): get_enemy returns null for unknown id, &"", and
##         the null-equivalent — no crash, no diagnostic, no push_error.
##   AC-3 (DI-constructed): DB is built from an in-memory EnemyCatalog with no
##         file I/O; lookups succeed from that fixture catalog.
##   Fatal on null entry / duplicate id (spy LogSink records code + detail).
##
## The loader is exercised via DI (load_catalog takes catalog + LogSink params)
## — no autoload coupling. No DirAccess in the load path (static grep).
## Mirrors the proven Move-DB / Passive-DB / Part-DB loader tests.
## Framework: GUT · Godot 4.7.
extends GutTest

const EnemyDBScript := preload("res://src/core/content/enemy_db.gd")
const SpyLogSink := preload("res://tests/unit/enemy_database/spy_log_sink.gd")

const ENEMY_DB_SOURCE := "res://src/core/content/enemy_db.gd"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Build an EnemyDef with just enough shape for loader tests.
func _make_enemy(id: StringName) -> EnemyDef:
	var def := EnemyDef.new()
	def.id = id
	def.display_name = String(id).capitalize()
	def.enemy_class = EnemyDef.EnemyClass.WILD
	def.tier = 1
	def.level = 1
	def.xp_value = 45
	def.stats = {
		"structure": 60, "armor": 10, "resistance": 5,
		"physical_power": 20, "energy_power": 0,
		"mobility": 15, "processing": 10,
		"cooling": 0, "energy_capacity": 0, "recharge": 0, "output_power": 0,
	}
	def.skills = [&"basic_attack"]
	return def


func _catalog(entries: Array[EnemyDef]) -> EnemyCatalog:
	var cat := EnemyCatalog.new()
	for e in entries:
		cat.entries.append(e)
	return cat


func _loaded_db(entries: Array[EnemyDef], spy) -> Node:
	var db: Node = EnemyDBScript.new()
	db.load_catalog(_catalog(entries), spy)
	return db


# ---------------------------------------------------------------------------
# AC-1: known lookup — get_enemy resolves a valid id
# ---------------------------------------------------------------------------

func test_enemy_db_get_enemy_returns_def_for_valid_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"wild_rustling")], spy)

	# Act
	var got: EnemyDef = db.get_enemy(&"wild_rustling")

	# Assert
	assert_not_null(got, "valid id returns an EnemyDef")
	assert_eq(got.id, &"wild_rustling", "returned def has the requested id")


func test_enemy_db_two_distinct_ids_both_resolve_independently() -> void:
	# Arrange — catalog with two entries; both must be reachable.
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"wild_rustling"), _make_enemy(&"slag_drone")], spy)

	# Act
	var got_a: EnemyDef = db.get_enemy(&"wild_rustling")
	var got_b: EnemyDef = db.get_enemy(&"slag_drone")

	# Assert — each lookup returns the correct def, not the other.
	assert_not_null(got_a, "first id resolves")
	assert_not_null(got_b, "second id resolves")
	assert_eq(got_a.id, &"wild_rustling", "first def has correct id")
	assert_eq(got_b.id, &"slag_drone", "second def has correct id")
	assert_true(got_a != got_b, "two distinct ids return two distinct defs")


func test_enemy_db_lookup_returns_same_shared_instance() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"shared")], spy)

	# Act
	var a: EnemyDef = db.get_enemy(&"shared")
	var b: EnemyDef = db.get_enemy(&"shared")

	# Assert — same object identity, proving no defensive copy on lookup.
	assert_true(a == b, "lookups return the same shared def instance")


# ---------------------------------------------------------------------------
# AC-2: null-safe unknowns — no crash, no diagnostic
# ---------------------------------------------------------------------------

func test_enemy_db_get_enemy_returns_null_for_unknown_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"wild_rustling")], spy)

	# Act / Assert — an unknown id returns null with no crash.
	assert_null(db.get_enemy(&"does_not_exist"), "unknown id returns null")


func test_enemy_db_get_enemy_returns_null_for_empty_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"wild_rustling")], spy)

	# Act / Assert — &"" is the project's null-equivalent StringName; returns null,
	# no crash. A literal `null` argument is statically rejected at the StringName
	# call boundary, so &"" is the correct "no id" sentinel path.
	assert_null(db.get_enemy(&""), "empty id (null-equivalent) returns null")


func test_enemy_db_unknown_lookup_emits_no_diagnostic() -> void:
	# Arrange — spy starts clean; we call with an unknown id.
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"wild_rustling")], spy)

	# Act
	var _result: EnemyDef = db.get_enemy(&"does_not_exist")

	# Assert — no error, no warn, no info must be emitted by a miss.
	# (spy was only fed during load_catalog; misses are pure null returns.)
	assert_eq(spy.total(), 0, "unknown id lookup emits no diagnostic")


func test_enemy_db_empty_catalog_returns_null_for_any_id() -> void:
	# Arrange — a DB loaded from an empty catalog has no entries.
	var spy := SpyLogSink.new()
	var db := _loaded_db([], spy)

	# Assert — any lookup misses cleanly, no crash.
	assert_null(db.get_enemy(&"anything"), "empty DB returns null for any id")
	assert_false(db.has_enemy(&"anything"), "empty DB has no ids")


# ---------------------------------------------------------------------------
# AC-3: DI-constructed — no file I/O
# ---------------------------------------------------------------------------

func test_enemy_db_built_from_in_memory_catalog_lookups_succeed() -> void:
	# Arrange — construct catalog entirely in memory; no disk access.
	var spy := SpyLogSink.new()
	var db: Node = EnemyDBScript.new()
	var cat := EnemyCatalog.new()
	cat.entries.append(_make_enemy(&"bolt_creeper"))

	# Act
	var ok: bool = db.load_catalog(cat, spy)
	var got: EnemyDef = db.get_enemy(&"bolt_creeper")

	# Assert
	assert_true(ok, "in-memory catalog loads successfully")
	assert_not_null(got, "in-memory lookup returns the def")
	assert_eq(got.id, &"bolt_creeper", "in-memory def has the correct id")
	assert_eq(spy.total(), 0, "in-memory load emits no diagnostics")


# ---------------------------------------------------------------------------
# has_enemy: mirrors index membership
# ---------------------------------------------------------------------------

func test_enemy_db_has_enemy_returns_true_for_present_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"wild_rustling")], spy)

	# Assert
	assert_true(db.has_enemy(&"wild_rustling"), "present id → true")


func test_enemy_db_has_enemy_returns_false_for_absent_id() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"wild_rustling")], spy)

	# Assert
	assert_false(db.has_enemy(&"nope"), "absent id → false")
	assert_false(db.has_enemy(&""), "empty id → false")


# ---------------------------------------------------------------------------
# all_enemies: snapshot of index values
# ---------------------------------------------------------------------------

func test_enemy_db_all_enemies_returns_all_loaded_defs() -> void:
	# Arrange — two entries.
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"a"), _make_enemy(&"b")], spy)

	# Act
	var all: Array[EnemyDef] = db.all_enemies()

	# Assert — both defs present (order not guaranteed).
	assert_eq(all.size(), 2, "all_enemies returns exactly 2 defs")
	var ids: Array[StringName] = []
	for d in all:
		ids.append(d.id)
	assert_true(ids.has(&"a"), "def 'a' is in all_enemies")
	assert_true(ids.has(&"b"), "def 'b' is in all_enemies")


func test_enemy_db_all_enemies_returns_empty_array_for_empty_catalog() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([], spy)

	# Assert
	assert_eq(db.all_enemies().size(), 0, "empty catalog → empty all_enemies array")


# ---------------------------------------------------------------------------
# Load return values: clean catalog vs. fatal conditions
# ---------------------------------------------------------------------------

func test_enemy_db_valid_catalog_loads_true_no_errors() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = EnemyDBScript.new()

	# Act
	var ok: bool = db.load_catalog(
		_catalog([_make_enemy(&"a"), _make_enemy(&"b")]), spy)

	# Assert
	assert_true(ok, "clean catalog returns true")
	assert_eq(spy.total(), 0, "clean catalog logs nothing")


func test_enemy_db_duplicate_id_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = EnemyDBScript.new()

	# Act — two entries share an id.
	var ok: bool = db.load_catalog(
		_catalog([_make_enemy(&"dup"), _make_enemy(&"dup")]), spy)

	# Assert
	assert_false(ok, "duplicate id returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_duplicate_id", "logs content_duplicate_id")
	assert_eq(spy.errors[0]["detail"]["id"], &"dup", "error detail carries the offending id")
	assert_eq(spy.errors[0]["detail"]["db"], &"enemy", "error detail names the enemy DB")


func test_enemy_db_null_entry_is_fatal() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db: Node = EnemyDBScript.new()
	var cat := EnemyCatalog.new()
	cat.entries.append(_make_enemy(&"a"))
	cat.entries.append(null)  # stale/deleted authored slot

	# Act
	var ok: bool = db.load_catalog(cat, spy)

	# Assert
	assert_false(ok, "null entry returns false")
	assert_eq(spy.errors.size(), 1, "exactly one error logged")
	assert_eq(spy.errors[0]["code"], &"content_null_entry", "logs content_null_entry")
	assert_eq(spy.errors[0]["detail"]["db"], &"enemy", "error detail names the enemy DB")


# ---------------------------------------------------------------------------
# Read-only contract — returned def field is stable across reads
# ---------------------------------------------------------------------------

func test_enemy_db_returned_def_snapshot_stable_across_reads() -> void:
	# Arrange
	var spy := SpyLogSink.new()
	var db := _loaded_db([_make_enemy(&"stable")], spy)

	# Act — snapshot a field, do more reads, snapshot again.
	var got: EnemyDef = db.get_enemy(&"stable")
	var before: int = got.level
	var _again: EnemyDef = db.get_enemy(&"stable")
	var after: int = got.level

	# Assert
	assert_eq(before, after, "def field is stable across lookups (read-only, shared)")


# ---------------------------------------------------------------------------
# No DirAccess in the content load path (static grep)
# ---------------------------------------------------------------------------

func test_enemy_db_source_has_no_dir_access() -> void:
	# Arrange — read the loader source, strip comment lines. The doc comment
	# legitimately NAMES DirAccess ("No DirAccess anywhere in the load path"), so a
	# raw substring check would false-positive on the very comment documenting the
	# ban. We assert against actual CODE only.
	var src := FileAccess.get_file_as_string(ENEMY_DB_SOURCE)
	var code_lines: PackedStringArray = []
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	var code := "\n".join(code_lines)

	# Assert
	assert_ne(src, "", "loader source is readable")
	assert_false(code.contains("DirAccess"),
		"content load path must never use DirAccess (content_directory_scanning forbidden)")
