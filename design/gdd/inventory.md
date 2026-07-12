# Inventory System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 1 (Engineer, Don't Collect), Pillar 3 (Build Depth Over Content Breadth)

## Overview

The **Inventory System** is the per-save store of everything the player has collected but not yet committed to a build: their **part instances**, their **stackable consumables**, and their **Scrap** balance. It is the single source of truth for *what the player owns*, sitting between the systems that produce items (Drop System, World Loot) and the systems that consume them (Workshop, part upgrading, in-battle item use). It holds two fundamentally different storage models under one roof: **parts are individual instances** — every copy is a distinct object with its own upgrade tier, never stacked or deduplicated, because two copies of the same part are genuinely different tools once you tier them differently and equip them on different Symbots (Part DB EC-05, DB5). **Consumables are stackable counts** — a quantity per item id, capped by the item's `max_stack`, because one Repair Kit is interchangeable with another. The system owns the operations the player performs on that store: acquiring items (and resolving what happens when a stack overflows its cap), scrapping surplus parts into currency, and querying holdings for the Workshop and Combat UIs. Beyond the plumbing, the inventory is where **Pillar 1 (Engineer, Don't Collect)** becomes tangible: opening it is opening a box of *hypotheses* — the untested Volt core, the third copy of an arm you could tier up, the boss part no one else has found. Crucially it is a **workbench, not a trophy case** — there is no completion counter, no "gotta collect them all" (anti-pillar); every item is present because it *could go into a build*, and surplus exists to be scrapped and reinvested, never to be hoarded for a checklist.

## Player Fantasy

The player never thinks "I am managing a data store." They think: *"I've got two of that arm now — I could tier one up for the Volt build and leave the other stock for the Kinetic one."*

The Inventory's fantasy is the **well-stocked workbench** — the quiet, grounding pleasure of a builder surveying their materials before they make something. In a build-craft game the inventory is where potential lives: every part sitting in it is a build you *haven't made yet*. The reference feeling is the Monster Hunter item box or the Path of Exile stash at its best — not a chore screen, but a place you actually *like* opening because it's dense with things you're excited to use. When the player returns from a hunt and drops three new parts into the box, the feeling should be *"what can I build now?"* — not *"where do I put this?"* The inventory serves the loop's turnaround: the moment between *collected* and *committed*, where a hypothesis gets picked up off the shelf.

Two feelings do the work:

1. **Possibility, not accumulation.** Opening the inventory should feel like opening a box of hypotheses, never like checking a completion list. This is Pillar 1 made physical — the parts are yours because you *hunted and will build* them, not because they fill a registry. The system deliberately withholds the collector's dopamine loop (no "12/50 discovered!", no dex): the reward for a duplicate is *"another tool"* or *"more Scrap to reinvest,"* never *"+1 toward 100%."* A player who hoards for a checklist is playing a game we didn't build; a player who scraps a surplus Common to tier up their main is playing exactly the one we did.

2. **Frictionless when working, invisible when full.** The other half of the fantasy is one the player should barely notice — the inventory just *holds* things, correctly, across sessions, without ever making the player fight it. Parts never silently merge or vanish; a stack that hits its cap resolves in a way the player understands and chooses, not a lossy surprise. Good inventory infrastructure is felt only in its absence — the fantasy breaks the instant a player loses a part to a bug or can't find the copy they tiered. So the emotional target here is split: a *warm* direct layer (the workbench you enjoy) over *rock-solid* plumbing (the store you can trust).

This is delivered jointly with the Inventory UI (touch-first browsing, sorting, the scrap action) and the Workshop (where holdings become builds) — this GDD builds the model and the rules those surfaces present.

## Detailed Design

### Core Rules

