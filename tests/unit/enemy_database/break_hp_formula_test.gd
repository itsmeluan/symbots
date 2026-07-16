## Enemy-Database Story 003 — EDB-1 break_hp derivation formula.
##
## Covers:
##   AC-1 (epsilon load-bearing): 180×0.35 → 63, not 62.
##          python3 proof: math.floor(180*0.35) == 62 (WITHOUT epsilon);
##                         math.floor(180*0.35 + 0.0001) == 63 (WITH epsilon).
##          This is the whole reason the +0.0001 nudge exists. If a future refactor
##          drops or changes the epsilon, this test MUST go red.
##   AC-2 (discriminating floor): 85×0.35 → 29 (floor ≠ round(30) ≠ ceil(30)).
##          python3: math.floor(85*0.35 + 0.0001) == 29.
##          Proves the epsilon is small enough NOT to bump a legitimately below-
##          boundary value (29.7499… + 0.0001 = 29.7500…, floor = 29, not 30).
##   AC-3 (BREAK_HP_MIN clamp): 20×0.15 → 5 (raw 3.0, clamped up to min).
##          python3: max(5, math.floor(20*0.15 + 0.0001)) == 5.
##   AC-4 (happy path): 160×0.55 → 88 (clean integer product, no clamp).
##          python3: max(5, math.floor(160*0.55 + 0.0001)) == 88.
##   AC-5 (happy path): 100×0.40 → 40 (clean integer product, no clamp).
##          python3: max(5, math.floor(100*0.40 + 0.0001)) == 40.
##
## All pass-values python3-verified 2026-07-16 with and without epsilon.
## Framework: GUT · Godot 4.7.
extends GutTest


# ---------------------------------------------------------------------------
# AC-1 — epsilon load-bearing (TR-edb-003)
# ---------------------------------------------------------------------------

func test_derive_break_hp_180_x_035_epsilon_proof_returns_63() -> void:
	# Arrange / Act / Assert
	# 180 × 0.35 is stored as 62.9999999... in IEEE-754 float.
	# WITHOUT the +0.0001 epsilon, floor() returns 62 — wrong.
	# WITH the epsilon,         floor() returns 63 — correct.
	# If this case starts returning 62, the epsilon has been removed or modified.
	assert_eq(BreakHpFormula.derive_break_hp(180, 0.35), 63,
		"180×0.35 must return 63 (epsilon rescues 62.9999… → 63)")

func test_derive_break_hp_constant_break_hp_min_is_five() -> void:
	# The named constant must equal 5 — a rename or value change breaks the
	# validator (Story 006) that uses BreakHpFormula.BREAK_HP_MIN directly.
	assert_eq(BreakHpFormula.BREAK_HP_MIN, 5,
		"BREAK_HP_MIN must equal 5")


# ---------------------------------------------------------------------------
# AC-2 — discriminating floor (floor ≠ round ≠ ceil)
# ---------------------------------------------------------------------------

func test_derive_break_hp_85_x_035_discriminating_floor_returns_29() -> void:
	# Arrange / Act / Assert
	# 85 × 0.35 = 29.7499…. floor = 29, round = 30, ceil = 30.
	# Proves floor() is used (not round/ceil), AND that the +0.0001 epsilon
	# does NOT push 29.7499 + 0.0001 = 29.7500 to the next integer (floor = 29).
	assert_eq(BreakHpFormula.derive_break_hp(85, 0.35), 29,
		"85×0.35 must return 29 (floor=29, not round/ceil=30; epsilon must not bump to 30)")


# ---------------------------------------------------------------------------
# AC-3 — BREAK_HP_MIN clamp
# ---------------------------------------------------------------------------

func test_derive_break_hp_20_x_015_clamps_up_to_break_hp_min() -> void:
	# Arrange / Act / Assert
	# 20 × 0.15 = 3.0. floor(3.0 + 0.0001) = 3. max(5, 3) = 5.
	# A missing clamp returns 3 and fails; a wrong min value returns something else.
	assert_eq(BreakHpFormula.derive_break_hp(20, 0.15), 5,
		"20×0.15=3.0 must be clamped up to BREAK_HP_MIN=5")


# ---------------------------------------------------------------------------
# AC-4 — happy path: clean integer product, no clamp
# ---------------------------------------------------------------------------

func test_derive_break_hp_160_x_055_returns_88() -> void:
	# Arrange / Act / Assert
	# 160 × 0.55 = 88.0 (exact in float). floor(88.0 + 0.0001) = 88. max(5,88)=88.
	assert_eq(BreakHpFormula.derive_break_hp(160, 0.55), 88,
		"160×0.55=88.0 must return 88")


# ---------------------------------------------------------------------------
# AC-5 — happy path: clean integer product, no clamp
# ---------------------------------------------------------------------------

func test_derive_break_hp_100_x_040_returns_40() -> void:
	# Arrange / Act / Assert
	# 100 × 0.40 = 40.0 (exact in float). floor(40.0 + 0.0001) = 40. max(5,40)=40.
	assert_eq(BreakHpFormula.derive_break_hp(100, 0.40), 40,
		"100×0.40=40.0 must return 40")
