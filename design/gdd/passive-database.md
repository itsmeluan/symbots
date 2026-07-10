# Passive Database

> **Status**: In Design — revised 2026-07-10 post-review (4 blocking gates addressed; awaiting fix-confirmation re-review)
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
> **Review**: First /design-review 2026-07-10 (game-designer, systems-designer, qa-lead, creative-director) — verdict NEEDS REVISION. Revisions applied: (1) `behavior_params` sub-schema added (Rule 3a) so STAT_AURA/RESOURCE_EFFECT/STRUCTURAL_EFFECT are implementable; `behavior_class` ratified as the resolution axis, `passive_class` demoted to pure metadata; Rule 4 stacking defaults re-keyed onto `behavior_class`. (2) `ON_WEAPON_HIT` trigger removed — collapsed into `ON_HIT` + `scope: WEAPON_ONLY` to match TBC Rule 13 exactly; `ON_TURN_START` added for TBC-enum parity; `PERSISTENT` clarified as an application mode. (3) AC-PDB-02 orphan fixture given a concrete trigger + observable + FAIL; AC-PDB-06 positive case added; AC-PDB-08 ordering observable named; AC count corrected. (4) OQ-PDB-1 reclassified as named critical-path dependency with a content charter. Added Rule 2a (ON_OVERHEAT ordering), Rule 3 legality matrix, EC-PDB-08 + AC-PDB-15/16/17, deferred AC-PDB-D1–D4.
> **Implements Pillar**: Pillar 3 (Build Depth Over Content Breadth), Pillar 4 (Synergy Is the Endgame)

## Overview

The Passive Database is the authoritative catalog of every passive effect a Symbot can carry into battle. Where the Move Database defines what a part *does* when its skill fires, the Passive Database defines what a part *is always doing* — the automatic, persistent behaviors that activate without the player choosing them. Each entry stores a passive's ID, display name, description, trigger category, scope constraints, and stacking policy. The catalog is static and read-only at runtime; it supplies the definitions that Part Database `passive_id` fields reference and that Turn-Based Combat's Rule 13 registry executes.

The Passive Database owns exactly one concern: defining what each passive ID *means* at the design level. It does not resolve passives (that belongs to TBC), does not store which passives are currently active on a combatant (runtime state, owned by TBC), and does not define synergy tier bonuses (owned by Synergy System). It is the shared vocabulary that makes the Part Database's `passive_id` references meaningful and keeps TBC's execution registry honest. Formally, this GDD ratifies the three MVP status-rider IDs that Turn-Based Combat seeded in its Rule 13 registry (`volt_shock_on_hit`, `thermal_burn_on_weapon`, `kinetic_stagger_on_hit`), establishes the passive entry schema, defines behavior categories and stacking rules, and provides the MVP content roster of passive entries.

## Player Fantasy

The Passive Database has no fantasy the player ever names. Its fantasy is *borrowed and enabling*, the same quiet relationship the Move Database has to "the move panel is the build speaking."

When a player builds a full Volt stack and watches their DAMAGE moves apply Shock automatically — even though they only pressed "Strike" — they aren't thinking about a passive catalog. They're thinking: *"My build does this on its own."* That moment of autonomous payoff — the build operating beyond its explicit instructions — is what passives exist to deliver. The player feels it as build depth, not as a system feature. A Core that passively heals on battle start, a Weapon that adds Stagger riders to every hit, a Prototype with a drawback-counterpart that makes the Symbot vent Heat when it deals a critical blow — each of these is a hypothesis the player assembled in the Workshop and is now watching validate itself in combat.

The Passive Database's role is upstream and quiet: it is the promise that when a `passive_id` resolves, something real and differentiated happens. Flatten passives into indistinct `on_hit: apply_something` stubs and the Part Database's Boss-grade and Prototype rarities lose their claim to identity. Give each passive a named, designed behavior and the workshop hypothesis has concrete weight.

This system's fantasy is delivered entirely through Turn-Based Combat (where passives fire) and the Workshop (where passive descriptions inform build decisions before battle). The Passive Database's job is to make those downstream moments possible.

## Detailed Design

### Core Rules

**Rule 1 — The Passive Entry Schema.** Every passive in the game is one catalog entry:

| Field | Type | Notes |
|-------|------|-------|
| `id` | StringName | Referenced by a part's `passive_id`, by Synergy tier `effects`, or by a Move DB `SKILL_ENHANCE` upgrade |
| `display_name` | String | Player-visible passive name in Workshop and battle log |
| `short_description` | String | 1–2 sentence description of what the passive does, written for players |
| `trigger_category` | Enum | When the passive fires (Rule 2) |
| `scope` | Enum | `ANY_DAMAGE` / `WEAPON_ONLY` — the move-slot filter for `ON_HIT` triggers; `null` for all non-`ON_HIT` triggers |
| `behavior_class` | Enum | What the passive does (Rule 3). **This is the authoritative resolution axis** — TBC's Rule 13 executor branches on `behavior_class`, not `passive_class`. |
| `behavior_params` | Dictionary | Typed per-`behavior_class` payload holding the numeric/target data the effect needs (Rule 3a). The one field whose keys vary by `behavior_class`. |
| `stacking_policy` | Enum | `UNIQUE`, `UNIQUE_PER_TRIGGER`, or `STACKABLE` (Rule 4) |
| `passive_class` | Enum | `STATUS_RIDER` / `CORE_TRAIT` / `UPGRADE_PASSIVE` — **pure authoring/display metadata. It does not change resolution and does not derive stacking policy** (Rule 4 defaults key on `behavior_class`). Consumed only by content-validation tooling (AC-PDB-12) and Workshop UI display. |

`heat_generation` and `energy_cost` are never on a passive — passives fire automatically and consume no player resources (they are not moves).

