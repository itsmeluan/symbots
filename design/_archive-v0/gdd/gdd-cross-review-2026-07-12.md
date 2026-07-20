# Cross-GDD Review Report

**Date:** 2026-07-12
**GDDs Reviewed:** 12 Approved system GDDs (part-database, damage-formula, enemy-database, symbot-assembly, synergy-system, turn-based-combat, move-database, passive-database, part-break, drop-system, encounter-zone, consumable-database) + game-concept, systems-index, entities.yaml
**Checkpoint:** MVP Foundation + Core + partial Feature layer (12 of 22 MVP systems designed). Follows the 2026-07-10 review (8 GDDs, CONCERNS — all items resolved).
**Method:** Registry pre-load baseline → parallel consistency (Phase 2) + design-theory (Phase 3) subagents → main-session cross-system scenario walkthrough (Phase 4). Prior review items (B-1, B-2, W-1..W-9, HOLISM-01) confirmed resolved and NOT re-flagged.

---

## Verdict: CONCERNS

No blocking issues. The 4 GDDs added since the prior review (part-break, drop-system, encounter-zone, consumable-database) integrate cleanly into the established hunt→collect→build loop and the design pillars. Findings: one cosmetic consistency fix (C-1, applied this session) and two advisory design watches (D-1 attention budget → Combat UI GDD; D-2 consumable economy → OQ-DS-7 + playtest). Architecture is not blocked by these — but 10 of 22 MVP systems remain undesigned, so architecture should not begin until the MVP GDD set is complete regardless.

---

## Consistency Issues (Phase 2)

**Blocking:** None.

### Warnings

**C-1 (LOW, APPLIED 2026-07-12) — Consumable DB Overview count drift.**
`consumable-database.md` Overview said a roster of "six items" while Rule 1, Rule 10, and AC-CD-18 all say eight entries / six effect concepts (RESTORE_STRUCTURE is a 3-tier family). The binding count (8) was consistent everywhere except the Overview prose; no downstream effect (the Drop rarity-channel keys off the `rarity` enum, not the count). **Fixed this session** — Overview now reads "eight items across six effect concepts."

### Passed axes
- **2a Bidirectionality** — PASS. Part-Break↔Drop (Drop Upstream table lists Part-Break, ratified; break-event vocabulary matches), Consumable↔TBC/Drop/EZ (all three list Consumable DB upstream; Consumable lists all three downstream), Move DB↔Part-Break (`break_bias`/`target_profile` erratum applied). All reciprocal.
- **2b Rule Contradictions** — PASS. REPAIR move (TBC-F6 ceiling 30) vs consumable RESTORE_STRUCTURE (25/50/120) are separate mechanisms, explicitly reconciled. Drop Rule 1 (victory-only) agrees with Consumable Rule 5/EC-CD-07 (Beacon spent on flee, no effect) and TBC Rule 7a. Part-Break Rule 5 deterministic break agrees with Drop Rule 7/DS-3. EZ-1 modifier hook matches Consumable CD-5 (both "one modifier, latest wins").
- **2c Stale References** — PASS. TBC Move/Passive DB labels now Approved; Enemy DB OQ-3 RESOLVED + dead-data note + EDB-2 addendum present; TBC-F2 (BASE_ENERGY_REGEN=10) exists; all 3 errata targets cross-reference Consumable DB.
- **2d Ownership Conflicts** — PASS. TBC-F6 owns REPAIR heal / Consumable owns item amounts; EZ owns encounter-rate bands / CD-5 reads them; Drop owns base drop rates / CD-4 reads them. Consumable Tuning Knobs explicitly disclaim ownership of all three.
- **2e Formula Compatibility** — PASS. CD-1 [1,594], CD-2 [0,100], CD-3 [0,120] in-bounds. CD-4 Beacon injects into the same `clamp(base × Π conditions × beacon_multiplier, 0, 1)` product as DS-1's Beacon erratum — identical structure/position. PB-F1 [1,393] < Structure max 594; PB-F2 [1,441] can OHK a region (EDB-1 max 330) by design.
- **2f AC Cross-Check** — PASS. AC-CD-20 (deferred TBC integration) and AC-TBC-41 (use-item action) complementary. AC-PB-28 harvest guarantee (`harvest_turns > fastest_kill_turns`) not undermined by the Beacon (Rule 12 keeps the consumable/Beacon channel out of break math; Beacon boosts drop rate, never the break requirement).

---

## Game Design Issues (Phase 3)

**Blocking:** None.

### Warnings

**D-1 — Combat attention budget elevated 4 → 5 (assign to Combat UI GDD).**
Consumables add a 5th active tracking demand per combat turn (a 4th action + preventive-Coolant window) on top of Heat / Energy / statuses / break-targeting. This crosses the comfortable 3–4 ceiling for non-theorycrafter and touch/mobile players. **Mitigated:** the 5th demand is *elective* — rejection is a pre-action gate (Consumable Rule 3), invalid items are greyed out (UI Req 1), and consumables are fully ignorable with no structural loss. Recommendation: the Combat UI GDD should treat consumables as a collapsible/secondary action affordance so they do not compete for primary attention. This is an elevation of the prior review's HOLISM-02.

