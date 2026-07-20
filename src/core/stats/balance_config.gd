## BalanceConfig — the single data-driven tuning Resource (ADR-0005 Layer 4).
##
## One authored `.tres` (`assets/data/balance_config.tres`) is loaded once at boot
## and injected into every Layer-1/Layer-2 stat construct; balance retuning is then
## a one-file diff, validated at boot + CI by ContentValidator (Stories 007+).
##
## [b]Fields are APPEND-ONLY.[/b] Later stories add their tables (`xp_thresholds`,
## `chassis_modifiers`, `type_chart`, `bench_xp_share`, …) without renaming or
## reordering existing ones — same discipline as the reserved schema fields in
## PartDef. This story (004) introduces only [member upgrade_multipliers].
##
## EPSILON is deliberately NOT here — it is a fixed const in [StatMath], not a
## tuning knob (ADR-0005; GDD Numeric precision note).
##
## The `@export` defaults below mirror the GDD tier table so a bare
## `BalanceConfig.new()` is valid for unit tests (DI). The authored `.tres` is the
## production source of truth and is asserted equal to the GDD by ContentValidator.
class_name BalanceConfig
extends Resource

## Formula 2 per-tier stat multiplier, indexed by upgrade tier (0–5).
## GDD tier table: +0 ×1.00, +1 ×1.15, +2 ×1.30, +3 ×1.50, +4 ×1.70, +5 ×2.00.
@export var upgrade_multipliers: Array[float] = [1.00, 1.15, 1.30, 1.50, 1.70, 2.00]

## Formula 3 per-rarity base drop rate, indexed by the [enum PartDef.Rarity] value
## (1=Common, 2=Rare, 3=Boss-grade, 4=Prototype). Index 0 is the reserved/invalid
## rarity sentinel and is never looked up. GDD Formula 3 table.
## [b]Boss-grade MUST stay 0.001, never 0.0[/b] — a zero base makes every drop-
## condition multiplier inert (the formula is multiplicative). ADR-0003: this is
## the rarity-constant base; `base_drop_rate` is NOT a per-part field.
@export var drop_rate_by_rarity: Array[float] = [0.0, 0.70, 0.25, 0.001, 0.05]

## Formula 1 Chassis archetype stat modifiers. Outer key = [enum
## PartDef.ChassisArchetype] value; inner key = canonical stat StringName; value =
## the per-stat multiplier. Stored SPARSE — only the non-×1.0 entries appear; every
## stat absent from an archetype's inner dict (and every archetype absent from the
## outer dict) resolves to ×1.0 via the formula's `.get(S, 1.0)`. Mirrors the GDD
## Formula 1 "Chassis modifier table" exactly (the complete, authoritative source —
## no modifier exists outside it). Untyped [Dictionary] because the value is itself
## a nested per-stat dictionary; `.get()` reads keep it robust to absent keys.
@export var chassis_modifiers: Dictionary = {
	PartDef.ChassisArchetype.LIGHT_FRAME: {&"structure": 0.85, &"mobility": 1.20},
	PartDef.ChassisArchetype.HEAVY_FRAME: {&"structure": 1.25, &"armor": 1.20, &"mobility": 0.80},
	PartDef.ChassisArchetype.BALANCED_FRAME: {&"processing": 1.05, &"cooling": 1.05},
	PartDef.ChassisArchetype.GUARDIAN_FRAME: {&"resistance": 1.20, &"physical_power": 0.85},
	PartDef.ChassisArchetype.ARTILLERY_FRAME: {&"armor": 0.85, &"energy_power": 1.20},
}

