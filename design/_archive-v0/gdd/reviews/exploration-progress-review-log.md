# Review Log — Exploration Progress System (design/gdd/exploration-progress.md)

## Review — 2026-07-13 — Verdict: APPROVED (round-2 confirmation — NEEDS REVISION → 2 new blockers + 2 fold-ins fixed same session; CD commit-approve honored, no round 3)
Scope signal: S (persistence contract layer; effort dominated by 15 BLOCKING unit tests)
Specialists: game-designer, systems-designer, qa-lead, creative-director (senior)
Blocking items: 2 | Recommended: 10 | Advisory: 6
Summary: All 4 round-1 blockers verified fixed by all three specialists. Two new true gates found and fixed same session: (1) MIGRATE path behavior was completely unspecified (SD+QA converged) — Rule 9 now normative: hookless MIGRATE → REFUSE under the full no-partial-restore guarantee (also discharges the MIGRATE-mid-failure conditional), AC-EP-02(b) rewritten with positive domain-state assertion + fall-through/silent-zero discriminators; (2) AC-EP-12's log-content assertion was untestable in GUT (push_error not capturable) — Rule 3 serialize now returns structured result {ok, failed_domain, error}, new Rule 3a.3 injectable warning sink covers all warning-count ACs. Two CD-mandated fold-ins: String-cast sort made normative (Rule 1 + AC-EP-01 fixture insertion order now normative); Player Fantasy OQ-EP-2 qualifying sentence (GD's challenge to prior CD adjudication upheld). Also landed: Rule 6(e) normative clamp ordering, domain-key-collision startup assertion, #17 forward-notes (quiesce precondition, save-repaired notice).
CD adjudications: GD's APPROVED overruled (both gates outside GD's domain); StringName sort held at advisory severity but folded in as one-liner; QA's advisory→blocking promotion of AC-EP-12 ruled legitimate (un-runnable BLOCKING AC = defect in deliverable, not scope creep); SD's clamp-ordering blocker downgraded (CD traced all four clamp-order permutations — the only dangerous one is AC-EP-06-covered).
Prior verdict resolved: Yes (round-1 NEEDS REVISION, 2026-07-13)

### Backlog recommended items (CD-adjudicated non-gating; for future pass or downstream GDD authoring)
1. [game-designer] EP-INV-1 rationale: name save-editing as known-and-accepted abuse vector (single-player)
2. [game-designer] OQ-EP-1: encode default-by-omission decision (re-added boss = new encounter per EC-ZWM-10)
3. [game-designer] World Loot domain row: double-collect ownership, loot_id format/stability, size cap → "#13 must resolve" sub-bullets
4. [game-designer] Anti-checklist: convert aspiration to explicit delegation to #20/#13 (not mechanically enforced here)
5. [systems-designer] Rule 6(e) check ownership: clarify domain-implemented vs system-level guard (one sentence)
6. [qa-lead] AC-EP-09: promote deep-copy nulling sub-fixture to formal numbered step
7. [qa-lead] Rule 3a.1: close autoload-singleton bypass in "cross-domain read" definition
8. [qa-lead] EC-EP-15: classify null sub-blob (Rule 6a missing vs 6d wrong-type) + third AC-EP-07 fixture
9. [qa-lead] Deferred ACs: name qa-lead as activation owner; concrete fixture for DEFERRED-A
10. [qa-lead] AC-EP-10: note world_loot excluded pending #13; extend to 3-domain orders when #13 ships

### Advisory
- Opaque store must survive/clear on reset_to_new_game() (Rule 7 — becomes real when title-screen flow ships)
- Rule 3a.1 accessor cycle: benign, but RefCounted cyclic-reference leak note for implementer
- EP-PRED-1 saved=0 is dead code at v1 (documented as such post-fix)

### Errata now due (approval trigger)
- **Encounter Zone Rule 8a** reword: "ZWM implements the increment; Exploration Progress persists the counter" — one line, tracked in EP Rule 2 + Bidirectionality Notes


## Review — 2026-07-13 — Verdict: NEEDS REVISION (4 blockers fixed same session — pending fresh-session confirmation re-review)
Scope signal: S (CD; game-designer estimated M — delta is test-fixture effort; producer to verify)
Specialists: game-designer, systems-designer, qa-lead, creative-director (senior)
Blocking items: 4 | Recommended: 8 | Advisory: 4
Summary: Structurally sound persistence-contract GDD — source-facts-only / re-derive-on-load architecture confirmed correct. Four surgical blockers, all fixed same session: (1) EP-INV-1 clamp direction silently revoked earned re-gates → changed to clamp-to-0 (over-credit; user decision), AC-EP-05 gained earned-regate discriminator (a2); (2) threshold notation trap (0-indexed preamble array vs CP-F1 level-indexed) → preamble rewritten level-indexed + inline level annotations in AC-EP-01/-03/-10/-13; (3) Rule 3 contract lacked the testability seams its own ACs require → new Rule 3a (injectable cross-domain accessor + `restore_records()` record-level path), AC-EP-14/AC-EP-08B updated; (4) Player Fantasy contingent on undefined save timing → new OQ-EP-2 + Rule 8/dependency-row cross-refs (CD reframed GD-B1 as contingency, not legislation of #17). CD adjudications: EC-EP-09 atomicity stays advisory (blob valid by Rule 4; sequencing is #17's job); QA-B2+QA-B3 merged as one contract defect. CD verdict: commit-approve on fixes landing.
Prior verdict resolved: First review

### Recommended items left open (for future pass or downstream GDD authoring)
1. [game-designer] Anti-checklist opaqueness constraint on world_loot domain row (or delegate to World Map UI #20 GDD)
2. [game-designer] OQ-EP-1 re-added boss semantics — decide rather than defer (3 cheap options listed in review)
3. [game-designer] World Loot provisional contract gaps: loot_id format/stability, uniqueness scope, size cap, double-collect rule → for #13 authoring
4. [systems-designer] EP-INV-1 check ownership (system-level guard vs domain-internal) — one sentence in Rule 6e
5. [systems-designer] Extend REFUSE no-partial-restore guarantee to MIGRATE mid-failure (Rule 9)
6. [qa-lead] AC-EP-09: pin progress_format_version: 1; promote deep-copy discriminator to formal sub-step
7. [qa-lead] Deferred ACs: name qa-lead as activation owner; concrete fixture for DEFERRED-A
8. [game-designer] Two-blob save atomicity constraint note → for Save/Load #17 authoring

### Advisory (nice-to-have)
- StringName sort trap: world_loot sort must cast String(key) — StringName.operator< compares intern index
- Opaque store must survive reset_to_new_game()
- AC-EP-12 needs injectable logging facade to be GUT-spy-able; AC-EP-02(b) MIGRATE-at-v1 observable contract note
- NG+ source-counter constraint note; CLEARED→ACCESSIBLE patch consequence needs UI communication flag

### Errata still owed on approval
- Encounter Zone Rule 8a hook wording ("ZWM implements the increment; Exploration Progress persists the counter") — one line, tracked in EP Rule 2 + Bidirectionality Notes
- Systems-index note: World Map UI dependency row resolves to ZWM (applied 2026-07-13 — already in index row #20)
