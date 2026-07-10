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

Assembly does not define new formulas — the underlying math belongs to the Part Database. This section specifies the **execution pipeline** Assembly runs, references the owning formulas, and documents the stat delta derivation.

---

### SA-F1 — Stat Derivation Pipeline (execution specification)

Assembly is the sole executor of the Part Database Formula 1 / 2 / 2b pipeline. The pipeline runs synchronously after every equip event.

**Step 1 — Per-part, per-stat upgrade scaling**

For each of the 8 equipped parts, for each stat key `S` present in `stat_bonuses`:
- If `base_stat[S] > 0`: compute `upgraded_value[S]` via **Part DB Formula 2**: `floor(base_stat[S] × upgrade_multiplier[tier] + 0.0001)`
- If `base_stat[S] < 0` (Prototype drawback): compute `upgraded_value[S]` via **Part DB Formula 2b**: `−ceil(abs(base_stat[S]) × max(0, 1.0 − tier × (1.0/3.0)) − 0.0001)`
- If `base_stat[S] = 0`: `upgraded_value[S] = 0`
- If `S` is not in the canonical 11-stat list: log a content warning and skip (see EC-SA-05)

**Step 2 — Sum across all 8 parts**

For each stat key `S`: `sum[S] = ∑ upgraded_value[S]` across all 8 equipped parts. Stats not present in any part's `stat_bonuses` sum to 0.

**Step 3 — Apply chassis archetype modifier**

Read `chassis_archetype` from the equipped `CHASSIS` part. For each stat `S`:
```
modified[S] = sum[S] × chassis_modifier.get(S, 1.0)
```
where `chassis_modifier` is the lookup table from Part DB Rule 3. Stats not listed in that table use `×1.0` exactly — this is the designed behavior, not a fallback for missing data. Every archetype that does not modify a stat leaves it at its raw summed value.

**Step 4 — Floor, clamp, and store (Part DB Formula 1)**

For each stat `S`:
```
final_stat[S] = max(0, floor(modified[S] + 0.0001))
```

Store the full `final_stat` dictionary and emit `stats_changed(final_stat)`.

**Output ranges** (inherited from Part DB Formula 1):

| Stat | Practical MVP range | Notes |
|------|-------------------|-------|
| `structure` | 60–594 | Low: all-Common Light Frame; high: all-Boss-grade Heavy Frame at +5 |
| `physical_power` / `energy_power` | 0–110 per contributing slot | Weapon/Arms max at +5; zero if no parts contribute |
| `armor` / `resistance` | 0–132 | Boss-grade Chassis at +5 with ×1.20 modifier |
| `mobility` | 0–96 | Light Frame ×1.20 upper bound |
| `energy_capacity` | 80–120 | Design target range (Part DB Rule 4) |
| `recharge` | 0–30 | At most 2 contributing parts × 15 each (Part DB Rule 4) |

---

### SA-F2 — Stat Delta (Workshop UI)

When the Workshop UI previews a proposed part swap, Assembly computes a hypothetical `final_stat` with the candidate part installed and the current slot occupant displaced. The stat delta is:

```
delta[S] = hypothetical_final_stat[S] − current_final_stat[S]
```

for all 11 stat keys `S`.

**Critical: this is a full hypothetical recompute, not a partial diff.** The candidate part is installed into its slot; the current occupant is removed; all 8 parts run through the full SA-F1 pipeline. This matters especially for **Chassis swaps**: changing the `chassis_archetype` re-applies the modifier table across all 11 stats simultaneously, so the delta can be non-zero for stats the new Chassis part contributes nothing to.

The hypothetical build is computed in memory only — no equip event fires, no signal emits, and Inventory is not modified until the player confirms the swap.

**Synergy exclusion**: `hypothetical_final_stat` uses Assembly base stats only (Rule 8). Synergy bonuses are not included. Workshop UI must not read a Synergy-inclusive total when computing delta — the delta would be incorrect when a swap crosses a synergy threshold.

## Edge Cases

### EC-SA-01 — Equipping a part to an incorrect slot type
**If** `P.slot_type ≠ target_slot_type` when `equip_part()` is called: **reject** the call and return an error. No state changes. No displacement occurs. The Workshop UI prevents this at the UI layer; this is a defensive guard for direct API calls.

### EC-SA-02 — Equipping the same part instance already in the slot
**If** the player attempts to equip a part whose `part_id` is identical to the currently equipped part in the target slot: **no-op**. No displacement, no recompute, no signal emission.

### EC-SA-03 — All-Common build with empty Move 4
**If** the `ARMS` slot is occupied by a Common part (`active_skill_id == null`): Move 4 is `null`. Assembly exposes `null` for Move 4 in the active move pool. Turn-Based Combat displays Move 4 as unavailable ("—"). The Basic Attack (Move 1) remains available. This is a valid build state.

### EC-SA-04 — Missing Move Database entry
**If** a part's `active_skill_id` is non-null but the referenced Move Database entry does not exist at runtime (content authoring error): log a content error, expose `null` for that move slot. Turn-Based Combat handles `null` as unavailable. Assembly does not crash. The same rule applies to `passive_id` referencing a missing Passive Database entry.

### EC-SA-05 — Unknown stat key in `stat_bonuses`
**If** a part's `stat_bonuses` dictionary contains a key not in the canonical 11-stat list: log a content warning and skip that key. All other stats compute normally. Assembly does not crash. This is Part DB EC-08 applied at the Assembly execution layer.

