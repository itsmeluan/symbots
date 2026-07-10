---
name: project-tbc-formulas
description: TBC GDD Section D formula proposals — all 6 formulas, registry errata, TTK impact check (proposed 2026-07-10)
metadata:
  type: project
---

TBC Section D (Formulas) was proposed by systems-designer on 2026-07-10 for user approval before writing to file.

**Why:** TBC GDD Section C (Detailed Design) was approved. Section D covers all combat math.

**How to apply:** When resuming TBC Section D work, the proposals below are the starting point. Do NOT re-derive from scratch — start from these and incorporate user feedback.

## Formulas Proposed

- **TBC-F1 (Initiative):** `effective_mobility = max(0, final_stat["mobility"] + synergy_delta.get("mobility",0) + shock_penalty)`. Shock_penalty from TBC-F4. Potency snapshots at application time.
- **TBC-F2 (Energy Recharge):** `min(max_energy_capacity, current_energy + 10 + final_stat["recharge"])`. Pure integer, no epsilon.
- **TBC-F3 (Burn Damage):** `max(BURN_MIN, floor(applier_processing × BURN_COEFF + 0.0001))`. BURN_COEFF=0.08, BURN_MIN=2. Output 2–8 per tick. Processing-only model (not structure-scaled) — accepted asymmetry for boss fights.
- **TBC-F4 (Shock Penalty):** `floor(applier_processing × 0.3 + 0.0001)`. Output 0–33. Epsilon LOAD-BEARING at multiples of 10.
- **TBC-F5 (Stagger):** Two-step. Step 1: `stagger_pct = floor(applier_processing × STAGGER_COEFF + 0.0001)`, STAGGER_COEFF=0.25, output 0–27. Step 2: `max(DAMAGE_FLOOR, floor(final_damage × (1 - stagger_pct/100.0) + 0.0001))`. POST-multiply (not pre-A), linear reduction. STAGGER_COEFF=0.25 is exactly representable (1/4), epsilon defensive in Step 1 but LOAD-BEARING in Step 2.
- **TBC-F6 (Repair):** `max(REPAIR_MIN, floor(user_energy_power × REPAIR_COEFF + REPAIR_BASE + 0.0001))`. REPAIR_COEFF=0.18, REPAIR_BASE=5, REPAIR_MIN=5. Output 5–24 (base), 5–30 (max synergy). Anti-stall verified: repair ≤ 30 < WILD-mid DPS 33. Epsilon LOAD-BEARING at energy_power=50.

## Registry Errata Proposed

- **DF-1 range:** [1,165] → [1,225]. New A ceiling: 150 (110 + SYNERGY_POWER_BUDGET 40).
- **SYNERGY_POWER_BUDGET = 40** (new constant): max cumulative stat_delta for physical_power or energy_power across all simultaneously active synergy tiers. Closes Synergy OQ-2 from TBC side.
- **SYNERGY_DEFENSE_BUDGET = 50** (new constant): max cumulative stat_delta for armor or resistance.

## TTK Impact Check

Max-synergy (A=150) vs. BOSS reference (D=30, structure=594):
- Neutral: 5 turns (was 18 base-only)
- Super-effective: 4 turns (was 12 base-only)
- Resisted: 7 turns (was 24 base-only)

Recommendation: No enemy errata needed. 4-turn boss kill on max-synergy build is intentional Pillar 4 endgame power. Add NOTE to Enemy Database EDB-2 section.

## Python3 Scans Required (in priority order)

1. TBC-F4: processing × 0.3 for all processing ∈ [0,110]
2. TBC-F5 Step 2: final_damage × (1-stagger_pct/100.0) for stagger_pct ∈ [0,27], representative damage values
3. TBC-F6: energy_power × 0.18 for all energy_power ∈ [0,110] — confirmed trap at input=50
4. TBC-F3: processing × 0.08 for all processing ∈ [0,110]
5. TBC-F5 Step 1: processing × 0.25 (defensive, but scan before coefficient tuning)
6. DF-1 extended: A ∈ [111,150], D ∈ [0,55], T ∈ {0.75, 1.0, 1.5}
