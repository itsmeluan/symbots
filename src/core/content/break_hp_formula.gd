## BreakHpFormula — pure EDB-1 derivation for enemy break-region HP (Enemy Database).
##
## One pure static function implementing GDD Formula EDB-1:
##   `max(BREAK_HP_MIN, floor(structure × region_fraction + 0.0001))`
##
## The `+0.0001` epsilon is LOAD-BEARING (TR-edb-003, project memory
## `float-epsilon-empirics`). IEEE-754 stores 180×0.35 as 62.9999999…; without
## the nudge it floors to 62 instead of the correct 63. See test AC-1 for the
## live proof — remove the epsilon and that test goes red.
##
## This function is the single derivation path for both:
##   - Story 006 ContentValidator (`_check_enemy_break_region` asserts
##     authored `break_hp == derive_break_hp(structure, region_fraction)`)
##   - Any future authoring tool that needs to pre-compute the value.
##
## Usage: `BreakHpFormula.derive_break_hp(structure, region_fraction)`
## Never instanced — call statically.
##
## Fixtures python3-verified 2026-07-16 (see break_hp_formula_test.gd header).
class_name BreakHpFormula
extends RefCounted

## Minimum break-HP floor (GDD EDB-1 / TR-edb-003). Named constant — never
## inline the literal 5 in derivations or validators (coding-standards,
## Story 003 Control Manifest). Story 006 may reference this via BreakHpFormula.BREAK_HP_MIN.
const BREAK_HP_MIN := 5

## EDB-1: `max(BREAK_HP_MIN, floor(structure × region_fraction + 0.0001))`.
##
## [param structure] — the enemy's raw `structure` stat (from its stats Dictionary).
## [param region_fraction] — the authored `region_fraction` for the break region
## (float in [0.15, 0.55] per TR-edb-014; validator enforces that bound, not this
## formula).
##
## Returns the derived break-HP as an [int] in the range [BREAK_HP_MIN, 330].
##
## [b]Epsilon note[/b]: the `+0.0001` nudge is LOAD-BEARING and must not be removed,
## rounded away, or changed in magnitude. Proof: `180 × 0.35` is represented as
## `62.9999999…` in IEEE-754 float — without the nudge `floor()` returns 62; with
## the nudge it returns 63. The discriminating case `85 × 0.35 = 29.7499…` confirms
## the nudge is small enough NOT to bump a legitimately sub-integer value to the
## next integer (floor(29.7499 + 0.0001) = floor(29.7500) = 29, not 30).
static func derive_break_hp(structure: int, region_fraction: float) -> int:
	return maxi(BREAK_HP_MIN, int(floor(structure * region_fraction + 0.0001)))
