# World Loot System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-13
> **Implements Pillar**: Pillar 5 (The World Is a Workshop), Pillar 2 (Every Battle Has a Harvest Goal)

## Overview

The World Loot System is the static-placement and collection-state authority for overworld pickups: it defines an authored catalog of `LootNode` entries — each pairing a zone and authored position with a specific reward (a part instance, a Scrap quantity, or a consumable) — and at runtime tracks which entries the player has already collected. When the player interacts with a pickup in the overworld, this system resolves the award into the Inventory, marks that entry's `loot_id` as collected, and ensures it never reappears. The runtime collection ledger is the `&"world_loot"` domain that the Exploration Progress System serializes and restores across sessions. In the player's experience, this system is responsible for the moment of off-path discovery: the chest tucked behind a pylon cluster that yields exactly the Rare part needed to complete a build — a reward for curiosity, not a guaranteed drop from combat.

## Player Fantasy

Finding a world chest is the game rewarding you for looking. Not for winning a fight — for going the other way, trying the path that looked like a dead end, tapping a pylon cluster that seemed decorative. The moment the chest opens, the core feeling is **curiosity validated**: you went somewhere, and the world said *yes, that was worth it*.

The reward is deliberately **build-relevant but not grind-critical**. A chest might hold the Rare Arms part you've been farming from Crawlers — suddenly you have it without a targeted break. More often it's a part you didn't know you needed: a Rare you hadn't encountered yet that suggests a build direction you weren't considering. Either way, the chest communicates that *this world has depth* — there are things in it that aren't on the combat loop's beaten path, and the combat loop alone doesn't find them.

One thing this fantasy explicitly resists: the **completionist pull**. The collected ledger exists so the world remembers what's been taken — the chest stays visually open, the reward doesn't reappear. It does not exist to surface "12/14 chests found" as a percentage. World loot rewards presence and curiosity; it punishes treating the game as a checklist. The game concept's anti-pillar ("not a catch-em-all collector") applies directly: the world is not a registry to complete — it is a place worth looking around in.

> *(Note: `creative-director` not consulted — Lean mode. Review Section B manually before production.)*

## Detailed Design

### Core Rules

**Rule 1 — The LootNode Schema.** Every world pickup is defined by a `LootNode` entry in the World Loot catalog. The catalog is read-only authored content — no entry is ever created at runtime.

| Field | Type | Notes |
|-------|------|-------|
| `loot_id` | StringName | Globally unique across all content; **stability required** — renaming a `loot_id` after a save exists triggers EP Rule 6c orphan-handling (the collected fact is preserved but the chest re-appears as uncollected on load). Convention: `&"<zone_id>_<sequential>_<descriptor>"` (e.g., `&"starter_01_rare_servo_arm"`). Zone prefix guarantees global uniqueness by construction. |
| `zone_id` | StringName | References a ZoneNode in Zone & World Map (one-to-one: this node lives in this zone). |
| `world_position` | Vector2 | Authored tile position within the zone; consumed by Overworld Navigation for rendering and proximity detection. |
| `reward_type` | Enum | `PART` / `SCRAP` / `CONSUMABLE` / `BLUEPRINT` (reserved — see Rule 6) |
| `reward_payload` | Dictionary | Shape depends on `reward_type` — see Rule 2 |
| `is_hidden` | bool | `true` = node does not appear on the overworld until the player approaches within detection range (the "behind the pylon cluster" beat). `false` = always visible. |

**Rule 2 — Reward payload shapes (by `reward_type`).**

| `reward_type` | `reward_payload` shape | Notes |
|---|---|---|
| `PART` | `{ part_id: StringName }` | `part_id` must resolve in the Part Database; `drop_enabled` is not checked here (world loot is a hand-placed guarantee, not a drop table roll) |
| `SCRAP` | `{ amount: int, min: 1 }` | Flat deposit to Inventory Scrap balance |
| `CONSUMABLE` | `{ consumable_id: StringName }` | Must resolve in the Consumable Database |
| `BLUEPRINT` | reserved — not authored in MVP | See Rule 6 |

