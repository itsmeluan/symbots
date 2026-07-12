# Encounter Zone System

> **Status**: **APPROVED — 3rd-round confirmation re-review 2026-07-12 (full panel, zero blocking); one minor revision (EC-EZ-12 `requires_defeated` fail-safe + AC-EZ-58) + 2 converged recommendations applied same session**
> **Author**: Luan + Claude Code Game Studios agents (systems-designer: Formulas; qa-lead: Acceptance Criteria)
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 5 (The World Is a Workshop)
> **Confirmation Re-Review Notes (2026-07-12, 3rd round)**: Fresh-session full-panel `/design-review` (game/systems/economy/level designers + qa-lead + CD synthesis) confirming the Round 2 fixes. **All five specialists returned ZERO blocking.** The delta re-gate, `is_farmable_target`, and `requires_defeated` sequencing were all verified correct at the discriminator level (AC-EZ-22 catches both the raw-counter and ignore-`defeated_once` bugs; the `LIGHTER_REGATE`→`ALWAYS_OPEN` collapse is genuinely closed; delta provably non-negative via Rule 8a monotonicity). CD verdict **APPROVED WITH ONE MINOR REVISION** — the lone survivor of the mature-doc triage was a spec-silent fail-safe gap on the field this cycle introduced (`requires_defeated` naming a non-existent boss). Applied same session: **EC-EZ-12 + AC-EZ-58** (broken-reference → fail-safe `LOCKED`, never fail-open — game + systems converged), plus two converged recommendations — **Tuning Knob warning 5** (re-gate × density coupling — economy + level converged) and the **`is_farmable_target` authoring criterion** (Rule 2a — level). **58 → 59 ACs (39 BLOCKING / 11 ADVISORY / 9 DEFERRED).** No Round 4 (CD directive: do not spawn a full panel for a fail-safe EC).
> **Prior Re-Review Notes (2026-07-12, 2nd round)**: Fresh-session full-panel `/design-review` (game/systems/economy/level designers + qa-lead + CD synthesis). NEEDS REVISION — 3 blockers + 2 recommended applied same session. The prior WAVE→shared-counter revision had introduced a latent defect the panel caught:
> - **LIGHTER_REGATE re-gate fixed** — it silently collapsed into `ALWAYS_OPEN` because the never-resetting shared counter (already ≥6 after a defeat) trivially satisfied the re-gate. Re-access is now a **delta**: `win_count − wins_at_last_defeat >= regate_params.required_wins`, with a per-boss `wins_at_last_defeat` snapshot taken on each defeat (Rule 9, Rule 8a, Exploration Progress storage). AC-EZ-21/22/23 rewritten around the delta; AC-EZ-22 is the central discriminator (boss re-locks at the moment of defeat).
> - **Boss-1-first sequencing added** — Boss 2 now requires `zone_win_count >= 10` **and** Boss 1 `defeated_once == true` via `gate_params.requires_defeated` (Rule 8), closing the Boss-1-bypass / simultaneous-dual-unlock gap. New AC-EZ-56; AC-EZ-19/20/49 updated.
> - **`is_farmable_target` field added to SpawnEntry** — Rule 2a's 20% weight floor was unenforceable (no schema field to mark farming hosts). AC-EZ-54B now queries the field; AC-EZ-54 also gains A2 (identity-enemy 10% weight floor, closing the token-exclusive loophole).
> - Recommended: EC-EZ-07 citation fixed (AC-EZ-35 added); zone-level `spawn_enabled` now verified (new AC-EZ-57, EC-EZ-10 re-cited); gate-eval timing pinned to `battle_ended`/approach (Rule 8); DENSE tuning flagged as provisional on OQ-EZ-8; new Tuning Knob warning 4 (required_wins × density coupling); UI Req 3 sequencing + wins-only feedback. **56 → 58 ACs (38 BLOCKING / 11 ADVISORY / 9 DEFERRED).**
> **Prior Review Notes (2026-07-11)**: Authored in lean mode, then full-panel `/design-review` (game/systems/economy/level designers + qa-lead + creative-director synthesis). NEEDS REVISION verdict — 4 blockers + 4 recommended applied same session:
> - **WAVE gate cut to Reserved** (CD verdict: largest cost concentration + off-pillar). Both MVP bosses are now `OVERWORLD`/`WIN_COUNT`/`LIGHTER_REGATE` on a **shared cumulative zone-win counter** (Boss 1 opens at 6, Boss 2 the deeper apex at 10). WAVE keeps its enum value alongside REACH/DUNGEON_RUSH; `wave_pools` deferred until WAVE is authored.
> - **WIN_COUNT counter semantic made normative** here (Rule 8a): cumulative, all-time, zone-wide, no reset; fled/lost never count. No longer deferred to Exploration Progress.
> - **AC-EZ-25 promoted ADVISORY → BLOCKING** (strictly-lighter regate is a MUST invariant; silent violation kills the harvest loop).
> - **AC-EZ-40 split** into 40a (BLOCKING, testable now — no-crash provisional fallback) and 40b (DEFERRED, live integration).
> - AC discriminator fixes (positive cases + boundary seeds), 1.3×/1.6× ratio text fixed, EZ-2 pre-filter note, terrain identity-enemy + 20% weight-floor guardrail (Rule 2a + AC-EZ-54).

## Overview

The Encounter Zone System is the spawn-table authority for each explorable area in Symbots. It answers one question per zone: *"Which enemies can the player fight here, and under what conditions?"* A zone definition is a static data resource — a named zone entry listing its eligible WILD enemy pool (weighted spawn probabilities drawn from Enemy DB entries), any area-restricted spawn rules (density bands, encounter rate), and the BOSS gate condition that must be met before the zone's boss encounter becomes accessible.

At runtime the Overworld Navigation system triggers an encounter event; the Encounter Zone system resolves which enemy ID to load (selecting from the WILD pool by weighted draw, or loading the BOSS if the gate is open and the player initiates a boss encounter). The selected ID is handed to Turn-Based Combat, which instantiates the enemy from the Enemy Database. The Encounter Zone owns no combat state — it is read-only at runtime, serving as the bridge between "where the player is standing" and "what battle starts."

In MVP there is exactly one zone. The zone schema is designed to generalize (additional zones in Vertical Slice and beyond add zone entries without schema changes), but MVP content only populates one entry. Boss gates in MVP are cleared when the player has won a sufficient number of WILD encounters in the zone, ensuring the boss is not immediately accessible but does not require any specific enemy type or drop to unlock.

## Player Fantasy

The player never thinks "the encounter zone system selected an enemy." They think: *"There are Crawlers past the scrap dunes — I need two more Servo Arms to finish the build."*

The Encounter Zone system's job is to make that thought possible. It ensures every enemy available in the zone is a meaningful hunt target for at least one part hypothesis. The zone's enemy roster is the player's ingredient list, and the list must be curated enough that a player entering the zone always has a reason to fight. A zone with random filler encounters — enemies that drop nothing the player cares about — breaks the "World Is a Workshop" promise. Every enemy in the spawn table earns its place by offering parts that belong in someone's build.

The boss gate reinforces the same feeling from another direction: the boss doesn't wait calmly for the player to stumble into it. Clearing enough WILD encounters to open the gate makes the boss feel *earned* — the player has been in the zone, understands its enemies, and now faces the zone's apex. The boss offers Boss-grade parts unavailable anywhere else; the gate ensures the player arrives having already learned the zone's element identities and break patterns.

*(Pure infrastructure note: this section documents the design intent and player experience the Encounter Zone must support — not a player-facing system that requires its own UX. The fantasy is owned by the hunt loop; this system enables it.)*

## Detailed Design

### Core Rules

**Rule 1 — Zone definition.** A zone is one static data resource. MVP authors exactly one. Fields:

| Field | Type | Notes |
|-------|------|-------|
| `zone_id` | StringName | Unique zone identifier (e.g. `&"scrapfield"`) |
| `display_name` | String | Player-visible zone name |
| `terrain_patches` | Array[TerrainPatch] | The zone's encounter terrains — see Rule 2 |
| `boss_encounters` | Array[BossEncounter] | The zone's bosses and their gates — see Rule 6 |
| `spawn_enabled` | bool | Zone-level master switch (mirrors Enemy DB `spawn_enabled`) |

**Rule 2 — Terrain patch (the encounter unit).** A terrain patch binds a terrain *type* to an enemy sub-pool. Terrain type is the player's coarse targeting lever — different terrain, different enemies.

| Field | Type | Notes |
|-------|------|-------|
| `terrain_type` | Enum | `MECHANICAL_GRASS`, `JUNKYARD`, `PYLON_FIELD`, `MACHINE_CAVERN` (extensible; content-authored per zone) |
| `enemy_subpool` | Array[SpawnEntry] | Weighted WILD enemy candidates — see Rule 4 |
| `encounter_rate` | float | Per-step probability of triggering an encounter (0.0–1.0) |
| `density_class` | Enum | `SPARSE` / `STANDARD` / `DENSE` — a labeled band for `encounter_rate` (Rule 5) |

A `SpawnEntry` = `{ enemy_id: StringName, spawn_weight: int, is_farmable_target: bool = false }`. `enemy_id` must reference an Enemy DB entry whose `enemy_class == WILD` and `spawn_enabled == true`. `is_farmable_target` (default `false`) marks an entry as a build-critical farming host so the Rule 2a weight-floor can be enforced mechanically (AC-EZ-54B) — it is a content-authoring signal local to this system, not enemy stat data, so it creates no Enemy DB errata obligation.

