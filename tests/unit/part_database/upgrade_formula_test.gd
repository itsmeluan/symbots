## Part-DB Story 004 — Formula 2 (upgrade stat scaling) + Formula 2b (drawback
## reduction) + sign-routing + the Common +3 cap.
##
## Covers QA test cases AC-1 through AC-4 (GDD AC-06/07/08/16). Fixtures are
## DISCRIMINATING — chosen so floor ≠ round ≠ ceil, so a wrong rounding mode or a
## missing epsilon/clamp actually fails an assertion. Framework: GUT · Godot 4.7.
##
## `UpgradeFormula`/`StatMath`/`BalanceConfig` are pure Layer-1/Layer-4 constructs
## (ADR-0005) — exercised directly with an injected `BalanceConfig.new()` (its
## `@export` defaults mirror the GDD tier table). No autoload, no boot coupling.
extends GutTest

const COMMON_MAX_TIER := 3
const RARE_MAX_TIER := 5


func before_each() -> void:
	_cfg = BalanceConfig.new()  # defaults == GDD tier table


var _cfg: BalanceConfig


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _part(stat_bonuses: Dictionary, max_tier: int) -> PartDef:
	var pd := PartDef.new()
	pd.id = &"fixture_part"
	pd.max_upgrade_tier = max_tier
	var typed: Dictionary[StringName, int] = {}
	for k in stat_bonuses:
		typed[k] = stat_bonuses[k]
	pd.stat_bonuses = typed
	return pd


## Compute Formula 2 across tiers 0..5 for a positive base stat.
func _f2_sequence(base_stat: int) -> Array[int]:
	var out: Array[int] = []
	for tier in range(6):
		out.append(UpgradeFormula.upgraded_stat(base_stat, tier, _cfg))
	return out


## Compute Formula 2b across tiers 0..5 for a (negative) base stat.
func _f2b_sequence(base_stat: int) -> Array[int]:
	var out: Array[int] = []
	for tier in range(6):
		out.append(UpgradeFormula.upgraded_drawback(base_stat, tier))
	return out


# ---------------------------------------------------------------------------
# AC-1 (GDD AC-06): Formula 2 multiplier + floor at each tier
# ---------------------------------------------------------------------------

func test_upgrade_f2_base_13_floors_at_each_tier() -> void:
	# floor(13×1.15)=14 (ceil/round→15); floor(13×1.50)=19 (round→20).
	assert_eq(_f2_sequence(13), [13, 14, 16, 19, 22, 26] as Array[int],
		"F2 base=13 must floor at every tier (discriminates floor from round/ceil)")


func test_upgrade_f2_base_7_floors_at_each_tier() -> void:
	assert_eq(_f2_sequence(7), [7, 8, 9, 10, 11, 14] as Array[int],
		"F2 base=7 floors: floor(7×1.15)=8 (ceil→9)")


func test_upgrade_f2_tier_zero_is_identity() -> void:
	assert_eq(UpgradeFormula.upgraded_stat(55, 0, _cfg), 55, "×1.00 at tier 0 is identity")


func test_upgrade_f2_epsilon_guard_exact_representable() -> void:
	# 20×1.15 == 23.0 exactly in IEEE754 (GDD correction note). Passes with or
	# without the nudge — retained as a regression guard against a bad retune.
	assert_eq(UpgradeFormula.upgraded_stat(20, 1, _cfg), 23, "20×1.15 floors to 23")


# ---------------------------------------------------------------------------
# AC-2 (GDD AC-07): Common +3 hard cap
# ---------------------------------------------------------------------------

func test_upgrade_common_can_upgrade_gate_at_plus_three() -> void:
	var common := _part({&"power": 10}, COMMON_MAX_TIER)
	assert_true(UpgradeFormula.can_upgrade(common, 3), "Common may reach +3")
	assert_false(UpgradeFormula.can_upgrade(common, 4), "Common may NOT reach +4")


func test_upgrade_common_silently_caps_at_plus_three() -> void:
	var common := _part({&"power": 10}, COMMON_MAX_TIER)
	# Both must equal the literal +3 value 15 (floor(10×1.50)) — not merely equal
	# each other. tier 4 silently clamps to 3; no throw.
	var at3 := UpgradeFormula.upgraded_value_for_part(common, &"power", 3, _cfg)
	var at4 := UpgradeFormula.upgraded_value_for_part(common, &"power", 4, _cfg)
	assert_eq(at3, 15, "Common +3 value is 15")
	assert_eq(at4, 15, "Common +4 request silently caps to the +3 value 15")


