# Epics Index

Last Updated: 2026-07-16
Engine: Godot 4.7

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Part Database](part-database/EPIC.md) | Foundation | Part Database | design/gdd/part-database.md | 11 stories | Complete |
| [Move Database](move-database/EPIC.md) | Foundation | Move Database | design/gdd/move-database.md | 6 stories | Complete |
| [Passive Database](passive-database/EPIC.md) | Foundation | Passive Database | design/gdd/passive-database.md | 7 stories | Complete |
| [Consumable Database](consumable-database/EPIC.md) | Foundation | Consumable Database | design/gdd/consumable-database.md | 8 stories | Complete |
| [Enemy Database](enemy-database/EPIC.md) | Foundation | Enemy Database | design/gdd/enemy-database.md | 10 stories | 9/10 — code Complete; 010 BLOCKED (Part-DB content) |
| [Damage Formula](damage-formula/EPIC.md) | Foundation | Damage Formula | design/gdd/damage-formula.md | 3 stories | Complete |

## Layer Status

- **Foundation** — 6 epics defined; **Part Database (11), Move Database (6), Passive Database (7), Consumable Database (8), and Damage Formula (3) all Complete** as of 2026-07-16. **Enemy Database: 9/10 stories implemented, tested & closed (schema, loader, EDB-1 formula, all six ContentValidator families) — 623/623 GUT green.** Story 010 (MVP roster content authoring) is **BLOCKED on Part-DB content**: only 2 of 14 parts carry break-gating `drop_conditions`, so a 0-warning roster satisfying AC-ED-19 for ~8 WILDs is unsatisfiable. Decision 2026-07-16: ship 001–009 as the Enemy-DB deliverable; unblock 010 later by fleshing out the break-gated Part roster. The Enemy-DB **code** is complete — remaining Foundation gap is content, not code. All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps.
- **Core** — not yet epicked (run `/create-epics layer: core` when Foundation is nearly complete)
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

All six Foundation epics are implemented and green (623/623 GUT). **Enemy Database
stories 001–009 (all code) are Complete; Story 010 (content authoring) is BLOCKED on a
richer break-gated Part-DB roster** — deferred by decision, not a code gap. Foundation's
*code* is complete.

Two tracks from here:
1. **Core layer** — run `/create-epics layer: core` to begin Core epics (the Enemy-DB
   code deliverable unblocks the systems that read it).
2. **Unblock Story 010** (optional, any time) — flesh out the Part-DB break-gated roster,
   then author the MVP enemy roster `.tres` + `EnemyCatalog` and close 010.
