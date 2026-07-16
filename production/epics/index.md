# Epics Index

Last Updated: 2026-07-16
Engine: Godot 4.7

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Part Database](part-database/EPIC.md) | Foundation | Part Database | design/gdd/part-database.md | 11 stories | Complete |
| [Move Database](move-database/EPIC.md) | Foundation | Move Database | design/gdd/move-database.md | 6 stories | Complete |
| [Passive Database](passive-database/EPIC.md) | Foundation | Passive Database | design/gdd/passive-database.md | 7 stories | Complete |
| [Consumable Database](consumable-database/EPIC.md) | Foundation | Consumable Database | design/gdd/consumable-database.md | 8 stories | Ready |
| [Enemy Database](enemy-database/EPIC.md) | Foundation | Enemy Database | design/gdd/enemy-database.md | 10 stories | Ready |
| [Damage Formula](damage-formula/EPIC.md) | Foundation | Damage Formula | design/gdd/damage-formula.md | 3 stories | Complete |

## Layer Status

- **Foundation** — 6 epics defined; **Part Database (11), Move Database (6), Passive Database (7), and Damage Formula (3) all Complete** as of 2026-07-16 (Part DB reopened + re-closed same day for story-011 validator hardening; Passive DB implemented same day — 370/370 GUT green); Consumable Database storied (8) and Enemy Database storied (10) 2026-07-16 — **all 6 Foundation epics now storied**. All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps.
- **Core** — not yet epicked (run `/create-epics layer: core` when Foundation is nearly complete)
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

Part Database (11), Move Database (6), Passive Database (7), and Damage Formula (3)
are all implemented and green. **All 6 Foundation epics are now storied** —
Consumable (8) and Enemy (10) were storied 2026-07-16 and await implementation.
Begin implementation with `/story-readiness production/epics/consumable-database/story-001-consumabledef-schema-enums-catalog.md`
(or the Enemy DB story-001). Foundation is two implementation passes from complete,
after which Core layer epics can begin (`/create-epics layer: core`).
