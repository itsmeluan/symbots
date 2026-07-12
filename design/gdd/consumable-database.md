# Consumable Database

> **Status**: **APPROVED — 2026-07-12 full-panel `/design-review`** (game-designer, systems-designer, economy-designer, qa-lead + creative-director synthesis). Verdict NEEDS REVISION → 5 surgical blockers resolved + verified same session (CD committed APPROVE on fix-confirmation). The systems-designer's IEEE-754 blocker on AC-CD-09/10 was **refuted** by a python3 float scan (independently confirmed by qa-lead) — `0.15×0.1`/`0.35×2.5`/`0.15×2.5` are exact; ACs unchanged. Blockers fixed: (1) Rule 3 rejection = pre-action gate, no turn consumed; (2) AC-CD-14 → named `EncounterModifierState` owner, true unit test; (3) AC-CD-12 → added `beacon_qty==0` flee-no-refund assertion; (4) new AC-CD-25 (BLOCKING unit: no-Heat/no-Energy on use); (5) CD-2 Coolant Flush **preventive-only** re Overheat (no carve-out ahead of TBC Rule 4 skip — bound to the TBC erratum). 24→25 ACs (19 BLOCKING). **3 RECOMMENDED carry into errata work**: latest-wins modifier replacement + Beacon flee-spend framing (bind as intended-behavior notes), and the contingent "Beacon 2:1 self-replenish" claim (pending Drop System drop-frequency erratum).
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 5 (The World Is a Workshop), Pillar 2 (Every Battle Has a Harvest Goal) — support layer under Pillar 1 (Engineer, Don't Collect)

## Overview

The **Consumable Database** is the schema authority for every usable item in Symbots — the salvaged machine-tech a player carries into and out of a fight. It answers one question per item: *"What is this, how rare is it, and what does it do when used?"* A consumable definition is a static data resource — a named entry declaring the item's display name, rarity tier, effect (type and magnitude), the context it can be used in (in battle, in the overworld, or both), and how it stacks in the inventory. Like the Part and Enemy Databases, it stores **definitions only**: it is read-only at runtime and holds no per-save quantities (owned by the Inventory System).

The database has a player-facing edge the other schema authorities lack: its entries are items the player *actively uses*. A **Repair Kit** welds Structure back onto a battered Symbot; a **Coolant Flush** dumps a dangerous Heat gauge; a **Signal Jammer** buys quiet passage through a swarm-nest. Every downstream system that consumes an item reads its effect from here — Turn-Based Combat applies the resource restores, the Drop System scatters consumables as loot, and Encounter Zone reads the repel/lure modifiers — but the Consumable Database owns the single source of truth for *what each item is*. Consumables are a deliberately **small support layer**: they smooth the moment-to-moment hunt without replacing build decisions — healing remains primarily a REPAIR *move*, a choice made in the Workshop, not a stockpile of potions (Pillar 1).

In MVP the database defines a compact roster of **eight items across six effect concepts** (the RESTORE_STRUCTURE concept is a three-tier family — Weld Patch / Repair Kit / Field Forge — see Rule 10) across the standard rarity tiers, dropped from enemies via a level/rarity-scaled table (Drop System). The schema is designed to generalize — later tiers add entries and new effect types without schema changes — but MVP content populates only these eight. **Designs/blueprints remain an Alpha drop class** (Blueprint Crafting #25); the MVP consumable layer is **drops-only**, with no crafting or shop faucet.

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

**Rule 3 — Use context & turn economics.** A `BATTLE` item that **successfully applies consumes the active Symbot's turn** (a 4th action alongside move/switch/flee — the TBC erratum), generates **no Heat**, costs **no Energy**, and resolves in the action phase. `WORLD` items are used from the overworld/inventory menu with no turn concept, applied immediately. `BOTH` items work in either context and apply the same effect. **Rejection is a pre-action validation gate, never charged.** A use that fails validation (no valid target, wrong context, zero-net/already-full, none in inventory, second Beacon while one is active — see Edge Cases) is rejected *before the action commits*: the **turn is NOT consumed** and the **item is NOT decremented**, and the player is free to choose another action that same turn. The battle item-menu SHOULD grey out an item that has no valid target in the current context (UI Requirements 1–2) so the common rejection is prevented at selection rather than surfaced after a wasted tap.

**Rule 4 — Targeting.** `RESTORE_*` items target a **player-chosen living team Symbot** (`Structure > 0`), active *or* benched — using a Repair Kit on a benched Symbot does **not** switch it in. A **downed** Symbot (Structure 0) is **not a valid target**: consumables never revive (revive is out of MVP; loss-stakes unchanged — TBC Rule 12). `BOOST_DROP` targets `CURRENT_BATTLE`; `MODIFY_ENCOUNTER_RATE` targets `OVERWORLD` movement (neither picks a unit).

**Rule 5 — Salvage Beacon (`BOOST_DROP`).** Used in battle, it sets a per-battle flag that multiplies that fight's effective drop rates by `multiplier` at resolution (`battle_ended VICTORY`), stacking multiplicatively with drop-condition multipliers (subject to the Drop System's clamp to [0, 1]). Consumed on use. On flee/loss it is spent with no effect (drops only on victory). **One Beacon per battle** — a second use while the boost is active is rejected (not wasted, not stacked). **Observable contract (part of the TBC erratum):** the battle context exposes `beacon_used_this_battle: bool` (set true on use, cleared at battle end) and, at resolution, `beacon_drop_multiplier_applied: bool` (true only on VICTORY) — these are the queryable fields AC-CD-11/12 assert against.

**Rule 6 — Encounter modifiers (Signal Jammer / Scrap Lure).** `WORLD` items that set a transient overworld modifier for `duration_steps`: Jammer `rate_multiplier < 1` (repel), Lure `> 1` (lure). Feeds the new Encounter Zone EZ-1 hook: `effective_rate = clamp(base_rate × active_modifier, 0, 1)`. Duration counts down per step and expires. **Only one modifier active at a time** — using a second **replaces** the active one (latest wins).

**Rule 7 — Rarity vs drop frequency (ownership boundary).** `rarity` classifies a consumable for the Drop System's level/rarity-scaled table; it does **not** set drop frequency here. Consumables share the rarity *enum* with parts but **not** parts' base drop rates — the consumable drop channel is separate (Drop System erratum). MVP authors no `BOSS_GRADE` consumable (reserved).

**Rule 8 — Economy fields (Scrap; reserved for post-MVP shops).** Every consumable declares two prices in **Scrap** (the game's sole currency, owned by the Drop System economy / HOLISM-01): `buy_price` (Scrap to purchase) and `sell_price` (Scrap gained from selling one). **Invariant: `buy_price > sell_price` strictly, for every entry** — a vendor always buys back for less than it sells, so buy/sell can never become an arbitrage faucet. Validated as a **BLOCKING content rule** (Acceptance Criteria). Both fields are **authored now but inert in MVP**: there are no shops and no vendor-sell in MVP (drops-only), so nothing reads these values yet. When shops ship (post-MVP — NPC System #23 / a future dedicated Shop system), buying and selling both come online; consumables are **sold**, distinct from duplicate *parts*, which are player-*scrapped* to Scrap in Inventory/Workshop (Drop System Rule 9). Rarity broadly informs pricing (a Rare costs/returns more than a Common), but exact values are per-entry **Tuning Knobs**.

**Rule 9 — Scope boundary (what this DB does NOT own).** Owns *used-up support items* only. Does **not** define: **key items** (Key Item System #23a — unique, non-consumable, un-scrappable, story-gated); **parts** (Part DB); **drop frequency** (Drop System); **inventory quantities / stacking storage** (Inventory); **the resources** it restores (TBC owns Structure/Heat/Energy); **shop buy/sell logic and UI** (future NPC/Shop system — this DB only declares the prices). Designs/blueprints are a reserved Alpha drop class (Drop System Rule 11), not consumables.

**Rule 10 — MVP content scope (8 entries / 6 concepts).** Weld Patch (COMMON) · Repair Kit (RARE) · Field Forge (PROTOTYPE) [RESTORE_STRUCTURE tier family, Both] · Coolant Flush (COMMON, REDUCE_HEAT, Both) · Power Cell (COMMON, RESTORE_ENERGY, Both) · Salvage Beacon (RARE, BOOST_DROP, Battle) · Signal Jammer (RARE, MODIFY_ENCOUNTER_RATE down, World) · Scrap Lure (COMMON, MODIFY_ENCOUNTER_RATE up, World). No `BOSS_GRADE`; drops-only (no shop/craft faucet in MVP); `buy_price`/`sell_price` authored per entry but inert until shops ship; Overclock (buff) / Emergency Reboot (revive) reserved and unauthored.

### States and Transitions

The Consumable Database is a static schema authority with **no runtime state machine** (like Part DB / Drop System) — consumable *definitions* are immutable. The only mutable state is **inventory quantity** (owned by Inventory) plus two transient effect flags this DB's effects create but does **not** store:
- **Salvage Beacon boost** — a per-battle boolean (set on use, read by Drop System at `battle_ended VICTORY`, cleared when the battle ends). Owned by the battle context (TBC), not this DB.
- **Encounter modifier** — an `EncounterModifierState` holding a `(rate_multiplier, steps_remaining)` pair active during overworld movement (set on use, decremented per step by Overworld Navigation via its sole mutator `on_overworld_step()`, expires at 0). It exposes **no battle-turn handler** — the countdown is frozen during battle *structurally* (battle turns never call it), not by an in-battle guard (AC-CD-14). Owned by the overworld/traversal context, not this DB.

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

*The TBC / Drop System / Encounter Zone errata are **APPLIED** (2026-07-12, on approval — TBC Rule 7a + AC-TBC-41; Drop Rule 12 + AC-DS-31; Encounter Zone EZ-1 hook + AC-EZ-59 / OQ-EZ-4 RESOLVED; registry + GDDs updated together). Inventory / Overworld Navigation / NPC-Shop interfaces remain provisional (Not Started).*

## Formulas

**No formula in this section uses `floor()`/`ceil()`.** CD-1/2/3 are pure integer clamps (`min`/`max`); CD-4/5 are float-multiply-into-`clamp()` feeding a `randf() <` comparison (identical in structure to the already-approved EZ-1 and DS-1). No epsilon nudge is needed and **no python3 float scan is required** — stated explicitly so a reviewer does not flag the absence. All effect magnitudes are per-entry constants (Tuning Knobs, Section G). Combat resource ranges are owned by upstream systems: `max_structure` ∈ [60, 594] (SA-F1), Heat ∈ [0, 100] (Overheat at 100), `max_energy` ∈ [80, 120] (SA-F1), `BASE_ENERGY_REGEN = 10`/turn (TBC-F2).

### CD-1 — RESTORE_STRUCTURE (Weld Patch / Repair Kit / Field Forge)

`new_structure = min(max_structure, current_structure + amount)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current Structure | `current_structure` | int | [1, max_structure] | Target's Structure at use (> 0 enforced by living-target rule) |
| Max Structure | `max_structure` | int | [60, 594] | Target's max Structure (SA-F1, build-dependent) |
| Restore amount | `amount` | int | tier constant | **Weld Patch 25 / Repair Kit 50 / Field Forge 120** |
| Output | `new_structure` | int | [1, max_structure] | Structure after application; overheal clamped, never exceeds max |

**Output range:** [1, max_structure]. Pure integer arithmetic + `min()` clamp. **Design choice — flat, not %-of-max:** a percentage heal would make a consumable trivial for a 60-Structure glass cannon (the build that most needs the rescue) and introduce a `floor(pct × max)` requiring an epsilon scan. Flat healing is meaningful across the 10× spread (25 = 42% of a glass cannon, real absolute HP for a tank) and scan-exempt.

**Worked example:** current 37, max 60, Repair Kit (50) → `min(60, 87) = 60` (glass-cannon full restore, 27 overheal discarded — the clamp-fires case). Non-clamp: current 150, max 300, Repair Kit → `min(300, 200) = 200` (heals exactly 50). Repair Kit's 50 exceeds the REPAIR *move*'s absolute ceiling (30 at max energy_power), justifying the item + turn cost without eclipsing a dedicated REPAIR build (which heals every turn).

### CD-2 — REDUCE_HEAT (Coolant Flush)

`new_heat = max(0, current_heat − amount)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current Heat | `current_heat` | int | [0, 100] | Target's Heat gauge at use |
| Reduce amount | `amount` | int | constant **50** | Heat removed by a Coolant Flush |
| Output | `new_heat` | int | [0, current_heat] | Heat after application; floored at 0, never negative |

**Output range:** [0, current_heat]. `max(0, …)` clamp prevents negative Heat; if the result drops below the Overheat threshold the Symbot exits Overheat via TBC's normal Heat logic (no special flag). **50 rescues a near-Overheat state with margin** (90 → 40) while leaving Heat management meaningful (not a full reset — a full 100→0 wipe would delete the Heat tension entirely).

**Preventive-only interaction with Overheat (design decision, 2026-07-12).** Because using a consumable *is* the active Symbot's action, and a Symbot that **starts its turn already Overheated (Heat 100) skips its action phase** (TBC Rule 4), a Coolant Flush **cannot rescue an already-Overheated Symbot** — the action phase in which the item would resolve is skipped. Coolant Flush is therefore a **preventive** vent, used on an earlier turn to bleed Heat down *before* the gauge tips to 100 (e.g. 90 → 40). An already-Overheated Symbot eats its skip; the consumable layer deliberately does **not** soften Overheat's self-inflicted, legible penalty (TBC Player Fantasy — "Overheat is a self-inflicted failure"). Only the *active* Symbot builds Heat (benched Symbots are frozen — TBC Rule 6), so this interaction only ever concerns the active Symbot. **This is a binding note on the TBC erratum** (Dependencies → Errata): the erratum adds `use item` as a normal action *within* the action phase, with **no** carve-out ahead of the Rule 4 Overheat skip check.

**Worked example:** current 90 → `max(0, 40) = 40` (near-Overheat rescue, no clamp). current 30 → `max(0, −20) = 0` (clamp fires, floors at 0 — the `amount > current_heat` case).

### CD-3 — RESTORE_ENERGY (Power Cell)

`new_energy = min(max_energy, current_energy + amount)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current Energy | `current_energy` | int | [0, max_energy] | Target's Energy at use |
| Max Energy | `max_energy` | int | [80, 120] | Target's energy capacity (SA-F1) |
| Restore amount | `amount` | int | constant **25** | Energy restored by a Power Cell |
| Output | `new_energy` | int | [0, max_energy] | Energy after application; capped at max_energy |

**Output range:** [0, max_energy]. `min()` clamp prevents over-cap. **25 ≈ 2.5 turns of regen** (BASE_ENERGY_REGEN 10) — buys roughly two moves (Move DB Rule 7: move cost > 10), a "one more big move" bridge, not an engine reset (which +50 on an 80-cap pool would be).

**Worked example:** current 5, max 80 → `min(80, 30) = 30` (no clamp). current 100, max 120 → `min(120, 125) = 120` (clamp fires, 5 discarded).

### CD-4 — BOOST_DROP (Salvage Beacon)

`effective_drop_rate = clamp(base_rate × Π(condition_multipliers) × beacon_multiplier, 0.0, 1.0)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base rate | `base_rate` | float | {0.70, 0.25, 0.05, 0.001} | Per-rarity base drop rate (Drop System / Part DB Formula 3) |
| Condition product | `Π(condition_multipliers)` | float | [1.0, ∞) | Product of fired drop-condition multipliers this fight |
| Beacon multiplier | `beacon_multiplier` | float | constant **2.0** | Salvage Beacon's factor, injected into the Drop System product |
| Output | `effective_drop_rate` | float | [0.0, 1.0] | Final per-roll drop probability; clamped, fed to `randf() <` |

**Output range:** [0.0, 1.0]. Float multiply into `clamp()` — no `floor()`. **beacon_multiplier = 2.0** is the economy-validated value: a Beacon self-replenishes at RARE base 0.25 × 2.0 = 0.50, so the player *drains* Beacons ~2:1 (sustainable, no runaway farm-Beacons-to-farm-Beacons loop; ×3.0+ is where that breaks — see Tuning Knobs safe range 1.5–2.5). Guardrails: one Beacon per battle, spent on flee/loss, drops only on victory (Rule 5).

**Worked example:** Rare, no conditions, Beacon → `clamp(0.25 × 1.0 × 2.0) = 0.50` (a coin-flip Rare — meaningful lift, still a real miss chance). Prototype, floor-compliant conditions (×4.5), Beacon → `clamp(0.05 × 4.5 × 2.0) = 0.45` (vs 0.225 without). Common at conditioned ceiling → `clamp(0.70 × … × 2.0) = 1.0` (already-guaranteed Commons gain nothing — acceptable; a Rare item guaranteeing a 5-Scrap Common is a fair trade).

### CD-5 — MODIFY_ENCOUNTER_RATE (Signal Jammer / Scrap Lure)

`effective_rate = clamp(base_rate × rate_multiplier, 0.0, 1.0)` — applied for `duration_steps` steps; then `triggered = rng.randf() < effective_rate` (EZ-1).

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base rate | `base_rate` | float | {0.07, 0.15, 0.35} | Zone's density encounter_rate (EZ-1) |
| Rate multiplier | `rate_multiplier` | float | > 0.0 | < 1 = repel, > 1 = lure |
| Duration | `duration_steps` | int | > 0 | Steps the modifier stays active |
| Output | `effective_rate` | float | [0.0, 1.0] | Clamped per-step rate; replaces base_rate in EZ-1 |

**Constants:** Signal Jammer `rate_multiplier = 0.1`, `duration_steps = 20` (90% reduction — a heavy but not total suppression, so a DENSE zone still threatens rather than becoming free transit). Scrap Lure `rate_multiplier = 2.5`, `duration_steps = 15` (stays under the 1.0 clamp even at DENSE 0.35 × 2.5 = 0.875, so movement isn't reduced to every-step forced combat).

**Output range:** [0.0, 1.0]. Same clean float-clamp-into-`randf()<` as EZ-1 — no `floor()`. **Worked example:** DENSE 0.35 × Jammer 0.1 = `clamp(0.035) = 0.035` (~1 encounter/29 steps, down from 1/2.9). SPARSE 0.07 × Lure 2.5 = `clamp(0.175) = 0.175` (~1/5.7 steps, up from 1/14.3). Only one modifier active at a time; a second use replaces it (Rule 6).

## Edge Cases

**EC-CD-01 — Zero-net-effect use (overheal / already-full / already-cool).** A `RESTORE_STRUCTURE` on a full-Structure target, `RESTORE_ENERGY` on a full-Energy target, or `REDUCE_HEAT` on a target at Heat 0 would change nothing: the use is **rejected before consumption** — the item is NOT consumed, **the turn is NOT spent (Rule 3 — rejection is a pre-action gate)**, and feedback tells the player it would have no effect. A *partial* effect (e.g. current 55 / max 60, Weld Patch heals 5 then clamps) is **allowed and consumed** — only an exactly-zero net change is rejected. Prevents accidental waste. *Verified by AC-CD-05.*

**EC-CD-02 — Use on a downed Symbot.** A `RESTORE_*` item targeting a Symbot at `Structure == 0` is **rejected**, item not consumed — consumables never revive (Rule 4). *Verified by AC-CD-06.*

**EC-CD-03 — Wrong use context.** A `BATTLE`-only item used in the overworld, or a `WORLD`-only item used in battle, is **rejected**, not consumed (Rule 3). `BOTH` items are valid in either context. *Verified by AC-CD-07.*

**EC-CD-04 — None in inventory.** A use requested for a consumable at quantity 0 is **rejected** — nothing is consumed. Quantity is owned by Inventory; the use action validates `quantity > 0` before applying. *Verified by AC-CD-08.*

**EC-CD-05 — Second Salvage Beacon in one battle.** With a Beacon boost already active this battle, a second Beacon use is **rejected**, not consumed (Rule 5 — no stacking, no waste). *Verified by AC-CD-11.*

**EC-CD-06 — Second encounter modifier while one is active.** Using a Signal Jammer or Scrap Lure while a modifier is active **replaces** the active modifier with the new one — the new item is consumed and the prior flag is discarded (Rule 6, latest wins). This is a replacement, not a rejection. *Verified by AC-CD-13.*

**EC-CD-07 — Beacon used but battle not won.** If a battle with an active Beacon ends in flee or loss, the Beacon is **already spent** (consumed on use) and has no effect — drops only on victory (Drop System Rule 1). *Verified by AC-CD-12.*

**EC-CD-08 — Encounter modifier across battles / persistence.** The encounter modifier counts down **per overworld step only** — it is frozen during a battle (no steps occur) and resumes after, persisting until `steps_remaining` reaches 0. Survival across save/reload is owned by Overworld Navigation (provisional; if discarded on reload, that is an acceptable minor loss, never a crash). *No-crash verified by AC-CD-14; persistence deferred (Overworld Navigation / Save-Load).*

**EC-CD-09 — Malformed `effect_params`.** A consumable whose `effect_params` is missing a key its `effect_type` requires (e.g. `RESTORE_STRUCTURE` with no `amount`) is a **content error at load**: the item is flagged invalid and unusable (fail-safe — never applies an undefined effect); validation names the consumable and the missing key. *Verified by AC-CD-15.*

**EC-CD-10 — `buy_price ≤ sell_price` (economy invariant violation).** A consumable authored with `buy_price <= sell_price` is a **BLOCKING content error** (Rule 8 invariant); validation names the item and both values. Fail-safe: the item still functions in MVP (prices are inert), but the check blocks it from shipping to a shop-enabled build. *Verified by AC-CD-16.*

**EC-CD-11 — Unknown `effect_type`.** A consumable with an `effect_type` outside the defined enum is a **content error**; the item is unusable (fail-safe), validation names it. *Verified by AC-CD-17.*

**EC-CD-12 — `max_stack` overflow.** Acquiring a consumable already at `max_stack` — the overflow policy (reject pickup / convert to Scrap / discard) is **owned by Inventory** (Not Started). The DB declares `max_stack`; this EC flags the boundary for the Inventory GDD. *Deferred to Inventory.*

## Dependencies

### Upstream (Consumable Database reads from these)

**None hard.** The Consumable Database is a standalone schema authority (like Part DB) — it is read-only at runtime and reads no other GDD. It *aligns with shared vocabulary it does not own*: the `rarity` enum (Part DB / Drop System), combat-resource semantics (Turn-Based Combat: Structure / Heat / Energy and their ranges), the drop formula (Drop System Formula 3 / DS-1), and the encounter formula (Encounter Zone EZ-1). It **declares** data those systems interpret; if any of that shared vocabulary changes, this GDD's effect model must be re-checked (soft/vocabulary coupling, not a runtime dependency).

### Downstream (these systems read from / realize this one)

| System | Direction | Interface | Status |
|--------|-----------|-----------|--------|
| **Turn-Based Combat** | → read by *(ERRATUM)* | `use item` action; applies CD-1/2/3 to a chosen living team Symbot; sets the per-battle Salvage Beacon flag | Approved |
| **Drop System** | → read by *(ERRATUM)* | consumables as a level/rarity-scaled drop channel; reads the Beacon flag to inject `beacon_multiplier` (CD-4) | Approved |
| **Encounter Zone** | → read by *(ERRATUM)* | EZ-1 `encounter_rate` modifier hook (CD-5); un-defers OQ-EZ-4 | Approved |
| **Inventory** *(Not Started)* | ↔ stored by | per-save quantities, stacking, `max_stack` | Not Started |
| **Overworld Navigation** *(Not Started)* | ← used by | decrements the encounter-modifier `steps_remaining` per step | Not Started |
| **NPC System / future Shop** *(Not Started)* | → read by | `buy_price` / `sell_price` for vendor buy/sell in Scrap (post-MVP) | Not Started |
| **Combat UI / World Map UI** *(Not Started)* | → read by | item menus, the battle target-picker, Beacon + encounter-modifier active indicators | Not Started |

### Errata obligations this GDD creates on Approved documents

Each errata'd doc needs a light re-review touch. Per the project's consistency-failure lesson (`docs/consistency-failures.md`), **the source GDD and the registry are updated together**, never one without the other.

1. **Turn-Based Combat** — add **use item** as a 4th action in Rule 3's action set (alongside move / switch / flee), taking a target arg (a living team Symbot, `Structure > 0`); it consumes the turn **only on a successful apply** (a rejected use is a pre-action gate and consumes no turn — CD Rule 3), generates no Heat, costs no Energy; applies `RESTORE_STRUCTURE / REDUCE_HEAT / RESTORE_ENERGY` (CD-1/2/3) to the target; sets the per-battle Salvage Beacon flag. **The item action resolves *within* the action phase — it gets NO carve-out ahead of the Rule 4 Overheat skip check, so a Symbot that starts its turn Overheated cannot Coolant-Flush out of it (CD-2 preventive-only note).** New AC. References the CD effect constants.
2. **Drop System** — add consumables as a **level/rarity-scaled drop output class**, a channel separate from the part loot pool; read the Beacon per-battle flag to inject `beacon_multiplier` into `effective_drop_rate` (CD-4, `clamp` [0,1]). New rule + AC. Consumable drop frequency owned here.
3. **Encounter Zone** — add the **EZ-1 `encounter_rate` modifier hook** (`effective_rate = clamp(base_rate × active_modifier, 0, 1)`, CD-5); Overworld Navigation counts down `duration_steps`. New rule/AC, and **OQ-EZ-4 → RESOLVED** (repel/lure consumables are now designed).

*(Enemy Database needs no change — the global level/rarity drop table means there are no per-enemy consumable pools.)*

### Bidirectionality

- **Turn-Based Combat, Drop System, Encounter Zone** each now list Consumable Database as an upstream dependency — **errata APPLIED 2026-07-12** (TBC Upstream table + Rule 7a; Drop Upstream/Interactions + Rule 12; Encounter Zone Upstream + EZ-1 hook). Bidirectionality confirmed in all three.
- **Inventory, Overworld Navigation, NPC System / Shop, Combat UI, World Map UI** (all Not Started) must list Consumable Database when authored.

## Tuning Knobs

### Effect magnitudes

| Knob | Value | Safe Range | What Changing It Does |
|------|-------|------------|----------------------|
| `WELD_PATCH_AMOUNT` | 25 | 15–35 | Common heal — meaningful for a glass cannon (42% of a 60 pool), modest for a tank |
| `REPAIR_KIT_AMOUNT` | 50 | 40–70 | Standard heal — keep **> 30** (the REPAIR move's absolute ceiling) so the item + turn cost is earned |
| `FIELD_FORGE_AMOUNT` | 120 | 90–160 | Prototype emergency heal (≈ four REPAIR casts in one action) |
| `COOLANT_FLUSH_AMOUNT` | 50 | 40–70 | Keep **< 100** — a full wipe deletes Heat-management tension; **≥ 40** for genuine near-Overheat margin |
| `POWER_CELL_AMOUNT` | 25 | 15–40 | ≈ 2 moves' worth (regen 10/turn); keep **< 50** or it becomes a full energy reset on an 80-cap pool |
| `BEACON_MULTIPLIER` | 2.0 | 1.5–2.5 | Drop-rate boost. **≥ 3.0 = degenerate** — the Beacon self-replenishes at RARE base (0.25 × 3.0 = 0.75) and the farm-Beacons-to-farm loop breaks |
| `JAMMER_RATE_MULTIPLIER` | 0.1 | 0.05–0.2 | Repel strength. Keep **> 0** — 0.0 is a total blackout that trivializes zone tension |
| `JAMMER_DURATION_STEPS` | 20 | 15–30 | How long a repel lasts (~one mid-zone traversal) |
| `LURE_RATE_MULTIPLIER` | 2.5 | 2.0–3.0 | Lure strength. At **≥ 3.0** a DENSE zone (0.35) clamps to ~every-step forced combat |
| `LURE_DURATION_STEPS` | 15 | 10–20 | Length of a lure farming burst |

### Buy / sell prices (Scrap; reserved for post-MVP shops — inert in MVP)

`buy_price > sell_price` **strictly, for every entry** (Rule 8 invariant — BLOCKING, AC).

| Item | Rarity | `buy_price` | `sell_price` | Spread |
|------|--------|-------------|--------------|--------|
| Weld Patch | COMMON | 12 | 2 | 6× |
| Coolant Flush | COMMON | 12 | 2 | 6× |
| Power Cell | COMMON | 12 | 2 | 6× |
| Scrap Lure | COMMON | 15 | 3 | 5× |
| Repair Kit | RARE | 36 | 8 | 4.5× |
| Signal Jammer | RARE | 45 | 10 | 4.5× |
| Salvage Beacon | RARE | 48 | 10 | 4.8× |
| Field Forge | PROTOTYPE | 75 | 15 | 5× |

Anchored to part-scrap yields (Common 5 / Rare 20 / Prototype 35): each consumable's `sell_price` sits *below* the same-rarity part yield (a single-use utility is less extractable than a raw part). Utility items (Beacon, Jammer, Lure) price above restoratives of the same rarity — proactive, build-shaping power.

### Stack caps

| `max_stack` | Value | Note |
|-------------|-------|------|
| Common | 20 | The primary post-MVP surplus-sell lever — a physical bound on hoarding |
| Rare | 10 | |
| Prototype | 5 | Field Forge — scarce emergency item |

### Knob interaction warnings

1. **`buy_price > sell_price` strictly, every entry** — a vendor must always buy back for less than it sells, or buy/sell becomes an arbitrage faucet. BLOCKING content check (AC).
2. **`BEACON_MULTIPLIER ≥ 3.0` breaks the economy** — self-replenishment ≥ 0.75 (farm-Beacons-to-farm-Beacons). Stay in 1.5–2.5; the authored 2.0 drains Beacons ~2:1.
3. **Post-MVP sell-faucet ceiling** — keep maximum plausible surplus-sell income **below ~20% of the arc part-faucet (~368 Scrap)**. Primary levers, in order of impact: Common `sell_price`, `max_stack` caps, Rare `sell_price`. If playtest shows Common consumable surplus flooding Scrap, pull Common `sell_price` first.
4. **`LURE_RATE_MULTIPLIER` × `density_class` coupling** — the Lure's felt strength depends on the zone's base rate; at DENSE (0.35) a multiplier ≥ 3.0 clamps to near-every-step. Tune the Lure against the zone's densest farming terrain, not SPARSE.

**Owned elsewhere — referenced, not duplicated:** the combat resources these restore (TBC: Structure/Heat/Energy); the drop rates the Beacon multiplies (Drop System); the encounter rates the modifiers scale (Encounter Zone); Scrap yields and the economy target (Drop System / HOLISM-01); inventory stacking storage (Inventory).

## Visual/Audio Requirements

> **Ownership note**: The Consumable Database is a data-schema layer — it owns no assets. The requirements below are obligations on the presentation systems (Combat UI, World Map UI, Audio System) and the Art Bible.

**VA-1 — Use-effect feedback (binding).** Each `effect_type` needs a clear feedback beat when used: `RESTORE_STRUCTURE` = a weld/nanite heal flash on the target Symbot; `REDUCE_HEAT` = venting steam / cooldown shimmer; `RESTORE_ENERGY` = a charge-up pulse; `BOOST_DROP` (Salvage Beacon) = a targeting "ping" that reads as *this fight matters*; `MODIFY_ENCOUNTER_RATE` = an overworld status pulse (repel vs lure visually distinct). *(Combat UI / Audio System / Art Bible.)*

**VA-2 — Rarity readability.** Consumable icons must read rarity at a glance, sharing the rarity color language used for parts (COMMON / RARE / PROTOTYPE). *(Art Bible.)*

**VA-3 — Active-modifier indicator.** A Beacon-active state reads in battle; a Signal Jammer / Scrap Lure active state **and its remaining steps** read in the overworld. *(Combat UI / World Map UI.)*

**Audio intent:** a distinct use-sound per effect family (heal / vent / charge / ping / field-modifier), plus a soft "rejected / no-effect" cue for the EC-CD-01/02/03 rejections so a blocked tap does not feel like a bug. *(Audio System.)*

> **📌 Asset Spec** — after the Art Bible is approved, run `/asset-spec system:consumable-database` to produce per-item icon specs and use-effect VFX descriptions from this section.

## UI Requirements

Obligations on Combat UI, World Map UI, and Inventory UI (all Not Started) — layout and interaction belong to those GDDs.

1. **Item menu** (battle + overworld): list consumables usable *in the current context* with name / icon / quantity; grey out wrong-context items (a `WORLD`-only item is not selectable in battle, and vice-versa — EC-CD-03).
2. **Battle target-picker**: for `RESTORE_*` items the player picks a **living team Symbot**, and the picker must show each Symbot's current/max resource so the choice is informed; **downed Symbots are not selectable** (EC-CD-02).
3. **Rejection feedback**: EC-CD-01…05 rejections need clear, non-punishing messages — "already full", "can't revive a downed Symbot", "can't use here", "none left", "beacon already active" — so a rejected tap reads as a rule, not a bug.
4. **Active-effect indicators**: a Beacon-active marker in battle; an encounter-modifier marker **with steps-remaining** in the overworld (mirrors VA-3).
5. **Shop UI** *(post-MVP)*: buy/sell in Scrap against `buy_price`/`sell_price`; deferred with shops (NPC System #23 / a future Shop system).

> **📌 UX Flag — Consumable Database**: this system places item-menu, target-picker, and active-effect-indicator requirements on the UI. In Pre-Production, run `/ux-design` for the consumable menu + battle target-picker + overworld effect indicators **before** writing epics; stories should cite the resulting `design/ux/` spec, not this GDD directly.

## Acceptance Criteria

**Tags:** **BLOCKING** (automated unit/content test — gates story completion) · **ADVISORY** (content-validation linter) · **DEFERRED** (needs a Not-Started system or a pending erratum; write the stub now). **Test types:** Unit (GUT, injected seeded RNG + stub TBC/Drop/Inventory, no live scene) · Content Validation (offline data linter) · Integration (≥2 systems wired).

**Implementation constraints:** (1) Any RNG is **injected**, never global `randf()`/`randi()`. (2) **IEEE-754 note:** the rate fixtures below deliberately use density base `0.15` (and DENSE `0.35`) because `0.15×0.1`, `0.15×2.5`, `0.35×2.5` are *exact* in doubles; `0.35×0.1` and `0.07×2.5` are NOT exact — do not use them for `==` assertions without `is_equal_approx`. (3) The Salvage Beacon assertions read `beacon_used_this_battle` / `beacon_drop_multiplier_applied` (Rule 5 observable contract). (4) In CD-4, `Π(cond_mults)` is the Drop System's existing drop-condition product (owned there); unit fixtures isolate the Beacon factor with `cond_mults=[]` (= 1.0), and the full product is exercised by AC-CD-21.

### Effect formulas (CD-1…CD-5)

**AC-CD-01** (BLOCKING, Unit): CD-1 RESTORE_STRUCTURE applies + caps. **A:** Weld Patch (25), `max_structure=60`, `current=50` → `current == 60` (clamped, not 75). **B:** Repair Kit (50), `max_structure=594`, `current=30` → `current == 80` (no clamp). Discriminator: an impl omitting `min()` returns 75 in A; both cases required so a wrong-formula-but-correct-clamp can't pass.

**AC-CD-02** (BLOCKING, Unit): CD-2 REDUCE_HEAT applies + floors at 0. **A:** Coolant Flush (50), `current_heat=30` → `0` (floored, not −20). **B:** `current_heat=80` → `30`. Discriminator: an impl omitting `max(0,…)` returns −20 in A.

**AC-CD-03** (BLOCKING, Unit): CD-3 RESTORE_ENERGY applies + caps. **A:** Power Cell (25), `max_energy=100`, `current=90` → `100` (clamped, not 115). **B:** `max_energy=80`, `current=50` → `75`. Discriminator: an impl omitting `min()` returns 115 in A.

**AC-CD-04** (BLOCKING, Unit): CD-4 BOOST_DROP injects + clamps. Beacon `multiplier=2.0`, `cond_mults=[]`. **A:** `base_rate=0.25` (Rare) → `effective == 0.5` (exact). **B:** `base_rate=0.70` (Common) → `effective == 1.0` (clamped from 1.40). Discriminator: an impl omitting `clamp` returns 1.4 in B; an impl treating empty product as 0.0 returns 0.0 in A.

**AC-CD-09** (BLOCKING, Unit): CD-5 Signal Jammer. Jammer (0.1, 20 steps), `base_encounter_rate=0.15` → `effective == 0.015` (exact), `steps_remaining == 20`; after 3 `on_overworld_step` → `steps_remaining == 17`. Discriminator: an impl using 0.5 returns 0.075; a non-decrementing impl leaves 20.

**AC-CD-10** (BLOCKING, Unit): CD-5 Scrap Lure. Lure (2.5, 15 steps). **A:** `base=0.15` → `effective == 0.375` (exact, no clamp). **B:** `base=0.35` (DENSE) → `effective == 0.875` (exact, NOT clamped to 1.0). Discriminator: a `3.0×` impl gives `0.35×3.0 = 1.05 → 1.0` in B (≠ 0.875).

### Use validation / rejections (EC-CD-01…07)

**AC-CD-05** (BLOCKING, Unit): EC-CD-01 zero-net-effect rejected, not consumed; partial allowed. **A:** Weld Patch, `current==max==594`, `qty=1` → `USE_REJECTED`, structure 594, `qty==1`. **B:** Coolant Flush, `heat=0`, `qty=1` → `USE_REJECTED`, `qty==1`. **C:** Weld Patch, `max=594`, `current=580` (heals 14) → `USE_OK`, `current==594`, `qty==0`. Discriminator: always-consume impl drops qty in A/B; reject-any-clamped-heal impl rejects C.

**AC-CD-06** (BLOCKING, Unit): EC-CD-02 downed target rejected. Repair Kit, target `structure=0`, `qty=1` → `USE_REJECTED`, structure 0, `qty==1`. (Positive path in AC-CD-24.)

**AC-CD-07** (BLOCKING, Unit): EC-CD-03 wrong context rejected. **A:** Beacon (`BATTLE`) in world context → `USE_REJECTED`, `qty==1`. **B:** Jammer (`WORLD`) in battle → `USE_REJECTED`. **C:** Weld Patch (`BOTH`) in battle w/ valid target → `USE_OK`. Discriminator: a context-ignoring impl returns `USE_OK` in A/B; an always-reject-BATTLE impl fails C.

**AC-CD-08** (BLOCKING, Unit): EC-CD-04 quantity 0 rejected. **A:** `qty=0`, valid target/context → `USE_REJECTED`, `qty==0` (no underflow to −1). **B:** `qty=1` → `USE_OK`, `qty==0`. Discriminator: a negative-allowing impl sets `qty=−1` in A.

**AC-CD-11** (BLOCKING, Unit): EC-CD-05 second Beacon rejected. **A:** `beacon_used_this_battle=true`, second Beacon `qty=1` → `USE_REJECTED`, `qty==1`, flag still true. **B:** fresh battle `beacon_used_this_battle=false` → `USE_OK`, flag true, `qty==0`. Discriminator: a stacking impl consumes the second (qty→0) in A.

**AC-CD-12** (BLOCKING, Unit): EC-CD-07 Beacon spent on flee/loss, never refunded. Setup: the Beacon was consumed on use this battle (`beacon_qty` went 1 → 0). **A:** `beacon_used_this_battle=true`, `on_battle_end(FLEE)` → `beacon_drop_multiplier_applied==false`, flag cleared, **and `beacon_qty == 0` (spent, NOT refunded on flee)**. **B:** `on_battle_end(WIN)` → `beacon_drop_multiplier_applied==true`, `beacon_qty == 0`. Discriminator: an outcome-ignoring impl applies the multiplier in A; a **flee-refund impl restores `beacon_qty` to 1 in A** (the qty assertion is the sole catch for this economy bug).

### Encounter modifier state (EC-CD-06/08)

**AC-CD-13** (BLOCKING, Unit): EC-CD-06 second modifier replaces. Active Jammer (`steps_remaining=5`), use Scrap Lure (`base=0.35`) → `modifier_type==LURE`, `steps_remaining==15`, `effective==0.875` (exact), Lure `qty==0`, old Jammer gone. Discriminator: a stacking impl gives `0.35×0.1×2.5 = 0.0875`; a retain-old impl leaves JAMMER/5.

**AC-CD-14** (BLOCKING, Unit): EC-CD-08 countdown advances on overworld steps only. **Unit under test: `EncounterModifierState`** — the `(rate_multiplier, steps_remaining)` counter owned by the overworld/traversal context (States and Transitions). Its **sole mutator is `on_overworld_step()`** (decrement, expire at 0); it exposes **no** battle-turn handler, so the "frozen in battle" property is *structural* (battle turns never call it) and is asserted by construction. **A:** Jammer `steps=20`; 3× `on_overworld_step()` → `steps_remaining==17`; (a battle occurs — zero calls to the counter) ; 1× `on_overworld_step()` → `steps_remaining==16`. **B:** 8× `on_overworld_step()` from 20 → `12`. **No-crash:** querying `steps_remaining` / `effective_rate` with no active modifier returns the inert default and raises nothing. Discriminator: a per-step-off-by-one impl gives 17 in A step-2 or 13 in B; the *live* battle-freeze (that battle turns genuinely issue no step to this counter) is the integration concern of AC-CD-22 (DEFERRED).

### Content validation (EC-CD-09/10/11)

**AC-CD-15** (BLOCKING, Content-Val): EC-CD-09 malformed `effect_params`. **A:** RESTORE_STRUCTURE with `{}` (no `amount`) → error naming `consumable_id` + missing key `amount`, entry unusable. **B:** REDUCE_HEAT with `{"amount":"fifty"}` (wrong type) → error naming id + key. Discriminator: a generic-error impl fails the naming check; a silent-skip impl emits nothing.

**AC-CD-16** (BLOCKING, Content-Val): EC-CD-10 `buy_price ≤ sell_price`. **A:** `buy=10, sell=10` (equal) → error. **B:** `buy=9, sell=10` → error. **C:** `buy=11, sell=10` → no error. Discriminator: a `<`-only impl passes the `buy==sell` case A silently — the equal case is the canonical discriminator for the strict invariant.

**AC-CD-17** (BLOCKING, Content-Val): EC-CD-11 unknown `effect_type`. **A:** `"GRANT_XP"` → error naming id + type, unusable, runtime never applies it. **B:** `"RESTORE_STRUCTURE"` → no error. Discriminator: a permissive check passes A; an over-strict check rejects B.

### Roster (Content Validation)

**AC-CD-18** (ADVISORY, Content-Val): MVP roster. Exactly **8 entries** (7/9 → error); the 6 effect concepts present; **no `BOSS_GRADE`**; all `buy>sell`; all `effect_params` well-formed per type. Discriminator: count 7 or a BOSS_GRADE entry fails.

**AC-CD-19** (ADVISORY, Content-Val): use_context + target coherence. Beacon `BATTLE`/`CURRENT_BATTLE`; Jammer & Lure `WORLD`/`OVERWORLD`; the 5 restoratives `BOTH`/`LIVING_TEAM_MEMBER`. No `BATTLE`-item with `target=OVERWORLD`; no `WORLD`-item with `target=LIVING_TEAM_MEMBER`. Discriminator: a Jammer set to `BATTLE` fails; incoherent pairings catch copy-paste errors.

### Targeting positive path

**AC-CD-24** (BLOCKING, Unit): valid living target accepted (affirmative path — closes the gap AC-CD-06 leaves). Repair Kit; `is_valid_target` for `structure ∈ {1, 45, 594}` → all `true`; `structure=0` → `false`. Discriminator: a reject-all impl fails `structure=1`; a `structure>=5` threshold fails the boundary `structure=1`.

### Turn economics (Rule 3)

**AC-CD-25** (BLOCKING, Unit): Rule 3 — a BATTLE consumable use emits **no Heat and no Energy cost**. Using Weld Patch (or any `RESTORE_*`) against a stub battle context with a living target and a successful apply → after resolve, `heat_generated == 0` **AND** `energy_consumed == 0` (the use pathway never invokes the move Heat-gain / Energy-cost hooks). Discriminator: an impl that routes item-use through the move damage/cost pipeline reports a non-zero Heat or Energy delta. (Turn *consumption* is integration-level — AC-CD-20, DEFERRED; this AC isolates the resource-neutrality contract testable now with a stub.)

### Deferred integration (activate when the erratum / Not-Started system lands)

**AC-CD-20** (DEFERRED, Integration): TBC use-item action — 4th action slot; Weld Patch on a living target → `+25` structure (clamped), **turn consumed**, no Heat, no Energy, `qty−1`. Discriminator: a no-turn-consume impl lets the actor act again; a Heat-generating impl shows a Heat delta. *Activate when the TBC erratum lands.*

**AC-CD-21** (DEFERRED, Integration): Drop System consumable channel + Beacon end-to-end — battle WIN with Beacon, Rare enemy `base=0.25`, seeded RNG → effective 0.50 applied (not 0.25), `beacon_drop_multiplier_applied` set, Beacon `qty−1`. *Activate when the Drop System erratum lands.*

**AC-CD-22** (DEFERRED, Integration): Encounter Zone hook + Overworld step countdown — Jammer active (`steps=20`), 5 steps → `steps_remaining==15`, each step's trigger used the modified rate, no crash at expiry. *Activate when the Encounter Zone erratum + Overworld Navigation land.*

**AC-CD-23** (DEFERRED, Integration): Inventory stacking / `max_stack` overflow (EC-CD-12) — Weld Patch `max_stack=5`, slot at 5, `add_item` → overflow handled per Inventory spec (reject `INVENTORY_FULL` or new slot). *Activate when the Inventory GDD defines the stack model.*

### Coverage

Every core rule and formula (CD-1…5) and every edge case (EC-CD-01…12) has a verifying AC: CD-1→01, CD-2→02, CD-3→03, CD-4→04, CD-5→09/10; EC-01→05, EC-02→06/24, EC-03→07, EC-04→08, EC-05→11, EC-06→13, EC-07→12, EC-08→14, EC-09→15, EC-10→16, EC-11→17, EC-12→23(DEFERRED); roster→18/19; Rule 3 turn-economics→25 (unit: no-Heat/no-Energy) + 20 (integration: turn-consume, DEFERRED); TBC/Drop/EZ integration→20/21/22. **25 ACs: 19 BLOCKING (16 Unit + 3 Content-Validation) / 2 ADVISORY (Content-Validation) / 4 DEFERRED (Integration).** Unit/content-testable now with stubs + injected RNG: AC-CD-01–19, 24, 25. DEFERRED (await erratum / Not-Started): 20–23. No untestable ("feels-good") criteria.

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-CD-1 | **Shop vendor economy (post-MVP).** `buy_price`/`sell_price` are authored but inert — the vendor UI, buy/sell flow, and live sell-faucet monitoring belong to the NPC System (#23) / a future Shop system. The 20%-of-arc-faucet sell ceiling (Tuning Knob warning 3) must be validated when shops ship. | NPC System / Economy | None in MVP; gates the shop feature |
| OQ-CD-2 | **Consumable drop frequencies on the global level/rarity table.** How often consumables drop (and how enemy level/rarity scales it) is the Drop System erratum's to set — it feeds the sell-faucet model and how quickly the player accrues Beacons. | Drop System (erratum) | Balances the whole layer; set with the erratum |
| OQ-CD-3 | **Beacon × pity interaction.** A Beacon-boosted *non-guaranteed* drop should reset/advance pity counters normally; a pity-*guaranteed* drop ignores the Beacon (already 100%). Confirm the exact ordering when the Drop System erratum lands. | Drop System | Correctness of the drop/pity interface |
| OQ-CD-4 | **Encounter-modifier save/reload persistence.** Whether an active Jammer/Lure survives a save/reload (or is discarded, per EC-CD-08) is Overworld Navigation / Save-Load's call. | Overworld Nav / Save-Load | Minor QoL; deferred (AC-CD-22) |
| OQ-CD-5 | **`max_stack` final values + overflow policy.** Proposed C20 / R10 / P5; the actual caps and the overflow behavior (reject / convert / discard, EC-CD-12) are coupled to the Inventory model. | Inventory GDD | Surplus-sell lever; set with Inventory |
| OQ-CD-6 | **Stretch consumables (reserved).** Overclock Chip (temp buff) and Emergency Reboot (revive) are unauthored; **Reboot especially reshapes the deliberately low-stakes loss design** — needs a design pass before it enters scope. | game-designer | Post-MVP; loss-stakes risk |
| OQ-CD-7 | **In-battle item stalling (playtest watch).** Each item-use costs a turn and enemies escalate (Part-Break enrage), so stall-with-consumables should be self-limiting — confirm at playtest that Repair/Coolant looping can't trivialize fights. | Playtest / balance | Balance watch, not a blocker |
