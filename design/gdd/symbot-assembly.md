# Symbot Assembly System

> **Status**: In Design
> **Author**: Luan + Claude Code (game-designer, systems-designer)
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 1 (Engineer, Don't Collect), Pillar 3 (Build Depth Over Content Breadth), Pillar 4 (Synergy Is the Endgame)

## Overview

The Symbot Assembly System is the runtime build state for every Symbot on the player's team. It owns three responsibilities: (1) **slot validation** — enforcing that each of the 8 part slots carries exactly one valid `SympartData` entry whose `slot_type` matches the slot, with no empty slots permitted; (2) **stat derivation** — executing the Formula 1 / 2 / 2b pipeline to compute all 11 `final_stat` values for a given build from the equipped parts' `stat_bonuses`, upgrade tiers, and the Chassis archetype modifier table; and (3) **build exposure** — providing the computed stat block, active skill pool, passive list, and combat resource maxima (max Structure, max Energy Capacity) to every downstream system that reads from it (Synergy, Turn-Based Combat, Workshop UI).

The Assembly System does not define what parts exist (Part Database's job), does not store which copies of parts the player owns (Inventory's job), and does not track runtime combat values such as current Structure or current Energy (Turn-Based Combat's job). It knows only what is *equipped* and what those parts *compute to*. Like the Part Database, it is read-only at combat start — stats are locked in when the fight begins and do not change mid-battle. Recomputation happens in the Workshop when the player swaps a part.

One Assembly instance exists per Symbot. The team roster — how many Symbots the player can field and how they are organized — is an open design decision resolved in Section C.

## Player Fantasy

The player never thinks "I am running the stat pipeline." They think: *"Wait — if I swap this Heavy Frame Chassis for the Ironclad one, my Structure goes up by 18 but I lose that Mobility bonus… but that's fine because my Weapon already has enough speed, and now I can slot the Ironclad Arms and get the 3-piece bonus."*

That is the fantasy the Assembly System exists to enable: **the workshop as a laboratory**. Every part swap is a live hypothesis test. The moment a player equips a new part and sees all 11 stats update immediately — that feedback loop is what makes the build feel real and owned. The stat numbers are not a secondary mechanic layered over "the real game." They are the creative medium. The Symbot you finish equipping is a statement about how you understand the game.

The Assembly System serves this fantasy in two layers:

**Direct (the workshop moment):** The player opens the Workshop after a hunt. They have a new Rare Arms part from the boss — a Kinetic type they've been targeting for three fights. They slot it in. The `final_stat` recomputes instantly. Physical Power jumps. The synergy tag count ticks from 2 to 3. They see the stat delta comparing the old build to the new one. They feel it: the build got sharper. This moment — the swap, the recompute, the delta — is the core of Pillar 1. No capture screen, no evolution cutscene. Just: you chose a part, you equipped it, your machine changed.

**Indirect (the combat payoff):** When the player enters combat and their Symbot's stats are exactly what they architected — the structure holding up under heavy hits because the Heavy Frame multiplied it correctly, the Physical Power delivering the damage the boss's Armor makes relevant — the Assembly System's accuracy becomes invisible. The fantasy is now "I built this." The infrastructure disappears into the experience.

The Assembly System's design test (Pillar 1): *"If swapping a part doesn't change at least one number the player cares about, the slot design needs redesigning."*

## Detailed Design

### Core Rules

**Rule 1 — The SymbotBuild**

Each Symbot the player builds is a `SymbotBuild` — a named record holding:
- A player-assigned display name
- An 8-slot part manifest: one `part_id` per slot type
- The computed `final_stat` dictionary (all 11 stats as integers)
- The derived active move pool and passive pool

The Assembly System manages `SymbotBuild` instances. It does not manage how many exist or which three are "active" — that is the Workshop System's responsibility. Assembly's scope is per-build computation and validation.

---

**Rule 2 — The 8-Slot Contract**

Every `SymbotBuild` has exactly 8 slots, one per slot type. No slot may be empty at any time:

| Slot | Active Skill | Passive | Notes |
|------|-------------|---------|-------|
| `CORE` | Never | Required at Rare+ | Identity slot; the Symbot's "element" and manufacturer affiliation |
| `CHASSIS` | Never | Never | Determines combat archetype via archetype modifier table |
| `CHIPSET` | Never in MVP | Never in MVP | Processing/status stats; skill reserved for post-MVP |
| `ENERGY_CELL` | Never | Never | Energy Capacity + Recharge; no skill or passive |
| `HEAD` | 1 scan or utility skill | Never | Targeting stats; skill available at all rarities |
| `ARMS` | 1 active skill | Never | Physical or Energy Power; skill available at Rare+ only |
| `LEGS` | Never | 1 passive (movement) | Mobility + Evasion (reserved); passive is always present |
| `WEAPON` | 1 primary combat skill | Never | Primary damage source; skill available at all rarities |

Every slot ships pre-equipped with a starter `COMMON` part when a new `SymbotBuild` is created. The starter parts are defined in content data and always exist in the Part Database with `drop_enabled = false` (they are given, not hunted).

---

**Rule 3 — Equip Mechanics**

When the player equips part `P` into slot `slot_type`:

1. **Validate**: `P.slot_type == slot_type`. If not, reject — mismatched slot types cannot be equipped.
2. **Displace**: The currently equipped part in `slot_type` is returned to the player's Inventory as a new instance at its current upgrade tier.
3. **Install**: `P` is removed from Inventory and installed into the slot.
4. **Recompute**: `final_stat` is recomputed eagerly (see Rule 6).
5. **Emit signals**: `part_equipped(slot_type, new_part_id)` and `stats_changed(final_stat)`.

Unequipping without a replacement is not permitted — slots must always be filled. To remove a part, the player equips a different part to the same slot.

---

**Rule 4 — The Active Move Pool**

Each `SymbotBuild` exposes exactly **4 moves** to Turn-Based Combat:

| Move slot | Source | Notes |
|-----------|--------|-------|
| Basic Attack | Universal — all Symbots always have one | 0 Energy cost, 0 Heat. Damage uses `final_stat["physical_power"]` or `final_stat["energy_power"]` depending on the equipped Weapon's `damage_type`. Defined in Turn-Based Combat GDD. |
| Move 2 | `WEAPON` part's `active_skill_id` | Primary combat skill. Always non-null (every Weapon at every rarity has a skill). |
| Move 3 | `HEAD` part's `active_skill_id` | Scan or utility. Always non-null (every Head at every rarity has a skill). |
| Move 4 | `ARMS` part's `active_skill_id` | Attack, repair, or utility. Non-null at Rare+ only; `null` if a Common Arms is equipped. When null, Combat shows Move 4 as unavailable ("—"). |

Move pool ordering (Move 2 → Move 3 → Move 4) is fixed. Turn-Based Combat displays all 4 slots; unavailable moves are grayed out. The Basic Attack is always available regardless of Energy or Heat.

---

**Rule 5 — The Passive Pool**

Assembly collects all non-null `passive_id` values from the 8 equipped parts and exposes them as an ordered list to Turn-Based Combat and the Synergy System. Order: CORE, LEGS, then all other slots in slot-type order. Common parts contribute no passive (always `null`). A build with all Common parts has an empty passive pool — this is valid and handled gracefully.

---

**Rule 6 — Stat Derivation Pipeline**

Assembly owns the complete Formula 1 / 2 / 2b computation. Triggered eagerly after every equip:

1. **Per part, per stat**: For each of the 8 equipped parts, for each key `S` in `stat_bonuses`:
   - If `base_stat[S] > 0` → apply Formula 2: `floor(base_stat[S] × upgrade_multiplier[tier] + 0.0001)`
   - If `base_stat[S] < 0` (Prototype drawback) → apply Formula 2b: `-ceil(abs(base_stat[S]) × max(0, 1.0 − tier × (1.0/3.0)) − 0.0001)`
   - If `base_stat[S] = 0` → 0
   - Unknown stat keys (not in the canonical 11): log a warning, skip — do not crash (Part DB EC-08).
2. **Sum per stat**: Sum all 8 parts' upgraded contributions for each stat key.
3. **Apply chassis modifier**: Read `chassis_archetype` from the equipped `CHASSIS` part. For each stat `S`: multiply sum by `chassis_modifier.get(S, 1.0)` (using the Part DB Formula 1 modifier table; unlisted stats use ×1.0).
4. **Floor and clamp**: `final_stat[S] = max(0, floor(sum[S] × chassis_modifier[S] + 0.0001))`.
5. **Store**: Replace the current `final_stat` dictionary with the newly computed values.
6. **Emit**: `stats_changed(final_stat)`.

The 11 canonical MVP stat keys: `structure`, `armor`, `resistance`, `physical_power`, `energy_power`, `mobility`, `targeting`, `processing`, `cooling`, `energy_capacity`, `recharge`.

---

**Rule 7 — Combat Resource Maxima**

Assembly exposes three maxima to Turn-Based Combat at battle start:

| Resource | Value | Source |
|----------|-------|--------|
| `max_structure` | `final_stat["structure"]` | Formula 1 output |
| `max_energy_capacity` | `final_stat["energy_capacity"]` | Formula 1 output |
| `heat_max` | 100 | Constant — not a stat; defined in Part DB Formula 5 |

Runtime current values (current Structure, current Energy, current Heat) are owned by Turn-Based Combat and are never stored in Assembly.

---

**Rule 8 — Synergy Interface**

Assembly exposes the equipped-parts list (all 8 `SympartData` references) to the Synergy System for tag evaluation. Assembly's `final_stat` output represents **base stats from parts only** — synergy bonuses are not included. The Synergy System computes its own bonus block separately; Turn-Based Combat and Workshop UI sum Assembly base stats + Synergy bonuses as needed.

This one-way dependency (Synergy reads from Assembly; Assembly does not call Synergy) prevents circular dependencies.

---

### States and Transitions

The `SymbotBuild` is a stateless data record with one runtime characteristic: its `final_stat` dictionary is either current (post-equip) or computing. Recomputation is synchronous — no async state needed in MVP.

The Workshop System (not Assembly) manages the distinction between "player is in workshop mode" and "player is in combat." Assembly computes `final_stat` whenever a swap occurs. It receives no swap events during combat because the Workshop System gates all equip calls.

---

### Interactions with Other Systems

| System | Reads from Assembly | Writes to Assembly / Triggers |
|--------|--------------------|-----------------------------|
| **Part Database** | Assembly reads `SympartData` via `PartDatabase.get_part(id)` | — |
| **Inventory System** | — | Provides parts for equipping; receives displaced parts on swap |
| **Synergy System** | Reads equipped-parts list (all 8 `SympartData`) for tag evaluation | — |
| **Turn-Based Combat** | Reads `final_stat`, active move pool (skill IDs for moves 2–4), passive pool, `max_structure`, `max_energy_capacity`, `heat_max` | — |
| **Workshop System** | Triggers `equip_part(symbot_build, slot, part_id)`; reads `final_stat` for stat display | Initiates all equip operations |
| **Workshop UI** | Reads `final_stat` for live display; reads stat delta between current build and proposed swap | — |

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
