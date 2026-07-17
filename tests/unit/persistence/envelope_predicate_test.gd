## SL-2 — Envelope assembly + SL-PRED-1 predicate + two-phase restore (ADR-0001).
##
## Covers AC-SL-06..12. In-memory only (no disk): consumes/produces envelope
## Dictionaries; SL-3 adds the JSON encode + atomic write around this seam.
extends GutTest

const SpyLogSink = preload("res://tests/unit/tbc/spy_log_sink.gd")

## Provider spy: records call order into a shared Array + captures restored data,
## so we can assert Phase-1-before-Phase-2 and order-independence. preload/inner,
## never class_name (no global-registry pollution from tests/).
class SpyProvider extends RefCounted:
	var key: String
	var order_log: Array
	var restored_data: Dictionary = {}
	var restore_count: int = 0
	var rederive_count: int = 0
	func _init(k: String, log_ref: Array) -> void:
		key = k
		order_log = log_ref
	func snapshot() -> Dictionary:
		return {"k": key}
	func restore(data: Dictionary) -> void:
		restored_data = data
		restore_count += 1
		order_log.append("restore:" + key)
	func rederive() -> void:
		rederive_count += 1
		order_log.append("rederive:" + key)


func _svc() -> SaveLoadService:
	return SaveLoadService.new(SpyLogSink.new())


# --- AC-SL-06: envelope shape + version + both provider keys ---
func test_snapshot_envelope_shape() -> void:
	var svc: SaveLoadService = _svc()
	var order: Array = []
	svc.register_provider(&"drop", SpyProvider.new("drop", order))
	svc.register_provider(&"settings", SpyProvider.new("settings", order))
	var env: Dictionary = svc.snapshot_envelope()
	assert_eq(env["save_format_version"], SaveLoadService.SAVE_FORMAT_VERSION, "outer version key present")
	assert_true(env.has("providers"), "envelope has a providers map")
	var providers: Dictionary = env["providers"]
	assert_true(providers.has(&"drop") and providers.has(&"settings"), "both providers present under providers")
	assert_eq(providers[&"drop"], {"k": "drop"}, "provider snapshot placed under its key")


# --- AC-SL-07: v == CURRENT → RESTORE then REDERIVE both fire ---
func test_current_version_restores_and_rederives() -> void:
	var svc: SaveLoadService = _svc()
	var order: Array = []
	var p: SpyProvider = SpyProvider.new("drop", order)
	svc.register_provider(&"drop", p)
	var env: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION,
		"providers": {&"drop": {"seed": 7}},
	}
	var result: Dictionary = svc.restore_envelope(env)
	assert_true(result["ok"], "current-version envelope restores")
	assert_eq(p.restore_count, 1, "restore fired once")
	assert_eq(p.rederive_count, 1, "rederive fired once")
	assert_eq(p.restored_data, {"seed": 7}, "provider received its blob")


# --- AC-SL-08: v > CURRENT → REFUSE, no provider touched, state untouched ---
func test_newer_version_refuses_without_touching_providers() -> void:
	var svc: SaveLoadService = _svc()
	var order: Array = []
	var p: SpyProvider = SpyProvider.new("drop", order)
	svc.register_provider(&"drop", p)
	var env: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION + 1,
		"providers": {&"drop": {"seed": 9}},
	}
	var result: Dictionary = svc.restore_envelope(env)
	assert_false(result["ok"], "newer-version envelope is refused")
	# discriminator: a naive restore-anyway impl would trip these to > 0
	assert_eq(p.restore_count, 0, "REFUSE must fire no restore")
	assert_eq(p.rederive_count, 0, "REFUSE must fire no rederive")


