## SL-3 — Atomic file write + full failure surface + `.bak` (ADR-0001).
##
## Covers AC-SL-13..19. Uses the fake backend to force each failure point
## deterministically and to assert the previous save survives byte-identical.
extends GutTest

const SpyLogSink = preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeFileBackend = preload("res://tests/unit/persistence/fake_file_backend.gd")

const SLOT := 1
const FINAL := "user://save_slot_1.json"
const TMP := "user://save_slot_1.json.tmp"
const BAK := "user://save_slot_1.json.bak"


class StubProvider extends RefCounted:
	var data: Dictionary
	func _init(d: Dictionary) -> void:
		data = d
	func snapshot() -> Dictionary:
		return data.duplicate(true)
	func restore(_d: Dictionary) -> void:
		pass
	func rederive() -> void:
		pass


func _svc(backend) -> SaveLoadService:
	var s: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	s.register_provider(&"drop", StubProvider.new({"pity": 5}))
	return s


# --- AC-SL-13: happy path writes tmp → rotate → rename → final ---
func test_happy_path_writes_final() -> void:
	var backend = FakeFileBackend.new()
	var svc: SaveLoadService = _svc(backend)
	var result: Dictionary = svc.save(SLOT)
	assert_true(result["ok"], "healthy save succeeds")
	assert_true(backend.exists(FINAL), "final save file exists")
	assert_false(backend.exists(TMP), "tmp is renamed away, not left behind")
	assert_true(svc.has_save(SLOT), "has_save true after a successful write")
	# the final file holds the pretty-printed envelope
	assert_string_contains(backend.read_text(FINAL), "save_format_version")


# --- AC-SL-14: open failure aborts, prior save untouched ---
func test_open_failure_preserves_prior_save() -> void:
	var backend = FakeFileBackend.new()
	backend.seed_file(FINAL, "PRIOR_SAVE_BYTES")
	var svc: SaveLoadService = _svc(backend)
	backend.fail_open = true
	var result: Dictionary = svc.save(SLOT)
	assert_false(result["ok"], "open failure aborts the save")
	assert_eq(backend.read_text(FINAL), "PRIOR_SAVE_BYTES", "prior save byte-identical after open failure")


# --- AC-SL-15: store_string bool false aborts, prior save untouched ---
func test_store_bool_false_preserves_prior_save() -> void:
	var backend = FakeFileBackend.new()
	backend.seed_file(FINAL, "PRIOR_SAVE_BYTES")
	var svc: SaveLoadService = _svc(backend)
	backend.fail_store_bool = true
	var result: Dictionary = svc.save(SLOT)
	assert_false(result["ok"], "store_string==false aborts the save")
	assert_eq(backend.read_text(FINAL), "PRIOR_SAVE_BYTES", "prior save intact when store bool is false")
	assert_false(backend.exists(TMP), "the partial tmp is discarded")


# --- AC-SL-16: post-write get_error != OK aborts (the iOS discriminator) ---
func test_post_write_error_preserves_prior_save() -> void:
	var backend = FakeFileBackend.new()
	backend.seed_file(FINAL, "PRIOR_SAVE_BYTES")
	var svc: SaveLoadService = _svc(backend)
	# store_string returns TRUE but the post-write error is non-OK — the iOS
	# full-disk / sandbox-denial case the bool alone would miss
	backend.fail_get_error = ERR_FILE_CANT_WRITE
	var result: Dictionary = svc.save(SLOT)
	assert_false(result["ok"], "post-write get_error aborts even when the bool was true")
	assert_eq(backend.read_text(FINAL), "PRIOR_SAVE_BYTES", "prior save intact on post-write error")


# --- AC-SL-17: no handle leak — a later save on the same slot succeeds ---
func test_no_handle_leak_after_failure() -> void:
	var backend = FakeFileBackend.new()
	var svc: SaveLoadService = _svc(backend)
	backend.fail_store_bool = true
	assert_false(svc.save(SLOT)["ok"], "first save fails")
	backend.fail_store_bool = false
	var second: Dictionary = svc.save(SLOT)
	assert_true(second["ok"], "a later save on the same slot succeeds (no leaked handle blocking it)")


# --- AC-SL-18: flush precedes close ---
func test_flush_precedes_close() -> void:
	var backend = FakeFileBackend.new()
	var svc: SaveLoadService = _svc(backend)
	svc.save(SLOT)
	var flush_idx: int = backend.call_log.find("flush")
	var close_idx: int = backend.call_log.find("close")
	assert_gt(flush_idx, -1, "flush was called")
	assert_gt(close_idx, -1, "close was called")
	assert_lt(flush_idx, close_idx, "flush must precede close (iOS durability)")


# --- AC-SL-19: .bak holds exactly the previous generation ---
func test_bak_one_generation() -> void:
	var backend = FakeFileBackend.new()
	# v1
	var svc1: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	svc1.register_provider(&"drop", StubProvider.new({"gen": 1}))
	svc1.save(SLOT)
	var v1_content: String = backend.read_text(FINAL)
	# v2 — rotates v1 → .bak
	var svc2: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	svc2.register_provider(&"drop", StubProvider.new({"gen": 2}))
	svc2.save(SLOT)
	assert_eq(backend.read_text(BAK), v1_content, ".bak holds the v1 generation after v2 save")
	var v2_content: String = backend.read_text(FINAL)
	# v3 — rotates v2 → .bak (one generation, not an accumulation)
	var svc3: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	svc3.register_provider(&"drop", StubProvider.new({"gen": 3}))
	svc3.save(SLOT)
	assert_eq(backend.read_text(BAK), v2_content, ".bak now holds v2 — exactly one generation kept")
