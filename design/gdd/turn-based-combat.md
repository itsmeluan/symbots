# Turn-Based Combat System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 4 (Synergy Is the Endgame)

## Overview

The Turn-Based Combat System is the runtime battle orchestrator of Symbots — the system that takes over when an encounter begins and owns everything that happens until it ends. It sequences turns between the player's Symbots and enemies, executes the active Symbot's 4-move pool, and tracks all runtime combat state that the data-layer systems deliberately refuse to hold: current Structure, current Energy, and current Heat for every combatant. It is the integration point for the game's combat mathematics — at battle start it snapshots Assembly's `final_stat` block and calls the Synergy System's `evaluate_silent()` to freeze the bonus block; on every skill use it applies SYN-F4 for effective stats and calls Damage Formula DF-1 for the final integer; at turn starts it runs the Part Database's Heat decay and Energy recharge formulas. It also hosts the extension points other MVP systems plug into: region damage accrual for the Part-Break System, move selection for the Enemy AI System, and the battle-end event bundle (victory state, fired break events) that the Drop System converts into loot.

For the player, this is the game's primary screen: every battle is a tactical puzzle played through the build they assembled in the Workshop. The moves available, the damage they deal, the resources that constrain them — all of it is the build speaking. Combat exists to make the Workshop's decisions matter, and to make every fight a harvest opportunity worth planning (Pillar 2).

## Player Fantasy

The player never thinks "the combat system resolved my action." They think: *"I could finish it this turn — but if I put two more Kinetic hits into that arm first, I get the Servo Arm drop. Can I survive the extra two turns at this Heat?"*

Combat in Symbots is played directly, turn by turn, and its signature feeling is the **harvest dilemma**: the fight you can win and the fight that pays are usually not the same fight. Pillar 2 — Every Battle Has a Harvest Goal — lives or dies on this system. A pure turn-based battle asks "how do I win?"; a Symbots battle asks "how do I win *while breaking the left arm before the kill*?" — a deliberately harder, more interesting question that turns every encounter into a small plan. The reference is Monster Hunter's part-targeting translated to turn-based tempo: the enemy is not an obstacle, it is a walking shopping list, and combat is where the player executes the list.

Beneath the dilemma, two supporting feelings keep every turn textured:

1. **The build speaking** — every option on the move panel exists because of a Workshop decision. The moves, their damage type, their costs, the synergy effects that ride on them: combat is the instrument the player built, and each turn is playing it. When the Volt build's super-effective hit lands for the big number, that's the Workshop hypothesis confirmed in public (this payoff is shared with the Assembly and Damage Formula fantasies — combat is where it becomes *visible*).
2. **Resource brinkmanship** — Heat, Energy, and ammo are a light constraint layer, not a punishing economy. The intended texture is riding the edge: using the Signature skill at Heat 72 knowing it lands at 99, spending down Energy trusting next turn's recharge. Overheat is a self-inflicted, legible failure — the player always knows they gambled.

The intended emotional arc of a fight: **read** (scan the enemy — element, regions, threat) → **plan** (set the harvest target and the win route) → **execute under pressure** (each turn re-weighs the plan against dwindling Structure and rising Heat) → **collect** (the break pays out; the plan was worth it). Losses are educational, not punishing — defeat costs only the lost battle's time and pending loot (inventory and all previously-acquired parts are untouched — Rule 12), and a failed fight is a build hypothesis disproved, not progress destroyed (game concept: "Recovery from failure").

*Joint-delivery note: the harvest dilemma requires the Part-Break System (region damage mechanics — Not Started) and Combat UI (break pips, drop-hint legibility — Enemy DB constraint ED6) to land. This GDD builds the stage: turn structure that makes targeting a per-turn choice, and the event plumbing that makes breaks pay out. A silent break with no payoff readout reduces the dilemma to bookkeeping — the same class of binding as Synergy's Beat 3.*

*(Lean mode note: creative-director not consulted for this section — review manually before production.)*

## Detailed Design

### Core Rules

**Rule 1 — Battle shape (MVP).** A battle is the player's team versus **exactly one enemy** (WILD or BOSS). The player fields `TEAM_ROSTER_CAP` (3) Symbots: **1 active, 2 benched**. Only the active Symbot acts and can be targeted. Multi-enemy encounters are a Vertical Slice expansion — the battle-end event bundle is designed to carry multiple enemy IDs so the expansion is additive, not structural.

