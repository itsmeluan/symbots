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

**Rule 1 — The World Graph.** The world is one `WorldMap` resource: a directed graph of `ZoneNode` entries plus a runtime `current_zone_id`. MVP authors exactly one node. The `WorldMap` is the runtime authority for zone traversal state and zone-progression state; it is read-only content at authoring time except for the runtime fields defined in Rule 7.

| Field | Type | Notes |
|-------|------|-------|
| `zones` | Array[ZoneNode] | All zone nodes in the world (MVP: 1) |
| `start_zone_id` | StringName | The zone the player begins in; always ACCESSIBLE from a new game |
| `current_zone_id` | StringName (runtime) | Which zone the player currently occupies |

**Rule 2 — ZoneNode.** A node wraps one Encounter Zone definition and carries the world-graph metadata around it. It does **not** duplicate spawn data — it references the Encounter Zone by `zone_id`.

| Field | Type | Notes |
|-------|------|-------|
| `zone_id` | StringName | References the Encounter Zone entry (Encounter Zone Rule 1). One-to-one. |
| `display_name` | String | Player-visible zone name for the map |
| `map_position` | Vector2 | Node position on the world-map screen (World Map UI reads this) |
| `edges` | Array[ZoneEdge] | Outbound traversal edges — see Rule 3 |
| `difficulty_band` | Enum | `EARLY` / `MID` / `LATE` / `ENDGAME` — an *advisory* label surfaced by the UI so difficulty reads as the soft gate. Not a hard lock. |
| `runtime` | ZoneRuntimeState | The mutable progression/traversal state — see Rule 7 |

**Rule 3 — ZoneEdge (directed connection).** Each edge is a one-way connection from its owning node to a target zone, traversable only when its `unlock_condition` is satisfied. Bidirectional travel is authored as two edges.

| Field | Type | Notes |
|-------|------|-------|
| `to_zone_id` | StringName | The destination node |
| `unlock_condition` | Enum | `OPEN` / `BOSS_DEFEATED` / `STORY_FLAG` / `KEY_ITEM` — see Rule 4 |
| `condition_params` | Dictionary | Shape depends on condition (`OPEN` → `{}`; `BOSS_DEFEATED` → `{ boss_id: StringName }`) |

**Rule 4 — Unlock-condition taxonomy (extensible; MVP fills two).**

