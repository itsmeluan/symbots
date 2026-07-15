<p align="center">
  <h1 align="center">Symbots</h1>
  <p align="center">
    You don't catch your team — you build it.
    <br />
    A turn-based creature-collection RPG about hunting wild machines for parts
    and engineering your own robotic companions from scratch.
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-pre--production-brightgreen" alt="Status: Pre-Production">
  <img src="https://img.shields.io/badge/GDDs-19%20MVP%20approved-blue" alt="19 MVP GDDs approved">
  <img src="https://img.shields.io/badge/architecture-8%20ADRs%20accepted-blue" alt="8 ADRs accepted">
  <img src="https://img.shields.io/badge/engine-Godot%204.6-478cbf?logo=godotengine&logoColor=white" alt="Godot 4.6">
  <img src="https://img.shields.io/badge/platform-Mac%20%7C%20iOS-lightgrey" alt="Mac | iOS">
</p>

---

## Elevator Pitch

Symbots is a creature-collection RPG where you explore a world of wild machines,
hunt specific components from your enemies, and engineer a team of modular
robotic companions called Symbots from interchangeable parts.

Every battle is a harvest decision: win fast, or target specific parts, damage
types, and finish conditions to maximize the chance of dropping exactly the
component you need. Power isn't given — it's engineered.

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Creature-collection RPG / Tactical Turn-based RPG / Crafting RPG |
| **Platform** | Mac (launch), iOS (primary long-term target) |
| **Player Count** | Single-player |
| **Session Length** | 30–90 minutes |
| **Comparable Titles** | Pokémon (main series), Monster Hunter World, Path of Exile |

## Game Pillars

1. **Engineer, Don't Collect** — every Symbot is assembled, not found
2. **Every Battle Has a Harvest Goal** — combat always targets a specific drop
3. **Build Depth Over Content Breadth** — fewer parts, deeper synergy
4. **Synergy Is the Endgame** — cross-system combinations reward mastery
5. **The World Is a Workshop** — exploration exists to feed the build loop

Full detail in [`design/gdd/game-concept.md`](design/gdd/game-concept.md).

## Project Status

Currently in **Pre-Production** — the Technical Setup → Pre-Production phase gate
**passed** on 2026-07-15 (all four directors READY), and the MVP scope is now
[frozen](production/mvp-scope-freeze.md). The core build/hunt loop was validated
in a throwaway concept prototype ([findings](prototypes/symbot-build-loop-concept/REPORT.md) —
verdict: **PROCEED**). Design, architecture, and the visual foundation are all in
place; implementation (`src/`) has not yet begun.

**Design — 19 MVP system GDDs approved**, each through a multi-agent `/design-review`:

| Layer | Systems | Status |
| ---- | ---- | ---- |
| **Foundation** | Part Database · Move Database · Passive Database · Consumable Database · Enemy Database · Damage Formula | ✅ Approved (6) |
| **Gameplay** | Symbot Assembly · Synergy · Turn-Based Combat · Part-Break · Enemy AI · Symbot Core Progression | ✅ Approved (6) |
| **World / Economy** | Encounter Zone · Enemy Level & Zone Scaling · Zone & World Map · Drop System · Inventory · Exploration Progress · World Loot | ✅ Approved (7) |
| **Integration · Presentation** | Workshop · Overworld Navigation · Save/Load · Workshop/Combat/Map UIs · Audio · Main Menu | ⏳ Implementation-tier (specced during production) |

**Architecture — complete.** 8 Accepted ADRs (0001–0008) cover Foundation, Core,
and Presentation tiers; requirements traceability sits at 251/277 with **zero
Foundation gaps**. See [`docs/architecture/`](docs/architecture/).

**Visual identity — foundation locked.** Art bible Sections 1–4 (Visual Identity
Statement, Mood & Atmosphere, Shape Language, Color System) are complete; Sections
5–9 are deferred to production. See [`design/art/art-bible.md`](design/art/art-bible.md).

Next up: the **first Pre-Production sprint** — Foundation/Core epics and stories
generated from the Accepted ADRs, then a vertical slice to validate the full core
loop is fun before committing to full Production. Full system breakdown, dependency
map, and design order in [`design/gdd/systems-index.md`](design/gdd/systems-index.md).

## Tech Stack

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Version Control**: Git, trunk-based development
- **Testing**: GUT (Godot Unit Testing)

## Project Structure

```
CLAUDE.md              # Project configuration
.claude/                # Agent/skill/hook framework (see "Built With" below)
design/                 # GDDs, entity registry, review logs
docs/                   # Technical documentation, engine reference
production/             # Sprint plans, session state
prototypes/             # Throwaway concept/vertical-slice prototypes
src/                    # Game source code (once implementation begins)
```

## Built With

Development is coordinated using [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) —
an open-source framework that structures a Claude Code session into a
studio-style team of specialized agents (design, programming, art, QA,
production) with defined workflows and quality gates. The `.claude/` directory
in this repo is that framework, kept in sync with the upstream template via
`git merge` (see [`UPGRADING.md`](UPGRADING.md)).

## License

The `.claude/` framework (agents, skills, hooks, rules) is MIT-licensed by its
original author — see [`LICENSE`](LICENSE). Game design documents, narrative,
and original art/code under `design/`, `docs/`, `src/`, and `assets/` are
© Luan, all rights reserved unless stated otherwise.
