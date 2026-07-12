# Consumable Database

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 5 (The World Is a Workshop), Pillar 2 (Every Battle Has a Harvest Goal) — support layer under Pillar 1 (Engineer, Don't Collect)

## Overview

The **Consumable Database** is the schema authority for every usable item in Symbots — the salvaged machine-tech a player carries into and out of a fight. It answers one question per item: *"What is this, how rare is it, and what does it do when used?"* A consumable definition is a static data resource — a named entry declaring the item's display name, rarity tier, effect (type and magnitude), the context it can be used in (in battle, in the overworld, or both), and how it stacks in the inventory. Like the Part and Enemy Databases, it stores **definitions only**: it is read-only at runtime and holds no per-save quantities (owned by the Inventory System).

The database has a player-facing edge the other schema authorities lack: its entries are items the player *actively uses*. A **Repair Kit** welds Structure back onto a battered Symbot; a **Coolant Flush** dumps a dangerous Heat gauge; a **Signal Jammer** buys quiet passage through a swarm-nest. Every downstream system that consumes an item reads its effect from here — Turn-Based Combat applies the resource restores, the Drop System scatters consumables as loot, and Encounter Zone reads the repel/lure modifiers — but the Consumable Database owns the single source of truth for *what each item is*. Consumables are a deliberately **small support layer**: they smooth the moment-to-moment hunt without replacing build decisions — healing remains primarily a REPAIR *move*, a choice made in the Workshop, not a stockpile of potions (Pillar 1).

In MVP the database defines a compact roster of **six items** across the standard rarity tiers, dropped from enemies via a level/rarity-scaled table (Drop System). The schema is designed to generalize — later tiers add entries and new effect types without schema changes — but MVP content populates only the six. **Designs/blueprints remain an Alpha drop class** (Blueprint Crafting #25); the MVP consumable layer is **drops-only**, with no crafting or shop faucet.

## Player Fantasy

[To be designed]

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