## Content-authoring positive stat-point budgets (GDD Stat Budget Reference,
## AC-12) — the primary content balance lever. Outer key = [enum
## PartDef.SlotType]; inner key = [enum PartDef.Rarity]; value = `[min, max]`
## inclusive bounds on `sum(max(0, v) for v in stat_bonuses.values())` (positive
## spend only — Prototype drawback penalties are NOT counted). Mirrors the GDD
## table verbatim. Untyped [Dictionary] because the value nests a per-rarity dict;
## `.get()` reads keep the validator robust to absent keys.
@export var stat_budgets: Dictionary = {
	PartDef.SlotType.CORE: {
		PartDef.Rarity.COMMON: [18, 22], PartDef.Rarity.RARE: [32, 38],
		PartDef.Rarity.BOSS_GRADE: [48, 55], PartDef.Rarity.PROTOTYPE: [35, 45],
	},
	PartDef.SlotType.CHASSIS: {
		PartDef.Rarity.COMMON: [22, 28], PartDef.Rarity.RARE: [38, 46],
		PartDef.Rarity.BOSS_GRADE: [55, 68], PartDef.Rarity.PROTOTYPE: [40, 55],
	},
	PartDef.SlotType.CHIPSET: {
		PartDef.Rarity.COMMON: [12, 16], PartDef.Rarity.RARE: [22, 28],
		PartDef.Rarity.BOSS_GRADE: [35, 42], PartDef.Rarity.PROTOTYPE: [28, 38],
	},
	PartDef.SlotType.ENERGY_CELL: {
		PartDef.Rarity.COMMON: [14, 18], PartDef.Rarity.RARE: [26, 32],
		PartDef.Rarity.BOSS_GRADE: [40, 48], PartDef.Rarity.PROTOTYPE: [32, 42],
	},
	PartDef.SlotType.HEAD: {
		PartDef.Rarity.COMMON: [12, 16], PartDef.Rarity.RARE: [22, 28],
		PartDef.Rarity.BOSS_GRADE: [35, 42], PartDef.Rarity.PROTOTYPE: [28, 38],
	},
	PartDef.SlotType.ARMS: {
		PartDef.Rarity.COMMON: [14, 18], PartDef.Rarity.RARE: [26, 32],
		PartDef.Rarity.BOSS_GRADE: [40, 48], PartDef.Rarity.PROTOTYPE: [32, 42],
	},
	PartDef.SlotType.LEGS: {
		PartDef.Rarity.COMMON: [14, 18], PartDef.Rarity.RARE: [24, 30],
		PartDef.Rarity.BOSS_GRADE: [38, 46], PartDef.Rarity.PROTOTYPE: [30, 40],
	},
	PartDef.SlotType.WEAPON: {
		PartDef.Rarity.COMMON: [16, 20], PartDef.Rarity.RARE: [28, 35],
		PartDef.Rarity.BOSS_GRADE: [45, 55], PartDef.Rarity.PROTOTYPE: [38, 50],
	},
}

## AC-23 Common primary-stat CAP per slot: every Common part's primary stat must be
## `<=` this value. Keyed by [enum PartDef.SlotType]. GDD caps/floors table verbatim
## (`cap = floor(0.70 × max Common budget)`).
@export var primary_stat_common_caps: Dictionary = {
	PartDef.SlotType.CORE: 15, PartDef.SlotType.CHASSIS: 19,
	PartDef.SlotType.CHIPSET: 11, PartDef.SlotType.ENERGY_CELL: 12,
	PartDef.SlotType.HEAD: 11, PartDef.SlotType.ARMS: 12,
	PartDef.SlotType.LEGS: 12, PartDef.SlotType.WEAPON: 14,
}

## AC-23 Rare primary-stat FLOOR per slot: every Rare part's primary stat must be
## `>=` this value. Keyed by [enum PartDef.SlotType]. GDD caps/floors table verbatim
## (`floor = floor(cap × 1.50) + 1`, guaranteeing a Rare at +0 beats any legal
## Common at +3 in the primary stat).
@export var primary_stat_rare_floors: Dictionary = {
	PartDef.SlotType.CORE: 23, PartDef.SlotType.CHASSIS: 29,
	PartDef.SlotType.CHIPSET: 17, PartDef.SlotType.ENERGY_CELL: 19,
	PartDef.SlotType.HEAD: 17, PartDef.SlotType.ARMS: 19,
	PartDef.SlotType.LEGS: 19, PartDef.SlotType.WEAPON: 22,
}

