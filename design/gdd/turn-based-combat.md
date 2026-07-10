# Turn-Based Combat System

> **Status**: Designed — awaiting /design-review
> **Author**: Luan + Claude Code Game Studios agents (systems-designer: Formulas; qa-lead: ACs; art-director: Visual/Audio)
> **Review Notes**: Authored in lean mode — CD-GDD-ALIGN gate skipped per review-mode; specialists consulted for Formulas, ACs, and Visual/Audio. All floor/ceil formulas python3 epsilon-scanned 2026-07-10 (all defensive, zero load-bearing).
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

> **Asset Spec flag**: No asset specifications exist yet. The Art Bible (`/art-bible` not yet run) is the prerequisite for per-asset dimensions, formats, palette locks, and animation frame budgets. Everything below is **intent and constraint**, not specification. After the Art Bible is approved, run `/asset-spec system:turn-based-combat` to produce the full asset list.

> **Art Bible Ratification Required**: All element colors, visual timing budgets, and accessibility decisions below must be ratified by the Art Bible before production. The Assembly GDD's rarity glow table (cyan / amber / white per element) is the current canonical reference and the source used here.

### V1 — Visual Identity Principles Active in Combat

**V1-1 — Element-from-flash-alone test (binding).** A player must be able to identify the element of any attack from the screen flash alone, without reading text. This is a hard readability gate, not an aspiration. Every hit VFX must pass this test at the Art Bible review.

**V1-2 — Element color contract (binding until Art Bible changes it).** Sourced from the Assembly GDD rarity glow table: Volt = cyan; Thermal = amber; Kinetic = white / silver-white. All hit VFX, status indicators, damage number tints, gauge highlights, and audio cue emotional registers use these as their primary identity signal. The Art Bible may extend but must not contradict these assignments.

**V1-3 — Accessibility: never color alone.** Element and effectiveness information must always carry a second non-color channel (shape, icon, animation profile, or text label). Color is the fast read; the second channel ensures players with color vision deficiencies reach the same information. Project accessibility standard, not a preference.

**V1-4 — Vibrant and readable, not grimdark.** Combat is exciting, not oppressive. Even the worst combat states (Overheat, Defeat) read as dramatic, not punishing. Saturation stays high; shadow work stays purposeful.

### V2 — Animation and Timing Constraints (Mobile Pacing Budget)

| Constraint | Budget | Notes |
|---|---|---|
| Full turn resolution (move → damage → status apply) | **≤ 2.0 s** | Sum of all VFX, number pop, and feedback animations on a single turn |
| Individual VFX read window | **≤ 300 ms** | Element and behavior legible within 300 ms of onset — then it may persist |
| Damage number display | **≤ 1.5 s** on screen | Float up and fade; must not block the next animation beat |
| Status application feedback | **≤ 0.5 s** | The apply flash; the persistent indicator may remain |
| Status tick (Burn DoT) | **≤ 0.3 s** | Brief pulse on the afflicted combatant at their turn start |
| Forced switch (DOWNED) | **≤ 0.8 s** | Emergency replacement must feel fast — it is free and reactive |
| Victory / Defeat screen | Skippable after **1.0 s** | A beat to read the outcome, then a tap skips to results |
| Overheat state entry | **0.6–1.0 s** | Intentionally slower — a dramatic beat, not a status tick |

**Skip / fast-forward requirement**: all non-interactive animations must support player interruption via tap after their minimum read window. Applies to move resolution, status ticks, initiative reorder displays, victory/defeat fanfares. Interaction design deferred to Combat UI GDD; the animation system must not structurally block it.

**Initiative order display constraint**: when Shock causes a mid-round initiative reorder, the order change must be shown as a brief update to the turn-order indicator (< 0.5 s) before the affected combatant acts. The change must be perceivable — a readability requirement for a real mechanic, not decoration.

### V3 — VFX Requirements per Combat Event

**V3-1 — Battle Start.** Both combatants presented; the player's 8-layer modular composite renders identically to its Workshop appearance (no visual discontinuity). Enemy visual identity (element glow, silhouette archetype) readable before the first turn. Entry animation settles fully before `ROUND_START`; rarity glow renders from the first settle frame.

**V3-2 — Turn Indicator / Initiative Order.** The active combatant is visually unambiguous during `TURN_ACTIVE`. A persistent turn-order display is required. Shock-caused order changes animate in the display (element-colored flash on the affected entry) before the displaced combatant acts — a player riding Heat 90 must be able to see that a Volt rider may push the enemy ahead of them.

**V3-3 — Move Use: Hit VFX.** Volt: cyan arc flash + screen-space electric crackle (< 300 ms settle). Thermal: amber burst with radiant bloom, orange-to-amber fade trail. Kinetic: white/silver impact burst with a sharp directional streak, no lingering glow — reads as mechanical impact, not energy. Shape profiles (arc / bloom / streak) distinguish elements without color, per V1-3. PHYSICAL hits carry heavier weight (mass on chassis, sparks); ENERGY hits are lighter and more diffuse. Type is the secondary read under element — the flash-alone test applies to element.

