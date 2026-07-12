# Encounter Zone System

> **Status**: **Designed — pending fresh-session /design-review**
> **Author**: Luan + Claude Code Game Studios agents (systems-designer: Formulas; qa-lead: Acceptance Criteria)
> **Last Updated**: 2026-07-11
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 5 (The World Is a Workshop)
> **Review Notes**: Authored in lean mode — CD-GDD-ALIGN gate skipped (perform a manual pillar check before production). systems-designer consulted for Formulas (EZ-1/EZ-2, no floor/epsilon — no python3 scan required); qa-lead for the 52 ACs (full rule + EC coverage). Two schema amendments applied from qa-lead flags: `regate_params` added to the BossEncounter schema (WAVE re-gate data source); AC-EZ-52 added for `ALWAYS_OPEN`.

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

A `SpawnEntry` = `{ enemy_id: StringName, spawn_weight: int }`. `enemy_id` must reference an Enemy DB entry whose `enemy_class == WILD` and `spawn_enabled == true`.

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
| `gate_params` | Dictionary | First-access gate parameters (e.g. `{ required_wins: 6 }` or `{ wave_count: 3, wave_pools: [...] }`) |
| `regate_params` | Dictionary | Re-access (post-first-defeat) gate parameters, parallel to `gate_params` (e.g. `{ required_wins: 2 }` or `{ wave_count: 1 }`). Read only when `repeat_policy = LIGHTER_REGATE` and the boss is defeated-once. Values must be strictly lighter than `gate_params` (Rule 9 / Tuning Knobs). |
| `repeat_policy` | Enum | Re-access model after first defeat — see Rule 9 |

**Rule 7 — Gate-type taxonomy (extensible; MVP fills three).** `gate_type` is one enum; each value is a *reward vector*:

| `gate_type` | Reward vector | First-access condition | MVP |
|-------------|---------------|------------------------|-----|
| `OPEN` | (baseline) | Always accessible — no gate | Authorable |
| `WIN_COUNT` | Grinding | Win `gate_params.required_wins` WILD encounters in this zone | **Boss 1** |
| `WAVE` | Fighting | Enter the boss arena and defeat `gate_params.wave_count` consecutive enemy waves; the boss appears after the final wave | **Boss 2** |
| `REACH` | Exploration | Player reaches a specific (hard-to-reach / hidden) map location | **Reserved** |
| `DUNGEON_RUSH` | Luck / skill | Boss sits deep in a dungeon; the player clears its mobs *or* rushes past them to reach it | **Reserved** |

