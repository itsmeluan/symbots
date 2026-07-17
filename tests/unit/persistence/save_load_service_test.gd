## SL-1 — SaveLoadService host + provider registry (ADR-0001).
##
## Covers AC-SL-01..05: register/retrieve, multi-key, fail-loud duplicate key,
## injected-LogSink diagnostics, DI constructibility (no global reach).
extends GutTest

const SpyLogSink = preload("res://tests/unit/tbc/spy_log_sink.gd")

## Minimal duck-typed provider stub — the registry only stores/retrieves it in
## SL-1 (the contract methods are exercised in SL-2+). preload()-ed, not
## class_name (a class_name in tests/ would pollute the global registry).
class StubProvider extends RefCounted:
	var tag: String = ""
	func _init(t: String = "") -> void:
		tag = t
	func snapshot() -> Dictionary:
		return {"tag": tag}
	func restore(_data: Dictionary) -> void:
		pass
	func rederive() -> void:
		pass


func _make_service() -> SaveLoadService:
	var spy: SpyLogSink = SpyLogSink.new()
	return SaveLoadService.new(spy)


# --- AC-SL-01: register → retrievable ---
func test_register_single_provider_is_retrievable() -> void:
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new())
	var p: StubProvider = StubProvider.new("drop")
	svc.register_provider(&"drop", p)
	assert_true(svc.has_provider(&"drop"), "registered key should be present")
	assert_eq(svc.get_provider(&"drop"), p, "should retrieve the same instance")


# --- AC-SL-02: two distinct keys both retained, count == 2 ---
func test_register_two_distinct_keys_keeps_both() -> void:
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new())
	svc.register_provider(&"drop", StubProvider.new("drop"))
	svc.register_provider(&"settings", StubProvider.new("settings"))
	assert_eq(svc.provider_count(), 2, "both distinct providers should be held")
	assert_true(svc.has_provider(&"drop"))
	assert_true(svc.has_provider(&"settings"))


# --- AC-SL-03: duplicate key is fail-loud, first instance retained ---
func test_duplicate_key_errors_and_retains_first() -> void:
	var spy: SpyLogSink = SpyLogSink.new()
	var svc: SaveLoadService = SaveLoadService.new(spy)
	var first: StubProvider = StubProvider.new("first")
	var second: StubProvider = StubProvider.new("second")
	svc.register_provider(&"drop", first)
	svc.register_provider(&"drop", second)
	# discriminator vs last-wins: the FIRST instance must survive
	assert_eq(svc.get_provider(&"drop"), first, "duplicate key must retain the first provider, not replace")
	assert_eq(svc.provider_count(), 1, "duplicate registration must not grow the registry")
	assert_true(spy.errors.size() >= 1, "duplicate key must route an error through the sink")
	assert_eq(spy.errors[0]["code"], &"save_provider_duplicate_key", "error code should identify the duplicate key")


# --- AC-SL-04: diagnostics route through the injected sink (not a global) ---
func test_diagnostics_use_injected_sink() -> void:
	var spy: SpyLogSink = SpyLogSink.new()
	var svc: SaveLoadService = SaveLoadService.new(spy)
	svc.register_provider(&"drop", StubProvider.new())
	svc.register_provider(&"drop", StubProvider.new())
	# the only path that logs in SL-1 is the duplicate-key error; its presence in
	# the spy proves the seam is wired, not bypassed to push_error
	assert_eq(spy.errors.size(), 1, "the injected spy should capture exactly the duplicate-key error")


# --- AC-SL-05: constructible with DI, no global reach, null sink tolerated ---
func test_constructible_with_injected_deps() -> void:
	var svc_with_spy: SaveLoadService = _make_service()
	assert_not_null(svc_with_spy, "service constructs with an injected spy sink")
	# a null sink must not crash the host (production wires the real sink at boot)
	var svc_null: SaveLoadService = SaveLoadService.new(null)
	svc_null.register_provider(&"drop", StubProvider.new())
	svc_null.register_provider(&"drop", StubProvider.new())  # duplicate → error path with null sink
	assert_eq(svc_null.provider_count(), 1, "null-sink host still enforces fail-loud duplicate policy without crashing")
