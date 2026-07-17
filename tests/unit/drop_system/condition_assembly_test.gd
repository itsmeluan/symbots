## DS-2 condition-assembly unit spec (Drop System Story 002).
##
## Covers the multiplier-product assembly that feeds the DS-1 roll:
##   AC-DS-22 exact-string match (no case-fold, no substring)
##   AC-DS-23 multiplicative stacking, 2-of-3 fired, unfired excluded
##   AC-DS-07 unknown condition key logged once + skipped, never a crash
##   AC-DS-25 outcome-fact conditions multiply identically to break-event keys
##
## The RNG is stubbed (rng_doubles.gd) and the LogSink is spied so every rate and
## every content-error emission is asserted deterministically (ADR-0006).
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

var _balance: BalanceConfig
var _log: SpyLogSink


func before_each() -> void:
	_balance = BalanceConfig.new()
	_log = SpyLogSink.new()


func _make_drop_system(rng: RandomNumberGenerator) -> DropSystem:
	return DropSystem.new(rng, _balance, _log, null)


func _make_part(id: StringName, rarity: int, conditions: Array[Dictionary] = []) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = rarity
	p.drop_conditions = conditions
	return p


func _drops(rng: RandomNumberGenerator, part: PartDef, fired: Dictionary) -> int:
	var pool: Array[PartDef] = [part]
	return _make_drop_system(rng).resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired).size()