**Rule 2a — Terrain-identity authoring invariant (makes the targeting lever real).** "Terrain = targeting lever" (Rule 2, Player Fantasy) is a content promise the schema must enforce, not merely encourage — otherwise a content author can silently collapse terrain into a cosmetic reskin by fully overlapping the sub-pools. Two authoring constraints, validated as content (AC-EZ-54):
- **Identity enemy.** Every terrain patch must contain **at least one `enemy_id` that appears in no other patch in the zone** — the patch's identity enemy. This guarantees each terrain is a distinct destination ("go to the pylon field for Pylon Crushers"), not a re-weighted copy of another.
- **Farmable-target weight floor.** Any enemy the player is expected to *farm* for a needed (non-Boss-grade) part — marked in data by `SpawnEntry.is_farmable_target == true` — must be **≥ 20% of its patch's `total_weight`**. Below that, the compounded scarcity (spawn rarity × the Drop System's conditional/pity rates) pushes farming time past the point where a deliberate hunt reads as a hunt rather than a slot machine. The 5–20% band is reserved for optional/bonus enemies (`is_farmable_target == false`), not for hosts of build-critical parts. The `is_farmable_target` flag is what makes this floor machine-checkable (AC-EZ-54B): the linter applies the floor only to flagged entries, so authors declare intent explicitly rather than the linter having to infer farmability from loot data it does not own (Rule 10).
  - *Authoring criterion (when to set the flag).* Mark `is_farmable_target == true` **if and only if** the enemy is the *primary or sole source* of a part required for a non-Boss-grade build path — the flag is about **scarcity-of-source, not importance-of-part**. If a part drops from several enemies, flag only the one with the highest availability in the most relevant terrain (flagging multiple hosts splits patch weight and inflates the compounded floor unnecessarily). **Filler/pacing enemies** that host no build-critical part are always `is_farmable_target == false` and face no weight floor — they may legitimately dominate a patch's weight, because the targeting lever is guaranteed by the *identity enemy's exclusivity*, not by frequency.

**Rule 3 — Encounter trigger (per-step roll).** While the player moves within a terrain patch, each step rolls against that patch's `encounter_rate` (Formula EZ-1). On success, an encounter is triggered from *that patch's* `enemy_subpool` (Rule 4). Steps on non-terrain tiles (paths, safe ground) never trigger. The trigger is owned by Overworld Navigation calling into this system; Encounter Zone owns the *resolution* (which enemy), not the movement detection.

**Rule 4 — Weighted enemy selection.** On a triggered encounter, select one `enemy_id` from the patch's `enemy_subpool` by weighted random draw (Formula EZ-2): each entry's probability = its `spawn_weight` ÷ the sum of all weights in that patch. The selected `enemy_id` is handed to Turn-Based Combat, which instantiates the enemy from Enemy DB. WILD encounters are fleeable (TBC Rule 7).

**Rule 5 — Density classes (dense biomes).** `density_class` maps to an `encounter_rate` band, giving the zone pacing texture:
- `SPARSE` — low rate; open/transitional terrain the player crosses without much friction.
- `STANDARD` — the default farming terrain.
- `DENSE` — high rate (near-every-step); the "cave/swarm-nest" fast-farm biome. Higher encounter throughput = faster farming at the cost of resource attrition between fights.

The exact rate per band is a Tuning Knob (Section G). Density is a *label*; the rate is the mechanism.

**Rule 6 — Boss encounter definition.** Each entry in a zone's `boss_encounters` defines one boss and how the player reaches it:

| Field | Type | Notes |
|-------|------|-------|
| `boss_id` | StringName | References an Enemy DB entry with `enemy_class == BOSS` |
| `placement` | Enum | `OVERWORLD` / `DUNGEON` / `HIDDEN` — where the boss lives (MVP: `OVERWORLD` only) |
| `gate_type` | Enum | How first-access is earned — see Rule 7 |
| `gate_params` | Dictionary | First-access gate parameters (MVP: `{ required_wins: N }` for `WIN_COUNT`, plus optional `requires_defeated: StringName` naming a prerequisite `boss_id` that must be defeated first — Rule 8 sequencing; `OPEN` uses `{}`). Reserved gate types carry their own shapes when authored — e.g. WAVE's `{ wave_count, wave_pools }` is defined only when WAVE is un-reserved (Rule 7). |
| `regate_params` | Dictionary | Re-access (post-first-defeat) gate parameters, parallel to `gate_params` (MVP: `{ required_wins: N }`). Read only when `repeat_policy = LIGHTER_REGATE` and the boss is defeated-once. `WIN_COUNT` re-access counts **new wins since this boss was last defeated** (a delta against `wins_at_last_defeat`, Rule 9), not the raw cumulative counter — otherwise the never-resetting counter satisfies any re-gate instantly. Values must be strictly lighter than `gate_params` (Rule 9 / Tuning Knobs). |
| `repeat_policy` | Enum | Re-access model after first defeat — see Rule 9 |

**Rule 7 — Gate-type taxonomy (extensible; MVP fills two).** `gate_type` is one enum; each value is a *reward vector*:

| `gate_type` | Reward vector | First-access condition | MVP |
|-------------|---------------|------------------------|-----|
| `OPEN` | (baseline) | Always accessible — no gate | Authorable |
| `WIN_COUNT` | Grinding | Win `gate_params.required_wins` WILD encounters in this zone (shared cumulative counter — Rule 8a) | **Boss 1 & Boss 2** |
| `WAVE` | Fighting | Enter the boss arena and defeat `gate_params.wave_count` consecutive enemy waves; the boss appears after the final wave | **Reserved** |
| `REACH` | Exploration | Player reaches a specific (hard-to-reach / hidden) map location | **Reserved** |
| `DUNGEON_RUSH` | Luck / skill | Boss sits deep in a dungeon; the player clears its mobs *or* rushes past them to reach it | **Reserved** |

