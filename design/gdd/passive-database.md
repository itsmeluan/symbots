# Passive Database

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
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
| `scope` | Enum | `ANY_DAMAGE` / `WEAPON_ONLY` — relevant for ON_HIT triggers; `null` for others |
| `behavior_class` | Enum | What the passive does (Rule 3) |
| `stacking_policy` | Enum | `UNIQUE`, `UNIQUE_PER_TRIGGER`, or `STACKABLE` (Rule 4) |
| `passive_class` | Enum | `STATUS_RIDER` / `CORE_TRAIT` / `UPGRADE_PASSIVE` — authoring classification only; does not change resolution |

`heat_generation` and `energy_cost` are never on a passive — passives fire automatically and consume no player resources (they are not moves).

---

**Rule 2 — Trigger Categories (MVP).** A passive fires when its trigger condition occurs on the combatant carrying it:

| `trigger_category` | When it fires |
|--------------------|--------------|
| `ON_HIT` | The carrying Symbot's DAMAGE move lands a hit (`hit_resolved` emitted by TBC) |
| `ON_WEAPON_HIT` | Same as `ON_HIT`, narrowed to WEAPON-slot moves only |
| `ON_BATTLE_START` | Once per battle, during TBC's BATTLE_INIT phase before the first turn |
| `ON_OVERHEAT` | The carrying Symbot triggers Overheat (Heat reaches 100) |
| `PERSISTENT` | Active for the entire battle; applies from BATTLE_INIT and never re-triggers |

All triggers resolve through TBC's Rule 13 registry. The `trigger_category` in this catalog must match the TBC registry entry exactly — it is the shared vocabulary, not an independent spec.

---

**Rule 3 — Behavior Classes (MVP).** The four behavior classes cover all MVP passive effects:

| `behavior_class` | What it does | Typical trigger |
|-----------------|-------------|----------------|
| `STATUS_RIDER` | Applies a status effect (Shock / Burn / Stagger) automatically | `ON_HIT` or `ON_WEAPON_HIT` |
| `STAT_AURA` | Modifies a combat stat for the entire battle (runtime only — Part DB `final_stat` unchanged) | `PERSISTENT` |
| `RESOURCE_EFFECT` | Modifies Heat or Energy immediately when triggered | `ON_BATTLE_START` or `ON_OVERHEAT` |
| `STRUCTURAL_EFFECT` | Modifies current or max Structure immediately when triggered | `ON_BATTLE_START` |

Additional behavior classes (`CONDITIONAL_BUFF`, `SPAWN_EFFECT`) are reserved for Vertical Slice+. A passive may not combine two behavior classes — one entry, one effect.

---

**Rule 4 — Stacking Policy.** When a Symbot carries the same passive ID from multiple sources (e.g., two equipped parts both reference `volt_shock_on_hit`, or a part passive and a synergy effect grant the same ID), the `stacking_policy` field governs how TBC handles it:

| `stacking_policy` | Behavior |
|------------------|----------|
| `UNIQUE` | Only one instance is ever active; a second source granting the same ID does nothing new. Best for `PERSISTENT` stat auras and `STRUCTURAL_EFFECT` passives where double-application would be unintentional. |
| `UNIQUE_PER_TRIGGER` | Multiple sources may exist, but the effect fires at most **once per trigger event** (once per hit, once per battle start). The instances de-duplicate at fire time. Best for `STATUS_RIDER` passives — prevents multi-Shock on a single hit from two sources of the same rider. |
| `STACKABLE` | Each source fires independently. Best for non-status `RESOURCE_EFFECT` passives where the intent is that deeper investment yields more payoff. |

