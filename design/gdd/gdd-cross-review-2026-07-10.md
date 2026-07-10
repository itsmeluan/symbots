# Cross-GDD Review Report

**Date:** 2026-07-10
**GDDs Reviewed:** 8 approved system GDDs (part-database, damage-formula, enemy-database, symbot-assembly, synergy-system, turn-based-combat, move-database, passive-database) + game-concept, systems-index, entities.yaml
**Checkpoint:** MVP Foundation + Core layer complete (8 of 22 MVP systems designed). This is an early holistic checkpoint, not the final pre-architecture gate.
**Method:** Registry pre-load baseline → parallel consistency (systems-designer) + design-theory (game-designer) subagent passes → main-session cross-system scenario walkthrough.

---

## Verdict: CONCERNS

No issue blocks the current 8 approved Foundation + Core GDDs. The two integration seams (B-1, B-2) exercise only *deferred* passive content (non-ON_HIT triggers, non-STATUS_RIDER behavior classes) — zero MVP content path touches them. They are the cross-GDD shadow of the already-ratified OQ-PDB-1 deferral, resolvable via forward-looking TBC errata. HOLISM-01 is a design decision for a Not-Started downstream GDD (Drop System). Everything else is verified documentation drift. The formula pipeline is range-compatible end-to-end and the pillars are mutually coherent.

---

## Consistency Issues

### Integration Seams (forward-looking — required before OQ-PDB-1 passive content + TBC passive-dispatcher implementation; NOT exercised by MVP content)

**B-1 — ON_OVERHEAT firing order undocumented in TBC.**
`passive-database.md` Rule 2a ↔ `turn-based-combat.md` Rule 4/Rule 13. Passive DB asserts ON_OVERHEAT passives fire *before* the Overheat consequence (self-damage + skip) and states this requires a simultaneous TBC Rule 13/Rule 4 update. TBC documents no such ordering and has no verifying AC (AC-TBC-09 tests Overheat but not passive firing). All 3 MVP riders are ON_HIT — no MVP content exercises ON_OVERHEAT. Resolution: apply a TBC Rule 13 errata documenting the ordering contract before the first ON_OVERHEAT content (OQ-PDB-1).

**B-2 — STAT_AURA application path missing from TBC Rule 10.**
`passive-database.md` Rule 3/EC-PDB-05 ↔ `turn-based-combat.md` Rule 10. Passive DB says STAT_AURA is "applied via SYN-F4 clamp," but TBC Rule 10's SYN-F4 reads only the frozen synergy delta (`cached_bonus_block.stat_delta`), which the Synergy System populates from tier definitions — never from a part's passive `behavior_params`. No documented path wires a part-passive PERSISTENT aura into the effective-stat computation. No MVP STAT_AURA content exists. Resolution: TBC Rule 10 errata adding a step that folds PERSISTENT part-passive auras into effective stats, gated as an OQ-PDB-1 entry criterion (ties to AC-PDB-D2).

### Stale-Doc / Drift (verified — cheap fixes)

- **W-1** `part-database.md` downstream dependents table omits Move Database (body references it at lines 221/241; table row missing).
- **W-2** `turn-based-combat.md` dependency tables label Move DB "Not Started (provisional)" and Passive DB "Not Started | Soft" — both are now Approved.
- **W-3** `synergy-system.md` doesn't list Passive DB as a downstream consumer, though Passive DB Rule 5 names Synergy as one.
- **W-4** `turn-based-combat.md` `STATUS_DURATION` knob ("2 turns — all three statuses") reads as if it governs all status applications; passive-rider durations are independently authored in Passive DB Rule 5 (1T Shock/Stagger, 2T Burn) and are NOT driven by this knob.
- **W-5** `enemy-database.md` OQ-3 (enemy resource symmetry) unmarked RESOLVED; Rule 3 not annotated that cooling/energy_capacity/recharge are dead data per TBC Rule 8 (ED1); EDB-2 lacks the max-synergy BOSS-TTK addendum.
- **W-7** `part-database.md` AC-13 still "Status: BLOCKED — Move/Passive DBs don't exist" — both now exist; unblock.
- **W-8 / W-9** `entities.yaml`: `DAMAGE_FLOOR` and `BASE_ENERGY_REGEN` missing `move-database.md` in `referenced_by` (MOVE-F1 uses DAMAGE_FLOOR; Move DB Rule 7 REPAIR energy-brake uses BASE_ENERGY_REGEN).
- **W-6 WITHDRAWN** — the systems-designer flagged a dangling `AC-MDB-10` citation, but AC-MDB-10 exists (move-database.md:299, the SCAN reveal AC) and TBC AC-TBC-39's citation is valid.

### Formula Compatibility (2e): PASS
SA-F1 [0,110] → SYN-F4 [0,150 atk / 0,182 def] → DF-1 [1,225] → MOVE-F1 [1,315] → TBC-F5 [1,315]. Range-compatible end-to-end. Registered values coherent.

### Acceptance Criteria Cross-Check (2f): PASS
No mutually-exclusive AC pairs. Passive DB and TBC ACs on rider durations/scope reinforce each other (AC-PDB-04≡AC-TBC-29; AC-PDB-05≡AC-TBC-30). The only gap is coverage absence for ON_OVERHEAT passive ordering (= B-1), not a contradiction.

---

## Game Design Issues