## MOVE-F1 per-tier power multiplier (Move DB Formula 1), indexed by the
## [enum MoveDef.PowerTier] value (1=BASIC … 5=SIGNATURE). Index 0 is the reserved/
## invalid tier sentinel and is never looked up — mirrors the
## [member drop_rate_by_rarity] index-0-reserved pattern. GDD MOVE-F1 tier table.
## [b]Cross-document, TTK-sensitive:[/b] `power_tier_multipliers[SIGNATURE]` is
## coupled to the MOVE-F1 range, TBC-F5's range, the DF-1 pipeline errata, and the
## TTK envelope — treat any change as a design decision requiring the epsilon
## re-scan and TBC re-derivation, not a tuning pass (GDD Tuning-Knob warning 1).
## The tiers must stay STRICTLY ORDERED BASIC < LIGHT < STANDARD < HEAVY < SIGNATURE
## or the tier taxonomy loses meaning (GDD Tuning-Knob warning 3).
@export var power_tier_multipliers: Array[float] = [0.0, 0.70, 0.80, 1.00, 1.20, 1.40]

## DF-1 minimum damage (GDD Formula DF-1 DAMAGE_FLOOR). Every `compute_damage`
## result is clamped up to at least this via `max(damage_floor, floor(...))`, so a
## landed hit always deals ≥1 — a chip of damage, never 0. GDD safe range 0–5;
## ContentValidator rejects a negative value. Default 1 keeps a bare
## `BalanceConfig.new()` valid for unit-test DI; the authored `.tres` is the source.
@export var damage_floor: int = 1

## DF-1 type-effectiveness chart (Part DB Rule 6 / GDD Rule 2) — the sole source of
## the multiplier T. Nested `skill Element → {target-Core Element → float}`, mirroring
## [member chassis_modifiers]' shape and the same nested typed-Dictionary `.tres`
## round-trip gate. Read exclusively via [method DamageFormula.type_effectiveness]
## with `.get(skill, {}).get(core, 1.0)`, so any absent cell (a null/reserved element
## on either axis) resolves to a neutral ×1.0 (GDD EC-04/EC-05) — the 3×3 VOLT/THERMAL/
## KINETIC grid below is the complete MVP set; reserved elements are deliberately
## absent and inherit the ×1.0 default. Values are LOCKED at Rule 6 (×1.5 super, ×1.0
## neutral, ×0.75 resisted) — retuning is a design decision, not a balance pass, and
## ContentValidator asserts every cell stays ∈ {0.75, 1.0, 1.5}. Untyped [Dictionary]
## because the value is itself a nested per-element dict (same reason as
## [member chassis_modifiers]).
@export var type_chart: Dictionary = {
	PartDef.Element.VOLT:    {PartDef.Element.VOLT: 1.0, PartDef.Element.THERMAL: 1.5, PartDef.Element.KINETIC: 0.75},
	PartDef.Element.THERMAL: {PartDef.Element.VOLT: 0.75, PartDef.Element.THERMAL: 1.0, PartDef.Element.KINETIC: 1.5},
	PartDef.Element.KINETIC: {PartDef.Element.VOLT: 1.5, PartDef.Element.THERMAL: 0.75, PartDef.Element.KINETIC: 1.0},
}

