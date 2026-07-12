# Zone & World Map System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 5 (The World Is a Workshop), Pillar 2 (Every Battle Has a Harvest Goal)

## Overview

The Zone & World Map System is the world-graph authority for Symbots: it defines the game's explorable zones as a directed graph of node entries — each wrapping an Encounter Zone definition — connected by traversal edges, and tracks runtime zone state (**locked**, **accessible**, or **cleared**) relative to the player's progress. In MVP the graph holds exactly one zone and two boss encounters, but the schema generalizes so that additional zones add entries without restructuring the graph contract. At runtime this system answers three questions for dependent systems: which zone the player is currently in, which adjacent zones they can enter, and whether a given boss gate is open. The World Map UI reads zone state for display; Overworld Navigation validates zone transitions against it; Exploration Progress serializes its win-count and boss-defeat records. The system holds no spawn logic or gate-type semantics — those are delegated to the Encounter Zone — and no persistence — that is delegated to Exploration Progress.

## Player Fantasy

The player's relationship with the Zone & World Map is built on two moments.

The first is the **zone unlock**: after clearing enough WILD fights to open the boss gate, defeating the boss, and returning to the world map — a path that was greyed out is now alive. A new zone name appears, a new terrain icon, and the player's mind immediately starts running: *"What drops in there? What parts does that boss hold? What synergies could that unlock?"* The map doesn't reward exploration for its own sake — it rewards *readiness*. You don't unlock the next zone because you walked far enough; you unlock it because you proved you understood the current one.

The second is the **purposeful return**: the world map as a shopping list at a glance. The player opens the map and immediately knows where their target is. *"The Servo Arms come from the Crawlers in Zone 1. Zone 2 is locked — I need 4 more wins."* The map confirms what the player already knows from the hunt loop and makes the next step legible. There is no wandering. Every navigation decision is a build decision.

The infrastructure beneath both moments — zone graph, state tracking, gate evaluation — is invisible when it works. The player never thinks about the zone-win counter. They think: *"I earned this."*

That is the fantasy: the world map as a progress ledger where every milestone is built, not given.

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
