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

**Epsilon status (scan-verified 2026-07-10):** every `+ 0.0001` nudge in TBC-F1…F6 and in DF-1's extended input range is **DEFENSIVE, not load-bearing** — an exhaustive python3 scan against exact rational arithmetic (95,000+ inputs: all processing ∈ [0,110], energy_power ∈ [0,150], stagger_pct × damage ∈ [0,27]×[1,225], and DF-1 A ∈ [1,150] × D ∈ [0,182] × T ∈ {0.75, 1.0, 1.5}) found zero bare-floor errors and zero epsilon overcorrections. The nudges are retained as project convention. *(An earlier analytical claim that `processing × 0.3` misrounds at multiples of 10 is empirically false — IEEE 754 rounds those products to exact integers. Do not treat these epsilons as load-bearing; if a coefficient is ever retuned, re-run the scan.)*

**Status potency snapshot contract (ratified):** every status magnitude formula reads the **applier's `processing` at the moment the status lands** and stores it on the status instance. It is never re-read live. Every tick and modifier is fully predictable from the moment of application, consistent with the frozen-synergy battle model.

---

### TBC-F1 — Initiative Order

```
effective_mobility = max(0, final_stat["mobility"]
                            + synergy_delta.get("mobility", 0)
                            + shock_penalty)

shock_penalty = −TBC-F4(snapshotted_processing)   [when Shock active; else 0]
```

Combatants sorted descending by `effective_mobility` at each round start (Rule 3). Player side wins ties. Enemy path: `stats["mobility"]`, synergy_delta always 0 (Rule 8).

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base mobility | `final_stat["mobility"]` | int | 0–96 | SA-F1 output |
| Synergy mobility delta | `synergy_delta.get("mobility",0)` | int | ≥ 0 (MVP content) | From the frozen `cached_bonus_block` |
| Shock penalty | `shock_penalty` | int | −33–0 | From TBC-F4, negative modifier |
| Output | `effective_mobility` | int | 0–unbounded | Initiative rank; floored at 0 |

**Worked example (discriminating):** applier processing = 53, target base mobility = 64, no synergy: `shock_penalty = floor(53 × 0.3 + 0.0001) = floor(15.9001) = 15` (round/ceil give 16); `effective_mobility = max(0, 64 − 15) = 49` — a round()/ceil() implementation yields 48.

---

### TBC-F2 — Energy Recharge

```
new_energy = min(max_energy_capacity, current_energy + 10 + final_stat["recharge"])
```

Applied at turn start (Rule 4.1b), player Symbots only. **Pure integer arithmetic — no epsilon applies.**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current energy | `current_energy` | int | 0–max_energy_capacity | Pre-recharge |
| Base recharge | `10` | int | fixed | Universal per-turn gain |
| Recharge stat | `final_stat["recharge"]` | int | 0–30 | From ENERGY_CELL/CORE parts |
| Capacity | `max_energy_capacity` | int | 80–120 | Battle-start snapshot |
| Output | `new_energy` | int | 0–120 | Always ≤ capacity; at least 10 recovered when below cap−10 |

