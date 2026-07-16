## ConsumableEffects — the pure math for every consumable effect (Consumable DB).
##
## One home for the CD-1…CD-5 formulas (GDD Formulas section). Every function is a
## PURE static function: same inputs → same output, no RNG, no state read beyond the
## passed args, no target mutation. Applying a returned value to a live Symbot (a
## turn-consuming action) is TBC's concern (AC-CD-20, DEFERRED) — this class only
## computes the value the erratum will assign.
##
## Magnitudes (`amount`, `multiplier`, `rate_multiplier`) are read from a def's
## `effect_params` by the CALLER and passed in — never hardcoded here (data-driven
## discipline, ADR-0003 / coding-standards). Resource caps (`max_structure`,
## `max_energy`) come from the RUNTIME target — a leveled CORE carries a higher cap —
## so they are always parameters, never literals.
##
## CD-1/2/3 (restore) are pure INTEGER `min`/`max` clamps — NO `floor()`/`ceil()`
## (GDD Formulas, TR-cdb-008: flat-integer magnitudes). CD-4/5 (Stories 005/006) are
## float multiplies into `clamp()`.
class_name ConsumableEffects
extends RefCounted

# ---------------------------------------------------------------------------
# CD-1 — RESTORE_STRUCTURE (AC-CD-01)
# ---------------------------------------------------------------------------

## CD-1: `new_structure = min(max_structure, current_structure + amount)`.
## Restores flat Structure, capped at the target's runtime `max_structure`. Pure
## integer clamp — an impl omitting `min()` overshoots the cap (25→75 not 60).
static func restore_structure(current_structure: int, max_structure: int, amount: int) -> int:
	return mini(max_structure, current_structure + amount)


# ---------------------------------------------------------------------------
# CD-2 — REDUCE_HEAT (AC-CD-02)
# ---------------------------------------------------------------------------

## CD-2: `new_heat = max(0, current_heat − amount)`.
## Removes flat Heat, floored at 0 (Heat has no "negative"). If it drops Heat below
## the Overheat threshold the Symbot exits Overheat via TBC's normal Heat logic — no
## special flag here (preventive-only, TR-cdb-007). An impl omitting `max(0,…)`
## underflows to a negative Heat (50 removed from 30 → −20 not 0).
static func reduce_heat(current_heat: int, amount: int) -> int:
	return maxi(0, current_heat - amount)


# ---------------------------------------------------------------------------
# CD-3 — RESTORE_ENERGY (AC-CD-03)
# ---------------------------------------------------------------------------

## CD-3: `new_energy = min(max_energy, current_energy + amount)`, reading the RUNTIME
## `max_energy` (a leveled CORE carries a higher cap — never a hardcoded 120). Pure
## integer clamp. The case `restore_energy(130, 147, 25) == 147` is the sole catch for
## a hardcoded-ceiling bug that every lower-cap case would pass silently.
static func restore_energy(current_energy: int, max_energy: int, amount: int) -> int:
	return mini(max_energy, current_energy + amount)


# ---------------------------------------------------------------------------
# CD-4 — BOOST_DROP (Salvage Beacon, AC-CD-04 / Story 005)
# ---------------------------------------------------------------------------

## CD-4: `effective = clamp(base_rate × Π(cond_mults) × beacon_multiplier, 0.0, 1.0)`.
## The Beacon's `multiplier` (2.0) is injected into the Drop System's effective-drop-
## rate product and clamped to a probability. Unit fixtures isolate the Beacon factor
## with `cond_mults=[]` (empty product = 1.0); the full drop-condition product + the
## seeded roll are the Drop System's (AC-CD-21, DEFERRED). Float multiply into
## `clampf` — no `floor()`. `0.25 × 2.0 = 0.50`; `0.70 × 2.0 = 1.40 → clamp 1.0`.
## An impl treating the empty product as 0.0 wrongly returns 0.0 for the first case.
static func boost_drop(base_rate: float, cond_mults: Array, beacon_multiplier: float) -> float:
	var product := 1.0
	for m in cond_mults:
		product *= float(m)
	return clampf(base_rate * product * beacon_multiplier, 0.0, 1.0)


# ---------------------------------------------------------------------------
# CD-5 — MODIFY_ENCOUNTER_RATE (Jammer / Lure, AC-CD-09/10 / Story 006)
# ---------------------------------------------------------------------------

## CD-5: `effective_rate = clamp(base_rate × rate_multiplier, 0.0, 1.0)`.
## Jammer `rate_multiplier < 1` repels; Lure `> 1` lures. Float multiply into `clampf`
## — no `floor()`. IEEE-754 note (GDD): `0.15×0.1`, `0.15×2.5`, `0.35×2.5` are exact in
## doubles (used for `==` fixtures); DENSE `0.35 × 2.5 = 0.875` stays UNDER the 1.0
## clamp deliberately. A `3.0×` Lure impl would give `0.35 × 3.0 = 1.05 → 1.0 ≠ 0.875`.
static func modify_encounter_rate(base_rate: float, rate_multiplier: float) -> float:
	return clampf(base_rate * rate_multiplier, 0.0, 1.0)