## Warn entries recorded under a given code (spy stores {"code","detail"} dicts).
func _warns_with_code(code: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in _log.warns:
		if w["code"] == code:
			out.append(w)
	return out


# --- AC-DS-22: condition matching is exact-string (verifies R5) ---
func test_condition_match_is_exact_string_not_case_or_substring() -> void:
	# Rare servo (base 0.25) gated on the canonical key `arm_broken`.
	var servo := _make_part(&"servo_arm", PartDef.Rarity.RARE, [
		{"condition": &"arm_broken", "multiplier": 1.5},
	])
	# Fired set holds a CASE variant and a SUBSTRING variant — neither is arm_broken.
	var fired := {&"ARM_BROKEN": true, &"arm_break": true}

	# The ×1.5 must NOT apply: rate stays the bare base 0.25 (a case/substring impl
	# would reach 0.375 and drop at 0.30).
	var rate: float = _make_drop_system(Rng.Const.new(0.0))._effective_drop_rate(servo, fired, -1, 1.0)
	assert_almost_eq(rate, 0.25, 1e-9, "no fuzzy match → bare base rate 0.25")

	# 0.30 is ≥ 0.25 (no drop) but < 0.375 — the discriminating draw.
	assert_eq(_drops(Rng.Const.new(0.30), servo, fired), 0,
		"0.30 ≥ 0.25 → no drop; a case/substring match would wrongly drop at 0.375")
	# `arm_broken` is a canonical key, so no unknown-key content error is logged.
	assert_eq(_warns_with_code(&"drop_unknown_condition_key").size(), 0,
		"canonical keys never emit a content error")


# --- AC-DS-23: multipliers stack multiplicatively; unfired excluded (verifies R3) ---
func test_multipliers_stack_multiplicatively_only_for_fired() -> void:
	# Prototype delta_core (base 0.05) with three canonical ×1.5 conditions.
	var delta_core := _make_part(&"delta_core", PartDef.Rarity.PROTOTYPE, [
		{"condition": &"zero_defeats", "multiplier": 1.5},
		{"condition": &"flawless", "multiplier": 1.5},
		{"condition": &"no_repairs_used", "multiplier": 1.5},  # this one does NOT fire
	])
	var fired := {&"zero_defeats": true, &"flawless": true}  # exactly 2 of 3

	# 0.05 × 1.5 × 1.5 = 0.1125 (the third ×1.5 excluded — not 0.16875).
	var rate: float = _make_drop_system(Rng.Const.new(0.0))._effective_drop_rate(delta_core, fired, -1, 1.0)
	assert_almost_eq(rate, 0.1125, 1e-9, "two ×1.5 stack multiplicatively → 0.1125")

	# Scenario A: 0.11 < 0.1125 → drops (none-applied 0.05 / additive 0.10 both fail here).
	assert_eq(_drops(Rng.Const.new(0.11), delta_core, fired), 1,
		"0.11 < 0.1125 → drops; a 0.05 or 0.10 impl would not")
	# Scenario B: 0.15 ≥ 0.1125 → no drop (all-three 0.16875 would wrongly drop).
	assert_eq(_drops(Rng.Const.new(0.15), delta_core, fired), 0,
		"0.15 ≥ 0.1125 → no drop; an all-three-applied 0.16875 would wrongly drop")


# --- AC-DS-07: unknown condition key logged + skipped (verifies EC-DS-03) ---
func test_unknown_condition_key_logged_and_skipped_without_crash() -> void:
	var servo := _make_part(&"servo_arm", PartDef.Rarity.RARE, [
		{"condition": &"arm_broken", "multiplier": 1.5},
		{"condition": &"UNKNOWN_KEY_XYZ", "multiplier": 2.0},  # not in the vocabulary
		{"condition": &"targeting_active", "multiplier": 1.3},
	])
	var fired := {&"arm_broken": true, &"targeting_active": true}

	# 0.25 × 1.5 × 1.3 = 0.4875 — the ×2.0 is skipped, never applied.
	var rate: float = _make_drop_system(Rng.Const.new(0.0))._effective_drop_rate(servo, fired, -1, 1.0)
	assert_almost_eq(rate, 0.4875, 1e-9, "unknown ×2.0 skipped → 0.25 × 1.5 × 1.3 = 0.4875")

	# 0.41 < 0.4875 → drops, and exactly one content error names the unknown key.
	_log = SpyLogSink.new()  # fresh sink for the drop path
	assert_eq(_drops(Rng.Const.new(0.41), servo, fired), 1, "0.41 < 0.4875 → drops")
	var unknown_warns := _warns_with_code(&"drop_unknown_condition_key")
	assert_eq(unknown_warns.size(), 1, "exactly one content error for the unknown key")
	assert_eq(unknown_warns[0]["detail"].get(&"key"), &"UNKNOWN_KEY_XYZ",
		"the content error names UNKNOWN_KEY_XYZ")

	# 0.70 ≥ 0.4875 → no drop (applying the ×2.0 would give 0.975 and falsely drop).
	assert_eq(_drops(Rng.Const.new(0.70), servo, fired), 0,
		"0.70 ≥ 0.4875 → no drop; applying the unknown ×2.0 (→0.975) would falsely drop")


# --- AC-DS-25: outcome-fact conditions apply their multipliers (unit half of AD-1) ---
func test_outcome_fact_condition_multiplies_like_break_event() -> void:
	# Base 0.25 Rare gated on the outcome-fact key `zero_defeats`.
	var part := _make_part(&"clean_sweep_core", PartDef.Rarity.RARE, [
		{"condition": &"zero_defeats", "multiplier": 1.5},
	])
	var fired := {&"zero_defeats": true}  # injected directly as a Set of strings

	# 0.25 × 1.5 = 0.375 — outcome facts multiply identically to break events.
	var rate: float = _make_drop_system(Rng.Const.new(0.0))._effective_drop_rate(part, fired, -1, 1.0)
	assert_almost_eq(rate, 0.375, 1e-9, "outcome-fact ×1.5 → 0.375")

	# Scenario A: 0.30 < 0.375 → drops (an ignore-multiplier impl at 0.25 does not).
	assert_eq(_drops(Rng.Const.new(0.30), part, fired), 1,
		"0.30 < 0.375 → drops; an ignore-multiplier 0.25 impl would not")
	# Scenario B: 0.40 ≥ 0.375 → no drop (an additive 0.25 + 0.5 = 0.75 impl would drop).
	assert_eq(_drops(Rng.Const.new(0.40), part, fired), 0,
		"0.40 ≥ 0.375 → no drop; an additive 0.75 impl would wrongly drop")
