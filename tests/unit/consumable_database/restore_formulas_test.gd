## Consumable-DB Story 003 — CD-1/2/3 restore formulas.
##
## Covers AC-CD-01 (CD-1 restore_structure applies + caps), AC-CD-02 (CD-2 reduce_heat
## applies + floors), AC-CD-03 (CD-3 restore_energy applies + caps at the RUNTIME max —
## case C `(130,147,25)==147` catches a hardcoded-120 ceiling). Each AC pairs a
## clamp-firing case with a no-clamp case so a wrong-formula-but-correct-clamp impl
## can't pass. Pure integer arithmetic — no floor/ceil. GUT · Godot 4.7.
extends GutTest


# ---------------------------------------------------------------------------
# AC-CD-01 — CD-1 RESTORE_STRUCTURE
# ---------------------------------------------------------------------------

func test_cd1_clamps_at_max() -> void:
	# Weld Patch amount=25, current 50 / max 60 → 60 (clamped, not 75).
	assert_eq(ConsumableEffects.restore_structure(50, 60, 25), 60)

func test_cd1_no_clamp_when_headroom() -> void:
	# current 30 / max 594 + 50 → 80 (no clamp). An impl omitting min() returns 75
	# in the clamp case; this proves the add path is correct too.
	assert_eq(ConsumableEffects.restore_structure(30, 594, 50), 80)


# ---------------------------------------------------------------------------
# AC-CD-02 — CD-2 REDUCE_HEAT
# ---------------------------------------------------------------------------

func test_cd2_floors_at_zero() -> void:
	# Coolant Flush amount=50, current 30 → 0 (floored, not −20).
	assert_eq(ConsumableEffects.reduce_heat(30, 50), 0)

func test_cd2_no_floor_when_headroom() -> void:
	# current 80 − 50 → 30 (no floor). An impl omitting max(0,…) returns −20 above.
	assert_eq(ConsumableEffects.reduce_heat(80, 50), 30)


# ---------------------------------------------------------------------------
# AC-CD-03 — CD-3 RESTORE_ENERGY (runtime max, no hardcoded ceiling)
# ---------------------------------------------------------------------------

func test_cd3_clamps_at_runtime_max() -> void:
	# Power Cell amount=25, current 90 / max 100 → 100 (clamped, not 115).
	assert_eq(ConsumableEffects.restore_energy(90, 100, 25), 100)

func test_cd3_no_clamp_when_headroom() -> void:
	# current 50 / max 80 + 25 → 75 (no clamp).
	assert_eq(ConsumableEffects.restore_energy(50, 80, 25), 75)

func test_cd3_caps_at_leveled_core_max_not_hardcoded_120() -> void:
	# Case C — the sole catch for a hardcoded-120 ceiling against an L10 leveled core.
	# current 130 / max 147 + 25 → 147, NOT 120 and NOT 155.
	assert_eq(ConsumableEffects.restore_energy(130, 147, 25), 147)
