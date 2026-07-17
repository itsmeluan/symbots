## DS-009 (release-blocker) — pity-counter persistence across save/load, including
## the post-reload guarantee boundary (AC-DS-28).
##
## This is the capstone that closes the Drop System epic. It does NOT use a bespoke
## serialization shortcut: state travels the ENTIRE real path built by the Save/Load
## epic — DropSystem.snapshot() → SaveLoadService envelope → JSON.stringify → atomic
## write (fake backend) → parse → SL-PRED-1 RESTORE → DropSystem.restore() — then the
## reloaded counters are driven through the real `resolve_drops` pity decisions to
## prove boundary SEMANTICS survived, not merely integer equality.
##
## Fixtures (from AC-DS-28):
##   delta_core — Prototype, 3 canonical ×1.5 conditions → C = 3, threshold 25×3 = 75,
##                optimal rate clamp(0.05 × 1.5³) = 0.16875.
##   forge_core — Boss-grade, 1 break condition ×500 → rate 0.001 × 500 = 0.5 when it
##                fires; guarantee floor M_BOSS_PITY = 8.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeFileBackend := preload("res://tests/unit/persistence/fake_file_backend.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

const SLOT := 0

# delta_core's three canonical conditions (all fired → c = 3, the optimal attempt).
const COND_A := &"zero_defeats"
const COND_B := &"flawless"
const COND_C := &"no_repairs_used"
const FORGE_BREAK := &"core_broken"


var _balance: BalanceConfig


func before_each() -> void:
	_balance = BalanceConfig.new()


func _make_drop_system(rng: RandomNumberGenerator) -> DropSystem:
	return DropSystem.new(rng, _balance, SpyLogSink.new(), null)


## delta_core Prototype with three canonical ×1.5 conditions (C = 3).
func _make_delta_core() -> PartDef:
	var p := PartDef.new()
	p.id = &"delta_core"
	p.rarity = PartDef.Rarity.PROTOTYPE
	p.drop_conditions = [
		{"condition": COND_A, "multiplier": 1.5},
		{"condition": COND_B, "multiplier": 1.5},
		{"condition": COND_C, "multiplier": 1.5},
	]
	return p


## forge_core Boss-grade with one break condition ×500 (rate 0.5 when it fires).
func _make_forge_core() -> PartDef:
	var p := PartDef.new()
	p.id = &"forge_core"
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.drop_enabled = true
	p.drop_conditions = [{"condition": FORGE_BREAK, "multiplier": 500.0}]
	return p


func _resolve(ds: DropSystem, part: PartDef, fired: Dictionary) -> int:
	var pool: Array[PartDef] = [part]
	return ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired).size()


## Save a DropSystem seeded to the AC-DS-28 pre-reload state through the real
## SaveLoadService path, then reload into a fresh DropSystem driven by a
## miss-forcing RNG. Returns the reloaded system.
func _save_then_reload(load_rng: RandomNumberGenerator, backend) -> DropSystem:
	# --- Source: seed the exact AC-DS-28 pre-reload counters, save the real path ---
	var src: DropSystem = _make_drop_system(Rng.Const.new(0.99))
	src.set_prototype_pity_credit(&"delta_core", 72)
	src.set_break_pity_counter(&"forge_core", 7)
	var src_svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	src_svc.register_provider(&"drop", src)
	assert_true(src_svc.save(SLOT)["ok"], "source save through the full path succeeds")

	# --- Teardown + reload: a brand-new DropSystem loads from the on-disk bytes ---
	var reloaded: DropSystem = _make_drop_system(load_rng)
	var dst_svc: SaveLoadService = SaveLoadService.new(SpyLogSink.new(), backend)
	dst_svc.register_provider(&"drop", reloaded)
	assert_true(dst_svc.load(SLOT)["ok"], "reload from the saved bytes succeeds")
	return reloaded


# --- AC-DS-28 (a): both maps reload identical to their saved values ---
func test_pity_maps_reload_identical() -> void:
	var reloaded: DropSystem = _save_then_reload(Rng.Const.new(0.60), FakeFileBackend.new())
	assert_eq(reloaded.get_prototype_pity_credit(&"delta_core"), 72,
		"delta_core credit reloads as 72 (not 0, not a wrong value)")
	assert_eq(reloaded.get_break_pity_counter(&"forge_core"), 7,
		"forge_core counter reloads as 7")


# --- AC-DS-28 (b): a failing qualifying attempt advances FROM the restored value ---
func test_post_reload_advance_is_from_restored_value() -> void:
	# RNG 0.60 misses both (0.60 ≥ 0.16875 and 0.60 ≥ 0.5) → both attempts fail.
	var reloaded: DropSystem = _save_then_reload(Rng.Const.new(0.60), FakeFileBackend.new())

	# delta_core: c = 3 (all conditions fired), miss → credit 72 + 3 → 75 (+= c, not += 1).
	var delta := _make_delta_core()
	assert_eq(_resolve(reloaded, delta, {COND_A: true, COND_B: true, COND_C: true}), 0,
		"0.60 ≥ 0.16875 → delta_core misses")
	assert_eq(reloaded.get_prototype_pity_credit(&"delta_core"), 75,
		"advance is 72 → 75 via += c from the RESTORED value, not 3 (from 0) or 73 (+= 1)")

	# forge_core: qualifying break, miss → counter 7 + 1 → 8.
	var forge := _make_forge_core()
	assert_eq(_resolve(reloaded, forge, {FORGE_BREAK: true}), 0,
		"0.60 ≥ 0.5 → forge_core misses")
	assert_eq(reloaded.get_break_pity_counter(&"forge_core"), 8,
		"advance is 7 → 8 via += 1 from the restored value")


# --- AC-DS-28 (c): the next qualifying attempt fires the guarantee post-reload ---
func test_post_reload_guarantee_fires_and_resets() -> void:
	# Reload, then advance to the thresholds (75 / 8) via a first failing attempt.
	var guarantee_rng := Rng.Const.new(0.60)  # would MISS if it were ever drawn
	var reloaded: DropSystem = _save_then_reload(guarantee_rng, FakeFileBackend.new())
	var delta := _make_delta_core()
	var forge := _make_forge_core()
	var all_three := {COND_A: true, COND_B: true, COND_C: true}
	var break_fired := {FORGE_BREAK: true}
	_resolve(reloaded, delta, all_three)   # 72 → 75
	_resolve(reloaded, forge, break_fired)  # 7 → 8
	var draws_before_guarantee: int = guarantee_rng.call_count

	# delta_core at 75 ≥ 75 → guaranteed drop (pre-roll, no RNG draw), credit → 0.
	assert_eq(_resolve(reloaded, delta, all_three), 1,
		"delta_core at 75 fires the guarantee → drops")
	assert_eq(reloaded.get_prototype_pity_credit(&"delta_core"), 0,
		"guarantee resets delta_core credit to 0")

	# forge_core at 8 ≥ 8 → guaranteed drop, counter → 0.
	assert_eq(_resolve(reloaded, forge, break_fired), 1,
		"forge_core at 8 fires the guarantee → drops")
	assert_eq(reloaded.get_break_pity_counter(&"forge_core"), 0,
		"guarantee resets forge_core counter to 0")

	# Discriminator: the guarantees were PRE-ROLL — the RNG stream was untouched by
	# them (0.60 would have missed, so a drop can only be the guarantee firing).
	assert_eq(guarantee_rng.call_count, draws_before_guarantee,
		"both guarantees are pre-roll — no RNG draw, so the drop is the reloaded boundary firing")
