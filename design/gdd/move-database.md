# Move Database

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 1 (Engineer, Don't Collect), Pillar 3 (Build Depth Over Content Breadth), Pillar 4 (Synergy Is the Endgame)

## Overview

The Move Database is the authoritative catalog of every move a Symbot can perform in combat. Each part that grants an action — a WEAPON's primary skill, a HEAD's scan or utility, an ARMS active, plus the universal Basic Attack — references a move entry by `active_skill_id`; the Move Database is where that ID resolves into a concrete, executable definition: the move's **behavior class** (`DAMAGE`, `STATUS`, `REPAIR`, `SCAN`, `UTILITY`), its `damage_type` and `element`, its Energy cost, the status it applies (if any), its targeting, and its **power coefficient** — the per-move multiplier that makes a Signature strike hit harder than a Light jab on the same power stat. It is read-only from a gameplay perspective and is the direct sibling of the Part Database: where the Part Database defines what a part *is*, the Move Database defines what a part *does* when its skill fires. It holds no runtime state — turn resolution, resource spending, and the damage math all live in Turn-Based Combat; the Move Database supplies only the static contract each move obeys. Formally, this document **ratifies MOVE-CONTRACT-1** — the provisional move schema Turn-Based Combat authored in its Rule 9 — accepting it in full with one negotiated addition: the per-move power coefficient (§Formulas), which Turn-Based Combat's original "stat-scaled only" constraint deliberately left open for this GDD to decide.

## Player Fantasy

The Move Database has no fantasy the player ever names — they never think "I am reading a move definition." Its fantasy is *borrowed and enabling*, the same relationship the Part Database has to collecting: it is the guarantee that **the move panel is the build speaking**.

When a player equips a Boltwell arc-weapon and its `active_skill_id` resolves into a cyan Volt `DAMAGE` move with a Shock rider, that panel button is the Workshop hypothesis made playable. Every option the player taps in combat — its element, its cost, whether it staggers or repairs or scans, how hard it lands — exists because a part they chose put it there. The Move Database is where *"I built this"* becomes *"I can press this."* A Signature move that hits like a truck and floods the Heat gauge, a cheap Light jab that holds tempo, a repair that buys a turn — these read as **distinct tools with distinct weights** only because this catalog gives each move its own power, cost, and rider. Flatten those into interchangeable numbers and the move panel is a list; give each move a real identity and the panel becomes an instrument.

The player *feels* this fantasy in Turn-Based Combat, which owns the moment-to-moment "build speaking" experience (TBC Player Fantasy, supporting feeling 1). The Move Database's role is upstream and quiet: it is the promise that when the build says something, combat has a concrete, differentiated move to say it with.

## Detailed Design

### Core Rules

**Rule 1 — The Move Schema (MOVE-CONTRACT-1, ratified).** Every move is one entry with these fields. This accepts Turn-Based Combat's Rule 9 schema in full and adds `power_tier` (the negotiated power coefficient):

| Field | Type | Notes |
|-------|------|-------|
| `id` | StringName | Referenced by a part's `active_skill_id` |
| `display_name` | String | Combat UI move-panel label |
| `behavior` | Enum | `DAMAGE`, `STATUS`, `REPAIR`, `SCAN`, `UTILITY` (Rule 2) |
| `power_tier` | Enum | `LIGHT`, `STANDARD`, `HEAVY`, `SIGNATURE` — maps to a damage multiplier and expected cost/heat bands (Rule 3). `null` for non-`DAMAGE` behaviors |
| `damage_type` | Enum/null | `PHYSICAL`/`ENERGY` — from the owning part's `damage_type` in MVP (DF constraint DF1). `null` for non-`DAMAGE` |
| `element` | Enum/null | From the owning part's `element` in MVP; drives type effectiveness and status identity |
| `energy_cost` | int | 0–40, must fall in the `power_tier`'s band (Rule 3) |
| `status_proc` | Dictionary/null | `{ status_id, duration }` — `STATUS` moves apply it guaranteed on hit; `DAMAGE` moves carry riders only via passives, never innately (Rule 5) |
| `targeting` | Enum | `ENEMY`, `SELF` — region sub-targeting within `ENEMY` is the Part-Break System's layer |
| `scan_payload` | Enum/null | `BREAK_REGIONS` for `SCAN` moves (Rule 6); `null` otherwise |
| `vent_amount` | int/null | Heat removed for `UTILITY` Vent (Rule 8); `null` otherwise |

`heat_generation` and `ammo_cost` remain on the **part** (Part DB schema), never the move — ratified unchanged from MOVE-CONTRACT-1.

**Rule 2 — Behavior classes.** A move's `behavior` selects its resolution path; the runtime resolution itself is owned by Turn-Based Combat (this GDD defines the contract each obeys):

- **`DAMAGE`** — deals damage via DF-1 scaled by `power_tier` (Rule 3 / §Formulas MOVE-F1). The only behavior that emits `hit_resolved` (TBC AC-TBC-34).
- **`STATUS`** — applies `status_proc` guaranteed on hit; deals no damage (Rule 5).
- **`REPAIR`** — restores the user's Structure via TBC-F6; `energy_cost > BASE_ENERGY_REGEN` (Rule 7).
- **`SCAN`** — reveals enemy break-region/drop info; no damage, no status (Rule 6).
- **`UTILITY`** — MVP: exactly one move, Vent (Rule 8).

**Rule 3 — Power tiers (the coherence spine).** `power_tier` unifies a `DAMAGE` move's damage multiplier with its expected Energy cost and its part's Heat generation, so "heavier" always means "hits harder, costs more, runs hotter" — one coherent axis, not three loose numbers:

| `power_tier` | Damage `power_mult` | Expected `energy_cost` | Expected part `heat_generation` |
|--------------|--------------------|-----------------------|-------------------------------|
| `LIGHT` | 0.80 | 5–8 | 0–5 |
| `STANDARD` | 1.00 | 12–18 | 8–15 |
| `HEAVY` | 1.20 | 22–30 | 18–28 |
| `SIGNATURE` | 1.40 | 32–40 | 30–40 |
| *Basic Attack* | 0.70 | 0 | 0 |

The Energy/Heat bands are the **same tiers Part DB Formula 5/6 already define** — this table binds them to a damage multiplier. Content validation enforces that a `DAMAGE` move's `energy_cost` falls in its tier's band, and warns when the owning part's `heat_generation` falls outside it (cross-schema, so a warning not a hard fail). `power_mult` is applied post-DF-1 (§Formulas MOVE-F1) — DF-1 itself is untouched.

**Rule 4 — The Basic Attack (built-in template).** The Move Database registers one canonical Basic Attack template: `behavior = DAMAGE`, `power_tier` = Basic Attack (mult 0.70), `energy_cost = 0`, `status_proc = null`, `targeting = ENEMY`. Turn-Based Combat instantiates it at battle start, filling `damage_type` and `element` from the equipped WEAPON (TBC Rule 9). It is always available (cost 0) and is the weakest damage option by design — the free fallback, never the optimal hit.

**Rule 5 — Status moves.** A `STATUS` move applies its `status_proc` `{ status_id, duration }` guaranteed on hit. Status **identity** is fixed by element — Volt→Shock, Thermal→Burn, Kinetic→Stagger (TBC Rule 11) — so `status_id` must match the move's `element`. Status **potency** is never a move field: it scales with the applier's `processing` at application time (TBC-F3/F4/F5). `duration` defaults to 2 (TBC Rule 11); the field exists so specific moves or `SKILL_ENHANCE` unlocks can extend it. `DAMAGE` moves never carry an innate status rider — riders come only from passive effects through TBC's Rule 13 registry, keeping base moves legible.

**Rule 6 — SCAN (delivers Enemy DB ED6).** A `SCAN` move (`scan_payload = BREAK_REGIONS`) consumes the turn, pays its Energy cost and the part's Heat, deals no damage and applies no status, and reveals the enemy's `break_regions` — each region's label and its drop hint (which part it can yield). The revealed info **persists for the rest of the battle**. This is the delivery mechanism for Enemy DB constraint ED6's "drop-hint mechanism" and directly serves Pillar 2: the player scans to learn *what to break*, then plans the harvest. The information payload's data shape is owned jointly with Enemy DB (ED6) and its on-screen display is the Combat UI GDD's; this GDD defines that SCAN *produces* the reveal event.

**Rule 7 — REPAIR.** A `REPAIR` move restores the user's Structure by TBC-F6 (`repair_amount` scales with effective `energy_power`). It **must** author `energy_cost > BASE_ENERGY_REGEN` (≥ 11 at the current 10) — the anti-stall Energy-brake contract ratified in TBC Rule 9 / AC-TBC-38. `targeting = SELF`. Overheal above `max_structure` is discarded; the Energy and Heat costs still apply (TBC EC-TBC-10).

**Rule 8 — UTILITY: Vent (the one MVP utility).** A `UTILITY` Vent move consumes the turn, pays its Energy cost, and reduces the user's `current_heat` by `vent_amount` (floored at 0). It is the *active* complement to the passive Cooling stat — it lets a Thermal or high-power build shed Heat on demand and push Signature moves harder without Overheating. `targeting = SELF`. Vent is the complete MVP `UTILITY` taxonomy; the enum retains headroom for Vertical Slice+ (buffs, energy transfer) but no other `UTILITY` move ships in MVP.

**Rule 9 — Upgrade effects (runtime semantics).** Part DB Rule 10 stores an `upgrade_effects` array on the part; this GDD defines what its two `effect_type` values do:
- **`SKILL_UNLOCK`** — at the specified upgrade tier, adds a new move (by `skill_id`) to that part's contributed move slot. In MVP this is used only by specific boss-grade/prototype parts at tiers +4/+5. (Never on a Core part — Part DB Core exception.)
- **`SKILL_ENHANCE`** — at the specified tier, modifies an existing move's parameters: reduce `energy_cost`, bump `power_tier` one step, extend a `status_proc.duration`, or add a passive rider ID. Each enhancement names the exact parameter and delta.

### States and Transitions

The Move Database is a **static data schema** — move definitions have no runtime state and no state machine, exactly like the Part Database. All mutable combat state (whether a move is affordable this turn, cooldown-equivalents, resource spending) lives in Turn-Based Combat, not here.

Lifecycle note: move definitions are added at content-authoring time. A retired move is never deleted (existing parts may reference it); it is left in the catalog and simply removed from any new part authoring. There is no `deprecated` flag on moves in MVP — the Part that references a move governs whether it is reachable.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** | ← referenced by | Parts' `active_skill_id` → move `id`; `damage_type`/`element` sourced from the owning part; `heat_generation`/`ammo_cost` stay on the part; `upgrade_effects` array stored on the part, semantics defined here (Rule 9) |
| **Turn-Based Combat** | → consumed by | MOVE-CONTRACT-1 (Rule 1); TBC resolves every move, owns runtime state, applies `power_mult` post-DF-1, emits `hit_resolved` for `DAMAGE`. **Errata obligation on TBC** (§Formulas): TBC-F5 `final_damage` input range and `hit_resolved` damage range widen to accommodate `power_mult` |
| **Damage Formula** | ← calls | `DAMAGE` moves resolve through DF-1; `power_mult` multiplies DF-1's *output* (DF-1 unchanged) |
| **Enemy Database** | ↔ joint | Enemy `skills` reference Move DB entries; SCAN's `BREAK_REGIONS` payload reads Enemy DB `break_regions`/drop hints (ED6) |
| **Part-Break System** | → provides keyword | Moves whose resolution can break a region flow through TBC's `hit_resolved`; drop-condition keywords (e.g. `arm_broken`) are Part-Break/Drop vocabulary, matched by `id` |
| **Passive Database** | ↔ sibling | `DAMAGE`-move status riders are passives (TBC Rule 13 registry), not move fields; the two schemas are authored together |
| **Enemy AI** | ← reads | Enemy move entries (behavior, cost, tier) inform AI move selection; enemies ignore Energy/Heat gating (TBC Rule 8) |
| **Combat UI** | → displays | `display_name`, tier, cost, greyed/affordable state, and the SCAN reveal readout |

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
