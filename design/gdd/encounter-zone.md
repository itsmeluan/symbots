# Encounter Zone System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-11
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 5 (The World Is a Workshop)

## Overview

The Encounter Zone System is the spawn-table authority for each explorable area in Symbots. It answers one question per zone: *"Which enemies can the player fight here, and under what conditions?"* A zone definition is a static data resource — a named zone entry listing its eligible WILD enemy pool (weighted spawn probabilities drawn from Enemy DB entries), any area-restricted spawn rules (density bands, encounter rate), and the BOSS gate condition that must be met before the zone's boss encounter becomes accessible.

At runtime the Overworld Navigation system triggers an encounter event; the Encounter Zone system resolves which enemy ID to load (selecting from the WILD pool by weighted draw, or loading the BOSS if the gate is open and the player initiates a boss encounter). The selected ID is handed to Turn-Based Combat, which instantiates the enemy from the Enemy Database. The Encounter Zone owns no combat state — it is read-only at runtime, serving as the bridge between "where the player is standing" and "what battle starts."

In MVP there is exactly one zone. The zone schema is designed to generalize (additional zones in Vertical Slice and beyond add zone entries without schema changes), but MVP content only populates one entry. Boss gates in MVP are cleared when the player has won a sufficient number of WILD encounters in the zone, ensuring the boss is not immediately accessible but does not require any specific enemy type or drop to unlock.

## Player Fantasy

The player never thinks "the encounter zone system selected an enemy." They think: *"There are Crawlers past the scrap dunes — I need two more Servo Arms to finish the build."*

The Encounter Zone system's job is to make that thought possible. It ensures every enemy available in the zone is a meaningful hunt target for at least one part hypothesis. The zone's enemy roster is the player's ingredient list, and the list must be curated enough that a player entering the zone always has a reason to fight. A zone with random filler encounters — enemies that drop nothing the player cares about — breaks the "World Is a Workshop" promise. Every enemy in the spawn table earns its place by offering parts that belong in someone's build.

The boss gate reinforces the same feeling from another direction: the boss doesn't wait calmly for the player to stumble into it. Clearing enough WILD encounters to open the gate makes the boss feel *earned* — the player has been in the zone, understands its enemies, and now faces the zone's apex. The boss offers Boss-grade parts unavailable anywhere else; the gate ensures the player arrives having already learned the zone's element identities and break patterns.

*(Pure infrastructure note: this section documents the design intent and player experience the Encounter Zone must support — not a player-facing system that requires its own UX. The fantasy is owned by the hunt loop; this system enables it.)*

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
