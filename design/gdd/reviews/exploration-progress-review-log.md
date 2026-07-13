# Review Log — Exploration Progress System (design/gdd/exploration-progress.md)

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