### Design Decision Required (out of scope for the 8 approved GDDs; blocks the Not-Started Drop System GDD)

**HOLISM-01 — Part economy sink undefined.**
The persistent part economy has a designed faucet (drops) but no designed sink. Duplicate-part disposition is undecided: (a) scrap-as-currency, (b) inventory accumulation with cap, or (c) no-store/zero-inventory. Part DB defers this to Drop System constraint DB5; Enemy DB OQ-4/OQ-5 depend on it. The decision propagates into Workshop, Inventory, and session pacing. Must be taken before the Drop System GDD is authored. (Option a best serves Pillar 1 by giving Common parts endgame utility but is the most work; option c is MVP-fastest.)

### Warnings (watch/track — no rules change)

- **HOLISM-02** 4 simultaneous active tracking demands during a combat turn (Heat, Energy, up to 3 statuses, break-targeting). Within tolerance for the theorycrafter audience; becomes a Combat UI GDD legibility constraint at 44pt touch targets (iOS primary long-term).
- **HOLISM-03 (Pillar 4)** All 3 MVP riders are flat UNIQUE_PER_TRIGGER — a 6-part Volt stack procs Shock at the same rate as a 1-part stack. Investment→behavior scaling is deferred to OQ-PDB-1 (CRITICAL PATH). If OQ-PDB-1 doesn't ship before content authoring completes, Pillar 4 reduces to "bigger stats, not different behavior."
- **HOLISM-04** Player-fantasy coherence gap: "my build does this on its own" is only partly delivered at the passive layer. Workshop/Combat UI must communicate the stacking-bonus vs. once-per-event distinction.
- **HOLISM-05 (balance watch)** `kinetic_stagger_on_hit` is the only rider that mitigates *incoming* damage (0–27% via processing) — asymmetric vs. Shock (initiative) and Burn (DoT). Not a problem at 2-boss MVP scope; monitor in playtest. Levers: lower STAGGER_COEFF (0.25) or retarget Stagger to a specific stat.

### Design Holism PASS
No progression-loop competition (single build loop; no parallel XP — anti-pillar upheld). No dominant damage type (DF-1 symmetric; intransitive type triangle). Difficulty curve coherent at design level. SIGNATURE 3-turn boss kill confirmed as a legitimate mastery ceiling behind maximum build investment, not a degenerate strategy. No dependency cycles (clean DAG). The 5 pillars are mutually compatible.

---

## Cross-System Scenario Walkthrough (Phase 4)

1. **Max-synergy SIGNATURE WEAPON hit on boss** — full pipeline range-compatible; rider and Part-Break accumulator share the `hit_resolved` hook, ordering immaterial (statuses don't affect break HP). **Coherent.**
2. **Overheat turn + ON_OVERHEAT passive** — undefined ordering (= B-1); no MVP content exercises it.
3. **Battle-start PERSISTENT STAT_AURA Core passive** — no wired path into effective-stat (= B-2); no MVP content exercises it.
4. **Same rider ID from part + synergy on one hit** — UNIQUE_PER_TRIGGER dedup, triple-covered (TBC Rule 13 + SYN-F3 + AC-PDB-07/AC-SYN-05). **Coherent.**

Insight: both seams live exclusively in deferred passive paths. MVP content (all STATUS_RIDER/ON_HIT) is fully coherent across the 8 GDDs.

---

## GDDs Flagged (errata only — none require re-review)

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| turn-based-combat.md | Stale dep labels (W-2), STATUS_DURATION scope (W-4); ON_OVERHEAT/STAT_AURA seam errata (B-1/B-2) | Consistency | Errata |
| enemy-database.md | OQ-3 resolve + dead-data note + EDB-2 addendum (W-5) | Consistency | Errata |
| part-database.md | AC-13 unblock (W-7); Move DB downstream row (W-1) | Consistency | Errata |
| synergy-system.md | Passive DB downstream reciprocity (W-3) | Consistency | Errata |
| entities.yaml | referenced_by gaps (W-8/W-9) | Registry | Errata |

---

## Required Actions Before /create-architecture

1. ~~Apply TBC errata for B-1 (ON_OVERHEAT ordering) and B-2 (STAT_AURA application path)~~ **DONE 2026-07-10.** TBC Rule 13 now carries a "Trigger dispatch & firing order" contract (ON_OVERHEAT fires before the Overheat consequence; PERSISTENT is an application mode sieved from event dispatch; alphabetical multi-passive ordering). TBC Rule 10 now folds PERSISTENT STAT_AURA part-passive deltas into `effective_stat` via a `frozen_passive_aura` block. Both closed bidirectionally (Passive DB Rule 2a / Rule 3a note the closure). AC-PDB-D2 remains the OQ-PDB-1 entry gate that exercises the B-2 path.
2. Take the HOLISM-01 duplicate-part-sink decision before authoring the Drop System GDD.
3. (Recommended) Confirm OQ-PDB-1 Core passive content pass is gated as a design prerequisite before the first content authoring sprint (Pillar 4 delivery).
4. Note: 14 of 22 MVP systems remain undesigned — architecture should not begin until the MVP GDD set is complete. Next in design order: #7 Encounter Zone; #9 Part-Break is the binding Pillar-2 obligation.

*Applied in this session (2026-07-10): W-1, W-2, W-3, W-4, W-5, W-7, W-8, W-9 doc-drift/registry errata.*
