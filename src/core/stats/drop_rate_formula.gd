## DropRateFormula — GDD Formula 3, the effective drop probability.
##
## Pure, stateless, static-only; homed in the ADR-0005 "pure formula core"
## (`src/core/stats/`) though governed by ADR-0003 (content). It computes ONLY the
## probability — `clamp(base_drop_rate × Πmultipliers, 0, 1)` — and never draws
## against it: the RNG roll is the Drop System's (ADR-0006/0007), so no
## [RandomNumberGenerator] appears here. That keeps it deterministic and trivially
## unit-testable.
##
## Per ADR-0003 the base rate is a rarity CONSTANT sourced from [BalanceConfig]
## ([member BalanceConfig.drop_rate_by_rarity]) — [b]not[/b] a per-part field. The
## matching of `drop_conditions` against live battle state is the Drop System's
## job; this function receives the already-matched conditions.
class_name DropRateFormula
extends RefCounted

## Multiplier applied by a `drop_conditions` entry that lacks an explicit
## `"multiplier"` key — inert (no effect on the product).
const DEFAULT_MULTIPLIER := 1.0


## Formula 3: `clamp(base_drop_rate[rarity] × product(condition multipliers), 0, 1)`.
##
## [param rarity] is a [enum PartDef.Rarity] value; its base rate is looked up from
## [param cfg]. [param matching_conditions] are the `drop_conditions` entries
## (`{ "condition": StringName, "multiplier": float }`) that the Drop System has
## already determined fired — their multipliers stack multiplicatively. With no
## matching conditions the product is 1.0, so the result is the bare base rate
## (e.g. Boss-grade 0.001, NOT 0.0). The output is always clamped to [0.0, 1.0].
static func compute_effective_drop_rate(
		rarity: PartDef.Rarity,
		matching_conditions: Array[Dictionary],
		cfg: BalanceConfig) -> float:
	var base_rate: float = cfg.drop_rate_by_rarity[rarity]
	var product := 1.0
	for condition in matching_conditions:
		product *= float(condition.get("multiplier", DEFAULT_MULTIPLIER))
	return clampf(base_rate * product, 0.0, 1.0)
