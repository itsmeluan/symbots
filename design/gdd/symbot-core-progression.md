# Symbot Core Progression (Leveling)

> **Status**: **APPROVED (2026-07-13)** — 4th-pass full-panel confirmation re-review + all 4 condition-of-approval errata (ST-1..ST-4) discharged + /consistency-check PASS + user acceptance. C-2 + D-2 re-confirmed RESOLVED by full panel; NEEDS REVISION (light) → **2 in-doc fixes applied**, then the 4 errata applied across sibling docs. **In-doc DONE this pass:** (1) AC-CP-21 worked examples rewritten with explicit `float()` casts + DF-1 float-cast contract cross-ref (qa-lead R4-B2 int/int truncation trap; values 53/10 unchanged); (2) Rule 2 + EC-CP-02 dead "consumers iterate the crossed range" clause removed — no current per-level-unlock consumer exists (game-designer #6). **Prior-pass in-doc DONE:** logging-spy interface (Rule 1), AC-CP-22 cooling portion ADVISORY-until-established, AC-CP-21 discriminating fixture, OQ-CP-6 CD ratification, OQ-CP-8 re-derived + orphan flagged, AC-CP-18 traceability. **4 producer-tracked errata stories (CD condition of approval) — ALL APPLIED this session** (see `production/errata-backlog.md`): ST-1 → ELZS (**AC-ELZS-14** equip-gate coverage AC + the **Rule 3a boss completion bonus** lever, Boss 1 = 310 / Boss 2 = 180, resolving OQ-CP-8); ST-2 → Symbot Assembly (**AC-SA-15** gating AC-CP-18); ST-3 → TBC (**Rule 2 step 0 + AC-TBC-42** `is_build_valid()` refusal for EC-CP-05); ST-4 → Consumable DB (CD-1/CD-3 ranges → [60,612]/[80,147] + **AC-CD-03 case C** max_energy=147). New CP-side AC this pass: **AC-CP-24** (boss bonus award). **Remaining:** light `/design-review` confirmation touches on the 4 mechanically-amended sibling docs (their Status stays APPROVED); CP itself is now Approve-ready — the CD's condition of approval is met.)
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-13
> **Supports Pillar**: Pillar 1 (Engineer, Don't Collect) and Pillar 3 (Build Depth Over Content Breadth) — this is a **support/pacing** system: it *gates and paces* access to the build depth those pillars deliver, it does not itself implement them (cf. Consumable DB tagging). Anti-pillar defense: NOT a level-matching treadmill — "levels set the stage; the workshop wins the fight."

## Overview

The Symbot Core Progression System is the runtime authority for every Symbot core's experience points, level, and level-gated stat growth. It owns three responsibilities: (1) **XP tracking** — receiving XP awards from Turn-Based Combat at battle end and distributing them to active and benched core slots according to the bench share rule; (2) **level derivation** — converting cumulative XP into a discrete level using the CP-F1 XP-to-level formula; and (3) **equip gating** — enforcing the `level_requirement` field that Part Database authors set on parts, blocking equip via the Workshop if the occupying core's level is below threshold.

This system does not own stat computation — the per-level stat gains it stores are read by Symbot Assembly and feed into the SA-F1 pipeline alongside the part's own stat bonuses. It does not own the Workshop equip flow — it exposes a gate-check call that Assembly invokes on equip. It does not own XP award amounts — each defeated enemy carries an `xp_value` (derived from its **enemy level**, owned by the Enemy Database), and Turn-Based Combat passes that value in at battle end. Higher-level enemies award more XP.

Core level is the sole player-side output that gates access to high-tier parts. It cannot be purchased — the only path is battle XP. Scrap currency upgrades parts; battle XP levels cores. These two axes are intentionally non-substitutable.

**This GDD is the player-side authority of the Level Backbone.** The Level Backbone is the game's unified leveling model, introduced 2026-07-12: **enemy level** (Enemy DB — drives enemy power, XP reward, and drop quality), **zone level range** (Encounter Zone — floor/roof levels that gradient the world's difficulty), and **core level** (this system — the player's access/investment leg). This GDD owns only the core-level (player) side and how enemy level converts to awarded XP. The enemy-level and zone-range sides are designed in the separate **Enemy Level & Zone Scaling** system (see Dependencies and the Cross-Document Change Manifest in Open Questions).

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

**Core acquisition:** CORE-slot parts enter Inventory via the standard Drop System (enemy drops from specific enemy types, following standard drop mechanics) or as a starter gift at game start (`drop_enabled = false`, never hunted). The bench XP mechanic therefore becomes relevant only when the player holds ≥ 2 cores and has added a second to their active roster. A player with only 1 core on their team roster earns full XP from the deployed slot; there are no bench rows to populate. Early-game, the player will likely have a single Symbot for their first several encounters — this is expected and correct.

**Interface:** this system exposes `register_core(core_instance_id: int) -> void`. The caller (Inventory, or whoever adds the core to the player's collection) invokes this on first-add. Calling `register_core` with an already-registered `core_instance_id` is a no-op with a content warning logged. No other system creates `CoreProgressionRecord` entries.

**Injected logger (testability contract).** All content warnings and content errors this system emits (Rule 1 duplicate-register, EC-CP-08 unknown stat key, EC-CP-09 absent `xp_value`, EC-CP-10 negative `cumulative_xp`, and the AC-CP-23 `BENCH_XP_SHARE` startup assertion) MUST route through the **injected `LogSink`** dependency (ADR-0002 contract: `warn(code: StringName, detail: Dictionary)` and `error(code: StringName, detail: Dictionary)`) — never GDScript's global `push_warning()`/`push_error()`. Production injects an engine-output wrapper; unit tests inject a spy that captures codes and detail payloads for assertion. Without this injection point, AC-CP-09/10/11/12/23 (which assert on logged warning/error content via a logging spy) are not unit-testable in GUT, since engine console output cannot be intercepted. *(qa-lead R3-E, 2026-07-13 — mirrors the Rule 1 `register_core` interface fix from the prior round.)*

---

**Rule 2 — Level derivation.** Level is a deterministic function of `cumulative_xp`, computed via CP-F1 (the XP threshold table). The table is derived from a base cost of `XP_PER_LEVEL_BASE` with a `LEVEL_COST_RAMP` multiplier per level (see Formulas). Level never decreases. After any XP gain, re-derive level and emit `core_leveled_up(core_instance_id, old_level, new_level)` if level increased. Multiple levels in a single XP gain are possible — in this case, emit **once** with the final span (`old_level → new_level`). The signal carries both endpoints so that any *future* consumer requiring per-level handling could iterate the crossed range itself — but **no current consumer does**: Workshop UI re-reads the current level for display, and the equip gate (Rule 4) re-checks synchronously on each equip attempt. Do not add per-level iteration to a consumer until a system that genuinely unlocks per-level content is designed (at which point add its EC + a verifying AC).

---

**Rule 3 — XP award at battle end.** On `battle_ended(VICTORY, ...)`:

1. Read `full_xp = defeated_enemy.xp_value + bonus`, where `bonus = defeated_enemy.completion_bonus_xp` **if and only if** `battle_ended.is_first_boss_defeat == true`, **else `bonus = 0`** (Rule 3a first-defeat guard). `xp_value` is the per-enemy XP value (derived from the enemy's level by the Enemy Database via CP-F4; see Formulas); `completion_bonus_xp`, `is_first_boss_defeat`, `xp_value` all ride the `battle_ended` payload. `completion_bonus_xp` is `0` for WILD enemies and non-zero only on BOSS entries; `is_first_boss_defeat` is `true` only on a BOSS's **first-ever** defeat (`false` for WILD and for every boss refight — see Rule 3a). This system does not compute these values — it consumes what TBC hands it, and applies the first-defeat guard.
2. For each Symbot in the active team roster (up to `TEAM_ROSTER_CAP` = 3):
   - If the Symbot was **deployed** (fielded at any point during the battle): award `full_xp` to its core.
   - If the Symbot was **not deployed** (was in the team roster but never switched in): award `floor(full_xp × BENCH_XP_SHARE)` to its core (CP-F2).
3. On `battle_ended(DEFEAT, ...)` or `battle_ended(FLED, ...)`: no XP is awarded to any core.

**"Deployed"** is tracked by TBC's existing switch state — if a Symbot was the active fighter at any point during the battle (including entering as the start-of-battle active Symbot), it counts as deployed.

**Bench-level cap guard (anti-power-leveling):** A benched core only earns XP toward levels it could plausibly reach in the current zone. If `benched_core.level >= defeated_enemy.level + BENCH_LEVEL_LEAD_CAP`, the bench award is 0 for that core — a max-level veteran benched in a low-level zone does not vacuum XP from trivial fights. This prevents a player from parking a strong core to farm easy zones for free levels. (Deployed cores are never capped this way — actively fighting always earns.)

**Rule 3a — Boss completion bonus (equip-gate pacing; resolves OQ-CP-8).** A defeated BOSS carries a flat `completion_bonus_xp` (an Enemy DB field, authored per boss; `0` on WILD enemies) that is added to `full_xp` **before** the deployed/benched distribution in Rule 3 step 1 — so a deployed core earns `xp_value + completion_bonus_xp` and a benched core earns `floor((xp_value + completion_bonus_xp) × BENCH_XP_SHARE)` subject to the lead cap.

**First-defeat guard (BLOCKING — the bonus is once-per-boss, never farmable).** The completion bonus is awarded **only on a boss's first-ever defeat** — gated on the `is_first_boss_defeat` payload flag (`true` iff `enemy_class == BOSS` **and** the boss's `defeated_once` was `false` at battle start). On any **boss refight**, `is_first_boss_defeat == false`, so `bonus = 0` and the deployed core earns `xp_value` alone (the standard CP-F4 boss XP, e.g. Boss 1 = 170). **Why this guard is mandatory:** both MVP bosses are refightable via Encounter Zone `LIGHTER_REGATE` (Boss 1 after +2 WILD wins, Boss 2 after +3). Without the guard, the +310/+180 bonus would repeat every refight — ~480 XP per ~2 trivial fights (~5.3× WILD XP density), power-leveling any core to `MAX_CORE_LEVEL` in ~4–5 Boss-1 refights and blowing past every equip gate. That is the exact anti-treadmill / "patient investment" fantasy violation this system exists to prevent (a farmable pacing lever is a treadmill). **Ownership of the signal:** `defeated_once` is owned by Zone & World Map (Rule 8, stored by Exploration Progress) and already read at boss-approach for gating; the boss-approach / Overworld Navigation layer computes `is_first_boss_defeat` from the *pre-battle* `defeated_once` (before ZWM flips it on this victory) and hands it to TBC, which relays it in `battle_ended`. Passing the pre-battle value makes the guard **ordering-independent** — CP does not depend on reading `defeated_once` before ZWM flips it (TBC Rule 12 does not guarantee subscriber ordering). *Verified by AC-CP-25 (refight awards no bonus) — the discriminating companion to AC-CP-24 (first defeat awards the bonus).* The bonus does **not** affect the ELZS AC-ELZS-14 first-clear coverage math (that AC is about the first defeat, which still awards the full bonus). **This bonus is deliberately NOT derived from CP-F4** (it is not `enemy_level`-scaled): a boss victory is the emotional beat where the Player Fantasy promises the boss's drop "finally became equippable," so the bonus is sized per-boss to land the deployed core at (or just past) the equip gate for the rarity that boss drops — even on the zone's worst-case (floor-level) approach path. **Why a per-boss flat value and not a bigger `BOSS_XP_MULTIPLIER`:** the two MVP bosses sit at different distances from their gates (Boss 1 → Boss-grade L6; Boss 2 → Prototype L8), so a single multiplier cannot close both gaps independently without over/undershooting one (OQ-CP-8 single-lever caution). The bonus **values** are calibrated by the Enemy Level & Zone Scaling pass against the equip-gate coverage AC (ELZS AC-ELZS-14, ST-1) — MVP: Boss 1 = **310**, Boss 2 = **180**. The *mechanism* (award-on-boss-victory, folded into `full_xp`) is owned here; the *field* is Enemy DB content; the *values* are ELZS-calibrated. Because the bonus lands the deployed core inside — not past — the next gate's threshold (Boss 1 → L6 with margin below `threshold[7]`; Boss 2 → L8 below `threshold[9]`), it does not shortcut later gates.

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

**Rule 6 — Stat growth integration.** A core part's PartDef includes a `level_growth` dictionary: `stat_key → int bonus_per_level`. This is a new field added to PartDef via Part DB erratum — only present on `CORE` slot parts (other slots have `null` or empty dict).

**Rule 6a — Power stats are forbidden in `level_growth` (DF-1 domain guard).** `physical_power` and `energy_power` MUST NOT appear as keys in any core's `level_growth` dictionary. Rationale: CP-F3 is applied *before* SYN-F4, so growth in a power stat stacks with the synergy power budget (SYNERGY_POWER_BUDGET = 40) on top of the SA-F1 base (max 110). Allowing `energy_power` growth pushed the attacker-power input `A` to `110 + 18 + 40 = 168`, outside Damage Formula DF-1's declared and float-scanned domain `A ∈ [0, 150]` (see damage-formula.md). Prohibiting power stats keeps `A ≤ 150` with zero DF-1 change and no re-scan. This also enforces the anti-pillar: **leveling gates and paces access; it must never directly raise raw damage output.** Part DB content validation enforces this (AC-CP-22). Defensive/utility/resource stats (`structure`, `energy_capacity`, `cooling`, `armor`, `resistance`, `mobility`, etc.) remain permitted.

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
| **Turn-Based Combat** (upstream) | Emits the eight-field `battle_ended` (see TBC Rule 12): outcome, `enemy_id`, `fired_break_events`, `xp_value`, `completion_bonus_xp`, `is_first_boss_defeat`, `enemy_level`, `deployed_symbot_ids` | This system receives the signal and awards XP per Rules 3–3a–4 (bonus folded into `full_xp` only when `is_first_boss_defeat`) |
| **Symbot Assembly** (downstream) | Assembly invokes the equip gate (Rule 4) on every equip call; reads `level_growth` from the core's PartDef and applies the CP contribution step | Assembly is the only system that calls the gate-check; this system never directly blocks equip — it exposes `can_equip(core_instance_id, part)` → bool |
| **Part Database** *(erratum pending)* | Defines `level_requirement: int` and `level_growth: Dictionary[String, int]` on all PartDef | Source of gate thresholds and per-core growth authored values |
| **Inventory** (upstream caller) | Calls `register_core(core_instance_id)` when a CORE-slot part is first added to the player's collection | Record creation only; Inventory does not read progression state |
| **Exploration Progress** (downstream) | Serializes `CoreProgressionRecord` (cumulative_xp per core instance_id); state is always re-derived on load (level re-computed from cumulative_xp, never read from serialized level) | Persistence layer only |
| **Workshop System** (downstream) | Reads `core.level` and `cumulative_xp` for display; forwards Assembly's gate-check result as a UI validation message | Display and equip routing only |

## Formulas

> **Calibration note:** CP-F1's arc pacing and CP-F4's XP outputs both depend on the MVP zone's `enemy_level_floor`/`enemy_level_roof`, which are owned by the **Enemy Level & Zone Scaling** system (not yet designed). The constants below are **provisional first-pass values** and must be re-calibrated once the MVP zone's level range is set. The *formula structure* is stable; the constants are tuning knobs.

### CP-F1 — XP-to-Level Threshold Table (player side)

Converts a core's `cumulative_xp` to its level. Thresholds derive from `XP_PER_LEVEL_BASE` with a `LEVEL_COST_RAMP` multiplier per step:

`threshold[L] = Σ (XP_PER_LEVEL_BASE × LEVEL_COST_RAMP^(k-1)) for k = 1 .. (L-1)`

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `cumulative_xp` | int | [0, ∞) | Total XP earned by this core instance |
| `XP_PER_LEVEL_BASE` | int | 100 | XP cost of the first level-up (1→2) |
| `LEVEL_COST_RAMP` | float | 1.20 | Multiplicative cost increase per level |
| `MAX_CORE_LEVEL` | int | 10 | Hard level cap |

**Threshold table (pre-computed — use this table directly at runtime, do not re-run the ramp formula):**

| Level | Cumulative XP required | Per-level cost |
|-------|----------------------|----------------|
| 1 | 0 (start) | — |
| 2 | 100 | 100 |
| 3 | 220 | 120 |
| 4 | 364 | 144 |
| 5 | 537 | 173 |
| 6 | 744 | 207 |
| 7 | 993 | 249 |
| 8 | 1,292 | 299 |
| 9 | 1,650 | 358 |
| 10 | 2,080 | 430 |

**Output:** `level = L` where `threshold[L] ≤ cumulative_xp < threshold[L+1]` (capped at `MAX_CORE_LEVEL`). Pure sorted-integer lookup at runtime — no float arithmetic.

**Derivation procedure (use when extending the table for a new `MAX_CORE_LEVEL` value within the safe range 8–12):** For each level k (k ≥ 2), the per-level cost = `round(XP_PER_LEVEL_BASE × LEVEL_COST_RAMP^(k-2))`. Accumulate the running sum of these rounded per-step values to obtain each threshold — do not round the cumulative total itself. Example: k=5 → `round(100 × 1.20^3) = round(172.8) = 173`; threshold[5] = 100+120+144+173 = 537.

---

### CP-F4 — Enemy XP Value from Enemy Level (bridge formula)

Each enemy's `xp_value` is derived from its **enemy level** (owned by Enemy DB / Enemy Level & Zone Scaling). This system defines the conversion because XP is its concern; the resulting `xp_value` is stored on the Enemy DB entry and passed to this system via `battle_ended`.

`xp_value = (XP_BASE + enemy_level × XP_PER_ENEMY_LEVEL) × role_multiplier`

| Variable | Type | Value (provisional) | Description |
|----------|------|---------------------|-------------|
| `enemy_level` | int | [1, MAX_ENEMY_LEVEL] | The defeated enemy's level (Enemy DB) |
| `XP_BASE` | int | 35 | Flat XP floor at level 0 |
| `XP_PER_ENEMY_LEVEL` | int | 10 | XP added per enemy level |
| `role_multiplier` | int | WILD = 1, BOSS = `BOSS_XP_MULTIPLIER` = 2 | Bosses award double |

**Output:** a positive integer. **Pure integer arithmetic — no floor, no float, no epsilon** (all multipliers are integers; `int × int` is exact in GDScript). Worked values at provisional constants:

| Enemy | Level | xp_value |
|-------|-------|----------|
| WILD-early | 1 | (35 + 10) × 1 = **45** |
| WILD-mid | 3 | (35 + 30) × 1 = **65** |
| WILD-mid | 5 | (35 + 50) × 1 = **85** |
| BOSS 1 | 5 | (35 + 50) × 2 = **170** |
| BOSS 2 | 6 | (35 + 60) × 2 = **190** |

This preserves the prior flat calibration's *scale* (a mid-level WILD ≈ 65, a boss ≈ 170–190) while making tougher enemies award proportionally more, and it gives level a second job (defining XP) exactly as intended.

**Ownership note (explicit — resolves the `→` notation).** CP-F4 and its constants (`XP_BASE`, `XP_PER_ENEMY_LEVEL`, `BOSS_XP_MULTIPLIER`) are **authored and owned here** (Core Progression, because XP is this system's concern). The Enemy Level & Zone Scaling (ELZS) system holds a **calibration obligation only**: it sets the enemy `level` distribution and MVP zone level range (OQ-CP-1), against which these provisional constants are re-tuned. It does **not** re-derive or re-own the formula. The `*(→ Enemy Level & Zone Scaling)*` tag in Tuning Knobs means exactly this: *value provisional, awaiting ELZS calibration input; formula ownership stays here.* When ELZS is (re)visited, its Dependencies section must list CP-F4 as a **read-only reference it calibrates, not owns**, and Enemy DB stores the resulting `xp_value` per this formula's output.

---

### CP-F2 — Bench XP Award

`bench_xp = floor(full_xp × BENCH_XP_SHARE)`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `full_xp` | int | = defeated enemy's `xp_value` (CP-F4) | The XP a deployed core earns |
| `BENCH_XP_SHARE` | float | 0.5 (exactly) | Fraction awarded to non-deployed team members |

**Output range:** `[0, floor(full_xp × 0.5)]`. **No epsilon guard required** — `BENCH_XP_SHARE = 0.5 = 2⁻¹` is exactly representable in IEEE 754, so `N × 0.5` is exact for all integer N (odd N → exact `X.5`, `floor(X.5) = X` correctly). *If BENCH_XP_SHARE is ever changed to a non-power-of-2 value, add a `+ 0.0001` epsilon guard and run a python3 scan.*

**Example:** `floor(65 × 0.5) = 32`; `floor(170 × 0.5) = 85`. Subject to the Rule 3 bench-level-cap guard (a benched core at `level ≥ enemy_level + BENCH_LEVEL_LEAD_CAP` earns 0).

---

### CP-F3 — Level-Growth Stat Contribution

Applied per stat key in the equipped core's `level_growth` dictionary, after SA-F1 and before SYN-F4:

`level_contribution[stat_key] = level_growth[stat_key] × (core.level − 1)`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `level_growth[stat_key]` | int | [0, N]; authored per core | Per-level flat bonus for this stat; 0 = no growth in this stat |
| `core.level` | int | [1, 10] | Current derived level of the equipped core |

**Output range:** `[0, level_growth[stat_key] × 9]` (max at level 10). **Pure integer multiplication — no floor, no float, no epsilon.** At level 1 the contribution is always 0.

**Authoring reference (Spark Core — energy-focused):**

| Stat | `level_growth` | Max (level 10) | Rationale |
|------|---------------|----------------|-----------|
| `structure` | 2 | +18 | Modest survivability (~15–22% of expected base) |
| `energy_capacity` | 3 | +27 | Primary identity stat (resource-pool growth, not damage) |
| `cooling` | 1 | +9 | Light — Heat management is player skill, not level reward |
| All other stats | 0 | 0 | Grow via part choices, not level |

> **Power stats removed (Rule 6a, /design-review 2026-07-13):** the prior reference grew `energy_power` at 2/level (+18 at L10). That breached DF-1's `A ∈ [0,150]` domain (110 SA-F1 + 18 CP-F3 + 40 synergy = 168). Power growth is now prohibited (Rule 6a). Total L10 contribution is now **54 stat-points across 3 stats** (was 72). Removing power growth also better serves the fantasy: leveling extends the resource pool that enables *more moves*, not the raw damage per move.

**Interaction with part-derived stat ceilings (range re-annotation).** CP-F3 growth is **additive on top of** the part-derived SA-F1 output ranges — it is not bounded by them. A leveled CORE therefore legitimately raises a stat above its part-only ceiling. Concretely at level 10 with this reference: `energy_capacity` max `120 → 147`; `structure` max `594 → 612`. This is intended (the CORE's leveled anchor adds a pool parts alone cannot reach). The falsified part-only ceilings are re-annotated at their source — see the Symbot Assembly SA-F1 output table and Consumable DB CD-1/CD-3 errata (Bidirectionality Notes). Downstream clamp formulas (`min(max_energy, …)`, `min(max_structure, …)`) read the runtime max and self-correct; only the *documented* ceilings needed updating.

**Anti-grind invariant (honest statement — verified by AC-CP-21).** The invariant is **bounded-edge, not build-dominant-at-parity**:

- Total level-10 contribution is 54 stat-points across 3 non-power stats. Against a *well-built* core (all-Rare parts, the AC-CP-21 reference baseline), each per-stat contribution is ≤ ~25% of that stat's reference pool.
- **The invariant is NOT "a leveled core is always beaten by a lower-level one."** At *equal part rarity and equal type matchup*, the higher-level core wins on CP-F3 accumulation — level is designed to matter somewhat. What the invariant guarantees is narrower and testable: **a lower-level core that holds a build-quality advantage AND a type-matchup advantage out-damages a higher-level core that holds neither** (AC-CP-21). Level never overrides the combination of build + type mastery — the two pillars this system supports.
- Because power stats are excluded (Rule 6a), leveling never raises raw damage directly; the CP-F3 stats (`structure`/`energy_capacity`/`cooling`) affect survivability and resource economy, keeping raw offense a function of parts + synergy + type.

**AC-CP-21 reference baseline (well-built Spark Core, all-Rare parts, no synergy).** So the 25%-ceiling and the invariant are measurable, the reference build's SA-F1 per-stat outputs are fixed here (illustrative Rare-tier values; re-derive and re-run AC-CP-21 if SA-F1 tier outputs are retuned):

| Stat | SA-F1 reference output (all-Rare) | CP-F3 L10 add | CP-F3 as % of reference |
|------|-----------------------------------|---------------|-------------------------|
| `structure` | ~260 | +18 | ~7% |
| `energy_capacity` | ~110 | +27 | ~25% (ceiling) |
| `cooling` | ~40 | +9 | ~22% |

`energy_capacity` sits at the 25% ceiling against a well-built reference — this is the binding stat and the reason its growth is not raised further. Any future core whose `sum(level_growth[stat] × 9)` for a single stat exceeds 25% of that stat's all-Rare reference output fails the authoring guidance (AC-CP-22).

## Edge Cases

**EC-CP-01 — Core at max level gains XP.** *If* a level-10 core is awarded XP: the XP beyond `threshold[10]` is discarded (not banked), `cumulative_xp` is held at `threshold[10]`, and the core stays level 10. No overflow, no wrap. *Verified by AC-CP-06.*

**EC-CP-02 — Single XP gain crosses multiple level thresholds.** *If* one XP award pushes `cumulative_xp` past two or more thresholds (e.g., a low-level core defeats a high-XP boss): the core jumps directly to the correct final level, and `core_leveled_up(id, old_level, new_level)` fires once with the full span (`old_level` → `new_level`). The signal carries both endpoints so a future per-level-unlock consumer *could* iterate the crossed range; no current consumer requires this (see Rule 2). *Verified by AC-CP-03.*

**EC-CP-03 — Benched core at or above the level-lead cap.** *If* `benched_core.level ≥ defeated_enemy.level + BENCH_LEVEL_LEAD_CAP`: the bench award for that core is 0 (Rule 3 guard). A max-level veteran benched in a low-level zone earns nothing from trivial fights, preventing free power-leveling. *Verified by AC-CP-08.*

**EC-CP-04 — Equip blocked by level_requirement.** *If* the player attempts to equip a part whose `level_requirement` exceeds the build's core level: the equip is rejected, no part is displaced, no Inventory change occurs, and an error message is returned. *Verified by AC-CP-04.*

**EC-CP-05 — Core swap invalidates already-equipped parts.** *If* the player swaps the CORE slot to a lower-level core, and parts already in other slots now exceed the new core's level: the previously-equipped parts are **not** auto-unequipped (no silent data loss), but the build is flagged invalid and Workshop UI must surface a validation warning listing the offending parts. The build cannot enter combat while invalid. **Ownership of the combat block:** this system exposes `is_build_valid(symbot_build) -> bool` (returns false iff any equipped part's `level_requirement > core.level`); the "cannot enter combat" enforcement is **owned by Turn-Based Combat / Overworld Navigation**, which MUST call `is_build_valid()` before starting a battle and refuse an invalid build. This obligation is tracked in Bidirectionality Notes so it is not left orphaned in edge-case prose. *Verified by AC-CP-05 (flagging/list side, this system); the combat refusal is verified by **Turn-Based Combat AC-TBC-42** (added by erratum ST-3, 2026-07-13 — battle refused at start if any fielded build is invalid).*

**EC-CP-06 — Load: stored level disagrees with cumulative_xp.** *If* a save's serialized `level` does not match what CP-F1 derives from `cumulative_xp` (drift, tampering, or a curve retune between versions): the level is **re-derived from cumulative_xp** on load — the serialized `level` field is a display cache and is never trusted. *Verified by AC-CP-07.*

**EC-CP-07 — Core instance with no CoreProgressionRecord.** *If* a core part instance exists in Inventory but has no `CoreProgressionRecord` (newly acquired core, or a drifted save): a record is created with `cumulative_xp = 0, level = 1`. Cores are never level-less. *Verified by AC-CP-09.*

**EC-CP-08 — level_growth references an unknown stat key.** *If* a core's `level_growth` dictionary contains a key not in the canonical 11 stats: log a content warning and skip that key (mirrors Assembly EC-SA-05 / Part DB EC-08). Other keys apply normally; no crash. *Verified by AC-CP-10.*

**EC-CP-09 — Enemy xp_value is 0 or absent.** *If* `defeated_enemy.xp_value` is 0 or missing (content error, or an intentionally XP-less enemy): all cores are awarded 0 XP for that battle, no level changes, no crash. A content warning is logged if the field is absent (distinct from an intentional 0). *Verified by AC-CP-11.*

**EC-CP-10 — Negative cumulative_xp on corrupt load.** *If* a loaded `cumulative_xp` is negative (corruption or manual save edit): clamp to 0, log a content error, and re-derive level (→ 1). XP is semantically non-negative. *Verified by AC-CP-12.*

**EC-CP-11 — Non-CORE part carries level_growth.** *If* a part in a non-CORE slot has a non-empty `level_growth` (authoring error — the field is CORE-only): it is ignored. Only the `level_growth` of the part in the CORE slot is read by CP-F3. *Verified by AC-CP-13.*

**EC-CP-12 — Defeated but max-level deployed core.** *If* a deployed core is already level 10 when the battle is won: it earns 0 (EC-CP-01) but still **counts as deployed** — its presence does not change the XP awarded to other team members. Each core's award is computed independently. *Verified by AC-CP-06.*

**EC-CP-13 — Boss refight (already defeated once).** *If* a BOSS is defeated again after its first defeat (`is_first_boss_defeat == false`, e.g. a `LIGHTER_REGATE` refight): only `xp_value` is awarded — the `completion_bonus_xp` is **not** re-granted (Rule 3a first-defeat guard). The bonus is a once-per-boss equip-gate nudge, not a farmable XP faucet; refights pay the standard CP-F4 boss XP only. *Verified by AC-CP-25.*

## Dependencies

### Upstream Dependencies (what this system requires)

| System | What this system reads/receives | Hard/Soft | Status |
|--------|--------------------------------|-----------|--------|
| **Turn-Based Combat** | `battle_ended(outcome, enemy_id, ...)` carries `xp_value`, `completion_bonus_xp`, `is_first_boss_defeat`, `enemy_level`, and the set of **deployed** Symbots (see TBC Rule 12 for the full eight-field payload) | **Hard** — no XP awards without the battle-end signal | Approved ✓ *(payload extension applied — Level Backbone ST-1 + refight-guard erratum 2026-07-13; OQ-TBC-6 resolved)* |
| **Enemy Database / Enemy Level & Zone Scaling** | Enemy `level` and derived `xp_value` (CP-F4) | **Hard** — XP is a function of enemy level | Enemy DB Approved ✓; **Enemy Level & Zone Scaling Not Started** (new tracked system) |
| **Part Database** | `level_requirement: int` (equip gate, Rule 4/5) and `level_growth: Dictionary[String, int]` (CP-F3, CORE parts only) | **Hard** — no gate or stat growth without these fields | Approved ✓ *(erratum pending — two new fields)* |

### Downstream Dependents (what depends on this system)

| System | What it reads/calls | Status |
|--------|--------------------|--------|
| **Symbot Assembly** | Calls `can_equip(core_instance_id, part)` on every equip (Rule 4); reads the equipped core's `level_growth` and applies the CP-F3 contribution step in its pipeline | Approved ✓ *(erratum pending — gate call + CP-F3 step)* |
| **Exploration Progress** | Serializes/restores every `CoreProgressionRecord` (`cumulative_xp` per `core_instance_id`); level always re-derived on load, never trusted from disk (EC-CP-06) | Not Started |
| **Workshop System** | Reads `core.level` / `cumulative_xp` for display; routes the equip-gate result; flags invalid builds (EC-CP-05) | Not Started |
| **Workshop UI** | Level display on core slot, level-up notification, greyed-out parts with "Core level N required" tooltips, invalid-build warning banner | Not Started |

### Bidirectionality Notes (errata obligations)

- **Turn-Based Combat erratum:** `battle_ended` must carry `xp_value`, enemy `level`, and the deployed-Symbot set. OQ-TBC-6 (currently records "no XP — concept: no level grind") must be updated to reflect the Level Backbone.
- **Part Database erratum:** add `level_requirement: int` and `level_growth: Dictionary[String, int]` to the Sympart schema; author `level_requirement` per Rule 5's rarity table; author `level_growth` on CORE parts only.
- **Symbot Assembly erratum:** wire the equip gate call (Rule 4) and insert the CP-F3 contribution step between SA-F1 and SYN-F4. Discharges Assembly's open **"CORE identity mechanical enforcement"** Deferred Obligation — the CORE now has mechanical teeth (leveled anchor + gate). **Traceability requirement (qa-lead R3-C, 2026-07-13):** AC-CP-18 (the DEFERRED pipeline-ordering test proving CP-F3 sits *between* SA-F1 and SYN-F4) currently has its DoD gate expressed only as prose in this GDD's Coverage Check — the Assembly GDD carries no AC referencing it, so an Assembly erratum story could close without ever running it. The Assembly erratum **MUST add an explicit `AC-SA-XX` that names AC-CP-18 as a required gate** on the CP-F3-insertion story; without it, a wrong insertion point (before SA-F1, or after SYN-F4) ships untested since no non-deferred AC catches it. **DISCHARGED (ST-2, 2026-07-13):** `AC-SA-15` added to symbot-assembly.md — an Integration test (M=1.2, level-5 CORE, contribution 40, SA-F1 output 120 → expects 160 not 168) that names AC-CP-18 as a binding DoD gate on the CP-F3-insertion story.
- **Enemy Level & Zone Scaling (new system)** owns: Enemy DB `level` + `xp_value` fields (CP-F4 output storage), Encounter Zone `enemy_level_floor`/`enemy_level_roof`, Zone & World Map `difficulty_band`↔level-range mapping, and Drop System level→rarity/stat-roll influence. This system (Core Progression) depends on its enemy-level output but does not own it.
- **Inventory erratum:** Inventory must call `register_core(core_instance_id)` whenever a CORE-slot part is added to the player's collection. This is a one-way call — no progression state flows back. Inventory does not read `CoreProgressionRecord` fields; it only triggers record creation.
- **No reverse dependency on Inventory:** `CoreProgressionRecord` is keyed by the Inventory `instance_id` but this system never queries Inventory for data.
- **Symbot Assembly range re-annotation (erratum owed):** CP-F3 growth is additive on top of the SA-F1 output ranges. Assembly's SA-F1 "Output ranges" table must annotate that a leveled CORE raises `energy_capacity` above its part-only ceiling (`120 → up to 147` at L10 with the Spark Core reference) and `structure` (`594 → up to 612`). The ranges are part-derived; CP-F3 adds on top. *(C-2 downstream; falsified-range fix.)*
- **Consumable DB range re-annotation (erratum owed):** Consumable DB CD-1/CD-3 cite `max_structure ∈ [60,594]` and `max_energy ∈ [80,120]` as SA-F1-owned. Both must be re-annotated as **part-derived ceilings; a leveled CORE's CP-F3 growth adds on top** (`max_energy` up to ~147, `max_structure` up to ~612). The CD-1/CD-3 clamp formulas already read the runtime max and self-correct — only the cited documentation ranges and the Power Cell/`+50`-on-80-cap balance note are stale. *(C-2 downstream.)*
- **`cooling` has no declared SA-F1 ceiling (owed — blocks AC-CP-22 cooling portion):** unlike structure/energy_capacity, no approved GDD declares a `cooling` output range. Part DB / SA-F1 must add one so CP-F3's `cooling: 1` (+9 at L10) can be range-checked. **Until it lands, AC-CP-22 check (B) for `cooling` is ADVISORY-until-established, not BLOCKING** (a test would otherwise hardcode the unverified `~40` and could falsely pass). Promote to BLOCKING when the SA-F1 cooling range is authored. *(C-2 gap; converged re-review finding 2026-07-13.)*
- **`REFERENCE_SA_F1_OUTPUT` table is not registry-anchored (owed):** the `structure ~260` / `energy_capacity ~110` / `cooling ~40` reference outputs used by AC-CP-21 and AC-CP-22 are illustrative all-Rare estimates local to this GDD, not constants in the registry or an approved SA-F1 change-propagation chain. If SA-F1 Rare-tier tier outputs are retuned, this table must be re-derived and AC-CP-21/AC-CP-22 re-run. Add a registry cross-reference (or an SA-F1 erratum obligation) so this drift path is not silent. *(systems-designer finding 2026-07-13.)*
- **Turn-Based Combat / Overworld Navigation `is_build_valid` (DISCHARGED — ST-3, 2026-07-13):** the "invalid build cannot enter combat" invariant (EC-CP-05) is enforced by whichever system starts battles calling this system's `is_build_valid(symbot_build)`. **TBC now owns this** — Rule 2 step 0 (battle-start build-validity precondition) + **AC-TBC-42** (BLOCKING: an invalid build is refused at battle start, no runtime state created). Core Progression is added to TBC's upstream dependencies as a Hard read. Overworld Navigation (Not Started) SHOULD additionally gate the encounter earlier (pre-hand-off) so the player is warned at the Workshop, not the battle screen — TBC's check is the authoritative last line of defense.

## Tuning Knobs

| Knob | Type | Value | Owner | Effect / Safe guidance |
|------|------|-------|-------|------------------------|
| `XP_PER_LEVEL_BASE` | int | 100 | This system | Cost of level 1→2. Raising it slows all leveling proportionally. Safe range 60–150. |
| `LEVEL_COST_RAMP` | float | 1.20 | This system | Per-level cost multiplier. 1.0 = flat curve; higher = back-loaded grind. Safe range 1.10–1.35. Above ~1.4 the level-9→10 wall becomes a grind; at 1.0 late levels feel unearned. |
| `MAX_CORE_LEVEL` | int | 10 | This system | Level cap. Determines the whole curve's scope and the top of every `level_requirement`. Changing it requires re-authoring the Rule 5 rarity gate table. Safe MVP range 8–12. |
| `XP_BASE` | int | 35 | This system *(→ Enemy Level & Zone Scaling)* | Flat floor in CP-F4. Sets the XP of a level-0 reference enemy. Provisional — re-calibrate with zone level ranges. |
| `XP_PER_ENEMY_LEVEL` | int | 10 | This system *(→ Enemy Level & Zone Scaling)* | XP added per enemy level in CP-F4. The primary lever for how fast leveling tracks enemy strength. Provisional. |
| `BOSS_XP_MULTIPLIER` | int | 2 | This system | Boss XP multiplier in CP-F4. Keep an integer to preserve CP-F4's epsilon-free property. Safe range 2–3. |
| `completion_bonus_xp` (per boss) | int | Boss 1 = 310, Boss 2 = 180 | Enemy DB *(field)* / ELZS *(values)* | Flat boss-victory bonus added to `full_xp` (Rule 3a); `0` on WILD. **Not** CP-F4-scaled — sized per-boss to land the deployed core at its drop's equip gate on the floor-level path (ELZS AC-ELZS-14). Retune only alongside that AC; a value large enough to push the deployed core past the *next* gate's threshold breaks the anti-shortcut property (Boss 1 must stay < `threshold[7]=993`; Boss 2 < `threshold[9]=1650`). |
| `BENCH_XP_SHARE` | float | 0.5 | This system | Fraction of full XP a benched core earns (CP-F2). **Keep a power of 2** (0.25 / 0.5) to stay epsilon-free; a non-power-of-2 requires an epsilon guard + scan. Safe range 0.3–0.6 (values off a power of 2 add the epsilon cost). **Enforced, not just documented:** a startup assertion fires a content error if `BENCH_XP_SHARE × 2 != round(BENCH_XP_SHARE × 2)` (i.e. not a half-integer) unless the CP-F2 epsilon guard is present — see AC-CP-23. This stops a tuner picking 0.3 from the safe range without reading this note and silently shipping off-by-one bench XP. |
| `BENCH_LEVEL_LEAD_CAP` | int | 3 | This system | How many levels above an enemy a benched core may be before its bench XP drops to 0 (Rule 3 / EC-CP-03). Lower = tighter anti-power-level clamp. Safe range 2–5. At 0–1 a benched core stops earning almost immediately in on-level zones (too punishing); above ~5 the guard rarely fires. |
| Per-core `level_growth[stat]` | Content | authored per core | Part DB *(erratum)* | Per-level stat gain (CP-F3). **Power stats forbidden** (`physical_power`/`energy_power` — Rule 6a; enforced by AC-CP-22). Anti-grind ceiling: for each stat, `level_growth[stat] × 9` must be ≤ **25% of that stat's all-Rare reference SA-F1 output** (the AC-CP-21 reference baseline documented in Formulas → CP-F3), not an undefined "stat pool." The Spark Core's `energy_capacity` (+27 vs ~110 reference = 25%) sits exactly at the ceiling — do not raise it. AC-CP-22 validates the ceiling per Part DB entry. |
| Per-part `level_requirement` | Content | Rule 5 rarity floors | Part DB *(erratum)* | Core level needed to equip. Never below the rarity floor (Common 1 / Rare 3 / Boss-grade 6 / Prototype 8); may be raised for individually powerful parts. |

**Cross-referenced knob (owned elsewhere, affects this system):**

| Knob | Owner | Relevance here |
|------|-------|----------------|
| `enemy_level_floor` / `enemy_level_roof` | Encounter Zone *(Enemy Level & Zone Scaling erratum)* | The zone's level band bounds the enemy levels this system sees, which drives XP (CP-F4) and the bench-lead cap (Rule 3). CP-F1's arc pacing cannot be finalized until these are set. |
| `TEAM_ROSTER_CAP` | Symbot Assembly | Number of cores that can earn XP per battle (1 deployed + up to 2 benched at cap = 3). |

**Warning — the anti-grind invariant is a tuning contract, not just a formula property.** `XP_PER_ENEMY_LEVEL`, `level_growth`, and `LEVEL_COST_RAMP` jointly determine whether leveling stays a supporting axis or creeps toward dominance. Whenever any of the three is retuned, re-check the invariant: *a clever low-level build with great parts must still beat a lazily-assembled higher-level core.* Validate at playtest, not just on paper.

## Visual/Audio Requirements

This system renders nothing directly; its footprint is the signals it emits. `core_leveled_up(core_id, old_level, new_level)` → Workshop UI / post-battle summary shows a level-up flourish on the core slot; Audio plays a level-up chime. Per the Player Fantasy, this is deliberately *quiet* — a line in the post-battle summary and a glow on the Workshop core slot, not a screen-stopping cutscene. The emotionally important beat is what the level *unlocks* (a greyed part becoming available), not the number itself. All art (level badge, XP bar, greyed-part treatment, level-up animation) and mix parameters are specified in the **Workshop UI GDD** and **Audio System GDD**. This section defines only the signal contract those systems subscribe to.

## UI Requirements

Exposes read APIs + signals; contributes no screens of its own. Consumed by Workshop UI (#18) and Combat UI (#19):
- Reads: `core.level`, `cumulative_xp`, XP-to-next (`threshold[level+1] − cumulative_xp`), per-part `level_requirement`, `can_equip()` result.
- Signals: `core_leveled_up(core_id: int, old_level: int, new_level: int)`.
- **Post-battle bench-XP legibility (bench-lead-cap transparency):** The post-battle summary must list per-core XP earned. For a benched core that earned 0 due to the level-lead cap (Rule 3 guard: `benched.level ≥ enemy_level + BENCH_LEVEL_LEAD_CAP`), the entry must display "0 XP — over-level for this zone" rather than a blank line. This ensures the player understands why their veteran core stopped advancing. *(Detail spec in Workshop UI / Combat UI GDD.)*

> **📌 UX Flag — Symbot Core Progression**: Workshop UI must show the core's level + an XP-progress bar on the core slot; parts above the core's level render greyed with a "Core level N required" tooltip; an invalid-build banner appears when a core swap orphans over-level parts (EC-CP-05); the post-battle summary shows the level-up notification. Run `/ux-design` for these before writing Workshop UI stories. Touch-first: tap-targets ≥ 44×44pt, no hover-only affordances (per technical-preferences).

## Acceptance Criteria

**AC-CP-01 — Deployed core earns full xp_value; level-up signal fires on a threshold cross.** **GIVEN** a deployed core `cumulative_xp = 100` (level 2), defeated enemy `xp_value = 170`, **WHEN** `battle_ended(VICTORY)` fires, **THEN** `cumulative_xp == 270`, `level == 3`, **AND** `core_leveled_up` fires exactly once with params `[core_id, 2, 3]`. *(Rule 3; CP-F4)* **Test:** Unit. *(Assert via `assert_signal_emit_count(system, "core_leveled_up", 1)` + `assert_signal_emitted_with_parameters(...)` — the count assertion is required, not optional.)*

**AC-CP-02 — Level derivation boundary (`≥` discriminator).** **GIVEN** `cumulative_xp ∈ {99, 100, 219, 220}`, **WHEN** CP-F1 derives level, **THEN** result is `{1, 2, 2, 3}` respectively. An implementation using `>` instead of `≥` returns level 1 at exactly 100 and fails. **Test:** Unit.

**AC-CP-03 — Multi-level jump emits a single spanning signal.** **GIVEN** a level-1 core `cumulative_xp = 0`, **WHEN** awarded 600 XP in one battle, **THEN** `level == 5` (600 ≥ 537, < 744), **AND** `assert_signal_emit_count(system, "core_leveled_up", 1)` **AND** `assert_signal_emitted_with_parameters(system, "core_leveled_up", [core_id, 1, 5])`. An implementation firing one signal per crossed threshold (4 signals) fails the count assertion. **Sub-case (discriminator for `≥` vs `>` at the final level boundary):** starting from `cumulative_xp = 0`, award exactly **537 XP** (= threshold[5]); assert `level == 5` and `assert_signal_emitted_with_parameters(system, "core_leveled_up", [core_id, 1, 5])`. A `>` implementation yields `level = 4` here (537 is the threshold value, not strictly greater than itself). *(EC-CP-02)* **Test:** Unit.

**AC-CP-04 — Equip gate blocks under-level, allows at-level, ignores null.** **GIVEN** a build whose CORE is level 3: (a) equipping `level_requirement = 6` → `can_equip == false`, no part displaced, error returned; (b) equipping `level_requirement = 3` → `can_equip == true`, equip proceeds; (c) equipping `level_requirement = 0` (or null) → `can_equip == true` regardless of core level. *(Rule 4; EC-CP-04)* **Test:** Unit.

**AC-CP-05 — Core swap invalidates over-level parts without unequipping them.** **GIVEN** a build with a Boss-grade part (`level_requirement = 6`) in ARMS and a level-8 core, **WHEN** the CORE is swapped to a level-4 core, **THEN** the build is flagged invalid, the ARMS part is **not** auto-unequipped, and the validation report lists the ARMS part. *(EC-CP-05)* **Test:** Unit. *(The "cannot enter combat while invalid" block is verified in the Workshop/TBC GDD, not here.)*

**AC-CP-06 — Max level caps XP and the cap is per-core, not global.** **(A)** **GIVEN** a level-10 core `cumulative_xp = 2080`, **WHEN** awarded 85 XP, **THEN** `cumulative_xp` stays 2080, `level` stays 10. **(B)** **GIVEN** the same battle also has a benched level-5 core (below the lead cap), enemy `xp_value = 85` (level-5 WILD: `(35+50)×1`), **THEN** the benched core earns `floor(85 × 0.5) = 42` — proving the level-10 core's cap does not zero other cores' awards. (`round(42.5) = 43` in GDScript round-half-away-from-zero — this is the discriminating case per project standards: floor ≠ round.) *(EC-CP-01, EC-CP-12)* **Test:** Unit.

**AC-CP-07 — Level is re-derived from cumulative_xp, never trusted from the serialized field.** **GIVEN** a `CoreProgressionRecord` deserialized from `{ cumulative_xp: 744, level: 3 }` (drifted), **WHEN** its level is derived, **THEN** `level == 6` (from `cumulative_xp` via CP-F1), not 3. *(EC-CP-06)* **Test:** Unit — exercises the derive method directly, independent of the Not-Started Exploration Progress system.

**AC-CP-07b — Full save/load round-trip.** **GIVEN** a saved core at `cumulative_xp = 744`, **WHEN** the game saves and reloads via Exploration Progress, **THEN** the restored core derives to level 6. **Test:** Integration. **DEFERRED** — unblocks when Exploration Progress serialization is implemented.

**AC-CP-08 — Bench-lead cap boundary (`≥` discriminator).** **GIVEN** `BENCH_LEVEL_LEAD_CAP = 3`, enemy `level = 3`, `xp_value = 65`: **(A)** benched core `level = 6` (6 ≥ 3+3) → earns **0** (the at-cap discriminator; a `>` impl wrongly awards XP here); **(B)** benched `level = 5` (5 < 6) → earns `floor(65 × 0.5) = 32`; **(C)** benched `level = 9` → earns **0**. *(Rule 3; EC-CP-03)* **Test:** Unit.

**AC-CP-09 — Missing CoreProgressionRecord is created on register_core call.** **GIVEN** a core part instance with no existing record, **WHEN** `register_core(core_instance_id)` is called, **THEN** a record is created with `cumulative_xp == 0, level == 1`. Calling `register_core` a second time with the same id is a no-op with a content warning emitted via logging spy. *(EC-CP-07, Rule 1 interface)* **Test:** Unit.

**AC-CP-10 — Unknown level_growth stat key is skipped with a warning.** **GIVEN** a core `level_growth = { structure: 2, bogus_stat: 5 }` at level 10, **WHEN** CP-F3 applies, **THEN** `structure` gains +18, `bogus_stat` is skipped, no crash, **AND** an injected logging spy shows a warning containing `"bogus_stat"`. *(EC-CP-08)* **Test:** Unit.

**AC-CP-11 — Enemy xp_value of 0 vs. absent.** **(A)** **GIVEN** defeated enemy `xp_value = 0`, **WHEN** `battle_ended(VICTORY)`, **THEN** all cores earn 0, no level change (no warning — intentional). **(B)** **GIVEN** the payload lacks the `xp_value` key (`.has("xp_value") == false`), **THEN** all cores earn 0 **AND** a content warning is logged via the logging spy. *(EC-CP-09)* **Test:** Unit.

**AC-CP-12 — Negative cumulative_xp is clamped on load.** **GIVEN** a `CoreProgressionRecord` deserialized with `cumulative_xp = -50`, **WHEN** it is sanitized, **THEN** `cumulative_xp == 0`, `level == 1`, and a content error is logged via the spy. *(EC-CP-10)* **Test:** Unit — exercises the sanitize method directly.

**AC-CP-13 — Non-CORE level_growth is ignored.** **GIVEN** a WEAPON part with `level_growth = { physical_power: 5 }` and a core at level 10, **WHEN** CP-F3 runs, **THEN** `physical_power` receives **no** level contribution from the WEAPON — only the CORE-slot part's `level_growth` is read. *(EC-CP-11)* **Test:** Unit.

**AC-CP-14 — Deployed vs. benched split across the full roster.** **GIVEN** core A deployed and cores B and C both benched (both below the lead cap), enemy `xp_value = 170`, **WHEN** `battle_ended(VICTORY)`, **THEN** A earns 170, B earns 85, C earns 85 — verifying the bench-list iteration does not skip the second benched core. *(Rule 3; CP-F2)* **Test:** Unit.

**AC-CP-15 — Level-growth contribution is a level-1 no-op and scales thereafter.** **GIVEN** a core `level_growth = { energy_capacity: 3 }`: at **level 1**, `final_stat[energy_capacity]` is identical to the SA-F1 output (contribution 0 — assert the pipeline value, not just the delta); at **level 5**, contribution `= +12`; at **level 10**, `= +27`. *(CP-F3)* **Test:** Unit.

**AC-CP-16 — CP-F4 xp_value from enemy level (isolates each constant).** **GIVEN** enemy `level = 1` WILD → `xp_value == 45` (isolates `XP_BASE`); `level = 3` WILD → `65`; `level = 5` BOSS → `170` (isolates `BOSS_XP_MULTIPLIER`). *(CP-F4)* **Test:** Unit.

**AC-CP-17a — No XP on DEFEAT.** **GIVEN** cores with known `cumulative_xp`, **WHEN** `battle_ended(DEFEAT)` fires, **THEN** every core's `cumulative_xp` is unchanged (`assert_eq` to the pre-battle value) **AND** `assert_signal_emit_count(system, "core_leveled_up", 0)` — no spurious level-up signal on a non-victory outcome. *(Rule 3)* **Test:** Unit.

**AC-CP-17b — No XP on FLED.** **GIVEN** the same, **WHEN** `battle_ended(FLED)` fires, **THEN** every core's `cumulative_xp` is unchanged **AND** `assert_signal_emit_count(system, "core_leveled_up", 0)`. A separate code path from DEFEAT. *(Rule 3)* **Test:** Unit.

**AC-CP-18 — CP-F3 is applied AFTER SA-F1 and BEFORE SYN-F4 (pipeline ordering).** **GIVEN** a chassis archetype multiplier `M = 1.2`, a CORE with `level_growth = { target_stat: 10 }` at level 5 (contribution = 40), and an SA-F1 output of 120 for `target_stat` (100 raw × 1.2 archetype), **WHEN** Assembly computes `final_stat`, **THEN** the value fed to SYN-F4 is exactly **160** (= 120 + 40), **not 168** (= (100+40) × 1.2, which results from applying CP-F3 before SA-F1). This proves the contribution bypasses the chassis modifier and precedes synergy. *(Rule 6; CP-F3)* **Test:** Integration. **DEFERRED** — unblocks when the Symbot Assembly erratum (inserting the CP-F3 contribution step between SA-F1 and SYN-F4) is applied. **The enforcing test now lives in the Assembly GDD as `AC-SA-15` (added by erratum ST-2, 2026-07-13), which is a required DoD gate on the CP-F3-insertion story** — see symbot-assembly.md AC-SA-15. *(Matches AC-CP-07b deferral pattern.)*

**AC-CP-19 — core_leveled_up does NOT fire when no threshold is crossed.** **GIVEN** a level-2 core at `cumulative_xp = 100`, **WHEN** awarded 50 XP (new total 150 < threshold[3] = 220), **THEN** `cumulative_xp == 150`, `level` stays 2, **AND** `assert_signal_emit_count(system, "core_leveled_up", 0)`. *(Rule 2)* **Test:** Unit.

**AC-CP-20 — Rarity level_requirement floor invariant (content validation).** For every Part DB entry: `part.level_requirement ≥ RARITY_LEVEL_FLOOR[part.rarity]` where the floors are Common 1 / Rare 3 / Boss-grade 6 / Prototype 8. A Prototype part authored with `level_requirement = 1` fails. *(Rule 5)* **Test:** Content Validation. **BLOCKING** — *(promoted from ADVISORY, /design-review 2026-07-13).* This is the **sole** protection against an under-authored gate: a PROTOTYPE part with `level_requirement = 1` lets any level-1 core equip it, silently defeating the entire equip-gate system (Rule 4/5), and there is **no runtime fallback** — the gate trusts the authored value. Must run and pass before any Part DB erratum authoring `level_requirement` values is merged.

**AC-CP-21 — Anti-grind invariant: build + type mastery out-damages raw level (checkable).** Verifies the honest bounded-edge invariant (see Formulas → CP-F3), using the all-Rare reference baseline. **GIVEN** two Symbots both using an Energy skill:
- **Challenger (level 4):** Spark Core L4; Rare ARMS `energy_power` base = 45; active synergy `+10` energy_power; CP-F3 contributes 0 to `energy_power` (power stats forbidden, Rule 6a). Final `energy_power = 55`. Target Core = Thermal (T = 1.5); target `resistance = 30`.
- **Incumbent (level 8):** Spark Core L8; Common ARMS `energy_power` base = 24; no synergy; CP-F3 contributes 0 to `energy_power`. Final `energy_power = 24`. Neutral matchup (T = 1.0); target `resistance = 30`.

**WHEN** DF-1 is applied to each, **THEN**:
- Challenger `= floor(float(55*55) / (float(55)+float(30)) × 1.5 + 0.0001) = floor(3025.0/85.0 × 1.5) = floor(53.38) = 53`
- Incumbent `= floor(float(24*24) / (float(24)+float(30)) × 1.0 + 0.0001) = floor(576.0/54.0) = floor(10.666…) = 10` — **discriminating fixture**: `floor(10.666…) = 10` while `round(10.666…) = 11` and `ceil(10.666…) = 11`, so a `round()`/`ceil()` DF-1 bug returns 11 here (the prior `energy_power = 20` fixture gave an exact `8.0`, which floor and round both yield — non-discriminating; corrected per systems-designer/qa-lead 2026-07-13).

> **Float-cast contract (mandatory — qa-lead R4-B2, 2026-07-13).** The division steps above are written with explicit `float()` casts because **GDScript `int / int` truncates**: without the cast, `3025 / 85 = 35` (not 35.588), `floor(35 × 1.5) = 52`, and the Challenger fixture would falsely fail at 52 ≠ 53. This AC applies **DF-1 exactly as specified in damage-formula.md** — see its binding "GDScript implementation note — float arithmetic required" (damage-formula.md line 174) and the ordering requirement AC-DF-04 (`T` multiplied into the float *before* the single `floor()`). The expected values (53, 10) are correct under that contract; the test MUST invoke the real DF-1 function, not a re-implemented integer-division copy.
- Assert `challenger_damage > incumbent_damage` (53 > 10) — the level-4 build+type advantage dominates the level-8 raw-level core by ~5.3×.

*(Note: because Rule 6a forbids power growth, the level gap contributes **nothing** to `energy_power` here — the entire delta is build quality + type mastery, exactly as the pillars require.)* **Test:** Content Validation / calculation check. **ADVISORY gate**, but must be re-run and logged whenever `level_growth`, `XP_PER_LEVEL_BASE`, `LEVEL_COST_RAMP`, or SA-F1 Rare/Common tier outputs are retuned; a tuning change that inverts this comparison is an anti-pillar violation requiring creative-director sign-off. Record passing numbers + the tuning-knob values used in `design/balance/anti-grind-invariant-log.md`. *(Resolves cross-review D-2.)*

**AC-CP-22 — level_growth content validation: no power stats, per-stat 25% ceiling.** For every CORE-slot Part DB entry: **(A)** `level_growth` contains no `physical_power` or `energy_power` key (Rule 6a) — a Spark Core authored with `energy_power: 2` fails; **(B)** for each stat key, `level_growth[stat] × 9 ≤ 0.25 × REFERENCE_SA_F1_OUTPUT[stat]` where the reference outputs are the all-Rare baseline (CP-F3 table). A core authored with `energy_capacity: 5` (+45 vs ~110 reference = 41%) fails. *(Rule 6a; CP-F3 anti-grind ceiling)* **Test:** Content Validation. **BLOCKING** — no runtime check catches an over-powered or power-stat `level_growth`; without this test, a single mis-authored core silently makes level the dominant variable (anti-pillar breach) or breaches DF-1's input domain.

> **Per-stat implementability of check (B) — 2026-07-13, converged game-designer + systems-designer + qa-lead finding.** Check (B) is only as reliable as its `REFERENCE_SA_F1_OUTPUT[stat]` source. Two of the three grown stats have a usable reference; one does not:
> - **`structure` (~260) and `energy_capacity` (~110):** derived from the all-Rare SA-F1 baseline (CP-F3 table). Check (B) for these is **BLOCKING** as stated. *(Caveat: these are illustrative Rare-tier estimates, not registry constants — if SA-F1 tier outputs are retuned, the `REFERENCE_SA_F1_OUTPUT` table here must be re-derived. See Bidirectionality Notes.)*
> - **`cooling` (`~40`):** **no approved GDD declares a `cooling` SA-F1 output reference** — the `~40` is an inline estimate local to this document (see Bidirectionality Notes → "cooling has no declared SA-F1 ceiling"). Check (B) for `cooling` is therefore **ADVISORY-until-established**: a test hardcoding `~40` would falsely pass even if the real all-Rare cooling output is below 36 (at which point the Spark Core's `cooling: 1` / +9 breaches 25%). Check (B) for `cooling` is promoted to BLOCKING **only when** the owed Part DB / SA-F1 `cooling` output range lands (tracked as an erratum obligation). Part **(A)** (no power stats) and check (B) for `structure`/`energy_capacity` remain BLOCKING regardless.

**AC-CP-23 — BENCH_XP_SHARE epsilon-safety assertion.** **GIVEN** `BENCH_XP_SHARE` is set to a value where `BENCH_XP_SHARE × 2` is not an integer (e.g. 0.3, within the documented safe range 0.3–0.6) **AND** the CP-F2 epsilon guard is absent, **WHEN** the system initializes, **THEN** a content error is logged via the injected logging spy naming `BENCH_XP_SHARE`. **GIVEN** the default 0.5 (a half-integer, `0.5 × 2 = 1`), **THEN** no error. *(CP-F2 epsilon note; Tuning Knobs)* **Test:** Unit — exercises the startup validation directly. **ADVISORY.**

**AC-CP-24 — Boss completion bonus is folded into the award and distributed on FIRST defeat (Rule 3a).** **GIVEN** a deployed core `cumulative_xp = 220` (level 3) and a benched core `cumulative_xp = 0` (level 1, below the lead cap), defeated **BOSS** with `xp_value = 170` and `completion_bonus_xp = 310`, **and `is_first_boss_defeat == true`**, **WHEN** `battle_ended(VICTORY)` fires, **THEN**: (a) the deployed core is awarded `170 + 310 = 480` → `cumulative_xp == 700`, and since `threshold[5]=537 ≤ 700 < threshold[6]=744`, **`level == 5`**; (b) the benched core is awarded `floor((170 + 310) × 0.5) = floor(240.0) = 240` → `cumulative_xp == 240`, and since `threshold[3]=220 ≤ 240 < threshold[4]=364`, **`level == 3`**. **AND** for a **WILD** enemy with `completion_bonus_xp = 0`, the deployed award equals `xp_value` alone (bonus adds nothing). Discriminating: an implementation that awards only `xp_value` (ignoring the bonus) gives the deployed core 390 (level 4) not 700 (level 5) — the level assertion catches it; an implementation that adds the bonus but forgets to fold it into the bench base gives the bench core 85 not 240. *(Rule 3a first defeat; resolves OQ-CP-8 runtime side)* **Test:** Unit.

**AC-CP-25 — Boss REFIGHT awards no completion bonus (first-defeat guard; anti-farm).** **GIVEN** a deployed core `cumulative_xp = 0` (level 1), defeated **BOSS** with `xp_value = 170` and `completion_bonus_xp = 310`, **but `is_first_boss_defeat == false`** (a refight — the boss's `defeated_once` was already `true` at battle start), **WHEN** `battle_ended(VICTORY)` fires, **THEN** the deployed core is awarded `xp_value` **only** = `170` → `cumulative_xp == 170`, `level == 2` (100 ≤ 170 < 220) — **NOT** `480` (which from `cumulative_xp = 0` would be `level 4`, since `threshold[4]=364 ≤ 480 < threshold[5]=537`). A benched core (below lead cap) earns `floor(170 × 0.5) = 85` (level 1), **not** `floor(480 × 0.5) = 240` (level 3). **Discriminating:** an implementation that ignores `is_first_boss_defeat` and always folds `completion_bonus_xp` awards 480/level 4 (deployed) and 240/level 3 (bench) — the level-2-not-4 (deployed) and level-1-not-3 (bench) assertions are the sole catch for the refight-farm exploit (a boss refightable via `LIGHTER_REGATE` would otherwise flood XP at ~5.3× WILD density). This AC and AC-CP-24 together prove the bonus is **once-per-boss**: awarded on the first defeat (24), suppressed on every refight (25). *(Rule 3a first-defeat guard)* **Test:** Unit.

**Coverage check:** every core rule (1–7, incl. 6a and the Rule 3a boss completion bonus → AC-CP-24 first defeat + AC-CP-25 refight-no-bonus first-defeat guard) and all four formulas (CP-F1/F2/F3/F4) have ≥1 AC; every edge case EC-CP-01…12 cites a listed AC. Pipeline ordering (AC-CP-18) and signal-suppression (AC-CP-19, plus emit-count-0 on DEFEAT/FLED in AC-CP-17a/b) are explicitly covered. The anti-grind invariant is now a checkable AC (AC-CP-21) with a fixed reference baseline; content-integrity gates AC-CP-20 (gate floor) and AC-CP-22 (no power stats / 25% ceiling) are BLOCKING. Signal assertions use both `assert_signal_emit_count` and parameter checks. Load-behavior ACs (07, 12) are unit-scoped against the derive/sanitize methods; the full save/load round-trip (07b) is DEFERRED pending Exploration Progress.

> **DoD note on AC-CP-18 (pipeline ordering, DEFERRED).** AC-CP-18 proves CP-F3 is inserted between SA-F1 and SYN-F4. It is DEFERRED until the Symbot Assembly erratum lands. **Unblocking and passing AC-CP-18 is a required Definition-of-Done item on the Assembly erratum story** — the erratum must not be marked complete with the CP-F3 step inserted but untested, because a wrong insertion point (before SA-F1, or after SYN-F4) produces a different `final_stat` that no non-deferred AC catches.

## Open Questions

### Cross-Document Change Manifest (Level Backbone — introduced 2026-07-12)

The Level Backbone (enemy level + zone level range + core level) touches multiple Approved GDDs. This system owns the **player/core** side; the enemy/zone side is designed in the separate **Enemy Level & Zone Scaling** system.

> **Condition-of-approval errata (4th-pass /design-review 2026-07-13).** Four cross-doc
> obligations gate this GDD's move to Approved. They land in sibling Approved docs, NOT here,
> and are tracked as producer-owned stories **ST-1…ST-4** in
> [`production/errata-backlog.md`](../../production/errata-backlog.md): ST-1 → ELZS (OQ-CP-8
> equip-gate coverage AC), ST-2 → Symbot Assembly (AC-SA-XX gating AC-CP-18), ST-3 → TBC
> (`is_build_valid()` pre-battle refusal AC for EC-CP-05), ST-4 → Consumable DB (CD-1/CD-3
> range fix + AC-CD-03 `max_energy=147` fixture — highest silent-failure risk). CP is
> **NEEDS REVISION (light)** until these are discharged.

| # | Document | Status | Change | Owned by |
|---|----------|--------|--------|----------|
| 1 | game-concept.md | **DONE** (CD ratified 2026-07-13) | Anti-pillar #3 revised to "NOT a level-matching treadmill" | This session |
| 2 | enemy-database.md | Approved | Add real `level` field; relate level to EDB-2 stat block; add `xp_value` (CP-F4 output); drop-quality hook | Enemy Level & Zone Scaling pass |
| 3 | encounter-zone.md | Approved | Add `enemy_level_floor` / `enemy_level_roof`; enemies spawn in-band | Enemy Level & Zone Scaling pass |
| 4 | zone-world-map.md | Approved | Map `difficulty_band` → zone level range | Enemy Level & Zone Scaling pass |
| 5 | drop-system.md | Approved | Enemy level → drop rarity odds + stat rolls | Enemy Level & Zone Scaling pass |
| 6 | part-database.md | Approved | Add `level_requirement` + `level_growth` fields | Core Progression errata pass |
| 7 | symbot-assembly.md | Approved | Wire equip gate + CP-F3 step; discharges CORE-identity Deferred Obligation | Core Progression errata pass |
| 8 | turn-based-combat.md | Approved | `battle_ended` carries `xp_value`/`level`/deployed set; update OQ-TBC-6 | Core Progression errata pass |
| 9 | systems-index.md | Draft | Add **Enemy Level & Zone Scaling** system; update #10b scope | This session |

### Genuine open questions

- **OQ-CP-1 — MVP zone level range unset.** CP-F1 arc pacing and CP-F4 constants (`XP_BASE`/`XP_PER_ENEMY_LEVEL`) are provisional until the MVP zone's `enemy_level_floor`/`roof` are set. *Owner: Enemy Level & Zone Scaling pass.*
- **OQ-CP-2 — Does enemy level DRIVE stats or LABEL them?** Either enemy level feeds a scaling formula that produces the stat block, or it is a consistent label over the existing manually-authored EDB-2 TTK-band stats. Central Enemy DB design decision. *Owner: Enemy Level & Zone Scaling pass.*
- **OQ-CP-3 — Does source enemy level influence dropped part stat rolls?** The PoE item-level model: higher-level enemies drop parts with better stat rolls / rarity odds. *Owner: Drop System erratum.*
- **OQ-CP-4 — Storage cores earn no XP.** Only the 3-slot active roster (1 deployed + up to 2 benched) earns; cores in storage earn nothing (Rule 3). Confirm intended. *Owner: playtest.*
- **OQ-CP-5 — No core progress transfer.** A leveled core's XP cannot be transferred to another core (core = identity; leveling is earned per-core). Confirmed no-transfer. *Owner: this system.*
- **OQ-CP-6 — CD sign-off on the anti-pillar revision. ✅ RESOLVED (2026-07-13).** The game-concept.md anti-pillar #3 change and the Core Fantasy revision required creative-director ratification before the Level Backbone is locked. **Ratified by the creative-director in the 2026-07-13 full-panel re-review synthesis** — the CD verified both file-level conditions at source (game-concept.md Core Fantasy + anti-pillar #3 lines) and confirmed the "leveling gates and paces access; it must never directly raise raw damage" framing (Rule 6a) delivers the anti-treadmill intent. *Owner: creative-director (discharged).*
- **OQ-CP-8 — Equip-gate frustration (Pillar-2 calibration). ✅ RESOLVED (2026-07-13) via the Rule 3a boss completion bonus.** The lever chosen (user decision, /design-review 2026-07-13) is a per-boss flat `completion_bonus_xp` (Boss 1 = 310, Boss 2 = 180) that lands the deployed core at its drop's equip gate on the worst-case floor path — see Rule 3a. The passing gate is **ELZS AC-ELZS-14** (ST-1, BLOCKING): `(WIN_COUNT × xp_value[enemy_level_floor]) + Σ(boss_xp + completion_bonus_xp) ≥ threshold[boss_rarity_gate]`. Floor-path check: Boss 1 → `6×45 + (170+310) = 750 ≥ 744` ✓; Boss 2 → `10×45 + (170+310) + (190+180) = 1300 ≥ 1292` ✓. The original gap analysis is retained below for the record. *Owner: discharged (mechanism here + ELZS AC-ELZS-14 + Enemy DB `completion_bonus_xp` field).*
  **[Historical — the gap this resolved]** With the confirmed CP-F4 constants (`XP_BASE = 35`, `XP_PER_ENEMY_LEVEL = 10`, `BOSS_XP_MULTIPLIER = 2`) and the confirmed level-1–6 MVP zone, the pre-bonus gap was real:
  - **Boss-grade gap (Boss 1 → level 6):** mid-band path (6 WILD wins at L3 = 65 XP each) + Boss 1 (L5, 170 XP) = 390 + 170 = **560 XP** vs `threshold[6] = 744` → **~184 XP short (~2.8 L3 battles)**. Floor-level path (6 WILD at L1 = 45 XP) + 170 = **440 XP → ~304 XP short**.
  - **Prototype gap (Boss 2 → level 8), corrected:** mid-band path (10 WILD wins at L3) + Boss 1 (170) + Boss 2 (L6, 190 XP) = 650 + 170 + 190 = **1,010 XP** vs `threshold[8] = 1,292` → **~282 XP short (~4.3 L3 battles)**; floor-level ~482 XP short. *(The prior "~452 XP / ~7 battles" parenthetical was inconsistent with the confirmed WIN_COUNT/zone/boss-level numbers — corrected here per economy-designer 2026-07-13.)*
  - Those "harvest-goal-less" battles manufacture the exact *"need more XP"* feeling the Player Fantasy prohibits and dent Pillar 2.
  - **Single-lever caution:** `BOSS_XP_MULTIPLIER` scales both gaps *proportionally* and cannot close them **independently** — the two bosses sit at different distances from their equip gates. Per-gate levers are the correct tool: `WIN_COUNT`, the rarity `level_requirement` floor (e.g. Boss-grade 6→5 / Prototype 8→7), or a per-boss completion bonus XP that is not tied to CP-F4. `XP_PER_ENEMY_LEVEL` and `BOSS_XP_MULTIPLIER` are blunt levers that risk over-shooting the Prototype gate.
  - **⚠️ Tracking gap:** this was routed to the ELZS pass "as a blocking Pillar-2 acceptance check," **but ELZS has since been Approved without absorbing it** — the obligation now lives only as this prose pointing at an Approved system. **Resolution:** file an ELZS erratum that converts this into a numbered, tracked AC with an explicit worst-case formula — `(WIN_COUNT × xp_value[enemy_level_floor]) + Σ boss_xp ≥ threshold[boss_rarity_gate]` — classified BLOCKING, using the zone **floor** enemy level (not an average) so early-terrain players are covered. Producer-coordinated (touches an Approved doc). *(Cross-review economy-designer finding, 2026-07-13; confirmed absent from ELZS at source by creative-director.)*
- **OQ-CP-7 — Bench dead zone in single-zone MVP.** In a single-zone MVP with enemy levels ~1–6, any benched core at level > `enemy_level_roof + BENCH_LEVEL_LEAD_CAP` stops earning bench XP entirely. Veterans (level 7+) produce no bench XP in the early zone. This is intentional anti-power-leveling, but it means the bench mechanic is an early-game tool only in a single-zone context. *Resolve at Enemy Level & Zone Scaling pass (OQ-CP-1): ensure the MVP zone's enemy_level_roof is high enough to keep the bench mechanic usable for most of the level-1–10 arc, or explicitly document the bench system as early-game only.* *Owner: Enemy Level & Zone Scaling pass.*