# ---------------------------------------------------------------------------
# AC-3 (GDD AC-08): Formula 2b full sequence + load-bearing max(0,…) clamp
# ---------------------------------------------------------------------------

func test_upgrade_f2b_base_minus_15_reduces_to_zero() -> void:
	# tier +1 is THE load-bearing epsilon case: 15×(1−1/3)=10.0000000000000018;
	# without the −ε nudge ceil() returns 11 → penalty −11 instead of −10.
	assert_eq(_f2b_sequence(-15), [-15, -10, -5, 0, 0, 0] as Array[int],
		"F2b base=-15 reduces to 0 by +3 and STAYS 0 at +4/+5 (max(0,…) clamp)")


func test_upgrade_f2b_base_minus_3_reduces_to_zero() -> void:
	# Round 11: replaces the former base=-1 fixture (non-discriminating — a no-reduction
	# implementation produces the same [-1,-1,-1,0,0,0] sequence). Base=-3 is
	# discriminating (python-verified 2026-07-16): correct [-3,-2,-1,0,0,0];
	# no-reduction [-3,-3,-3,0,0,0]; floor-instead-of-ceil [-2,-1,0,1,1,1].
	assert_eq(_f2b_sequence(-3), [-3, -2, -1, 0, 0, 0] as Array[int],
		"F2b base=-3 reduces by one magnitude per tier, reaching 0 at +3 (discriminates no-reduction and floor-instead-of-ceil)")


func test_upgrade_f2b_clamp_prevents_positive_at_plus_four_five() -> void:
	# Without max(0,…): tier+4 scale = 1−4/3 = -0.333 → -ceil(15×-0.333) = +5 (a
	# drawback becoming a BONUS). Assert the sign never flips positive.
	var at4 := UpgradeFormula.upgraded_drawback(-15, 4)
	var at5 := UpgradeFormula.upgraded_drawback(-15, 5)
	assert_eq(at4, 0, "tier +4 clamps to 0 (no double-negation to positive)")
	assert_eq(at5, 0, "tier +5 clamps to 0")


# ---------------------------------------------------------------------------
# AC-4 (GDD AC-16): sign-routing + per-stat independence
# ---------------------------------------------------------------------------

func test_upgrade_sign_routing_positive_negative_zero() -> void:
	assert_eq(UpgradeFormula.upgraded_value(13, 1, _cfg), 14, "positive routes to F2")
	assert_eq(UpgradeFormula.upgraded_value(-15, 1, _cfg), -10, "negative routes to F2b")
	assert_eq(UpgradeFormula.upgraded_value(0, 5, _cfg), 0, "zero stays zero at any tier")


func test_upgrade_f2b_independent_per_negative_stat() -> void:
	# Prototype with two independent negative stats; neither must affect the other.
	var proto := _part({&"armor": -15, &"mobility": -8}, RARE_MAX_TIER)
	var armor := UpgradeFormula.upgraded_value_for_part(proto, &"armor", 2, _cfg)
	var mobility := UpgradeFormula.upgraded_value_for_part(proto, &"mobility", 2, _cfg)
	assert_eq(armor, -5, "armor -15 at +2 → -5")
	assert_eq(mobility, -3, "mobility -8 at +2 → -3 (independent of armor)")


func test_upgrade_mixed_signs_on_same_part_route_separately() -> void:
	# A positive and a negative stat on one part take F2 and F2b respectively.
	var mixed := _part({&"power": 13, &"armor": -15}, RARE_MAX_TIER)
	assert_eq(UpgradeFormula.upgraded_value_for_part(mixed, &"power", 1, _cfg), 14,
		"positive stat → F2")
	assert_eq(UpgradeFormula.upgraded_value_for_part(mixed, &"armor", 1, _cfg), -10,
		"negative stat → F2b")


func test_upgrade_missing_stat_key_is_zero() -> void:
	var part := _part({&"power": 13}, RARE_MAX_TIER)
	assert_eq(UpgradeFormula.upgraded_value_for_part(part, &"nonexistent", 3, _cfg), 0,
		"a stat the part does not define contributes 0")
