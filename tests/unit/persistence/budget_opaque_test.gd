## SL-4 — Budget guard + int-cast discipline + opaque unknown providers (ADR-0001).
##
## Covers AC-SL-20..26.
extends GutTest

const SpyLogSink = preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeFileBackend = preload("res://tests/unit/persistence/fake_file_backend.gd")

const SLOT := 1
const FINAL := "user://save_slot_1.json"


## A provider whose snapshot size we control (to trip the budget guard).
class BulkProvider extends RefCounted:
	var payload: String
	func _init(p: String) -> void:
		payload = p
	func snapshot() -> Dictionary:
		return {"blob": payload}
	func restore(_d: Dictionary) -> void:
		pass
	func rederive() -> void:
		pass


## A map provider that int-casts on restore (mirrors the real drop provider).
class MapProvider extends RefCounted:
	var map: Dictionary = {}
	func snapshot() -> Dictionary:
		return map.duplicate(true)
	func restore(data: Dictionary) -> void:
		map = {}
		for k in data:
			map[k] = SaveLoadService.as_int(data[k])
	func rederive() -> void:
		pass


# --- AC-SL-20 + AC-SL-21: budget guard rejects, explicit-if (Release-firing) ---
func test_budget_guard_rejects_oversized() -> void:
	var backend = FakeFileBackend.new()
	backend.seed_file(FINAL, "PRIOR")
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	svc.register_provider(&"bulk", BulkProvider.new("xxxxxxxxxxxxxxxxxxxx"))  # 20 bytes
	svc._max_save_bytes = 10   # lowered threshold — exercises the explicit-if path
	var result: Dictionary = svc.save(SLOT)
	assert_false(result["ok"], "oversized save is rejected")
	assert_eq(result["reason"], "budget_exceeded", "reason is budget_exceeded (the explicit-if path, not an assert)")
	assert_eq(backend.read_text(FINAL), "PRIOR", "nothing written; prior save intact")


# --- AC-SL-22: normal save is well under budget ---
func test_under_budget_saves() -> void:
	var backend = FakeFileBackend.new()
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	svc.register_provider(&"map", MapProvider.new())
	var result: Dictionary = svc.save(SLOT)
	assert_true(result["ok"], "a small save passes the budget guard (guard is not over-eager)")


# --- AC-SL-23: int-cast on restore keeps ints as ints, not JSON floats ---
func test_int_cast_on_restore() -> void:
	# as_int helper directly
	assert_eq(typeof(SaveLoadService.as_int(72.0)), TYPE_INT, "as_int returns TYPE_INT from a float")
	assert_eq(SaveLoadService.as_int(72.0), 72, "as_int preserves the value")
	# through a full JSON round-trip in a provider
	var provider: MapProvider = MapProvider.new()
	var json: String = JSON.stringify({"a": 72})
	var parsed = JSON.parse_string(json)
	# sanity: JSON parse yields a float
	assert_eq(typeof(parsed["a"]), TYPE_FLOAT, "JSON.parse yields float — the hazard the cast defends against")
	provider.restore(parsed)
	assert_eq(typeof(provider.map["a"]), TYPE_INT, "restored counter is TYPE_INT after the cast")
	assert_eq(provider.map["a"], 72, "value preserved")


# --- AC-SL-24: unknown provider key preserved byte-identical + warned ---
func test_opaque_unknown_provider_preserved() -> void:
	var spy: SpyLogSink = SpyLogSink.new()
	var svc: SaveLoadService = SaveLoadService.new(spy)
	svc.register_provider(&"map", MapProvider.new())
	var loaded: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION,
		"providers": {
			&"map": {"a": 1},
			&"future_system": {"nested": {"x": 5}, "flag": true},
		},
	}
	svc.restore_envelope(loaded)
	var out: Dictionary = svc.snapshot_envelope()
	assert_true(out["providers"].has(&"future_system"), "unknown provider key preserved")
	assert_eq(out["providers"][&"future_system"], {"nested": {"x": 5}, "flag": true}, "content preserved verbatim")
	assert_true(spy.warns.size() >= 1, "an opaque-preservation warning is emitted")


# --- AC-SL-25: opaque hold is a deep copy, immune to source mutation ---
func test_opaque_hold_is_deep_copy() -> void:
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new())
	var loaded: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION,
		"providers": {&"future_system": {"nested": {"x": 5}}},
	}
	svc.restore_envelope(loaded)
	# mutate the ORIGINAL parsed source after load
	loaded["providers"][&"future_system"]["nested"]["x"] = 999
	var out: Dictionary = svc.snapshot_envelope()
	assert_eq(out["providers"][&"future_system"]["nested"]["x"], 5, "held blob is a deep copy — source mutation does not leak in")


# --- AC-SL-26: registered provider takes precedence over a stored blob ---
func test_registered_provider_beats_stored_blob() -> void:
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new())
	var map_provider: MapProvider = MapProvider.new()
	svc.register_provider(&"map", map_provider)
	# the file has a `map` blob AND an unknown key
	var loaded: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION,
		"providers": {&"map": {"a": 42}, &"future_system": {"z": 1}},
	}
	svc.restore_envelope(loaded)
	# provider mutates its own state; the next snapshot must reflect the PROVIDER,
	# not the stored blob (the opaque path is only for unregistered keys)
	map_provider.map = {"a": 7, "b": 8}
	var out: Dictionary = svc.snapshot_envelope()
	assert_eq(out["providers"][&"map"], {"a": 7, "b": 8}, "registered provider's snapshot wins its own key")
	assert_true(out["providers"].has(&"future_system"), "unknown key still preserved opaquely")
