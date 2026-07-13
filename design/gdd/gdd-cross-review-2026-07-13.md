# Cross-GDD Review Report

**Date:** 2026-07-13
**GDDs Reviewed:** 19 system GDDs + entity registry (69 entries)
**Systems Covered:** Part / Move / Passive / Consumable / Enemy Databases, Damage Formula, Symbot Assembly, Synergy, Turn-Based Combat, Part-Break, Enemy AI, Symbot Core Progression, Enemy Level & Zone Scaling, Inventory, Drop System, Encounter Zone, Zone & World Map, World Loot, Exploration Progress
**Method:** Three parallel passes — Cross-GDD Consistency (2a–2f), Game Design Holism (3a–3g), Cross-System Scenario Walkthrough (Phase 4) — each reading all 19 GDDs in full, with the entity registry as the authoritative conflict baseline.

> **Scope note:** This review ran at **21/25 MVP systems designed**. Four MVP systems remain Not Started — most consequentially **Workshop / Part Upgrade (#15/#26)**, which owns the primary Scrap sink, and **Overworld Navigation (#16)**, which owns the battle-result → world-progression relay. Several findings below are gated on those unwritten systems and can only be fully closed once they exist.

> **Revision note (2026-07-13):** Initial verdict was FAIL on the `battle_ended` payload seam (C-1/S-B1) and the subscriber-ordering seam (S-B2). A deeper contract check downgraded both to **Warnings** — see the reasoning inline — and the verdict was revised to **CONCERNS**. A TBC erratum tightening those two contracts was applied the same day. The one substantive blocking issue is **C-2 (CP-F3 range breach)**, in Core Progression + Damage Formula.

**Headline:** The 19 designed GDDs are unusually well-reconciled — a single coherent player fantasy, consistent anti-pillar defense, one dominant loop, and (after three prior 0-conflict consistency checks) no value contradictions in the registry baseline. The remaining risks are one formula-range breach the newest system (CP-F3) introduced, two now-tightened event-contract seams at `battle_ended`, and a cluster of economy numbers that stay unfalsifiable until the Scrap-sink and Overworld-Navigation systems are written.

---

## Consistency Issues

### 🔴 Blocking

**C-2 · CP-F3 level-growth pushes stats past the input ranges every downstream formula declares.** *(The one substantive gap all three prior 0-conflict passes missed — CP-F3 is newer than the range derivations.)*
CP-F3 adds `level_growth[stat] × (level−1)` into `final_stat` before SYN-F4. The authoring reference grows *power* stats (Spark Core: `energy_power` 2 → +18 at L10). But:

- **DF-1 input ceiling:** `damage-formula.md` declares `A ∈ 0–150` ("base 110 + synergy 40"); TBC's exhaustive float-safety scan covered exactly `A ∈ [1,150]`. A level-10 core reaches **110 + 18 (CP-F3) + 40 (synergy) = 168 > 150** — outside the declared and scanned domain.
- **max_energy** [80,120] → ~147; **max_structure** [60,594] → ~612 (cited by SA-F1, Part DB F6, Consumable CD-1).

No crash (consumers clamp), but the declared ranges are now false and DF-1's float-safety scan doesn't cover A=151–168. **Fix (design judgment):** cap `level_growth` away from power stats, OR extend the DF-1 range + re-scan, OR annotate ranges as "pre-CP-F3." Given this project's float-epsilon rigor, extending the scan is the safe path. *(Owner: Core Progression + Damage Formula; downstream range annotations in Assembly, Consumable DB, Part DB.)*

### ⚠️ Warnings

**C-1 · The `battle_ended` signal name denotes two differently-shaped signals, and the world-progression relay contract is unratified.** *(Downgraded from Blocking after the relay layer was confirmed — see below. Applied as a TBC erratum 2026-07-13.)*
`turn-based-combat.md` Rule 12 emits a 6-field combat signal `battle_ended(VICTORY, enemy_id, fired_break_events, xp_value, enemy_level, deployed_symbot_ids)`, consumed **directly** by Drop System and Core Progression. Separately, `zone-world-map.md` (lines 111, 114, 217, 223) and `encounter-zone.md` (Rule 8a) consume a **relayed** `battle_ended(result, encounter_type)` — WIN/LOSS/FLEE + WILD/BOSS — that **Overworld Navigation (#16, Not Started)** produces: ON knows `encounter_type` from the encounter trigger and maps TBC's VICTORY/DEFEAT/FLED vocab. So the boss gate is **not** structurally unable to open (the scenario pass initially read it that way because ZWM consumes a shape TBC doesn't emit, and the relaying system isn't written yet). The real defects are (a) a **signal-name collision** — one identifier, two shapes — that could be miswired, and (b) the relay contract lives only in ZWM prose until Overworld Navigation is authored. **Applied fix:** TBC Rule 12 now carries a signal-name-disambiguation note ("do not wire ZWM/Encounter Zone to this combat payload; ON relays a distinct 2-field signal"). **Remaining:** ratify the relay in the Overworld Navigation GDD when authored, and have ZWM/EZ dependency rows name the relayed signal explicitly.

**C-3 · Base energy regen is double-owned under two names with two safe ranges.** `part-database.md` uses `BASE_REGEN` (safe 5–15); `turn-based-combat.md`/registry use `BASE_ENERGY_REGEN` (safe 8–15, owner = TBC). Same value (10), but the lower bound matters — TBC's REPAIR anti-stall contract needs the **8** floor ("never 0"). Unify name, owner, and range.

**C-4 · `synergy-system.md` line 232 cites the dead DF-1 range [1,165] and demands a re-derivation already done.** Every other doc + registry uses **[1,225]**; Synergy's own Dependencies row records the obligation as discharged. Stale prose only — update to [1,225]/mark resolved.

**C-5 · `drop-system.md` Rule 4 still shows the pre-erratum partial DS-1** (missing `level_rarity_mult` and `beacon_factor`). Canonical DS-1 (line 110) and Rule 12a are correct; Rule 4 slipped the ELZS pre-gate 3a "as amended" labeling. Risk: an implementer coding from Rule 4 drops the level factor.

**C-6 · `part-database.md` ↔ Core Progression dependency is one-directional.** Part DB Rule 1 carries CP-owned fields (`level_growth`, `level_requirement`) and names CP by formula, but its Dependencies still say "Upstream: None" and omit CP downstream. (Registry already wires it.)

### ℹ️ Info

- **Stale status labels** (documentation drift, several self-noted as owed): Move DB lists Enemy AI "Not Started"; Enemy DB lists Move DB "Not designed" + AC-ED-03 BLOCKED; Assembly lists Passive/Move DB "Not Started"; ZWM lists EP + World Loot "Not Started"; Encounter Zone lists ZWM "Not Started"; Drop/Part/Consumable DB list Inventory "Not Started" — **all now Approved.**
- **C-7 ·** `enemy-database.md` AC-ED-03 names `MoveDatabase.has_skill(id)`, an interface Move DB doesn't expose (it defines only the null-returning lookup). Interface-name gap.
- **EDB-1 range** stated [5,330] (registry/Part-Break) vs 9–326 in-spec (Enemy DB owner). Harmless; numbers differ.
- **Verified clean:** rule contradictions (2b) — floor/ceiling epsilon convention, resource ownership, death handling, Overheat-skip, status no-stacking all consistent. AC cross-check (2f) — no mutually-unsatisfiable AC pairs.

---

## Game Design Issues

### 🔴 Blocking

*(None among the designed systems — but see D-1, gated on an unwritten system.)*

### ⚠️ Warnings

**D-1 · The primary Scrap sink does not exist yet — the MVP economy is an open faucet as currently specified.** `drop-system.md` Rule 9 names the sink as "part upgrading (Part Upgrade / Workshop, MVP)," but that system is **Not Started**. The entire ~1,555–2,125 Scrap model is validated against a sink whose cost curve is only *proposed*. As the document set stands, the player accrues ~1,800 Scrap with nowhere to spend it. **Not a contradiction — a missing half.** Until Workshop/Part Upgrade is authored, every Scrap-balance claim is unfalsifiable. Expected at 21/25 MVP — flagging so it isn't forgotten; treat Drop System's proposed cost curve as a binding constraint when the sink is designed.

**D-2 · The anti-grind invariant protecting the revised leveling anti-pillar is prose, not a testable AC.** `symbot-core-progression.md` asserts "a clever low-level build with great parts must still beat a lazily-assembled higher-level core," flagged "validate at playtest." This single claim is the *only* thing keeping Core Progression on the right side of anti-pillar #3. It's tuning-dependent and **CD sign-off (OQ-CP-6) is still open.** Add a concrete worked comparison as a checkable AC. Also reconsider the pillar claim: Core Progression *gates* P1/P3 (access/pacing) rather than *implementing* them — consider tagging it a support/pacing system, as Consumable DB is tagged. *(Bundle with the C-2 fix — both live in Core Progression.)*

**D-3 · SIGNATURE+synergy burst is not Heat-gated and collapses boss TTK from the authored 12–18 turns to 4–7.** Defensible as the Pillar-4 endgame reward, but two risks: (a) the Heat/Overheat tension layer becomes vestigial for top play; (b) enemy authoring (EDB-2 TTK bands) is calibrated for base-only stats and has **no in-MVP answer to the optimized build** (synergy-tier bosses deferred post-MVP). The hardcore audience *will* reach A=150 — document that the last content they see is meant to feel trivial.

**D-4 · Type-effectiveness (×1.5) + telegraphed single-element zones + 3-Symbot roster risks a "carry one element-specialist each, always swap to super-effective" heuristic** that flattens build depth (Pillar 3). Mitigated by enemy AI exploiting *your* weakness and the turn cost of switching. Watch that "the Volt Symbot" is itself a deep build, not a Volt stat-stick.

**D-5 · Battle turn carries 5–6 concurrent active systems** (move choice, sub-target kill-vs-harvest, Heat, Energy, enrage escalation, +switch/consumable) — above the 3–4 comfort threshold. Intended "harvest dilemma" tension, well-mitigated (synergy/passives frozen at battle start; Heat/Energy light). **#1 thing to watch in first playtest** — specifically enrage legibility (must be a visible *decision*, not invisible lethality).

**D-6 · Unset cross-GDD economy numbers leave two balance claims unfalsifiable.** Consumable drop-channel frequencies (OQ-DS-7) and world-loot consumable nodes (OQ-WL-4) are both OPEN, so the consumable economy is a stub *and* the Beacon 2:1 self-replenishment guardrail (which depends on those rates) is unverified. Resolve OQ-DS-7 + OQ-WL-4 together using the shared `level_band()` vocabulary.

**D-7 · EARLY-band Rare ×0.5 penalty + back-loaded Scrap = a double-thin first session** — lowest-Scrap and lowest-Rare-odds window coincide exactly when the player is forming the loop. Partially mitigated by the world-loot guaranteed-Rare-per-zone. Watch first-session retention; lever (raise EARLY mult within 0.3–0.8) is identified.

### ℹ️ Info

- **Pillar alignment (3f):** all 19 systems map to ≥1 pillar; **no scope-creep orphans.** Anti-pillar #1 (no completion counter) actively defended across Inventory, World Loot, and Enemy DB.
- **Fantasy coherence (3g):** genuinely single identity (the Symbot mechanic); recurring "the build speaking" motif. One mild tonal note — Core Progression's "patient investment" register vs. the "instant hypothesis" register elsewhere; hold the "quiet, byproduct" framing in the Workshop UI.
- **Positive:** enrage (+12%/break) is a well-designed self-adjusting difficulty coupling; no catch-up mechanic needed; no resource monopoly among passives; Beacon farm-loop correctly closed.

---

## Cross-System Scenario Issues

**Scenarios walked (5):** S1 Battle-End Victory Bundle · S2 Spillover-Kill Erases the Harvest · S3 Mid-Bundle Level-Up Crosses a `level_requirement` · S4 Dropped CORE Part Needs a Progression Record · S5 Beacon Flag Lifetime.

### 🔴 Blockers

*(None. S-B1 and S-B2 downgraded to Warnings — see below.)*

### ⚠️ Warnings

**S-B1 · `battle_ended` signal-name collision / relay contract** — same item as **C-1** above (the scenario pass surfaced it; downgraded once the Overworld Navigation relay layer was confirmed to own `encounter_type`). Applied as the TBC 2026-07-13 erratum.

**S-B2 · Battle-end subscriber ordering and "resolve-before-teardown."** *(Downgraded from Blocker.)* TBC Rule 12 discarded runtime state on the line after `emit`; the scenario pass worried a teardown could beat the Drop System's read of `beacon_used_this_battle` / the break set. Under **Godot's synchronous signal model**, `emit_signal` blocks until every connected subscriber returns, so the discard on the next line runs *after* Drop resolves — no race. Residual: the ordering guarantee was implicit. **Applied fix:** TBC Rule 12 now states runtime state (Structure/Energy/Heat, break pools, `beacon_used_this_battle`) is discarded only after all subscribers return, and that inter-subscriber *ordering* is deliberately not relied upon (each reads disjoint state or payload-carried values).

**S-W1 · Cross-consumer save atomicity is undefined** — a crash mid-bundle can persist a level-up without its `win_count` (or vice-versa). Owned by the unwritten Save/Load #17; the synchronous-emit contract (S-B2 fix) gives Save/Load a clean post-teardown latch point. EP OQ-EP-2 already names the competing save triggers.

### ℹ️ Info

- **S-I1 · Dropped-CORE `register_core` lives only in Core Progression's Bidirectionality notes as a pending Inventory erratum** — Inventory's GDD has no such call. Non-fatal (EC-CP-07 lazy-creates a record on first read), but track the erratum so the CP Rule 1 "one-to-one on first-add" invariant isn't left to the fallback.
- **S-I2 · Spillover-kill harvest-erasure (EC-PB-03) is correct and telegraphed** — but the "I finished too soon" lesson only lands if Combat UI distinguishes it from a clean break-then-kill. Note for when Combat UI is authored.
- **S-I3 (positive) · Mid-bundle level-up is verified inert** — no retroactivity defect: DS-F-LEVEL reads *enemy* level not core level, the equip gate is Workshop-only and battle-locked-out, and CP-F3 is a battle-start snapshot. A genuinely clean seam.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| **symbot-core-progression.md** | CP-F3 breaches DF-1 input ceiling (168 vs 150) + max_energy/max_structure ranges (C-2); anti-grind invariant needs a testable AC + open CD sign-off (D-2) | Consistency + Design | **Blocking** (C-2) |
| damage-formula.md, symbot-assembly.md, consumable-database.md, part-database.md | Declared stat ranges falsified by CP-F3; reconcile ranges/scan (C-2) | Consistency | Warning→Blocking |
| part-database.md ↔ turn-based-combat.md | Base regen double-owned (`BASE_REGEN` vs `BASE_ENERGY_REGEN`) (C-3) | Consistency | Warning |
| synergy-system.md | Dead DF-1 [1,165] + already-discharged obligation (C-4) | Consistency | Warning |
| drop-system.md | Rule 4 pre-erratum partial DS-1 (C-5); name the relayed `battle_ended` explicitly (C-1) | Consistency | Warning |
| part-database.md | One-directional CP dependency (C-6) | Consistency | Warning |
| zone-world-map.md, encounter-zone.md | Name the ON-relayed `battle_ended(result, encounter_type)` explicitly once Overworld Navigation is authored (C-1) | Consistency | Warning |
| move-database, enemy-database, symbot-assembly | Stale "Not Started" status labels for now-Approved systems | Consistency | Info |
| **turn-based-combat.md** | ✅ **RESOLVED 2026-07-13** — battle_ended synchronous-teardown/ordering contract + signal-name disambiguation applied (C-1/S-B2) | Consistency + Scenario | Done |

*(Systems-index status set to Needs Revision for **symbot-core-progression** only. TBC #6 re-approved same day after the erratum.)*

---

## Verdict: **CONCERNS**

The 19 designed systems are holistically sound — one coherent fantasy, no registry value conflicts, no orphan systems, no dominant strategy that breaks the pillars. One **blocking** issue remains: **C-2**, the CP-F3 level-growth range breach that falsifies DF-1's declared/scanned input domain and several stat ranges. The two seams initially read as blocking (`battle_ended` payload C-1/S-B1, subscriber ordering S-B2) proved to be a signal-name/relay-contract hygiene issue plus an implicit-but-safe Godot synchronous-signal guarantee; both were tightened by a TBC erratum the same day and are now Warnings.

### Recommended before architecture

1. **Resolve C-2 (the one blocker)** — cap `level_growth` away from power stats OR extend the DF-1 input range and re-run the float-safety scan; update the falsified ranges in Damage / Assembly / Consumable / Part DB. Bundle the D-2 anti-grind AC + CD sign-off in the same Core Progression pass.
2. **Doc-hygiene warnings** — C-3 (base-regen naming), C-4 (synergy dead range), C-5 (drop Rule 4 label), C-6 (Part DB↔CP dep), stale status labels. Low-risk batch edits.
3. **Ratify the ON relay** — when Overworld Navigation (#16) is authored, formalize the `battle_ended(result, encounter_type)` relay contract and update ZWM/EZ dependency rows (C-1 remainder).

The economy/tuning warnings (D-1 Scrap sink pending Workshop, D-3/D-4/D-5/D-7 playtest watches, D-6 unset consumable frequencies) should be resolved but are gated on the 4 unwritten MVP systems or on playtest — they don't block architecture of the designed set.
