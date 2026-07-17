## SL-6 (integration) — the `&"drop"` provider round-trips through the ENTIRE
## SaveLoadService path: envelope → JSON.stringify → atomic write (fake backend)
## → parse → SL-PRED-1 RESTORE → DropSystem.restore(). No bespoke shortcut.
##
## Covers AC-SL-37 (registration + written envelope shape) and AC-SL-38 (both pity
## maps survive the full path, values identical and int-typed).
extends GutTest

const SpyLogSink = preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeFileBackend = preload("res://tests/unit/persistence/fake_file_backend.gd")

const SLOT := 0
const FINAL := "user://save_slot_0.json"


func _make_drop_system() -> DropSystem:
	return DropSystem.new(RandomNumberGenerator.new(), BalanceConfig.new(), SpyLogSink.new(), null)


# --- AC-SL-37: registered under &"drop"; a full save writes a providers.drop entry ---
func test_drop_provider_registered_and_written() -> void:
	# Arrange — a DropSystem with pity accrued, registered as the drop provider
	var backend = FakeFileBackend.new()
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	var ds: DropSystem = _make_drop_system()
	ds.set_prototype_pity_credit(&"delta_core", 72)
	ds.set_break_pity_counter(&"forge_core", 7)
	svc.register_provider(&"drop", ds)
	assert_true(svc.has_provider(&"drop"), "drop provider is registered")

	# Act
	var result: Dictionary = svc.save(SLOT)

	# Assert — the written envelope carries the drop provider with both maps
	assert_true(result["ok"], "save succeeds")
	var written: Dictionary = JSON.parse_string(backend.read_text(FINAL))
	assert_true(written["providers"].has("drop"), "written envelope has a providers.drop entry")
	var drop_blob: Dictionary = written["providers"]["drop"]
	assert_eq(int(drop_blob["proto_pity_credit"]["delta_core"]), 72, "written proto credit is persisted")
	assert_eq(int(drop_blob["break_pity_counter"]["forge_core"]), 7, "written break counter is persisted")


# --- AC-SL-38: both maps survive the full save→load path, exact + int-typed ---
func test_full_path_roundtrip_preserves_both_maps() -> void:
	# Arrange — seed pity on a source DropSystem and save through the real path
	var backend = FakeFileBackend.new()
	var src_svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	var src_ds: DropSystem = _make_drop_system()
	src_ds.set_prototype_pity_credit(&"delta_core", 72)
	src_ds.set_break_pity_counter(&"forge_core", 7)
	src_svc.register_provider(&"drop", src_ds)
	assert_true(src_svc.save(SLOT)["ok"], "source save succeeds")

	# Act — a FRESH DropSystem (zero pity) loads over the same on-disk bytes
	var dst_ds: DropSystem = _make_drop_system()
	assert_eq(dst_ds.get_prototype_pity_credit(&"delta_core"), 0, "fresh system starts with no pity")
	var dst_svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	dst_svc.register_provider(&"drop", dst_ds)
	var load_result: Dictionary = dst_svc.load(SLOT)

	# Assert — restored exactly, and as ints (not the JSON floats they were parsed as)
	assert_true(load_result["ok"], "load succeeds")
	assert_eq(dst_ds.get_prototype_pity_credit(&"delta_core"), 72, "proto credit restored across the full path")
	assert_eq(typeof(dst_ds.get_prototype_pity_credit(&"delta_core")), TYPE_INT, "restored proto credit is int")
	assert_eq(dst_ds.get_break_pity_counter(&"forge_core"), 7, "break counter restored across the full path")
	assert_eq(typeof(dst_ds.get_break_pity_counter(&"forge_core")), TYPE_INT, "restored break counter is int")


# --- AC-SL-38 discriminator: an unrelated part id restores to zero (no bleed) ---
func test_roundtrip_does_not_invent_counters() -> void:
	# Arrange
	var backend = FakeFileBackend.new()
	var src_svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	var src_ds: DropSystem = _make_drop_system()
	src_ds.set_prototype_pity_credit(&"delta_core", 72)
	src_svc.register_provider(&"drop", src_ds)
	src_svc.save(SLOT)

	# Act
	var dst_ds: DropSystem = _make_drop_system()
	var dst_svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	dst_svc.register_provider(&"drop", dst_ds)
	dst_svc.load(SLOT)

	# Assert — only the saved key exists; an unsaved id is a clean zero
	assert_eq(dst_ds.get_prototype_pity_credit(&"never_saved"), 0, "an unsaved part id restores to 0, not invented")
	assert_eq(dst_ds.get_break_pity_counter(&"forge_core"), 0, "empty break map restores empty (nothing was saved there)")
