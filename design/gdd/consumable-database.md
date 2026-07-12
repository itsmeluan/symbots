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

**The feeling: the field-mechanic's kit — improvised salvage that turns a losing position around.**

Consumables are not potions bought from a shopkeeper. In MVP there are **no shops at all** — every item is *tech you pulled off the wrecks you fight*, so the entire consumable layer is salvage (NPC vendors may sell them in a later tier, but the MVP identity is pure scavenging). The fantasy is the resourceful scavenger-engineer: the player who, three encounters deep and low on Structure, remembers the **Repair Kit** they salvaged and welds themselves back into the fight — or who watches the Heat gauge climb toward an Overheat lockout, one turn from losing control, and slams a **Coolant Flush** to vent it and keep swinging. Each item is a small act of field-improvisation, and because every one was *found in the world* rather than bought, using it feels like the world paying back the time spent hunting it (**Pillar 5 — The World Is a Workshop**).

Consumables also sharpen the hunt itself. A **Salvage Beacon** is the player declaring "*this* kill matters — I need the drop" and tilting the odds for it; a **Scrap Lure** or **Signal Jammer** is the player shaping their own path through a zone — drawing out a farm, or slipping past a swarm to reach a boss with resources intact. These are the harvest loop's fine controls (**Pillar 2 — Every Battle Has a Harvest Goal**). Crucially, the fantasy stays *support*, never *substitute*: a player leaning on consumables to survive is buying time, not skipping the build problem. The durable answer to "I keep dying" is still a better Symbot — a Repair *move*, better parts, a sharper synergy — and consumables are the margin that lets a good-enough build push one encounter further, not a crutch that replaces it (**Pillar 1 — Engineer, Don't Collect**).

## Detailed Design

### Core Rules

**Rule 1 — Consumable definition (the schema).** A consumable is one static data resource. MVP authors eight.

| Field | Type | Notes |
|-------|------|-------|
| `consumable_id` | StringName | Unique id (e.g. `&"repair_kit"`) |
| `display_name` | String | Player-visible name |
| `rarity` | Enum | `COMMON / RARE / PROTOTYPE / BOSS_GRADE` — classifies for the Drop System table (Rule 7) |
| `effect_type` | Enum | `RESTORE_STRUCTURE / REDUCE_HEAT / RESTORE_ENERGY / BOOST_DROP / MODIFY_ENCOUNTER_RATE` |
| `effect_params` | Dictionary | Typed per `effect_type` (Rule 2) — mirrors Passive DB's `behavior_params` pattern |
| `use_context` | Enum | `BATTLE / WORLD / BOTH` |
| `target` | Enum | `LIVING_TEAM_MEMBER / CURRENT_BATTLE / OVERWORLD` (Rule 4) |
| `max_stack` | int | Inventory stack cap (storage owned by Inventory) |
| `buy_price` | int | Scrap to purchase from a vendor (**reserved** — post-MVP shops). Must be `> sell_price` (Rule 8) |
| `sell_price` | int | Scrap gained from selling one (**reserved** — post-MVP shops) |

**Rule 2 — Effect model (typed `effect_params`).** Required keys per `effect_type`:
- `RESTORE_STRUCTURE` → `{ amount: int }` — flat Structure restored, capped at the target's `max_structure`.
- `REDUCE_HEAT` → `{ amount: int }` — flat Heat removed, floored at 0; if it drops Heat below the Overheat threshold, the Symbot exits Overheat via TBC's normal Heat logic (no special flag).
- `RESTORE_ENERGY` → `{ amount: int }` — flat Energy restored, capped at max.
- `BOOST_DROP` → `{ multiplier: float }` — multiplies the current fight's effective drop rates (Rule 5).
- `MODIFY_ENCOUNTER_RATE` → `{ rate_multiplier: float, duration_steps: int }` — Jammer `< 1` (repel), Lure `> 1` (lure), active N steps (Rule 6).

*(Exact magnitudes → Formulas / Tuning Knobs.)*

**Rule 3 — Use context & turn economics.** `BATTLE` items **consume the active Symbot's turn** (a 4th action alongside move/switch/flee — the TBC erratum), generate **no Heat**, cost **no Energy**, and resolve in the action phase. `WORLD` items are used from the overworld/inventory menu with no turn concept, applied immediately. `BOTH` items work in either context and apply the same effect.

**Rule 4 — Targeting.** `RESTORE_*` items target a **player-chosen living team Symbot** (`Structure > 0`), active *or* benched — using a Repair Kit on a benched Symbot does **not** switch it in. A **downed** Symbot (Structure 0) is **not a valid target**: consumables never revive (revive is out of MVP; loss-stakes unchanged — TBC Rule 12). `BOOST_DROP` targets `CURRENT_BATTLE`; `MODIFY_ENCOUNTER_RATE` targets `OVERWORLD` movement (neither picks a unit).

**Rule 5 — Salvage Beacon (`BOOST_DROP`).** Used in battle, it sets a per-battle flag that multiplies that fight's effective drop rates by `multiplier` at resolution (`battle_ended VICTORY`), stacking multiplicatively with drop-condition multipliers (subject to the Drop System's clamp to [0, 1]). Consumed on use. On flee/loss it is spent with no effect (drops only on victory). **One Beacon per battle** — a second use while the boost is active is rejected (not wasted, not stacked).

**Rule 6 — Encounter modifiers (Signal Jammer / Scrap Lure).** `WORLD` items that set a transient overworld modifier for `duration_steps`: Jammer `rate_multiplier < 1` (repel), Lure `> 1` (lure). Feeds the new Encounter Zone EZ-1 hook: `effective_rate = clamp(base_rate × active_modifier, 0, 1)`. Duration counts down per step and expires. **Only one modifier active at a time** — using a second **replaces** the active one (latest wins).

