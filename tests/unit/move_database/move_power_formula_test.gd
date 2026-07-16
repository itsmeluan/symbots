## Move-DB Story 003 — MOVE-F1 power-multiply formula (discriminating + load-bearing).
##
## Covers QA test cases AC-1 through AC-3:
##   AC-1 (AC-MDB-02): discriminating floor — round()/ceil() paths asserted to FAIL.
##   AC-2 (AC-MDB-03): load-bearing epsilon — the bare-floor path returns the wrong
##         integer and is asserted to differ; the min clamp never returns 0.
##   AC-3 (AC-MDB-04): tier ceilings / range — output never exceeds 315; every tier
##         maps to its exact multiplier.
##
## Fixtures pre-verified by a python3 Fraction-oracle scan over all 1,125 inputs
## (df1 ∈ [1,225] × 5 tiers): 0 impl-vs-exact mismatches; exactly 10 load-bearing
## inputs (0.70×{90,170,180}, 1.40×{45,85,90,165,170,175,180}). Framework: GUT · 4.7.
extends GutTest

const MovePowerFormulaScript := preload("res://src/core/stats/move_power_formula.gd")

var _cfg: BalanceConfig


func before_each() -> void:
	# Fresh BalanceConfig — its @export default power_tier_multipliers mirrors the
	# GDD tier table [0.0, 0.70, 0.80, 1.00, 1.20, 1.40] (index 0 reserved).
	_cfg = BalanceConfig.new()


## Local helper mirroring the bare-floor (epsilon-omitted) WRONG path, so the test
## can prove the epsilon is load-bearing without reaching into the formula.
func _bare_floor(df1: int, tier: int) -> int:
	var mult: float = _cfg.power_tier_multipliers[tier]
	return maxi(1, floori(float(df1) * mult))


# ---------------------------------------------------------------------------
# Tier table — every tier maps to its exact multiplier
# ---------------------------------------------------------------------------

func test_move_f1_tier_multipliers_match_gdd_table() -> void:
	# STANDARD is the ×1.00 identity tier — df1 passes through unchanged.
	assert_eq(MovePowerFormulaScript.move_damage(100, MoveDef.PowerTier.BASIC, _cfg),     70,  "BASIC ×0.70")
	assert_eq(MovePowerFormulaScript.move_damage(100, MoveDef.PowerTier.LIGHT, _cfg),     80,  "LIGHT ×0.80")
	assert_eq(MovePowerFormulaScript.move_damage(100, MoveDef.PowerTier.STANDARD, _cfg),  100, "STANDARD ×1.00 identity")
	assert_eq(MovePowerFormulaScript.move_damage(100, MoveDef.PowerTier.HEAVY, _cfg),     120, "HEAVY ×1.20")
	assert_eq(MovePowerFormulaScript.move_damage(100, MoveDef.PowerTier.SIGNATURE, _cfg), 140, "SIGNATURE ×1.40")


func test_move_f1_tiers_strictly_ordered() -> void:
	# The taxonomy is meaningless unless the tiers strictly increase (Tuning-Knob 3).
	var m := _cfg.power_tier_multipliers
	assert_true(
		m[MoveDef.PowerTier.BASIC] < m[MoveDef.PowerTier.LIGHT]
		and m[MoveDef.PowerTier.LIGHT] < m[MoveDef.PowerTier.STANDARD]
		and m[MoveDef.PowerTier.STANDARD] < m[MoveDef.PowerTier.HEAVY]
		and m[MoveDef.PowerTier.HEAVY] < m[MoveDef.PowerTier.SIGNATURE],
		"power_tier_multipliers strictly ordered BASIC < LIGHT < STANDARD < HEAVY < SIGNATURE")


# ---------------------------------------------------------------------------
# AC-1 (AC-MDB-02): discriminating floor — round/ceil paths must FAIL
# ---------------------------------------------------------------------------

func test_move_f1_discriminating_floor_basic() -> void:
	# df1=164, BASIC 0.70 → 164×0.70 = 114.8 → floor = 114 (round/ceil give 115).
	var got := MovePowerFormulaScript.move_damage(164, MoveDef.PowerTier.BASIC, _cfg)
	assert_eq(got, 114, "164 × 0.70 floors to 114")
	# Discriminator: a round()- or ceil()-based impl would give 115.
	assert_ne(got, 115, "must NOT be 115 — round()/ceil() would produce that (wrong)")
	assert_eq(roundi(164.0 * 0.70), 115, "sanity: round() path is the 115 wrong answer")


func test_move_f1_discriminating_floor_signature() -> void:
	# df1=187, SIGNATURE 1.40 → 261.8 → floor = 261 (round/ceil give 262).
	var got := MovePowerFormulaScript.move_damage(187, MoveDef.PowerTier.SIGNATURE, _cfg)
	assert_eq(got, 261, "187 × 1.40 floors to 261")
	assert_ne(got, 262, "must NOT be 262 — round()/ceil() would produce that (wrong)")


func test_move_f1_standard_identity_sanity() -> void:
	# df1=164, STANDARD 1.00 → 164 (no scaling — proves ×1.0 is a true identity).
	assert_eq(MovePowerFormulaScript.move_damage(164, MoveDef.PowerTier.STANDARD, _cfg), 164,
		"164 × 1.00 = 164 (identity sanity)")