**Both MVP bosses use `WIN_COUNT`** on one shared cumulative zone-win counter (Rule 8a), at escalating thresholds: Boss 1 opens at 6 wins; Boss 2 (the zone's deeper apex) opens at 10 wins **and** only once Boss 1 has been defeated (the sequencing precondition, Rule 8). This makes "the more you know the zone, the deeper you go" the single, coherent arrival fantasy for the whole zone — the escalating threshold *is* the progression, with no second gate mechanic to learn, and the Boss-1-first precondition guarantees the escalation is experienced in order rather than raced past.

**`WAVE`, `REACH`, and `DUNGEON_RUSH` are reserved.** `REACH`/`DUNGEON_RUSH` require spatial systems that do not exist yet (Zone & World Map #12, Overworld Navigation #16). `WAVE` was cut from MVP content by design-review verdict (off-pillar — an arena-gauntlet fantasy distinct from the zone's "earned by familiarity" arrival — and its `wave_pools` authoring schema is deliberately deferred). All three keep their enum values so the schema never changes when they ship; **no MVP content authors any of them**, and each carries a provisional contract (Dependencies / Open Questions). WAVE's `gate_params` shape (`{ wave_count, wave_pools }`) and abort/reset semantics are defined only when WAVE is un-reserved.

**Rule 8 — Gate evaluation (first access).** A boss's gate is evaluated against persistent player state (owned by Exploration Progress #14). Until the gate condition is met, the boss encounter is not offerable. `WIN_COUNT` reads the shared per-zone win counter (Rule 8a) and compares it to that boss's `gate_params.required_wins`; `OPEN` is always met. When the condition is met, the boss becomes accessible (its overworld presence / entry becomes active). (`WAVE`'s live-arena evaluation is defined only when WAVE is un-reserved — Rule 7.)

**Sequencing precondition (MVP).** A `WIN_COUNT` boss may declare a prerequisite boss that must be defeated first via `gate_params.requires_defeated: StringName` (a `boss_id`). The gate is met only when the win threshold is reached **and** the named prerequisite boss's `defeated_once == true`. In MVP, Boss 2 carries `requires_defeated = <Boss 1's boss_id>`, so Boss 2 stays `LOCKED` until Boss 1 falls even if `win_count >= 10`. The field is absent (no prerequisite) for Boss 1. This makes the shared-counter escalation strictly sequential rather than a race to a threshold.

**Evaluation timing.** The gate is (re)evaluated on `battle_ended` (when the win counter may have changed and when a boss's `defeated_once` may have just flipped) and on boss-approach query — **never mid-battle**. A WILD victory that pushes `win_count` from 5→6 unlocks Boss 1 on that battle's `battle_ended`, not during the fight.

**Rule 8a — WIN_COUNT counter semantic (normative — this system owns the definition).** Encounter Zone is the *gating authority*, so the meaning of the win counter is fixed here; Exploration Progress (#14) only *stores* it to this contract. The counter is:
- **Cumulative and all-time.** It counts total WILD encounters *won* in the zone across the game's entire history. It **never resets** — not on zone-exit, not per session, not after a boss is defeated.
- **Zone-wide and shared, but sequenced.** One counter per zone, read by every `WIN_COUNT` boss in that zone at its own threshold. In MVP: `win_count >= 6` opens Boss 1. Boss 2 requires **both** `win_count >= 10` **and** Boss 1 already defeated (`boss1.defeated_once == true`) — the sequencing precondition (Rule 8) that enforces the "deeper you go" escalation so a player cannot grind straight to the apex having skipped Boss 1. A player at 7 wins has Boss 1 unlocked and Boss 2 locked; a player who reaches 10 wins *without* beating Boss 1 has Boss 1 unlocked and Boss 2 still locked until Boss 1 falls.
- **Raw for first-access, delta for re-access.** First-access `WIN_COUNT` gates compare the raw cumulative counter to `gate_params.required_wins`. Re-access (Rule 9 `LIGHTER_REGATE`) instead compares `win_count − wins_at_last_defeat` (new wins banked since the boss's last defeat) to `regate_params.required_wins` — because the counter never resets, reading it raw for re-access would satisfy any re-gate the instant the boss first died.
- **Wins only.** A **fled** encounter (TBC flee) and a **lost** encounter do **not** increment it. Only a victory counts. (This is why it is a *win* count, not an *encounter* count — the "earned arrival" fantasy requires the player to have actually beaten the zone's enemies, not merely met them.)

This semantic resolves the former OQ-EZ-5 as a normative rule; Exploration Progress must implement its increment hook to advance only on a WILD victory in the zone.

**Rule 9 — Repeat policy (re-access for grinding).** After a boss's *first* defeat, its `repeat_policy` governs re-access so farming its parts stays viable but never free:
- `LIGHTER_REGATE` (MVP default) — the boss becomes repeatable behind a **reduced, delta-measured** gate read from `regate_params` (Rule 6): `WIN_COUNT` re-access requires `regate_params.required_wins` **new** WILD wins **since this boss was last defeated**, i.e. `win_count − wins_at_last_defeat >= regate_params.required_wins` (< first-access threshold); a persistent map icon marks it. **`wins_at_last_defeat` is a per-boss snapshot of the shared counter taken each time the boss is defeated** (owned/stored by Exploration Progress, semantic fixed here). This delta is what gives `LIGHTER_REGATE` real, recurring friction — reading the raw never-resetting counter instead would make the re-gate permanently satisfied the instant the boss first died (collapsing `LIGHTER_REGATE` into `ALWAYS_OPEN`). The specific reduction is a Tuning Knob. Re-access values MUST be strictly lighter than first-access, and MUST be ≥ 1 (a re-gate of 0 silently degenerates into `ALWAYS_OPEN`) — both validated as BLOCKING (AC-EZ-25). (`WAVE` re-access via `regate_params.wave_count` is defined only when WAVE is un-reserved — Rule 7.)
- `ALWAYS_OPEN` — after first clear the boss is permanently accessible (no re-gate).
- `FULL_REGATE` — the original gate must be re-paid every time (reserved for special/limited bosses; no MVP content).

The "boss defeated at least once" flag is owned by Exploration Progress; this system reads it to select first-access vs. re-access behavior.

**Rule 10 — Enemy DB is the source of truth.** Encounter Zone stores no enemy stats, elements, regions, or loot — only `enemy_id` references. It reads `enemy_class` (to validate WILD-in-patches / BOSS-in-boss-slots), `spawn_enabled` (excluded when false), and respects `tier` (always 1 in MVP; no tier logic). An `enemy_id` in a spawn pool that is missing, `spawn_enabled == false`, or the wrong class is a content error (Edge Cases).

**Rule 11 — MVP content scope.** One zone; 3–4 terrain patch types drawn from ~8 WILD enemy types (each patch honoring the Rule 2a identity-enemy + weight-floor invariants); 2 bosses, both `OVERWORLD`/`WIN_COUNT`/`LIGHTER_REGATE` on the shared zone-win counter (Boss 1 `required_wins = 6`, Boss 2 `required_wins = 10` with `requires_defeated = <Boss 1 boss_id>`; delta regate 2 and 3 respectively). `WAVE`, `REACH`, `DUNGEON_RUSH`, `DUNGEON`, and `HIDDEN` are reserved and unauthored.

### States and Transitions

WILD encounters are stateless — each is an independent per-step roll with no memory. The stateful element is the **boss gate lifecycle**, tracked per boss (persistent state owned by Exploration Progress, read by this system):

| State | Entered when | Exits to |
|-------|-------------|----------|
| `LOCKED` | Zone loaded, gate condition not yet met, boss never defeated | `UNLOCKED` when the gate condition is met (Rule 8) |
| `UNLOCKED` | First-access gate condition met, boss not yet defeated | `DEFEATED` on first victory; back to `LOCKED` only if the gate is progress-based and progress is externally reset (not in MVP) |
| `DEFEATED` | Boss defeated; `wins_at_last_defeat` snapshotted to the current counter (delta re-gate resets to 0) | `RE_ACCESSIBLE` per `repeat_policy` (Rule 9) — for `LIGHTER_REGATE`, only once the delta re-gate is met again |
| `RE_ACCESSIBLE` | Post-defeat, re-access gate met (`LIGHTER_REGATE`: `win_count − wins_at_last_defeat >= regate_params.required_wins`) | On each subsequent clear, re-snapshots `wins_at_last_defeat` and returns to `DEFEATED` (delta re-gate) — the player banks the delta again to re-fight |

The `DEFEATED → RE_ACCESSIBLE` edge branches on `repeat_policy`: `LIGHTER_REGATE` enters `RE_ACCESSIBLE` behind the reduced **delta** `regate_params` gate (MVP default) — measured as new wins since `wins_at_last_defeat`, so `DEFEATED` is a genuine resting state the player must farm out of, not an instantaneous pass-through; `ALWAYS_OPEN` enters a permanently-`UNLOCKED` `RE_ACCESSIBLE` with no re-gate evaluation; `FULL_REGATE` (reserved) re-imposes the original first-access gate. `OPEN` gates begin already `UNLOCKED`.

*(Reserved — activated when WAVE is un-reserved, Rule 7: a `WAVE` boss would run a transient `WAVE_IN_PROGRESS(n)` sub-sequence on arena entry — cycling `wave_count` battles, aborting to arena-reset on any defeat/flee, offering the boss after the final wave, and never persisting mid-sequence progress. No MVP content exercises this path.)*

The per-encounter transient flow (WILD): `EXPLORING` (player moving in a patch) → `ENCOUNTER_TRIGGERED` (EZ-1 roll succeeds) → enemy resolved (EZ-2) and handed to TBC → on `battle_ended`, return to `EXPLORING`. Encounter Zone holds none of this between steps — the movement/step state is Overworld Navigation's.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Enemy Database** | ← reads | `enemy_id` references resolve to entries; reads `enemy_class` (WILD/BOSS validation), `spawn_enabled` (exclude if false), `tier` (respected, always 1 in MVP). Stores no enemy data itself. |
| **Turn-Based Combat** | → hands off | On a resolved encounter, passes the selected `enemy_id` (and boss/wild context so TBC applies the correct flee rule — WILD fleeable, BOSS not, TBC Rule 7). TBC instantiates the enemy and owns the battle. |
| **Overworld Navigation** *(Not Started)* | ← triggered by | Calls into Encounter Zone with the player's current `terrain_type` on each step; Encounter Zone runs EZ-1 and, on success, EZ-2. Movement detection and step counting belong to Overworld Navigation. |
| **Zone & World Map** *(Not Started)* | ↔ provisional | Owns the spatial realization of terrain patches, boss placement, and — for the reserved `WAVE` arena + `REACH`/`DUNGEON_RUSH` gates + `DUNGEON`/`HIDDEN` placement — the actual map geometry. This GDD defines *what a gate requires*; Zone & World Map defines *where it physically is*. **Three spatial contracts this GDD imposes** (see OQ-EZ-6): (1) tiles are single-tagged with exactly one `terrain_type` **or** the `PATH` tag — encounters resolve against the tile stepped *onto*, and `PATH`/non-terrain tiles never roll EZ-1; (2) an `OVERWORLD` boss is a static, non-encounter map entity (its tile must not also be a forced-encounter terrain tile, so boss re-access is never gated behind an unwanted WILD gauntlet); (3) if `WAVE` is un-reserved later, it requires a dedicated arena entry point distinct from open-terrain encounters. |
| **Exploration Progress** *(Not Started)* | ↔ reads/writes | Owns the persistent per-boss gate state (win counters, "defeated once" flag). Encounter Zone reads it to evaluate gates (Rule 8) and select first-vs-re-access (Rule 9); it does not store this itself. |
| **Drop System** | (indirect) | No direct interface — drops flow TBC → Drop System on `battle_ended`. Encounter Zone's only contribution is selecting *which* enemy is fought, which determines the loot pool in play. |

## Formulas

Both formulas use the project's **deterministic seeded RNG** convention: an injected `RandomNumberGenerator` (never the global `randf()`/`randi()`), so a given `(seed, terrain patch, progress state)` reproduces exactly — required for testable ACs (same stance as Drop System DS-1). **Neither formula contains a `floor()`/`round()`/`ceil()` operation** — EZ-1 is a pure float comparison, EZ-2 is pure integer arithmetic. No epsilon nudge is needed in either, and no python3 float scan is required. This is stated explicitly so a reviewer does not flag the absence as an omission.

### EZ-1 — Per-Step Encounter Trigger

`triggered = rng.randf() < encounter_rate`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Encounter rate | `encounter_rate` | float | [0.0, 1.0] | Per-step trigger probability on the terrain patch (set by `density_class`) |
| RNG draw | `rng.randf()` | float | [0.0, 1.0) | Seeded draw — **half-open**, never returns 1.0 exactly |
| Output | `triggered` | bool | {false, true} | Whether an encounter fires this step |

**Output range:** boolean. **Strict `<`** (matches Drop System DS-1). Boundary behavior is a *feature* of the half-open `randf()` interval, not an edge case:
- `encounter_rate = 0.0` → `randf() < 0.0` is always false → never triggers.
- `encounter_rate = 1.0` → `randf() < 1.0` is always true (randf never reaches 1.0) → triggers every step.

**Expected steps to encounter:** `E[steps] = 1 / encounter_rate` (defined only for `encounter_rate > 0`; at `encounter_rate = 0.0` the expectation is infinite — never triggers — so any tooling that displays `E[steps]` must special-case rate 0 rather than dividing).

**Worked example:** `encounter_rate = 0.15`; draw `0.09` → `0.09 < 0.15` → **true** (encounter). Draw `0.22` → **false** (no encounter). Expected gap = 1/0.15 ≈ **6.7 steps**.

### EZ-2 — Weighted Enemy Selection

Cumulative-weight walk against a single integer draw. **`subpool` here is the *filtered* pool** — entries that are missing, `spawn_enabled == false`, wrong-class, or `spawn_weight <= 0` are excluded *before* this runs (EC-EZ-02/03/04), and `total_weight` is recomputed from the survivors. The walk operates only on clean, positive-weight entries:

```
subpool = filter_valid(raw_subpool)              # EC-EZ-02/03/04 exclusions applied first
total_weight = sum(e.spawn_weight for e in subpool)
if total_weight == 0:                            # empty after filtering — EC-EZ-01
    return StringName("")
roll = rng.randi_range(1, total_weight)          # inclusive both ends
cumulative = 0
for e in subpool:
    cumulative += e.spawn_weight
    if roll <= cumulative:
        return e.enemy_id
return StringName("")                             # defensive: unreachable with valid input, but required for a typed return
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Sub-pool | `subpool` | Array[{enemy_id, spawn_weight}] | size ≥ 1 | The terrain patch's weighted candidates |
| Spawn weight | `spawn_weight` | int | [1, ∞) | Authored relative weight; only ratios matter |
| Total weight | `total_weight` | int | [1, ∞) | Sum of all weights; computed fresh each draw |
| Roll | `roll` | int | [1, total_weight] | Seeded `randi_range` draw, inclusive both ends |
| Output | `enemy_id` | StringName | authored ID set | The selected enemy |

**Output range:** one `enemy_id`. Pure integer arithmetic. `randi_range(1, total_weight)` with `roll <= cumulative` is the conventional form — a `[0, …]` draw would bias the first entry. **Single-entry pool** returns its only member with no special case. **Empty pool** is a content error handled in Edge Cases (log + sentinel `StringName("")`), not guarded by the formula.

**Worked example (3-enemy pool, all branches exercised):**

| enemy_id | spawn_weight | cumulative | probability |
|----------|-------------|------------|-------------|
| `iron_crawler` | 10 | 10 | 50% |
| `volt_drone` | 6 | 16 | 30% |
| `rust_hulk` | 4 | 20 | 20% |

`total_weight = 20`. Roll **7** → `7 ≤ 10` → **iron_crawler**. Roll **13** → `13 > 10`, `13 ≤ 16` → **volt_drone**. Roll **19** → `19 > 16`, `19 ≤ 20` → **rust_hulk**. The boundary rolls (exactly 10, 16, 20) are the discriminating cases — `<=` vs `<` in the walk would diverge there, so ACs must assert on them.

### Density-band rates (tuning anchors — full ranges in Tuning Knobs)

| `density_class` | `encounter_rate` | Expected steps/encounter | Role |
|-----------------|------------------|--------------------------|------|
| `SPARSE` | 0.07 | ~14 | Transitional terrain — light hazard, not a grind tax |
| `STANDARD` | 0.15 | ~6.7 | The baseline farming anchor (≈ classic tall-grass feel) |
| `DENSE` | 0.35 | ~2.9 | Fast-farm biome — **2.3× STANDARD's throughput**, the reason to seek it out |

DENSE/STANDARD = 2.3× more encounters per step justifies the fast-farm role; below ~1.6× players wouldn't bother (the floor enforced by AC-EZ-13 and Tuning Knob warning 2), above 0.45 it becomes mobile combat-spam.

## Edge Cases

**EC-EZ-01 — Empty enemy sub-pool.** A terrain patch whose `enemy_subpool` is empty (or has zero total weight): EZ-2 cannot select. Log a content error naming the `terrain_type` and `zone_id`; return sentinel `StringName("")`; the caller (Overworld Navigation) treats a sentinel result as "no encounter this step" and does not start a battle. Never crash. *Verified by AC-EZ-26.*

**EC-EZ-02 — Spawn entry references a missing or disabled enemy.** A `SpawnEntry.enemy_id` that (a) has no Enemy DB entry, or (b) has `spawn_enabled == false`: the entry is skipped at selection time — excluded from `total_weight` and never returned. If skipping empties the pool, EC-EZ-01 applies. A missing ID additionally logs a content error. *Verified by AC-EZ-27 / AC-EZ-28.*

**EC-EZ-03 — Wrong enemy class for the slot.** A `BOSS`-class `enemy_id` placed in a terrain `enemy_subpool`, or a `WILD`-class `enemy_id` placed in a `boss_encounters` slot: content error, the misplaced entry is excluded (a WILD in a boss slot makes that boss unofferable; validation flags it). Class integrity is a content-authoring invariant. *Verified by AC-EZ-30 / AC-EZ-31.*

**EC-EZ-04 — `spawn_weight` of 0 or negative.** A weight ≤ 0 is invalid (weights must be ≥ 1). A 0-weight entry can never be selected (contributes nothing to `total_weight`) — treated as absent with a content warning; a negative weight is a content error (clamped to exclusion). The formula assumes positive integers. *Verified by AC-EZ-32 (zero) / AC-EZ-33 (negative).*

**EC-EZ-05 — `encounter_rate` at 0.0 or 1.0.** Both are legal, not errors: 0.0 = a terrain patch that never triggers (a safe "walk-through" band); 1.0 = triggers every step (extreme DENSE). These are the documented EZ-1 boundary behaviors, exposed as tuning extremes. Values outside [0.0, 1.0] are a content error (clamped to range). *Verified by AC-EZ-02.*

**EC-EZ-06 — WAVE gate aborted mid-sequence *(RESERVED — WAVE cut from MVP, Rule 7)*.** When `WAVE` is un-reserved: during a `WAVE` boss gate, if the player is defeated or flees before the final wave, the wave attempt aborts — arena resets, no boss appears, no gate progress banked (transient, all-or-nothing); re-entering restarts from wave 1; a won sequence immediately offers the boss; a mid-sequence crash/reload discards wave progress (re-enter at wave 1). *No MVP content exercises this. Verifying ACs (WAVE win / defeat-abort / flee-abort / reload-discard) are authored when WAVE is un-reserved — see OQ-EZ-3.*

**EC-EZ-07 — Missing or malformed `gate_params`.** A `gate_type` whose required `gate_params` key is absent (e.g. `WIN_COUNT` with no `required_wins`): content error at load; the boss defaults to `LOCKED` and unofferable (fail-safe — never accidentally `OPEN`). Validation names the boss and the missing key. Conversely, an `OPEN` boss carrying spurious params (e.g. `{ required_wins: 3 }`) ignores them and evaluates `UNLOCKED`, with a content *warning* (not error) so the author cleans it up. *Verified by AC-EZ-34 (WIN_COUNT missing key) / AC-EZ-35 (OPEN ignores spurious params) / AC-EZ-36 (OPEN with empty params is valid).*

**EC-EZ-08 — Reserved `gate_type` authored in MVP content.** A boss authored with `WAVE`, `REACH`, or `DUNGEON_RUSH` while those are reserved (WAVE cut from MVP; REACH/DUNGEON_RUSH awaiting their spatial systems): content error — the reserved values are not yet fulfillable. The boss is `LOCKED` and unofferable. This guards against content outrunning the systems (or design decisions) that realize it. *Verified by AC-EZ-37 (REACH) / AC-EZ-38 (DUNGEON_RUSH) / AC-EZ-24 (WAVE).*

**EC-EZ-09 — Re-access before first defeat.** `repeat_policy` only takes effect after the "defeated once" flag is set. Querying re-access on a never-defeated boss returns the *first-access* gate (Rule 8), never the lighter re-gate. A boss cannot skip its first-access gate via the re-access path. *Verified by AC-EZ-39.*

**EC-EZ-10 — Zone or enemy retired mid-progression.** A zone with `spawn_enabled == false` offers no encounters (its patches are inert — EZ-1 never rolls, no enemy is resolved). An enemy set `spawn_enabled == false` after the player has already been farming it: it simply stops appearing (EC-EZ-02 exclusion) — no error, no retroactive effect on already-owned parts. Retirement is graceful. *Zone-level inertness verified by AC-EZ-57; enemy-level exclusion verified by AC-EZ-27 (shared enemy-exclusion fixture).*

**EC-EZ-11 — Exploration Progress unavailable (provisional dependency).** Exploration Progress (#14) does not exist yet. Until it does, gate state is read through a provisional interface; if the progress store is absent at runtime, gates default to their first-access `LOCKED`/`OPEN` authored state and win counters read 0 (no crash). This is a provisional-dependency safeguard, not a shipping behavior. *Verified by AC-EZ-40a (BLOCKING, testable now — no-crash + safe defaults); live integration by AC-EZ-40b (deferred).*

**EC-EZ-12 — `gate_params.requires_defeated` names a non-existent boss.** A `requires_defeated` StringName that does not resolve to any `boss_id` in this zone's `boss_encounters` (e.g. a typo, or a prerequisite boss later removed from the zone) is a content error: the prerequisite is unresolvable, so the sequencing gate (Rule 8) cannot be satisfied. The boss defaults to `LOCKED` and unofferable — **fail-safe, never fall through to accessible on a dangling prerequisite** (a fail-*open* would silently bypass the entire sequencing constraint). Validation names the boss and the unresolved `requires_defeated` value. This mirrors the missing-`required_wins` fail-safe (EC-EZ-07) and the missing-`enemy_id` handling (EC-EZ-02). *Verified by AC-EZ-58.*

## Dependencies

### Upstream (Encounter Zone reads from these)

| System | What Encounter Zone reads | Status | Hard/Soft |
|--------|---------------------------|--------|-----------|
| **Enemy Database** | `enemy_id` → entry resolution; `enemy_class` (WILD/BOSS slot validation), `spawn_enabled` (exclude if false), `tier` (respected, always 1 in MVP) | Approved | Hard |
| **Exploration Progress** *(Not Started)* | Persistent gate state: the shared cumulative zone-win counter, the per-boss "defeated once" flag, and the per-boss `wins_at_last_defeat` snapshot — read to evaluate first-access gates (Rule 8) and the delta re-gate (Rule 9). **Storage contract fixed by Rule 8a/9**: one cumulative, never-resetting, zone-wide counter incremented only on a WILD victory (fled/lost never increment); plus, per boss, a `wins_at_last_defeat` value (re)written to the current counter on each defeat so re-access can measure the win delta. Encounter Zone owns these semantics; Exploration Progress implements the increment + snapshot hooks to them. | Not Started | Soft (provisional interface; EC-EZ-11 fallback until it exists) |

### Downstream (these systems read from / realize this one)

| System | What it reads | Status | Obligation on that GDD |
|--------|---------------|--------|------------------------|
| **Turn-Based Combat** | Receives the resolved `enemy_id` + WILD/BOSS context at encounter start (lateral handoff; TBC instantiates the enemy and applies its flee rule — TBC Rule 7) | Approved | None new — TBC already accepts an enemy at battle start; Encounter Zone supplies the ID and class context |
| **Zone & World Map** *(Not Started)* | The zone's `terrain_patches`, `boss_encounters`, placement, and gate structure — to realize them as actual map geometry (where a terrain patch physically is, where a boss lives, and the spatial half of reserved `REACH`/`DUNGEON_RUSH`/`DUNGEON`/`HIDDEN`) | Not Started | Must list Encounter Zone; owns the spatial realization; must fulfill the reserved-gate spatial contract when those gates are authored |
| **Overworld Navigation** *(Not Started)* | Calls Encounter Zone with the player's current `terrain_type` per step (EZ-1 trigger, EZ-2 resolution); owns step detection and movement | Not Started | Must list Encounter Zone; owns movement/step state; treats a sentinel `enemy_id` as "no encounter this step" (EC-EZ-01) |

### Bidirectionality

- **Enemy Database** already lists Encounter Zone as a downstream reader (its Interactions table: *"Encounter Zone — `id`, `enemy_class`, `tier`, `spawn_enabled` — builds spawn tables; spawn placement is Encounter Zone's domain; this schema holds no zone data"*) — bidirectionality confirmed, no Enemy DB change needed.
- **Turn-Based Combat** does not need to list Encounter Zone as a formal dependency — the encounter→battle handoff is Encounter Zone calling into TBC's existing battle-start entry (TBC already accepts an enemy at `BATTLE_INIT`). No TBC change required.
- **Zone & World Map, Overworld Navigation, Exploration Progress** (all Not Started) must list Encounter Zone when authored. The reserved `REACH`/`DUNGEON_RUSH` gates and `DUNGEON`/`HIDDEN` placements carry a **provisional spatial contract** those systems will fulfill.

### Errata obligations this GDD creates on Approved documents

None. Encounter Zone reads Enemy DB through its existing, already-documented interface (`id`, `enemy_class`, `spawn_enabled`, `tier`) and hands off to TBC through its existing battle-start entry. No Approved document requires modification.

## Tuning Knobs

| Knob | Value | Safe Range | What Changing It Does |
|------|-------|------------|----------------------|
| `encounter_rate[SPARSE]` | 0.07 | 0.04–0.10 | Transitional-terrain trigger chance (~14 steps/encounter at default). Below 0.04, SPARSE is functionally "no encounters" and the terrain loses navigational meaning; above 0.10 it blurs into a slow STANDARD. |
| `encounter_rate[STANDARD]` | 0.15 | 0.12–0.20 | The baseline farming rate (~6.7 steps/encounter). This is the anchor — the default farming feel. At 0.20 (~5 steps) it starts to feel busy; below 0.12 it collapses toward SPARSE. |
| `encounter_rate[DENSE]` | 0.35 | 0.25–0.45 | Fast-farm biome rate (~2.9 steps/encounter). Must stay meaningfully above STANDARD (≥ ~1.6×) to justify the biome; above 0.45 (~2.2 steps) it becomes mobile combat-spam. First fatigue adjustment: pull toward 0.28–0.30, not a redesign. **This range is provisional on OQ-EZ-8** (inter-encounter recovery model, owned by TBC): DENSE's throughput is only a *cost* trade-off if attrition between fights is real — if TBC full-heals between encounters, DENSE is pure upside and the range needs re-derivation. Do not finalize DENSE tuning until OQ-EZ-8 is resolved. |
| `WIN_COUNT.required_wins` — Boss 1 (first access) | 6 | 4–12 | Shared-counter threshold to open Boss 1. At 4, the boss opens before zone familiarity builds; above 12, first access feels like a grind wall. |
| `WIN_COUNT.required_wins` — Boss 2 (first access) | 10 | 8–16 | Shared-counter threshold to open Boss 2, the zone's deeper apex. MUST stay meaningfully above Boss 1's (a ≥ ~1.5× gap, default 6→10) or the two bosses unlock too close together and the escalation reads as one gate. Above 16 the apex feels like a grind wall for a single-zone MVP. |
| `regate_params.required_wins` — Boss 1 (re-access) | 2 | 1–4 | Lighter re-gate after first defeat (`LIGHTER_REGATE`), measured as **new wins since last defeat** (delta, Rule 9) so it recurs every re-fight. Keeps boss-part farming viable without being free. Must stay ≥ 1 and < Boss 1's first-access value (AC-EZ-25). |
| `regate_params.required_wins` — Boss 2 (re-access) | 3 | 1–6 | Lighter **delta** re-gate for the apex boss. Scaled up from Boss 1's re-gate because its parts are the zone's scarcest; still must stay ≥ 1 and < Boss 2's first-access value (AC-EZ-25). |
| `WAVE.*` (reserved) | — | — | `wave_count` / `wave_pools` and their re-gate counterparts are defined only if `WAVE` is un-reserved (Rule 7). No MVP tuning. |
| `spawn_weight` (authoring guidance) | — | 1–100 typical | Relative enemy frequency within a patch. Only ratios matter (weight 10 vs 5 = 2:1). Guidance: keep the spread readable (a "rare" target at ~1/5 of a "common" filler's weight reads as noticeably rarer without being unfarmable). |

**Knob interaction warnings:**
1. **Re-access knobs must stay strictly below their first-access counterparts, and ≥ 1** (Boss 1: 1 ≤ 2 < 6; Boss 2: 1 ≤ 3 < 10) or `LIGHTER_REGATE` provides no actual relief — a re-gate ≥ first-access silently becomes `FULL_REGATE`, and a re-gate of 0 silently becomes `ALWAYS_OPEN`. Either way the "grinding stays viable" design intent (Rule 9) fails silently. This is now a BLOCKING content check (AC-EZ-25).
2. **`DENSE`/`STANDARD` ratio is the load-bearing pacing lever**, not the absolute DENSE value. Tuning both up together preserves the ratio but raises baseline combat frequency across the whole zone — check the ratio (target ≥ 1.6×, default 2.3×) before shipping a rate change.
3. **`required_wins` (first access) is coupled to the zone's WILD variety** — a high win count in a zone with few enemy types means repetitive farming to open the boss; raise variety or lower the count together.
4. **`required_wins` (first access) is coupled to the starting terrain's `density_class`** — the win count is a *familiarity* proxy, but win *speed* scales with encounter rate. At DENSE (0.35, ~2.9 steps/encounter) Boss 1's 6-win gate can open in ~17 steps, before the player has seen the zone's roster — undermining the "earned arrival" intent. Content guidance: the player's early/starting terrain should be `SPARSE`/`STANDARD`, not `DENSE`; if a zone is DENSE-dominant, raise `required_wins` toward the top of its safe range. (The felt cost of DENSE also presumes the OQ-EZ-8 recovery model is non-trivial — see the DENSE knob and OQ-EZ-8.)
5. **`regate_params.required_wins` (re-access) is subject to the *same* density coupling as first access** — warning 4 applies to re-gates too, not just first-access gates. The "viable friction" of the delta re-gate (Rule 9) presumes the boss's adjacent farming terrain is `STANDARD`/`SPARSE`. At `DENSE` (~2.9 steps/encounter) Boss 1's 2-win re-gate compresses to ~6 steps between attempts — cosmetic, not friction, so `LIGHTER_REGATE` reads as `ALWAYS_OPEN` in felt terms even though the delta logic is correct. If re-fight traffic routes through `DENSE` terrain, raise the re-gate toward the top of its safe range (3–4) or lay out the overworld so re-fight paths cross `STANDARD`/`SPARSE` tiles. Do not tune `regate_params.required_wins` in isolation from the farming terrain's `density_class`.

**Owned elsewhere — referenced, not duplicated:** enemy stats/regions/loot (Enemy DB); the drop RNG and pity (Drop System); persistent win-counter and defeated-flag storage (Exploration Progress); step detection and movement (Overworld Navigation).

## Visual/Audio Requirements

> **Ownership note**: Encounter Zone is a spawn-table/logic layer — it owns no assets. The requirements below are obligations it places on the presentation systems (Zone & World Map, World Map UI, Combat UI, Audio System) and the Art Bible. Per-asset specs await the Art Bible.

**VA-1 — Terrain-type readability (binding, load-bearing for the core loop).** Each `terrain_type` must be **visually distinct at a glance** — mechanical grass, junkyard, and pylon field must be instantly tellable apart. The entire "terrain = targeting lever" design (Rule 2, Player Fantasy) collapses if the player can't read which terrain they're standing in. This is the single most important presentation requirement of this system. *(Owned by Art Bible + Zone & World Map tilemap art.)*

**VA-2 — Encounter-trigger beat.** When EZ-1 fires, the transition into battle needs a clear, fast feedback moment (screen effect + audio sting) so the encounter never feels like it "just happened." Classic-RPG encounter-transition register. *(Owned by Overworld Navigation / Combat UI transition; Audio System sting.)*

**VA-3 — Density telegraphing.** `DENSE` biomes should *look* more active/hazardous than `STANDARD` terrain — the player choosing a fast-farm cavern should know they're entering higher encounter frequency. Density is a deliberate player choice, so it must be visible before entry. *(Owned by Art Bible + Zone & World Map.)*

**VA-4 — Boss map presence and gate state.** An accessible boss needs unambiguous map presence (icon/landmark). Gate state must read: locked (gate visible or boss hidden per placement), unlocked/available, and defeated→re-accessible. *(Owned by World Map UI.)*

**VA-5 — WAVE arena framing *(RESERVED — WAVE cut from MVP, Rule 7)*.** If `WAVE` is un-reserved: a `WAVE` gate needs an "arena" framing on entry and a wave-progress readout (wave *n* of *N*) between fights. No MVP presentation obligation. *(Owned by Combat UI + World Map UI when authored.)*

**Audio intent:** distinct per-terrain ambience reinforces VA-1 (a second, non-visual readability channel — you can *hear* which biome you're in); encounter-trigger sting for VA-2; boss-available cue when a gate opens. *(Owned by Audio System.)*

## UI Requirements

Obligations on World Map UI, Overworld Navigation, and Combat UI (Not Started) — layout and interaction belong to those GDDs.

1. **Terrain legibility** (World Map UI / Art Bible): terrain types must be distinguishable on the map — the UI side of VA-1.
2. **Encounter transition** (Overworld Navigation / Combat UI): the trigger→battle handoff must be visually clear; a sentinel `enemy_id` (EC-EZ-01) must *not* start a transition.
3. **Boss gate status readout** (World Map UI): show each boss's gate state and — for `WIN_COUNT` — **the progress toward it against the shared counter (e.g. "3 / 6 wins" for Boss 1, "3 / 10 wins" for Boss 2)**. *Design decision: `WIN_COUNT` progress is **shown**, not hidden.* Rationale: unlike the Drop System's hidden surprise-rescue pity, a boss gate is a **goal** — the player should see a clear objective and its progress. Hiding it would make the boss's appearance feel arbitrary. Because both bosses read one shared counter, the readout also communicates the escalation (crossing 6 unlocks Boss 1 while Boss 2 still shows locked progress toward 10). **Two feedback obligations this creates:** (a) when Boss 2's win threshold is met but Boss 1 is undefeated (sequencing precondition, Rule 8), the readout must show "Defeat Boss 1 first" rather than a met-but-locked count, so the sequencing is legible; (b) because only *wins* advance the counter (Rule 8a), the readout (or a first-flee tooltip) must make clear that fleeing/losing does not count — otherwise a player who flees several fights sees the counter stall with no explanation. For re-access (`LIGHTER_REGATE`), the readout shows the **delta** progress since last defeat (e.g. "1 / 2 wins to re-challenge"), not the raw cumulative counter.
4. **Enemy-terrain discovery** (World Map UI / field guide — obligation, owner TBD): the "there are Crawlers past the scrap dunes" fantasy requires the player to *learn which enemies live in which terrain*. This GDD does not own the surface, but it flags the obligation: a first-encounter-reveals-it roster (or static zone guide) must exist so the player can form a harvest goal rather than grind the wrong terrain blind. Tracked as OQ-EZ-7.
5. **Re-access indication** (World Map UI): a defeated, re-accessible boss should read as "cleared, repeatable" — distinct from a never-defeated locked boss.

*(Former UI Requirement 4 "WAVE progress" is reserved with the WAVE gate — Rule 7 / VA-5.)*

> **📌 UX Flag — Encounter Zone**: this system places map/overworld UI requirements (terrain legibility, boss-gate readouts, wave progress). In Pre-Production, run `/ux-design` for the World Map / overworld screens before writing epics; stories should cite the resulting `design/ux/` spec, not this GDD directly.

## Acceptance Criteria

**Tags:** **BLOCKING** (automated unit/integration test — gates story completion) · **ADVISORY** (content-validation linter — gates content shipping, not code merge) · **DEFERRED** (needs a Not-Started system; write the stub now, activate when it ships). **Test type:** Unit (GUT, injected seeded RNG + stub Enemy DB, no live scene) · Content Validation (offline data linter) · Integration (≥2 systems wired, stubs allowed).

**Seeded-RNG mandate (implementation constraint):** the Encounter Zone system MUST accept an **injected** `RandomNumberGenerator` (or Callable RNG wrapper), never the global `randf()`/`randi()`. Without dependency-injected RNG, the `<` vs `<=` boundary discriminators (AC-EZ-03, AC-EZ-05..07) are unreachable.

### EZ-1 — Encounter Trigger

**AC-EZ-01** (BLOCKING, Unit): `encounter_rate = 0.0` never triggers. GIVEN rate 0.0 and any seed, WHEN EZ-1 runs 10,000 steps, THEN `triggered == false` every step.

**AC-EZ-02** (BLOCKING, Unit): legal rate boundaries + out-of-range clamping. *(Verifies EC-EZ-05)* **A:** rate 1.0, 10,000 steps → triggers every step (`randf()` is `[0,1)`, so `< 1.0` always true). **B:** rate 1.5 (content error) → error logged, effective rate clamped to 1.0. **C:** rate −0.3 → error logged, clamped to 0.0, never triggers. The content-error log is the observable proving clamping.

**AC-EZ-03** (BLOCKING, Unit): `<` operator discrimination via injected draws (not a pre-generated seed sequence — a seed-derived sequence is circular if the tester generates it from their own impl, and `randf()` output is Godot-version-dependent). GIVEN a mock RNG returning a scripted draw list `[0.14, 0.15, 0.16]` at rate 0.15, THEN `triggered == [true, false, false]`. The `0.15` draw is the discriminator: strict `< 0.15` yields `false` (a `<=` impl would yield `true`) — assert `false`. Determinism is proven by the mock RNG being deterministic; no seed-1234 reference array is needed.

### EZ-2 — Weighted Enemy Selection

Canonical fixture (all EZ-2 ACs): `iron_crawler`(w10, cum 10), `volt_drone`(w6, cum 16), `rust_hulk`(w4, cum 20); `total_weight = 20`; all WILD + `spawn_enabled` in stub Enemy DB.

**AC-EZ-04** (BLOCKING, Unit): distribution. GIVEN the fixture and a **freshly-seeded RNG (seed 99) created within this test** (not shared state carried from AC-EZ-03), 10,000 draws, THEN counts fall in iron_crawler 4750–5250 (50%), volt_drone 2750–3250 (30%), rust_hulk 1750–2250 (20%). Bands are ±5–6σ, so a correct impl effectively never fails spuriously. Discriminator: a uniform (weight-ignoring) impl gives ~3333 each → fails all three bands.

**AC-EZ-05** (BLOCKING, Unit): boundary roll = **10** → `iron_crawler` (`<=` lower boundary). `10 <= 10` true. Discriminator: a `roll < cumulative` impl falls through to `volt_drone` — assert `iron_crawler`.

**AC-EZ-06** (BLOCKING, Unit): boundary roll = **16** → `volt_drone` (middle boundary). `16 > 10`, `16 <= 16` true. A `<` impl continues to `rust_hulk` — assert `volt_drone`.

**AC-EZ-07** (BLOCKING, Unit): boundary roll = **20** → `rust_hulk` (upper boundary / last entry reachable). `20 <= 20` true. Catches the `randi_range(0, total−1)` off-by-one (max roll 19 would make `rust_hulk` unreachable) — assert on roll=20 specifically.

**AC-EZ-08** (BLOCKING, Unit): interior rolls (regression baseline). Roll 7 → iron_crawler; 13 → volt_drone; 19 → rust_hulk. (Non-discriminating for `<`/`<=`; the boundary ACs are the discriminators.)

**AC-EZ-09** (BLOCKING, Unit): single-entry pool. GIVEN `{iron_crawler, w1}`, `total_weight = 1`, `randi_range(1,1)` always 1, THEN returns `iron_crawler`, no error, no divide-by-zero. Confirms no special-case guard needed.

### Density-Band Rate Mapping

**AC-EZ-10** (ADVISORY, Content Val): `SPARSE` → `encounter_rate == 0.07` (`abs(rate − 0.07) < 1e-9`).
**AC-EZ-11** (ADVISORY, Content Val): `STANDARD` → `0.15` (within 1e-9).
**AC-EZ-12** (ADVISORY, Content Val): `DENSE` → `0.35` (within 1e-9).
**AC-EZ-13** (ADVISORY, Content Val): pacing ratio. `rate[DENSE] / rate[STANDARD] >= 1.6` (default 2.33 passes). Enforces Tuning Knob warning 2.
**AC-EZ-14** (ADVISORY, Content Val): unknown `density_class` (e.g. `"SWAMP"`) → content error logged + `encounter_rate` defaults to STANDARD 0.15 (conservative fallback, never DENSE).

### WILD Handoff to TBC

**AC-EZ-15** (BLOCKING, Integration): correct handoff — both classes. Stub TBC records `(enemy_id, is_boss, fleeable)`. **Scenario A (WILD):** GIVEN pool `{bolt_skitter w8, iron_crawler w2}`, a **stub EZ-1 forced to `triggered = true`** (removes seed ambiguity — a seed where EZ-1 never fires would vacuously pass) and EZ-2 seeded to pick `bolt_skitter`, THEN stub TBC receives exactly one call `("bolt_skitter", false, true)` (WILD is fleeable, TBC Rule 7). **Scenario B (BOSS):** GIVEN an `OPEN` boss `boss_id = "zone_boss"`, player initiates the boss encounter, THEN stub TBC receives `("zone_boss", true, false)` (boss is not fleeable). Scenario B guards against a `return true` fleeable flag that Scenario A alone cannot catch. Upgrade trigger: replace stub EZ-1 with live terrain-step driving when Overworld Navigation ships.

### Boss Gate — WIN_COUNT (shared cumulative counter: Boss 1 @ 6, Boss 2 @ 10)

Both bosses read one shared `zone_win_count` (Rule 8a) at their own `required_wins` threshold.

**AC-EZ-16** (BLOCKING, Unit): Boss 1 — 5 wins = `LOCKED`. GIVEN `zone_win_count = 5`, `defeated_once = false`, THEN `LOCKED`.
**AC-EZ-17** (BLOCKING, Unit): Boss 1 — exactly 6 wins = `UNLOCKED` (threshold `>=` discriminator). GIVEN win_count 6, THEN `UNLOCKED` — a `> 6` impl stays LOCKED; assert `UNLOCKED`.
**AC-EZ-18** (BLOCKING, Unit): Boss 1 — 7 wins = `UNLOCKED` (no upper-bound "window" regression).

**AC-EZ-19** (BLOCKING, Unit): Boss 2 — threshold at 10 (sequencing precondition satisfied). GIVEN Boss 1 `defeated_once = true` (so the sequencing precondition is met and the win threshold is the sole variable), `zone_win_count = 9`, THEN Boss 2 `LOCKED`; GIVEN the same with `zone_win_count = 10`, THEN Boss 2 `UNLOCKED` (`>= 10` discriminator — a `> 10` impl stays LOCKED at 10; assert `UNLOCKED`).

**AC-EZ-20** (BLOCKING, Unit): shared-counter dual gate — the two thresholds are read independently off one counter, with Boss 2's sequencing precondition satisfied. GIVEN `zone_win_count = 6`, Boss 1 not yet defeated, THEN Boss 1 `UNLOCKED` **and** Boss 2 `LOCKED` (6 ≥ 6 but 6 < 10). GIVEN `zone_win_count = 10` **and** Boss 1 `defeated_once = true`, THEN **both** `UNLOCKED`. Discriminator: an impl using one flag for "any boss unlocked" opens Boss 2 at 6; assert Boss 2 `LOCKED` at 6. (The Boss-1-not-defeated-at-10 case is the dedicated sequencing discriminator AC-EZ-56.)

**AC-EZ-21** (BLOCKING, Unit): Boss 2 `LIGHTER_REGATE` **delta** re-gate at 3. GIVEN Boss 2, `defeated_once = true`, `wins_at_last_defeat = 10` (snapshot at its defeat), `regate_params.required_wins = 3`. GIVEN `zone_win_count = 13` → delta `13 − 10 = 3` → `UNLOCKED` (`3 >= 3`). GIVEN `zone_win_count = 12` → delta 2 → `LOCKED`. Confirms Boss 2 re-access uses its own regate value (3), not Boss 1's (2) and not its first-access value (10). Discriminator vs the raw-counter bug: a raw-counter impl returns `UNLOCKED` at `zone_win_count = 12` (`12 >= 3`) — assert `LOCKED`.

### Repeat Policy (LIGHTER_REGATE)

**AC-EZ-22** (BLOCKING, Unit): re-gate **re-locks the boss at the moment of defeat** — the central discriminator for the delta-counter fix. GIVEN Boss 1 just defeated at `zone_win_count = 6` → `wins_at_last_defeat = 6`, `defeated_once = true`, `regate_params.required_wins = 2`, `zone_win_count` still `6` → delta `6 − 6 = 0` → `LOCKED`. Discriminator: BOTH the raw-counter bug (`6 >= 2` → UNLOCKED) AND an ignore-`defeated_once` first-access impl (`6 >= 6` → UNLOCKED) return the wrong answer; assert `LOCKED`. This is the AC that proves `LIGHTER_REGATE` does not collapse into `ALWAYS_OPEN`.
**AC-EZ-23** (BLOCKING, Unit): re-gate met after banking the delta. GIVEN Boss 1, `defeated_once = true`, `wins_at_last_defeat = 6`, `regate_params.required_wins = 2`. GIVEN `zone_win_count = 8` → delta 2 → `UNLOCKED` (`2 >= 2`). GIVEN `zone_win_count = 7` → delta 1 → `LOCKED`. The 7→LOCKED / 8→UNLOCKED boundary is the `>=` discriminator on the delta; a raw-counter impl wrongly returns UNLOCKED at 7.
**AC-EZ-24** (BLOCKING, Unit): reserved `WAVE` gate is fail-safe. *(Verifies EC-EZ-08 — WAVE variant)* GIVEN a boss authored `gate_type = WAVE` in MVP content, THEN content error logged naming the boss + gate_type, boss `LOCKED` and unofferable (no crash, no fall-through to OPEN). Confirms WAVE's reserved enum value is defined but not activatable in MVP.
**AC-EZ-25** (BLOCKING, Content Val): re-access strictly lighter **and ≥ 1** — promoted from ADVISORY because a silent violation removes a design pillar with no runtime symptom. **A:** `regate_params.required_wins >= gate_params.required_wins` (e.g. Boss 1 regate 6 vs first-access 6) → content error naming the boss + both values; the "lighter" promise is broken (degenerates to `FULL_REGATE`). **B:** `regate_params.required_wins == 0` → content error (degenerates to `ALWAYS_OPEN`). **C:** valid defaults (Boss 1 `1 ≤ 2 < 6`, Boss 2 `1 ≤ 3 < 10`) → no error. Enforces Tuning Knob warning 1.

### Empty / Invalid Pool (EC-EZ-01/02/03/04)

**AC-EZ-26** (BLOCKING, Unit): empty sub-pool. *(Verifies EC-EZ-01)* GIVEN `enemy_subpool = []`, forced EZ-1 trigger, THEN EZ-2 returns `StringName("")`, content error logged (naming terrain_type + zone_id), no crash, stub caller starts no battle.
**AC-EZ-27** (BLOCKING, Unit): disabled enemy excluded. *(Verifies EC-EZ-02 + EC-EZ-10)* pool `{iron_crawler w10, retired_bot w10}`, `retired_bot spawn_enabled=false`, 1,000 draws → `retired_bot` never returned, `iron_crawler` all 1,000, no error for iron_crawler.
**AC-EZ-28** (BLOCKING, Unit): missing enemy excluded + error. pool `{known_enemy w10, ghost_id w5}`, `ghost_id` has no entry → error logged naming ghost_id, contributes 0 to total_weight, only `known_enemy` returned.
**AC-EZ-29** (BLOCKING, Unit): all-disabled drains to empty → chains to EC-EZ-01 (sentinel + error). Tests composition of EC-EZ-02 exclusion into EC-EZ-01.
**AC-EZ-30** (BLOCKING, Unit): BOSS in terrain pool excluded. *(Verifies EC-EZ-03)* `{iron_crawler w10 WILD, zone_boss_1 w5 BOSS}` → error naming zone_boss_1 + slot, excluded from total_weight, only iron_crawler returned.
**AC-EZ-31** (BLOCKING, Unit): WILD in boss slot → boss LOCKED. `boss_id = "iron_crawler"` (WILD) → error logged, boss entry excluded, LOCKED (fail-safe, not OPEN).
**AC-EZ-32** (BLOCKING, Unit): `spawn_weight = 0` excluded with **warning**. *(Verifies EC-EZ-04 — zero)* `{iron_crawler w10, empty_shell w0, volt_drone w5}` → warning (not error) for empty_shell, total_weight 15, empty_shell never returned.
**AC-EZ-33** (BLOCKING, Unit): negative weight → **error**, excluded. *(Verifies EC-EZ-04 — negative)* `{iron_crawler w10, corrupt_entry w−3}` → error (severity distinct from the w0 warning), excluded, total_weight 10.

### Gate Params / Reserved Gates (EC-EZ-07/08)

**AC-EZ-34** (BLOCKING, Unit): WIN_COUNT missing `required_wins`. *(Verifies EC-EZ-07)* `gate_params = {}` → error naming boss + missing key, boss `LOCKED`, never offerable. A `required_wins=0` default would wrongly open it — this catches that.
**AC-EZ-35** (BLOCKING, Unit): OPEN with spurious params. *(Verifies EC-EZ-07 — spurious-params half)* GIVEN `gate_type = OPEN`, `gate_params = { required_wins: 3 }`, THEN evaluates `UNLOCKED` (params ignored, NOT interpreted as a WIN_COUNT gate) with a content *warning* (not error). Discriminator: an impl that reads `required_wins` off any gate would treat this as a 3-win gate and LOCK it below 3; assert `UNLOCKED`.
**AC-EZ-36** (BLOCKING, Unit): OPEN with empty `gate_params` is valid — no error, no warning, evaluates `UNLOCKED` immediately. Confirms OPEN is the one type needing no params.
**AC-EZ-37** (BLOCKING, Unit): `REACH` in MVP → content error naming boss + gate_type, `LOCKED`. *(Verifies EC-EZ-08)*
**AC-EZ-38** (BLOCKING, Unit): `DUNGEON_RUSH` in MVP → content error, `LOCKED`. (37/38 confirm reserved enum values are defined but fail-safe — no crash, no fall-through to OPEN.)

### Re-access Before Defeat (EC-EZ-09)

**AC-EZ-39** (BLOCKING, Unit): re-access path gated on `defeated_once`. *(Verifies EC-EZ-09)* **A (negative):** GIVEN Boss 1, `defeated_once = false`, win_count 3, first-access 6, re-gate 2, THEN `LOCKED` (first-access applies; 3 < 6). Minimum fixture discriminating the flag: with `wins_at_last_defeat` unset (0 before any defeat), win_count 3 PASSES the delta re-gate (`3 − 0 = 3 ≥ 2`) but FAILS first-access (`3 < 6`) — an impl ignoring `defeated_once` and applying the re-gate path returns UNLOCKED. **B (positive, guards against all-LOCKED impl):** GIVEN `defeated_once = false`, win_count 6, first-access 6, THEN `UNLOCKED` (first-access path returns UNLOCKED when met — an impl that never unlocks pre-defeat fails this).

### Provisional / Deferred Integration

**AC-EZ-40a** (BLOCKING, Unit): Exploration Progress absent — no crash, safe defaults (testable NOW; this fallback is live for the whole MVP dev period). *(Verifies EC-EZ-11)* GIVEN a null/not-connected progress stub, WIN_COUNT gate → win counter reads 0, state `LOCKED`, provisional **warning** (not error) logged, no crash; OPEN gate → `UNLOCKED`. Uses a null stub — no live Exploration Progress needed.
**AC-EZ-40b** (DEFERRED, Integration): Exploration Progress connected — live counter reads correctly and drives the real gate. Activate when Exploration Progress ships.
**AC-EZ-41** (DEFERRED, Integration): Overworld Navigation runs EZ-1 only on terrain tiles, never path tiles (100 terrain + 50 path steps → 100 evaluations).
**AC-EZ-42** (DEFERRED, Integration): sentinel `enemy_id` → no battle transition, no TBC call.
**AC-EZ-43** (DEFERRED, Integration): WIN_COUNT counter persists across save/reload (4 wins → reload → reads 4, LOCKED).
**AC-EZ-44** (DEFERRED, Integration): `defeated_once` persists across save/reload (first kill → reload → lighter re-gate applies).
**AC-EZ-45** (DEFERRED, Integration): standing on a `MECHANICAL_GRASS` tile → Overworld Navigation calls EZ with `terrain_type = MECHANICAL_GRASS` (Zone & World Map spatial realization).
**AC-EZ-46** (DEFERRED, Integration): both OVERWORLD bosses have reachable map presence.

### MVP Content Scope (Content Validation)

**AC-EZ-47** (ADVISORY, Content Val): exactly 1 zone entry, `spawn_enabled = true`, valid `zone_id`.
**AC-EZ-48** (ADVISORY, Content Val): zone has 3–4 terrain patches; every patch `enemy_subpool.size() >= 1`; every entry `spawn_weight >= 1`.
**AC-EZ-49** (ADVISORY, Content Val): exactly 2 boss entries — Boss1 `WIN_COUNT`/`required_wins=6`/`regate 2`/`LIGHTER_REGATE`, Boss2 `WIN_COUNT`/`required_wins=10`/`regate 3`/`LIGHTER_REGATE`, both `OVERWORLD`. Assert Boss2 carries `gate_params.requires_defeated == <Boss1 boss_id>` (sequencing precondition) and Boss1 carries no `requires_defeated`. Assert the escalation gap is machine-checkable: `required_wins[Boss2] − required_wins[Boss1] >= 3` (default 10 − 6 = 4 passes) so the two gates read as distinct without relying on an approximate ratio. No MVP boss uses `WAVE`/`REACH`/`DUNGEON_RUSH`.
**AC-EZ-50** (ADVISORY, Content Val): de-duplicated WILD enemy count across all patches ∈ [6, 10] (target ~8).
**AC-EZ-51** (ADVISORY, Content Val): every `boss_id` resolves to a `BOSS`-class, `spawn_enabled` Enemy DB entry.

### ALWAYS_OPEN Policy

**AC-EZ-52** (BLOCKING, Unit): `repeat_policy = ALWAYS_OPEN`. GIVEN a boss with **first-access `gate_type = WIN_COUNT`, `required_wins = 6`**, `repeat_policy = ALWAYS_OPEN`, `defeated_once = true`, `win_count = 0` (first-access unmet), THEN `UNLOCKED` (permanently accessible after first clear, no re-gate). GIVEN the same boss `defeated_once = false`, `win_count = 0`, THEN the first-access gate still applies (`LOCKED`) — ALWAYS_OPEN only takes effect post-first-defeat. (Gate_type is pinned to WIN_COUNT so Scenario B does not pass spuriously against an OPEN first-access gate, which is always UNLOCKED regardless — that path is AC-EZ-36.)

### Reserved / New Guardrails

**AC-EZ-53** (DEFERRED, Unit): `FULL_REGATE` (reserved). GIVEN a boss with `repeat_policy = FULL_REGATE`, `defeated_once = true`, first-access gate met (win_count ≥ required), THEN `UNLOCKED` (the original full gate re-applies each cycle — not permanently open, not lighter). Reserved; no MVP content authors `FULL_REGATE`. Activate when FULL_REGATE content is authored. The enum value being live without a specified behavior is the latent gap this AC closes.

**AC-EZ-54** (ADVISORY, Content Val): terrain-identity invariants (Rule 2a). **A (identity enemy):** every terrain patch contains ≥ 1 `enemy_id` present in no other patch in the zone → content error naming any patch that fails. Discriminator: a zone where all patches share one pool (cosmetic terrain) fails. **A2 (identity-enemy weight floor):** at least one such patch-exclusive enemy must be **≥ 10% of its patch's `total_weight`** → content warning below the floor. Discriminator: a patch whose only exclusive enemy sits at weight 1 in a 100-weight pool (a token exclusive masking a shared pool) fails A2 while passing A. **B (farmable weight floor):** every `SpawnEntry` with `is_farmable_target == true` has `spawn_weight >= 0.20 * patch.total_weight` → content warning below the floor. The `is_farmable_target` field (Rule 2, Rule 2a) is the machine-readable ground truth the linter queries — no farming-data inference needed. Discriminator: a flagged entry at 15% of its patch fails B. Enforces the targeting-lever promise mechanically instead of by author discipline.

**AC-EZ-55** (DEFERRED, Integration): WIN_COUNT is wins-only (Rule 8a). GIVEN a WIN_COUNT boss, WHEN the player **flees** a zone WILD encounter, THEN `zone_win_count` is unchanged; WHEN the player **loses**, unchanged; WHEN the player **wins**, `+1`. Discriminator: an "any-encounter-ended" increment opens the gate early — assert no increment on flee/loss. Activate when Exploration Progress ships its increment hook (ratifies Rule 8a storage contract).

**AC-EZ-56** (BLOCKING, Unit): Boss 2 sequencing precondition (Rule 8 — `requires_defeated`). GIVEN Boss 2 with `gate_params.requires_defeated = <Boss 1 boss_id>`, `zone_win_count = 10`, Boss 1 `defeated_once = false`, THEN Boss 2 `LOCKED` (win threshold met, prerequisite unmet). GIVEN the same with Boss 1 `defeated_once = true`, THEN Boss 2 `UNLOCKED`. Discriminator: an impl checking only the win threshold opens Boss 2 at 10 regardless of Boss 1 — assert `LOCKED` when Boss 1 is undefeated. This is the AC that enforces the sequential "deeper you go" escalation and forbids the Boss-1-bypass.

**AC-EZ-57** (BLOCKING, Unit): zone-level `spawn_enabled == false` → all patches inert (Rule 1 / EC-EZ-10). GIVEN a zone with `spawn_enabled = false` and a valid populated terrain patch, WHEN a step is taken on that patch, THEN EZ-1 never rolls, EZ-2 is never called, no `enemy_id` is resolved, no crash. Discriminator: an impl that checks only enemy-level `spawn_enabled` (EC-EZ-02) still triggers encounters in a disabled zone — assert zero encounters.

**AC-EZ-58** (BLOCKING, Unit): `requires_defeated` broken reference is fail-safe. *(Verifies EC-EZ-12)* GIVEN Boss 2 with `gate_params.requires_defeated = "no_such_boss"` (resolves to no entry in this zone's `boss_encounters`), `zone_win_count = 10`, THEN Boss 2 `LOCKED` and unofferable, content error logged naming the boss + the unresolved `requires_defeated` value. Discriminator: an impl that treats an unresolvable prerequisite as "no prerequisite" (fail-**open**) returns `UNLOCKED` at win_count ≥ 10 — assert `LOCKED`. This closes the dangling-foreign-key gap on the field introduced this cycle: the sequencing precondition (AC-EZ-56) must never be silently voided by a typo in `requires_defeated`.

### Coverage

Every Core Rule (1–11, plus 2a/8a) and every Edge Case (EC-EZ-01…12) has a verifying AC (see the *Verified by* citations in Edge Cases and the rule-mapping: R1→47/57, R2→48/30, R2a→54, R3→01–03/41, R4→04–09/15, R5→10–14, R6→49/51, R7→16–21/24/36–38, R8→16–21/34–35/56/58, R8a→20/55/56, R9→21–25/39/52/53, R10→27–31, R11→47–51). **59 ACs**: 39 BLOCKING (Unit/Integration), 11 ADVISORY (Content Validation), 9 DEFERRED (Integration, Not-Started systems). Unit-testable now with stub Enemy DB + injected seeded RNG: AC-EZ-01–09, 16–24, 26–39, 40a, 52, 56, 57, 58; offline content-validation linters (10–14, 25, 47–51, 54) also run now. DEFERRED (await Not-Started systems): 40b, 41–46, 53, 55.

> **Note on the cut WAVE gate:** the former WAVE integration ACs (win-all-waves, defeat-abort, flee-abort, lighter-wave-regate) are intentionally *not* present — WAVE is reserved (Rule 7). AC-EZ-24 verifies it is fail-safe (LOCKED) if authored; its full behavioral ACs are authored when WAVE is un-reserved (OQ-EZ-3). AC slots 19–21/24 were repurposed to Boss 2's WIN_COUNT + shared-counter coverage.

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-EZ-1 | **Terrain-type enum finalization.** The MVP terrain types (`MECHANICAL_GRASS`, `JUNKYARD`, `PYLON_FIELD`, `MACHINE_CAVERN`) are provisional placeholders. The final list depends on the Art Bible (visual distinctness per VA-1) and the ~8 WILD enemy roster's element/faction identities (which enemies group into which biome). | Art Bible + content authoring | Terrain readability (VA-1) and the targeting-lever design; not a schema change |
| OQ-EZ-2 | **Reserved-gate spatial contract (`REACH`/`DUNGEON_RUSH`).** The exact `gate_params` shape and the spatial fulfillment (where a hidden boss physically is, how a dungeon's mobs are laid out and "rushed") are owned by Zone & World Map (#12) and Overworld Navigation (#16) when authored. This GDD reserves the enum values only. | Zone & World Map + Overworld Navigation GDDs | Blocks nothing in MVP; the contract is defined when those systems are designed |
| OQ-EZ-3 | **WAVE gate un-reserval (deferred by design-review verdict).** WAVE is cut from MVP (Rule 7). If a future tier re-introduces it, this OQ owns the deferred design: the `wave_pools` schema (structure, per-wave selection, `wave_pools.size()` vs `wave_count`, re-gate wave pools), the arena scene/context, and reactivating EC-EZ-06 + its behavioral ACs. | Future tier + Combat UI | None for MVP — WAVE is reserved; no Boss 2 dependency (Boss 2 is now WIN_COUNT) |
| OQ-EZ-4 | **Encounter-rate modifiers (repel / anti-frustration).** MVP uses a fixed per-terrain `encounter_rate`. Should later tiers add player-state modifiers — a "repel" consumable, or a decaying rate after many consecutive encounters (anti-grind-fatigue)? Deferred; the fixed-rate EZ-1 is the MVP baseline. Also the natural home for **traversal relief** through DENSE terrain (a depleted player crossing a fast-farm biome to reach a boss). | Playtest / balance / Economy (if item-based) | None for MVP; a Vertical Slice+ enhancement |
| OQ-EZ-5 | **WIN_COUNT counter semantics — RESOLVED (2026-07-11).** Now normative in **Rule 8a**: cumulative, all-time, zone-wide, never resets, wins-only (fled/lost never count). Exploration Progress *implements* this contract; it no longer *ratifies* it. Verified by AC-EZ-20 (shared counter) + AC-EZ-55 (wins-only). | *(resolved — Rule 8a)* | Closed |
| OQ-EZ-6 | **Boss/terrain spatial contract (routed to Zone & World Map #12).** Three obligations this GDD imposes (see Interactions): (1) single-tagged tiles with one `terrain_type` or `PATH`, encounters resolve on the tile stepped onto, `PATH` never rolls EZ-1; (2) an `OVERWORLD` boss is a static non-encounter entity, never gated behind a forced-encounter gauntlet; (3) reserved WAVE needs a dedicated arena entry point. | Zone & World Map GDD | Blocks nothing in MVP; must be honored when #12 is authored (else Overworld Nav + Zone&Map invent conflicting tile semantics) |
| OQ-EZ-7 | **Enemy-to-terrain discovery surface (routed to World Map UI #20).** The "Crawlers past the scrap dunes" fantasy needs the player to *learn* which enemies live where — a first-encounter-reveals-it roster or static zone field guide. Encounter Zone owns the data (Rule 2a identity enemies); it does not own the surface. | World Map UI / UX | Not an Encounter Zone code blocker, but a Pillar-2 loop blocker if no downstream system provides it — flagged so it can't be lost |
| OQ-EZ-8 | **Inter-encounter Structure/HP recovery (routed to Turn-Based Combat).** Rule 5's "resource attrition between fights" in DENSE (and any future WAVE waves) presumes a recovery model — full heal, no heal, or partial — that TBC/combat-loop owns, not this system. This GDD does not author it; it only notes DENSE's throughput is only a *cost* trade-off if attrition is real. | Turn-Based Combat / balance | Encounter Zone stays correct under any choice; the choice affects DENSE's economic role and must be pinned before DENSE tuning is finalized |
