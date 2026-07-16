# Epics Index

Last Updated: 2026-07-16
Engine: Godot 4.7

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Part Database](part-database/EPIC.md) | Foundation | Part Database | design/gdd/part-database.md | 11 stories | Complete |
| [Move Database](move-database/EPIC.md) | Foundation | Move Database | design/gdd/move-database.md | 6 stories | Complete |
| [Passive Database](passive-database/EPIC.md) | Foundation | Passive Database | design/gdd/passive-database.md | 7 stories | Complete |
| [Consumable Database](consumable-database/EPIC.md) | Foundation | Consumable Database | design/gdd/consumable-database.md | 8 stories | Complete |
| [Enemy Database](enemy-database/EPIC.md) | Foundation | Enemy Database | design/gdd/enemy-database.md | 10 stories | 9/10 — code Complete; 010 Ready (Part-DB gate cleared) |
| [Damage Formula](damage-formula/EPIC.md) | Foundation | Damage Formula | design/gdd/damage-formula.md | 3 stories | Complete |

## Layer Status

- **Foundation** — 6 epics defined; **Part Database (11), Move Database (6), Passive Database (7), Consumable Database (8), and Damage Formula (3) all Complete** as of 2026-07-16. **Enemy Database: 9/10 stories implemented, tested & closed (schema, loader, EDB-1 formula, all six ContentValidator families) — 623/623 GUT green.** Story 010 (MVP roster content authoring) is now **Ready** — the Part-DB content gate was CLEARED 2026-07-16 by enriching the Part roster with an anatomy-linked break-event vocabulary (now 15 parts: every RARE break-gated, 2 distinct BOSS_GRADE exclusives; part CI 623/623 green). Remaining Foundation gap is authoring the enemy `.tres` roster (Story 010), then closing the epic. All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps.
- **Core** — not yet epicked (run `/create-epics layer: core` when Foundation is nearly complete)
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

All six Foundation epics are implemented and green (623/623 GUT). **Enemy Database
stories 001–009 (all code) are Complete; Story 010 (content authoring) is now Ready** —
the Part-DB break-gated roster was authored 2026-07-16 (15 parts, anatomy break-event
vocabulary), clearing the gate. Foundation's *code* is complete.

Two tracks from here:
1. **Author Story 010** — write the ~8 WILD + 2 BOSS `EnemyDef` `.tres` + `EnemyCatalog`,
   run the smoke pass, and close the Enemy-DB epic → Foundation fully Complete.
2. **Core layer** — run `/create-epics layer: core` to begin Core epics (the Enemy-DB
   code deliverable already unblocks the systems that read it).