# --- AC-SL-09: v < CURRENT with no hook → behavioral REFUSE ---
func test_older_version_no_hook_refuses() -> void:
	var svc: SaveLoadService = _svc()
	var order: Array = []
	var p: SpyProvider = SpyProvider.new("drop", order)
	svc.register_provider(&"drop", p)
	var env: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION - 1,
		"providers": {&"drop": {"seed": 1}},
	}
	var result: Dictionary = svc.restore_envelope(env)
	assert_false(result["ok"], "older-version-no-hook is behaviorally refused")
	assert_eq(result["reason"], "migrate_no_hook", "reason distinguishes the MIGRATE branch")
	assert_eq(p.restore_count, 0, "no restore fired on a no-hook migrate")


# --- AC-SL-10: missing key + non-int value → REFUSE ---
func test_malformed_version_refuses() -> void:
	var svc: SaveLoadService = _svc()
	var order: Array = []
	svc.register_provider(&"drop", SpyProvider.new("drop", order))

	# missing key
	var missing: Dictionary = {"providers": {&"drop": {}}}
	assert_false(svc.restore_envelope(missing)["ok"], "missing version key → refuse")

	# non-int: string
	var str_ver: Dictionary = {"save_format_version": "1", "providers": {&"drop": {}}}
	assert_false(svc.restore_envelope(str_ver)["ok"], "string version → refuse")

	# non-int: non-integral float
	var frac_ver: Dictionary = {"save_format_version": 1.5, "providers": {&"drop": {}}}
	assert_false(svc.restore_envelope(frac_ver)["ok"], "non-integral float version → refuse")

	# integral float IS valid (JSON returns numbers as float) — proves the guard
	# is not over-eager
	var float_ok: Dictionary = {
		"save_format_version": float(SaveLoadService.SAVE_FORMAT_VERSION),
		"providers": {&"drop": {}},
	}
	assert_true(svc.restore_envelope(float_ok)["ok"], "integral float version restores (JSON number path)")


# --- AC-SL-11: all Phase-1 restores precede all Phase-2 rederives ---
func test_two_phase_ordering() -> void:
	var svc: SaveLoadService = _svc()
	var order: Array = []
	svc.register_provider(&"a", SpyProvider.new("a", order))
	svc.register_provider(&"b", SpyProvider.new("b", order))
	var env: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION,
		"providers": {&"a": {}, &"b": {}},
	}
	svc.restore_envelope(env)
	# every restore marker must come before every rederive marker
	var last_restore_idx: int = -1
	var first_rederive_idx: int = order.size()
	for i in order.size():
		if String(order[i]).begins_with("restore:"):
			last_restore_idx = i
		elif String(order[i]).begins_with("rederive:") and first_rederive_idx == order.size():
			first_rederive_idx = i
	assert_lt(last_restore_idx, first_rederive_idx, "all restores must precede all rederives (two-phase barrier)")


# --- AC-SL-12: reversed registration order → identical restored state ---
func test_order_independence() -> void:
	var env: Dictionary = {
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION,
		"providers": {&"a": {"v": 1}, &"b": {"v": 2}},
	}

	var svc1: SaveLoadService = _svc()
	var order1: Array = []
	var a1: SpyProvider = SpyProvider.new("a", order1)
	var b1: SpyProvider = SpyProvider.new("b", order1)
	svc1.register_provider(&"a", a1)
	svc1.register_provider(&"b", b1)
	svc1.restore_envelope(env)

	var svc2: SaveLoadService = _svc()
	var order2: Array = []
	var a2: SpyProvider = SpyProvider.new("a", order2)
	var b2: SpyProvider = SpyProvider.new("b", order2)
	# reversed registration order
	svc2.register_provider(&"b", b2)
	svc2.register_provider(&"a", a2)
	svc2.restore_envelope(env)

	assert_eq(a1.restored_data, a2.restored_data, "provider a restores identically regardless of order")
	assert_eq(b1.restored_data, b2.restored_data, "provider b restores identically regardless of order")
	assert_eq(a2.restored_data, {"v": 1}, "each provider gets its own blob, no cross-provider read")