**V3-4 — Damage Numbers.** Pop over the struck combatant on `hit_resolved`; value is DF-1's integer (or TBC-F3 for Burn ticks, visually distinct per V3-6). Effectiveness tinting (fulfills DF constraint DF2 — never color alone):

| Effectiveness | Color signal | Non-color signal |
|---|---|---|
| Super-effective (×1.5) | Bright yellow-white | +30% font size AND an upward exclamation accent |
| Neutral (×1.0) | White | Standard size, no accent |
| Resisted (×0.75) | Muted grey-blue | −20% font size AND a downward suppression accent |

**V3-5 — Status Application.** Shock: cyan arc wraps the chassis ~0.4 s; lightning-bolt icon in the status bar. Burn: amber flame-burst ~0.4 s; flame icon. Stagger: white impact ripple ~0.4 s; concentric-ring icon ("shaken" without color). Application flashes must (a) land as a secondary beat ~0.2 s after the hit VFX (cause and effect, not one blur), (b) be legible at minimum iOS rendered sizes.

**V3-6 — Status Active Indication and Ticks.** Persistent icons for the full duration — ambient readability, not animated noise. Burn tick: brief amber pulse (~0.25 s) + amber-tinted damage number (distinguishes Burn ticks from move damage). Expiry: icon desaturates and fades ~0.3 s at turn end. Zero-potency statuses (EC-TBC-09) render and expire normally; no zero-damage number for Stagger; Burn at BURN_MIN reads as 2.

**V3-7 — Heat Gauge.** Three zones: **0–69 (safe)** — neutral cool fill (not an element color); **70–89 (riding the edge)** — amber-orange with a subtle pulse that reads as exciting, not alarming (this range is intentional play); **90–100 (brinkmanship)** — deeper orange-red, faster pulse; must read "on the edge, which is the point," never "about to lose."

**V3-8 — Overheat.** A blown gasket, not a punishment screen: screen-wide steam/pressure-release flash (white→grey ~0.5 s); brief overloaded-chassis overlay (screen shake, if used, reserved for Overheat and DOWNED only, < 0.3 s); gauge slams to 0 then visibly rises to the 20 carry-in (two-step teaching visual); self-damage number in the heat register (not an element color); the skipped turn shown by graying/bypassing in the turn-order display. Total 0.6–1.0 s. Brinkmanship or miscalculation — both readings correct, neither shameful.

**V3-9 — Energy.** Bar decreases immediately on move use, before the move VFX (cost telegraphed, then reward). Recharge: brief fill animation ~0.2 s at turn start — bar climbs, no pop event. Bar color distinct from Heat and elements (Art Bible defines). Greyed-out unaffordable moves read as "unavailable this turn," not "broken" (Combat UI owns the panel).

**V3-10 — Switch: Tactical vs. Emergency.** Voluntary: outgoing steps back (0.3–0.4 s), incoming steps forward (0.3–0.4 s) — deliberate, composed. Forced/DOWNED: collapse/shutdown animation first (sparks, darkening, ~0.4 s), then an urgent, reactive entry; total ≤ 0.8 s. Status icons on the downed Symbot disappear as part of the downed animation (EC-TBC-14), never linger.

**V3-11 — Region Damage / Break Events.** Hosted by TBC; owned by the Part-Break System GDD (Not Started). Break pips are Combat UI's (Enemy DB ED6). TBC's requirement is limited to firing `hit_resolved` correctly per hit; break VFX direction goes to the Part-Break GDD when authored.

**V3-12 — Victory / Defeat / Flee.** Victory: clear positive payoff; the winning build gets a visible beat; the loot moment is calmer than the fight. Defeat: somber, not shameful — educational register with an immediate re-challenge path. Flee: neutral, clean, no fanfare. Victory/defeat skippable after 1.0 s.

### V4 — Audio Requirements per Combat Event

The Audio System GDD owns assets and mix parameters; TBC emits signals, the Audio System subscribes. This table defines the **character** each sound must have:

| Event | Signal / Trigger | Character |
|---|---|---|
| Battle start | Transition settle | Rising mechanical hum — tension building, not menacing |
| Turn begins (player) | `TURN_ACTIVE(player)` | Subtle ready chime — "your move" |
| Turn begins (enemy) | `TURN_ACTIVE(enemy)` | Lower mechanical tick — rhythm maintained, slight threat |
| Volt hit | `hit_resolved`, element=Volt | Sharp electric crack — bright and snappy, < 300 ms |
| Thermal hit | `hit_resolved`, element=Thermal | Deep whomp with heat trail — warmth and weight |
| Kinetic hit | `hit_resolved`, element=Kinetic | Heavy metallic impact — mass, white-noise burst, no sustain |
| Super-effective hit | T=×1.5 | Layer above the base hit: a distinct resonance "ring" — "that landed right" |
| Resisted hit | T=×0.75 | A dulled version of the base hit — the same blow, dampened |
| Shock apply | Status application (Volt) | Brief electric zap, distinct from the hit sound |
| Burn apply | Status application (Thermal) | Soft ignition — small flame catching |
| Stagger apply | Status application (Kinetic) | Heavy thud + rattle — chassis disrupted |
| Burn tick | TBC-F3 at turn start | Low crackling pulse — ongoing, not alarming, < 0.3 s |
| Shock tick (initiative reduce) | Initiative recalc shows penalty | Brief descending electronic tone — "something shifted" |
| Status expiry | Duration reaches 0 | Quiet dissipating sound — threat passed, not celebratory |
| Heat increase | Post-move heat gain | Rising pressure sound scaling with gauge: 0–69 near-silent; 70–89 low hiss; 90+ tense steam pressure |
| Overheat | Heat hits 100 | Sharp pressure burst / steam release — mechanical, dramatic, not punishing. The loudest combat event outside victory |
| Energy spend | Move use | Clean energy-discharge tick — light, non-intrusive |
| Energy recharge | Turn start | Soft rising fill tone — background texture |
| Voluntary switch | Player switches | Clean mechanical swap — confident, composed |
| DOWNED / forced switch | `current_structure = 0` | Two sounds with a beat between: shutdown wind-down, then urgent incoming entry |
| Repair | TBC-F6 fires | Warm resonant repair tone — restorative; distinct from energy recharge |
| Region damage tick / part break | `hit_resolved` hook | Deferred to Part-Break System GDD audio spec |
| Victory | `battle_ended(VICTORY,…)` | Satisfying mechanical resolution — energetic but earned, not bombastic |
| Defeat | `battle_ended(DEFEAT,…)` | Low quiet wind-down — loss acknowledged, not rubbed in |
| Flee | `battle_ended(FLED,…)` | Quick retreating sound — neutral, no failure register |

**Audio identity note**: element hit sounds must be as mutually distinct as the V3-3 visual profiles — a player should identify Volt vs. Thermal vs. Kinetic from audio alone (complementary channel; the audio equivalent of the flash-alone test).

### V5 — Deferral Boundaries

| Item | Owner | Status |
|---|---|---|
| Per-asset dimensions, formats, palette locks, frame budgets | Art Bible | Not Started |
| Combat screen layout, gauge placement, break pip UI | Combat UI GDD | Not Started |
| Part-break VFX and break event visual treatment | Part-Break System GDD | Not Started |
| Region sub-targeting visual feedback | Part-Break System GDD | Not Started |
| Audio asset specs, mix parameters, music direction | Audio System GDD | Not Started |
| Skip / fast-forward interaction model | Combat UI GDD | Not Started |
| Enemy-side visual design (attack animations, silhouettes) | Art Bible + Enemy DB visual extension | Not Started |
| DOWNED animation frame detail | Art Bible | Not Started |
| Status icon art (Shock / Burn / Stagger) | Art Bible | Not Started |
| Color-blind mode palette alternatives | Art Bible accessibility chapter | Not Started |