**Rule 2 — Battle start sequence.** In order:

1. For each of the 3 player Symbots: snapshot Assembly `final_stat`, `max_structure`, `max_energy_capacity`, move pool, and passive pool. Snapshots are locked for the battle (Assembly combat-lock contract).
2. For each of the 3 player Symbots: call Synergy `evaluate_silent(parts)` and store the frozen `cached_bonus_block` per Symbot. No `evaluate()` is ever called during battle (Synergy Rule 8; Workshop equip is locked out per Synergy DCO-8).
3. Instantiate the enemy from its Enemy DB entry: authored `stats`, `skills`, `core_element`, and `break_regions` (each region's independent `break_hp` pool). **Enemies receive no synergy block** — their authored stats already represent their full combat profile.
4. Initialize runtime state per combatant: `current_structure = max_structure`, `current_energy = max_energy_capacity`, `current_heat = 0` (players only — Rule 8), no statuses. Full reset every battle; nothing persists from previous fights. *(Resolves the Assembly deferred obligation on `current_structure` between battles: reset, not persistent.)*
5. Compute round 1 initiative (Rule 3). Battle begins.

**Rule 3 — Rounds and initiative.** A **round** = every living fielded combatant (active player Symbot + the enemy) acts exactly once, in **descending effective Mobility**: `effective_mobility = max(0, final_stat["mobility"] + synergy_delta.get("mobility", 0) + status_modifiers)` for player Symbots; `stats.mobility + status_modifiers` for the enemy. Initiative is recomputed at every round start (statuses and switches can change it mid-battle). **Tiebreak**: the player side acts first on equal Mobility.

**Rule 4 — Turn anatomy.** Each combatant's turn resolves in fixed phases:

1. **Turn start**: (a) Heat decay — Part DB Formula 4: `heat = max(0, heat − cooling)` (player Symbots only); (b) Energy recharge — `energy = min(max_energy_capacity, energy + 10 + final_stat["recharge"])` (players only; resolves the Assembly recharge obligation: recharge = bonus Energy at turn start); (c) status ticks — Burn damage applies now; status durations decrement at the *end* of the afflicted combatant's turn.
2. **Overheat check**: a combatant entering its turn OVERHEATED skips the action phase entirely (Part DB Formula 5 consequences), then clears to Heat 20.
3. **Action**: exactly one of — use a move (Rule 5), switch (Rule 6), flee (Rule 7).
4. **Turn end**: decrement this combatant's own status durations; expired statuses lift.

**Rule 5 — Using a move.** The active Symbot's 4-slot pool comes from Assembly (Basic Attack + WEAPON + HEAD + ARMS skills; Move 4 may be null). To use a move: (a) **cost gate** — `current_energy ≥ energy_cost`, else the move is unavailable this turn (greyed out; Basic Attack costs 0 and is always available); (b) **pay** the Energy cost; (c) **resolve** the move's behavior per the Move Contract (Rule 9) — damage moves call DF-1 (Rule 10), status moves apply their status (Rule 11), utility/repair/scan resolve per their contract entry; (d) **heat gain** — Part DB Formula 5: `heat = min(100, heat + heat_generation + (5 if part.element == THERMAL else 0))`; if heat hits 100, Overheat triggers (10% max-structure self-damage now, skip next turn, carry-in 20). **Ammo is deferred to Full Vision**: `ammo_cost` exists in the part schema but the Ammo Capacity stat is Full Vision-reserved (Part DB Rule 4), so MVP content must author `ammo_cost = 0` and TBC tracks no ammo pool — flagged as a content validation rule.

**Rule 6 — Switching.** Switching to a living benched Symbot **consumes the turn**. The incoming Symbot arrives with its own battle-start snapshot, its own frozen synergy block, and its own current resources (each of the 3 Symbots tracks Structure/Energy/Heat independently for the whole battle — benched Symbots neither decay Heat nor recharge Energy; their state is frozen while benched). **Forced replacement is free**: when the active Symbot's Structure reaches 0 (DOWNED), the player immediately chooses a living benched replacement without consuming a turn (if only one lives, it auto-fields). If none live, defeat (Rule 12).

**Rule 7 — Fleeing.** Available against WILD enemies only; always succeeds; consumes the action and ends the battle immediately with outcome `FLED` — no drops, no rewards, no penalty beyond the encounter's lost time. Never available in BOSS battles.

**Rule 8 — Resources and the enemy asymmetry (ED1 resolution).** Player Symbots run the full Heat/Energy economy (Formulas 4/5, recharge, Overheat). **Enemies track no Heat and no Energy** — their moves are always available and they never Overheat. This **ratifies Enemy DB constraint ED1 in the simplified direction**: `cooling`, `energy_capacity`, and `recharge` in enemy stat blocks are dead data in MVP; the Enemy Database GDD must be errata'd (Rule 3 note) and content validation SHOULD warn when enemy entries author non-zero values for those three keys. Statuses (Rule 11) apply to enemies normally — Burn ticks on enemy turns; Shock lowers enemy initiative.

**Rule 9 — Provisional Move Contract (MOVE-CONTRACT-1).** *The Move Database GDD does not exist. This is the schema TBC requires of it — provisional, to be ratified (not silently changed) by the Move Database GDD.* Each move entry:

| Field | Type | Notes |
|-------|------|-------|
| `id` | StringName | Referenced by parts' `active_skill_id` |
| `display_name` | String | Combat UI move panel label |
| `behavior` | Enum | `DAMAGE`, `STATUS`, `REPAIR`, `SCAN`, `UTILITY` |
| `damage_type` | Enum/null | `PHYSICAL`/`ENERGY` for DAMAGE moves — from the owning part's `damage_type` in MVP (DF hard constraint DF1: overrides belong to Move DB, not Part DB) |
| `element` | Enum/null | From the owning part's `element` in MVP; drives type effectiveness and status identity |
| `energy_cost` | int | Per Part DB Formula 5's tier table (0–40) |
| `power_source` | — | MVP moves are stat-scaled only: damage comes entirely from DF-1 on the user's effective power stat. No per-move base power in MVP (locked by DF constraint DF1). |
| `status_proc` | Dictionary/null | `{ status_id, duration }` — STATUS-behavior moves apply guaranteed on hit; DAMAGE moves may carry a rider only via passive effects, not innately (keeps MVP moves legible) |
| `targeting` | Enum | `ENEMY`, `SELF` — region sub-targeting within `ENEMY` is the Part-Break System's layer |

`heat_generation` and `ammo_cost` stay on the **part** (existing Part DB schema), not the move. The Basic Attack is a TBC-owned built-in: `behavior=DAMAGE`, `energy_cost=0`, `heat_generation=0`, `damage_type` = equipped WEAPON's `damage_type`, `element` = equipped WEAPON's `element`.

**Rule 10 — Damage resolution.** For a DAMAGE move: effective attack stat = **SYN-F4** (`max(0, final_stat[S] + frozen_synergy_delta.get(S, 0))`) on the routing stat (`physical_power` or `energy_power`); defense side likewise for the defender (enemy = authored stats, no synergy). Call DF-1: `compute_damage(A, skill_damage_type, skill_element, D, target_core_element, crit_mult=1.0)`. The player-side core element = the equipped CORE part's `element`; enemy = `core_element` field (null → ×1.0 per DF EC-04). The returned integer reduces `current_structure`, floored at 0. **Status damage (Burn) bypasses DF-1 entirely** — it is fixed-magnitude, unaffected by Armor/Resistance/type (resolves DF OQ-2: DF-1 is the only path for *move* damage; status DoT is a separate, documented path). Region damage routing awaits the Part-Break GDD — TBC exposes a per-hit hook (`hit_resolved(move, damage, target)`) that Part-Break will subscribe to.

**Rule 11 — Statuses (MVP set: exactly three).** One per element; durations in the afflicted combatant's turns; **no stacking** — reapplying refreshes duration to full; different statuses coexist freely. Magnitudes are Section D formulas (potency scales with the applier's `processing` stat — this is what makes CHIPSET matter, resolving the Assembly obligation).

