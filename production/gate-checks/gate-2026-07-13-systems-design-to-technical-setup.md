# Gate Check: Systems Design → Technical Setup

**Date:** 2026-07-13
**Checked by:** /gate-check (lean mode — all four directors ran)
**Verdict: CONCERNS — passable; advanced to Technical Setup.** `stage.txt` updated Concept → Technical Setup.
**Chain-of-Verification:** 5 questions checked — verdict unchanged (CONCERNS). Two tool actions confirmed OQ-CP-6 resolved (PR concern #2 stale) and stage.txt stale.

---

## Required Artifacts: 3/3 present
- [x] `design/gdd/systems-index.md` — 25 MVP systems enumerated; dependency map; priority tiers; recommended design order + effort estimates.
- [x] All 19 MVP mechanical GDDs (Foundation/Core/Feature/World) pass `/design-review` — 8/8 sections, no MAJOR REVISION verdict.
- [x] Cross-GDD review report — `design/gdd/gdd-cross-review-2026-07-13.md`, verdict **PASS** (after an in-session blocker fix).

## Quality Checks: pass
- [x] `/review-all-gdds` verdict not FAIL — PASS (the boss-completion-bonus refight-flood blocker was found and fixed same session).
- [x] All cross-GDD consistency issues resolved or accepted — C-2 (CP-F3 range breach), C-3 (base-regen double-name), C-4 (synergy stale DF-1 range), C-5 (drop Rule 4 partial DS-1), C-6 (Part DB↔CP dep), and the boss-refight guard — all fixed. 2 advisories accepted (`is_build_valid`/`can_equip` interface enumeration → defer to architecture; enemy-ai `H_cur [1,594]` vs 612).
- [x] System dependencies mapped + bidirectionally consistent — clean DAG, no cycles (the one mutual-reference edge CP↔TBC verified cycle-safe as a stateless query).
- [x] MVP priority tier defined; no live stale GDD references (the stale ones fixed in the C-3..C-6 batch).
- [x] `/consistency-check` PASS; entity registry synced (48 constants / 34 formulas / 8 items; YAML valid).

## Director Panel Assessment

**Creative Director: READY** (2 non-blocking concerns)
- Pillars faithfully represented across all 19 GDDs; single coherent fantasy; no orphan systems; no dominant strategy. The one design decision that could have compromised the vision — leveling — is closed at the formula level (Rule 6a power-stat ban + AC-CP-21 discriminating invariant: L4 build beats L8 by ~5.3×). "The workshop still wins the fight."
- Carry-forward: (1) architect Scrap/Part-Upgrade as first-class persistent state despite the missing #15/#26 GDD; (2) formalize the `battle_ended` relay as two distinct named signals when Overworld Nav is authored; (3) treat the Save/Load contract in Exploration Progress as normative; (4) sequence `/art-bible` before architecture concludes (modular-rendering risk).
- Presentation directive (not a gate item): leveling stays a quiet byproduct in UI, never a foreground grind screen.

**Technical Director: CONCERNS** (all "resolve during the first ADRs")
- Exceptionally well-specified corpus; the registry is already close to an interface-contract document; Foundation formulas are ADR-derivable today; Godot 4.6 HIGH-risk domains don't apply to a turn-based 2D Mac/iOS game (exception: AccessKit/accessibility → UI-layer note for #18–22).
- Concerns: (1) Save/Load (#17) ordering is correct — architect it as an ADR now, but there's no single durable-state manifest and Workshop (#15) is an undesigned dependency of the save schema; generalize Exploration Progress's domain-envelope so Workshop slots in later without a format bump. (2) No persistence/serialization budget — uncapped part *instances* vs iOS 512MB ceiling could force a bad lock-in if serialization is naive; add a blob-size/save-time budget to technical-preferences.md. (3) Minor stale-data cleanup (playtest-gated balance OQs + EAI-1 H_cur range).

**Producer: CONCERNS** (4 cheap items)
- Sequencing correct (architect the mechanical foundation now, design UI/persistence during pre-pro); scope disciplined (zero scope-creep orphans, all 19 map to pillars); cross-review PASS.
- Concerns: (1) re-classify #16 Overworld Nav and #17 Save/Load OUT of the deferred-UI bucket — they own contracts the approved set already depends on; they must *lead* Technical Setup. (2) ~~Close OQ-CP-6 + D-2~~ — **already resolved** (OQ-CP-6 CD-ratified 2026-07-13; D-2 = AC-CP-21; verified in-file — this item drops off). (3) Declare MVP scope frozen (2 discretionary MVP additions in 3 days is the velocity to arrest). (4) Fix `stage.txt` (was "Concept") — DONE.
- Stress point: the 6-month clock is an *implementation* clock that hasn't started (`src/` empty). Keep Technical Setup lean; drive to a playable combat vertical slice fast.

**Art Director: CONCERNS** (art bible absence is EXPECTED at this gate — it's a Technical Setup deliverable, per the gate coverage table)
- Visual Identity Anchor is well-formed and sufficient to begin the art bible (one-line rule "every element must feel like it grew here", supporting principles, color philosophy, reference alignment).
- Concerns (rework risks if not handled before the art-bible review closes): (1) element-color contract locked in 5 approved GDDs (Volt=cyan/Thermal=amber/Kinetic=white) — art bible must AUDIT before proposing a palette, or it triggers errata on TBC/Part-Break/Assembly/Consumable. (2) 8-layer modular sprite architecture committed in Assembly without dimension/format spec — the rendering ADR needs sprite canvas dims + sheet organization from the art bible FIRST. (3) rarity glow language (4 tiers) implies shader capability not yet validated — shader architecture ADR needs the art bible's visual targets. (4) "never color alone" accessibility standard committed without a defined palette alternative — art bible must include an accessibility chapter.

**Panel rule applied:** no NOT READY → not a FAIL; ≥1 CONCERNS → verdict is CONCERNS (not PASS). All required artifacts + quality checks pass, so the gate is passable and advancing is appropriate.

---

## Consolidated Technical Setup Agenda (deduplicated from all 4 directors)

1. **Run `/art-bible` early** — before the rendering/sprite/shader ADRs. Brief it with the locked GDD visual commitments (element colors, 4 rarity glows, 8-layer sprite z-order, 2.0s turn timing, "never color alone"); include an accessibility chapter. *(AD 1–4, CD 4)*
2. **Save/Load (#17) + Overworld Nav (#16) LEAD Technical Setup** — reclassify out of the deferred-UI bucket. Architect Save/Load as the first ADR (ratify Exploration Progress's serialize / version-refusal / source-vs-derived contract; generalize the domain-envelope so Workshop slots in without a format bump). Formalize the `battle_ended` relay as two distinct named signals. *(PR 1, TD 1, CD 2–3)*
3. **Architect Scrap/Part-Upgrade as first-class persistent state** — even though #15/#26 aren't written; treat Drop System's cost curve as a binding constraint on the future Workshop GDD. *(CD 1)*
4. **Add a persistence/serialization budget** to `.claude/docs/technical-preferences.md` — save-blob-size + save-time bounds for uncapped part instances vs the iOS 512MB ceiling. *(TD 2)*
5. **Declare MVP scope frozen.** *(PR 3)*
6. **Housekeeping:** `stage.txt` fixed (Concept → Technical Setup); clear the enemy-ai `H_cur [1,594]→612` advisory; complete the light sibling `/design-review` confirmation touches (consumable-database, symbot-assembly, turn-based-combat, enemy-level-zone-scaling) tracked in `production/errata-backlog.md`. *(PR 4, TD 3)*

**Dropped (already resolved):** OQ-CP-6 (CD-ratified) + D-2 anti-grind AC (AC-CP-21) — verified in-file.

**On the 8 Not-Started MVP GDDs (Workshop, Overworld Nav, Save/Load, Workshop UI, Combat UI, World Map UI, Audio, Main Menu):** all four directors agreed these are correctly deferred — they are Presentation/Persistence *consumers* of already-specified state. Mechanics-first → presentation-later is the right order. Save/Load and Overworld Nav are the exceptions whose *contracts* must be architected early (agenda item 2).

---

## Recommended next steps
1. `/create-architecture` — produce the master architecture blueprint + prioritized ADR work plan (reads all GDDs + registry + engine reference). Foundation-layer + Save/Load + the `battle_ended` relay should be the first ADRs.
2. `/art-bible` — early, before the rendering/sprite/shader ADRs (can run in parallel with architecture per the CD/AD sequencing note).

### Verdict: CONCERNS — advanced to Technical Setup (stage.txt updated). Concerns are the Technical Setup work plan, not entry blockers.