**Worked example (paired — cap fires / cap doesn't):** `min(95, 73 + 10 + 22) = 95` (cap fires; no-min implementation returns 105); `min(95, 40 + 10 + 22) = 72` (cap silent). Both assertions required together.

---

### TBC-F3 — Burn Damage (DoT)

```
burn_damage = max(BURN_MIN, floor(snapshotted_processing × BURN_COEFF + 0.0001))
```

`BURN_COEFF = 0.08`, `BURN_MIN = 2`. Applied at the afflicted combatant's turn start (Rule 4.1c). **Bypasses DF-1** — reduces `current_structure` directly; Armor/Resistance/type effectiveness do not apply (the documented non-DF-1 damage path per Rule 10).

**Model rationale (ratified):** processing-only scaling. Against WILD-early (structure 60) a max-investment Burn's 2-tick total (16) is 26.7% — a real tempo tool; against BOSS (594) it is 2.7% — deliberate light pressure. Burn never rivals attacking: at processing 110, one tick (8) is ~9% of the same build's Basic Attack output (86 at A=110, D=30, T=1.0). The boss-negligibility asymmetry is intentional; CHIPSET's promise is kept through wild-fight tempo, not boss DPS.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Applier processing | `snapshotted_processing` | int | 0–110 | Snapshot at application |
| Coefficient | `BURN_COEFF` | float | 0.08 | Tuning knob |
| Minimum | `BURN_MIN` | int | 2 | Baseline tick for zero-CHIPSET builds |
| Output | `burn_damage` | int | 2–8 per tick | 4–16 total over the 2-turn duration |

**Worked example (discriminating):** processing = 72: `max(2, floor(72 × 0.08 + 0.0001)) = max(2, floor(5.7601)) = 5` — round/ceil give 6.

---

### TBC-F4 — Shock Mobility Reduction

```
shock_penalty = floor(snapshotted_processing × SHOCK_COEFF + 0.0001)
```

`SHOCK_COEFF = 0.3`. Feeds TBC-F1 as a negative modifier for the status duration.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Applier processing | `snapshotted_processing` | int | 0–110 | Snapshot at application |
| Coefficient | `SHOCK_COEFF` | float | 0.3 | Tuning knob |
| Output | `shock_penalty` | int | 0–33 | Mobility reduction while Shocked |

**Calibration:** a max Shock (33) flips initiative across mobility gaps ≤ 33 — meaningful pressure in the realistic 30–96 band without guaranteeing order-flips at large gaps. Zero-processing appliers produce a 0-penalty Shock (status lands, does nothing to initiative — legal, discourages status moves on no-CHIPSET builds).

**Worked example (discriminating):** processing = 53: `floor(15.9001) = 15` — round/ceil give 16.

---

### TBC-F5 — Stagger Damage Reduction

**Application point (ratified): post-DF-1 multiply.** A pre-A reduction would be amplified super-linearly by DF-1's `A²/(A+D)` curve and its felt percentage would drift with the A/D ratio; the post-multiply keeps "Stagger X%" meaning exactly X% at any stat matchup.

Step 1 — percentage from the applier's snapshot (at application):
```
stagger_pct = floor(snapshotted_processing × STAGGER_COEFF + 0.0001)
```
`STAGGER_COEFF = 0.25` → `stagger_pct` ∈ [0, 27].

Step 2 — applied to every DAMAGE move the Staggered combatant uses while the status is active:
```
staggered_damage = max(DAMAGE_FLOOR, floor(final_damage × (1 − stagger_pct / 100.0) + 0.0001))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Applier processing | `snapshotted_processing` | int | 0–110 | Snapshot at application |
| Stagger percentage | `stagger_pct` | int | 0–27 | Integer % reduction |
| Pre-Stagger damage | `final_damage` | int | 1–225 | DF-1 output (re-derived ceiling below) |
| Damage floor | `DAMAGE_FLOOR` | int | 1 | Same constant as DF-1; Stagger cannot zero a hit |
| Output | `staggered_damage` | int | 1–225 | Post-reduction damage |

**Worked example (discriminating on both steps):** processing = 86 → `stagger_pct = floor(21.5001) = 21` (GDScript round-half-away gives 22 — wrong). Then final_damage = 50: `max(1, floor(50 × 0.79 + 0.0001)) = max(1, floor(39.5001)) = 39` — round/ceil give 40.

---

### TBC-F6 — Repair Amount

```
repair_amount = max(REPAIR_MIN, floor(user_energy_power × REPAIR_COEFF + REPAIR_BASE + 0.0001))
current_structure = min(max_structure, current_structure + repair_amount)
```

`REPAIR_COEFF = 0.17` (ratified — lowered from the proposed 0.18 for anti-stall margin), `REPAIR_BASE = 5`, `REPAIR_MIN = 5`. Scaling stat is **effective `energy_power`** (SYN-F4) — the natural fit for energy-based repair, leaving `processing` to statuses.

**Anti-stall verification:** WILD-mid reference DPS = 33/turn (DF-1 at A=53, D=30, T=1.0). repair(110) = 23; repair(150, max synergy) = **30 < 33** — margin 3. Energy costs (Light 8–14 vs. base recharge 10/turn) further break sustained-repair loops.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| User energy power | `user_energy_power` | int | 0–150 | Effective (SYN-F4) at time of use |
| Coefficient | `REPAIR_COEFF` | float | 0.17 | Tuning knob |
| Base / minimum | `REPAIR_BASE`, `REPAIR_MIN` | int | 5 / 5 | Flat floor for zero-investment builds |
| Output | `repair_amount` | int | 5–30 | Applied capped at `max_structure` |

**Worked example (discriminating):** energy_power = 45: `max(5, floor(45 × 0.17 + 5 + 0.0001)) = max(5, floor(12.6501)) = 12` — round/ceil give 13. Extremes: ep 110 → 23 (round 24); ep 150 → 30 (round 31) — both discriminating.

---

### DF-1 Range Re-Derivation (fulfills the Synergy SYN-F4 cross-system range contract)

**New constants (close Synergy OQ-2's cap from the consumer side; content validation must enforce both):**

| Constant | Value | Meaning |
|----------|-------|---------|
| `SYNERGY_POWER_BUDGET` | **40** | Max cumulative synergy `stat_delta` to `physical_power` or `energy_power` across all simultaneously active tiers |
| `SYNERGY_DEFENSE_BUDGET` | **50** | Max cumulative synergy `stat_delta` to `armor` or `resistance` across all simultaneously active tiers |

New DF-1 input ceilings: `A_max = 110 + 40 = 150`; `D_max = 132 + 50 = 182`.

**Re-derived output range: [1, 225]** (registry errata — replaces the invalidated [1, 165]):
- Absolute max (A=150, D=0, T=1.5): `floor(150 × 1.5 + 0.0001) = 225`
- Realistic max vs. authored MVP enemies (A=150, D=55, T=1.5): `floor(22500/205 × 1.5 + 0.0001) = floor(164.6342…) = 164` (round/ceil give 165 — discriminating)
- Minimum unchanged: `DAMAGE_FLOOR = 1`
- Extended range scanned exhaustively (A ∈ [1,150], D ∈ [0,182], all T): zero float traps; DF-1's epsilon remains defensive.

**TTK impact (ratified — no enemy errata):** a max-synergy build (A=150) vs. BOSS reference (D=30, structure 594) yields TTK 4 (T=1.5) / 5 (T=1.0) / 7 (T=0.75) turns, versus the base-calibration 12–18 band. Per Pillar 4, boss-melting at a perfect 7-tier build is the intended endgame reward. **Enemy DB errata obligation:** add the EDB-2 addendum — "EDB-2 calibrates for base-only player stats (A_cal ≤ 53); a max-synergy build (A ≤ 150 per SYNERGY_POWER_BUDGET) legitimately reduces BOSS TTK to 4–7 turns. If a synergy-calibrated boss tier is desired post-MVP, author it as a separate class with its own A_cal."

## Edge Cases

**EC-TBC-01 — Initiative tie at any value (including 0 vs. 0).** Both combatants at equal `effective_mobility`: player side acts first (Rule 3 tiebreak). A Shocked, zero-mobility player Symbot against a zero-mobility enemy still acts first. *Verified by AC-TBC-03.*

**EC-TBC-02 — No affordable moves.** Energy below every non-basic move's cost, or Move 4 null (Common ARMS): the Basic Attack is always available at 0 Energy / 0 Heat — no turn can soft-lock. The move panel shows unaffordable moves greyed with their costs. *Verified by AC-TBC-06.*

**EC-TBC-03 — Overheated turn still ticks statuses.** An OVERHEATED combatant's turn runs the full turn-start phase (Heat decay does NOT run — carry-in 20 is set directly per Part DB Formula 5; Burn ticks normally; recharge applies), skips only the action phase, then runs turn-end (status durations decrement). Overheat costs the action, not the turn's bookkeeping. *Verified by AC-TBC-09.*

**EC-TBC-04 — Burn downs a combatant at its own turn start.** The combatant is DOWNED before its action phase: player Symbot → free forced switch (Rule 6), then the round continues from the next initiative slot (the incoming Symbot does not act this round — it arrives mid-round); enemy → victory immediately. *Verified by AC-TBC-10.*

**EC-TBC-05 — Kill and self-down in the same resolution.** A move kills the enemy, then its heat gain triggers Overheat self-damage that downs the user (possible only when Overheat's 10%-max-structure exceeds remaining Structure). **End-condition order: victory is checked immediately when enemy Structure hits 0, before heat gain resolves** — the battle ends in VICTORY and the self-damage never applies. Resolution order within Rule 5 is authoritative: (c) resolve → end-check → (d) heat gain. *Verified by AC-TBC-11.*

**EC-TBC-06 — Switch with no living bench.** The switch action is absent from the action set when no benched Symbot lives. A direct API call to switch to a DOWNED or out-of-range Symbot is rejected with an error; no state changes. *Verified by AC-TBC-12.*

**EC-TBC-07 — Status reapplication re-snapshots.** Reapplying an active status refreshes its duration to full AND replaces the snapshotted potency with the new applier's current processing (the newest application wins entirely — no max(), no averaging). *Verified by AC-TBC-13.*

**EC-TBC-08 — Unknown effect ID in the passive registry.** An effect ID from Synergy's `effects` array or Assembly's passive pool with no registry entry: log a content error naming the ID, skip it, never crash. This is the TBC-side obligation from Synergy EC-SYN-05. *Verified by AC-TBC-14.*

**EC-TBC-09 — Zero-potency statuses are legal no-ops.** A processing-0 applier lands Shock (penalty 0) or Stagger (0%): the status applies, displays, and expires normally but modifies nothing. Not an error — the natural floor of the scaling design (Burn is the exception: `BURN_MIN = 2` always ticks). *Verified by AC-TBC-15.*

**EC-TBC-10 — Repair at or near full Structure.** `current_structure + repair_amount` caps at `max_structure` (TBC-F6); the overheal is discarded, the Energy cost and heat gain still apply. Repairing at exactly full is legal and wasteful, not rejected. *Verified by AC-TBC-16.*

**EC-TBC-11 — Move slot references a missing Move DB entry.** Assembly already exposes such slots as `null` (EC-SA-04). TBC treats null move slots as unavailable ("—") — same rendering as a Common-ARMS Move 4. No TBC-side crash path exists because the null is resolved upstream. *Verified by AC-TBC-06 (shared fixture).*

**EC-TBC-12 — Flee in a BOSS battle.** The flee action is absent from the action set (Rule 7). A direct API flee call during a BOSS battle is rejected with an error; battle state unchanged. *Verified by AC-TBC-17.*

**EC-TBC-13 — Statuses on a benched Symbot are frozen.** Statuses tick and decrement only on the afflicted combatant's own turns; benched Symbots have no turns, so their statuses (and remaining durations) freeze with the rest of their state (Rule 6) and resume on return. Switching to dodge Burn ticks is a legal tactic — it costs the turn, which is the price. *Verified by AC-TBC-18.*

**EC-TBC-14 — DOWNED clears statuses.** When a combatant is DOWNED, all its statuses are removed. A later revival mechanic (none in MVP) would start clean. *Verified by AC-TBC-18 (Scenario B).*

**EC-TBC-15 — Enemy stat keys absent.** Enemy stat lookups use `.get(key, 0)` (Enemy DB EC-ED-06 semantics): a missing `mobility` reads 0 (acts last), missing `processing` reads 0 (its statuses have zero potency, Burn still ticks at BURN_MIN). No crash. *Verified by AC-TBC-19.*

## Dependencies

### Upstream (this system reads from these)

| System | What TBC reads | Status | Hard/Soft |
|--------|---------------|--------|-----------|
| **Symbot Assembly** | `final_stat`, move pool, passive pool, `max_structure`, `max_energy_capacity`, `heat_max` — snapshot at battle start | Approved | Hard |
| **Synergy System** | `evaluate_silent(parts)` at battle start; frozen `cached_bonus_block` per Symbot; SYN-F4 applied per Rule 10 | Approved | Hard |
| **Damage Formula** | `compute_damage(A, damage_type, element, D, target_core_element, crit_mult)` per DAMAGE move — the DF call contract is hereby ratified | Approved | Hard |
| **Enemy Database** | `stats`, `skills`, `core_element`, `break_regions` at battle start | Approved | Hard |
| **Part Database** | Formulas 4/5 (Heat), Energy cost tiers, `heat_generation`/`element` per part, damage_type routing enums | Approved | Hard |
| **Move Database** | MOVE-CONTRACT-1 (Rule 9) — **provisional**; every move resolution depends on it | **Not Started** | Hard (provisional) |
| **Passive Database** | Passive IDs from Assembly's pool resolve through the Rule 13 registry | **Not Started** | Soft (null-tolerant per EC-SA-04 / EC-TBC-08) |

### Downstream (these systems read from this one)

| System | What it reads | Status | Obligation on that GDD |
|--------|---------------|--------|------------------------|
| **Part-Break System** | `hit_resolved(move, damage, target)` hook; battle-start region pools; contributes break events to the Rule 12 set | Not Started | Must define region targeting/damage accrual (Part DB DB3, Enemy DB ED2) against the hook this GDD provides; if mid-battle synergy adjustment is ever needed, coordinate with Synergy Rule 8's deferred dependency |
| **Enemy AI System** | Move-choice request at enemy `ACTION_PENDING`; visible battle state | Not Started | Must define behavior profiles (Enemy DB ED4) returning exactly one legal action; must respect that enemies have no Heat/Energy gating (Rule 8) |
| **Drop System** | `battle_ended(outcome, enemy_id, fired_break_events: Set)` | Not Started | Must consume events as a deduplicated set (Enemy DB ED3); VICTORY-only payout (Rule 12) |
| **Combat UI** | Turn/damage/status/Overheat/break signals; move panel state incl. greyed costs and null slots; type-effectiveness metadata (DF constraint DF2) | Not Started | Must resolve DF OQ-1 (how `T`/type_mult reaches the UI from a damage event) |
| **Audio System** | Combat event signals (hits, breaks, Overheat, victory/defeat) | Not Started | Subscribes to the same signal inventory as Combat UI |

### Errata obligations this GDD creates on Approved documents

| Target | Change | Source decision |
|--------|--------|-----------------|
| **Enemy Database** (Rule 3 / EDB-2) | ED1 ratified as simplified: `cooling`/`energy_capacity`/`recharge` in enemy stat blocks are dead data in MVP (validation SHOULD warn on non-zero); add the EDB-2 addendum on synergy-ceiling TTK (4–7 turn boss kills at A=150 are intended) | Rule 8; Formulas TTK ruling |
| **Synergy System** (OQ-2) | `SYNERGY_POWER_BUDGET = 40` / `SYNERGY_DEFENSE_BUDGET = 50` close the per-stat cumulative cap; content validation must enforce | Formulas re-derivation |
| **Damage Formula / registry** | DF-1 registered output range [1,165] → **[1,225]** (realistic MVP ceiling 164) | Formulas re-derivation |
| **Part Database** (content rule) | MVP moves must author `ammo_cost = 0` (ammo deferred to Full Vision); validation SHOULD warn otherwise | Rule 5 |

### Bidirectionality

Damage Formula, Enemy Database, Symbot Assembly, and Synergy System all already list Turn-Based Combat as a downstream dependent (verified in their Dependencies sections). Move Database, Passive Database, Part-Break, Enemy AI, Drop System, Combat UI, and Audio System must list TBC when authored — Move DB additionally must ratify MOVE-CONTRACT-1 explicitly rather than silently diverging.

## Tuning Knobs

| Knob | Value | Safe Range | What Changing It Does |
|------|-------|------------|----------------------|
| `BASE_ENERGY_REGEN` | 10 | 8–15 | Universal per-turn Energy. Below 8, Standard skills (15–22) take 2+ turns to afford on zero-recharge builds — combat drags; above 15, ENERGY_CELL investment stops mattering (kills the slot's meaning, an Assembly obligation). |
| `STATUS_DURATION` | 2 turns | 1–3 | All three statuses. At 1, statuses barely outlive their application turn; at 3, Burn totals (up to 24) start rivaling move damage and Stagger blankets whole fights. |
| `BURN_COEFF` | 0.08 | 0.05–0.12 | Burn tick per processing point. At 0.12 max tick = 13 (26/duration — too close to WILD move damage); at 0.05 max tick = 5 (CHIPSET investment imperceptible). **Re-run the epsilon scan if changed.** |
| `BURN_MIN` | 2 | 1–3 | Zero-CHIPSET baseline tick. At 0, Burn from no-investment builds does nothing (dead rider); above 3, no-investment Burn rivals invested Burn. |
| `SHOCK_COEFF` | 0.3 | 0.2–0.4 | Mobility penalty per processing point (max 33 at 0.3). Calibrated against the realistic 30–96 mobility band: at 0.2 (max 22), Shock rarely flips initiative; at 0.4 (max 44), it flips almost any gap. **Re-run the epsilon scan if changed.** |
| `STAGGER_COEFF` | 0.25 | 0.15–0.35 | Damage reduction % per processing point (max 27% at 0.25). Bounds the design target 15–35%. **Re-run the epsilon scan if changed.** |
| `REPAIR_COEFF` | 0.17 | 0.10–0.17 | Repair per energy_power point. **Hard ceiling 0.17**: at 0.18+, max-synergy repair (32+) approaches WILD-mid DPS (33) and stall loops open. Coupled to `BASE_ENERGY_REGEN` — raising both compounds stall risk. **Re-run the epsilon scan if changed.** |
| `REPAIR_BASE` / `REPAIR_MIN` | 5 / 5 | 3–8 | Flat floor. Above 8, zero-investment repair spam becomes efficient on high-structure builds. |
| `SYNERGY_POWER_BUDGET` | 40 | 30–50 | Endgame power ceiling (A_max = 110 + budget). **Changing it invalidates the DF-1 registered range and the TTK impact table — re-run the Formulas re-derivation and update the registry.** At 30, boss TTK floor ~5–8 turns; at 50, ~3–4. |
| `SYNERGY_DEFENSE_BUDGET` | 50 | 40–60 | Defense ceiling (D_max = 132 + budget). Lower risk than the power budget (diminishing returns in DF-1's denominator), but the registered D range moves with it. |

**Owned elsewhere — referenced, not duplicated**: `DAMAGE_FLOOR` (Damage Formula); Heat cap 100, Overheat carry-in 20, Overheat damage 10%, Energy cost tiers (Part Database Formulas 4/5); `TEAM_ROSTER_CAP`, `ACTIVE_MOVE_SLOTS` (Assembly); type effectiveness multipliers (Damage Formula/Part DB).

**Knob interaction warnings**: (1) `REPAIR_COEFF` + `BASE_ENERGY_REGEN` + Energy cost tiers jointly control stall viability — never tune one without checking the anti-stall inequality `repair(150) < WILD-mid DPS`. (2) `SYNERGY_POWER_BUDGET` is coupled to the DF-1 registry range, the TTK ruling, and Synergy OQ-2's content validation — it is a cross-document constant; treat changes as design decisions, not tuning passes. (3) Any coefficient change to BURN/SHOCK/STAGGER/REPAIR requires re-running the python3 epsilon scan (the current all-defensive verdict is input-range-specific).

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