*Joint delivery note: this section's readability requirements (V1-1, V3-4 effectiveness tinting, V3-5 status icons) depend on the Combat UI GDD for placement and the Art Bible for palette ratification — neither exists yet. Authored against the Visual Identity Anchor; revisit for consistency at the first Art Bible review.*

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:turn-based-combat` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

Requirements this system places on the Combat UI GDD (Not Started). These are obligations, not designs — layout and interaction belong to that GDD.

1. **Move panel**: 4 fixed slots (Basic Attack + Moves 2–4). Unaffordable moves greyed with their Energy cost visible; null slots render "—" (identical for Common-ARMS and missing-Move-DB cases); Basic Attack is never greyed. Touch targets ≥ 44×44pt.
2. **Turn-order display**: persistent, shows upcoming order; Shock-caused reorders animate perceivably before the displaced combatant acts (V2/V3-2 constraint).
3. **Damage feedback**: damage numbers with effectiveness tinting + non-color channels per V3-4. **Requires resolving DF OQ-1**: how the type multiplier `T` reaches the UI from a damage resolution event (struct return vs. parallel lookup) — Combat UI GDD decides jointly with the TBC call contract.
4. **Status readout**: per-combatant status bar (icons per V3-5), tick and expiry moments visible; zero-potency statuses still shown.
5. **Resource gauges**: Heat as the three-zone design (V3-7 — 70–89 must read as exciting, not alarming); Energy bar with pre-VFX cost deduction (V3-9).
6. **Bench visibility**: benched Symbots' current Structure and active statuses must be readable before choosing a switch — the switch decision is a resource comparison, not a guess.
7. **Break pips**: enemy break-region display (Enemy DB ED6 — labels from `break_regions[].display_name`); region damage state visualization is Part-Break GDD territory; pips are Combat UI's.
8. **Battle log**: per the game concept's feedback-clarity requirement ("battle log describes why moves hit hard or weak"), a scrollable log entry per resolution: move used, damage, effectiveness, statuses applied/ticked/expired, Overheat events.
9. **Skip/fast-forward**: tap-to-skip for all non-interactive animations after their minimum read window (V2); interaction model is Combat UI's.
10. **Outcome screens**: victory (with drop payout readout), defeat (immediate re-challenge path), flee — registers per V3-12.

> **📌 UX Flag — Turn-Based Combat**: this system has extensive screen-level UI requirements. In Phase 4 (Pre-Production), run `/ux-design` for the combat screen before writing implementation epics. Stories referencing combat UI should cite `design/ux/combat.md`, not this GDD directly.

## Acceptance Criteria

ACs marked **BLOCKING** are Logic-type: they gate story completion and require automated unit tests in `tests/unit/tbc/`. ACs marked **DEFERRED** require integration with one or more Not-Started systems; they must be unblocked before the integrating system's story is marked Done, not TBC's own stories. ACs marked **ADVISORY** gate content authoring pipelines rather than runtime correctness.

**Test-type note:** statuses, initiative, recharge, and repair are fully unit-testable with stub combatants (a `Dictionary` carrying `final_stat`, `current_structure`, `current_energy`, `current_heat`, `max_structure`, `max_energy_capacity`, `cached_bonus_block`). No live scene or Enemy DB lookup is required for any BLOCKING AC below.

**Consumer-ownership note (SYN-F4):** AC-SYN-06 and AC-SYN-10 in the Synergy GDD define the SYN-F4 contract and must be implemented in `tests/unit/tbc/` (as well as `tests/unit/workshop_ui/`). They are not re-stated here; the ACs below that apply SYN-F4 (AC-TBC-07, AC-TBC-22) test TBC's pipeline around it, not the formula in isolation.

**DF-1 registered range:** per the Formulas re-derivation, DF-1's output range is **[1, 225]**. All TBC ACs using DF-1 operate within this range.

---

### Battle Start Sequence (Rule 2)

**AC-TBC-01** (BLOCKING): Battle-start snapshot locks Assembly state and calls `evaluate_silent()` exactly once per Symbot, with no `synergy_changed` emitted.
GIVEN a battle begins with 3 player Symbots and exactly one enemy, WHEN `BATTLE_INIT` → `ROUND_START` executes, THEN: (a) `evaluate_silent(parts)` is called exactly 3 times and `synergy_changed` is NOT emitted during the sequence; (b) each Symbot's `cached_bonus_block` holds the correct frozen bonus for its own part set; (c) the enemy receives no `evaluate_silent` call and has no synergy block; (d) `current_structure == max_structure`, `current_energy == max_energy_capacity`, `current_heat == 0` for all three player Symbots; (e) enemy `current_structure` == authored `stats["structure"]`.
FAIL: any `synergy_changed` fires during battle start; `evaluate_silent` call count ≠ 3; any Symbot's heat ≠ 0; enemy has a synergy block. **Test type**: Unit.

**AC-TBC-02** (BLOCKING): Enemy dead-stat fields are read but never applied.
GIVEN an enemy with authored `stats = { structure: 120, mobility: 40, physical_power: 30, armor: 20, cooling: 15, energy_capacity: 80, recharge: 5 }`, WHEN instantiated, THEN the enemy tracks no `current_heat` and no `current_energy` (sentinel null/absent, not a live 0), and all its moves are always available regardless of any cost.
FAIL: enemy has a live heat counter that can Overheat; enemy moves gated by an energy check. **Test type**: Unit.

### Initiative and Round Structure (Rule 3 / TBC-F1)

**AC-TBC-03** (BLOCKING): Initiative tie — including 0 vs. 0 — breaks in the player's favor. *(Verifies EC-TBC-01)*
GIVEN active Symbot and enemy both at `effective_mobility = 0` (Symbot mobility 0, no synergy, Shock active with processing-0 penalty 0; enemy mobility 0), WHEN initiative is computed at `ROUND_START`, THEN the player Symbot acts first. *Second fixture:* both at 35 → player first.
FAIL: enemy acts first on a tie; RNG tiebreak used. **Test type**: Unit.

**AC-TBC-04** (BLOCKING): Initiative recomputes at every `ROUND_START`.
GIVEN Round 1: Symbot mobility 30, enemy mobility 50 (enemy first). Player applies Shock (processing 53 → penalty 15) to the enemy. THEN Round 2: enemy effective = 35, still first at 35 > 30 — proving recomputation ran without inferring it from an order change. *Discriminating flip case:* Symbot mobility 40, enemy 50, Shock 15 → Round 2 enemy 35 < 40 → order flips.
FAIL: initiative computed once at battle start; Round 2 order ignores the Shock penalty; flip case does not flip. **Test type**: Unit.

**AC-TBC-05** (BLOCKING): TBC-F1/F4 Shock penalty floor discrimination.
GIVEN `snapshotted_processing = 53`, WHEN `shock_penalty = floor(53 × 0.3 + 0.0001)`, THEN penalty = **15**; on a mobility-64 target, `effective_mobility = 49`.
FAIL: penalty = 16 (round()/ceil() — 15.9 rounds up); effective = 48. *Edge:* processing 0 → penalty 0, no crash. **Test type**: Unit.

### Turn Phase Order (Rule 4)

**AC-TBC-06** (BLOCKING): No-affordable-moves and null move slot — Basic Attack always available; no soft-lock. *(Verifies EC-TBC-02 + EC-TBC-11)*
*Fixture A:* GIVEN `current_energy = 5` and Moves 1–3 cost 15/22/30, THEN Basic Attack available (cost 0); Moves 1–3 greyed with costs shown; no soft-lock.
*Fixture B:* GIVEN Move 4 = null (EC-SA-04 upstream), THEN slot renders "—", no crash, other moves unaffected.
FAIL: Basic Attack greyed; turn skipped without input; null slot crashes or renders as available. Both fixtures required. **Test type**: Unit.

**AC-TBC-07** (BLOCKING): Turn-start phase order: Heat decay → Energy recharge → Burn tick, players only.
GIVEN heat 30 / cooling 10; energy 40 / cap 95 / recharge 22; Burn active (processing 72); structure 50, WHEN the turn starts (not Overheated), THEN in order: heat = max(0, 30−10) = **20**; energy = min(95, 40+10+22) = **72**; burn = max(2, floor(5.7601)) = **5** → structure **45**.
FAIL: burn = 6 (round/ceil); energy = 105 (no cap); Burn ticks before decay. *Enemy exclusion:* no decay/recharge on enemy turns. **Test type**: Unit.

**AC-TBC-08** (BLOCKING): TBC-F2 recharge — cap-fires and cap-silent pair.
*Case A:* `min(95, 73+10+22) = 95`. FAIL: 105 (min omitted). *Case B:* `min(95, 40+10+22) = 72`. Both required together — a no-cap implementation passes B accidentally. **Test type**: Unit.

**AC-TBC-09** (BLOCKING): Overheated turn skips the action phase but runs all bookkeeping. *(Verifies EC-TBC-03)*
GIVEN a Symbot entering its turn OVERHEATED (heat 100), Burn active (processing 72, 2 turns left), energy 50 / cap 95 / recharge 22, structure 40, WHEN the turn resolves, THEN: (1) heat decay does NOT run — heat set directly to carry-in **20**; (2) energy = **82**; (3) burn ticks 5 → structure **35**; (4) no action phase; (5) turn-end decrements Burn 2 → **1**; (6) OVERHEATED clears, next turn acts normally.
FAIL: `max(0, 100−cooling)` applied instead of flat 20; action executes; Burn doesn't tick; duration doesn't decrement. **Test type**: Unit.

### Down-Ordering and Victory Check (EC-TBC-04 / EC-TBC-05)

**AC-TBC-10** (BLOCKING): Burn kill at turn start — correct branching. *(Verifies EC-TBC-04)*
*Scenario A (player):* GIVEN active Symbot structure 3, Burn tick 5, one living benched Symbot, WHEN its turn starts, THEN it is DOWNED before acting; forced switch is free; the incoming Symbot does NOT act this round; the round continues from the next initiative slot.
*Scenario B (enemy):* GIVEN enemy structure 3, Burn tick 5, WHEN its turn starts, THEN `battle_ended(VICTORY, …)` emits immediately — no enemy action phase.
FAIL: downed combatant acts; forced switch consumes a turn; incoming Symbot acts same round; victory not emitted. **Test type**: Unit.

**AC-TBC-11** (BLOCKING): Victory is checked before heat gain — kill+self-down resolves as VICTORY. *(Verifies EC-TBC-05)*
GIVEN Symbot heat 90, move `heat_generation = 20` (non-THERMAL), max_structure 50 (Overheat self-damage 5), current_structure 4, WHEN the move drops the enemy to 0, THEN `battle_ended(VICTORY, …)` emits at that moment; heat gain (Rule 5 step d) never executes; no Overheat; the Symbot is NOT downed.
FAIL: heat resolves first → self-down → DEFEAT reported. The Rule 5 order (c) resolve → end-check → (d) heat is the system under test. **Test type**: Unit.

### Switch and Flee (Rules 6–7)

**AC-TBC-12** (BLOCKING): Switch with no living bench rejected; forced switch free and stateful. *(Verifies EC-TBC-06)*
*Scenario A:* GIVEN both benched Symbots DOWNED, THEN switch is absent from the action set; a direct `switch_to(index)` call is rejected with a logged error, no state change.
*Scenario B:* GIVEN active Symbot downed, one benched alive, THEN the replacement fields immediately, no turn consumed, arriving with its own independently-tracked resources (not reset).
FAIL: switch offered with dead bench; forced switch consumes a turn; incoming resources reset; incoming acts in the same round. **Test type**: Unit.

**AC-TBC-17** (BLOCKING): Flee rejected in BOSS; succeeds in WILD. *(Verifies EC-TBC-12)*
*Scenario A (BOSS):* flee absent from action set; direct `flee()` rejected with logged error; no outcome emitted; state unchanged.
*Scenario B (WILD):* flee emits `battle_ended(FLED, enemy_id, {})`, consumes the action, discards all state, no drops.
FAIL: FLED emitted in a BOSS fight; flee fails vs. WILD; drops awarded on FLED. **Test type**: Unit.

**AC-TBC-18** (BLOCKING): Bench freezes statuses; DOWNED clears them. *(Verifies EC-TBC-13 + EC-TBC-14)*
*Scenario A (bench freeze):* GIVEN Symbot A active with Burn (2 turns left), player switches to B, WHEN B takes turns, THEN A's Burn stays at 2 turns (no ticks, no decrement while benched); on switching back, it ticks and decrements normally from A's next turn start.
*Scenario B (DOWNED clears):* GIVEN A has Burn (1) and Shock (2) active and is downed by an enemy hit, THEN all statuses on A are removed immediately at DOWNED.
FAIL: benched durations decrement; ticks apply while benched; statuses linger on a DOWNED record. **Test type**: Unit.

### Enemy Asymmetry (Rule 8)

**AC-TBC-21** (BLOCKING): Enemy moves always available — no energy gating, no Overheat.
GIVEN an enemy with `energy_capacity = 80` authored and a skill costing 30, WHEN it is the enemy's turn at any point, THEN all skills are selectable by the AI hook; no energy check; the enemy never enters OVERHEATED; no heat tracking exists for it.
FAIL: skills filtered by energy; enemy Overheats; energy initialized at battle start. **Test type**: Unit.

### Damage Resolution (Rule 10)

**AC-TBC-22** (BLOCKING): SYN-F4 applies to both sides before DF-1; the fixture discriminates synergy-amplified vs. base-only.
GIVEN active Symbot `physical_power = 90` with frozen synergy delta `{ physical_power: 25 }` → effective A = 115; enemy `armor = 55`, no synergy → D = 55; PHYSICAL KINETIC move; enemy `core_element = KINETIC` → T = 1.0, WHEN the move resolves, THEN `compute_damage(115, PHYSICAL, KINETIC, 55, KINETIC, 1.0)` is called (argument-capture stub) and damage = `floor(13225/170 + 0.0001)` = **77**; enemy structure −77.
FAIL: `compute_damage(90, …)` called (SYN-F4 skipped — damage 55); synergy applied to enemy defense.
*Type-effectiveness integration:* same fixture but enemy `core_element = VOLT` → T = 1.5 (Kinetic is super-effective vs. Volt per the DF-1 type chart), THEN damage = `floor(77.7941… × 1.5 + 0.0001)` = **116**. FAIL: T = 1.0 (lookup failed) or T = 0.75 (inverted chart). **Test type**: Unit.

**AC-TBC-23** (BLOCKING): Burn bypasses DF-1 — Armor/Resistance/type never reduce it.
GIVEN enemy `armor = 80`, `resistance = 80`, `core_element = KINETIC`; Burn active (processing 72 → tick 5), WHEN Burn ticks, THEN structure −5 exactly; `compute_damage` NOT called; no type multiplier applied.
FAIL: Burn routed through DF-1; tick reduced by armor; tick scaled by type matchup. **Test type**: Unit.

### Status System (Rule 11)

**AC-TBC-13** (BLOCKING): Reapplication refreshes duration AND re-snapshots — newest wins entirely. *(Verifies EC-TBC-07)*
GIVEN Burn active with `snapshotted_processing = 30` (tick 2), 1 turn left, WHEN reapplied with processing 72, THEN duration = 2 (reset, not 1+2) and tick = 5 (snapshot replaced).
*Discriminating lower-processing reapplication:* then reapply with processing 10 → tick = **2**, duration = 2. FAIL: tick = 5 (max()/higher-wins logic retained the old snapshot instead of newest-wins). **Test type**: Unit.

**AC-TBC-14** (BLOCKING): Unknown effect ID: log + skip, no crash. *(Verifies EC-TBC-08 / Synergy EC-SYN-05 obligation)*
GIVEN the registry lacks `&"unknown_passive_xyz"` and a Symbot's effect list is `[&"volt_shock_on_hit", &"unknown_passive_xyz"]`, WHEN triggers fire, THEN `volt_shock_on_hit` resolves normally; exactly one content error logged naming the unknown ID; no crash; remaining effects unaffected.
FAIL: crash; silent swallow; the unknown ID halts processing of the rest of the pool. **Test type**: Unit (stub logger captures the message).

**AC-TBC-15** (BLOCKING): Zero-potency statuses are legal no-ops; Burn still ticks BURN_MIN. *(Verifies EC-TBC-09)*
GIVEN applier processing 0: Shock penalty = 0 (target mobility unchanged, status displays and expires); Stagger pct = 0 (`floor(50 × 1.0 + 0.0001) = 50`, no reduction); Burn tick = `max(2, 0)` = **2**.
FAIL: zero-potency status rejected or crashes; mobility/damage wrongly reduced; Burn ticks 0. **Test type**: Unit.

**AC-TBC-24** (BLOCKING): All three statuses coexist; reapplication targets same-type only.
GIVEN Shock (proc 53), Burn (proc 72), Stagger (proc 86) all applied to one target, THEN all three present with independent snapshots/durations (penalty 15, tick 5, pct 21). WHEN Burn reapplied (proc 30), THEN only Burn's record changes; Shock and Stagger untouched.
FAIL: statuses overwrite each other; any status rejected because another type is present. **Test type**: Unit.

### Formula Discriminators (Section D fixtures)

**AC-TBC-25** (BLOCKING): TBC-F3 Burn floor. processing 72 → `floor(5.7601)` = **5** (round/ceil → 6 FAIL). Boundaries: processing 0 → 2 (BURN_MIN, guard-only); processing 110 → `floor(8.8001)` = **8** (round/ceil → 9 FAIL). **Test type**: Unit.

**AC-TBC-26** (BLOCKING): TBC-F5 two-step floor. Step 1: processing 86 → `floor(21.5001)` = **21** (GDScript round-half-away gives 22 — FAIL). Step 2: damage 50, pct 21 → `floor(39.5001)` = **39** (round/ceil → 40 FAIL). Floor guard: damage 1, pct 27 → `max(1, floor(0.7301))` = **1**. **Test type**: Unit.

**AC-TBC-27** (BLOCKING): TBC-F6 Repair floor. ep 45 → `floor(12.6501)` = **12** (round/ceil → 13 FAIL); ep 150 → `floor(30.5001)` = **30** (round → 31 FAIL). **Test type**: Unit.

**AC-TBC-28** (BLOCKING): DF-1 extended range. Absolute ceiling A=150, D=0, T=1.5 → **225**. Realistic ceiling A=150, D=55, T=1.5 → `floor(164.6342…)` = **164** (round/ceil → 165 FAIL). Minimum A=1, D=182, T=0.75 → `max(1, 0)` = **1** (DAMAGE_FLOOR). **Test type**: Unit.

**AC-TBC-16** (BLOCKING): Repair caps at max_structure; costs still paid. *(Verifies EC-TBC-10)*
GIVEN structure 98/100, ep 45 (repair 12), move cost 15 energy / 8 heat, energy 60, heat 20, WHEN used, THEN energy 45, structure `min(100, 110)` = **100** (overheal discarded), heat 28. *At exactly full:* repair is legal, wasteful, costs apply.
FAIL: rejected at full; uncapped overheal; costs skipped on wasted repair. **Test type**: Unit.

### Passive Effect Registry (Rule 13)

**AC-TBC-29** (BLOCKING): `&"volt_shock_on_hit"` fires on any DAMAGE move; applies Shock with **duration 1** (not 2); snapshot = user's effective processing at the hit. *Negative case:* REPAIR moves do not trigger it.
FAIL: not applied; duration 2; snapshot unset. **Test type**: Unit.

**AC-TBC-30** (BLOCKING): `&"thermal_burn_on_weapon"` fires on WEAPON-slot DAMAGE moves only. WEAPON move → Burn (2 turns) applied; HEAD-slot DAMAGE move → NOT applied.
FAIL: slot filter ignored; duration ≠ 2. **Test type**: Unit.

### Battle End (Rule 12)

**AC-TBC-31** (BLOCKING): `battle_ended` payloads for all three outcomes; break events deduplicated.
*VICTORY:* break events `"arm_broken"` (fired twice) + `"head_cracked"` (once) → payload set has exactly 2 elements. FAIL: multiset of 3; empty set despite breaks.
*DEFEAT:* all 3 Symbots downed → `(DEFEAT, enemy_id, {})` — break events discarded. FAIL: events included.
*FLED:* `(FLED, enemy_id, {})`. FAIL: anything else.
*(Break-set collection is unit-tested with a stub emitter; the full hit_resolved chain is AC-TBC-INT-01.)* **Test type**: Unit.

**AC-TBC-32** (BLOCKING): All runtime state discarded after any outcome.
GIVEN a battle ends with Symbot A at heat 45 and Burn on the enemy, WHEN a new battle begins, THEN A's heat = 0, structure/energy at max, no statuses anywhere, fresh enemy instance, `evaluate_silent` runs again (snapshots not reused).
FAIL: any state carries over; post-battle reads of live combat state succeed. **Test type**: Unit.

### Enemy Stat Safety

**AC-TBC-19** (BLOCKING): Absent enemy stat keys read 0 via `.get()`. *(Verifies EC-TBC-15)*
GIVEN enemy `stats = { "structure": 80 }` only, THEN `mobility` reads 0 (acts last — player first per tie rule); `processing` reads 0 (its Shock/Stagger have zero potency; its Burn ticks at BURN_MIN 2); `armor`/`resistance` read 0 (full damage); no crash on any absent key.
FAIL: bracket-access runtime error; null propagates into a formula call. **Test type**: Unit.

### Content Validation (ADVISORY)

**AC-TBC-20** (ADVISORY, DEFERRED): All MVP move entries author `ammo_cost = 0`; validator warns on violations naming the move ID; TBC initializes no ammo pool. *Unblocks when: Move Database GDD + content validation tooling exist.* **Test type**: Content Validation.

**AC-TBC-33** (ADVISORY): `SYNERGY_POWER_BUDGET` (40) and `SYNERGY_DEFENSE_BUDGET` (50) enforced by the Synergy content validator — cumulative stat_delta across simultaneously active tiers, not per-tier. GIVEN content summing energy_power deltas to 41 across the 7-tier worst case, THEN a BLOCKING validation failure names the exceeded budget. FAIL: over-budget content passes; check is per-tier instead of cumulative. *Implementation lives in the Synergy content validator; stated here because TBC derived the constants.* **Test type**: Content Validation.

### Integration ACs (DEFERRED)

**AC-TBC-INT-01** (BLOCKING, DEFERRED): `hit_resolved(move, damage, target)` hook — Part-Break receives post-SYN-F4/post-Stagger final damage per hit; break events flow into the Rule 12 set. *Unblocks when: Part-Break GDD defines its subscription and accrual interface.* **Test type**: Integration.

**AC-TBC-INT-02** (BLOCKING, DEFERRED): Enemy AI hook returns exactly one legal move at enemy `ACTION_PENDING`; TBC resolves it through the same pipeline as player input; no energy gating applied. *Unblocks when: Enemy AI GDD defines `request_move(battle_state)`.* **Test type**: Integration.

**AC-TBC-INT-03** (BLOCKING, DEFERRED): Drop System consumes `battle_ended` — loot on VICTORY only, deduplicated set semantics. *Unblocks when: Drop System GDD defines its consumer interface.* **Test type**: Integration.

**AC-TBC-INT-04** (BLOCKING, DEFERRED): Workshop equip rejected while a battle is active; no `evaluate_silent` mid-battle. *Unblocks when: Workshop System GDD defines its lockout (Synergy DCO-8).* **Test type**: Integration.

### Summary

33 numbered ACs (29 BLOCKING unit, 2 ADVISORY content-validation, plus 4 DEFERRED integration). EC↔AC cross-check: every EC-TBC-01…15 observable outcome is verified by its named AC (see the Verified-by references in Edge Cases).

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-TBC-1 | Move Database GDD must **ratify MOVE-CONTRACT-1** (Rule 9) — accept the schema or negotiate changes explicitly with this GDD; silent divergence is forbidden. | Move Database GDD | Blocks Move DB authoring; blocks final validation of Rules 5/9 |
| OQ-TBC-2 | How does the type multiplier `T` reach the Combat UI from a damage event — `compute_damage()` returns a struct `{final_damage, type_mult}`, or TBC looks up T separately and forwards it? (Damage Formula OQ-1, restated — the decision is jointly owned by the TBC call contract and Combat UI GDD.) | Combat UI GDD + TBC implementation | Blocks Combat UI damage feedback spec (UI Req 3) |
| OQ-TBC-3 | **What does a SCAN move actually do?** MOVE-CONTRACT-1 lists SCAN as a behavior (HEAD skills are "scan or utility" per Assembly Rule 4) but no system defines its effect. Natural candidate: reveal enemy break regions/drop hints — which would make SCAN the delivery mechanism for Enemy DB constraint ED6's "drop-hint mechanism." Needs a design decision before Move DB content authoring. | Game Designer (resolve with Move DB GDD; coordinate with ED6) | HEAD-slot moves are unauthorable until defined; ED6's information layer may depend on it |
| OQ-TBC-4 | UTILITY behavior taxonomy — which non-damage, non-status, non-repair move behaviors exist in MVP (buffs? Heat venting? energy transfer?), if any? MVP could ship with zero UTILITY moves; the enum value exists for Move DB headroom. | Move Database GDD | Low — enum headroom; content decision |
| OQ-TBC-5 | Multi-enemy battles (Vertical Slice): Rule 1 locks MVP to one enemy; the `battle_ended` payload carries `enemy_id` extensibly. When multi-enemy is designed, targeting UI, initiative with multiple enemies, and AoE move semantics all need design. | Vertical Slice design | None for MVP |
| OQ-TBC-6 | Victory rewards beyond drops: MVP awards loot only (Drop System via `battle_ended`) — no XP (concept: no level grind), no currency (crafting/scrap deferred to Alpha blueprint system). Confirm the Drop System GDD is the sole reward channel or define scrap salvage there. | Drop System GDD / Economy Designer | Reward loop completeness at MVP |