**Default policies by passive class:**
- `STATUS_RIDER` → `UNIQUE_PER_TRIGGER`
- `CORE_TRAIT` (any behavior class) → `UNIQUE` (reinforced by Part DB's one-Core-per-Symbot schema)
- `UPGRADE_PASSIVE` that grants a status rider → inherits the rider's `UNIQUE_PER_TRIGGER`
- `UPGRADE_PASSIVE` that grants a `RESOURCE_EFFECT` → `STACKABLE` (upgrade investment deepens the reward)

---

**Rule 5 — Status Rider Passives (OQ-MDB-1 resolution, TBC Rule 13 ratification).** These three entries formally ratify the MVP status rider IDs seeded in TBC Rule 13. The Passive Database is the design-level source of truth; TBC Rule 13 is the runtime executor. Both documents must agree — any change to these entries requires updating TBC Rule 13 simultaneously.

| `id` | `trigger_category` | `scope` | `behavior_class` | Effect | `stacking_policy` |
|------|--------------------|---------|-----------------|--------|------------------|
| `volt_shock_on_hit` | `ON_HIT` | `ANY_DAMAGE` | `STATUS_RIDER` | Applies Shock for **1 turn** (shorter than the STATUS-move's 2 — the passive rider is a weaker, automatic application) | `UNIQUE_PER_TRIGGER` |
| `thermal_burn_on_weapon` | `ON_WEAPON_HIT` | `WEAPON_ONLY` | `STATUS_RIDER` | Applies Burn for **2 turns** (full duration — Weapon attacks are the primary damage source; the Weapon rider is full-strength) | `UNIQUE_PER_TRIGGER` |
| `kinetic_stagger_on_hit` | `ON_HIT` | `ANY_DAMAGE` | `STATUS_RIDER` | Applies Stagger for **1 turn** | `UNIQUE_PER_TRIGGER` |

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

**Rule 7 — Upgrade-Granted Passives (SKILL_ENHANCE path).** Move DB Rule 9 defines `SKILL_ENHANCE` as a part upgrade effect that can "add a passive rider ID" at a specified tier. Any passive ID added via SKILL_ENHANCE must exist in this catalog before it can be authored in content. The Passive Database does not define *which parts* unlock which passives at which tiers (that is the part's `upgrade_effects` array, owned by Part DB / Move DB) — it defines what each passive ID means. A SKILL_ENHANCE that adds `volt_shock_on_hit` inherits that entry's trigger, scope, behavior class, and stacking policy without overriding them.

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
- **STRUCTURAL_EFFECT numeric values** — same pattern: per-entry authored integers, clamped by TBC's Structure floor (0) and ceiling (current `max_structure` at the moment of trigger).

**Interaction with registry constants:** The 3 status rider passives (Rule 5) produce effects governed by TBC-F3 (Burn), TBC-F4 (Shock), and TBC-F5 (Stagger). Their output ranges are unchanged by Passive DB — the Passive Database only specifies that the effect fires; the magnitude is determined by the applier's `snapshotted_processing` stat at fire time per TBC's snapshot contract (pre-synergy, per TBC Rule 10).

## Edge Cases

**EC-PDB-01 — `passive_id` references a missing catalog entry.** A part's `passive_id` resolves to an ID with no Passive DB catalog entry. This ripples through to TBC's Rule 13 registry lookup: per TBC EC-TBC-08, unknown effect IDs are logged as a content error and skipped — the Symbot enters battle without that passive firing, no crash. The Part DB schema does not validate `passive_id` references at equip time; this is caught by content validation tooling. *Verified by AC-PDB-01.*

**EC-PDB-02 — `passive_id` references a valid catalog entry but TBC Rule 13 has no matching registry entry.** The Passive Database catalog and TBC Rule 13 can diverge if a passive is authored here but not added to TBC's registry (or vice versa). Resolution: TBC's Rule 13 is the execution authority — if TBC has no entry for an ID, the passive does not fire (logged per EC-TBC-08). This constitutes a content authoring error, caught at content validation time. *Verified by AC-PDB-02.*

**EC-PDB-03 — Two passives with different IDs share the same `trigger_category` and fire in the same event.** A Symbot equips parts granting both `volt_shock_on_hit` and `kinetic_stagger_on_hit`. On a hit, both trigger. TBC fires each independently — multiple passives with different IDs may all resolve in one trigger event. Resolution order: TBC's Rule 13 execution order (alphabetical by ID, consistent with Synergy's determinism rule). *Verified by AC-PDB-03.*

**EC-PDB-04 — `UNIQUE_PER_TRIGGER` passive granted by two sources fires in the same event.** A Synergy effect AND a part `passive_id` both grant `volt_shock_on_hit`. On a DAMAGE hit, the stacking policy says: de-duplicate and fire once. TBC's Rule 13 deduplicates before firing — the ID fires exactly once per trigger event regardless of source count. The Shock duration is the catalog value (1 turn); no escalation occurs. *Verified by AC-PDB-04.*

**EC-PDB-05 — `STAT_AURA` passive with a negative delta.** A STAT_AURA passive authors `armor: -15` (content authoring error — negative stat auras should not ship but must not crash). TBC applies the aura via the SYN-F4 pattern: `effective_stat = max(0, final_stat + aura_delta)`. The max(0) clamp prevents negative effective stats. No crash. *Verified by AC-PDB-05.*

**EC-PDB-06 — `STRUCTURAL_EFFECT` passive fires when the Symbot is at `max_structure`.** The passive restores Structure but the Symbot is at full health. Overheal above `max_structure` is discarded (TBC EC-TBC-10 principle applies here by analogy). The passive fires normally; excess is wasted. No crash. *Verified by AC-PDB-06.*

**EC-PDB-07 — `CORE_TRAIT` passive authored with `trigger_category: ON_HIT`.** Violates the Core identity doctrine (Rule 6, constraint 2). Content validation flags it naming the passive ID. At runtime: the passive still fires per its trigger category (the `passive_class` field is authoring metadata only, not a runtime gate). *Verified by AC-PDB-07 (content validator).*

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

**AC-PDB-02** (BLOCKING): a valid Passive DB catalog entry whose ID is absent from TBC's Rule 13 registry does not fire during battle — TBC skips it and logs exactly one content error naming the ID; no crash; other passives on the same Symbot unaffected. *Verifies EC-PDB-02.* GIVEN a Symbot has `passive_id = &"orphaned_test_passive"` (in Passive DB catalog, absent from TBC Rule 13), WHEN the trigger condition fires, THEN no effect resolves; exactly one content error logged; `volt_shock_on_hit` on the same Symbot fires normally.

**AC-PDB-03** (BLOCKING): a well-formed Passive DB entry carries all required fields (`id`, `display_name`, `short_description`, `trigger_category`, `behavior_class`, `stacking_policy`, `passive_class`) and does NOT carry `heat_generation` or `energy_cost`. *Rule 1.*

### Status Rider Passives (Rule 5 — OQ-MDB-1 resolution)

**AC-PDB-04** (BLOCKING): `volt_shock_on_hit` fires on any DAMAGE move hit and applies Shock for **1 turn**. Fixture: Symbot with `passive_id = &"volt_shock_on_hit"`, STANDARD-tier DAMAGE move lands. THEN target has Shock status, `duration = 1`. FAIL: no Shock applied; duration = 2 (matching STATUS move — wrong). NEGATIVE case: REPAIR move does not trigger it.

**AC-PDB-05** (BLOCKING): `thermal_burn_on_weapon` fires on WEAPON-slot DAMAGE move hits and applies Burn for **2 turns**. NEGATIVE case: ARM-slot DAMAGE move does not trigger it (`scope = WEAPON_ONLY`). FAIL: fires on Arms move; duration ≠ 2.

**AC-PDB-06** (BLOCKING): `kinetic_stagger_on_hit` fires on any DAMAGE move hit and applies Stagger for **1 turn**. FAIL: fires on STATUS or REPAIR moves.

### Stacking Policy

**AC-PDB-07** (BLOCKING): `UNIQUE_PER_TRIGGER` — two sources of `volt_shock_on_hit` (one from part `passive_id`, one from synergy `effects`) produce exactly **one Shock application** on a single hit. FAIL: two Shocks applied; or second application overwrites with a duration reset (distinct bug from double-apply). *Verifies EC-PDB-04.*

**AC-PDB-08** (BLOCKING): two passives with **different IDs** and the same `trigger_category` (`volt_shock_on_hit` + `kinetic_stagger_on_hit`) both fire on the same DAMAGE hit — both statuses applied, each exactly once, in alphabetical ID order. FAIL: only one fires; wrong order. *Verifies EC-PDB-03.*

**AC-PDB-09** (BLOCKING): a `UNIQUE` passive granted twice (part `passive_id` + a second source) — only one instance active; the second source adds no additional effect. Runtime state holds exactly one entry for the ID. FAIL: two instances active.

### Edge Case Coverage

**AC-PDB-10** (BLOCKING): `STAT_AURA` passive with a negative delta applied to a Symbot with a low base stat — `effective_stat = max(0, final_stat + aura_delta)` clamps at 0; no negative effective stats; no crash. FAIL: negative effective stat; crash. *Verifies EC-PDB-05.*

**AC-PDB-11** (BLOCKING): `STRUCTURAL_EFFECT` passive fires on a full-Structure Symbot — excess heal discarded, Structure stays at `max_structure`, no crash. FAIL: overheal persists; crash. *Verifies EC-PDB-06.*

### Content Validation (ADVISORY, DEFERRED)

**AC-PDB-12** (ADVISORY-DEFERRED): a `CORE_TRAIT` passive authored with `trigger_category: ON_HIT` — content validator flags it naming the passive ID. *Unblocks when: Passive DB content-authoring pipeline and schema validation tooling exist. Verifies EC-PDB-07.*

**AC-PDB-13** (ADVISORY-DEFERRED): a part's `passive_id` references an ID not in the Passive DB catalog — content validator errors naming the part ID and the missing passive ID. *Unblocks when: cross-schema content validation tooling exists.*

**AC-PDB-14** (ADVISORY-DEFERRED): every Boss-grade or Prototype Core passive in MVP content has a unique `trigger_category` + `behavior_class` combination — content validator flags duplicates naming both passive IDs. *Unblocks when: MVP Core passive content is authored (OQ-PDB-1) and content validation tooling exists.*

### Summary

11 ACs: 9 BLOCKING unit (AC-PDB-01–11) + 3 ADVISORY-DEFERRED content (12–14). EC↔AC cross-check: EC-PDB-01→AC-PDB-01, EC-PDB-02→AC-PDB-02, EC-PDB-03→AC-PDB-08, EC-PDB-04→AC-PDB-07, EC-PDB-05→AC-PDB-10, EC-PDB-06→AC-PDB-11, EC-PDB-07→AC-PDB-12.

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-PDB-1 | **MVP Core passive roster.** Specific passive IDs and behaviors for Rare+ Core identity passives (Rule 6) must be authored with the content plan. The schema (Rule 1) and doctrine (Rule 6) are defined; the actual entries await content design co-planning with the Part Database content authoring pass. | Content plan / game-designer | Blocks Boss-grade and Prototype Core content authoring; unblocks once the MVP part roster is planned |
| OQ-PDB-2 | **Synergy-only effect IDs.** Synergy tier `effects` arrays may reference IDs that never appear on any part's `passive_id` (pure synergy effects). These are NOT cataloged in Passive DB per the current design (Rule C Interactions). If synergy effects grow complex enough to need a display name or description here, this question reopens. | Synergy System / Passive DB | Low in MVP — TBC Rule 13 handles them without Passive DB entries |
| OQ-PDB-3 | **SKILL_ENHANCE passive IDs beyond status riders.** Move DB Rule 9 allows `SKILL_ENHANCE` to add non-status-rider passives (e.g., a `RESOURCE_EFFECT` that grants Energy on hit at upgrade tier +5). These must be authored in this catalog before content uses them. The question is when to design those entries — alongside Move DB content or at content-authoring time. | Move Database content plan | Unblocks content authors who want upgrade-path passives beyond the 3 status riders |
