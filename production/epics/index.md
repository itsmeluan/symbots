# Epics Index

Last Updated: 2026-07-16
Engine: Godot 4.7

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Part Database](part-database/EPIC.md) | Foundation | Part Database | design/gdd/part-database.md | 11 stories | Complete |
| [Move Database](move-database/EPIC.md) | Foundation | Move Database | design/gdd/move-database.md | 6 stories | Complete |
| [Passive Database](passive-database/EPIC.md) | Foundation | Passive Database | design/gdd/passive-database.md | Not yet created | Ready |
| [Consumable Database](consumable-database/EPIC.md) | Foundation | Consumable Database | design/gdd/consumable-database.md | Not yet created | Ready |
| [Enemy Database](enemy-database/EPIC.md) | Foundation | Enemy Database | design/gdd/enemy-database.md | Not yet created | Ready |
| [Damage Formula](damage-formula/EPIC.md) | Foundation | Damage Formula | design/gdd/damage-formula.md | 3 stories | Complete |

## Layer Status

- **Foundation** — 6 epics defined; **Part Database (11), Move Database (6), and Damage Formula (3) all Complete** as of 2026-07-16 (Part DB reopened + re-closed same day for story-011 validator hardening); 3 remaining epics unstoried (Passive / Consumable / Enemy). All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps.
- **Core** — not yet epicked (run `/create-epics layer: core` when Foundation is nearly complete)
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

Part Database (11), Move Database (6), and Damage Formula (3) are implemented and
green. Next Foundation work is one of the three unstoried epics — story the next as
it approaches (`/create-stories passive-database`, etc.).
