# Epics Index

Last Updated: 2026-07-15
Engine: Godot 4.6

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Part Database](part-database/EPIC.md) | Foundation | Part Database | design/gdd/part-database.md | 10 stories | Ready |
| [Move Database](move-database/EPIC.md) | Foundation | Move Database | design/gdd/move-database.md | Not yet created | Ready |
| [Passive Database](passive-database/EPIC.md) | Foundation | Passive Database | design/gdd/passive-database.md | Not yet created | Ready |
| [Consumable Database](consumable-database/EPIC.md) | Foundation | Consumable Database | design/gdd/consumable-database.md | Not yet created | Ready |
| [Enemy Database](enemy-database/EPIC.md) | Foundation | Enemy Database | design/gdd/enemy-database.md | Not yet created | Ready |
| [Damage Formula](damage-formula/EPIC.md) | Foundation | Damage Formula | design/gdd/damage-formula.md | Not yet created | Ready |

## Layer Status

- **Foundation** — 6 epics defined; Part Database broken into 10 stories (2026-07-15), 5 remaining epics unstoried. All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps.
- **Core** — not yet epicked (run `/create-epics layer: core` when Foundation is nearly complete)
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

Part Database stories are written (10). Begin implementation at the engine gate:
`/story-readiness production/epics/part-database/story-001-tres-typed-dict-roundtrip-spike.md`.
Story the remaining Foundation epics as they approach (`/create-stories move-database`, etc.).
