## Part-DB Story 006 — Formula 3 (effective drop rate).
##
## Covers QA test cases AC-1 through AC-4 (GDD AC-09 + TR-part-016/017/007-side).
## Float discipline (GDD Engine Note): verified-exact IEEE-754 boundaries use strict
## `==`; float-product results use tolerance (`< 1e-9`). No RNG here — this is the
## probability only. Framework: GUT · Godot 4.7.
extends GutTest

const TOL := 1e-9


func before_each() -> void:
	_cfg = BalanceConfig.new()  # defaults == GDD Formula 3 base-rate table


var _cfg: BalanceConfig


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Build an Array[Dictionary] of matching conditions from bare multipliers.
func _conditions(multipliers: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in multipliers.size():
		out.append({"condition": StringName("cond_%d" % i), "multiplier": float(multipliers[i])})
	return out


func _edr(rarity: PartDef.Rarity, multipliers: Array) -> float:
	return DropRateFormula.compute_effective_drop_rate(rarity, _conditions(multipliers), _cfg)


# ---------------------------------------------------------------------------
# AC-1 (GDD AC-09 a/b/c): Boss-grade clamp boundaries (verified-exact → strict ==)
# ---------------------------------------------------------------------------

func test_drop_boss_grade_no_conditions_is_base_not_zero() -> void:
	# The multiplicative-formula invariant: base is 0.001, NEVER 0.0.
	assert_eq(_edr(PartDef.Rarity.BOSS_GRADE, []), 0.001,
		"Boss-grade with no conditions is exactly 0.001 (not 0.0)")


func test_drop_boss_grade_x1000_clamps_to_one() -> void:
	assert_eq(_edr(PartDef.Rarity.BOSS_GRADE, [1000.0]), 1.0,
		"0.001 × 1000 = 1.0 (clamp boundary, exact)")


func test_drop_boss_grade_x999_is_point_999_no_premature_clamp() -> void:
	# The clamp must NOT trigger until exactly 1.0 — an impl that rounds up fails.
	assert_eq(_edr(PartDef.Rarity.BOSS_GRADE, [999.0]), 0.999,
		"0.001 × 999 = 0.999 (clamp does not trigger below 1.0)")


func test_drop_boss_grade_x500_is_half() -> void:
	# The intended authoring value (BOSS_GRADE_BREAK_GUARANTEE = 0.5).
	assert_eq(_edr(PartDef.Rarity.BOSS_GRADE, [500.0]), 0.5,
		"0.001 × 500 = 0.5 (design break-guarantee target)")


# ---------------------------------------------------------------------------
# AC-2 (GDD AC-09 d): Rare multiplicative stack (float product → tolerance)
# ---------------------------------------------------------------------------

func test_drop_rare_stacks_multiplicatively() -> void:
	# 0.25 × 1.5 × 1.3 = 0.48750000000000004 in IEEE-754 → tolerance, not ==.
	assert_almost_eq(_edr(PartDef.Rarity.RARE, [1.5, 1.3]), 0.4875, TOL,
		"Rare base 0.25 × 1.5 × 1.3 ≈ 0.4875 (multipliers stack)")


# ---------------------------------------------------------------------------
# AC-3 (TR-part-017): Prototype gradient — each fired condition strictly improves
# ---------------------------------------------------------------------------

func test_drop_prototype_gradient_is_monotonic_not_all_or_nothing() -> void:
	var r0 := _edr(PartDef.Rarity.PROTOTYPE, [])
	var r1 := _edr(PartDef.Rarity.PROTOTYPE, [1.5])
	var r2 := _edr(PartDef.Rarity.PROTOTYPE, [1.5, 1.5])
	var r3 := _edr(PartDef.Rarity.PROTOTYPE, [1.5, 1.5, 1.5])
	assert_almost_eq(r0, 0.05, TOL, "0 fired = base 0.05")
	assert_almost_eq(r1, 0.075, TOL, "1 fired = 0.075")
	assert_almost_eq(r2, 0.1125, TOL, "2 fired = 0.1125")
	assert_almost_eq(r3, 0.16875, TOL, "3 fired = 0.16875 (~17%)")
	# Strictly increasing — proves gradient, not an all-or-nothing gate.
	assert_true(r0 < r1 and r1 < r2 and r2 < r3, "each fired condition strictly improves odds")


func test_drop_prototype_full_fire_lands_in_optimal_band() -> void:
	var r3 := _edr(PartDef.Rarity.PROTOTYPE, [1.5, 1.5, 1.5])
	assert_between(r3, 0.15, 0.20, "3× ×1.5 lands in the 15–20% optimal-play band")


# ---------------------------------------------------------------------------
# AC-4: Clamp above 1.0 never leaks
# ---------------------------------------------------------------------------

func test_drop_common_clamps_when_product_exceeds_one() -> void:
	# Common 0.70 × 1.5 × 1.3 = 1.365 raw → clamps to exactly 1.0.
	assert_eq(_edr(PartDef.Rarity.COMMON, [1.5, 1.3]), 1.0,
		"raw product > 1.0 clamps to exactly 1.0, never leaks through")


# ---------------------------------------------------------------------------
# Extra: missing multiplier key is inert; base rates match the GDD table
# ---------------------------------------------------------------------------

func test_drop_condition_without_multiplier_key_is_inert() -> void:
	var conds: Array[Dictionary] = [{"condition": &"broke_arm"}]  # no "multiplier"
	var rate := DropRateFormula.compute_effective_drop_rate(PartDef.Rarity.RARE, conds, _cfg)
	assert_almost_eq(rate, 0.25, TOL, "a condition lacking a multiplier defaults to ×1.0 (inert)")


func test_drop_base_rates_match_gdd_table() -> void:
	assert_almost_eq(_edr(PartDef.Rarity.COMMON, []), 0.70, TOL, "Common base 0.70")
	assert_almost_eq(_edr(PartDef.Rarity.RARE, []), 0.25, TOL, "Rare base 0.25")
	assert_almost_eq(_edr(PartDef.Rarity.BOSS_GRADE, []), 0.001, TOL, "Boss-grade base 0.001")
	assert_almost_eq(_edr(PartDef.Rarity.PROTOTYPE, []), 0.05, TOL, "Prototype base 0.05")
