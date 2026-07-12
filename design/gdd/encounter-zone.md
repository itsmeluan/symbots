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

**Rule 1 — Zone definition.** A zone is one static data resource. MVP authors exactly one. Fields:

| Field | Type | Notes |
|-------|------|-------|
| `zone_id` | StringName | Unique zone identifier (e.g. `&"scrapfield"`) |
| `display_name` | String | Player-visible zone name |
| `terrain_patches` | Array[TerrainPatch] | The zone's encounter terrains — see Rule 2 |
| `boss_encounters` | Array[BossEncounter] | The zone's bosses and their gates — see Rule 6 |
| `spawn_enabled` | bool | Zone-level master switch (mirrors Enemy DB `spawn_enabled`) |

**Rule 2 — Terrain patch (the encounter unit).** A terrain patch binds a terrain *type* to an enemy sub-pool. Terrain type is the player's coarse targeting lever — different terrain, different enemies.

| Field | Type | Notes |
|-------|------|-------|
| `terrain_type` | Enum | `MECHANICAL_GRASS`, `JUNKYARD`, `PYLON_FIELD`, `MACHINE_CAVERN` (extensible; content-authored per zone) |
| `enemy_subpool` | Array[SpawnEntry] | Weighted WILD enemy candidates — see Rule 4 |
| `encounter_rate` | float | Per-step probability of triggering an encounter (0.0–1.0) |
| `density_class` | Enum | `SPARSE` / `STANDARD` / `DENSE` — a labeled band for `encounter_rate` (Rule 5) |

A `SpawnEntry` = `{ enemy_id: StringName, spawn_weight: int }`. `enemy_id` must reference an Enemy DB entry whose `enemy_class == WILD` and `spawn_enabled == true`.

**Rule 3 — Encounter trigger (per-step roll).** While the player moves within a terrain patch, each step rolls against that patch's `encounter_rate` (Formula EZ-1). On success, an encounter is triggered from *that patch's* `enemy_subpool` (Rule 4). Steps on non-terrain tiles (paths, safe ground) never trigger. The trigger is owned by Overworld Navigation calling into this system; Encounter Zone owns the *resolution* (which enemy), not the movement detection.

**Rule 4 — Weighted enemy selection.** On a triggered encounter, select one `enemy_id` from the patch's `enemy_subpool` by weighted random draw (Formula EZ-2): each entry's probability = its `spawn_weight` ÷ the sum of all weights in that patch. The selected `enemy_id` is handed to Turn-Based Combat, which instantiates the enemy from Enemy DB. WILD encounters are fleeable (TBC Rule 7).

**Rule 5 — Density classes (dense biomes).** `density_class` maps to an `encounter_rate` band, giving the zone pacing texture:
- `SPARSE` — low rate; open/transitional terrain the player crosses without much friction.
- `STANDARD` — the default farming terrain.
- `DENSE` — high rate (near-every-step); the "cave/swarm-nest" fast-farm biome. Higher encounter throughput = faster farming at the cost of resource attrition between fights.

The exact rate per band is a Tuning Knob (Section G). Density is a *label*; the rate is the mechanism.

**Rule 6 — Boss encounter definition.** Each entry in a zone's `boss_encounters` defines one boss and how the player reaches it:

| Field | Type | Notes |
|-------|------|-------|
| `boss_id` | StringName | References an Enemy DB entry with `enemy_class == BOSS` |
| `placement` | Enum | `OVERWORLD` / `DUNGEON` / `HIDDEN` — where the boss lives (MVP: `OVERWORLD` only) |
| `gate_type` | Enum | How first-access is earned — see Rule 7 |
| `gate_params` | Dictionary | Gate-type-specific parameters (e.g. `{ required_wins: 6 }` or `{ wave_count: 3, wave_pools: [...] }`) |
| `repeat_policy` | Enum | Re-access model after first defeat — see Rule 9 |

**Rule 7 — Gate-type taxonomy (extensible; MVP fills three).** `gate_type` is one enum; each value is a *reward vector*:

| `gate_type` | Reward vector | First-access condition | MVP |
|-------------|---------------|------------------------|-----|
| `OPEN` | (baseline) | Always accessible — no gate | Authorable |
| `WIN_COUNT` | Grinding | Win `gate_params.required_wins` WILD encounters in this zone | **Boss 1** |
| `WAVE` | Fighting | Enter the boss arena and defeat `gate_params.wave_count` consecutive enemy waves; the boss appears after the final wave | **Boss 2** |
| `REACH` | Exploration | Player reaches a specific (hard-to-reach / hidden) map location | **Reserved** |
| `DUNGEON_RUSH` | Luck / skill | Boss sits deep in a dungeon; the player clears its mobs *or* rushes past them to reach it | **Reserved** |

