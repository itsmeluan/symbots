## SL-6 — DropSystem as the `&"drop"` save provider: snapshot / restore / rederive
## over the two pity maps (ADR-0001 provider contract).
##
## Covers AC-SL-33..36 (the pure provider surface, in isolation from SaveLoadService).
## The full-path round-trip through SaveLoadService is the integration test
## (tests/integration/persistence/drop_roundtrip_test.gd, AC-SL-37/38).
extends GutTest

const SpyLogSink = preload("res://tests/unit/tbc/spy_log_sink.gd")

var _balance: BalanceConfig
var _log: LogSink


func before_each() -> void:
	_balance = BalanceConfig.new()
	_log = SpyLogSink.new()


## The pity maps carry no RNG/inventory dependency — a bare seeded RNG suffices.
func _make_drop_system() -> DropSystem:
	return DropSystem.new(RandomNumberGenerator.new(), _balance, _log, null)


# --- AC-SL-33: snapshot shape — both maps present, plain data ---
func test_snapshot_shape_holds_both_maps() -> void:
	# Arrange
	var ds: DropSystem = _make_drop_system()
	ds.set_prototype_pity_credit(&"delta_core", 72)
	ds.set_break_pity_counter(&"forge_core", 7)

	# Act
	var snap: Dictionary = ds.snapshot()

	# Assert
	assert_true(snap.has("proto_pity_credit"), "snapshot carries proto_pity_credit map")
	assert_true(snap.has("break_pity_counter"), "snapshot carries break_pity_counter map")
	assert_eq(snap["proto_pity_credit"], {"delta_core": 72}, "proto map holds the seeded credit")
	assert_eq(snap["break_pity_counter"], {"forge_core": 7}, "break map holds the seeded counter")


# --- AC-SL-33: empty maps snapshot as empty (no pity accrued) ---
func test_snapshot_empty_when_no_pity() -> void:
	# Arrange
	var ds: DropSystem = _make_drop_system()

	# Act
	var snap: Dictionary = ds.snapshot()

	# Assert
	assert_eq(snap["proto_pity_credit"], {}, "empty proto map when nothing accrued")
	assert_eq(snap["break_pity_counter"], {}, "empty break map when nothing accrued")


# --- AC-SL-34: snapshot is a deep copy — mutating it never touches internal state ---
func test_snapshot_is_a_copy_not_a_live_map() -> void:
	# Arrange
	var ds: DropSystem = _make_drop_system()
	ds.set_prototype_pity_credit(&"delta_core", 72)

	# Act — mutate the returned snapshot
	var snap: Dictionary = ds.snapshot()
	snap["proto_pity_credit"]["delta_core"] = 999
	snap["proto_pity_credit"]["injected_key"] = 5

	# Assert — internal state is untouched (proves .duplicate(true), not a live ref)
	assert_eq(ds.get_prototype_pity_credit(&"delta_core"), 72, "internal credit unchanged by snapshot mutation")
	assert_eq(ds.get_prototype_pity_credit(&"injected_key"), 0, "injected key did not leak into internal map")


# --- AC-SL-35: restore sets exact values, int-cast from JSON floats ---
func test_restore_int_casts_json_floats() -> void:
	# Arrange — values as they arrive from a JSON parse: floats
	var ds: DropSystem = _make_drop_system()
	var data: Dictionary = {
		"proto_pity_credit": {"delta_core": 72.0},
		"break_pity_counter": {"forge_core": 7.0},
	}

	# Act
	ds.restore(data)

	# Assert — exact value AND TYPE_INT (a float counter would break the == N×C compare)
	assert_eq(ds.get_prototype_pity_credit(&"delta_core"), 72, "proto credit restored to exact value")
	assert_eq(typeof(ds.get_prototype_pity_credit(&"delta_core")), TYPE_INT, "restored proto credit is int, not float")
	assert_eq(ds.get_break_pity_counter(&"forge_core"), 7, "break counter restored to exact value")
	assert_eq(typeof(ds.get_break_pity_counter(&"forge_core")), TYPE_INT, "restored break counter is int, not float")


# --- AC-SL-35: restore replaces (does not merge) prior state ---
func test_restore_replaces_prior_state() -> void:
	# Arrange — seed stale state, then restore a different set
	var ds: DropSystem = _make_drop_system()
	ds.set_prototype_pity_credit(&"stale_core", 50)
	ds.restore({"proto_pity_credit": {"delta_core": 10}, "break_pity_counter": {}})

	# Assert — the stale key is gone (restore replaced the whole map)
	assert_eq(ds.get_prototype_pity_credit(&"stale_core"), 0, "stale key cleared — restore replaces, not merges")
	assert_eq(ds.get_prototype_pity_credit(&"delta_core"), 10, "restored key present")


# --- AC-SL-35: missing / non-Dictionary sub-map restores as a clean empty baseline ---
func test_restore_tolerates_missing_submaps() -> void:
	# Arrange
	var ds: DropSystem = _make_drop_system()
	ds.set_prototype_pity_credit(&"old", 3)

	# Act — an envelope missing both keys (e.g. a save predating the maps)
	ds.restore({})

	# Assert — no crash; both maps reset to empty
	assert_eq(ds.get_prototype_pity_credit(&"old"), 0, "missing proto sub-map yields empty baseline")
	assert_eq(ds.get_break_pity_counter(&"anything"), 0, "missing break sub-map yields empty baseline")


# --- AC-SL-36: rederive is a no-op — pity counters are source facts ---
func test_rederive_is_noop() -> void:
	# Arrange
	var ds: DropSystem = _make_drop_system()
	ds.set_prototype_pity_credit(&"delta_core", 72)
	ds.set_break_pity_counter(&"forge_core", 7)
	var before: Dictionary = ds.snapshot()

	# Act
	ds.rederive()

	# Assert — snapshot identical before and after
	assert_eq(ds.snapshot(), before, "rederive alters nothing (pity is a source fact)")