## The canonical 11 Symbot stat keys, in GDD order (design/gdd/symbot-assembly.md
## §"The 11 canonical MVP stat keys"). SA-F1 ([StatPipeline.derive]) iterates THIS
## list — never the union of the equipped parts' `stat_bonuses` keys — so every
## `final_stat` carries all 11 entries even when no part contributes to a stat
## (downstream present-key assertions like `final_stat["targeting"]==0` depend on
## this). A part key outside this list is a content error: skipped with a warning
## (EC-SA-05). Distinct from the Enemy DB stat vocabulary, which swaps `targeting`
## for `output_power` (enemies have no player-facing targeting stat). APPEND-ONLY
## like every field here; the default lets a bare `BalanceConfig.new()` serve DI
## unit tests without loading the authored `.tres`.
@export var canonical_stat_keys: Array[StringName] = [
	&"structure", &"armor", &"resistance", &"physical_power", &"energy_power",
	&"mobility", &"targeting", &"processing", &"cooling", &"energy_capacity",
	&"recharge",
]

# ---------------------------------------------------------------------------
# Turn-Based Combat tuning knobs (ADR-0005 / ADR-0007; GDD TBC-F1…F7).
# APPEND-ONLY, same discipline as every field above. Defaults mirror the GDD
# formula tables verbatim so a bare BalanceConfig.new() drives the TBC unit
# tests via DI; the authored `.tres` is the production source of truth.
# ---------------------------------------------------------------------------

## TBC-F2 universal per-turn energy gain (Rule 4.1b). Also the anti-stall brake
## reference (`REPAIR moves author energy_cost > this`). GDD range: fixed 10.
@export var base_energy_regen: int = 10

## TBC-F3 Burn DoT: `max(burn_min, floor(processing × burn_coeff + ε))`.
## GDD: BURN_COEFF = 0.08, BURN_MIN = 2. Bypasses DF-1 (direct structure loss).
@export var burn_coeff: float = 0.08
@export var burn_min: int = 2

## TBC-F4 Shock mobility reduction: `floor(processing × shock_coeff + ε)`, stored
## POSITIVE and subtracted by TBC-F1. GDD: SHOCK_COEFF = 0.3, output 0–33.
@export var shock_coeff: float = 0.3

## TBC-F5 Stagger: `stagger_pct = floor(processing × stagger_coeff + ε)` (0–27),
## then `max(1, floor(final_damage × (1 − pct/100) + ε))` post-MOVE-F1.
## GDD: STAGGER_COEFF = 0.25.
@export var stagger_coeff: float = 0.25

## TBC-F6 Repair: `max(repair_min, floor(energy_power × repair_coeff + repair_base + ε))`
## capped at max_structure. GDD: REPAIR_COEFF = 0.17, REPAIR_BASE = 5, REPAIR_MIN = 5.
@export var repair_coeff: float = 0.17
@export var repair_base: int = 5
@export var repair_min: int = 5

## TBC-F7 enemy enrage (Part-Break PB-F5, TBC-applied POST-Stagger):
## `max(1, floor(hit × (1 + broken_region_count × enrage_per_break) + ε))`.
## GDD: ENRAGE_PER_BREAK = 0.12 → multiplier ∈ {1.00, 1.12, 1.24, 1.36}.
## Part-Break-owned tuning knob — do not duplicate-tune; mirror it here only.
@export var enrage_per_break: float = 0.12

## PB-F3 break spillover fraction TBC applies on a region hit (Rule 10).
## GDD/Part-Break: BREAK_SPILLOVER = 0.20. Part-Break-owned; mirrored here.
@export var break_spillover: float = 0.20

## SYN-F4 consumer-side cumulative synergy `stat_delta` caps (DF-1 range contract).
## GDD: SYNERGY_POWER_BUDGET = 40 (physical_power / energy_power),
## SYNERGY_DEFENSE_BUDGET = 50 (armor / resistance). Content-validation ceilings.
@export var synergy_power_budget: int = 40
@export var synergy_defense_budget: int = 50

