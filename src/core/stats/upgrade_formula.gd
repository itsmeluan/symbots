## UpgradeFormula — GDD Formula 2 / Formula 2b per-part upgrade math (ADR-0005 Layer 1).
##
## Pure, stateless, static-only. Constants arrive via an injected [BalanceConfig]
## ([member BalanceConfig.upgrade_multipliers]); nothing is read from a global.
## Every function is a direct input→output mapping, GUT-testable against the GDD's
## discriminating worked examples (base=13 → [13,14,16,19,22,26]; base=-15 →
## [-15,-10,-5,0,0,0]) — where floor ≠ round ≠ ceil, so a wrong rounding mode fails.
##
## [b]Sign-routing is the composition point.[/b] Formula 1 (Story 005) NEVER
## receives raw `stat_bonuses[S]`: each stat is routed by sign here first —
## `> 0` → Formula 2, `< 0` → Formula 2b (Prototype drawbacks), `= 0` → 0 —
## and F2 / F2b run independently per stat with no cross-contamination.
##
## The frozen [PartDef] is read-only (ADR-0003): stat values are read via
## `stat_bonuses.get(...)`, never mutated.
class_name UpgradeFormula
extends RefCounted

## The upgrade tier below which a Formula-2b drawback is fully removed. Structural
## to F2b's shape (`1 − tier/3`), not a tuning knob — reduce a penalty by one-third
## per tier, reaching zero at +3. Kept inline (not in [BalanceConfig]) for the same
## reason as EPSILON: it defines the formula, it does not tune it.
const DRAWBACK_TIERS_TO_ZERO := 3.0


## True when [param part] may be upgraded to [param tier] — i.e. the tier is within
## the part's [member PartDef.max_upgrade_tier] (Common = 3, Rare+ = 5). This is the
## behavioral +3 hard cap (TR-part-010); the Workshop UI enforces the button gating.
static func can_upgrade(part: PartDef, tier: int) -> bool:
	return tier >= 0 and tier <= part.max_upgrade_tier


## Formula 2: `floor(base_stat × upgrade_multiplier[tier] + ε)`.
## [param base_stat] must be ≥ 0 (negative stats route to [method upgraded_drawback]).
## [param tier] is clamped into the multiplier table's bounds; callers cap it to the
## part's max tier via [method upgraded_value_for_part].
static func upgraded_stat(base_stat: int, tier: int, cfg: BalanceConfig) -> int:
	var t := clampi(tier, 0, cfg.upgrade_multipliers.size() - 1)
	return StatMath.floor_eps(float(base_stat) * cfg.upgrade_multipliers[t])


## Formula 2b: `-ceil(abs(base_stat) × max(0, 1 − tier/3) − ε)` — reduces a Prototype
## drawback toward zero, never past it. The `max(0, …)` clamp is LOAD-BEARING: without
## it, tiers +4/+5 double-negate a penalty into a positive stat (GDD BLOCK-6). Tiers
## +3/+4/+5 all yield 0. [param base_stat] is expected ≤ 0; its magnitude is used.
static func upgraded_drawback(base_stat: int, tier: int) -> int:
	var scale := maxf(0.0, 1.0 - float(tier) / DRAWBACK_TIERS_TO_ZERO)
	return -StatMath.ceil_eps(absf(float(base_stat)) * scale)


## Sign-router (GDD Formula Pipeline, Prototype variant): the single value a part
## contributes for one stat at [param tier]. `> 0` → Formula 2, `< 0` → Formula 2b,
## `= 0` → 0. F2 and F2b run on the same source independently.
static func upgraded_value(base_stat: int, tier: int, cfg: BalanceConfig) -> int:
	if base_stat > 0:
		return upgraded_stat(base_stat, tier, cfg)
	if base_stat < 0:
		return upgraded_drawback(base_stat, tier)
	return 0


## Part-level entry point: resolves [param stat] from the part's frozen
## [member PartDef.stat_bonuses], caps [param tier] at the part's max upgrade tier
## (the silent +3 cap for Commons — no throw), and sign-routes via
## [method upgraded_value]. Each stat is resolved independently (AC-16: no
## cross-contamination between a part's negative stats).
static func upgraded_value_for_part(part: PartDef, stat: StringName, tier: int, cfg: BalanceConfig) -> int:
	var capped_tier := clampi(tier, 0, part.max_upgrade_tier)
	var base_stat: int = part.stat_bonuses.get(stat, 0)
	return upgraded_value(base_stat, capped_tier, cfg)
