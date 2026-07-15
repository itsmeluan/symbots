## Part-DB Story 001 — typed-dict `.tres` round-trip GATE (headless GUT test).
##
## Verifies ADR-0003 Verification-Required item (2): that a
## `Dictionary[StringName, int]` `@export` survives a `.tres` write + reload with
## its key/value RUNTIME TYPES intact — StringName keys must NOT degrade to
## String, int values must NOT become Variant. This is the single load-bearing
## Foundation engine unknown; PASS unblocks Story 002 and all content authoring.
##
## Run headless (CI command) so editor-cache Resource instances can't contaminate
## the result:
##   godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
##
## Framework: GUT v9.6.1 · base class: GutTest · Godot 4.7
extends GutTest

const PROBE_SCRIPT := "res://tests/unit/part_database/stat_bonuses_probe.gd"
## Editor-authored fixture (generated in the exact text format Godot 4.7 writes).
const FIXTURE_TRES := "res://tests/unit/part_database/stat_bonuses_probe.tres"


## AC-1 (committed-fixture LOAD path — the primary coercion risk).
## Loading a real on-disk `.tres` is where StringName keys would silently
## deserialize as String. Assert the positive (is StringName) AND the negative
## (is NOT String) for every key.
func test_part_database_tres_load_preserves_stringname_keys_and_int_values() -> void:
	# Arrange / Act — fresh load, cache ignored so we exercise real deserialization.
	var res := ResourceLoader.load(FIXTURE_TRES, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Assert — the resource loaded and carries the authored entries.
	assert_not_null(res, "Fixture .tres must load")
	var bonuses: Dictionary = res.stat_bonuses
	assert_eq(bonuses.size(), 2, "Authored fixture has exactly two entries")

	for k in bonuses.keys():
		assert_eq(typeof(k), TYPE_STRING_NAME,
			"Key %s must reload as StringName" % [k])
		assert_ne(typeof(k), TYPE_STRING,
			"Key %s must NOT silently degrade to plain String" % [k])
	for v in bonuses.values():
		assert_eq(typeof(v), TYPE_INT, "Value %s must reload as int" % [v])

	# Authored values survived intact (not just their types).
	assert_eq(bonuses[&"structure"], 10, "structure bonus preserved")
	assert_eq(bonuses[&"armor"], 5, "armor bonus preserved")


## AC-1 (full SAVE + LOAD round-trip, independent of the committed fixture).
## Proves the write path too: build in memory → ResourceSaver.save → reload.
func test_part_database_tres_save_then_reload_round_trips_types() -> void:
	# Arrange — build a probe instance with StringName keys in code.
	var probe_script := load(PROBE_SCRIPT)
	var original: Resource = probe_script.new()
	var authored: Dictionary[StringName, int] = {}
	authored[&"structure"] = 42
	authored[&"armor"] = 7
	original.stat_bonuses = authored

	var tmp_path := "user://roundtrip_probe.tres"

	# Act — save to disk and reload with the cache bypassed.
	var save_err := ResourceSaver.save(original, tmp_path)
	var reloaded := ResourceLoader.load(tmp_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Assert
	assert_eq(save_err, OK, "ResourceSaver.save must succeed")
	assert_not_null(reloaded, "Round-tripped .tres must reload")
	var bonuses: Dictionary = reloaded.stat_bonuses
	assert_eq(bonuses.size(), 2, "Both entries survive the round-trip")
	for k in bonuses.keys():
		assert_eq(typeof(k), TYPE_STRING_NAME, "Round-tripped key stays StringName")
		assert_ne(typeof(k), TYPE_STRING, "Round-tripped key must not degrade to String")
	assert_eq(bonuses[&"structure"], 42, "Round-tripped int value preserved")

	# Cleanup — remove the temp artifact (isolation rule).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))


## AC-2 — typed accessor returns a usable `int`, not a `Variant`.
func test_part_database_get_bonus_returns_usable_int() -> void:
	# Arrange
	var res := ResourceLoader.load(FIXTURE_TRES, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Act
	var got: int = res.get_bonus(&"structure")

	# Assert — TYPE_INT and usable in integer arithmetic without a cast.
	assert_eq(typeof(got), TYPE_INT, "get_bonus must return int, not Variant")
	assert_eq(got * 2, 20, "Returned int is usable directly in arithmetic")


## AC-2 edge — missing key returns the typed 0 default, never null.
func test_part_database_get_bonus_missing_key_returns_int_zero() -> void:
	# Arrange
	var res := ResourceLoader.load(FIXTURE_TRES, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Act
	var got: int = res.get_bonus(&"does_not_exist")

	# Assert
	assert_eq(typeof(got), TYPE_INT, "Missing-key default is typed int")
	assert_eq(got, 0, "Missing key yields 0, not null")


## AC-1 edge — an empty typed dict round-trips as an empty dict (not null / not
## an untyped {}).
func test_part_database_empty_typed_dict_round_trips() -> void:
	# Arrange — probe with no bonuses authored.
	var probe_script := load(PROBE_SCRIPT)
	var original: Resource = probe_script.new()
	original.stat_bonuses = {} as Dictionary[StringName, int]
	var tmp_path := "user://empty_probe.tres"

	# Act
	var save_err := ResourceSaver.save(original, tmp_path)
	var reloaded := ResourceLoader.load(tmp_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Assert
	assert_eq(save_err, OK, "Empty-dict resource saves")
	assert_not_null(reloaded, "Empty-dict resource reloads")
	assert_eq(reloaded.stat_bonuses.size(), 0, "Empty dict stays empty")

	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