**Rule 3 — Collection is one-time and permanent.** When the player collects a `LootNode`: the reward is awarded to Inventory, the `loot_id` is added to the runtime collected Set, and the node's visual state flips to COLLECTED. A collected node **never reappears** — not on zone re-entry, not after saving and loading.

**Rule 4 — Double-collect is silently idempotent.** If `collect(loot_id)` is called and `loot_id` is already in the collected Set: no reward is awarded, no signal fires, no error is logged. Callers may but are not required to call `can_collect(loot_id)` first — the collect path is always safe.

**Rule 5 — `loot_id` global uniqueness is a hard content constraint.** The Exploration Progress domain is a flat global Set: there is no per-zone namespace in the collection ledger. Two LootNodes sharing a `loot_id` (even in different zones) would collapse to a single collected-state bit. World Loot performs a uniqueness validation pass at content load time: duplicate `loot_id`s are a **fatal content error** (load aborts, loud error), not a silent de-dupe.

**Rule 6 — BLUEPRINT reward type is reserved for Alpha.** The `BLUEPRINT` enum value is defined in schema now so content tooling can be extended without a breaking schema change. Authoring a `BLUEPRINT` node in MVP content is a **content error** (logged, node treated as INVALID). Blueprint Crafting (#25, Alpha) un-reserves this type when it ships.

**Rule 7 — EP domain contract (this system is the `&"world_loot"` domain).** This system implements the three-operation Exploration Progress domain contract:
- `snapshot()` → sorted `Array[StringName]` of all collected `loot_id`s (sorted via `String(a) < String(b)` — raw StringName sort is session-unstable); returns a fresh copy (no aliasing of the internal set).
- `restore(data: Array)` → replaces (never merges) the runtime collected Set with `Set(data)`, deduping on reconstruction.
- `rederive()` → no-op (the collected Set is a source fact, not a derived field — there is nothing to re-derive from it).

### States and Transitions

Each `LootNode` has exactly two states:

| State | Meaning | Visual |
|-------|---------|--------|
| `UNCOLLECTED` | Default; reward available | Closed chest / glowing indicator |
| `COLLECTED` | Permanently after `collect()` | Open chest / no indicator |

State is not serialized directly — it is **derived** from the runtime collected Set (if `loot_id ∈ collected_set` → COLLECTED; else UNCOLLECTED). On load, `restore()` re-populates the Set; the visual state of every node updates from that Set. There is no intermediate or transient state.

Content-error state: if a `LootNode`'s `loot_id` resolves to no catalog entry (removed content, authoring error), it is treated as a **phantom node** — not rendered, not collectable, no crash.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** (upstream) | This system reads `part_id` → validates the reward part exists; reads `display_name` + `sprite_id` for the reward reveal popup. `drop_enabled = false` does NOT block collection — world loot is hand-placed, not drop-table-sourced. | Hard dependency |
| **Consumable Database** (upstream) | Reads `consumable_id` → validates the reward item exists. | Hard dependency |
| **Zone & World Map** (upstream) | Groups `LootNode` entries by `zone_id`; on zone load, provides the list of nodes in that zone (both UNCOLLECTED and COLLECTED) to Overworld Navigation. Never reads ZWM at runtime — `zone_id` is a static reference on each node. | Soft — zone grouping only; this system can initialize without ZWM present |
| **Inventory** (downstream) | `collect()` calls Inventory's add-part / add-scrap / add-consumable interface. This system does not own Inventory state — it writes awards and trusts Inventory's own overflow/stack rules. | Hard at collection time |
| **Overworld Navigation** (downstream) | Provides the `LootNode` position list per zone for rendering. Receives `node_collected(loot_id)` signal after each successful collection. Overworld Navigation owns the interact gesture that triggers `collect(loot_id)` on this system. | Signal + API |
| **Exploration Progress** (downstream) | Registers as the `&"world_loot"` domain on EP startup; implements `snapshot()` / `restore()` / `rederive()`. EP serializes and restores the collected Set across sessions. | EP pulls via domain contract; no direct call |

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