**Rule 1 — Three stores.** The Inventory holds exactly three logical stores per save:
- **`part_instances`** — a collection of `PartInstance` records (**uncapped** in MVP; Part DB EC-05).
- **`consumable_stacks`** — a map `consumable_id → quantity` (int, one logical count per id, `0 ≤ quantity ≤ max_stack`).
- **`scrap`** — a single non-negative integer currency balance (the game's sole currency; the Drop System economy / HOLISM-01 owns *yields and targets*, Inventory owns the *running balance*).

**Rule 2 — `PartInstance` schema.** Every part the player owns is a distinct instance:

| Field | Type | Notes |
|-------|------|-------|
| `instance_id` | int (StringName-safe) | Unique per-save, **stable, never reused** — the handle Workshop/UI reference |
| `part_id` | StringName | → Part DB definition (immutable; validates against Part DB) |
| `upgrade_tier` | int | Per-instance, `0 … max_upgrade_tier` (Part DB: 0–3 Common / 0–5 Rare+); mutated only by the upgrade path |

Instances are **never merged, stacked, or deduplicated** (Part DB EC-05). Two instances of the same `part_id` are fully independent. Equipped state is **not** a field here — it is owned by Workshop and *queried* (Rule 5).

**Rule 3 — Consumable stacks.** Consumables are stored as a single count per `consumable_id`, `0 ≤ quantity ≤ max_stack` (max_stack read-only from Consumable DB). A quantity of 0 means "none held" — an absent key is equivalent to 0. Inventory owns only the count; the definition (name, effect, cap) lives in Consumable DB.

**Rule 4 — Acquisition (`add`).** When an item enters inventory (Drop System, World Loot, future shop):
- **Part** → append a new `PartInstance` with a fresh `instance_id` and the dropped tier (default 0). Always succeeds (uncapped).
- **Consumable** → increment that id's count toward `max_stack`. If the add would exceed `max_stack`, the count is set to `max_stack` and the **excess is rejected** — not stored, not converted (no Scrap in MVP). The call returns `{accepted, rejected}` so the awarding system can surface a "stack full" notice. No silent loss (the reject is reported). *This resolves Consumable EC-CD-12 and un-blocks AC-CD-23.*
- **Scrap** → add to the balance (clamped at `SCRAP_MAX`, Tuning Knobs).

**Rule 5 — Scrapping a part.** The player may, by **explicit choice**, scrap a part instance: it is permanently removed from `part_instances` and the balance gains Scrap per the scrap-value formula (INV-1, Section D). Scrapping is:
- **Manual only** — never automatic (Part DB DB5: "scrapped at the player's choice, never auto").
- **Irreversible** — the instance is destroyed; no undo (the confirm dialog belongs to UI).
- **Blocked on equipped instances** — an instance currently equipped on any Symbot (per Workshop's equipped set) is **not scrappable**; the operation is rejected and the instance is untouched. The player must unequip in Workshop first. This is the safety guard that protects an in-use part.

**Rule 6 — Consumable use decrement.** On a **successful** consumable apply (TBC in-battle Rule 7a, or overworld use), Inventory decrements that id's count by 1. A **rejected** use (Consumable Rule 3) decrements nothing. Inventory refuses to decrement below 0 (EC-CD-04: nothing to use at quantity 0). Use *validation* (target/context) is owned by TBC/Consumable; Inventory owns only the count and the decrement.

**Rule 7 — Query interface (read-only, no mutation).**
- `get_parts(filter?) → [PartInstance]` — optionally filtered by `slot_type` / `rarity` / `part_family` (Workshop & UI)
- `get_consumable_count(id) → int`  ·  `get_scrap() → int`
- `has_instance(instance_id) → bool`  ·  `get_instance(instance_id) → PartInstance`
- `is_scrappable(instance_id) → bool` — false if the instance is equipped or missing

**Rule 8 — Ownership boundary (what Inventory does NOT do).** Does not: define parts/consumables (Databases); set drop frequency or the economy *target* (Drop System / HOLISM-01); equip/unequip or *store* equipped state (Workshop — Inventory only *queries* it for the Rule 5 guard); raise a part's tier (the upgrade path spends Scrap and mutates `upgrade_tier` — Inventory owns the field, not the upgrade logic); render, sort, or confirm in UI (Inventory/Combat UI); serialize to disk (Save/Load — Inventory defines the in-memory model it persists).

### States and Transitions

Inventory is a data store, not a state machine. The only lifecycle is a light one on `PartInstance`:

| State | Meaning | Enters via | Exits to |
|-------|---------|------------|----------|
| **HELD** | in inventory, not on a Symbot | `add` (acquire); Workshop unequip/displace | EQUIPPED (Workshop equip); SCRAPPED (player scrap) |
| **EQUIPPED** | installed on a Symbot (**Workshop-owned overlay**, seen via query) | Workshop equip | HELD (Workshop unequip/displace) |
| **SCRAPPED** | destroyed for Scrap (**terminal**) | player scrap of a HELD instance | — |

Scrapping an EQUIPPED instance is **blocked** (Rule 5) — the only guarded transition. Consumable counts are a plain int in `[0, max_stack]` (+N capped on acquire, −1 on successful use); the Scrap balance is an int in `[0, SCRAP_MAX]` (+yield on scrap/drop, −cost on upgrade / future purchase). Neither has sub-states.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** *(Approved)* | ← reads | Part definitions (`id`, `display_name`, `rarity`, `slot_type`, `part_family`, `flavor_text`, `max_upgrade_tier`, `upgrade_effects`) to validate `part_id` and display instances |
| **Consumable Database** *(Approved)* | ← reads | Consumable definitions (`id`, `display_name`, `rarity`, `max_stack`, use-context, effect metadata). Rule 4 enforces `max_stack` — **resolves EC-CD-12, un-blocks AC-CD-23** |
| **Drop System** *(Approved)* | → deposits | Awards part instances, consumable increments, and Scrap via `add` (Rule 4); receives `{accepted, rejected}` for stack-full feedback |
| **World Loot System** *(Not Started)* | → deposits | Same `add` interface for overworld chests/pickups |
| **Workshop System** *(Not Started)* | ↔ | Reads holdings (`get_parts`/`get_instance`) to build; **owns the equipped-instance set** Inventory queries for the Rule 5 scrap guard; mutates a `PartInstance.upgrade_tier` when upgrading (spending Scrap) |
| **Turn-Based Combat** *(Approved erratum)* | → decrements | On a successful in-battle item apply (TBC Rule 7a), calls Inventory to decrement a consumable count by 1 (Rule 6); rejected use decrements nothing. Wiring realized at TBC integration |
| **Save/Load System** *(Not Started)* | → serializes | Persists/restores the three stores; Inventory defines the serialization-friendly model (flat records, stable `instance_id`s) |
| **Inventory UI / Combat UI** *(Not Started)* | → surfaced by | Render holdings, sort/filter, scrap-confirm flow, stack-full notices |

*Provisional: Workshop / World Loot / Save/Load / UI are Not Started — their interface columns are the contract this GDD exposes for them. Part DB, Consumable DB, Drop System are Approved.*

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