`REACH` and `DUNGEON_RUSH` require spatial systems that do not exist yet (Zone & World Map #12, Overworld Navigation #16). Their enum values and `gate_params` shape are reserved here so the schema never changes when those systems ship; **no MVP content authors them**, and their spatial fulfillment is a provisional contract (Dependencies).

**Rule 8 — Gate evaluation (first access).** A boss's gate is evaluated against persistent player state (owned by Exploration Progress #14). Until the gate condition is met, the boss encounter is not offerable. `WIN_COUNT` reads a per-zone win counter; `WAVE` is evaluated live when the player enters the arena; `OPEN` is always met. When the condition is met, the boss becomes accessible (its overworld presence / entry becomes active).

**Rule 9 — Repeat policy (re-access for grinding).** After a boss's *first* defeat, its `repeat_policy` governs re-access so farming its parts stays viable but never free:
- `LIGHTER_REGATE` (MVP default) — the boss becomes repeatable behind a **reduced** gate read from `regate_params` (Rule 6): `WIN_COUNT` re-access uses `regate_params.required_wins` (< first-access); `WAVE` re-access uses `regate_params.wave_count` (< first-access); a persistent map icon marks it. The specific reduction is a Tuning Knob. Re-access values MUST be strictly lighter than first-access (validated — AC-EZ-25).
- `ALWAYS_OPEN` — after first clear the boss is permanently accessible (no re-gate).
- `FULL_REGATE` — the original gate must be re-paid every time (reserved for special/limited bosses; no MVP content).

The "boss defeated at least once" flag is owned by Exploration Progress; this system reads it to select first-access vs. re-access behavior.

**Rule 10 — Enemy DB is the source of truth.** Encounter Zone stores no enemy stats, elements, regions, or loot — only `enemy_id` references. It reads `enemy_class` (to validate WILD-in-patches / BOSS-in-boss-slots), `spawn_enabled` (excluded when false), and respects `tier` (always 1 in MVP; no tier logic). An `enemy_id` in a spawn pool that is missing, `spawn_enabled == false`, or the wrong class is a content error (Edge Cases).

**Rule 11 — MVP content scope.** One zone; 3–4 terrain patch types drawn from ~8 WILD enemy types; 2 bosses (Boss 1 = `OVERWORLD`/`WIN_COUNT`, Boss 2 = `OVERWORLD`/`WAVE`), both `repeat_policy = LIGHTER_REGATE`. `REACH`, `DUNGEON_RUSH`, `DUNGEON`, and `HIDDEN` are reserved and unauthored.

### States and Transitions

WILD encounters are stateless — each is an independent per-step roll with no memory. The stateful element is the **boss gate lifecycle**, tracked per boss (persistent state owned by Exploration Progress, read by this system):

| State | Entered when | Exits to |
|-------|-------------|----------|
| `LOCKED` | Zone loaded, gate condition not yet met, boss never defeated | `UNLOCKED` when the gate condition is met (Rule 8) |
| `UNLOCKED` | First-access gate condition met, boss not yet defeated | `DEFEATED` on first victory; back to `LOCKED` only if the gate is progress-based and progress is externally reset (not in MVP) |
| `DEFEATED` | Boss defeated at least once | `RE_ACCESSIBLE` per `repeat_policy` (Rule 9) |
| `RE_ACCESSIBLE` | Post-defeat, re-access gate (lighter) available | Re-entered on each subsequent clear; stays available for grinding |

`OPEN` gates begin already `UNLOCKED`. For `WAVE` bosses, entering the arena runs a transient sub-sequence — `WAVE_IN_PROGRESS(n)` cycling through `wave_count` battles; a defeat or flee during the waves aborts the attempt (arena resets, no boss), and completing the final wave transitions the boss to an immediately-offered encounter. This wave sub-sequence is transient runtime state, not persisted.

The per-encounter transient flow (WILD): `EXPLORING` (player moving in a patch) → `ENCOUNTER_TRIGGERED` (EZ-1 roll succeeds) → enemy resolved (EZ-2) and handed to TBC → on `battle_ended`, return to `EXPLORING`. Encounter Zone holds none of this between steps — the movement/step state is Overworld Navigation's.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Enemy Database** | ← reads | `enemy_id` references resolve to entries; reads `enemy_class` (WILD/BOSS validation), `spawn_enabled` (exclude if false), `tier` (respected, always 1 in MVP). Stores no enemy data itself. |
| **Turn-Based Combat** | → hands off | On a resolved encounter, passes the selected `enemy_id` (and boss/wild context so TBC applies the correct flee rule — WILD fleeable, BOSS not, TBC Rule 7). TBC instantiates the enemy and owns the battle. |
| **Overworld Navigation** *(Not Started)* | ← triggered by | Calls into Encounter Zone with the player's current `terrain_type` on each step; Encounter Zone runs EZ-1 and, on success, EZ-2. Movement detection and step counting belong to Overworld Navigation. |
| **Zone & World Map** *(Not Started)* | ↔ provisional | Owns the spatial realization of terrain patches, boss placement, and — for reserved `REACH`/`DUNGEON_RUSH` gates + `DUNGEON`/`HIDDEN` placement — the actual map geometry. This GDD defines *what a gate requires*; Zone & World Map defines *where it physically is*. |
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

**Expected steps to encounter:** `E[steps] = 1 / encounter_rate`.

**Worked example:** `encounter_rate = 0.15`; draw `0.09` → `0.09 < 0.15` → **true** (encounter). Draw `0.22` → **false** (no encounter). Expected gap = 1/0.15 ≈ **6.7 steps**.

### EZ-2 — Weighted Enemy Selection

Cumulative-weight walk against a single integer draw:

```
total_weight = sum(e.spawn_weight for e in subpool)
roll = rng.randi_range(1, total_weight)          # inclusive both ends
cumulative = 0
for e in subpool:
    cumulative += e.spawn_weight
    if roll <= cumulative:
        return e.enemy_id
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

DENSE/STANDARD = 2.3× more encounters per step justifies the fast-farm role; below ~1.3× players wouldn't bother, above 0.45 it becomes mobile combat-spam.

## Edge Cases

**EC-EZ-01 — Empty enemy sub-pool.** A terrain patch whose `enemy_subpool` is empty (or has zero total weight): EZ-2 cannot select. Log a content error naming the `terrain_type` and `zone_id`; return sentinel `StringName("")`; the caller (Overworld Navigation) treats a sentinel result as "no encounter this step" and does not start a battle. Never crash. *Verified by AC-EZ-26.*

**EC-EZ-02 — Spawn entry references a missing or disabled enemy.** A `SpawnEntry.enemy_id` that (a) has no Enemy DB entry, or (b) has `spawn_enabled == false`: the entry is skipped at selection time — excluded from `total_weight` and never returned. If skipping empties the pool, EC-EZ-01 applies. A missing ID additionally logs a content error. *Verified by AC-EZ-27 / AC-EZ-28.*

**EC-EZ-03 — Wrong enemy class for the slot.** A `BOSS`-class `enemy_id` placed in a terrain `enemy_subpool`, or a `WILD`-class `enemy_id` placed in a `boss_encounters` slot: content error, the misplaced entry is excluded (a WILD in a boss slot makes that boss unofferable; validation flags it). Class integrity is a content-authoring invariant. *Verified by AC-EZ-30 / AC-EZ-31.*

**EC-EZ-04 — `spawn_weight` of 0 or negative.** A weight ≤ 0 is invalid (weights must be ≥ 1). A 0-weight entry can never be selected (contributes nothing to `total_weight`) — treated as absent with a content warning; a negative weight is a content error (clamped to exclusion). The formula assumes positive integers. *Verified by AC-EZ-32 (zero) / AC-EZ-33 (negative).*

**EC-EZ-05 — `encounter_rate` at 0.0 or 1.0.** Both are legal, not errors: 0.0 = a terrain patch that never triggers (a safe "walk-through" band); 1.0 = triggers every step (extreme DENSE). These are the documented EZ-1 boundary behaviors, exposed as tuning extremes. Values outside [0.0, 1.0] are a content error (clamped to range). *Verified by AC-EZ-02.*

**EC-EZ-06 — WAVE gate aborted mid-sequence.** During a `WAVE` boss gate, if the player is defeated or flees before the final wave, the wave attempt aborts: the arena resets, no boss appears, and no gate progress is banked (the wave sequence is transient, all-or-nothing). Re-entering the arena restarts from wave 1. A won wave sequence immediately offers the boss. *Verified by AC-EZ-20 (defeat) / AC-EZ-21 (flee); the won-sequence path by AC-EZ-19.*

**EC-EZ-07 — Missing or malformed `gate_params`.** A `gate_type` whose required `gate_params` key is absent (e.g. `WIN_COUNT` with no `required_wins`, or `WAVE` with no `wave_count`): content error at load; the boss defaults to `LOCKED` and unofferable (fail-safe — never accidentally `OPEN`). Validation names the boss and the missing key. *Verified by AC-EZ-34 (WIN_COUNT) / AC-EZ-35 (WAVE); AC-EZ-36 confirms OPEN legitimately needs no params.*

**EC-EZ-08 — Reserved `gate_type` authored in MVP content.** A boss authored with `REACH` or `DUNGEON_RUSH` while their spatial systems (Zone & World Map, Overworld Navigation) do not exist: content error — the reserved values are not yet fulfillable. The boss is `LOCKED` and unofferable. This guards against content outrunning the systems that realize it. *Verified by AC-EZ-37 (REACH) / AC-EZ-38 (DUNGEON_RUSH).*

**EC-EZ-09 — Re-access before first defeat.** `repeat_policy` only takes effect after the "defeated once" flag is set. Querying re-access on a never-defeated boss returns the *first-access* gate (Rule 8), never the lighter re-gate. A boss cannot skip its first-access gate via the re-access path. *Verified by AC-EZ-39.*

**EC-EZ-10 — Zone or enemy retired mid-progression.** A zone with `spawn_enabled == false` offers no encounters (its patches are inert). An enemy set `spawn_enabled == false` after the player has already been farming it: it simply stops appearing (EC-EZ-02 exclusion) — no error, no retroactive effect on already-owned parts. Retirement is graceful. *Verified by AC-EZ-27 (shared enemy-exclusion fixture).*

**EC-EZ-11 — Exploration Progress unavailable (provisional dependency).** Exploration Progress (#14) does not exist yet. Until it does, gate state is read through a provisional interface; if the progress store is absent at runtime, gates default to their first-access `LOCKED`/`OPEN` authored state and win counters read 0 (no crash). This is a provisional-dependency safeguard, not a shipping behavior. *Verified by AC-EZ-40 (provisional, deferred).*

## Dependencies

### Upstream (Encounter Zone reads from these)

| System | What Encounter Zone reads | Status | Hard/Soft |
|--------|---------------------------|--------|-----------|
| **Enemy Database** | `enemy_id` → entry resolution; `enemy_class` (WILD/BOSS slot validation), `spawn_enabled` (exclude if false), `tier` (respected, always 1 in MVP) | Approved | Hard |
| **Exploration Progress** *(Not Started)* | Persistent per-boss gate state: per-zone win counters, "defeated once" flag — read to evaluate first-access gates (Rule 8) and select re-access (Rule 9) | Not Started | Soft (provisional interface; EC-EZ-11 fallback until it exists) |

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
| `encounter_rate[DENSE]` | 0.35 | 0.25–0.45 | Fast-farm biome rate (~2.9 steps/encounter). Must stay meaningfully above STANDARD (≥ ~1.6×) to justify the biome; above 0.45 (~2.2 steps) it becomes mobile combat-spam. First fatigue adjustment: pull toward 0.28–0.30, not a redesign. |
| `WIN_COUNT.required_wins` (first access) | 6 | 4–12 | WILD wins to open a `WIN_COUNT` boss (Boss 1). At 4, the boss opens before zone familiarity builds; above 12, first access feels like a grind wall. |
| `regate_params.required_wins` (re-access) | 2 | 1–4 | Lighter re-gate after first defeat (`LIGHTER_REGATE`), read from `regate_params`. Keeps boss-part farming viable without being free. Must stay < the first-access value or the "lighter" promise breaks (AC-EZ-25). |
| `WAVE.wave_count` (first access) | 3 | 2–5 | Consecutive waves before a `WAVE` boss appears (Boss 2). At 2 the gate is trivial; above 5, mobile session length and attrition (no between-wave recovery guarantee) make it punishing. |
| `regate_params.wave_count` (re-access) | 1 | 1–3 | Lighter re-gate wave count, read from `regate_params`. Must stay < first-access count (AC-EZ-25). |
| `spawn_weight` (authoring guidance) | — | 1–100 typical | Relative enemy frequency within a patch. Only ratios matter (weight 10 vs 5 = 2:1). Guidance: keep the spread readable (a "rare" target at ~1/5 of a "common" filler's weight reads as noticeably rarer without being unfarmable). |

**Knob interaction warnings:**
1. **Re-access knobs must stay strictly below their first-access counterparts** (`WIN_COUNT` 2 < 6; `WAVE` 1 < 3) or `LIGHTER_REGATE` provides no actual relief — the "grinding stays viable" design intent (Rule 9) fails silently.
2. **`DENSE`/`STANDARD` ratio is the load-bearing pacing lever**, not the absolute DENSE value. Tuning both up together preserves the ratio but raises baseline combat frequency across the whole zone — check the ratio (target ≥ 1.6×, default 2.3×) before shipping a rate change.
3. **`required_wins` (first access) is coupled to the zone's WILD variety** — a high win count in a zone with few enemy types means repetitive farming to open the boss; raise variety or lower the count together.

**Owned elsewhere — referenced, not duplicated:** enemy stats/regions/loot (Enemy DB); the drop RNG and pity (Drop System); persistent win-counter and defeated-flag storage (Exploration Progress); step detection and movement (Overworld Navigation).

## Visual/Audio Requirements

> **Ownership note**: Encounter Zone is a spawn-table/logic layer — it owns no assets. The requirements below are obligations it places on the presentation systems (Zone & World Map, World Map UI, Combat UI, Audio System) and the Art Bible. Per-asset specs await the Art Bible.

**VA-1 — Terrain-type readability (binding, load-bearing for the core loop).** Each `terrain_type` must be **visually distinct at a glance** — mechanical grass, junkyard, and pylon field must be instantly tellable apart. The entire "terrain = targeting lever" design (Rule 2, Player Fantasy) collapses if the player can't read which terrain they're standing in. This is the single most important presentation requirement of this system. *(Owned by Art Bible + Zone & World Map tilemap art.)*

**VA-2 — Encounter-trigger beat.** When EZ-1 fires, the transition into battle needs a clear, fast feedback moment (screen effect + audio sting) so the encounter never feels like it "just happened." Classic-RPG encounter-transition register. *(Owned by Overworld Navigation / Combat UI transition; Audio System sting.)*

**VA-3 — Density telegraphing.** `DENSE` biomes should *look* more active/hazardous than `STANDARD` terrain — the player choosing a fast-farm cavern should know they're entering higher encounter frequency. Density is a deliberate player choice, so it must be visible before entry. *(Owned by Art Bible + Zone & World Map.)*

**VA-4 — Boss map presence and gate state.** An accessible boss needs unambiguous map presence (icon/landmark). Gate state must read: locked (gate visible or boss hidden per placement), unlocked/available, and defeated→re-accessible. *(Owned by World Map UI.)*

**VA-5 — WAVE arena framing.** A `WAVE` gate needs an "arena" framing on entry and a wave-progress readout (wave *n* of *N*) between fights. *(Owned by Combat UI + World Map UI.)*

**Audio intent:** distinct per-terrain ambience reinforces VA-1 (a second, non-visual readability channel — you can *hear* which biome you're in); encounter-trigger sting for VA-2; boss-available cue when a gate opens. *(Owned by Audio System.)*

## UI Requirements

Obligations on World Map UI, Overworld Navigation, and Combat UI (Not Started) — layout and interaction belong to those GDDs.

1. **Terrain legibility** (World Map UI / Art Bible): terrain types must be distinguishable on the map — the UI side of VA-1.
2. **Encounter transition** (Overworld Navigation / Combat UI): the trigger→battle handoff must be visually clear; a sentinel `enemy_id` (EC-EZ-01) must *not* start a transition.
3. **Boss gate status readout** (World Map UI): show a boss's gate state and — for `WIN_COUNT` — **the progress toward it (e.g. "3 / 6 wins")**. *Design decision: `WIN_COUNT` progress is **shown**, not hidden.* Rationale: unlike the Drop System's hidden surprise-rescue pity, a boss gate is a **goal** — the player should see a clear objective and its progress. Hiding it would make the boss's appearance feel arbitrary.
4. **WAVE progress** (Combat UI): during a `WAVE` gate, show the current wave and total (e.g. "Wave 2 / 3").
5. **Re-access indication** (World Map UI): a defeated, re-accessible boss should read as "cleared, repeatable" — distinct from a never-defeated locked boss.

> **📌 UX Flag — Encounter Zone**: this system places map/overworld UI requirements (terrain legibility, boss-gate readouts, wave progress). In Pre-Production, run `/ux-design` for the World Map / overworld screens before writing epics; stories should cite the resulting `design/ux/` spec, not this GDD directly.

## Acceptance Criteria

**Tags:** **BLOCKING** (automated unit/integration test — gates story completion) · **ADVISORY** (content-validation linter — gates content shipping, not code merge) · **DEFERRED** (needs a Not-Started system; write the stub now, activate when it ships). **Test type:** Unit (GUT, injected seeded RNG + stub Enemy DB, no live scene) · Content Validation (offline data linter) · Integration (≥2 systems wired, stubs allowed).

**Seeded-RNG mandate (implementation constraint):** the Encounter Zone system MUST accept an **injected** `RandomNumberGenerator` (or Callable RNG wrapper), never the global `randf()`/`randi()`. Without dependency-injected RNG, the `<` vs `<=` boundary discriminators (AC-EZ-03, AC-EZ-05..07) are unreachable.

### EZ-1 — Encounter Trigger

**AC-EZ-01** (BLOCKING, Unit): `encounter_rate = 0.0` never triggers. GIVEN rate 0.0 and any seed, WHEN EZ-1 runs 10,000 steps, THEN `triggered == false` every step.

**AC-EZ-02** (BLOCKING, Unit): legal rate boundaries + out-of-range clamping. *(Verifies EC-EZ-05)* **A:** rate 1.0, 10,000 steps → triggers every step (`randf()` is `[0,1)`, so `< 1.0` always true). **B:** rate 1.5 (content error) → error logged, effective rate clamped to 1.0. **C:** rate −0.3 → error logged, clamped to 0.0, never triggers. The content-error log is the observable proving clamping.

**AC-EZ-03** (BLOCKING, Unit): mid-rate seeded determinism + `<` operator. GIVEN rate 0.15, seed 1234, 20 steps, THEN the `triggered` sequence matches a hard-coded reference sequence (embedded constant, NOT recomputed from `randf()` at test time). Discriminator: inject a draw equal to exactly `0.15` → with `< 0.15` it is `false` (with `<=` it would be `true`); assert `false`.

### EZ-2 — Weighted Enemy Selection

Canonical fixture (all EZ-2 ACs): `iron_crawler`(w10, cum 10), `volt_drone`(w6, cum 16), `rust_hulk`(w4, cum 20); `total_weight = 20`; all WILD + `spawn_enabled` in stub Enemy DB.

**AC-EZ-04** (BLOCKING, Unit): distribution. GIVEN the fixture, seed 99, 10,000 draws, THEN counts fall in iron_crawler 4750–5250 (50%), volt_drone 2750–3250 (30%), rust_hulk 1750–2250 (20%). Discriminator: a uniform (weight-ignoring) impl gives ~3333 each → fails all bands.

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

**AC-EZ-15** (BLOCKING, Integration): correct handoff. GIVEN pool `{bolt_skitter w8, iron_crawler w2}`, a stub TBC recording `(enemy_id, is_boss, fleeable)`, seed where EZ-1 fires and EZ-2 picks `bolt_skitter`, THEN TBC receives `("bolt_skitter", false, true)` (WILD is fleeable, TBC Rule 7). Stub caller invokes resolution directly with a `terrain_type` — upgrade to full integration when Overworld Navigation ships.

### Boss Gate — WIN_COUNT (Boss 1, `required_wins = 6`)

**AC-EZ-16** (BLOCKING, Unit): 5 wins = `LOCKED`. GIVEN `zone_win_count = 5`, `defeated_once = false`, THEN `LOCKED`.
**AC-EZ-17** (BLOCKING, Unit): exactly 6 wins = `UNLOCKED` (threshold `>=` discriminator). GIVEN win_count 6, THEN `UNLOCKED` — a `> 6` impl stays LOCKED; assert `UNLOCKED`.
**AC-EZ-18** (BLOCKING, Unit): 7 wins = `UNLOCKED` (no upper-bound "window" regression).

### Boss Gate — WAVE (Boss 2, `wave_count = 3`)

**AC-EZ-19** (BLOCKING, Integration): win all 3 waves → boss offered. GIVEN a stub arena resolving each wave as WIN, WHEN waves 1–3 won in sequence, THEN boss offered (state → `UNLOCKED`). Stub arena emits `wave_won`; upgrade when Arena/Combat UI ships.
**AC-EZ-20** (BLOCKING, Integration): abort on defeat. *(Verifies EC-EZ-06)* wave 1 won, wave 2 lost → sequence resets to 0, boss not offered, re-entry restarts at wave 1.
**AC-EZ-21** (BLOCKING, Integration): abort on flee. *(Verifies EC-EZ-06 — flee variant)* wave 1 won, wave 2 fled → same reset. Both modalities tested because TBC emits distinct `battle_lost` vs `battle_fled` signals.

### Repeat Policy (LIGHTER_REGATE)

**AC-EZ-22** (BLOCKING, Unit): re-gate applies after defeat. GIVEN Boss 1, `defeated_once = true`, `zone_win_count = 2`, `regate_params.required_wins = 2`, THEN `UNLOCKED` (`2 >= 2`). Discriminator: an impl ignoring `defeated_once` applies first-access (`2 < 6`) → LOCKED; assert `UNLOCKED`.
**AC-EZ-23** (BLOCKING, Unit): re-gate not met = `LOCKED`. GIVEN `defeated_once = true`, win_count 1, re-gate 2, THEN `LOCKED`. Discriminator: an `ALWAYS_OPEN`-after-defeat impl returns UNLOCKED; assert `LOCKED`.
**AC-EZ-24** (BLOCKING, Integration): WAVE lighter re-gate. GIVEN Boss 2, `defeated_once = true`, first-access `wave_count = 3`, `regate_params.wave_count = 1`, WHEN 1 wave won, THEN boss offered after wave 1.
**AC-EZ-25** (ADVISORY, Content Val): re-access strictly < first-access. For Boss 1 `regate_params.required_wins < gate_params.required_wins`; for Boss 2 `regate_params.wave_count < gate_params.wave_count`. Defaults (2<6, 1<3) pass. Enforces Tuning Knob warning 1.

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
**AC-EZ-35** (BLOCKING, Unit): WAVE missing `wave_count` → error, `LOCKED`.
**AC-EZ-36** (BLOCKING, Unit): OPEN with empty `gate_params` is valid — no error, evaluates `UNLOCKED` immediately. Confirms OPEN is the one type needing no params.
**AC-EZ-37** (BLOCKING, Unit): `REACH` in MVP → content error naming boss + gate_type, `LOCKED`. *(Verifies EC-EZ-08)*
**AC-EZ-38** (BLOCKING, Unit): `DUNGEON_RUSH` in MVP → content error, `LOCKED`. (37/38 confirm reserved enum values are defined but fail-safe — no crash, no fall-through to OPEN.)

### Re-access Before Defeat (EC-EZ-09)

**AC-EZ-39** (BLOCKING, Unit): re-access path gated on `defeated_once`. *(Verifies EC-EZ-09)* GIVEN Boss 1, `defeated_once = false`, win_count 3, first-access 6, re-gate 2, THEN `LOCKED` (first-access applies; 3 < 6). Minimum fixture discriminating the flag: win_count 3 PASSES the re-gate (≥2) but FAILS first-access (<6) — an impl ignoring `defeated_once` returns UNLOCKED.

### Provisional / Deferred Integration

**AC-EZ-40** (DEFERRED, Integration): Exploration Progress unavailable. *(Verifies EC-EZ-11)* GIVEN a not-connected progress stub, WIN_COUNT gate → win counter reads 0, `LOCKED`, provisional **warning** (not error) logged, no crash; OPEN gate → `UNLOCKED`. Activate when Exploration Progress ships.
**AC-EZ-41** (DEFERRED, Integration): Overworld Navigation runs EZ-1 only on terrain tiles, never path tiles (100 terrain + 50 path steps → 100 evaluations).
**AC-EZ-42** (DEFERRED, Integration): sentinel `enemy_id` → no battle transition, no TBC call.
**AC-EZ-43** (DEFERRED, Integration): WIN_COUNT counter persists across save/reload (4 wins → reload → reads 4, LOCKED).
**AC-EZ-44** (DEFERRED, Integration): `defeated_once` persists across save/reload (first kill → reload → lighter re-gate applies).
**AC-EZ-45** (DEFERRED, Integration): standing on a `MECHANICAL_GRASS` tile → Overworld Navigation calls EZ with `terrain_type = MECHANICAL_GRASS` (Zone & World Map spatial realization).
**AC-EZ-46** (DEFERRED, Integration): both OVERWORLD bosses have reachable map presence.

### MVP Content Scope (Content Validation)

**AC-EZ-47** (ADVISORY, Content Val): exactly 1 zone entry, `spawn_enabled = true`, valid `zone_id`.
**AC-EZ-48** (ADVISORY, Content Val): zone has 3–4 terrain patches; every patch `enemy_subpool.size() >= 1`; every entry `spawn_weight >= 1`.
**AC-EZ-49** (ADVISORY, Content Val): exactly 2 boss entries — Boss1 `WIN_COUNT`/`required_wins=6`/`LIGHTER_REGATE`, Boss2 `WAVE`/`wave_count=3`/`LIGHTER_REGATE`, both `OVERWORLD`.
**AC-EZ-50** (ADVISORY, Content Val): de-duplicated WILD enemy count across all patches ∈ [6, 10] (target ~8).
**AC-EZ-51** (ADVISORY, Content Val): every `boss_id` resolves to a `BOSS`-class, `spawn_enabled` Enemy DB entry.

### ALWAYS_OPEN Policy

**AC-EZ-52** (BLOCKING, Unit): `repeat_policy = ALWAYS_OPEN`. GIVEN a boss with `ALWAYS_OPEN`, `defeated_once = true`, and its first-access gate unmet (e.g. win_count 0 vs required 6), THEN `UNLOCKED` (permanently accessible after first clear, no re-gate). GIVEN the same boss `defeated_once = false`, THEN the first-access gate still applies (`LOCKED`) — ALWAYS_OPEN only takes effect post-first-defeat.

### Coverage

Every Core Rule (1–11) and every Edge Case (EC-EZ-01…11) has a verifying AC (see the *Verified by* citations in Edge Cases and the rule-mapping: R1→47, R2→48/30, R3→01–03/41, R4→04–09/15, R5→10–14, R6→49/51, R7→16–21/36–38, R8→16–19/34–35, R9→22–25/39/52, R10→27–31, R11→47–51). **52 ACs**: 30 BLOCKING (Unit/Integration), 15 ADVISORY (Content Validation), 7 DEFERRED (Integration, Not-Started systems). Unit-testable now with stub Enemy DB + injected seeded RNG: AC-EZ-01–09, 16–18, 22–23, 26–39, 52.

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-EZ-1 | **Terrain-type enum finalization.** The MVP terrain types (`MECHANICAL_GRASS`, `JUNKYARD`, `PYLON_FIELD`, `MACHINE_CAVERN`) are provisional placeholders. The final list depends on the Art Bible (visual distinctness per VA-1) and the ~8 WILD enemy roster's element/faction identities (which enemies group into which biome). | Art Bible + content authoring | Terrain readability (VA-1) and the targeting-lever design; not a schema change |
| OQ-EZ-2 | **Reserved-gate spatial contract (`REACH`/`DUNGEON_RUSH`).** The exact `gate_params` shape and the spatial fulfillment (where a hidden boss physically is, how a dungeon's mobs are laid out and "rushed") are owned by Zone & World Map (#12) and Overworld Navigation (#16) when authored. This GDD reserves the enum values only. | Zone & World Map + Overworld Navigation GDDs | Blocks nothing in MVP; the contract is defined when those systems are designed |
| OQ-EZ-3 | **WAVE arena context.** Is the wave arena a distinct scene/encounter context, and does it reuse the combat screen with a wave-progress overlay, or its own framing? The `wave_pools` structure (how each wave's enemies are authored) needs definition jointly with Combat UI. | Combat UI + this system (content) | WAVE gate (Boss 2) polish; the runtime abort/reset logic (Rule 9, AC-EZ-20/21) is already specified |
| OQ-EZ-4 | **Encounter-rate modifiers (repel / anti-frustration).** MVP uses a fixed per-terrain `encounter_rate`. Should later tiers add player-state modifiers — a "repel" consumable, or a decaying rate after many consecutive encounters (anti-grind-fatigue)? Deferred; the fixed-rate EZ-1 is the MVP baseline. | Playtest / balance / Economy (if item-based) | None for MVP; a Vertical Slice+ enhancement |
| OQ-EZ-5 | **WIN_COUNT counter semantics.** Confirm the counter is *cumulative WILD victories in the zone* (not distinct enemy types, not since-last-visit). Fled and lost encounters do not count (it is a *win* count). This is Exploration Progress's storage contract — ratify when that GDD is authored. | Exploration Progress GDD | WIN_COUNT gate behavior (Boss 1); provisional until Exploration Progress ratifies |