**Rule 7 — Rarity vs drop frequency (ownership boundary).** `rarity` classifies a consumable for the Drop System's level/rarity-scaled table; it does **not** set drop frequency here. Consumables share the rarity *enum* with parts but **not** parts' base drop rates — the consumable drop channel is separate (Drop System erratum). MVP authors no `BOSS_GRADE` consumable (reserved).

**Rule 8 — Economy fields (Scrap; reserved for post-MVP shops).** Every consumable declares two prices in **Scrap** (the game's sole currency, owned by the Drop System economy / HOLISM-01): `buy_price` (Scrap to purchase) and `sell_price` (Scrap gained from selling one). **Invariant: `buy_price > sell_price` strictly, for every entry** — a vendor always buys back for less than it sells, so buy/sell can never become an arbitrage faucet. Validated as a **BLOCKING content rule** (Acceptance Criteria). Both fields are **authored now but inert in MVP**: there are no shops and no vendor-sell in MVP (drops-only), so nothing reads these values yet. When shops ship (post-MVP — NPC System #23 / a future dedicated Shop system), buying and selling both come online; consumables are **sold**, distinct from duplicate *parts*, which are player-*scrapped* to Scrap in Inventory/Workshop (Drop System Rule 9). Rarity broadly informs pricing (a Rare costs/returns more than a Common), but exact values are per-entry **Tuning Knobs**.

**Rule 9 — Scope boundary (what this DB does NOT own).** Owns *used-up support items* only. Does **not** define: **key items** (Key Item System #23a — unique, non-consumable, un-scrappable, story-gated); **parts** (Part DB); **drop frequency** (Drop System); **inventory quantities / stacking storage** (Inventory); **the resources** it restores (TBC owns Structure/Heat/Energy); **shop buy/sell logic and UI** (future NPC/Shop system — this DB only declares the prices). Designs/blueprints are a reserved Alpha drop class (Drop System Rule 11), not consumables.

**Rule 10 — MVP content scope (8 entries / 6 concepts).** Weld Patch (COMMON) · Repair Kit (RARE) · Field Forge (PROTOTYPE) [RESTORE_STRUCTURE tier family, Both] · Coolant Flush (COMMON, REDUCE_HEAT, Both) · Power Cell (COMMON, RESTORE_ENERGY, Both) · Salvage Beacon (RARE, BOOST_DROP, Battle) · Signal Jammer (RARE, MODIFY_ENCOUNTER_RATE down, World) · Scrap Lure (COMMON, MODIFY_ENCOUNTER_RATE up, World). No `BOSS_GRADE`; drops-only (no shop/craft faucet in MVP); `buy_price`/`sell_price` authored per entry but inert until shops ship; Overclock (buff) / Emergency Reboot (revive) reserved and unauthored.

### States and Transitions

The Consumable Database is a static schema authority with **no runtime state machine** (like Part DB / Drop System) — consumable *definitions* are immutable. The only mutable state is **inventory quantity** (owned by Inventory) plus two transient effect flags this DB's effects create but does **not** store:
- **Salvage Beacon boost** — a per-battle boolean (set on use, read by Drop System at `battle_ended VICTORY`, cleared when the battle ends). Owned by the battle context (TBC), not this DB.
- **Encounter modifier** — a `(rate_multiplier, steps_remaining)` pair active during overworld movement (set on use, decremented per step by Overworld Navigation, expires at 0). Owned by the overworld/traversal context, not this DB.

A single **use** is an atomic transaction: validate (item in inventory, valid target, valid context) → apply effect → decrement quantity by 1. There is no multi-step or reversible state — a use either fully applies or is rejected (Edge Cases), never partial.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Turn-Based Combat** | → read by *(ERRATUM)* | Action set gains **use item** (4th action alongside move/switch/flee). Reads `effect_type`/`effect_params` for BATTLE/BOTH items; applies restores to the chosen living team Symbot (target arg); consumes the turn, no Heat/Energy; sets the Salvage Beacon per-battle flag. TBC owns the resources (Structure/Heat/Energy). |
| **Drop System** | → read by *(ERRATUM)* | Reads `rarity` to place consumables in a level/rarity-scaled drop channel (separate from part loot pools); reads the Beacon flag to multiply the fight's effective drop rates (clamp [0, 1]). Consumable drop frequency owned by Drop System. Scrap currency (used by `buy_price`/`sell_price`) is owned by the Drop System economy (HOLISM-01). |
| **Encounter Zone** | → read by *(ERRATUM)* | Reads `MODIFY_ENCOUNTER_RATE` via a new EZ-1 modifier hook (un-defers OQ-EZ-4): `effective_rate = clamp(base_rate × active_modifier, 0, 1)`. |
| **Inventory** *(Not Started)* | ↔ stored by | Stores per-save consumable quantities as a **stackable** class (vs per-instance parts); reads `max_stack`, `display_name`, metadata. The DB declares stack behavior; Inventory owns the counts. |
| **Overworld Navigation** *(Not Started)* | ← used by | Decrements the encounter-modifier `steps_remaining` per step; applies the active modifier when calling EZ-1. |
| **NPC System / future Shop** *(Not Started)* | → read by | Post-MVP: reads `buy_price`/`sell_price` to run vendor buy/sell in Scrap. Inert in MVP (no shops). |
| **Combat UI / World Map UI** *(Not Started)* | → read by | Item menus (name/icon/use_context), the battle **target-picker** (living team member), and the Beacon + encounter-modifier active indicators. |

*Provisional: the TBC / Drop System / Encounter Zone errata are pending (to be applied when this GDD is approved — see Dependencies); Inventory / Overworld Navigation / NPC-Shop interfaces are provisional (Not Started).*

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
