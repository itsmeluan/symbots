## DS-4 Prototype gradient-pity unit spec (Drop System Story 004).
##
## The DS-2 pity model: per-Prototype-ID integer credit, a PRE-ROLL guarantee at
## `N_PROTO_PITY × C`, `+= c` partial credit on a qualifying miss, reset on any drop.
##   AC-DS-13 credit-threshold boundary — guarantee at 75, not 72; guarantee skips RNG
##   AC-DS-14 non-qualifying attempt (c == 0) earns no credit (anti-exploit)
##   AC-DS-29 partial-credit increment is `+= c`, not `+= 1`, not `+= C`
##   AC-DS-15 credit resets to 0 on any drop, even a natural sub-threshold drop
##
## delta_core: Prototype (base 0.05), three canonical ×1.5 conditions → C = 3,
## threshold = 25 × 3 = 75, optimal rate = clamp(0.05 × 1.5³) = 0.16875.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

const COND_A := &"zero_defeats"
const COND_B := &"flawless"
const COND_C := &"no_repairs_used"

var _balance: BalanceConfig
var _log: SpyLogSink


func before_each() -> void:
	_balance = BalanceConfig.new()
	_log = SpyLogSink.new()


func _make_drop_system(rng: RandomNumberGenerator) -> DropSystem:
	return DropSystem.new(rng, _balance, _log, null)


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


func _resolve(ds: DropSystem, part: PartDef, fired: Dictionary) -> int:
	var pool: Array[PartDef] = [part]
	return ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired).size()


# --- AC-DS-13: credit-threshold boundary — guarantee at 75, not 72 ---
func test_prototype_pity_guarantees_at_threshold_not_below() -> void:
	var delta := _make_delta_core()
	var all_three := {COND_A: true, COND_B: true, COND_C: true}  # c = 3

	# Scenario A: credit 72, c = 3, draw 0.50 → 72 ≥ 75 false → roll fails (0.50 ≥
	# 0.16875) → credit += 3 → 75; no emit; exactly one draw consumed.
	var rng_a := Rng.Const.new(0.50)
	var ds_a := _make_drop_system(rng_a)
	ds_a.set_prototype_pity_credit(&"delta_core", 72)
	assert_eq(_resolve(ds_a, delta, all_three), 0, "72 < 75 and 0.50 ≥ 0.16875 → no drop")
	assert_eq(ds_a.get_prototype_pity_credit(&"delta_core"), 75, "qualifying miss credits += c (3) → 75")
	assert_eq(rng_a.call_count, 1, "a non-guaranteed attempt consumes exactly one draw")

	# Scenario B: credit 75, c = 3 → guaranteed drop, RNG NOT called (stub armed with
	# a 0.50 that a post-roll bug would consume), credit → 0, exactly one instance.
	var rng_b := Rng.Const.new(0.50)
	var ds_b := _make_drop_system(rng_b)
	ds_b.set_prototype_pity_credit(&"delta_core", 75)
	assert_eq(_resolve(ds_b, delta, all_three), 1, "75 ≥ 75 → guaranteed drop")
	assert_eq(rng_b.call_count, 0, "a guaranteed drop is pre-roll — the RNG stream is untouched")
	assert_eq(ds_b.get_prototype_pity_credit(&"delta_core"), 0, "guarantee resets credit to 0")


# --- AC-DS-14: non-qualifying attempt (zero conditions fired) earns no credit ---
func test_non_qualifying_attempt_earns_no_credit() -> void:
	var delta := _make_delta_core()
	# None of delta_core's OWN conditions fired (an unrelated key fired instead).
	var fired := {&"arm_broken": true}  # canonical but not delta_core's → c = 0
	var rng := Rng.Const.new(0.50)  # 0.50 ≥ 0.05 base → miss
	var ds := _make_drop_system(rng)
	ds.set_prototype_pity_credit(&"delta_core", 10)

	assert_eq(_resolve(ds, delta, fired), 0, "0.50 ≥ 0.05 base → no drop")
	assert_eq(ds.get_prototype_pity_credit(&"delta_core"), 10,
		"c = 0 fight earns no pity progress (anti-exploit) — credit stays 10")


# --- AC-DS-29: partial-credit increment is += c (not += 1, not += C) ---
func test_partial_credit_increments_by_conditions_fired() -> void:
	var delta := _make_delta_core()
	var rng := Rng.Const.new(0.50)  # every attempt misses (0.50 ≥ every rate here)
	var ds := _make_drop_system(rng)
	ds.set_prototype_pity_credit(&"delta_core", 40)

	# 2-of-3 fired (c = 2), rate = clamp(0.05 × 1.5²) = 0.1125, miss → credit 40 → 42.
	var two := {COND_A: true, COND_B: true}
	assert_eq(_resolve(ds, delta, two), 0, "2-of-3 at 0.1125, draw 0.50 → miss")
	assert_eq(ds.get_prototype_pity_credit(&"delta_core"), 42, "+= c (2) → 42, not 41 (+=1) or 43 (+=C)")

	# From 42, 1-of-3 fired (c = 1), rate = 0.075, miss → credit 42 → 43.
	var one := {COND_A: true}
	assert_eq(_resolve(ds, delta, one), 0, "1-of-3 at 0.075, draw 0.50 → miss")
	assert_eq(ds.get_prototype_pity_credit(&"delta_core"), 43, "+= c (1) → 43")


# --- AC-DS-15: credit resets to 0 on any drop, even below threshold ---
func test_credit_resets_to_zero_on_natural_drop_below_threshold() -> void:
	var delta := _make_delta_core()
	var all_three := {COND_A: true, COND_B: true, COND_C: true}  # c = 3, rate 0.16875
	var rng := Rng.Const.new(0.10)  # 0.10 < 0.16875 → natural drop
	var ds := _make_drop_system(rng)
	ds.set_prototype_pity_credit(&"delta_core", 66)  # below the 75 threshold

	assert_eq(_resolve(ds, delta, all_three), 1, "0.10 < 0.16875 → drops via the normal roll")
	assert_eq(ds.get_prototype_pity_credit(&"delta_core"), 0,
		"any drop resets credit to 0 — not 66 (unchanged) or 69 (+= c on a drop)")