## Heat / overheat (Rule 5, Story 006). Heat is a 0–[member overheat_threshold] gauge.
## A move's heat gain (`gen + THERMAL bonus`) is clamped to the threshold; touching it
## trips OVERHEATED, dealing `floor(max_structure × overheat_self_damage_pct)` recoil.
## The overheated turn resets heat flat to [member overheat_reset_heat] (no decay that
## turn) and skips the action phase. Per-turn cooling itself is the combatant's
## effective `cooling` STAT (canonical key), not a global constant. GDD: THRESHOLD 100,
## SELF_DAMAGE 10%, RESET 20, THERMAL move heat bonus +5.
@export var overheat_threshold: int = 100
@export var overheat_self_damage_pct: float = 0.10
@export var overheat_reset_heat: int = 20
@export var thermal_move_heat_bonus: int = 5

# ---------------------------------------------------------------------------
# Drop System scrap-yield tuning (ADR-0003; GDD Drop System Rule 9). APPEND-ONLY.
# ---------------------------------------------------------------------------

## Rule 9 per-rarity Scrap yield when a part is scrapped, indexed by the
## [enum PartDef.Rarity] value (1=Common, 2=Rare, 3=Boss-grade, 4=Prototype).
## Index 0 is the reserved/invalid rarity sentinel and is never looked up — mirrors
## the [member drop_rate_by_rarity] index-0-reserved pattern. GDD Tuning Knobs:
## Common 5, Rare 20, Boss-grade 60, Prototype 35 (so the array reads
## `[_, 5, 20, 60, 35]` in enum-index order).
## [b]Load-bearing ordering invariant[/b] (DS-8 / AC-DS-19): read by VALUE the
## yields must satisfy `COMMON < RARE < PROTOTYPE < BOSS_GRADE` — deliberately NOT
## numeric-rarity-index order (Prototype 35 sits between Rare 20 and Boss-grade 60).
## No legal retune may invert a step; `DropSystem.get_scrap_yield` is the read seam
## and the DS-8 test asserts the three `<` comparisons programmatically.
@export var scrap_yield_by_rarity: Array[int] = [0, 5, 20, 60, 35]

# ---------------------------------------------------------------------------
# v1 battle tuning (design/v1/00-core-design.md §3). APPEND-ONLY, same discipline
# as every field above. Defaults let a bare BalanceConfig.new() drive the v1
# battle unit tests via DI; the authored `.tres` is the production source.
# ---------------------------------------------------------------------------

## Crit chance is derived from the `targeting` stat rather than being its own stat,
## so targeting stays worth investing in and the stat list does not grow. Chance in
## whole percent = `targeting / crit_targeting_divisor`, capped below.
@export var crit_targeting_divisor: int = 4

## Ceiling on derived crit chance, whole percent. A cap exists so a late-game
## targeting stack cannot reach guaranteed crits — at 100% the crit multiplier
## stops being variance and just becomes a flat damage bonus, which removes the
## reason crit is interesting.
@export var crit_chance_cap_percent: int = 50

## Damage multiplier on a crit. Passed to [method DamageFormula.compute_damage] as
## `crit_mult`, pre-floor with the type multiplier (TR-df-002).
@export var crit_damage_multiplier: float = 1.5

## Hard cap on rounds before a battle is declared a draw. Two full teams of tanks
## with regen can otherwise loop forever; without this the auto-battler and the
## offline expedition simulator both hang rather than resolve.
@export var max_battle_rounds: int = 50

# ---------------------------------------------------------------------------
# v1 skill-tree tuning (design/v1/00-core-design.md §4). APPEND-ONLY.
# ---------------------------------------------------------------------------

## Scrap charged per allocated node when respeccing (§4.5). A free respec turns the tree
## into a menu you re-pick per fight; a cost makes a build a commitment, which is what
## makes it feel owned. Priced to be affordable but not casual.
@export var respec_scrap_per_node: int = 150

## Scrap charged to pull an install item back out of a socket (§4.4, owner's call:
## "podem ser removidos, mas custa scrap").
@export var item_removal_scrap_cost: int = 400