**D-2 — Consumable economy is contingent + has no MVP sink besides use (assign to OQ-DS-7 + playtest).**
The Salvage Beacon "~2:1 self-drain" sustainability claim is explicitly contingent on the **unset OQ-DS-7** consumable drop frequencies (both CD-4 and Drop Rule 12c state this). If frequencies are tuned high, Beacon accrual could outpace the drain and re-open the farm-Beacons feedback the design guards against. Consumable accumulation is bounded only by `max_stack` (C20/R10/P5); the overflow policy is deferred to the Not-Started Inventory GDD (EC-CD-12), and the sell-faucet safety valve (Rule 8) is inert in MVP. Net: bounded but unverified. **The consumable drop frequency (OQ-DS-7) is the single highest-value balance number to lock at playtest.** Not a blocker — a deliberate deferred decision.

### Passed axes
- **3a Progression Loop Competition** — PASS. All 4 new GDDs feed the single hunt→collect→build loop; Scrap remains the sole currency. The Beacon is a spend-decision layered on the loop, economy-clamped so it cannot bootstrap a self-sustaining farm loop (INFO: contingent on OQ-DS-7).
- **3b Player Attention (overworld)** — PASS (3 demands: terrain, modifier steps, boss-gate wins). Combat is the concern (D-1).
- **3c Dominant Strategy** — PASS. Consumable stalling is net-negative tempo vs. rising enrage (OQ-CD-7 watch). Beacon-near-pity is optimal play, not an exploit (pity checked pre-roll, Drop Rule 12b). Signal Jammer cannot skip the wins-gated boss (EZ Rule 8a wins-only) — it optimizes post-gate traversal only.
- **3d Economic Loops** — Parts closed, Scrap closed in MVP; consumables the one watch (D-2).
- **3e Difficulty Curve** — PASS. Enrage × glass-cannon (PB-F5 honest, OQ-PB-3) × DENSE-attrition (consumables are the designed answer) dovetail. Boss gates ensure zone familiarity before enrage-on-boss. INFO: watch the compounding case (high region_fraction boss + full enrage + resource-depleted arrival) at Boss 2.
- **3f Pillar Alignment** — PASS. Part-Break → P2+P1; Drop → P2; Encounter Zone → P5+P2; Consumable → P5+P2. **Consumables do NOT violate Pillar 1** — Repair Kit 50 > REPAIR-move 30, but a REPAIR build heals every turn, so items never eclipse the build decision. Well-guarded.
- **3g Player Fantasy Coherence** — PASS. Engineer-architect (build) + deliberate-hunter (execution) + field-mechanic (in-fight margin) triangulate one "engineer-hunter" identity. The "field-mechanic's kit" is framed as salvage (no shops), folding into the "world is a workshop" scavenger identity.

---

## Cross-System Scenario Walkthrough (Phase 4)

5 scenarios walked, all **coherent** — no undefined behavior, broken state transitions, or contradictory messaging:

1. **Beacon + Part-Break + Drop on a boss** — Boss-grade with ×500 break condition × 2.0 Beacon = `clamp(1.0)`; graceful, intended. **Coherent.**
2. **Signal Jammer → DENSE zone → flee mid-fight** — `EncounterModifierState` freezes structurally during battle (no overworld steps), resumes after. **Coherent.** ℹ️ INFO: save/reload behavior for an active Jammer is unspecified — EC-CD-08 calls it "acceptable minor loss"; no unit AC. Minor, deferred to Overworld Navigation / Save-Load.
3. **Consumable use with all Symbots near defeat** — losing because the enemy acts first (lower Mobility) is intentional "should have healed earlier" tension, not a bug. **Coherent, by design.**
4. **Boss gate opens mid-Lure** — gate eval is trigger-based (`battle_ended`/approach); the Lure countdown continues independently. **Coherent.**
5. **Coolant Flush prevention vs. DOWNED** — the Flush buys a turn but does not prevent a lethal enemy hit; the "flush or heal?" decision is the intended tension. **Coherent.**

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority | Status |
|-----|--------|------|----------|--------|
| consumable-database.md | Overview "six items" vs Rules/AC "eight" (C-1) | Consistency | Warning | APPLIED 2026-07-12 |

No GDD requires re-review. The two design warnings (D-1, D-2) are advisory and already tracked as open questions (OQ-CD-7, OQ-DS-7, EC-CD-12); they assign to UX (Combat UI) and playtest/economy, not GDD revision.

---

## Required Actions Before /create-architecture

1. **None blocking from this review.** C-1 applied; D-1/D-2 are tracked watches, not blockers.
2. **Assign D-1** to the Combat UI GDD when authored: consumables as a collapsible/secondary combat affordance (attention-budget mitigation).
3. **Assign D-2** to OQ-DS-7 (set consumable drop frequencies) — the highest-value balance number, to lock at/before playtest; and to the Inventory GDD (EC-CD-12 max_stack overflow policy).
4. **10 of 22 MVP systems remain undesigned** — architecture should not begin until the MVP GDD set is complete. Next in design order: #10 Enemy AI, then #11 Inventory.

*Applied this session (2026-07-12): C-1 Overview count fix.*
