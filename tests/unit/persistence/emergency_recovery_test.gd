## SL-5 — Emergency save + never-destroy-unparseable + `.bak` read fallback (ADR-0001).
##
## Covers AC-SL-27..32.
extends GutTest

const SpyLogSink = preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeFileBackend = preload("res://tests/unit/persistence/fake_file_backend.gd")

const S0_FINAL := "user://save_slot_0.json"
const S1_FINAL := "user://save_slot_1.json"
const S1_BAK := "user://save_slot_1.json.bak"


class StateProvider extends RefCounted:
	var state: Dictionary
	var restored: Dictionary = {}
	func _init(s: Dictionary = {}) -> void:
		state = s
	func snapshot() -> Dictionary:
		return state.duplicate(true)
	func restore(d: Dictionary) -> void:
		restored = d.duplicate(true)
	func rederive() -> void:
		pass


func _svc(backend, provider_state: Dictionary) -> SaveLoadService:
	var s: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	s.register_provider(&"drop", StateProvider.new(provider_state))
	return s


# --- AC-SL-27: emergency save is indistinguishable from a normal save ---
func test_emergency_save_equals_normal_save() -> void:
	var b_emg = FakeFileBackend.new()
	_svc(b_emg, {"pity": 5}).save_emergency()   # active slot defaults to 0

	var b_norm = FakeFileBackend.new()
	_svc(b_norm, {"pity": 5}).save(0)

	assert_eq(b_emg.read_text(S0_FINAL), b_norm.read_text(S0_FINAL),
		"emergency save produces byte-identical envelope to a normal save")

	# and it is loadable by SL-PRED-1
	var svc_load: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), b_emg)
	var p: StateProvider = StateProvider.new()
	svc_load.register_provider(&"drop", p)
	assert_true(svc_load.load(0)["ok"], "emergency save loads back cleanly")
	assert_eq(int(p.restored["pity"]), 5, "loaded state matches")


# --- AC-SL-28: interrupted emergency write leaves the prior save intact ---
func test_interrupted_emergency_is_nondestructive() -> void:
	var b = FakeFileBackend.new()
	b.seed_file(S0_FINAL, "PRIOR_SAVE")
	var svc: SaveLoadService = _svc(b, {"pity": 9})
	b.fail_store_bool = true
	var res: Dictionary = svc.save_emergency()
	assert_false(res["ok"], "the interrupted emergency write fails")
	assert_eq(b.read_text(S0_FINAL), "PRIOR_SAVE", "prior save survives an interrupted emergency write")


# --- AC-SL-29: corrupt primary → recover from .bak ---
func test_corrupt_primary_recovers_from_bak() -> void:
	var b = FakeFileBackend.new()
	_svc(b, {"gen": 1}).save(1)   # final = gen1
	_svc(b, {"gen": 2}).save(1)   # rotates: bak = gen1, final = gen2
	b.files[S1_FINAL] = "{{{ not valid json"   # corrupt the primary

	var svc_load: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), b)
	var p: StateProvider = StateProvider.new()
	svc_load.register_provider(&"drop", p)
	var res: Dictionary = svc_load.load(1)
	assert_true(res["ok"], "load recovers from .bak when the primary is corrupt")
	assert_eq(res.get("reason", ""), "recovered_from_bak", "recovery is flagged")
	assert_eq(int(p.restored["gen"]), 1, "recovered the .bak generation (gen1)")


# --- AC-SL-30: both corrupt → surface, do NOT destroy the bytes ---
func test_both_corrupt_surfaces_and_preserves() -> void:
	var b = FakeFileBackend.new()
	b.seed_file(S1_FINAL, "CORRUPT_PRIMARY")
	b.seed_file(S1_BAK, "CORRUPT_BAK")
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), b)
	svc.register_provider(&"drop", StateProvider.new())
	var res: Dictionary = svc.load(1)
	assert_false(res["ok"], "both-corrupt is a failed load")
	assert_eq(res["reason"], "corrupt", "reason is corrupt (not no_save)")
	# discriminator vs a naive reset-to-new-game: the bytes must be untouched
	assert_eq(b.read_text(S1_FINAL), "CORRUPT_PRIMARY", "corrupt primary not destroyed")
	assert_eq(b.read_text(S1_BAK), "CORRUPT_BAK", "corrupt .bak not destroyed")


# --- AC-SL-31: missing file → no_save, distinct from corrupt ---
func test_missing_file_is_no_save() -> void:
	var b = FakeFileBackend.new()
	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), b)
	svc.register_provider(&"drop", StateProvider.new())
	assert_false(svc.has_save(1), "no file present")
	var res: Dictionary = svc.load(1)
	assert_false(res["ok"], "missing slot is a failed load")
	assert_eq(res["reason"], "no_save", "missing is no_save, distinct from corrupt")


# --- AC-SL-32: valid JSON that is not a Dictionary → treated corrupt → .bak ---
func test_non_dictionary_primary_falls_back_to_bak() -> void:
	var b = FakeFileBackend.new()
	var valid_env: String = JSON.stringify({
		"save_format_version": SaveLoadService.SAVE_FORMAT_VERSION,
		"providers": {&"drop": {"gen": 7}},
	}, "\t")
	b.seed_file(S1_FINAL, "[]")        # valid JSON, but an array not a Dictionary
	b.seed_file(S1_BAK, valid_env)     # a good backup

	var svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), b)
	var p: StateProvider = StateProvider.new()
	svc.register_provider(&"drop", p)
	var res: Dictionary = svc.load(1)
	assert_true(res["ok"], "a non-Dictionary primary is treated as corrupt and .bak recovers")
	assert_eq(res.get("reason", ""), "recovered_from_bak")
	assert_eq(int(p.restored["gen"]), 7, "recovered the .bak content")