# ---------------------------------------------------------------------------
# AC-2 (AC-MDB-03): load-bearing epsilon + floor clamp
# ---------------------------------------------------------------------------

func test_move_f1_epsilon_load_bearing_signature_165() -> void:
	# df1=165, SIGNATURE 1.40 = 230.99999999999997 in IEEE-754.
	# With epsilon → 231; bare floor → 230 (WRONG).
	var got := MovePowerFormulaScript.move_damage(165, MoveDef.PowerTier.SIGNATURE, _cfg)
	assert_eq(got, 231, "165 × 1.40 rounds to 231 with the load-bearing epsilon")
	assert_eq(_bare_floor(165, MoveDef.PowerTier.SIGNATURE), 230,
		"the epsilon-omitted path returns 230 — proving the nudge is load-bearing")
	assert_ne(got, _bare_floor(165, MoveDef.PowerTier.SIGNATURE),
		"formula result differs from the bare-floor wrong answer")


func test_move_f1_epsilon_load_bearing_basic_90() -> void:
	# df1=90, BASIC 0.70 → with epsilon 63; bare floor 62 (WRONG).
	var got := MovePowerFormulaScript.move_damage(90, MoveDef.PowerTier.BASIC, _cfg)
	assert_eq(got, 63, "90 × 0.70 rounds to 63 with the load-bearing epsilon")
	assert_eq(_bare_floor(90, MoveDef.PowerTier.BASIC), 62,
		"the epsilon-omitted path returns 62 — proving the nudge is load-bearing")


func test_move_f1_all_ten_load_bearing_inputs() -> void:
	# The complete python3-scanned load-bearing set: every one flips without epsilon.
	# 0.70 × {90,170,180} and 1.40 × {45,85,90,165,170,175,180}.
	var cases := [
		[MoveDef.PowerTier.BASIC, 90, 63], [MoveDef.PowerTier.BASIC, 170, 119],
		[MoveDef.PowerTier.BASIC, 180, 126],
		[MoveDef.PowerTier.SIGNATURE, 45, 63], [MoveDef.PowerTier.SIGNATURE, 85, 119],
		[MoveDef.PowerTier.SIGNATURE, 90, 126], [MoveDef.PowerTier.SIGNATURE, 165, 231],
		[MoveDef.PowerTier.SIGNATURE, 170, 238], [MoveDef.PowerTier.SIGNATURE, 175, 245],
		[MoveDef.PowerTier.SIGNATURE, 180, 252],
	]
	for c in cases:
		var tier: int = c[0]
		var df1: int = c[1]
		var expected: int = c[2]
		var got := MovePowerFormulaScript.move_damage(df1, tier, _cfg)
		assert_eq(got, expected,
			"df1=%d tier=%d → %d (epsilon load-bearing)" % [df1, tier, expected])
		assert_eq(_bare_floor(df1, tier), expected - 1,
			"df1=%d tier=%d bare-floor is exactly one low (%d)" % [df1, tier, expected - 1])


func test_move_f1_min_clamp_never_zero() -> void:
	# df1=1, BASIC 0.70 → floor(0.7001) = 0 → clamped to DAMAGE_FLOOR (1).
	var got := MovePowerFormulaScript.move_damage(1, MoveDef.PowerTier.BASIC, _cfg)
	assert_eq(got, 1, "df1=1 × 0.70 clamps to the DAMAGE_FLOOR of 1, never 0")
	assert_eq(MovePowerFormulaScript.DAMAGE_FLOOR, 1, "DAMAGE_FLOOR is 1")


# ---------------------------------------------------------------------------
# AC-3 (AC-MDB-04): tier ceilings / absolute range
# ---------------------------------------------------------------------------

func test_move_f1_tier_ceilings_at_max_df1() -> void:
	# df1=225 is the DF-1 output ceiling. Each tier's peak:
	assert_eq(MovePowerFormulaScript.move_damage(225, MoveDef.PowerTier.HEAVY, _cfg),     270, "HEAVY @ 225 → 270")
	assert_eq(MovePowerFormulaScript.move_damage(225, MoveDef.PowerTier.SIGNATURE, _cfg), 315, "SIGNATURE @ 225 → 315")


func test_move_f1_output_never_exceeds_315() -> void:
	# 315 is the absolute output ceiling (SIGNATURE × the DF-1 max). Sweep every
	# tier across the full DF-1 range and confirm nothing exceeds it.
	for tier in [MoveDef.PowerTier.BASIC, MoveDef.PowerTier.LIGHT, MoveDef.PowerTier.STANDARD,
			MoveDef.PowerTier.HEAVY, MoveDef.PowerTier.SIGNATURE]:
		for df1 in range(1, 226):
			var got := MovePowerFormulaScript.move_damage(df1, tier, _cfg)
			assert_true(got <= 315, "output %d (df1=%d tier=%d) must not exceed 315" % [got, df1, tier])
			assert_true(got >= 1, "output %d must never drop below the DAMAGE_FLOOR" % got)