**Note on the two class fields:** `behavior_class` and `passive_class` share the token `STATUS_RIDER` but are different axes. `behavior_class` answers *what the effect does* (drives runtime resolution and `behavior_params` shape); `passive_class` answers *what authoring role the passive plays* (drives validation and UI only). When they appear to conflict (e.g., a `CORE_TRAIT` passive with a `STATUS_RIDER` behavior), `behavior_class` wins at runtime — `passive_class` never gates execution (EC-PDB-07).

---

**Rule 2 — Trigger Categories (MVP).** A passive fires when its trigger condition occurs on the combatant carrying it. **This enum mirrors TBC's Rule 13 trigger enum exactly** (`ON_HIT, ON_TURN_START, ON_OVERHEAT, ON_BATTLE_START`) — it is the shared vocabulary, not an independent spec. There is **no `ON_WEAPON_HIT` trigger**: weapon-slot narrowing is expressed by the `scope` field on an `ON_HIT` trigger, matching how TBC Rule 13 registers `thermal_burn_on_weapon` as "`ON_HIT` (WEAPON-slot moves)".

| `trigger_category` | When it fires |
|--------------------|--------------|
| `ON_HIT` | The carrying Symbot's DAMAGE move lands a hit (`hit_resolved` emitted by TBC). The `scope` field narrows this: `ANY_DAMAGE` fires on any DAMAGE move; `WEAPON_ONLY` fires only on WEAPON-slot DAMAGE moves. |
| `ON_TURN_START` | The start of the carrying Symbot's turn (TBC Rule 4 turn-start phase). No MVP content; listed for TBC-enum parity. |
| `ON_BATTLE_START` | Once per battle, during TBC's BATTLE_INIT phase before the first turn |
| `ON_OVERHEAT` | The carrying Symbot triggers Overheat — the Heat-reaches-100 transition (Part DB Formula 5). Fires **once on the transition**, not every turn spent in the OVERHEATED carry-in state. TBC fires the passive *before* applying the Overheat consequence (self-damage + skip); see Rule 2a. |
| `PERSISTENT` | **Not an event trigger — an application mode.** The effect applies once at BATTLE_INIT and stays active for the whole battle without re-firing. TBC implements it as a one-shot application at BATTLE_INIT with no teardown. `stacking_policy` for a `PERSISTENT` passive resolves at application time (BATTLE_INIT), not per-event. |

---

**Rule 2a — `ON_OVERHEAT` firing order (TBC contract).** When Heat reaches 100, TBC fires all `ON_OVERHEAT` passives **before** resolving the Overheat consequence (the 10%-max-structure self-damage and turn-skip of TBC Rule 4). A `RESOURCE_EFFECT` `ON_OVERHEAT` passive that vents Heat therefore fires *after* the Overheat has already triggered — it cannot retroactively cancel the self-damage or the skip. This is by design: `ON_OVERHEAT` is a "when the bad thing happens" hook, not a "prevent the bad thing" hook. Any change to this ordering requires a simultaneous TBC Rule 13 / Rule 4 update.

---

**Rule 3 — Behavior Classes (MVP).** The four behavior classes cover all MVP passive effects:

| `behavior_class` | What it does | Typical trigger |
|-----------------|-------------|----------------|
| `STATUS_RIDER` | Applies a status effect (Shock / Burn / Stagger) automatically | `ON_HIT` (with `scope`) |
| `STAT_AURA` | Modifies a combat stat for the entire battle (runtime only — Part DB `final_stat` unchanged) | `PERSISTENT` |
| `RESOURCE_EFFECT` | Modifies Heat or Energy immediately when triggered | `ON_BATTLE_START` or `ON_OVERHEAT` |
| `STRUCTURAL_EFFECT` | Modifies current or max Structure immediately when triggered | `ON_BATTLE_START` |

Additional behavior classes (`CONDITIONAL_BUFF`, `SPAWN_EFFECT`) are reserved for Vertical Slice+. A passive may not combine two behavior classes — one entry, one effect.

**Allowed trigger × behavior combinations (MVP).** A content author must pick a legal pairing; content validation (AC-PDB-15) rejects the rest. Illegal pairings are semantically incoherent (e.g., a `STATUS_RIDER` firing at `ON_BATTLE_START` would apply a status before any hit lands):

| `behavior_class` | Legal `trigger_category` values |
|-----------------|--------------------------------|
| `STATUS_RIDER` | `ON_HIT` only |
| `STAT_AURA` | `PERSISTENT` only |
| `RESOURCE_EFFECT` | `ON_BATTLE_START`, `ON_TURN_START`, `ON_OVERHEAT` |
| `STRUCTURAL_EFFECT` | `ON_BATTLE_START`, `ON_TURN_START`, `ON_OVERHEAT` |

---

**Rule 3a — `behavior_params` schema (per behavior class).** The `behavior_class` determines which keys `behavior_params` carries. This is the storage the resolution needs; TBC reads these keys to execute the effect. A validator (AC-PDB-16) checks the payload matches the class.

| `behavior_class` | `behavior_params` keys | Notes |
|-----------------|------------------------|-------|
| `STATUS_RIDER` | `{ status_id: Enum, duration: int }` | `status_id` ∈ {SHOCK, BURN, STAGGER}; `duration` in turns. Magnitude/potency is TBC's (TBC-F3/F4/F5) — this only names the status and its duration. |
| `STAT_AURA` | `{ stat: StringName, delta: int }` | `stat` is a `final_stat` key; `delta` is a flat authored integer within the stat's safe range (see Formulas). Applied via SYN-F4 clamp. |
| `RESOURCE_EFFECT` | `{ resource: Enum, amount: int }` | `resource` ∈ {HEAT, ENERGY}; `amount` is a signed authored integer, clamped by the resource cap (Heat 100 / Energy Capacity). |
| `STRUCTURAL_EFFECT` | `{ target: Enum, amount: int }` | `target` ∈ {CURRENT_STRUCTURE, MAX_STRUCTURE}; `amount` is a signed authored integer, clamped by the Structure floor (0) and ceiling (`max_structure`). Negative `amount` is a content authoring error (EC-PDB-08). |

