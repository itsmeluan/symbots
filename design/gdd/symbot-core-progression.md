# Symbot Core Progression (Leveling)

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 1 (Engineer, Don't Collect), Pillar 3 (Build Depth Over Content Breadth)

## Overview

The Symbot Core Progression System is the runtime authority for every Symbot core's experience points, level, and level-gated stat growth. It owns three responsibilities: (1) **XP tracking** — receiving XP awards from Turn-Based Combat at battle end and distributing them to active and benched core slots according to the bench share rule; (2) **level derivation** — converting cumulative XP into a discrete level using the CP-F1 XP-to-level formula; and (3) **equip gating** — enforcing the `level_requirement` field that Part Database authors set on parts, blocking equip via the Workshop if the occupying core's level is below threshold.

This system does not own stat computation — the per-level stat gains it stores are read by Symbot Assembly and feed into the SA-F1 pipeline alongside the part's own stat bonuses. It does not own the Workshop equip flow — it exposes a gate-check call that Assembly invokes on equip. It does not own XP award amounts — those are authored in content data (one amount for WILD battles, one for boss encounters) and passed in by TBC.

Core level is the sole output that gates access to high-tier parts. It cannot be purchased — the only path is battle XP. Scrap currency upgrades parts; battle XP levels cores. These two axes are intentionally non-substitutable.

## Player Fantasy

The player never thinks "I am accumulating XP toward a threshold." They think: *"After that boss fight my Spark Core hit level 5 — and the Volt Arms I've been sitting on finally became equippable. I can run a full VOLT-line build now."*

That is the two-part fantasy this system exists to deliver.

**The level-up moment:** A core levels up at the end of a battle. The notification is quiet — a line in the post-battle summary, or a glow on the Workshop core slot. But the implications are immediate: the player opens the Workshop and sees a part that was greyed out is now available. The level wasn't a number going up. It was a door opening. Every level-up is a build hypothesis becoming reachable.

**The patient investment:** A new core starts at level 1. It can only equip starter-tier Common parts. This is intentional: the player chose to start a new Symbot — perhaps to try a different element or manufacturer line — and they are now investing real battle time to build it up. They bench their main-team veteran so the new core catches partial XP from fights it isn't in. Over five or ten sessions, the new Symbot grows from a blank chassis into a real combatant. The player did not buy that progression. They earned it through the hunt loop itself.

**The pacing anchor:** Core leveling also serves a protective role. A player who accumulates a powerful set of parts cannot immediately shortcut the system by creating a new core and instantly fielding it at full strength. The new core starts at level 1 and cannot equip high-rarity parts until it has earned sufficient level — a meaningful time-investment gate that keeps the power curve coherent. If Boss-grade and Prototype parts require level 6–8, a player cannot bypass the mid-game loop just by making a second Symbot. The core's level is its proof of experience. That proof cannot be faked or purchased.

The anti-fantasy to avoid: never let "need more XP" become grinding filler. If reaching a level feels like repetitive combat with no other payoff, the XP curve is wrong or the hunt loop itself lacks density. Level-up must feel like a side-effect of doing the game's real activities — hunting parts, breaking bosses — never the primary motivation for entering combat.

> *(Note: creative-director not consulted — Lean mode. Review Section B manually before production.)*

## Detailed Design

### Core Rules

**Rule 1 — CoreProgressionRecord.** Each core part instance has exactly one `CoreProgressionRecord`, keyed by `instance_id`:

| Field | Type | Notes |
|-------|------|-------|
| `core_instance_id` | int | Matches the Inventory `instance_id` for this core part. One-to-one. |
| `cumulative_xp` | int | Total XP ever earned by this core. Monotonically increasing — never resets, never decays. |
| `level` | int | [1, MAX_CORE_LEVEL]. Always re-derived from `cumulative_xp` via CP-F1 on load; the stored value is a cache for display and gate-check, not the authority. |

A `CoreProgressionRecord` is created when a core is first added to Inventory, initialized with `cumulative_xp = 0, level = 1`. The Exploration Progress System serializes it to disk.

---

**Rule 2 — Level derivation.** Level is a deterministic function of `cumulative_xp`, computed via CP-F1 (the XP threshold table). The table is derived from a base cost of `XP_PER_LEVEL_BASE` with a `LEVEL_COST_RAMP` multiplier per level (see Formulas). Level never decreases. After any XP gain, re-derive level and emit `core_leveled_up(core_instance_id, old_level, new_level)` if level increased. Multiple levels in a single XP gain are possible (emit for each crossed threshold).

---

**Rule 3 — XP award at battle end.** On `battle_ended(VICTORY, ...)`:

1. Determine `full_xp`: `XP_PER_BOSS` if the defeated enemy was a boss encounter; `XP_PER_WILD` otherwise.
2. For each Symbot in the active team roster (up to `TEAM_ROSTER_CAP` = 3):
   - If the Symbot was **deployed** (fielded at any point during the battle): award `full_xp` to its core.
   - If the Symbot was **not deployed** (was in the team roster but never switched in): award `floor(full_xp × BENCH_XP_SHARE)` to its core.
3. On `battle_ended(DEFEAT, ...)` or `battle_ended(FLED, ...)`: no XP is awarded to any core.

**"Deployed"** is tracked by TBC's existing switch state — if a Symbot was the active fighter at any point during the battle (including entering as the start-of-battle active Symbot), it counts as deployed.

---

**Rule 4 — Level_requirement equip gate.** When the Workshop System invokes `equip_part(symbot_build, slot, part_id)` on Assembly:

1. Assembly reads `part.level_requirement` from Part DB for the candidate part (new field — see Part DB erratum).
2. Assembly reads the current `level` of the core instance occupying the `CORE` slot of `symbot_build`.
3. If `core.level < part.level_requirement`: **reject the equip** and return an error with message "Core level [N] required — your [core name] is level [M]."
4. If `core.level >= part.level_requirement` (or `level_requirement == 0 / null`): proceed normally.

The gate check runs on every equip attempt, not just the first equip. If a player replaces their core with a lower-level core, previously equipped parts may now violate the gate — Workshop UI must surface this as a validation warning on the build (see UI Requirements).

---

**Rule 5 — Level_requirement by rarity (authoring rule).** Part Database authors MUST assign `level_requirement` according to this table:

| Rarity | level_requirement |
|--------|-------------------|
| `COMMON` | 1 (effectively no gate — all cores start at level 1) |
| `RARE` | 3 |
| `BOSS_GRADE` | 6 |
| `PROTOTYPE` | 8 |

Individual parts within a rarity may have a higher `level_requirement` (e.g., a particularly powerful Boss-grade weapon may require level 7), but never lower than their rarity's floor. Common parts must remain accessible to a fresh core.

---

**Rule 6 — Stat growth integration.** A core part's SympartData includes a `level_growth` dictionary: `stat_key → int bonus_per_level`. This is a new field added to SympartData via Part DB erratum — only present on `CORE` slot parts (other slots have `null` or empty dict).

At runtime, Assembly reads the equipped core's `level_growth` and applies the **CP contribution step** between the SA-F1 pipeline and SYN-F4:

```
for stat_key in core.level_growth:
    final_stat[stat_key] += core.level_growth[stat_key] * (core.level - 1)
```

This step is:
- Applied **after** SA-F1 (bypasses chassis modifier — level growth is intrinsic to the core, not amplified by archetype)
- Applied **before** SYN-F4 (synergy bonuses add on top of level-enhanced base stats)
- Applied only to stats listed in `level_growth`; unlisted stats are unaffected

The CP contribution at level 1 is zero (`core.level - 1 = 0`), so the integration is seamless for level-1 cores.

---

**Rule 7 — Max level cap.** `MAX_CORE_LEVEL = 10`. Cores do not receive XP beyond the XP threshold for level 10; excess XP is discarded (no over-cap banking). A level-10 core participating in battle still "counts as deployed" for the team's XP distribution, but its own `cumulative_xp` does not increase.

---

### States and Transitions

| State | Condition | Trigger to next state |
|-------|-----------|----------------------|
| Level 1 (start) | `cumulative_xp < threshold[2]` | XP gain crosses threshold[2] |
| Level 2–9 | `threshold[L] ≤ cumulative_xp < threshold[L+1]` | XP gain crosses threshold[L+1] |
| Level 10 (cap) | `cumulative_xp ≥ threshold[10]` | Terminal — no further level transitions |

`threshold[L]` is the cumulative XP required to reach level L, computed by CP-F1.

---

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Turn-Based Combat** (upstream) | Emits `battle_ended(VICTORY, enemy_id, fired_break_events)` plus whether the battle was BOSS or WILD, plus which Symbots were deployed | This system receives the signal and awards XP per Rules 3–4 |
| **Symbot Assembly** (downstream) | Assembly invokes the equip gate (Rule 4) on every equip call; reads `level_growth` from the core's SympartData and applies the CP contribution step | Assembly is the only system that calls the gate-check; this system never directly blocks equip — it exposes `can_equip(core_instance_id, part)` → bool |
| **Part Database** *(erratum pending)* | Defines `level_requirement: int` and `level_growth: Dictionary[String, int]` on all SympartData | Source of gate thresholds and per-core growth authored values |
| **Exploration Progress** (downstream) | Serializes `CoreProgressionRecord` (cumulative_xp per core instance_id); state is always re-derived on load (level re-computed from cumulative_xp, never read from serialized level) | Persistence layer only |
| **Workshop System** (downstream) | Reads `core.level` and `cumulative_xp` for display; forwards Assembly's gate-check result as a UI validation message | Display and equip routing only |

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
