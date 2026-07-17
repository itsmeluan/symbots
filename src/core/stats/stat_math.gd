## StatMath — numeric primitives shared by every stat formula (ADR-0005 Layer 1).
##
## Pure, stateless, static-only: call as `StatMath.floor_eps(x)` — never instanced.
## Its single job is to apply the GDD "Numeric precision note" epsilon discipline
## in exactly ONE place, so every multiply-then-round across Formulas 1/2/2b/3
## rounds identically.
##
## [b]EPSILON lives here, not in [BalanceConfig][/b]: the GDD marks it "not a
## tuning knob; fixed implementation constant" (DF-1), and ADR-0005 Layer 4
## deliberately excludes it from the tuning resource. Moving it to config would
## invite a balance pass to silently break the load-bearing F2b nudge.
class_name StatMath
extends RefCounted

## Fixed rounding epsilon (ADR-0005 / GDD Numeric precision note). NOT a tuning
## knob — do not relocate to [BalanceConfig], do not remove based on current-range
## behavior. F2b's nudge is empirically load-bearing (26 inputs flip without it).
const EPSILON := 0.0001

## floor(value + EPSILON) → int. The standard multiply-then-floor step for
## Formulas 1 and 2. Example: floor_eps(19.5) == 19 (not 20 — floor, not round).
static func floor_eps(value: float) -> int:
	return floori(value + EPSILON)

## ceil(value - EPSILON) → int. Formula 2b's penalty-reduction rounding.
## Example: ceil_eps(10.000000000000002) == 10 (the nudge cancels the float error
## that would otherwise ceil to 11).
static func ceil_eps(value: float) -> int:
	return ceili(value - EPSILON)

## SYN-F4 — the single stat-composition clamp `max(0, base + synergy_delta + aura)`
## (GDD Rule 10; ADR-0005). [param base_final] is the frozen SA-F1/CP-F3 `final_stat`
## dict; [param synergy_delta] is the frozen `cached_bonus_block["stat_delta"]`;
## [param passive_aura] is the frozen PERSISTENT-passive aura (Story 013 — empty in
## MVP). A stat absent from any block reads 0. Pure integer arithmetic — no epsilon.
##
## This is the ONE place synergy + aura fold into a base stat; the damage pipeline,
## repair, and status potency all read through it (or its [CombatantSnapshot] wrapper),
## never re-summing inline (`inline_stat_composition` forbidden).
static func effective_stat(base_final: Dictionary, synergy_delta: Dictionary,
		passive_aura: Dictionary, key: StringName) -> int:
	var base: int = int(base_final.get(key, 0))
	var syn: int = int(synergy_delta.get(key, 0))
	var aura: int = int(passive_aura.get(key, 0))
	return maxi(0, base + syn + aura)
