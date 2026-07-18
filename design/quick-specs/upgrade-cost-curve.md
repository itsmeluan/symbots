# Quick Spec: Part Upgrade Cost Curve (Scrap sink)

> **Status**: Ratified 2026-07-18 (Luan + ux-designer + drop-system source)
> **Owner**: Part Upgrade / Workshop (this doc is its authoritative home until a full
> Workshop System GDD exists — discharges Drop System line 272 & Rule 9 sink ownership)
> **Type**: Balance / tuning constant set

---

## Overview

The Scrap cost to raise a part's `upgrade_tier`. This is the **consuming sink** of the
Scrap economy (Drop System Rule 9 — the faucet is Scrap-conversion of duplicate parts).
The Drop System *proposed* these values in its Tuning Knobs (line 311) and explicitly
delegated final ownership to "Part Upgrade / Workshop". This doc **ratifies** them so the
Workshop UX spec (`design/ux/workshop.md`) and any future Workshop System GDD reference a
single owned source rather than re-deriving.

This is a **ratification, not a new derivation** — the values below are the exact curve the
entire Drop System economy model (faucet ~1,840 Scrap / arc, sink ~1,000 Scrap / Symbot,
mild-scarcity target) was validated against. Changing them re-opens that model.

---

## The Curve

Per-tier Scrap cost (**pure doubling**, monotonic — every step ≥ the previous, no discount
inflection):

| Step | Scrap cost | Rarity eligibility |
|------|-----------|--------------------|
| `+0 → +1` | **10** | All rarities |
| `+1 → +2` | **20** | All rarities |
| `+2 → +3` | **40** | All rarities |
| `+3 → +4` | **80** | Rare / Prototype / Boss-grade only (Common capped at +3) |
| `+4 → +5` | **160** | Rare / Prototype / Boss-grade only |

**Cap totals (cumulative to max tier):**

| Rarity | Max tier | Total Scrap to max |
|--------|----------|--------------------|
| Common | +3 | **70** (10 + 20 + 40) |
| Rare / Prototype / Boss-grade | +5 | **310** (70 + 80 + 160) |

---

## Design Rationale (why doubling, why these numbers)

- **The cheap first hit hooks the habit.** `+0→+1` at 10 is affordable inside the first
  game-third (~300 Scrap even at ~15% early Common absorption — Drop System game-thirds
  sketch), so the player makes their first upgrade before hour 3 (OQ-DS-5 watch criterion).
- **The cost lives at the top.** The final `+4→+5` step (160) *alone* exceeds the entire
  `+0→+3` Common journey (70); the last two tiers (80 + 160 = 240) cost ~3.4× the first
  three (70). Maxing a part is a deliberate end-game investment, not a default.
- **Monotonic, no inflection.** Every step is ≥ the previous — there is never a "discount"
  tier that would create a perverse "skip-ahead" incentive.
- **Economy consistency (the load-bearing reason the numbers are fixed):** against the
  Drop System faucet (~1,840 central; band ~1,555–2,125) and a ~1,000 Scrap priority-part
  sink per Symbot (2 Rare +5 = 620 · 1 Prototype +5 = 310 · 1 Common +3 = 70), this curve
  lands the arc at "**fully kit the lead Symbot, most of a second, prioritize on the
  third**" — the intended mild-scarcity sweet spot for the 3-Symbot roster cap.

---

## Interaction with Part-DB Rule 10

Scrap **cost** (this doc) and stat **effect** (Part-DB Rule 10) are orthogonal:

- Rule 10 defines what a tier *does*: ×1.15 / ×1.30 / ×1.50 / ×1.70 / ×2.00 to all stat
  bonuses (Formula 2), plus any `upgrade_effects[tier]` skill unlock/enhance.
- This doc defines what a tier *costs*: the Scrap table above.

The Workshop UPGRADE affordance reads both — it previews the Rule 10 stat delta (+ skill
callout) and charges the cost here.

---

## Tuning Knobs

| Knob | Value | Safe range | Notes |
|------|-------|-----------|-------|
| `UPGRADE_COST[+0→+1]` | 10 | 5–15 | The "hook" — keep affordable in game-third 1 |
| `UPGRADE_COST[+1→+2]` | 20 | — | Doubling maintained |
| `UPGRADE_COST[+2→+3]` | 40 | — | Common cap step |
| `UPGRADE_COST[+3→+4]` | 80 | Rare+ only | End-game investment begins |
| `UPGRADE_COST[+4→+5]` | 160 | Rare+ only | The single most expensive step |
| Doubling ratio | ×2.0 | 1.8–2.2 | Below 1.8 flattens the end-game sink; above 2.2 walls +5 |

**Retune coupling:** any change here MUST re-check the Drop System economy model
(faucet/sink balance) — the two are a single system. Flag `economy-designer` on retune.

---

## Acceptance Criteria

- **AC-UCC-01** — `get_upgrade_cost(tier)` returns exactly `[10, 20, 40, 80, 160]` for
  steps `+0→+1 … +4→+5`. *(Unit.)*
- **AC-UCC-02** — Cumulative cost to max is **70** for a Common (+3) and **310** for a
  Rare/Prototype/Boss-grade (+5). *(Unit.)*
- **AC-UCC-03** — The cost sequence is strictly monotonic non-decreasing (`cost[n+1] ≥
  cost[n]` for all n) — no discount inflection. *(Unit.)*
- **AC-UCC-04** — A Common part cannot be charged the `+3→+4` cost (upgrade blocked at the
  +3 cap before any Scrap is debited). *(Unit — pairs with Workshop AC-WS-04 "Max tier".)*

---

## Dependencies

- **Drop System** (`design/gdd/drop-system.md`) — Rule 9 (Scrap faucet), Tuning Knobs
  (proposed values + full economy derivation), line 272 (ownership handoff to Workshop).
- **Part Database** (`design/gdd/part-database.md`) — Rule 10 (stat effect per tier), tier
  caps (Common +3 / Rare+ +5).
- **Workshop UX** (`design/ux/workshop.md`) — the UPGRADE affordance that charges this cost
  (AC-WS-04); resolves that spec's OQ5.
- **Inventory** (`design/gdd/inventory.md`) — owns per-instance `upgrade_tier`; debits the
  Scrap balance.
