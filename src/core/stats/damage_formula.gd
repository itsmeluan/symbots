## DamageFormula — the single pure damage kernel (ADR-0005 Layer 1, Formula DF-1).
##
## Pure, stateless, static-only: call as `DamageFormula.compute_damage(...)` —
## never instanced. It is the sole composition point every damage calculation in
## the game routes through, so the float-cast, single-floor, and division-by-zero
## discipline lives in exactly ONE place (GDD DF-1; TR-df-001).
##
## [b]Reads no runtime state, rolls no RNG[/b] (TR-df-001; ADR-0006). The crit
## multiplier is an INJECTED parameter (default 1.0) — the formula is deterministic
## (GDD Rule 5); Turn-Based Combat vends `crit_mult` from its seeded RNG and passes
## it in. `type_mult` (the derived T) and `crit_mult` are multiplied PRE-floor so a
## single floor applies to the whole product (TR-df-002).
##
## Story 001 delivers this kernel + the `damage_floor` tuning field. Story 002 adds
## the `type_effectiveness` chart lookup (derives T); Story 003 adds `resolve`, the
## routed entry point that binds A/D from stats by damage_type and calls this kernel.
class_name DamageFormula
extends RefCounted

## DF-1 pure kernel: `final = max(DAMAGE_FLOOR, floor(A²/(A+D) × T × crit))`.
##
## [param a]/[param d] are the already-bound attack / defense stats (Story 003
## binds them by damage_type); [param type_mult] is the already-derived type
## effectiveness T (Story 002 looks it up); [param crit_mult] is the injected crit
## multiplier (1.0 = no crit). [param cfg] supplies the tunable `damage_floor`;
## [param log] is the injected diagnostics channel (unused on the happy path — kept
## for signature stability; never call `push_error`/`push_warning`, ADR-0002 §5).
##
## The `a == 0 and d == 0` guard returns the floor BEFORE any division so the
## degenerate `0/0` never produces NaN (TR-df-006). Every other path casts to float
## before dividing (`53*53/83` truncates to 33 in int math — the cast is load-
## bearing, TR-df-004) and applies [method StatMath.floor_eps] — the ONE shared
## epsilon-floor, never a second epsilon (ADR-0005).
static func compute_damage(a: int, d: int, type_mult: float, cfg: BalanceConfig,
		log: LogSink, crit_mult: float = 1.0) -> int:
	if a == 0 and d == 0:  # TR-df-006 — guard BEFORE the division (avoids 0/0 → NaN)
		return cfg.damage_floor
	var base := float(a) * float(a) / (float(a) + float(d))  # TR-df-004 float cast
	var pre_floor := base * type_mult * crit_mult            # TR-df-002 pre-floor T & crit
	return maxi(cfg.damage_floor, StatMath.floor_eps(pre_floor))  # TR-df-005 floor after


## Pure Part DB Rule 6 chart lookup — the SINGLE source of the type multiplier T
## for both DF-1 (Story 003 binds it into [method compute_damage]) AND the Combat UI
## pre-commit effectiveness glyph (GDD Open Question 1 / ADR-0008 `inline_stat_
## composition`): the two readings share this one function so they can never disagree.
##
## [param skill_element] / [param target_core_element] are the attacking skill's and
## defending Core's [enum PartDef.Element] values. They are INTENTIONALLY untyped so a
## literal `null` (a Core with no element, or a Full-Vision-reserved element with no
## authored row) flows straight to the nested `.get()` default — typing them `int`
## would raise on `null` before the fallback runs. Any absent / null / unrecognized
## element on EITHER side degrades to a neutral ×1.0 with no branch (GDD EC-04/EC-05):
## it is valid content, never a crash. The ratios themselves are locked in Part DB
## Rule 6 — this reads and applies them, it never redefines them (GDD Rule 2).
static func type_effectiveness(skill_element, target_core_element,
		cfg: BalanceConfig) -> float:
	return float(cfg.type_chart.get(skill_element, {}).get(target_core_element, 1.0))
