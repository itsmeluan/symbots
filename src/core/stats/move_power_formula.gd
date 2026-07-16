## MovePowerFormula — MOVE-F1: applies a move's power-tier multiplier to DF-1's
## integer damage output (Move DB Formula 1, ADR-0005 Layer 1).
##
## Pure, stateless, static-only: call as `MovePowerFormula.move_damage(...)` —
## never instanced. It multiplies DF-1's *output* by the tier coefficient that
## makes a Signature strike hit harder than a Light jab on the same power stat.
##
## [b]DF-1 is UNCHANGED[/b] (guardrail): MOVE-F1 takes DF-1's already-computed
## integer as input; it never calls or modifies DF-1. The full pipeline
## `DF-1 → MOVE-F1 → TBC-F5` composition test is owned by the Damage-Formula / TBC
## epics once those formulas exist in code.
##
## [b]The epsilon is LOAD-BEARING[/b]: `StatMath.floor_eps` adds `StatMath.EPSILON`
## (0.0001) before flooring. Without it, 10 of 1,125 inputs floor to the wrong
## integer — e.g. `165 × 1.40 = 230.99999999999997` in IEEE-754 → bare `floor()`
## gives 230 (wrong); the nudge gives 231. Full load-bearing set (python3-scanned):
## `0.70 × {90, 170, 180}` and `1.40 × {45, 85, 90, 165, 170, 175, 180}`. Reuse
## `StatMath.floor_eps` — never introduce a second epsilon. Re-run the scan if any
## multiplier in [member BalanceConfig.power_tier_multipliers] is retuned.
class_name MovePowerFormula
extends RefCounted

## Minimum damage a DAMAGE move can deal after the multiply (never 0 — a landed
## hit always does at least 1). Clamps the low end, e.g. `df1=1, BASIC 0.70` →
## `max(1, floor(0.7001)) = 1`.
const DAMAGE_FLOOR := 1

## MOVE-F1 = `max(DAMAGE_FLOOR, floor(df1_output × power_mult + EPSILON))`.
##
## [param df1_output] is DF-1's integer damage before the tier multiplier.
## [param power_tier] selects the coefficient from [param cfg]. Returns the
## post-tier integer damage, clamped to [constant DAMAGE_FLOOR] at the low end.
##
## Uses [method StatMath.floor_eps] for the load-bearing rounding. The tier
## multiplier is the single tuning source — injected via [param cfg], never
## hardcoded here.
static func move_damage(df1_output: int, power_tier: MoveDef.PowerTier, cfg: BalanceConfig) -> int:
	var power_mult: float = cfg.power_tier_multipliers[power_tier]
	return maxi(DAMAGE_FLOOR, StatMath.floor_eps(float(df1_output) * power_mult))