### EC-SA-06 — Recharge sum exceeds 30
**If** the assembled `sum["recharge"]` exceeds 30 after SA-F1 Step 2 (only possible if Part DB authoring rules are violated — more than 2 parts contribute non-zero `recharge`): log a content error. The formula does not clamp at this step; F1's floor and max(0,...) still apply. The resulting `final_stat["recharge"]` may be above 30. Must be caught by content validation (Part DB AC-18).

### EC-SA-07 — All-Prototype build with large drawbacks producing zero-floor stats
**If** the `sum[S]` for a given stat is negative after SA-F1 Step 2 (extreme Prototype drawback stacking): F1's `max(0, ...)` clamps the result to 0. The Workshop UI displays 0 (not a negative number). No crash, no special handling required.

### EC-SA-08 — New SymbotBuild creation with starter parts
**If** a new `SymbotBuild` is created: all 8 slots initialize with their respective starter Common parts and `final_stat` is computed immediately. The build is valid and functional from the first frame. Starter parts have `drop_enabled = false` in the Part Database — this does not affect their usability.

### EC-SA-09 — Chassis swap stat delta
**If** the player previews swapping the `CHASSIS` part: the stat delta (SA-F2) may be non-zero for all 11 stats because the chassis archetype modifier is re-applied across the full pipeline. The Workshop UI must display all 11 stat changes, not just stats the new Chassis part contributes to via `stat_bonuses`.

### EC-SA-10 — No available replacement when displacing a slot
**If** the player attempts to displace a part with no replacement: this cannot happen under the proposed atomic equip mechanic (Rule 3 — the player must provide the incoming part). An implementation that exposes a separate "unequip-only" API must block it if no replacement is provided, preserving the no-empty-slot invariant.

## Dependencies

### Upstream Dependencies (what Assembly requires)

| System | What Assembly Reads | Status |
|--------|-------------------|--------|
| **Part Database** | `SympartData` definitions via `PartDatabase.get_part(id)` — slot types, `stat_bonuses`, `chassis_archetype`, `active_skill_id`, `passive_id`, upgrade tier multiplier table, `heat_generation`, `ammo_cost` | Approved ✓ |
| **Inventory System** | Provides parts available for equipping; receives displaced parts on swap | Not Started |
| **Move Database** | `active_skill_id` references must resolve to valid entries at runtime | Not Started (referenced in Part DB Rule 1; not yet in systems index as a standalone system) |
| **Passive Database** | `passive_id` references must resolve to valid entries at runtime | Not Started |

*Note: Move Database and Passive Database are referenced in Part DB Rule 1 but are not listed in systems-index.md as standalone systems. Assembly's EC-SA-04 handles missing entries gracefully, but both must be authored before Assembly can be fully validated (Part DB AC-13 is BLOCKED on these).*

---

### Downstream Dependents (what depends on Assembly)

| System | What It Reads from Assembly | Constraint |
|--------|---------------------------|------------|
| **Synergy System** | Equipped-parts list (all 8 `SympartData`) for synergy tag evaluation | Assembly must expose the full equipped-parts list, not just `final_stat`. Synergy reads tags, not computed stats. |
| **Turn-Based Combat** | `final_stat` (all 11 stats), active move pool (skill IDs for moves 2–4), passive pool, `max_structure`, `max_energy_capacity`, `heat_max` | Stat snapshot taken at battle start; locked for the duration. Assembly must not change during combat. |
| **Workshop System** | Triggers `equip_part()` and replacement swaps; reads `final_stat` for display | Workshop is the only system that calls `equip_part()`. All other systems are read-only consumers. |
| **Workshop UI** | `final_stat` for live display; SA-F2 stat delta for part comparison previews | Must not include Synergy bonuses in delta computation (Rule 8). |

---

### Bidirectionality Note

Part Database lists Assembly as a downstream dependent in its Dependencies section (confirmed). When Inventory, Move Database, Passive Database, Synergy, Turn-Based Combat, Workshop System, and Workshop UI GDDs are authored, each must list Assembly in their upstream dependencies.

## Tuning Knobs

Most tuning knobs for this system live in the Part Database (chassis archetype modifiers, upgrade tier multipliers, stat budgets). Assembly inherits and executes them; they are not redefined here.

| Knob | Current Value | Safe Range | What Changing It Does |
|------|--------------|------------|----------------------|
| `TEAM_ROSTER_CAP` | 3 | 2–4 | Number of Symbots in the active battle roster. Below 2 removes team strategy depth; above 4 overwhelms balance with ~20 MVP parts and dilutes per-Symbot build investment. Increasing past 3 is a post-MVP expansion. |
| `ACTIVE_MOVE_SLOTS` | 4 | 3–5 | Number of moves per Symbot in battle: Basic Attack + WEAPON + HEAD + ARMS. Reducing to 3 removes a slot; increasing to 5 requires a new contributing slot (e.g., CHIPSET active skill, post-MVP). |
| Upgrade tier multiplier table | Owned by Part Database | See Part DB Tuning Knobs | Not redefined here. |
| Chassis archetype modifiers | Owned by Part Database | See Part DB Tuning Knobs | Not redefined here. |

**All-Prototype zero-floor display note:** Builds with heavy Prototype drawbacks stacking on the same stat can produce `final_stat[S] = 0` via F1's clamp, even without a penalizing chassis modifier. Correct formula behavior — but counterintuitive. Workshop UI should indicate when a stat is clamped to 0 by drawback accumulation (not a tuning knob — carry into Workshop UI GDD).

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