| Status | Element | Effect while active | Duration |
|--------|---------|--------------------|----------|
| **Shock** | Volt | Mobility reduced (initiative drops; formula in Section D) | 2 turns |
| **Burn** | Thermal | Fixed damage at the afflicted combatant's turn start (bypasses DF-1) | 2 turns |
| **Stagger** | Kinetic | Outgoing move damage reduced (formula in Section D) | 2 turns |

**Rule 12 — Battle end.** Victory: enemy `current_structure = 0` → emit `battle_ended(VICTORY, enemy_id, fired_break_events: Set)` — break events collected as a **deduplicated set** (Enemy DB ED3 semantics) for the Drop System. Defeat: all 3 player Symbots DOWNED → `battle_ended(DEFEAT, enemy_id, {})` — **fired break events are discarded; no drops from a lost battle**. Fled: `battle_ended(FLED, enemy_id, {})` — no drops. After any outcome, all runtime combat state is discarded.

**Rule 13 — Passive effect registry (Synergy OQ-3 resolution).** TBC owns the registry mapping effect IDs (from Synergy's `effects` array and Assembly's passive pool) to combat behaviors. Contract: each entry = `{ effect_id: StringName, trigger: Enum (ON_HIT, ON_TURN_START, ON_OVERHEAT, ON_BATTLE_START…), behavior: defined per entry }`. Unknown effect IDs are **logged as a content error and skipped, never a crash** (fulfills Synergy EC-SYN-05's TBC-side obligation — the verifying AC lives in this GDD). MVP seed registry (unblocks Synergy content authoring; grows with content):

| Effect ID | Trigger | Behavior |
|-----------|---------|----------|
| `&"volt_shock_on_hit"` | ON_HIT (any DAMAGE move) | Applies Shock (1 turn — shorter than the move-applied 2) |
| `&"thermal_burn_on_weapon"` | ON_HIT (WEAPON-slot moves) | Applies Burn (2 turns) |
| `&"kinetic_stagger_on_hit"` | ON_HIT (any DAMAGE move) | Applies Stagger (1 turn) |

### States and Transitions

| State | Entered when | Exits to |
|-------|-------------|----------|
| `BATTLE_INIT` | Encounter triggers | `ROUND_START` (after Rule 2 sequence) |
| `ROUND_START` | Init done / previous round ended | `TURN_ACTIVE(combatant)` — initiative order computed here |
| `TURN_ACTIVE(c)` | Combatant c's turn begins | `ACTION_PENDING(c)` after turn-start phase; or straight to `TURN_END(c)` if Overheat-skip |
| `ACTION_PENDING(c)` | Turn-start phase done | `RESOLVING` on action chosen (player input or Enemy AI hook) |
| `RESOLVING` | Action declared | `TURN_END(c)`; may detour to `FORCED_SWITCH` (active Symbot downed) or `BATTLE_END` |
| `TURN_END(c)` | Resolution done | Next combatant's `TURN_ACTIVE`, or `ROUND_START` if round exhausted; `BATTLE_END` if end condition met |
| `FORCED_SWITCH` | Active player Symbot downed, bench alive | `RESOLVING` continuation — free replacement, turn not consumed |
| `BATTLE_END(outcome)` | Victory / Defeat / Fled | Emits `battle_ended`; state discarded |

Per-combatant flags: `NORMAL`, `OVERHEATED` (skips next action phase), `DOWNED` (structure 0; enemies: battle ends, players: bench check). Enemy AI plugs in at `ACTION_PENDING` for the enemy — TBC requests a move choice through the AI hook and treats the response like player input.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Symbot Assembly** | ← reads at battle start | `final_stat`, move pool, passive pool, maxima — snapshot, locked |
| **Synergy System** | ← calls at battle start | `evaluate_silent(parts)` ×3; reads frozen `cached_bonus_block` per Symbot; applies SYN-F4 |
| **Damage Formula** | ← calls per DAMAGE move | `compute_damage(A, damage_type, element, D, target_core_element, crit_mult=1.0)` — ratifies the DF call contract |
| **Enemy Database** | ← reads at battle start | `stats`, `skills`, `core_element`, `break_regions` — ED1 ratified as simplified (Rule 8) |
| **Move Database** *(Not Started)* | ← reads per move | MOVE-CONTRACT-1 (Rule 9) — provisional, Move DB GDD must ratify |
| **Enemy AI** *(Not Started)* | → requests | Move choice at enemy `ACTION_PENDING`; receives visible battle state |
| **Part-Break** *(Not Started)* | → provides hook | `hit_resolved(move, damage, target)` per-hit hook; region pools initialized from Enemy DB at battle start; break events collected into the Rule 12 set |
| **Drop System** *(Not Started)* | → emits | `battle_ended(outcome, enemy_id, fired_break_events)` — deduplicated set, VICTORY only pays out |
| **Combat UI** *(Not Started)* | → emits | Turn/damage/status/overheat/break signals (UI Requirements section inventory) |
| **Workshop System** *(Not Started)* | ⊘ lockout | Must disable equip during battle (Synergy DCO-8) — restated here as the battle-side contract |

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