The three MVP status riders (Rule 5) populate `behavior_params` as `{ status_id, duration }` — e.g., `volt_shock_on_hit` → `{ status_id: SHOCK, duration: 1 }`.

---

**Rule 4 — Stacking Policy.** When a Symbot carries the same passive ID from multiple sources (e.g., two equipped parts both reference `volt_shock_on_hit`, or a part passive and a synergy effect grant the same ID), the `stacking_policy` field governs how TBC handles it:

| `stacking_policy` | Behavior |
|------------------|----------|
| `UNIQUE` | Only one instance is ever active; a second source granting the same ID does nothing new. Best for `PERSISTENT` stat auras and `STRUCTURAL_EFFECT` passives where double-application would be unintentional. |
| `UNIQUE_PER_TRIGGER` | Multiple sources may exist, but the effect fires at most **once per trigger event** (once per hit, once per battle start). The instances de-duplicate at fire time. Best for `STATUS_RIDER` passives — prevents multi-Shock on a single hit from two sources of the same rider. |
| `STACKABLE` | Each source fires independently. Best for non-status `RESOURCE_EFFECT` passives where the intent is that deeper investment yields more payoff. |

**Default policies by `behavior_class`** (the resolution axis — not `passive_class`, which is metadata only):
- `STATUS_RIDER` → `UNIQUE_PER_TRIGGER` (prevents multi-Shock on a single hit from two sources of the same rider)
- `STAT_AURA` → `UNIQUE` (double-applying a persistent stat delta is unintended)
- `STRUCTURAL_EFFECT` → `UNIQUE` (double-application would be unintentional)
- `RESOURCE_EFFECT` → `STACKABLE` (deeper investment yields more payoff — the one class where multi-source stacking is the intent)

`stacking_policy` is authored per entry; these are the defaults a content author starts from. `passive_class` (STATUS_RIDER / CORE_TRAIT / UPGRADE_PASSIVE) does **not** influence stacking — a `CORE_TRAIT`-authored `STAT_AURA` gets `UNIQUE` from its `behavior_class`, and its one-instance guarantee is *additionally* reinforced by Part DB's one-Core-per-Symbot schema, but the policy derives from the behavior, not the authoring class.

---

**Rule 5 — Status Rider Passives (OQ-MDB-1 resolution, TBC Rule 13 ratification).** These three entries formally ratify the MVP status rider IDs seeded in TBC Rule 13. The Passive Database is the design-level source of truth; TBC Rule 13 is the runtime executor. Both documents must agree — any change to these entries requires updating TBC Rule 13 simultaneously.