`REACH` and `DUNGEON_RUSH` require spatial systems that do not exist yet (Zone & World Map #12, Overworld Navigation #16). Their enum values and `gate_params` shape are reserved here so the schema never changes when those systems ship; **no MVP content authors them**, and their spatial fulfillment is a provisional contract (Dependencies).

**Rule 8 — Gate evaluation (first access).** A boss's gate is evaluated against persistent player state (owned by Exploration Progress #14). Until the gate condition is met, the boss encounter is not offerable. `WIN_COUNT` reads a per-zone win counter; `WAVE` is evaluated live when the player enters the arena; `OPEN` is always met. When the condition is met, the boss becomes accessible (its overworld presence / entry becomes active).

**Rule 9 — Repeat policy (re-access for grinding).** After a boss's *first* defeat, its `repeat_policy` governs re-access so farming its parts stays viable but never free:
- `LIGHTER_REGATE` (MVP default) — the boss becomes repeatable behind a **reduced** gate: `WIN_COUNT` re-access uses a smaller win count; `WAVE` re-access uses fewer waves; a persistent map icon marks it. The specific reduction is a Tuning Knob.
- `ALWAYS_OPEN` — after first clear the boss is permanently accessible (no re-gate).
- `FULL_REGATE` — the original gate must be re-paid every time (reserved for special/limited bosses; no MVP content).

The "boss defeated at least once" flag is owned by Exploration Progress; this system reads it to select first-access vs. re-access behavior.

**Rule 10 — Enemy DB is the source of truth.** Encounter Zone stores no enemy stats, elements, regions, or loot — only `enemy_id` references. It reads `enemy_class` (to validate WILD-in-patches / BOSS-in-boss-slots), `spawn_enabled` (excluded when false), and respects `tier` (always 1 in MVP; no tier logic). An `enemy_id` in a spawn pool that is missing, `spawn_enabled == false`, or the wrong class is a content error (Edge Cases).

**Rule 11 — MVP content scope.** One zone; 3–4 terrain patch types drawn from ~8 WILD enemy types; 2 bosses (Boss 1 = `OVERWORLD`/`WIN_COUNT`, Boss 2 = `OVERWORLD`/`WAVE`), both `repeat_policy = LIGHTER_REGATE`. `REACH`, `DUNGEON_RUSH`, `DUNGEON`, and `HIDDEN` are reserved and unauthored.

### States and Transitions

WILD encounters are stateless — each is an independent per-step roll with no memory. The stateful element is the **boss gate lifecycle**, tracked per boss (persistent state owned by Exploration Progress, read by this system):

| State | Entered when | Exits to |
|-------|-------------|----------|
| `LOCKED` | Zone loaded, gate condition not yet met, boss never defeated | `UNLOCKED` when the gate condition is met (Rule 8) |
| `UNLOCKED` | First-access gate condition met, boss not yet defeated | `DEFEATED` on first victory; back to `LOCKED` only if the gate is progress-based and progress is externally reset (not in MVP) |
| `DEFEATED` | Boss defeated at least once | `RE_ACCESSIBLE` per `repeat_policy` (Rule 9) |
| `RE_ACCESSIBLE` | Post-defeat, re-access gate (lighter) available | Re-entered on each subsequent clear; stays available for grinding |

`OPEN` gates begin already `UNLOCKED`. For `WAVE` bosses, entering the arena runs a transient sub-sequence — `WAVE_IN_PROGRESS(n)` cycling through `wave_count` battles; a defeat or flee during the waves aborts the attempt (arena resets, no boss), and completing the final wave transitions the boss to an immediately-offered encounter. This wave sub-sequence is transient runtime state, not persisted.

The per-encounter transient flow (WILD): `EXPLORING` (player moving in a patch) → `ENCOUNTER_TRIGGERED` (EZ-1 roll succeeds) → enemy resolved (EZ-2) and handed to TBC → on `battle_ended`, return to `EXPLORING`. Encounter Zone holds none of this between steps — the movement/step state is Overworld Navigation's.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Enemy Database** | ← reads | `enemy_id` references resolve to entries; reads `enemy_class` (WILD/BOSS validation), `spawn_enabled` (exclude if false), `tier` (respected, always 1 in MVP). Stores no enemy data itself. |
| **Turn-Based Combat** | → hands off | On a resolved encounter, passes the selected `enemy_id` (and boss/wild context so TBC applies the correct flee rule — WILD fleeable, BOSS not, TBC Rule 7). TBC instantiates the enemy and owns the battle. |
| **Overworld Navigation** *(Not Started)* | ← triggered by | Calls into Encounter Zone with the player's current `terrain_type` on each step; Encounter Zone runs EZ-1 and, on success, EZ-2. Movement detection and step counting belong to Overworld Navigation. |
| **Zone & World Map** *(Not Started)* | ↔ provisional | Owns the spatial realization of terrain patches, boss placement, and — for reserved `REACH`/`DUNGEON_RUSH` gates + `DUNGEON`/`HIDDEN` placement — the actual map geometry. This GDD defines *what a gate requires*; Zone & World Map defines *where it physically is*. |
| **Exploration Progress** *(Not Started)* | ↔ reads/writes | Owns the persistent per-boss gate state (win counters, "defeated once" flag). Encounter Zone reads it to evaluate gates (Rule 8) and select first-vs-re-access (Rule 9); it does not store this itself. |
| **Drop System** | (indirect) | No direct interface — drops flow TBC → Drop System on `battle_ended`. Encounter Zone's only contribution is selecting *which* enemy is fought, which determines the loot pool in play. |

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
