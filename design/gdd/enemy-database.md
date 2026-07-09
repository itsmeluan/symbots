# Enemy Database

> **Status**: In Design
> **Author**: Luan + Claude Code (game-designer)
> **Last Updated**: 2026-07-09
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 5 (The World Is a Workshop)

## Overview

The Enemy Database is the authoritative catalog of every enemy definition in Symbots — the ~8 wild machine types and 2 bosses of the MVP zone, and every enemy added after. Each entry defines what an enemy *is*: its identity fields, its combat stat block, its Core element (read by the Damage Formula System for type effectiveness), its breakable part regions (the targets of Pillar 2's harvest decisions), and its loot table (which Sympart IDs it can drop, referencing the Part Database). It is the Part Database's sibling schema: parts define what players build with; enemies define what players hunt.

Like the Part Database, this system is read-only at runtime and stores no combat state. What an enemy's current Structure is mid-battle, which of its regions are broken, what it decided to do this turn — those belong to the Turn-Based Combat, Part-Break, and Enemy AI systems respectively. The Enemy Database only answers the question "what is a Rustcrawler?" — every downstream system (Turn-Based Combat, Encounter Zone, Drop System, Enemy AI, Damage Formula) reads from it and none may define enemy properties outside it.

## Player Fantasy

The player never thinks "the Enemy Database loaded an entry." They think: *"Crawlers drop Servo Arms when you break the arm before the kill — I need two more. There's a nest of them past the scrap dunes."* The Enemy Database is the infrastructure of the hunt plan: because every enemy has defined part regions, a defined element, and a defined loot table, every enemy in the world can be *read* — sized up, targeted, and farmed deliberately.

This is the Monster Hunter promise translated to Symbots: an enemy is never just an obstacle, it is a walking catalog of components the player wants (Pillar 2 — Every Battle Has a Harvest Goal). The fantasy this schema enables is **the world as a legible shopping list**. A player who wants a specific part should always be able to answer "which enemy, which behavior, which break target" — and the answer is stable, learnable, and worth writing down. When a player says "I'm going Crawler farming," the Enemy Database is what makes that sentence mean something.

The player also reads enemies in reverse: a new machine type appearing at the zone's edge is a promise of parts that don't exist in the inventory yet. The database's job is to make sure that promise is always real — every enemy entry must be *worth hunting* for at least one build hypothesis (Pillar 5 — The World Is a Workshop).

## Detailed Design

### Core Rules

**Rule 1 — The Enemy Schema**

Every enemy in the game is defined by the following fields. The Enemy Database stores one definition per enemy type; runtime combat state (current Structure, broken regions, Heat/Energy) is owned by the Turn-Based Combat System:

| Field | Type | Description |
|-------|------|-------------|
| `id` | StringName | Unique identifier (e.g., `"rustcrawler"`) |
| `display_name` | String | Player-visible name (e.g., "Rustcrawler") |
| `enemy_class` | Enum | `WILD` or `BOSS` (MVP). `ELITE, RIVAL` reserved for Full Vision. |
| `tier` | int | Zone-scaling tier. **Reserved field: always `1` in MVP content** (1 zone). Full Vision multi-zone content assigns higher tiers; no formula reads it in MVP. |
| `core_element` | Enum | `VOLT, THERMAL, KINETIC`, or `null`. Read by the Damage Formula System for type effectiveness (hard constraint DF3). `null` is valid content — an elementless construct; DF-1 defaults to ×1.0 per its EC-04. |
| `stats` | Dictionary | Stat name → int. Uses **the same 11 canonical stat names as Part Database Rule 4** — no enemy-specific stat vocabulary exists. See Rule 3. |
| `skills` | Array[StringName] | Move Database entry references — the enemy's move pool (2–4 in MVP). *(Provisional: Move Database GDD not yet designed.)* |
| `ai_profile` | StringName | Reference to a behavior profile defined by the Enemy AI System. *(Provisional: interface point only; Enemy AI GDD defines profile contents.)* |
| `break_regions` | Array[Dictionary] | Breakable part regions — see Rule 5. 2–3 per enemy in MVP. |
| `loot_pool` | Array[StringName] | Part Database `id`s this enemy can drop. See Rule 6. |
| `spawn_enabled` | bool | `true` = appears in encounter tables; `false` = no longer spawns (seasonal/retired). Mirrors Part Database `drop_enabled`. |
| `flavor_text` | String | One-line bestiary description, ≤100 characters. *(Aligns with the pending Part DB flavor_text length decision — whichever value is ratified there applies to both schemas.)* |

---

**Rule 2 — Enemy Classes (MVP)**

| Class | Count (MVP) | Loot Profile | Break Regions |
|-------|-------------|--------------|---------------|
| `WILD` | ~8 types | Common and Rare parts only | 2–3 regions; breaks boost Common/Rare drop rates |
| `BOSS` | 2 | Common, Rare, **and Boss-grade exclusive** parts | 2–3 regions; **at least one region's break event must gate the Boss-grade drop** (chains with Part DB AC-11: multiplier ≥ 500) |

Boss-grade parts never appear in a `WILD` enemy's `loot_pool` (Part DB Rule 8: "cannot appear in wild drop tables"). Prototype parts may appear in either class's pool — their gradient conditions (Part DB Formula 3) govern acquisition.

---

**Rule 3 — The Stat Block (hybrid model)**

Enemy stats are **hand-authored**, not derived from equipped parts. They use the identical 11-stat vocabulary from Part Database Rule 4 (Structure, Armor, Resistance, Physical Power, Energy Power, Mobility, Targeting, Processing, Cooling, Energy Capacity, Recharge) so that the Damage Formula and Turn-Based Combat treat both sides of a battle symmetrically.

**Range constraint (hard, inherited from DF-1):** `physical_power`, `energy_power`, `armor`, and `resistance` must stay within **[0, 110]** — the input range under which Damage Formula DF-1's behavior is verified. `structure` is exempt (it is the HP pool, not a DF-1 input) and may exceed 110, particularly for bosses. Unknown stat keys follow Part DB EC-08: warn and ignore.

**Design intent:** an enemy's stats should *read as if* it were built from parts — a heavily armored crawler has high Armor and low Mobility, matching its visible silhouette — but no formula enforces this. The fiction is carried by content authoring and by the anatomy-linked loot rule (Rule 5), not by a derivation pipeline. Full Vision may migrate `BOSS` entries to true part-assembly; the schema reserves that path (see Open Questions).

---

**Rule 4 — Core Element (DF3 fulfillment)**

Every enemy exposes `core_element`, satisfying Damage Formula hard constraint DF3. The Turn-Based Combat System passes it as `target_core_element` into `compute_damage()`. For the reverse direction (enemy attacking player), the *player's* Core element comes from their equipped Core part's `element` field — both sides route through the same DF-1 call.

---

**Rule 5 — Break Regions (anatomy-linked loot)**

Each entry in `break_regions` defines one breakable component:

```
{ region_id: "left_arm", display_name: "Servo Arm", break_hp: 40, break_event: "arm_broken" }
```

| Field | Type | Description |
|-------|------|-------------|
| `region_id` | StringName | Unique within this enemy |
| `display_name` | String | Player-visible region name (Combat UI break pips) |
| `break_hp` | int | Damage the region absorbs before breaking. Independent pool — region damage does not reduce body Structure. |
| `break_event` | StringName | Event emitted when the region breaks — **must match the Part DB `drop_conditions` vocabulary exactly** (e.g., `"arm_broken"`) |

**The anatomy link is a validation rule, not a second loot channel.** There is one drop pipeline: Part DB Formula 3. A region's break influences drops because parts in this enemy's `loot_pool` carry `drop_conditions` entries keyed to this region's `break_event`. The content rule (validated by AC-ED-07): every `break_event` this enemy can emit must be referenced by at least one part in its `loot_pool` — a breakable region that boosts nothing violates Pillar 2 ("battles without meaningful drop targets feel like filler") and is a content authoring error.

*How region damage accrues, whether regions can be targeted, and break probability mechanics are owned by the Part-Break System GDD (Part DB constraint DB3). This schema only declares which regions exist, their HP pools, and the events they emit.*

---

**Rule 6 — Loot Pool**

`loot_pool` lists every Part Database `id` this enemy can drop. On battle end, the Drop System iterates the pool and computes each part's effective drop rate via Part DB Formula 3 (per-rarity base rate × multipliers from fired condition events). The Enemy Database declares *what can drop*; the Drop System owns *how the roll works* — including whether pool size divides rates (Part DB Tuning Knobs: `BASE_DROP_RARE ÷ pool_size`).

Pool size guidance (MVP): `WILD` 2–4 parts; `BOSS` 4–6 parts including exactly 1–2 Boss-grade exclusives.

---

### States and Transitions

The Enemy Database is a static data schema — enemy definitions have no runtime states. No state machine applies. Lifecycle mirrors Part DB: entries are added at content authoring time; retired enemies are set `spawn_enabled = false` and remain valid (a defeated-boss rematch flag, if added later, is owned by Exploration Progress, not this schema).

---

### Interactions with Other Systems

| System | What It Reads | What It Expects |
|--------|--------------|-----------------|
| **Turn-Based Combat** | `stats`, `skills`, `core_element` — instantiates the runtime combatant | Stat keys match the 11 canonical names; skills reference valid Move DB entries |
| **Damage Formula** | `core_element` (via Combat's call frame); `stats` provide A and D inputs | A/D-relevant stats within [0, 110] |
| **Part-Break** | `break_regions` — region HP pools and break events | `break_event` values match Part DB drop_conditions vocabulary exactly |
| **Drop System** | `loot_pool`, fired break events | Every pool `id` exists in Part DB; boss pools contain their Boss-grade exclusives |
| **Enemy AI** | `ai_profile`, `skills`, `stats` | Profile IDs resolve to defined behavior profiles |
| **Encounter Zone** | `id`, `enemy_class`, `tier`, `spawn_enabled` — builds spawn tables | Spawn placement is Encounter Zone's domain; this schema holds no zone data |

## Formulas

### Formula EDB-1 — Break Region HP (derived)

```
break_hp = max( BREAK_HP_MIN, floor( structure × region_fraction ) )
```

`break_hp` is **derived, not free-authored**: rebalancing an enemy's `structure` automatically preserves each region's relative break timing. Authors set `region_fraction` per region; the schema stores the computed `break_hp`.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy body structure | `structure` | int | 60–600 | The enemy's full HP pool from its stat block (EDB-2 ranges) |
| Region fraction | `region_fraction` | float | 0.15–0.55 | Fraction of body Structure this region absorbs before breaking. Encodes *when* in the fight the region breaks — see guidance table. |
| Minimum break HP | `BREAK_HP_MIN` | int | 5 (tunable) | Hard floor preventing trivial single-hit breaks on low-Structure enemies |
| Result | `break_hp` | int | 5–330 | Independent damage pool for this region. Does not reduce body Structure. |

**Region fraction guidance (content authoring):**

| Fraction | Break timing (mid-game neutral, ~33 dmg/turn) | Use for |
|----------|-----------------------------------------------|---------|
| 0.15–0.25 | Early fight | "Opener" region — breaks with minimal focus; rewards attentiveness |
| 0.25–0.40 | Mid fight | Primary harvest target — the deliberate hunt objective |
| 0.40–0.55 | Late fight | Expert challenge — requires committed region focus or type advantage |

The 0.55 cap is the safety bound for EDB-3's break-cheaper-than-kill invariant. Fractions across an enemy's regions need not sum to 1.0 — regions are independent pools.

**Output range:** 5 to floor(600 × 0.55) = 330. Practical: WILD 5–88, BOSS 52–330.

**Worked example (discriminating — floor ≠ round ≠ ceil):** Rustcrawler, structure = 85, Left Arm at region_fraction = 0.35:
- `break_hp = max(5, floor(85 × 0.35)) = max(5, floor(29.75)) = 29`
- Verification: floor(29.75) = **29**; round = 30; ceil = 30 — an implementation using round() or ceil() returns 30 and fails.

**Rebalancing behavior:** retuning Rustcrawler's structure 85 → 100 auto-updates break_hp to floor(100 × 0.35) = 35 — same relative fight timing, no manual audit.

---

### Formula EDB-2 — Enemy Stat Budget (TTK calibration)

This is a **design-time calibration table**, not a runtime formula. It grounds authored enemy stats in the locked DF-1 math so fights land in the intended turn windows.

```
TTK_turns = ceil( structure / damage_per_turn(A_cal, D_enemy, T) )
```

where `damage_per_turn` is DF-1 evaluated at a calibration loadout:

| Calibration point | A | D | T | DF-1 dmg/turn |
|-------------------|---|---|---|---------------|
| Early-game neutral | 35 | 20 | 1.0 | 22 |
| Mid-game neutral | 53 | 30 | 1.0 | 33 |
| Mid-game super-effective | 53 | 30 | 1.5 | 50 |
| Mid-game resisted | 53 | 30 | 0.75 | 25 |

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy structure | `structure` | int | 60–600 | Full HP pool — the primary TTK lever |
| Enemy defense | `D_enemy` | int | 0–110 | Armor or Resistance (DF-1's D input) |
| Calibration player power | `A_cal` | int | 20–80 | Assumed player power at the balancing milestone |
| Type effectiveness | `T` | float | {0.75, 1.0, 1.5} | Matchup assumed for calibration; use 1.0 as baseline |
| Result | `TTK_turns` | int | 2–18 | Expected fight length at the calibration point |

**TTK targets and authored stat ranges (normative for AC-ED-05):**

| Class | TTK target | Structure | Physical Power | Energy Power | Armor | Resistance |
|-------|-----------|-----------|----------------|--------------|-------|------------|
| WILD (early) | 2–3 turns | 60–100 | 18–30 | 18–30 | 15–30 | 15–30 |
| WILD (mid) | 3–5 turns | 90–160 | 25–40 | 25–40 | 20–35 | 20–35 |
| BOSS | 12–18 turns | 350–600 | 35–70 | 35–70 | 30–55 | 30–55 |

**WILD power cap (hard content rule):** WILD enemies' `physical_power` and `energy_power` must not exceed **40**. Derivation: at A=45, T=1.5, vs. a glass-cannon player (Armor 10, Structure 60), DF-1 gives 55 dmg/hit — a 2-hit death from a *wild* encounter is a cheap death. At the cap (A=40): `1600/50 × 1.5 = 48` dmg — still a 2-hit threat but only against a zero-armor, minimum-structure build in the worst matchup, which is a legitimate build-failure outcome. BOSS power is exempt (up to 70; bosses are allowed to demand build homework).

**Boss TTK note:** the 12–18 turn band (not 10–20) is a mobile session-length decision — at 33 dmg/turn, 20 turns implies Structure ~660 and a 5–8 minute fight; 350–600 keeps bosses substantial but bounded. A higher-armor boss trades structure for defense within the same TTK: D=45, Structure 350 → 2809/98 = 28 dmg/turn → ceil(350/28) = 13 turns.

---

### Formula EDB-3 — Break Region Validity (content validation)

A validation rule run at authoring/import time — not a runtime computation.

```
break_cheaper_than_kill = break_hp < structure
loot_connected          = any( break_event in part.drop_conditions for part in loot_pool )
region_is_valid         = break_cheaper_than_kill AND loot_connected
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Region break HP | `break_hp` | int | 5–330 | From EDB-1 |
| Enemy structure | `structure` | int | 60–600 | Full body HP pool |
| Break event | `break_event` | StringName | — | Event this region emits (e.g., `"arm_broken"`) |
| Loot pool | `loot_pool` | Array[StringName] | — | This enemy's droppable Part DB ids |
| Result | `region_is_valid` | bool | — | `false` = content authoring error, caught at import — never a runtime fallback |

**Why `break_hp < structure`:** body and region damage are independent pools, so a break is always *possible* — the invariant is about *worth*. If breaking a region costs more damage than killing the enemy outright, targeted hunting is strictly worse than just winning, and the harvest decision loses meaning (Pillar 2). Breaking must always be the cheaper commitment. (The EDB-1 fraction cap of 0.55 guarantees this with margin; the invariant catches hand-authored overrides.)

**Why `loot_connected`:** a region whose break event no pool part references is a dead UI element — a break pip that does nothing. Violates Pillar 2; same rule as Section C Rule 5.

**Worked example:** Rustcrawler (structure 85), Left Arm (break_hp 29, event `"arm_broken"`), pool contains `rustcrawler_servo_arm` with `drop_conditions: ["arm_broken"]` → `29 < 85` ✓ AND connected ✓ → valid.

**Counter-example:** region "chest_plate" with break_hp 90, event `"plate_cracked"`, no pool part referencing it → `90 < 85` ✗ AND connected ✗ → authoring error, import fails.

---

**Deliberately not defined here:** damage-to-region routing and break targeting (Part-Break System GDD, per Part DB constraint DB3); drop roll mechanics (Part DB Formula 3, executed by Drop System). This schema declares regions and pools; those systems own the runtime.

## Edge Cases

### EC-ED-01 — Enemy with zero break regions
**If** an enemy entry has an empty `break_regions` array: content validation **fails** for MVP content. Pillar 2 requires every encounter to carry a harvest target — an unbreakable enemy is filler by definition. Minimum 1 region; target 2–3 per the game concept. (If Full Vision ever adds pure-ambush trash encounters, that requires a pillar-level exception, not a silent schema allowance.)

### EC-ED-02 — `loot_pool` references a nonexistent part id
**If** any `loot_pool` entry has no matching `id` in the Part Database: content validation fails at import. Dangling loot references are never valid — this is the Enemy DB analog of Part DB AC-13's referential integrity.

### EC-ED-03 — `loot_pool` contains a part with `drop_enabled = false`
**If** a pool part is drop-disabled: the entry is **valid** — the Drop System excludes it from rolls at runtime (Part DB AC-15a). The validator emits an authoring *warning* (not a failure), since a pool full of disabled parts silently starves the enemy's loot. If **all** parts in a pool are disabled, escalate to a failure — the enemy would violate EC-ED-01's spirit with zero obtainable drops.

### EC-ED-04 — Class/rarity mismatches in the loot pool
**If** a `WILD` enemy's pool contains a Boss-grade part: content validation fails (Part DB Rule 8: Boss-grade never appears in wild drop tables). **If** a `BOSS` pool contains no Boss-grade part: content validation fails (Rule 2 requires 1–2 exclusives). Both are import-time errors.

### EC-ED-05 — `core_element` is null
**If** `core_element` is null: valid content — an elementless construct. DF-1's EC-04 fallback applies (×1.0 neutral for all incoming skills). Note the strategic consequence: a null-element enemy cannot be exploited by type-matching, making it a "neutral wall" — use sparingly, as it mutes the type-mastery fantasy.

### EC-ED-06 — Missing or unknown keys in `stats`
**If** a canonical stat key is absent: treated as 0, with one exception — `structure` absent or 0 fails validation (a 0-Structure enemy dies on contact; never valid content). **If** an unknown key is present: warn and ignore, matching Part DB EC-08 — the shared 11-stat vocabulary evolves in one place.

### EC-ED-07 — Two regions emit the same `break_event`
**If** two regions on one enemy share a `break_event` (e.g., left and right arm both emit `"arm_broken"`): valid — but break events are **set semantics** for Formula 3. Breaking both arms fires `arm_broken` *once*; a part's ×1.5 `arm_broken` multiplier applies once, not squared. The Drop System collects fired events as a deduplicated set. (Rewarding double-breaks with a stronger multiplier requires a distinct event like `"both_arms_broken"` — Full Vision vocabulary.)

### EC-ED-08 — Duplicate `region_id` or duplicate `loot_pool` entries
**If** two regions on one enemy share a `region_id`: content validation fails (region ids are unique per enemy). **If** the same part id appears twice in `loot_pool`: validator dedupes with a warning — duplicates do not double the drop chance (the Drop System iterates unique ids).

### EC-ED-09 — `spawn_enabled = false` on a boss
**If** a `BOSS` entry is spawn-disabled: the schema permits it (seasonal/event bosses are the field's purpose), but the validator emits a *progression warning* — if the Zone & World Map gates progression on defeating this boss, disabling it soft-locks the game. The Encounter Zone GDD owns the actual progression-integrity check; this schema's responsibility is only to surface the flag.

### EC-ED-10 — Empty `skills` array
**If** an enemy has no skills: content validation fails. Every enemy needs at least 1 move (its basic attack) or its combat turns are no-ops. MVP range: 2–4.

### EC-ED-11 — `region_fraction` outside [0.15, 0.55]
**If** a region's fraction is authored outside EDB-1's bounds: content validation fails at import — no silent clamping. Below 0.15 produces trivial breaks (undermines the hunt); above 0.55 violates EDB-3's break-cheaper-than-kill margin.

### EC-ED-12 — `tier ≠ 1` in MVP content
**If** any MVP-shipped entry has `tier` other than 1: validator warning (not failure). The field is reserved; no MVP formula reads it — but stray values would silently become live balance data the moment Full Vision zone-scaling activates.

## Dependencies

### Upstream Dependencies (what Enemy Database requires)

| System | What It Provides | Status |
|--------|-----------------|--------|
| **Part Database** | The `id` vocabulary for `loot_pool`; the `drop_conditions` event vocabulary that `break_event` must match; rarity rules (Boss-grade exclusivity, Rule 8); the 11 canonical stat names; Formula 3 (the drop pipeline this schema feeds) | ✓ Approved |
| **Move Database** *(provisional)* | Entries for `skills[]` references | Not designed — referential validation (AC-ED-03) is BLOCKED until it exists, mirroring Part DB AC-13 |
| **Enemy AI System** *(provisional)* | The behavior profile contract behind `ai_profile` | Not designed — field is an interface stub |

### Downstream Dependents (what depends on Enemy Database)

| System | What It Reads | Hard Constraint on That GDD |
|--------|--------------|------------------------------|
| **Damage Formula** | `core_element` (as `target_core_element`), `stats` as A/D inputs | Already ratified: DF3 is fulfilled by Rule 4. A/D stats within [0, 110] (Rule 3). |
| **Turn-Based Combat** | `stats`, `skills`, `core_element` — instantiates runtime combatants | **ED1**: must ratify (or replace) the assumption that enemies run the same Heat/Energy economy as player Symbots — Cooling/Energy Capacity/Recharge in enemy stat blocks are meaningless until Combat defines enemy resource tracking. |
| **Part-Break System** | `break_regions` — HP pools and events | **ED2**: must define region targeting and damage accrual against `break_hp` (per Part DB DB3), and must emit each region's `break_event` on break. |
| **Drop System** | `loot_pool`, fired break events | **ED3**: must collect fired events as a **deduplicated set** before applying Formula 3 multipliers (EC-ED-07 semantics), and iterate unique pool ids only. |
| **Enemy AI** | `ai_profile`, `skills`, `stats` | **ED4**: owns the profile schema; must define what a profile contains and how `ai_profile` resolves. |
| **Encounter Zone** | `id`, `enemy_class`, `tier`, `spawn_enabled` | **ED5**: owns spawn placement and must implement the progression-integrity check for spawn-disabled bosses (EC-ED-09). |

### Bidirectionality Note

Part Database already lists Enemy Database in its Downstream Dependents table (✓ verified). Damage Formula already lists Enemy Database as an upstream dependency via DF3 (✓ verified). Each system in the table above must reference Enemy Database in its own Dependencies section when authored.

## Tuning Knobs

All values live in external config, not code. Drop-rate knobs (`BASE_DROP_*`, break multiplier) are owned by the Part Database Tuning Knobs section — do not duplicate them here; this schema only feeds them.

| Knob | Current Value | Safe Range | What Changing It Does |
|------|--------------|------------|----------------------|
| `BREAK_HP_MIN` | 5 | 3–10 | Floor on derived break HP. Below 3, weak enemies' regions break on any hit (breaks stop feeling earned); above 10, low-Structure enemies' regions can approach the kill threshold, straining EDB-3. |
| `REGION_FRACTION_MIN` | 0.15 | 0.10–0.20 | Lower authoring bound for EDB-1. Lowering makes "opener" regions nearly free; raising removes the early-break reward tier. |
| `REGION_FRACTION_MAX` | 0.55 | 0.45–0.60 | Upper authoring bound. Raising above 0.60 lets breaks cost more than half the kill — approaching the EDB-3 worth threshold; lowering compresses the expert-challenge tier. |
| `WILD_POWER_CAP` | 40 | 30–45 | Max WILD `physical_power`/`energy_power`. Above 45, glass-cannon players face 2-hit deaths from trash encounters (EDB-2 derivation); below 30, wild enemies stop threatening mid-game builds and combat pacing sags. |
| WILD Structure bands | 60–100 / 90–160 | ±20% | Fight length for trash encounters. Directly multiplies session pacing — the primary "does farming feel fast" lever. |
| BOSS Structure band | 350–600 | 300–660 | Boss fight length (12–18 turns at calibration). Above 660 ≈ 20+ turns — mobile grind territory; below 300, bosses die inside 10 turns and stop feeling like walls that demand build homework. |
| Boss TTK target | 12–18 turns | 10–20 | The design intent behind the Structure band. Changing this requires recomputing the band via EDB-2 — never change one without the other. |
| Pool size (WILD / BOSS) | 2–4 / 4–6 | 2–6 / 3–8 | Larger pools dilute per-part rates if the Drop System divides by pool size (Part DB knob note) — coordinate any change with the Drop System GDD. |

**Knob interaction warning:** `WILD_POWER_CAP`, the Structure bands, and the Boss TTK target are all coupled through EDB-2's calibration points, which are themselves derived from DF-1 at assumed player loadouts. If the Part Database stat budgets or DF-1's type multipliers are retuned, re-run the EDB-2 calibration table before trusting any of these ranges.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