| `id` | `trigger_category` | `scope` | `behavior_class` | `behavior_params` | Effect | `stacking_policy` |
|------|--------------------|---------|-----------------|-------------------|--------|------------------|
| `volt_shock_on_hit` | `ON_HIT` | `ANY_DAMAGE` | `STATUS_RIDER` | `{ SHOCK, 1 }` | Applies Shock for **1 turn** (shorter than the STATUS-move's 2 — the passive rider is a weaker, automatic application) | `UNIQUE_PER_TRIGGER` |
| `thermal_burn_on_weapon` | `ON_HIT` | `WEAPON_ONLY` | `STATUS_RIDER` | `{ BURN, 2 }` | Applies Burn for **2 turns** (full duration — Weapon attacks are the primary damage source; the Weapon rider is full-strength). Weapon-slot narrowing is the `scope` field, matching TBC Rule 13's "`ON_HIT` (WEAPON-slot moves)". | `UNIQUE_PER_TRIGGER` |
| `kinetic_stagger_on_hit` | `ON_HIT` | `ANY_DAMAGE` | `STATUS_RIDER` | `{ STAGGER, 1 }` | Applies Stagger for **1 turn** | `UNIQUE_PER_TRIGGER` |

All three register in TBC Rule 13 as `ON_HIT` triggers — vocabulary now matches TBC exactly (no `ON_WEAPON_HIT` divergence).

These IDs may be granted by: part `passive_id` fields (Weapon or Arms parts with a status-rider passive), Synergy tier `effects` arrays, or SKILL_ENHANCE upgrades (Move DB Rule 9). The stacking policy applies across all sources — even if a Synergy grants `volt_shock_on_hit` AND a part also has it as `passive_id`, Shock fires only once per hit.

---

**Rule 6 — Core Identity Passives (authoring doctrine).** Part DB Rule 2 describes the Core as "what makes a Symbot itself when all other parts are swapped." Rare+ Cores are required to carry a passive (Part DB Rule 8 Core exception). These Core passives must fulfill this identity promise:

**Rarity escalation doctrine (content authoring rule):**
- **Rare Core**: The passive is a useful, defined bonus that characterizes the Core's element and role. It may share a `behavior_class` with another Rare Core passive from a different manufacturer. It should make the player notice they're using this Core — a consistent, modest upside that fits the Symbot's identity.
- **Boss-grade Core**: The passive must be **mechanically distinct** from all other Boss-grade Core passives in MVP — different `trigger_category` or materially different `behavior_class`. It defines how this Symbot plays, not just what stats it has. Finding a Boss-grade Core should feel like unlocking a playstyle.
- **Prototype Core**: The passive must have a **risk or tension component** — it is powerful but conditional, double-edged, or creates a pressure the player must manage. A Prototype Core's passive is inseparable from its drawback stat; together they define a build constraint the player embraces.

**Content authoring constraints:**
1. No two Boss-grade or Prototype Core passives may share the same `trigger_category` and `behavior_class` combination — uniqueness at the mechanic level, not just the flavor level.
2. Core identity passives must use `ON_BATTLE_START`, `ON_OVERHEAT`, or `PERSISTENT` triggers — never `ON_HIT`. Status riders are the domain of Weapon/Arms parts and synergy effects; a Core passive adding a status rider would read as a Weapon passive on the wrong part.
3. Prototype Core passives must pair with a design note in the passive entry's `short_description` naming the expected player tradeoff (e.g., "gain X, at cost of Y").

*MVP content: specific Core passive IDs and behaviors are authored with the content plan (OQ-PDB-1). The schema and doctrine above govern their authoring.*

---

**Rule 7 — Upgrade-Granted Passives (SKILL_ENHANCE path).** Move DB Rule 9 defines `SKILL_ENHANCE` as a part upgrade effect that can "add a passive rider ID" at a specified tier. Any passive ID added via SKILL_ENHANCE must exist in this catalog before it can be authored in content. The Passive Database does not define *which parts* unlock which passives at which tiers (that is the part's `upgrade_effects` array, owned by Part DB / Move DB) — it defines what each passive ID means. A SKILL_ENHANCE that adds `volt_shock_on_hit` inherits that entry's trigger, scope, behavior class, `behavior_params`, and stacking policy without overriding them.

### States and Transitions

The Passive Database is a static data schema — passive definitions have no runtime state and no state machine. Which passives are currently active on a combatant, and whether a trigger has fired this turn, are runtime state owned by Turn-Based Combat.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** | ← referenced by | Parts' `passive_id` → passive `id`; Part DB Rule 8 requires Rare+ Cores and Boss-grade/Prototype parts to carry a non-null `passive_id`. Part DB EC-13 defers stacking behavior to this GDD (Rule 4). |
| **Turn-Based Combat** | → consumed by | Rule 13 registry maps every `id` to a runtime behavior. TBC executes; Passive DB defines the design contract. The two must agree on trigger, scope, and behavior for every entry. **Changes to any entry here require simultaneous update to TBC Rule 13.** |
| **Move Database** | ↔ sibling | `SKILL_ENHANCE` upgrades can add a `passive_id` to a move at a specified tier (Move DB Rule 9). Those IDs must exist in this catalog. Move DB OQ-MDB-1 (status rider passives must be authored here) is resolved by Rule 5 above. |
| **Synergy System** | ↔ namespace sibling | Synergy tier `effects` arrays emit StringName IDs through TBC Rule 13. IDs that appear in both a part `passive_id` AND a synergy `effects` array are cataloged here — Synergy is the owner of tier definitions; Passive DB is the owner of what the ID means. Pure synergy-only IDs that never appear on a part `passive_id` are **not** cataloged here (they remain TBC Rule 13 entries without a Passive DB entry). |
| **Workshop UI** | → displays | `display_name` and `short_description` for the passive shown on a part's tooltip; active passive indicators during the Workshop preview. |

## Formulas

The Passive Database owns no computational formulas. Passive entries are definitional — they name a behavior and its trigger; they do not compute values. All math triggered by passives is owned elsewhere:

- **Status effect potency** (Burn damage, Shock mobility penalty, Stagger reduction) — owned by Turn-Based Combat (TBC-F3, TBC-F4, TBC-F5). The Passive Database's status rider entries specify which status and its duration; the scaling formula is TBC's.
- **STAT_AURA numeric values** — the specific stat delta applied by a STAT_AURA passive is a per-entry authored value (an integer in the passive's catalog entry). There is no scaling formula; it is a flat authored number. **Content constraint:** STAT_AURA deltas must be integers and must be within the affected stat's safe range (per Part DB stat budget tables and the SA-F1 output ranges in the registry) — a runtime STAT_AURA that would push a stat above its practical ceiling is a content authoring error, not handled by a formula.
- **RESOURCE_EFFECT numeric values** — Heat or Energy amounts modified by a `RESOURCE_EFFECT` passive are per-entry authored integers, not derived from a formula. They do not scale with any stat. **Content constraint:** Heat amounts must respect the Heat cap (100, Part DB Formula 5); Energy amounts must respect Energy Capacity (Part DB Formula 6). Authored values should be modest enough that `ON_BATTLE_START` resource effects don't trivialize the opening turns.
- **STRUCTURAL_EFFECT numeric values** — same pattern: per-entry authored integers, clamped by TBC's Structure floor (0) and ceiling (current `max_structure` at the moment of trigger). **Content constraint:** a `STRUCTURAL_EFFECT` `amount` targeting `CURRENT_STRUCTURE` must be **non-negative** — unlike `STAT_AURA` (where a negative delta is a legitimate debuff), a negative structural amount means self-damage at trigger time, which no MVP passive should author. Content validation rejects negative `CURRENT_STRUCTURE` amounts (AC-PDB-16); at runtime the floor clamp prevents a crash but the effect is a design error (EC-PDB-08).

**Interaction with registry constants:** The 3 status rider passives (Rule 5) produce effects governed by TBC-F3 (Burn), TBC-F4 (Shock), and TBC-F5 (Stagger). Their output ranges are unchanged by Passive DB — the Passive Database only specifies that the effect fires; the magnitude is determined by the applier's `snapshotted_processing` stat at fire time per TBC's snapshot contract (pre-synergy, per TBC Rule 10).

## Edge Cases

**EC-PDB-01 — `passive_id` references a missing catalog entry.** A part's `passive_id` resolves to an ID with no Passive DB catalog entry. This ripples through to TBC's Rule 13 registry lookup: per TBC EC-TBC-08, unknown effect IDs are logged as a content error and skipped — the Symbot enters battle without that passive firing, no crash. The Part DB schema does not validate `passive_id` references at equip time; this is caught by content validation tooling. *Verified by AC-PDB-01.*

**EC-PDB-02 — `passive_id` references a valid catalog entry but TBC Rule 13 has no matching registry entry.** The Passive Database catalog and TBC Rule 13 can diverge if a passive is authored here but not added to TBC's registry (or vice versa). Resolution: TBC's Rule 13 is the execution authority — if TBC has no entry for an ID, the passive does not fire (logged per EC-TBC-08). This constitutes a content authoring error, caught at content validation time. *Verified by AC-PDB-02.*

**EC-PDB-03 — Two passives with different IDs share the same `trigger_category` and fire in the same event.** A Symbot equips parts granting both `volt_shock_on_hit` and `kinetic_stagger_on_hit`. On a hit, both trigger. TBC fires each independently — multiple passives with different IDs may all resolve in one trigger event. Resolution order: TBC's Rule 13 execution order (alphabetical by ID, consistent with Synergy's determinism rule). *Verified by AC-PDB-03.*

**EC-PDB-04 — `UNIQUE_PER_TRIGGER` passive granted by two sources fires in the same event.** A Synergy effect AND a part `passive_id` both grant `volt_shock_on_hit`. On a DAMAGE hit, the stacking policy says: de-duplicate and fire once. TBC's Rule 13 deduplicates before firing — the ID fires exactly once per trigger event regardless of source count. The Shock duration is the catalog value (1 turn); no escalation occurs. *Verified by AC-PDB-04.*

**EC-PDB-05 — `STAT_AURA` passive with a negative delta.** A STAT_AURA passive authors `armor: -15` (content authoring error — negative stat auras should not ship but must not crash). TBC applies the aura via the SYN-F4 pattern: `effective_stat = max(0, final_stat + aura_delta)`. The max(0) clamp prevents negative effective stats. No crash. *Verified by AC-PDB-05.*

**EC-PDB-06 — `STRUCTURAL_EFFECT` passive fires when the Symbot is at `max_structure`.** The passive restores Structure but the Symbot is at full health. Overheal above `max_structure` is discarded (TBC EC-TBC-10 principle applies here by analogy). The passive fires normally; excess is wasted. No crash. *Verified by AC-PDB-06.*

**EC-PDB-07 — `CORE_TRAIT` passive authored with `trigger_category: ON_HIT`.** Violates the Core identity doctrine (Rule 6, constraint 2). Content validation flags it naming the passive ID. At runtime: the passive still fires per its `behavior_class`/`trigger_category` (the `passive_class` field is authoring metadata only, not a runtime gate — `behavior_class` is the resolution axis). *Verified at authoring by AC-PDB-12 (content validator); the runtime "fires anyway" behavior is verified by TBC's Rule 13 dispatch tests (TBC AC-TBC-40 family), not by a Passive DB unit test — Passive DB owns no runtime executor.*

**EC-PDB-08 — `STRUCTURAL_EFFECT` passive authored with a negative `CURRENT_STRUCTURE` amount.** A content authoring error (e.g., `amount: -20` instead of `20`) that would damage the carrying Symbot when the passive triggers. Content validation rejects it at authoring time (naming the passive ID). At runtime, if it ships anyway: TBC applies it through the Structure floor clamp — `current_structure = max(0, current_structure + amount)` — so Structure cannot go below 0 and no crash occurs, but the Symbot takes unintended self-damage. This mirrors EC-PDB-05's treatment of negative `STAT_AURA`, except a negative structural amount is *never* legitimate (a negative stat aura can be an intentional debuff). *Verified by AC-PDB-16 (content validator) and AC-PDB-17 (runtime clamp).*

## Dependencies

### Upstream (this system reads from / composes with these)

| System | What Passive DB reads | Status | Hard/Soft |
|--------|----------------------|--------|-----------|
| **Part Database** | The `passive_id` schema field (Rule 1 of this GDD defines what those IDs resolve to); Rarity rules that govern which parts require a passive (Part DB Rule 8); EC-13 defers stacking to here | Approved | Hard |

### Downstream (these systems read from Passive DB)

| System | What it reads | Status | Obligation on that GDD |
|--------|---------------|--------|------------------------|
| **Turn-Based Combat** | Passive IDs from Assembly's passive pool resolve through Rule 13 registry; `trigger_category` and `behavior_class` govern when and how TBC fires each passive | Approved | **Errata obligation**: TBC Rule 13 seed registry must remain in sync with this GDD's Rule 5 table. Any new passive ID authored here that TBC must execute requires a simultaneous TBC Rule 13 entry. |
| **Move Database** | `SKILL_ENHANCE` upgrades that add a `passive_id` must reference an ID that exists in this catalog | Approved | Move DB OQ-MDB-1 is resolved by this GDD. No further Move DB errata — the 3 status rider IDs are now formally authored here. |
| **Synergy System** | Synergy tier `effects` arrays may reference passive IDs cataloged here when the same ID also appears on a part's `passive_id` | Approved | Synergy content authoring must check this catalog before using an ID in `effects`. No Synergy GDD errata required — Rule 6 already states IDs must be registered in TBC GDD before use. |
| **Workshop UI** | `display_name` and `short_description` for part tooltip and active passive display | Not Started | Workshop UI must source passive display text from this catalog, not from Part DB or TBC. |

### Bidirectionality

- **Part Database** already references the Passive Database (Rule 1 schema field `passive_id`, Rule 2 Core slot passive requirement, Rule 8 Rarity passive rules, EC-13 defers stacking) ✓
- **Turn-Based Combat** already references the Passive Database (Rule 13 registry, EC-TBC-08, AC-TBC-29, Dependencies table row "Passive Database: Not Started | Soft") ✓ — this GDD converts that dependency to Authored.
- **Move Database** already references the Passive Database (Rule 5, OQ-MDB-1, sibling relationship in Dependencies) ✓ — OQ-MDB-1 is now resolved by this GDD.
- **Synergy System** references TBC Rule 13 as the effect ID execution registry (Rule 6, OQ-3 resolved) — no Synergy GDD update required; the TBC pathway covers synergy effect ID authoring.
- **Workshop UI** (Not Started) must list Passive DB when authored.

## Tuning Knobs

The Passive Database owns no numeric formula constants — authored values (status duration, stat delta, resource delta) live on individual passive entries, not as global constants. Tuning is per-entry content design, not a system knob. Three cross-system constants are referenced here, owned in Rule 5 of this GDD:

| Knob | Value | What Changing It Does |
|------|-------|-----------------------|
| Status rider Shock duration | 1 turn (passive rider) | If raised to 2: passive Shock matches STATUS-move Shock (narrows the intended power gap between automatic and chosen application). If dropped to 0: the passive becomes a no-op. Safe range: 1 (MVP). |
| Status rider Burn duration | 2 turns (Weapon rider) | At 1: Weapon burn rider is weaker than STATUS-move Burn (explicit downgrade). At 3+: Weapon rider outlasts STATUS moves, an unexpected power inversion. Safe range: 2 (MVP). |
| Status rider Stagger duration | 1 turn (passive rider) | Same logic as Shock rider. 1 turn is the intended "automatic, weaker" application. Safe range: 1 (MVP). |

**Knob interaction warning:** Status rider durations interact with TBC-F3/F4/F5 potency scaling (owned by TBC). A longer passive rider duration amplifies total damage or penalty — changing any rider duration requires TBC re-validation (both the TBC Rule 13 entry and any AC fixtures that assume duration 1 for the passive rider).

**Content-level tuning (not system knobs):** STAT_AURA deltas, RESOURCE_EFFECT amounts, and STRUCTURAL_EFFECT amounts are per-entry authored values. Tuning them is a content balance pass, not a system change. Safe ranges for those values are governed by the affected stat's Part DB stat budget tables and TBC's anti-stall contracts (TBC-F6, BASE_ENERGY_REGEN).

## Visual/Audio Requirements

The Passive Database is a data schema — it authors no assets and emits no signals of its own. All visual and audio for passive effects is owned by Turn-Based Combat's Visual/Audio section (where passives fire and resolve) and ratified by the Art Bible. Two passive-specific notes for downstream owners:

- **Passive proc readability**: when a status rider fires automatically (e.g., `volt_shock_on_hit` applying Shock without a STATUS move), the combat feedback must distinguish it from a move-applied status — a brief secondary indicator (e.g., a smaller, faded version of the Shock proc VFX) so the player knows the passive fired, not a move. Direction for TBC V3-5 / Art Bible.
- **Workshop passive indicator**: active passives on equipped parts need a consistent visual treatment in the Workshop (an icon or colored tag indicating passive class). Direction for Workshop UI / Art Bible — not a schema field here.

📌 **Asset Spec** — no assets originate here; when the Art Bible is approved, passive proc VFX are specced under `/asset-spec system:turn-based-combat`.

## UI Requirements

Obligations this catalog places on the **Workshop UI GDD** (Not Started):

1. **Part tooltip** — display the equipped part's passive by `display_name` + `short_description` from this catalog. The tooltip must distinguish `STATUS_RIDER`, `CORE_TRAIT`, and `UPGRADE_PASSIVE` classes so players understand when and how the passive fires.
2. **Active passive indicators** — during Workshop preview, show which passives are currently active on the loaded build (relevant when the same passive ID appears from multiple sources — display it once, per `UNIQUE_PER_TRIGGER` policy, not duplicated).
3. **Passive proc log** — when a passive fires in combat, the battle log should name it by `display_name` so players can learn what fires when. Owned by Combat UI / TBC.

> **📌 UX Flag — Passive Database**: the passive tooltip and proc log are player-facing information needs. Fold them into the combat-screen and Workshop `/ux-design` passes (they belong in `design/ux/combat.md` and `design/ux/workshop.md`, not this GDD).

## Acceptance Criteria

ACs marked **BLOCKING** are Logic-type — automated unit tests in `tests/unit/passive_db/` gating story completion. **ADVISORY** ACs gate content-authoring pipelines. **DEFERRED** ACs need Not-Started system tooling and state their unblock trigger.

### Schema and Lookup

**AC-PDB-01** (BLOCKING): a lookup for a `passive_id` with no Passive DB catalog entry returns `null` and never throws. *Verifies EC-PDB-01.*

**AC-PDB-02** (BLOCKING): a valid Passive DB catalog entry whose ID is absent from TBC's Rule 13 registry does not fire during battle — TBC skips it and logs exactly one content error naming the ID; no crash; other passives on the same Symbot unaffected. *Verifies EC-PDB-02.*
GIVEN the Passive DB catalog contains `orphaned_test_passive` with `trigger_category: ON_BATTLE_START`, `behavior_class: RESOURCE_EFFECT`, `behavior_params: { HEAT, -10 }`, and this ID is **absent from TBC's Rule 13 registry**, AND a Symbot carries both `passive_id = &"orphaned_test_passive"` and `volt_shock_on_hit` (the latter present in Rule 13),
WHEN the battle starts (firing the `ON_BATTLE_START` phase) and the Symbot then lands a DAMAGE hit,
THEN `orphaned_test_passive` resolves to no effect (Heat unchanged by it); exactly one content error is logged whose message contains the substring `"orphaned_test_passive"`; `volt_shock_on_hit` applies Shock normally on the hit.
FAIL: zero errors logged (silent skip); two or more errors logged (per-trigger log spam); the log message omits the ID; a crash; or `volt_shock_on_hit` is suppressed. *Chose `ON_BATTLE_START` for the fixture because it needs no hit setup to fire the orphan's trigger.*

**AC-PDB-03** (BLOCKING): a well-formed Passive DB entry carries all required fields (`id`, `display_name`, `short_description`, `trigger_category`, `behavior_class`, `stacking_policy`, `passive_class`) and does NOT carry `heat_generation` or `energy_cost`. *Rule 1.*

### Status Rider Passives (Rule 5 — OQ-MDB-1 resolution)

**AC-PDB-04** (BLOCKING): `volt_shock_on_hit` fires on any DAMAGE move hit and applies Shock for **1 turn**. GIVEN attacker Symbot A carries `passive_id = &"volt_shock_on_hit"` and target Symbot B has no Shock, WHEN A lands a STANDARD-tier DAMAGE move on B, THEN B has Shock status with `duration = 1`. FAIL: no Shock applied; `duration = 2` (matching STATUS move — wrong); `duration = 0` (registered but no-op). NEGATIVE case: A's REPAIR move does not apply Shock to any target.

**AC-PDB-05** (BLOCKING): `thermal_burn_on_weapon` fires on WEAPON-slot DAMAGE move hits and applies Burn for **2 turns**. GIVEN attacker A carries `passive_id = &"thermal_burn_on_weapon"` (`scope = WEAPON_ONLY`), WHEN A lands a WEAPON-slot DAMAGE move on target B, THEN B has Burn with `duration = 2`. NEGATIVE case: when A lands an ARMS-slot DAMAGE move on B, B has no Burn (scope excludes it). FAIL: fires on an ARMS-slot move; `duration = 1` (Shock duration copied); `duration ≠ 2`.

**AC-PDB-06** (BLOCKING): `kinetic_stagger_on_hit` fires on any DAMAGE move hit and applies Stagger for **1 turn**. GIVEN attacker A carries `passive_id = &"kinetic_stagger_on_hit"`, WHEN A lands a DAMAGE move on target B, THEN B has Stagger with `duration = 1`. FAIL: no Stagger applied; `duration ≠ 1`. NEGATIVE case: A's STATUS move and A's REPAIR move do not apply Stagger.

### Stacking Policy

**AC-PDB-07** (BLOCKING): `UNIQUE_PER_TRIGGER` — two sources of `volt_shock_on_hit` (one from part `passive_id`, one from synergy `effects`) produce exactly **one Shock application** on a single hit. FAIL: two Shocks applied; or second application overwrites with a duration reset (distinct bug from double-apply). *Verifies EC-PDB-04.*

**AC-PDB-08** (BLOCKING): two passives with **different IDs** and the same `trigger_category` (`volt_shock_on_hit` + `kinetic_stagger_on_hit`) both fire on the same DAMAGE hit — both statuses applied, each exactly once, in alphabetical ID order. GIVEN attacker A carries both passives, WHEN A lands a DAMAGE hit on B, THEN B has both Shock (`duration = 1`) and Stagger (`duration = 1`); AND the **TBC passive proc log** records the two proc entries in alphabetical ID order — `kinetic_stagger_on_hit` before `volt_shock_on_hit` (k < v). FAIL: only one status applied; either status applied twice; proc log lists `volt_shock_on_hit` first (wrong order) or the ordering observable is a set with no defined order. *Verifies EC-PDB-03. Ordering observable is the proc log emission sequence, consistent with Synergy's determinism rule.*

**AC-PDB-09** (BLOCKING): a `UNIQUE` passive granted twice (part `passive_id` + a second source) — only one instance active; the second source adds no additional effect. Runtime state holds exactly one entry for the ID. FAIL: two instances active.

### Edge Case Coverage

**AC-PDB-10** (BLOCKING): `STAT_AURA` passive with a negative delta applied to a Symbot with a low base stat — `effective_stat = max(0, final_stat + aura_delta)` clamps at 0; no negative effective stats; no crash. FAIL: negative effective stat; crash. *Verifies EC-PDB-05.*

**AC-PDB-11** (BLOCKING): `STRUCTURAL_EFFECT` passive fires on a full-Structure Symbot — excess heal discarded, Structure stays at `max_structure`, no crash. FAIL: overheal persists; crash. *Verifies EC-PDB-06.*

**AC-PDB-17** (BLOCKING): a `STRUCTURAL_EFFECT` passive with a negative `CURRENT_STRUCTURE` amount (a shipped authoring error) applied to a low-Structure Symbot — `current_structure = max(0, current_structure + amount)` clamps at 0; Structure never goes negative; no crash. FAIL: negative Structure; crash. *Verifies EC-PDB-08 (runtime path).*

### Content Validation (ADVISORY, DEFERRED)

**AC-PDB-12** (ADVISORY-DEFERRED): a `CORE_TRAIT` passive authored with `trigger_category: ON_HIT` — content validator flags it naming the passive ID. *Unblocks when: Passive DB content-authoring pipeline and schema validation tooling exist. Verifies EC-PDB-07.*

**AC-PDB-13** (ADVISORY-DEFERRED): a part's `passive_id` references an ID not in the Passive DB catalog — content validator errors naming the part ID and the missing passive ID. *Unblocks when: cross-schema content validation tooling exists.*

**AC-PDB-14** (ADVISORY-DEFERRED): every Boss-grade or Prototype Core passive in MVP content has a unique `trigger_category` + `behavior_class` combination — content validator flags duplicates naming both passive IDs. *Unblocks when: MVP Core passive content is authored (OQ-PDB-1) and content validation tooling exists.*

**AC-PDB-15** (ADVISORY-DEFERRED): a passive entry with an illegal `trigger_category` × `behavior_class` pairing (per Rule 3's legality table — e.g., `STATUS_RIDER` + `ON_BATTLE_START`) — content validator rejects it naming the passive ID and the illegal pairing. *Unblocks when: schema validation tooling exists.*

**AC-PDB-16** (ADVISORY-DEFERRED): a passive entry whose `behavior_params` does not match its `behavior_class` (missing a required key, wrong key set, or a negative `CURRENT_STRUCTURE` amount per EC-PDB-08) — content validator rejects it naming the passive ID and the offending field. *Unblocks when: schema validation tooling exists. Verifies EC-PDB-08 (authoring path).*

### Deferred — Activates on First Content (OQ-PDB-1 entry criteria)

These positive-path ACs cover behavior classes and triggers with **no MVP content yet** (all three shipped passives are `STATUS_RIDER` + `ON_HIT`). They are not blocking *this* GDD because nothing exercises these paths — but they become **BLOCKING entry criteria the moment OQ-PDB-1 authors the first passive using each path.** Recorded here so the content pass inherits them, not discovers them.

**AC-PDB-D1** (DEFERRED→BLOCKING on first `ON_BATTLE_START` content): an `ON_BATTLE_START` passive fires exactly once during BATTLE_INIT, before turn 1. Mirrors TBC AC-TBC-40's dispatch coverage on the Passive DB side. FAIL: fires zero times; fires per turn.

**AC-PDB-D2** (DEFERRED→BLOCKING on first `PERSISTENT`/`STAT_AURA` content): a `PERSISTENT` `STAT_AURA` applies its `delta` from BATTLE_INIT and the modified stat holds across all turns without re-firing. FAIL: applied on-hit instead of at battle start; delta lost after turn 1; delta applied every turn (stacking a PERSISTENT).

**AC-PDB-D3** (DEFERRED→BLOCKING on first `STACKABLE` content): two sources of a `STACKABLE` `RESOURCE_EFFECT` both fire independently on one trigger — combined amount = 2× a single source (clamped by the resource cap). FAIL: deduplicated to one application (behaving as `UNIQUE_PER_TRIGGER`).

**AC-PDB-D4** (DEFERRED→BLOCKING on first `RESOURCE_EFFECT` content): a `RESOURCE_EFFECT` passive changes the named resource by `amount` when triggered, clamped by the cap (Heat 100 / Energy Capacity). FAIL: resource unchanged; wrong resource modified; cap not respected.

### Summary

**14 ACs live + 4 deferred:** 12 BLOCKING unit (AC-PDB-01–11, 17) + 5 ADVISORY-DEFERRED content (AC-PDB-12–16) + 4 activates-on-first-content (AC-PDB-D1–D4, become BLOCKING when OQ-PDB-1 authors the matching path).

EC↔AC cross-check (every EC with an observable outcome cites a verifying AC):
- EC-PDB-01 → AC-PDB-01
- EC-PDB-02 → AC-PDB-02
- EC-PDB-03 → AC-PDB-08
- EC-PDB-04 → AC-PDB-07
- EC-PDB-05 → AC-PDB-10
- EC-PDB-06 → AC-PDB-11
- EC-PDB-07 → AC-PDB-12 (authoring, ADVISORY-DEFERRED) + TBC AC-TBC-40 family (runtime "fires anyway", owned by TBC — Passive DB has no runtime executor)
- EC-PDB-08 → AC-PDB-16 (authoring) + AC-PDB-17 (runtime clamp, BLOCKING)

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-PDB-1 | **MVP Core passive roster — CRITICAL PATH, not a routine backlog item.** Specific passive IDs and behaviors for Rare+ Core identity passives (Rule 6) must be authored with the content plan. The schema (Rule 1/3a) and doctrine (Rule 6) are defined; the actual entries await content design co-planning with the Part Database content authoring pass. **This is a named critical-path dependency**: Part Database (Approved) already *requires* Rare+ Cores to carry a non-null `passive_id` (Part DB Rule 8), and Pillars 3 (Build Depth) and 4 (Synergy Is the Endgame) are mechanically funded by Core passives being distinct. Until OQ-PDB-1 lands, those Part DB entries cannot be authored and the two highest pillars have no passive content behind them. **Charter for the content pass:** (a) the 3 MVP status riders are *deliberately flat* — they fire identically regardless of build depth; investment-scaling and multi-part-threshold passives (the mechanics that actually deliver the "my build does this on its own" fantasy) are the explicit design brief of this pass, not of the ratified riders; (b) OQ-PDB-1 inherits AC-PDB-D1–D4 (above) as entry criteria — the first Core passive using `ON_BATTLE_START` / `PERSISTENT` / `STAT_AURA` / `RESOURCE_EFFECT` / `STACKABLE` activates the matching deferred AC as BLOCKING; (c) mind the combinatorial ceiling (Rule 6 restricts Core passives to `ON_BATTLE_START`/`ON_OVERHEAT`/`PERSISTENT` × 4 behavior classes ≈ 12 unique combos — do not author more Boss-grade/Prototype Cores than the uniqueness constraint allows without expanding the enums). | Content plan / game-designer | **Blocks:** Boss-grade & Prototype Core content authoring, Part DB Rare+ Core entries, Pillar 3 & 4 delivery. Unblocks once the MVP part roster is planned. |
| OQ-PDB-2 | **Synergy-only effect IDs.** Synergy tier `effects` arrays may reference IDs that never appear on any part's `passive_id` (pure synergy effects). These are NOT cataloged in Passive DB per the current design (Rule C Interactions). If synergy effects grow complex enough to need a display name or description here, this question reopens. | Synergy System / Passive DB | Low in MVP — TBC Rule 13 handles them without Passive DB entries |
| OQ-PDB-3 | **SKILL_ENHANCE passive IDs beyond status riders.** Move DB Rule 9 allows `SKILL_ENHANCE` to add non-status-rider passives (e.g., a `RESOURCE_EFFECT` that grants Energy on hit at upgrade tier +5). These must be authored in this catalog before content uses them. The question is when to design those entries — alongside Move DB content or at content-authoring time. | Move Database content plan | Unblocks content authors who want upgrade-path passives beyond the 3 status riders |