| `unlock_condition` | Meaning | Traversable when | MVP |
|--------------------|---------|------------------|-----|
| `OPEN` | Free travel; difficulty self-gates | Always | **Authorable** |
| `BOSS_DEFEATED` | Story/progression hard-lock | `condition_params.boss_id`'s `defeated_once == true` (Rule 7) | **Authorable** |
| `STORY_FLAG` | Narrative gate | A named story flag is set | **Reserved** (no story content in MVP) |
| `KEY_ITEM` | Item gate | Player holds a named key item (from #23a Key Item System) | **Reserved** |

Default is `OPEN`. The intended world shape is *mostly open* — the player travels freely and self-limits by enemy difficulty (`difficulty_band` is the read-out) — with a small number of `BOSS_DEFEATED`/`STORY_FLAG` hard-locks for deliberate story gates.

**Rule 5 — Zone state (LOCKED / ACCESSIBLE / CLEARED).** Each node's `runtime.state` is one of three, **derived** (never hand-authored) from reachability and boss-defeat progress:

- **`CLEARED`** — every entry in the zone's Encounter Zone `boss_encounters` has `defeated_once == true`. A cleared zone remains enterable (re-farmable); CLEARED is a display/progress overlay, not a lockout.
- **`ACCESSIBLE`** — not cleared, and the zone is *reachable*: it is the `start_zone_id`, **or** some traversable edge (Rule 3/4) leads into it from a zone that is itself ACCESSIBLE or CLEARED.
- **`LOCKED`** — not reachable: no traversable inbound edge exists yet.

Because most edges are `OPEN`, **many zones can be ACCESSIBLE at once** — the open-world feel. State is recomputed whenever a boss-defeat or story flag changes (see States and Transitions).

**Rule 6 — Traversal.** Overworld Navigation asks this system whether a move from `current_zone_id` to a target zone is allowed. The move is permitted iff a traversable edge connects them and the target is `ACCESSIBLE` or `CLEARED`. On a permitted move, this system updates `current_zone_id` and emits `zone_entered(zone_id)`. This system validates and records the transition; Overworld Navigation owns the actual player movement and the tile-level detail.

**Rule 7 — Zone-progression runtime state (this system is the authority).** Each `ZoneRuntimeState` holds the mutable progression data that drives gates and display:

| Field | Type | Notes |
|-------|------|-------|
| `state` | Enum | Derived per Rule 5 (LOCKED/ACCESSIBLE/CLEARED) |
| `win_count` | int | Cumulative WILD wins in this zone. **Incremented per Encounter Zone Rule 8a semantics** (all-time, wins-only, no reset; fled/lost never count) on a `battle_ended(result = WIN)` for a WILD encounter in this zone. |
| `boss_progress` | Array[BossProgress] | One per zone boss: `{ boss_id, defeated_once: bool, wins_at_last_defeat: int }` (the delta snapshot Encounter Zone Rule 9 requires for re-gates) |

This system **owns these fields at runtime and implements Encounter Zone's rule semantics** — it does not re-define them. The Exploration Progress System serializes this state to disk and restores it on load (see Interactions); it is the persistence layer, not the runtime owner.

**Rule 8 — Boss-gate delegation (no circular dependency).** This system never re-implements gate logic. When Overworld Navigation initiates a boss approach, this system calls the Encounter Zone's gate-check, **passing in** the boss's `gate_params`/`regate_params` (owned by Encounter Zone content) together with this zone's `win_count` and `boss_progress` (owned here). Encounter Zone returns open/closed; it never reaches up into this system for state. On a boss victory, this system sets that boss's `defeated_once = true`, snapshots `wins_at_last_defeat = win_count`, and recomputes zone states (Rule 5).

**Rule 9 — MVP content.** MVP populates one `ZoneNode` (the starter zone), `start_zone_id` = that zone, no edges. It begins `ACCESSIBLE` and becomes `CLEARED` when both of its bosses are defeated (Encounter Zone: Boss 1 @ 6 wins, Boss 2 @ 10 wins on the shared `win_count`). The graph/edge machinery is schema-complete but dormant until Vertical Slice adds a second zone.

### States and Transitions

Zone state is a pure function of progression data, recomputed on every relevant change:

| From | To | Trigger |
|------|----|---------|
| `LOCKED` | `ACCESSIBLE` | An inbound edge becomes traversable (its `BOSS_DEFEATED`/`STORY_FLAG`/`KEY_ITEM` condition is now met, or a newly-accessible neighbor exposes an `OPEN` edge) |
| `ACCESSIBLE` | `CLEARED` | The zone's final un-defeated boss's `defeated_once` flips to `true` (all bosses now defeated) |
| `CLEARED` | `CLEARED` | Terminal — re-entering a cleared zone to farm does not change state |

Recomputation runs a reachability pass from `start_zone_id` across traversable edges, then overlays CLEARED for zones with all bosses defeated. Triggers: `battle_ended` (win-count/boss-defeat change), story-flag change, key-item acquisition, and load (after Exploration Progress restores state). The pass is deterministic and side-effect-free apart from emitting `zone_states_changed` when any state differs from the prior pass.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Encounter Zone** (upstream) | This system reads `zone_id`, `boss_encounters` (boss_id, gate_params, regate_params, repeat_policy) and **calls** its gate-check, passing `win_count` + `boss_progress` as inputs | Encounter Zone owns spawn tables + gate *semantics*; this system owns the *runtime counter/flags* and never lets Encounter Zone read up |
| **Overworld Navigation** (downstream) | Calls `can_travel(from, to)` and `enter_zone(to)`; reports `battle_ended(result, encounter_type)` for win-count increment | Owns tile movement + encounter triggering; this system owns zone-level transition validation and progression state |
| **Exploration Progress** (downstream) | Serializes/restores every `ZoneRuntimeState` (`win_count`, `boss_progress`, derived `state` re-derived on load) | Persistence layer only — not the runtime owner |
| **World Map UI** (downstream) | Reads `zones`, `current_zone_id`, each node's `state`, `display_name`, `map_position`, `difficulty_band`, and edge lock status for display | Read-only; renders locked/accessible/cleared and the difficulty read-out |
| **Turn-Based Combat** (indirect) | Emits the `battle_ended` signal (result WIN/LOSS/FLEE) that Overworld Navigation relays for win-count increment | This system never reads combat state directly |

## Formulas

This system owns no balance math. Its logic is deterministic graph/boolean derivation — no scaling curves, no floats, no `floor`/`ceil`, no epsilon exposure. It specifies two predicates/algorithms.

### ZWM-F1 — Edge traversability predicate

`traversable(edge)` = boolean, keyed on `unlock_condition`:

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `edge.unlock_condition` | Enum | OPEN / BOSS_DEFEATED / STORY_FLAG / KEY_ITEM | The gate on this edge |
| `edge.condition_params` | Dictionary | — | Condition-specific args |
| `boss_progress` | Array[BossProgress] | — | This system's runtime boss-defeat records (Rule 7) |

```
traversable(edge) =
  match edge.unlock_condition:
    OPEN           -> true
    BOSS_DEFEATED  -> boss_progress.find(condition_params.boss_id).defeated_once == true
    STORY_FLAG     -> story_flags.has(condition_params.flag)      # reserved; MVP: false if authored
    KEY_ITEM       -> inventory.has_key_item(condition_params.item_id)  # reserved
```

**Output:** boolean. Pure discrete lookup — no arithmetic. Unknown/reserved conditions with no backing system resolve to `false` (fail-safe LOCKED, never fail-open — see EC-ZWM-04).

**Example:** Edge `scrapfield → foundry`, `unlock_condition = BOSS_DEFEATED`, `boss_id = &"forge_titan"`. Before Forge Titan is beaten: `defeated_once == false` → `traversable == false`. After: `true`. An `OPEN` edge is `true` at all times regardless of any state.

### ZWM-F2 — Zone-state derivation (reachability pass)

Recomputes every node's `runtime.state` (LOCKED / ACCESSIBLE / CLEARED) as a pure function of the graph and progression records.

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `zones` | Array[ZoneNode] | size ≥ 1 | All nodes |
| `start_zone_id` | StringName | — | Always-reachable root |
| `traversable(edge)` | boolean | — | From ZWM-F1 |
| `all_bosses_defeated(zone)` | boolean | — | `zone.boss_encounters` all `defeated_once == true`; a zone with **zero** bosses is treated as `false` (never auto-CLEARED) |

```
step1 (cleared overlay): for each zone z: cleared[z] = all_bosses_defeated(z)
step2 (reachability BFS): reachable = { start_zone_id }
        frontier = { start_zone_id }
        while frontier not empty:
          n = frontier.pop()
          for edge in n.edges where traversable(edge) and edge.to_zone_id not in reachable:
            reachable.add(edge.to_zone_id); frontier.add(edge.to_zone_id)
step3 (assign): for each zone z:
          if cleared[z]:        z.runtime.state = CLEARED
          elif z in reachable:  z.runtime.state = ACCESSIBLE
          else:                 z.runtime.state = LOCKED
```

**Output:** each node assigned exactly one state. Deterministic; terminates in O(V+E) (each node enqueued at most once). No RNG, no floats, no `floor`/`ceil` → **no epsilon, no python3 scan required** (stated explicitly so reviewers don't flag the absence). A CLEARED zone is still reachable and enterable — CLEARED overrides ACCESSIBLE for *display/progress* only, not for traversal permission (Rule 6 permits entry to ACCESSIBLE **or** CLEARED).

**Example (MVP, 1 node):** `zones = [scrapfield]`, `start_zone_id = &"scrapfield"`, no edges. Before both bosses: `cleared = false`, `scrapfield ∈ reachable` → **ACCESSIBLE**. After Boss 1 + Boss 2 defeated: `all_bosses_defeated = true` → **CLEARED**.

**Example (2-node, discriminating):** `scrapfield` (start) with one `BOSS_DEFEATED(forge_titan)` edge to `foundry`; `foundry` has no inbound OPEN edge. Before Forge Titan: `reachable = {scrapfield}` → `foundry` is **LOCKED** (an implementation that ignored `traversable` and treated all edges as open would wrongly mark it ACCESSIBLE). After Forge Titan: edge traversable → `reachable = {scrapfield, foundry}` → `foundry` **ACCESSIBLE**.

The `win_count` increment is **not** a formula here — it is `win_count += 1` on a qualifying `battle_ended(WIN, WILD)`, implementing Encounter Zone Rule 8a's semantics (owned there, not redefined).

## Edge Cases

**EC-ZWM-01 — Zone with zero bosses.** *If* a `ZoneNode`'s Encounter Zone has an empty `boss_encounters` list: `all_bosses_defeated` returns `false`, so the zone **never auto-flips to CLEARED** — it stays ACCESSIBLE indefinitely (valid for a hub/pure-farming zone). It is never treated as "conquered." *Verified by AC-ZWM-07.*

**EC-ZWM-02 — Edge target zone does not exist.** *If* an `edge.to_zone_id` references no node in `zones` (content error): the edge is **skipped** during the ZWM-F2 reachability pass (contributes no reachability), a content error is logged, and no crash occurs. Other edges evaluate normally. *Verified by AC-ZWM-08.*

**EC-ZWM-03 — BOSS_DEFEATED names a non-existent boss.** *If* a `BOSS_DEFEATED` edge's `boss_id` matches no boss in any zone's `boss_encounters` (broken reference): `traversable` returns **`false` (fail-safe LOCKED, never fail-open)** and logs a content error. Mirrors Encounter Zone's EC-EZ-12 fail-safe stance — a broken gate locks, it never opens. *Verified by AC-ZWM-09.*

**EC-ZWM-04 — Reserved unlock_condition with no backing system.** *If* an edge uses `STORY_FLAG` or `KEY_ITEM` in MVP (systems not yet implemented): `traversable` returns **`false`** (fail-safe LOCKED) and logs a warning that a reserved condition was authored. The edge is effectively closed until its backing system exists. *Verified by AC-ZWM-10.*

**EC-ZWM-05 — Player is standing in a zone that recomputes to LOCKED.** *If* a state recompute (ZWM-F2) would mark `current_zone_id`'s zone LOCKED (e.g., an authoring change, or a hypothetical condition that revokes reachability): **current occupancy is never invalidated** — the player cannot be evicted from where they stand. LOCKED governs *future entry*, not present presence. `current_zone_id` is left unchanged; the recompute assigns the display state but Overworld Navigation does not force-exit the player. This prevents a traversal softlock. *Verified by AC-ZWM-11.*

**EC-ZWM-06 — Graph cycle.** *If* edges form a cycle (A→B→A, or longer): the ZWM-F2 BFS `reachable`/visited set guarantees each node is enqueued at most once — **no infinite loop**, deterministic termination. *Verified by AC-ZWM-12.*

**EC-ZWM-07 — Boss victory does not increment win_count.** *If* a `battle_ended(WIN)` resolves from a **BOSS** encounter (not WILD): `win_count` is **not** incremented (Encounter Zone Rule 8a counts WILD wins only). The boss victory instead sets that boss's `defeated_once = true` and snapshots `wins_at_last_defeat`. A fled or lost battle changes nothing. *Verified by AC-ZWM-03, AC-ZWM-05.*

**EC-ZWM-08 — start_zone_id references a non-existent zone.** *If* `start_zone_id` matches no node (unrecoverable content error): this is a **hard failure at load** — unlike the other fail-safe cases, the game cannot place the player anywhere, so it raises a loud content error rather than silently degrading. (Distinct from EC-ZWM-02/03/04, which are recoverable.) *Verified by AC-ZWM-13.*

**EC-ZWM-09 — Duplicate zone_id in `zones`.** *If* two nodes share a `zone_id`: a content error is logged and the **first** occurrence is authoritative; subsequent duplicates are ignored (not merged). *Verified by AC-ZWM-14.*

**EC-ZWM-10 — Load with drifted progression data.** *If* a save's `boss_progress` contains an entry for a boss no longer in content (removed boss): the orphaned entry is **ignored** on load; if a boss exists in content but has no saved entry, it defaults to `defeated_once = false, wins_at_last_defeat = 0`. State is always **re-derived** (ZWM-F2) on load, never trusted from the serialized `state` field. *Verified by AC-ZWM-15.*

**EC-ZWM-11 — Travel to a LOCKED or non-adjacent zone.** *If* `can_travel(current, target)` is asked for a target with no traversable edge from `current`, or whose state is LOCKED: it returns **`false`**; `current_zone_id` is unchanged and no `zone_entered` signal fires. *Verified by AC-ZWM-02.*

## Dependencies

### Upstream Dependencies (what this system requires)

| System | What this system reads/calls | Hard/Soft | Status |
|--------|------------------------------|-----------|--------|
| **Encounter Zone** | `zone_id` (node↔zone binding), `boss_encounters` (boss_id, gate_type, gate_params, regate_params, repeat_policy), and the **gate-check** call (passed `win_count` + `boss_progress`) | **Hard** — no world graph without zone definitions and the gate model | Approved ✓ |
| **Turn-Based Combat** | The `battle_ended(result, encounter_type)` signal that drives `win_count` increment and boss-defeat flips (relayed via Overworld Navigation) | **Soft** — indirect; consumed as an event, never read as state | Approved ✓ |

### Downstream Dependents (what depends on this system)

| System | What it reads/calls | Status |
|--------|--------------------|--------|
| **Overworld Navigation** | `can_travel(from, to)`, `enter_zone(to)`; relays `battle_ended` for win-count increment | Not Started |
| **Exploration Progress** | Serializes/restores every `ZoneRuntimeState` (`win_count`, `boss_progress`); state is re-derived on load, never trusted from disk | Not Started |
| **World Map UI** | `zones`, `current_zone_id`, per-node `state` / `display_name` / `map_position` / `difficulty_band`, edge lock status | Not Started |
| **World Loot System** | Reads the zone graph to place static loot per zone (Part DB + Zone & World Map, per systems index #13) | Not Started |

### Bidirectionality Note

- **Encounter Zone erratum (light):** This system depends on Encounter Zone, so Encounter Zone's GDD should list **Zone & World Map** as a downstream dependent (it currently predates this system). This is a one-line addition to the Encounter Zone Dependencies section — recorded here as a pending consistency touch, not a semantic change to Encounter Zone. Its Rule 8a/8/9 gate contract is consumed exactly as written; nothing in Encounter Zone changes behaviorally.
- When **Overworld Navigation**, **Exploration Progress**, **World Map UI**, and **World Loot** are authored, each must list Zone & World Map in its upstream dependencies.
- **No dependency on Symbot Core Progression** (#10b): leveling concerns Symbots, not the world graph. The two systems do not interact.

## Tuning Knobs

This system is structural, not numeric — its "knobs" are mostly **content-authoring levers** (graph shape), and the one progression number that affects it (`required_wins`) is **owned by Encounter Zone**, not redefined here.

| Knob | Type | Owner | Effect / Safe guidance |
|------|------|-------|------------------------|
| `start_zone_id` | Content | This system | Which zone a new game begins in. Must reference an existing node (else EC-ZWM-08 hard-fails). Exactly one. |
| Per-edge `unlock_condition` + `condition_params` | Content | This system | The graph's lock topology. Keep the world *mostly `OPEN`* (the design intent); reserve `BOSS_DEFEATED`/`STORY_FLAG` for deliberate story gates. Over-locking collapses the open-world feel into a corridor. |
| Per-zone `difficulty_band` | Content (advisory) | This system | `EARLY/MID/LATE/ENDGAME` label the UI surfaces as the *soft* gate. Purely informational — must never be wired to block travel (that would turn the soft gate hard and contradict Rule 4). Author it to match the zone's actual enemy power so the read-out is honest. |
| Graph connectivity (edges per node) | Content | This system | How branchy the world is. A tree feels guided; a dense mesh feels open. MVP (1 node) is trivial; Vertical Slice+ tunes this for pacing. |

**Cross-referenced knob (owned elsewhere, affects this system):**

| Knob | Owner | Relevance here |
|------|-------|----------------|
| `gate_params.required_wins` (Boss 1 = 6, Boss 2 = 10) | **Encounter Zone** (Tuning Knobs) | Sets how many WILD wins gate each boss. This system holds the `win_count` those thresholds are checked against but **does not define the thresholds** — tune them in Encounter Zone. Changing them alters how long a zone stays ACCESSIBLE before CLEARED. |

**Warning — difficulty_band honesty.** Because zones are mostly `OPEN`, the *only* thing steering a player away from an over-tough zone is the `difficulty_band` read-out. If a band label understates a zone's real difficulty, a low-power player wanders into a wall with no hard gate to stop them. Author bands conservatively and revisit them whenever a zone's enemy roster changes.

## Visual/Audio Requirements

This system renders nothing directly — it owns no sprites. Its visual/audio footprint is the **signals it emits** for other systems to present:

- `zone_entered(zone_id)` → World Map UI updates the "you are here" marker; Audio System plays a zone-enter stinger (character per `difficulty_band`).
- `zone_states_changed` → World Map UI re-renders node states (LOCKED/ACCESSIBLE/CLEARED) and edge locks. Two beats matter most (Player Fantasy):
  - **Zone unlock** (a node flips LOCKED → ACCESSIBLE): a distinct **unlock fanfare** — the "a new path just opened" moment. This is the single most important audio cue this system enables.
  - **Zone cleared** (ACCESSIBLE → CLEARED): a quieter conquest flourish.

All actual art (node icons, locked/accessible/cleared visual states, difficulty-band color language, map layout) and mix parameters are specified in the **World Map UI GDD** and **Audio System GDD**. This section defines only the signal contract those systems subscribe to.

> **Asset Spec** — no direct assets to spec here; per-asset visual work belongs to `/asset-spec system:world-map-ui` once the World Map UI GDD and Art Bible are approved.

## UI Requirements

This system exposes **read APIs + signals**; it contributes **no screens of its own**. The World Map screen that visualizes this data is **World Map UI (#20)**. Interface surface for that consumer:
- Reads: `zones`, `current_zone_id`, per-node `state` / `display_name` / `map_position` / `difficulty_band`, per-edge lock status (`traversable`).
- Signals: `zone_entered`, `zone_states_changed`.

> **📌 UX Flag — Zone & World Map**: The World Map screen (locked/accessible/cleared rendering, difficulty read-out, travel interaction, the unlock moment) must get a UX spec in Pre-Production. Run `/ux-design` for `design/ux/world-map.md` before writing World Map UI stories. Touch-first: node tap-targets ≥ 44×44pt, no hover-only affordances (per technical-preferences).

## Acceptance Criteria

**AC-ZWM-01 — Valid travel succeeds.** **GIVEN** `current_zone_id = A` and an `OPEN` edge A→B where B is ACCESSIBLE, **WHEN** `enter_zone(B)` is called, **THEN** it succeeds, `current_zone_id == B`, and exactly one `zone_entered(B)` signal fires. **Test:** Unit.

**AC-ZWM-02 — Invalid travel rejected.** **GIVEN** `current_zone_id = A`, and target C that is either LOCKED or has no edge from A, **WHEN** `can_travel(A, C)` is evaluated, **THEN** it returns `false`, `current_zone_id` stays `A`, and no `zone_entered` fires. *(EC-ZWM-11)* **Test:** Unit.

**AC-ZWM-03 — WILD win increments the counter; flee/loss do not.** **GIVEN** zone A `win_count = 5`, **WHEN** `battle_ended(WIN, WILD)` fires for A, **THEN** `win_count == 6`; **AND** a subsequent `battle_ended(FLEE, WILD)` and `battle_ended(LOSS, WILD)` each leave it at `6`. *(Rule 7; EC-ZWM-07)* **Test:** Unit.

**AC-ZWM-04 — MVP single-node lifecycle.** **GIVEN** the MVP world (1 node `scrapfield`, 2 bosses, no edges), **WHEN** state is derived before any boss is defeated, **THEN** `scrapfield.state == ACCESSIBLE`; **WHEN** both bosses' `defeated_once == true`, **THEN** `scrapfield.state == CLEARED`; with exactly one boss defeated it is still `ACCESSIBLE` (not CLEARED). *(ZWM-F2; Rule 9)* **Test:** Unit.

**AC-ZWM-05 — Boss victory flips defeat flag, snapshots delta, and does NOT increment win_count.** **GIVEN** zone A `win_count = 8`, boss `forge_titan.defeated_once = false`, **WHEN** `battle_ended(WIN, BOSS=forge_titan)` fires, **THEN** `forge_titan.defeated_once == true`, `forge_titan.wins_at_last_defeat == 8`, **AND** `win_count` remains `8` (a boss win is not a WILD win). *(Rule 8; EC-ZWM-07)* **Test:** Unit.

**AC-ZWM-06 — Reachability discriminates a gated edge.** **GIVEN** 2 nodes: `scrapfield` (start) with a single `BOSS_DEFEATED(forge_titan)` edge to `foundry`, and `foundry` has no other inbound edge, **WHEN** state is derived with `forge_titan.defeated_once = false`, **THEN** `foundry.state == LOCKED`; **WHEN** derived with `forge_titan.defeated_once = true`, **THEN** `foundry.state == ACCESSIBLE`. An implementation that ignores `traversable()` (treats all edges as open) fails the first assertion. *(ZWM-F1, ZWM-F2)* **Test:** Unit.

**AC-ZWM-07 — Zero-boss zone never auto-clears.** **GIVEN** a reachable node whose Encounter Zone has `boss_encounters == []`, **WHEN** state is derived, **THEN** its state is `ACCESSIBLE`, never `CLEARED`, regardless of `win_count`. *(EC-ZWM-01)* **Test:** Unit.

**AC-ZWM-08 — Dangling edge target is skipped, not fatal.** **GIVEN** a node with an edge whose `to_zone_id` matches no node, **WHEN** state is derived, **THEN** a content error is logged, no exception is raised, and reachability of all real nodes is unchanged from the same graph with the dangling edge removed. *(EC-ZWM-02)* **Test:** Unit.

**AC-ZWM-09 — Broken BOSS_DEFEATED reference fails safe (LOCKED).** **GIVEN** a `BOSS_DEFEATED` edge whose `boss_id` exists in no zone's `boss_encounters`, **WHEN** `traversable(edge)` is evaluated, **THEN** it returns `false` and logs a content error (never `true`). *(EC-ZWM-03)* **Test:** Unit.

**AC-ZWM-10 — Reserved condition is closed in MVP.** **GIVEN** an edge with `unlock_condition = STORY_FLAG` (or `KEY_ITEM`) authored in MVP, **WHEN** `traversable(edge)` is evaluated, **THEN** it returns `false` and logs a reserved-condition warning. *(EC-ZWM-04)* **Test:** Unit.

**AC-ZWM-11 — Current zone is never revoked from under the player.** **GIVEN** `current_zone_id = A` and A is ACCESSIBLE, **WHEN** a state recompute would classify A as LOCKED (e.g., its only inbound edge became non-traversable), **THEN** `current_zone_id` remains `A`, no forced exit occurs, and A's derived `state` may read LOCKED for display without affecting the player's presence. *(EC-ZWM-05)* **Test:** Unit.

**AC-ZWM-12 — Cyclic graph terminates deterministically.** **GIVEN** nodes with a cycle A→B→A (all `OPEN`), **WHEN** state is derived, **THEN** the pass terminates, and A and B are both `ACCESSIBLE` (assuming A is start); running the derivation twice yields identical states. *(EC-ZWM-06)* **Test:** Unit.

**AC-ZWM-13 — Missing start zone is a loud failure.** **GIVEN** a `WorldMap` whose `start_zone_id` matches no node, **WHEN** the world loads, **THEN** a fatal content error is raised (not silently degraded to any default). This is distinct from the recoverable EC-ZWM-02/03/04 cases. *(EC-ZWM-08)* **Test:** Unit.

**AC-ZWM-14 — Duplicate zone_id: first wins.** **GIVEN** two nodes sharing `zone_id = X`, **WHEN** the world loads, **THEN** a content error is logged, the first node is authoritative, and the second is ignored (no merge). *(EC-ZWM-09)* **Test:** Unit.

**AC-ZWM-15 — Save drift is tolerated; state is always re-derived.** **GIVEN** a save whose `boss_progress` has (a) an entry for a boss absent from content and (b) no entry for a boss present in content, **WHEN** the game loads, **THEN** the orphan entry is ignored, the missing boss defaults to `defeated_once = false, wins_at_last_defeat = 0`, and every zone's `state` is recomputed via ZWM-F2 rather than read from the serialized `state` field. *(EC-ZWM-10)* **Test:** Integration.

**Coverage check:** every core rule (1–9) and both formulas (ZWM-F1/F2) have ≥1 AC; every edge case EC-ZWM-01…11 cites a listed AC. Positive paths (AC-01/03/04) and failure/boundary paths (AC-02/06/08/09/10/11/13) are both represented.

## Open Questions

- **OQ-ZWM-1 — Per-zone vs shared win_count across multiple zones.** MVP is one zone → one `win_count`. Encounter Zone Rule 8a says the counter is "zone-wide"; this system models it per-zone (each node its own counter). Confirm that generalization holds when the 2nd zone is authored (Vertical Slice). *Owner: this system + Encounter Zone, at 2nd-zone authoring.*
- **OQ-ZWM-2 — Soft warning on entering a far-above-power zone.** Because travel is mostly `OPEN`, a low-power player can wander into an ENDGAME zone. Should the World Map UI show an "are you sure?" confirmation keyed on `difficulty_band` vs the player's build/core levels? *Owner: World Map UI / playtest.*
- **OQ-ZWM-3 — Fast-travel between ACCESSIBLE/CLEARED zones.** Jump directly vs. walk the overworld. Moot in MVP (1 zone). *Owner: Overworld Navigation, Vertical Slice.*
- **OQ-ZWM-4 — Post-clear escalation.** Should a CLEARED zone's spawn table or difficulty shift (harder post-boss variants)? Interacts with Encounter Zone. *Owner: Encounter Zone, deferred to Vertical Slice+.*
