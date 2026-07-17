## DS-7 Beacon (×2.0) & DS-F-LEVEL level-factor injection spec (Drop System Story 007).
##
## Fills Story 001's two `1.0` placeholder factors with their real values inside the
## DS-1 product, before the clamp:
##   effective = clamp(base × level_rarity_mult × Π(conditions) × beacon_factor, 0, 1)
##   AC-DS-31 A  Beacon on, MID band → 0.25 × 1.0 × 2.0 = 0.50 (no-injection impl fails)
##   AC-DS-31 A2 Beacon on, HIGH band → 0.25 × 1.5 × 2.0 = 0.75 (level-ignoring impl fails)
##   AC-DS-31 B  flee → nothing awarded, beacon flag stays false (victory-only, Rule 1)
##   AC-DS-31 C  Common 0.70 × Beacon → clamps to 1.0 (guaranteed)
##   AC-DS-31 D  a pity-guaranteed part ignores the Beacon (guarantee is pre-roll)
##
## Production interface (documented, AC-ELZS-11 binds here): `resolve_drops` takes
## `enemy_level: int` and resolves the DS-F-LEVEL band → Rare mult internally. A
## negative level opts out (mult 1.0); only the Rare column is level-scaled.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

const OUTCOME_FLED: int = 3  # any non-VICTORY int; Rule 1 gates them identically

var _balance: BalanceConfig
var _log: SpyLogSink


func before_each() -> void:
	_balance = BalanceConfig.new()
	_log = SpyLogSink.new()


func _make_drop_system(rng: RandomNumberGenerator) -> DropSystem:
	return DropSystem.new(rng, _balance, _log, null)


## A conditionless part of a given rarity → rolls at its bare per-rarity base rate.
func _make_part(id: StringName, rarity: PartDef.Rarity) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = rarity
	return p


## A break-gated Boss-grade part (base 0.001 × 500 = 0.5 when `break_key` fires).
func _make_boss(id: StringName, break_key: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.drop_conditions = [{"condition": break_key, "multiplier": 500.0}]
	return p


func _resolve(ds: DropSystem, part: PartDef, enemy_level: int, beacon: bool, outcome: int = DropSystem.OUTCOME_VICTORY, fired: Dictionary = {}) -> int:
	var pool: Array[PartDef] = [part]
	return ds.resolve_drops(outcome, pool, fired, enemy_level, beacon).size()


# --- AC-DS-31 A: Beacon injection, MID band → rate 0.50 ---
func test_beacon_injection_mid_band_doubles_rate() -> void:
	var rare := _make_part(&"servo_arm", PartDef.Rarity.RARE)
	# level 4 = MID (Rare mult 1.0) → 0.25 × 1.0 × 2.0 = 0.50. Draw 0.40 < 0.50 → drops.
	# A no-Beacon impl uses 0.25 and 0.40 ≥ 0.25 → does NOT drop (the discriminator).
	var rng := Rng.Const.new(0.40)
	var ds := _make_drop_system(rng)
	assert_eq(_resolve(ds, rare, 4, true), 1, "Beacon doubles 0.25 → 0.50; 0.40 < 0.50 drops")
	assert_true(ds.beacon_drop_multiplier_applied, "VICTORY-with-Beacon sets the observable flag")


# --- AC-DS-31 A2: Beacon + HIGH band level factor → rate 0.75 ---
func test_beacon_and_high_band_level_factor_stack() -> void:
	var rare := _make_part(&"servo_arm", PartDef.Rarity.RARE)
	# level 6 = HIGH (Rare mult 1.5) → 0.25 × 1.5 × 2.0 = 0.75. Draw 0.60 < 0.75 → drops.
	# An impl wiring the Beacon but ignoring the level factor returns 0.50, and
	# 0.60 ≥ 0.50 → does NOT drop. This test catches that omission.
	var rng := Rng.Const.new(0.60)
	var ds := _make_drop_system(rng)
	assert_eq(_resolve(ds, rare, 6, true), 1, "HIGH-band Rare ×1.5 × Beacon → 0.75; 0.60 < 0.75 drops")


# --- AC-DS-31 B: flee → nothing awarded, flag stays false ---
func test_flee_awards_nothing_and_leaves_beacon_flag_false() -> void:
	var rare := _make_part(&"servo_arm", PartDef.Rarity.RARE)
	var rng := Rng.Const.new(0.01)  # would drop at any positive rate IF a draw happened
	var ds := _make_drop_system(rng)
	assert_eq(_resolve(ds, rare, 4, true, OUTCOME_FLED), 0, "FLED awards nothing (Rule 1 victory-only)")
	assert_false(ds.beacon_drop_multiplier_applied, "a spent-on-flee Beacon never sets the flag")
	assert_eq(rng.call_count, 0, "the victory gate returns before any draw")


# --- AC-DS-31 C: Common × Beacon clamps to 1.0 (guaranteed) ---
func test_common_with_beacon_clamps_to_one() -> void:
	var common := _make_part(&"scrap_plate", PartDef.Rarity.COMMON)
	# 0.70 × 1.0 (Common never level-scaled) × 2.0 = 1.40 → clamp 1.0. Even a 0.99 draw drops.
	var rng := Rng.Const.new(0.99)
	var ds := _make_drop_system(rng)
	assert_eq(_resolve(ds, common, 4, true), 1, "0.70 × 2.0 = 1.40 clamps to 1.0 → guaranteed")


# --- AC-DS-31 D: a pity-guaranteed part ignores the Beacon ---
func test_pity_guaranteed_part_ignores_the_beacon() -> void:
	var forge := _make_boss(&"forge_core", &"core_broken")
	var fired := {&"core_broken": true}
	# Boss counter armed to guarantee. The Beacon is active, but the guarantee is
	# pre-roll: the part drops exactly once and NO rate is ever computed or multiplied
	# (call_count 0 proves the Beacon never touched a draw).
	var rng := Rng.Const.new(0.99)
	var ds := _make_drop_system(rng)
	ds.set_break_pity_counter(&"forge_core", 8)
	assert_eq(_resolve(ds, forge, 6, true, DropSystem.OUTCOME_VICTORY, fired), 1,
		"guaranteed part drops exactly once")
	assert_eq(rng.call_count, 0, "a guaranteed part is pre-roll — the Beacon multiplier is never applied to a rate")
	assert_eq(ds.get_break_pity_counter(&"forge_core"), 0, "guarantee resets the counter")
