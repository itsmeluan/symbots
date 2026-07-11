# Part-Break System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-11
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 1 (Engineer, Don't Collect)

## Overview

The Part-Break System is the runtime break state tracker for Symbots — the layer that gives enemy regions a separate, damageable health pool distinct from their total Structure, watches for region damage events during combat, and emits a break event to the victory payload when a pool is depleted. It has no logic of its own about *what* an enemy is or *what* drops when it breaks; it only answers "how much cumulative targeted damage has this region taken, and has it crossed its threshold?" Everything else belongs elsewhere: the Enemy Database authors the regions and their break HP fractions, TBC routes per-hit damage to the appropriate region pool via its `hit_resolved` hook, and the Drop System converts the emitted break events into loot multipliers.

For the player, this system is invisible machinery behind the most important per-turn question in Symbots: *"Do I route this hit into the arm or just finish it?"* That question — the harvest dilemma — only exists because break regions have real HP pools with real thresholds. A player who breaks a WILD enemy's torso before the kill sees a different loot screen than one who didn't. A player who shatters a Boss's leg before the kill may see the Boss-grade Core they came for. Part-Break makes "break the right part" a legible, achievable plan with a satisfying visual and audio payoff at the moment of break — not a vague suggestion.

## Player Fantasy

The player never thinks "the Part-Break system tracked region damage." They think: *"Three more Kinetic hits and that arm is gone. Can I survive three more turns at this Heat?"*

Part-Break's emotional signature is the **shopping list made concrete**. In the game concept's words, every battle is a harvest decision — but that decision only has teeth when breaking a region costs something. The player who routes three turns of sub-optimal damage into an arm instead of finishing fast is making a bet: the Servo Arm is worth those turns, and they can survive them. When the arm shatters, the bet pays. When it doesn't — when they misjudged the enemy's counter-damage and got DOWNED a turn before the break — the lesson lands clearly: *I aimed for the arm too late.* That's the Monster Hunter DNA translated to turn tempo. The enemy is a walking shopping list; Part-Break is the mechanism that charges you for reading from it.

The peak beat is the **break pop**: the moment a region threshold is crossed, the enemy's part explodes visually, an audio cue lands, and the break event fires into the victory payload. At that moment the player knows — before the loot screen even appears — that their targeting investment paid off. The harvesting fantasy is causal: *I broke it, so I get a shot at it.*

Beneath the pop, two quieter experiences sustain the system. First, **progress visibility**: break pips on the Combat UI show accumulated region damage as a partial fill (authored for Combat UI — not owned here), so the player always knows whether they're two hits or eight hits from the threshold. Without that feedback the break goal feels like gambling, not execution. Second, **persistence convergence**: the break-failure pity mechanic (Part-Break's DB3 obligation) means that even a player who consistently targets correctly but gets unlucky with break *firing* is guaranteed to eventually get the event. Bad luck can add turns, never wall the goal.

*Joint delivery note: the peak beat requires Combat UI (break pips) and Audio System (break SFX) to be realized. This GDD builds the break event emission; Combat UI owns the visual progress; Audio owns the sound. Neither this system nor TBC alone delivers the full fantasy.*

## Detailed Design

### Core Rules

**Rule 1 — Two damage pools.** Every enemy has a **Structure** pool (the kill pool — TBC-owned runtime state) and one independent **break pool** per breakable region (Part-Break-owned runtime state, initialized at battle start from the Enemy DB's `EDB-1`-derived `break_hp`). The pools are fully independent: depleting a region never reduces Structure *except* via spillover (Rule 4b); depleting Structure ends the fight regardless of any region's state (an un-broken region is simply lost — TBC Rule 12).

**Rule 2 — Target selection is free (no turn cost), and the target set is closed.** A DAMAGE-behavior move aimed at the ENEMY carries a **sub-target**: `STRUCTURE` or a specific un-broken `region_id`. Choosing the sub-target is part of choosing the move — it consumes no extra action, no extra Energy, no extra Heat. This resolves the region sub-targeting layer TBC deferred (Move Contract `targeting` = `ENEMY`; region sub-targeting is Part-Break's). **Target-set invariant:** the legal sub-targets are exactly `{STRUCTURE} ∪ {r ∈ enemy.break_regions : not r.is_broken}` — the action/UI layer builds the selectable set *from the enemy's own regions*, so a sub-target outside this set can never be generated or received. There is no "invalid target" runtime path because an invalid target is structurally impossible: every target is either `STRUCTURE` or a region that exists on *this* enemy and is not yet broken. Non-DAMAGE moves (STATUS / REPAIR / SCAN / UTILITY) and SELF moves have no sub-target. The Basic Attack (TBC built-in) may sub-target like any DAMAGE move; its `break_bias` is `BALANCED`.

**Rule 3 — Break bias (per-move kill-vs-harvest trade).** Each move carries a `break_bias ∈ {STRUCTURE_HEAVY, BALANCED, BREAK_HEAVY}`, mapping to a `(structure_mult, break_mult)` pair via the `BREAK_BIAS_MULTIPLIERS` table (values in Formulas). The enum enforces the trade — no move is strong against both pools. `break_bias` is authored on the move (Move Database field; a Move DB erratum this GDD creates).

**Rule 4 — Damage routing.** Let `move_damage` be the post-pipeline integer TBC produces for the hit (DF-1 → MOVE-F1 → Stagger, TBC Rule 10). Routing depends on the sub-target:
- **(a) Target = STRUCTURE**: `current_structure -= floor(move_damage × structure_mult + ε)`. No region effect.
- **(b) Target = region R**: `R.current_break_hp -= floor(move_damage × break_mult + ε)` **and** spillover `current_structure -= floor(move_damage × break_mult × BREAK_SPILLOVER + ε)`, `BREAK_SPILLOVER = 0.20`.

TBC owns Structure and applies both Structure reductions; Part-Break owns and applies the region-pool reduction. Floors are epsilon-guarded (Formulas). Spillover means breaking is never fully off the kill clock — a broken region that fails its drop roll still advanced the fight by ~20% of the break damage.

**Rule 5 — Break trigger is deterministic.** When a region's `current_break_hp` reaches ≤ 0 it transitions to **BROKEN**, and Part-Break, in order: (a) emits the region's `<region>_broken` key into TBC's battle-scoped `fired_break_events` set (TBC Rule 12); (b) increments the enemy's enrage stack (Rule 7); (c) marks the region an invalid future target; (d) **if every breakable region on the enemy is now broken**, additionally emits `all_boss_parts_broken`. Breaking is **guaranteed on depletion — never an RNG roll** (this is the whole of DB3(a): the break "success condition" is pool depletion). A region breaks at most once per battle.

**Rule 6 — Over-break and already-broken hits.** Damage beyond what a region needs is discarded (regions do not "over-break" or bank excess). A DAMAGE hit directed at an already-BROKEN region is **redirected entirely to Structure** at the move's `structure_mult` (treated as a Structure hit) — no re-break, no wasted damage. The Combat UI normally prevents targeting a broken region; this rule covers the API/edge path so no hit is ever lost.

**Rule 7 — Enrage escalator (designed-in; content-gated).** Each broken region raises the enemy's **outgoing-damage multiplier** by `ENRAGE_PER_BREAK` (additive per broken region, applied by TBC to the enemy's final damage output, persists for the battle, resets at battle end). Greedy multi-break therefore grows progressively more dangerous — the `all_boss_parts_broken` capstone is fought against a maximally enraged enemy. Setting `ENRAGE_PER_BREAK = 0` disables it globally; the always-on lever is region-fraction cost (Rule 1 / `EDB-1`). MVP default value set in Formulas / Tuning Knobs.

**Rule 8 — Break state is battle-local (no persistence).** Region pools, BROKEN flags, and enrage stacks initialize fresh every battle and are discarded at battle end — nothing persists across battles (unlike the Drop System's pity counters). Fled or lost battles evaporate all break progress (consistent with TBC discarding `fired_break_events` on non-victory).

**Rule 9 — Output contract: Part-Break never rolls drops.** Part-Break's entire output is the set of break keys written into TBC's `fired_break_events`. On VICTORY, TBC hands that set to the Drop System, which uses the keys as Formula 3 condition multipliers. Break keys **must exactly match** the Drop System Rule 5 vocabulary. Part-Break does not read loot pools, compute drop rates, or emit instances — the "break ≠ guaranteed drop" property lives entirely in the Drop System.

**Rule 10 — Break damage uses the full combat pipeline.** Region damage is the *same* `move_damage` Structure would receive — it passes through DF-1 (type effectiveness, the enemy's Armor/Resistance), MOVE-F1 (power tier), and Stagger (TBC-F5) before the `break_mult` split. So build power and element matchup matter for breaking exactly as for killing: the right element breaks faster, off-element pays more, and a heavily-armored enemy's regions are slow to break (intended build friction). MVP regions inherit the enemy's single defense stat — no per-region hitzone values (a possible post-MVP enrichment; see Open Questions).

**Rule 11 — Multi-target moves (reserved extension; no MVP content).** MVP DAMAGE moves are strictly **single-sub-target** (Rule 2 — one Structure hit or one region hit). The architecture, however, supports multi-hit moves natively: because Part-Break is a per-hit accumulator on `hit_resolved`, a move that produces several hits is simply routed several times through Rule 4, each sub-hit independently able to trigger a break (PB-F4) and an enrage stack (Rule 7). A future move may therefore declare a **`target_profile`** — an ordered list of `(target, damage_mult)` sub-hits (e.g. a `SHATTER` sweep = `[(all_regions, 0.5)]`, a `CLEAVE` = `[(structure, 0.7),(arm, 0.7)]`). Reserved constraints for whoever authors the first one: (a) `target_profile` **replaces** `break_bias` for that move (a move is either a single-bias hit or a profiled multi-hit, never both); (b) per-target multipliers must be balanced so no single move both kills *and* fully breaks (content rule); (c) a sweep that breaks multiple regions in one resolution applies **one enrage stack per break**, all in that hit (a deliberate risk spike); (d) the `all_regions` selector **expands to the enemy's actual unbroken regions only** (Rule 2's target-set invariant) — a sweep on a 2-region enemy hits 2 regions, never a placeholder, and a profile entry naming a region the enemy lacks is dropped from the resolution. This rule reserves the schema and the routing contract; **no MVP move authors a `target_profile`**, and the Move DB erratum this GDD creates need only add the field as reserved/nullable. *(See Open Questions.)*

### States and Transitions

Per **region** (each tracked independently):

| State | Entered when | Exits to |
|-------|-------------|----------|
| `INTACT` | Battle start — `current_break_hp = break_hp` (Enemy DB `EDB-1`) | `BROKEN` when `current_break_hp ≤ 0` (Rule 5) |
| `BROKEN` | `current_break_hp` depleted | Terminal for the battle; all region state discarded at `BATTLE_END` |

Per **enemy**: `enrage_stacks` — integer `0 … (breakable region count)`, +1 per break (Rule 7), reset at battle end.

Part-Break has **no state machine of its own** — it is a passive accumulator hanging off TBC's turn loop. It reacts to `hit_resolved` during TBC's `RESOLVING` state and writes into TBC's battle-scoped structures. It holds only per-battle data (region pools, enrage stacks), never a persistent counter.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Turn-Based Combat** | ← subscribes / ↔ writes | Subscribes to `hit_resolved(move, damage, target)`; initializes region pools from Enemy DB at `BATTLE_INIT`; applies region-pool reductions; writes `<region>_broken` / `all_boss_parts_broken` into TBC's `fired_break_events` set. **Requires TBC erratum** for target-routed damage application (Rule 4), the 20% spillover, `break_bias` multipliers, and the enrage damage modifier (Rule 7) |
| **Enemy Database** | ← reads | `break_regions` (region ids/keys) and each region's `EDB-1`-derived `break_hp`; the enemy defense stat (consumed via TBC/DF-1) |
| **Move Database** | ← reads | `break_bias` per move — **requires Move DB erratum** to add the field + the `BREAK_BIAS_MULTIPLIERS` table |
| **Damage Formula** | ← indirect | Region damage is DF-1 output (via TBC Rule 10) before the `break_mult` split — no direct call |
| **Drop System** | → indirect (via TBC) | Break keys become Formula 3 condition multipliers on VICTORY; break ≠ guaranteed drop (Drop System owns the roll). Part-Break discharges Drop System's provisional Rule 5/7 contract — **but redefines it**: break is deterministic, so there is no `P(break fires)` and no break-failure pity (**Drop System erratum**) |
| **Combat UI** *(Not Started)* | → provides | Per-region target selectors, break-progress pips (`current_break_hp / break_hp`), break-pop VFX/SFX trigger, enrage indicator |

## Formulas

Part-Break owns five formulas (PB-F1…F5) plus a battle-start initialization step that re-materializes the Enemy DB's `EDB-1` output into runtime state. All damage formulas take the combat pipeline's per-hit integer `move_damage` (DF-1 → MOVE-F1 → TBC-F5, registered range **[1, 315]**) as their sole damage input. `DAMAGE_FLOOR = 1` (shared with Damage Formula) guards every damage formula so a weak hit against an unfavorable multiplier never deals 0.

**Break pool initialization (not a new formula — restates Enemy DB `EDB-1`).** At `BATTLE_INIT`, for each breakable region `R`:
```
R.current_break_hp = max(BREAK_HP_MIN, floor(enemy.stats["structure"] × R.region_fraction + 0.0001))   # = EDB-1
R.is_broken = false
```
Ownership: the value is `EDB-1`'s (Enemy DB); Part-Break only reads and stores it. Range: `[5, 330]`.

### BREAK_BIAS_MULTIPLIERS

The `(structure_mult, break_mult)` pair keyed on each move's `break_bias` enum. **Defined here; applied by TBC** (Rule 4). BALANCED = `(1.00, 1.00)` is the fixed calibration anchor (mirrors POWER_TIER's STANDARD = 1.00) — do not tune.

| `break_bias` | `structure_mult` | `break_mult` | Character | Effective vs Structure @ M=100 | Effective vs Region @ M=100 |
|--------------|------------------|--------------|-----------|-------------------------------|------------------------------|
| `STRUCTURE_HEAVY` | 1.25 | 0.55 | "Crusher" | 125 | 55 |
| `BALANCED` | 1.00 | 1.00 | — | 100 | 100 |
| `BREAK_HEAVY` | 0.70 | 1.40 | "Breaker" | 70 (+14 spillover) | 140 |

The enum enforces the trade: no bias is strong against both pools. The ratio `structure_mult : break_mult` is 2.27× for Crusher and 2.0× for Breaker — keep both ≥ 2.0× or the specialist collapses toward Balanced.

---

### Epsilon status (python3 scan-verified 2026-07-11)

An exhaustive scan over `move_damage ∈ [1,315]` (and `enemy_hit_resolved ∈ [1,315]` for PB-F5), comparing bare float `floor`, epsilon `floor(...+0.0001)`, and exact-rational `floor` as ground truth, found **zero epsilon overcorrections and zero unfixed errors** — the `+0.0001` nudge is necessary and sufficient. Load-bearing status per coefficient:

| Formula | Coefficient | Status | Sample load-bearing input |
|---------|-------------|--------|---------------------------|
| PB-F1 | `structure_mult = 0.70` (Breaker) | **LOAD-BEARING** | M=90 → exact 63.0, bare floor 62, eps 63 (also M=170, 180) |
| PB-F1 | 1.00, 1.25 | defensive | — |
| PB-F2 | `break_mult = 1.40` (Breaker) | **LOAD-BEARING** | M=165 → exact 231.0, bare floor 230, eps 231 (7 cases; same trap MOVE-F1 documents) |
| PB-F2 | 0.55, 1.00 | defensive | — |
| PB-F3 | all (`break_mult × 0.20`) | defensive | none — analytically *expected* load-bearing, empirically clean |
| PB-F5 | `1 + 1×0.15 = 1.15` | **LOAD-BEARING** | EHR=100 → exact 115.0, bare floor 114, eps 115 (4 cases) |
| PB-F5 | 1.30, 1.45 | defensive | — |

**Re-run this scan if any bias multiplier, `BREAK_SPILLOVER`, or `ENRAGE_PER_BREAK` is retuned** — the all-defensive/load-bearing split is input- and coefficient-specific.

---

### PB-F1 — Structure-Target Damage

```
structure_damage = max(DAMAGE_FLOOR, floor(move_damage × structure_mult + 0.0001))
```
Applied to the enemy's `current_structure` when the move sub-targets `STRUCTURE` (Rule 4a). **Applied by TBC** (it owns Structure).

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Pipeline damage | `move_damage` | int | 1–315 | TBC-F5 output (post DF-1/MOVE-F1/Stagger) |
| Structure multiplier | `structure_mult` | float | {0.70, 1.00, 1.25} | From BREAK_BIAS_MULTIPLIERS |
| Damage floor | `DAMAGE_FLOOR` | int | 1 | Shared with Damage Formula |
| Output | `structure_damage` | int | 1–393 | `floor(315 × 1.25 + ε) = 393` at ceiling |

**Worked example (rounding-discriminating):** M=107, Crusher (1.25): `max(1, floor(107 × 1.25 + 0.0001)) = max(1, floor(133.7501)) = 133` — round/ceil give 134.
**Worked example (epsilon-discriminating):** M=90, Breaker (0.70): exact `90 × 0.70 = 63.0`, but IEEE-754 bare `floor(62.99999…) = 62` — epsilon corrects to **63**. A naive floor is off by one here.

---

### PB-F2 — Region Break Damage

```
break_damage = max(DAMAGE_FLOOR, floor(move_damage × break_mult + 0.0001))
```
Applied to the sub-targeted region's `current_break_hp` (Rule 4b). **Applied by Part-Break.**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Pipeline damage | `move_damage` | int | 1–315 | Shared input with PB-F1 |
| Break multiplier | `break_mult` | float | {0.55, 1.00, 1.40} | From BREAK_BIAS_MULTIPLIERS |
| Damage floor | `DAMAGE_FLOOR` | int | 1 | Shared constant |
| Output | `break_damage` | int | 1–441 | `floor(315 × 1.40 + ε) = 441` at ceiling |

**Content note:** `break_damage` can exceed `EDB-1`'s max pool (330), so a peak-synergy Breaker SIGNATURE move one-shots any single region. Intended (decisive endgame breaking); encounter designers should expect it.

**Worked example (rounding-discriminating):** M=89, Breaker (1.40): `max(1, floor(89 × 1.40 + 0.0001)) = max(1, floor(124.6001)) = 124` — round/ceil give 125.
**Worked example (epsilon-discriminating):** M=165, Breaker (1.40): exact `231.0`, IEEE-754 bare `floor(230.9999…) = 230` — epsilon corrects to **231** (the registry's documented MOVE-F1 trap, recurring here).

---

### PB-F3 — Break Spillover to Structure

```
spillover_damage = max(DAMAGE_FLOOR, floor(move_damage × break_mult × BREAK_SPILLOVER + 0.0001))
```
Fires alongside PB-F2 on every region-targeted hit; subtracted from `current_structure` (Rule 4b). **Applied by TBC.** `BREAK_SPILLOVER = 0.20`.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Pipeline damage | `move_damage` | int | 1–315 | Shared input |
| Break multiplier | `break_mult` | float | {0.55, 1.00, 1.40} | Same bias as PB-F2 — the bias that governs break efficiency also governs spillover |
| Spillover fraction | `BREAK_SPILLOVER` | float | 0.20 | Tuning knob |
| Damage floor | `DAMAGE_FLOOR` | int | 1 | Shared constant |
| Output | `spillover_damage` | int | 1–88 | `floor(315 × 1.40 × 0.20 + ε) = 88` at ceiling |

**Worked example (rounding-discriminating):** M=107, Breaker (1.40): `max(1, floor(107 × 1.40 × 0.20 + 0.0001)) = max(1, floor(29.9601)) = 29` — round/ceil give 30. (Scan-verified: PB-F3 epsilon is defensive across all coefficients — no epsilon-discriminating case exists.)

---

### PB-F4 — Region Break Trigger (deterministic)

Pure integer state update — **no float arithmetic, no epsilon, no RNG** (Rule 5). This is the entirety of the break "success" mechanic (DB3(a)).

```
R.current_break_hp = max(0, R.current_break_hp − break_damage)
if R.current_break_hp == 0 and not R.is_broken:
    R.is_broken = true
    emit(<region_id> + "_broken")           # into TBC fired_break_events set
    enemy.broken_region_count += 1           # feeds PB-F5
    if all(reg.is_broken for reg in enemy.break_regions):
        emit("all_boss_parts_broken")
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Region pool | `R.current_break_hp` | int | 0–330 | Remaining break HP; `max(0)`-guarded |
| Break damage | `break_damage` | int | 1–441 | PB-F2 output |
| Broken flag | `R.is_broken` | bool | — | Guard: a region emits its event at most once |

**Overkill:** excess break damage beyond the pool is discarded — it does **not** add to `spillover_damage` (PB-F3 is computed from raw `move_damage`, not HP actually depleted, so a one-shot break on a near-empty region does not deal outsized spillover). *Verified by AC-PB-08.*

**Worked example:** `R.current_break_hp = 30`, `break_damage = 35` → `max(0, 30 − 35) = 0` → region breaks, emits `arm_broken`, `broken_region_count` → 1.

---

### PB-F5 — Enrage Damage Multiplier

```
enraged_damage = max(DAMAGE_FLOOR, floor(enemy_hit_resolved × (1.0 + broken_region_count × ENRAGE_PER_BREAK) + 0.0001))
```
Applied by TBC to the **enemy's** outgoing hit (Rule 7), after the enemy's own DF-1/pipeline resolution, before it reduces a player Symbot's `current_structure`. `ENRAGE_PER_BREAK = 0.15`.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy resolved hit | `enemy_hit_resolved` | int | 1–315 | Enemy's TBC-F5 output pre-enrage (realistic ≤ ~55 at EDB-2 base calibration) |
| Broken region count | `broken_region_count` | int | 0–3 | Enemy regions currently `is_broken` (MVP cap 3) |
| Enrage per break | `ENRAGE_PER_BREAK` | float | 0.15 | Tuning knob; additive per break |
| Damage floor | `DAMAGE_FLOOR` | int | 1 | Shared constant |
| Output | `enraged_damage` | int | 1–456 | Multiplier range [1.00, 1.45]; `floor(315 × 1.45 + ε) = 456` at theoretical ceiling |

**Worked example (rounding-discriminating):** `enemy_hit_resolved = 73`, `broken_region_count = 2` → mult 1.30: `max(1, floor(73 × 1.30 + 0.0001)) = max(1, floor(94.9001)) = 94` — round/ceil give 95.
**Worked example (epsilon-discriminating):** `enemy_hit_resolved = 100`, `broken_region_count = 1` → mult 1.15: exact `115.0`, IEEE-754 bare `floor(114.9999…) = 114` — epsilon corrects to **115**.

**Calibration:** at 3 breaks (+45%) a mid enemy dealing ~40 rises to ~58 vs a ~200-Structure Symbot (5 hits-to-down → 3–4). Dangerous for glass cannons, absorbable by tanky/synergy builds — full dismantle is a skilled challenge, not a wall. The `all_boss_parts_broken` capstone is thus fought against a maximally enraged enemy.

## Edge Cases

**EC-PB-01 — Kill before break (the core tension).** *If Structure reaches 0 while a region is still `INTACT`*: the fight ends in VICTORY immediately (TBC Rule 12), the region is never broken, and its `<region>_broken` key never enters `fired_break_events`. The harvest is lost — this is the intended "don't finish too early" discipline, not an error. *Verified by AC-PB-21.*

**EC-PB-02 — Resolution order within one region hit (break vs. victory).** A region-targeted hit resolves in fixed order: (1) apply PB-F2 to the region pool — if depleted, the break fires and `broken_region_count` increments (PB-F4); (2) apply PB-F3 spillover to Structure; (3) TBC checks victory. Because the break (step 1) always resolves before the victory check (step 3), **a hit that both breaks the region and drops Structure to 0 via spillover counts the break** — the event is already in the set when VICTORY fires, so it pays out. *Verified by AC-PB-22.*

**EC-PB-03 — Spillover kills without breaking.** *If a region-targeted hit's PB-F3 spillover drops Structure to 0 while the region pool is not yet depleted*: step 1 fires no break, step 3 triggers VICTORY, and the region is lost un-broken. Legible consequence of over-committing spillover on a low-Structure enemy — the player killed it a hit early. *Verified by AC-PB-23.*

**EC-PB-04 — Overkill break damage is discarded and does not inflate spillover.** *If `break_damage` exceeds the region's remaining `current_break_hp`*: the pool floors at 0 (PB-F4 `max(0,…)`), the region breaks once, and the excess is discarded. Spillover (PB-F3) is computed from raw `move_damage`, **not** from HP actually depleted, so a one-shot break on a near-empty region deals normal spillover, never an outsized burst. *Verified by AC-PB-08.*

**EC-PB-05 — Hit on an already-broken region.** *If a DAMAGE move is directed at a region already `BROKEN`* (via API/edge; the Combat UI normally removes it as a target): the hit is redirected entirely to Structure at the move's `structure_mult` (treated as a Structure hit, PB-F1). No re-break, no re-emitted event, no lost damage. *Verified by AC-PB-18.*

**EC-PB-06 — Enemy with zero breakable regions.** *If an enemy authors an empty `break_regions`*: no region targets exist, every DAMAGE hit resolves against Structure, no break event can fire, and `broken_region_count` stays 0 (enrage never engages). No crash. *Verified by AC-PB-20.*

**EC-PB-07 — Region at the `BREAK_HP_MIN` floor is one-shot-breakable.** *If `EDB-1` floors a region at `break_hp = 5`* (tiny enemy): any hit dealing ≥ 5 break damage depletes it in one hit and breaks it normally (PB-F4). Legal — Part-Break consumes whatever `EDB-1` produces; the floor is Enemy DB's concern (its AC-ED-07). *Verified by AC-PB-11.*

**EC-PB-08 — Weakest breaking tool still makes progress (no zero-progress soft-lock).** *If a `STRUCTURE_HEAVY` move (`break_mult = 0.55`) hits a region at `move_damage = 1`*: `floor(1 × 0.55 + ε) = 0`, but `DAMAGE_FLOOR = 1` raises it to 1. Every hit chips at least 1 break HP, so even the worst tool can eventually break any region — there is no build that is *unable* to break (the "failure" mode is dying first, a build problem, not an RNG wall). This is why DB3(b)'s break-failure pity is dissolved. *Verified by AC-PB-05.*

**EC-PB-09 — Region progress survives a player switch.** *If the player switches Symbots mid-break*: region pools are the **enemy's** battle state, independent of which player Symbot is active. Break progress accumulated by one Symbot persists and a switched-in Symbot continues from the same `current_break_hp`. *Verified by AC-PB-19.*

**EC-PB-10 — Break progress evaporates on non-victory.** *If the player flees or is defeated after damaging or breaking regions*: all region pools, `is_broken` flags, and enrage stacks are discarded (Rule 8), and TBC discards `fired_break_events` (Rule 12) — no drops, no persisted progress (consistent with Drop System EC-DS-07). Nothing carries to the next encounter with that enemy. *Verified by AC-PB-24.*

**EC-PB-11 — Non-DAMAGE move on the enemy.** *If a STATUS / SCAN / UTILITY move targets the enemy*: it has no sub-target (Rule 2) and routes no damage through Part-Break — no Structure damage, no region damage, no break progress. (A STATUS move still applies its status via TBC; that path is unchanged.) *Verified by AC-PB-25.*

**EC-PB-12 — The spillover "total-damage" property is not a dominant strategy (design note, no runtime branch).** A `BREAK_HEAVY` hit on a region deals a *combined* coefficient of 1.68 (1.40 region + 0.28 spillover) versus `STRUCTURE_HEAVY`'s 1.25 direct-to-Structure — but this is **not** a kill-speed exploit: for pure killing, `STRUCTURE_HEAVY` puts 1.25 into Structure while `BREAK_HEAVY`'s spillover puts only 0.28 there, so a player who doesn't want the break is always faster hitting Structure directly. The extra region damage is only "value" if you want the part. *No dedicated AC — this is a balance property of the bias table (Section D), not an observable failure branch; the bias multipliers' ≥2.0× ratio is the enforcing mechanism.*

**EC-PB-13 — Targets are always valid by construction (closed target set).** *There is no "invalid target" case*: the selectable sub-targets are built from `enemy.break_regions` (Rule 2's invariant), so the resolver only ever receives `STRUCTURE` or a region that exists on this enemy and is unbroken. A move can never target a region the enemy lacks — the option is never generated. A reserved multi-region move (Rule 11) resolves its `all_regions` selector against the enemy's *actual* unbroken regions, so a sweep on a 2-region enemy affects exactly those 2 regions. This is an invariant to assert, not a failure to recover from — there is no redirect or error path because there is no invalid input. *Verified by AC-PB-30.*

## Dependencies

### Upstream (Part-Break reads from / is triggered by)

| System | What Part-Break reads | Status | Hard/Soft |
|--------|----------------------|--------|-----------|
| **Turn-Based Combat** | `hit_resolved(move, damage, target)` per-hit hook; battle lifecycle (`BATTLE_INIT` to init pools, `BATTLE_END` to discard); the `fired_break_events` set it writes into | Approved | Hard |
| **Enemy Database** | `break_regions` (region ids + `region_fraction`) and each region's `EDB-1`-derived `break_hp` | Approved | Hard |
| **Move Database** | `break_bias` per DAMAGE move (and reserved `target_profile`, Rule 11) | Approved | Hard (via TBC erratum) |
| **Damage Formula** | Indirect — region damage is DF-1 output (via TBC Rule 10) before the `break_mult` split | Approved | Soft (no direct call) |

### Downstream (these read from Part-Break)

| System | What it reads | Status | Obligation on that GDD |
|--------|---------------|--------|------------------------|
| **Drop System** | The `<region>_broken` / `all_boss_parts_broken` keys in `fired_break_events` (delivered by TBC on VICTORY) as Formula 3 condition multipliers | Approved | Break keys must match Drop System Rule 5 vocabulary exactly (they do); **must update its provisional Part-Break contract** — see Errata below |
| **Turn-Based Combat** | Region-pool reductions (Part-Break applies); break events (into TBC's set); `broken_region_count` (feeds PB-F5, TBC applies) | Approved | **Must ratify the routing + spillover + bias + enrage erratum** — see Errata below |
| **Combat UI** *(Not Started)* | Per-region target selectors; break-progress pips (`current_break_hp / break_hp`); break-pop VFX/SFX trigger; enrage indicator | Not Started | Must render region targeting and break progress; must make targeting legible (the Pillar-2 "visible tilt" wiring) |

### Errata obligations this GDD creates on Approved documents

| Target (Approved) | Change required | Source decision | Re-review weight |
|-------------------|-----------------|-----------------|------------------|
| **Turn-Based Combat** | Rule 10 damage application must (a) route by sub-target — Structure vs a region; (b) apply `structure_mult` / `break_mult` from `BREAK_BIAS_MULTIPLIERS`; (c) apply PB-F3 spillover to Structure on region hits; (d) apply PB-F5 enrage to the **enemy's** outgoing damage; (e) extend the action / Move Contract with the region sub-targeting layer TBC explicitly deferred to Part-Break. Also: **the BINDING Pillar-2 obligation TBC placed on Part-Break is discharged** (see below). | Rules 3–7, Formulas | **Substantial** — touches the core damage pipeline; needs a focused re-review |
| **Move Database** | Add a `break_bias` field (enum, default `BALANCED`) + the `BREAK_BIAS_MULTIPLIERS` constant table; add a reserved/nullable `target_profile` field (Rule 11, no MVP content); list Part-Break as a referencing system (bidirectionality). | Rule 3, Rule 11 | Small — additive field + table |
| **Drop System** | Its provisional Rule 5/7 characterization of Part-Break as owning `P(break fires)` + a break-failure pity is **redefined**: break is deterministic on pool depletion (PB-F4), so there is no break probability and no break-failure pity. **DS-3 drop-RNG pity is unaffected** (it still handles the post-break drop-roll tail). Update Rule 5, Rule 7, and the Part-Break dependency row. | Rules 5, 9; DB3 resolution | Small — clarifying prose; no formula/number change |

### Upstream obligations this GDD discharges

- **Part DB DB3** (Part-Break must define break triggering + a break-failure escalation mechanic): **(a)** triggering = deterministic pool depletion (PB-F4) — no probability; **(b)** the break-failure escalation/soft-lock is **dissolved**, not built: because break is deterministic and `DAMAGE_FLOOR` guarantees every hit makes progress (EC-PB-08), no build can be RNG-walled from breaking — the only failure is player defeat, recoverable by rebuilding (Pillar 1/3). The *drop*-RNG tail after a break remains Drop System DS-3's pity. This is a **legitimate resolution of DB3** — it satisfies the constraint's intent (no soft-lock) by removing the RNG DB3 feared.
- **Enemy DB ED2 / `break_regions` runtime semantics**: Part-Break defines what `break_regions` *means* at runtime — one independent pool per region, initialized from `EDB-1`, depleted by region-targeted damage (PB-F2), broken deterministically (PB-F4). Discharged.
- **TBC BINDING (Pillar-2 anchor)** — "part-targeting MUST impose a real cost relative to fastest-kill routing": **discharged**. Breaking costs (i) extra turns of exposure (break damage is largely off the kill clock — only 20% spills), (ii) rising enrage risk per region broken (PB-F5), and (iii) reduced kill-efficiency when using Breaker bias on Structure. Part-Break carries its own AC for this (AC-PB-28, Section H), as TBC required.
- **Drop System provisional contract** (Part-Break emits exactly the Rule 5 keys): discharged — Rule 9 mandates exact vocabulary match.

### Bidirectionality

- **Turn-Based Combat** already lists Part-Break as a downstream dependent (with the BINDING Pillar-2 note) ✓
- **Enemy Database** already references Part-Break (`break_regions`, `drop_conditions` vocabulary, DB3) ✓
- **Drop System** already references Part-Break (provisional Rule 5/7 contract) ✓ — this GDD redefines that contract (Errata)
- **Part Database** already references Part-Break (DB3) ✓
- **Move Database** does **not** yet reference Part-Break (it predates this GDD) — the erratum above adds the reference (bidirectionality gap to close)
- **Combat UI** (Not Started) will reference Part-Break when authored

## Tuning Knobs

| Knob | Value | Safe Range | What changing it does |
|------|-------|-----------|-----------------------|
| `BREAK_SPILLOVER` | 0.20 | 0.10 – 0.30 | Fraction of region-hit damage that bleeds into Structure (PB-F3). Higher → breaking chips the kill faster, harvest cost drops (toward ~0.67× a region's worth), Breaker builds also kill decently; lower → breaking is a purer detour, harvest cost rises (toward ~0.90×), a failed drop feels more wasted. **Re-run the epsilon scan if changed** (product coefficients shift). |
| `ENRAGE_PER_BREAK` | 0.15 | 0.08 – 0.20 | Additive enemy outgoing-damage bonus per broken region (PB-F5); max total = 3× this at full dismantle. At 0.20 (max +60%) a fully-enraged enemy can two-shot glass-cannon Symbots — tips from "risky" to "punishing." At 0.08 (max +24%) enrage is cosmetic and full-dismantle becomes near-free loot. **Re-run the epsilon scan if changed** (new multipliers). |
| `BREAK_BIAS_MULTIPLIERS` → STRUCTURE_HEAVY `structure_mult` | 1.25 | 1.15 – 1.40 | Crusher kill speed. Higher sharpens the kill-vs-harvest identity; toward 1.15 the Crusher collapses into Balanced. |
| STRUCTURE_HEAVY `break_mult` | 0.55 | keep ratio `structure_mult : break_mult` ≥ 2.0× | Crusher's (poor) breaking. Must stay low enough that the Crusher is clearly bad at harvesting. |
| BALANCED `(structure_mult, break_mult)` | (1.00, 1.00) | **FIXED** | The calibration anchor for the whole table (mirrors POWER_TIER's STANDARD = 1.00). Do not tune — all other multipliers are defined relative to it. |
| BREAK_HEAVY `break_mult` | 1.40 | 1.20 – 1.60 | Breaker break speed. Toward 1.60, even mid Breaker hits one-shot large regions (collapses the "which region" choice); toward 1.20, breaking big regions becomes a multi-hit slog. |
| BREAK_HEAVY `structure_mult` | 0.70 | keep ratio `break_mult : structure_mult` ≥ 2.0× | Breaker's (poor) kill speed. **Load-bearing epsilon coefficient (PB-F1)** — re-run the scan if changed. |

**Owned elsewhere — referenced, not duplicated:**
- `DAMAGE_FLOOR` = 1 (Damage Formula) — floors every Part-Break damage formula.
- `BREAK_HP_MIN` = 5, `region_fraction` (0.15–0.55), `EDB-1` (Enemy Database) — **the always-on harvest-cost lever.** The primary control over "how expensive is it to break everything" is not a Part-Break knob but the region fractions in Enemy DB content: bigger fractions → bigger pools → more turns exposed → costlier full dismantle. Enrage is the *active* escalator layered on top; fraction tuning is the *passive* baseline.
- `move_damage` pipeline (DF-1 → MOVE-F1 → TBC-F5) — the damage input; its ceiling (315) sets Part-Break's output ceilings.

**Knob interaction warnings:**
1. **Any change to a bias multiplier, `BREAK_SPILLOVER`, or `ENRAGE_PER_BREAK` invalidates the epsilon scan** — the load-bearing/defensive split (PB-F1@0.70, PB-F2@1.40, PB-F5@1.15 load-bearing; rest defensive) is coefficient-specific. Re-run the python3 scan and update Section D.
2. **`ENRAGE_PER_BREAK` is coupled to player Structure ranges** — it is balanced against SA-F1's Structure output (60–594) and the DF-1 enemy-damage band. Retuning enemy power (EDB-2) or Structure ranges shifts what enrage "feels like"; check the glass-cannon case (low-Structure builds vs. max enrage) before shipping a change.
3. **Full-dismantle difficulty is a two-lever system** — `region_fraction` (Enemy DB, passive cost) and `ENRAGE_PER_BREAK` (active risk). Tune them together: raising both compounds, and a high-fraction + high-enrage boss can become a wall for anything but a top-tier build (which may be the intent for a capstone, but is a design decision, not a tuning pass).

## Visual/Audio Requirements

> **Asset Spec flag**: No asset specifications exist yet. The Art Bible (`/art-bible` not yet run) is the prerequisite for per-asset dimensions, palettes, and frame budgets. Everything below is **intent and constraint**. After the Art Bible is approved, run `/asset-spec system:part-break`.
>
> **Art Bible ratification required**: element colors and timing budgets below inherit the Assembly rarity-glow table (Volt = cyan, Thermal = amber, Kinetic = white/silver) as the current canonical reference; the Art Bible may extend but must not contradict them.

**VA-1 — The break-pop is the signature sensation (binding intent).** The moment a region's pool depletes (PB-F4) must land as the game's most satisfying non-kill feedback — the "satisfying part-break effects" the game concept names as its Sensation pillar. The region visibly shatters/detaches with an element-colored burst (the *breaking hit's* element, not the region's), a distinct SFX "crunch," and a beat of hit-stop. It must read as clearly *different* from a normal hit and from the kill.

**VA-2 — Break progress must be visible on the enemy (legibility gate).** As a region's pool depletes, the enemy sprite shows escalating damage states (e.g., cracks → sparking → near-broken) so the player can read "two more hits or eight?" from the enemy itself, not only from UI pips. Without this, the harvest decision degrades to guesswork (the Player Fantasy's "progress visibility" beat).

**VA-3 — Enrage must telegraph rising danger (never color alone).** Each broken region visibly escalates the enemy — intensifying glow, more aggressive idle, an audio register that climbs per stack — so the player *feels* the greed tax of PB-F5 before the bigger hit lands. Per the project accessibility standard (TBC V1-3), enrage state carries a second non-color channel (posture/animation/icon), not just a color shift.

**VA-4 — The capstone break is bigger.** `all_boss_parts_broken` triggers a heightened version of VA-1 — a full-dismantle flourish — matching the risk the player took to earn it.

**VA-5 — Timing budget.** Break-pop VFX + SFX must fit inside TBC's turn-resolution budget (≤ 2.0 s total per turn); the break beat shares that window with the hit and damage-number feedback.

## UI Requirements

> **📌 UX Flag — Part-Break**: This system imposes real UI requirements on the **Combat UI** (Not Started). In Pre-Production, run `/ux-design` for the Combat UI's break elements **before** writing Combat UI epics. These are the requirements Part-Break places on that screen; Part-Break owns no UI of its own.

**UI-1 — Region target selectors (touch-first).** The enemy presents selectable sub-targets — Structure plus each unbroken region — as discrete tap targets (≥ 44×44 pt per the project touch standard). The selectable set is exactly Rule 2's closed set; broken regions are removed as targets (not greyed-and-tappable).

**UI-2 — Break-progress pips.** Each region shows its `current_break_hp / break_hp` as a pip/fill so the player can plan turn counts. This is the UI half of VA-2 (the enemy sprite is the other half).

**UI-3 — The harvest tilt must be legible (Pillar-2 wiring).** The UI must make it visible that targeting a region is *worth it* — e.g., surfacing which part a region's break helps drop (ties to Enemy DB ED6 / the Move DB SCAN reveal). This is the downstream half of the "visible tilt" promise the Drop System's fantasy depends on.

**UI-4 — Enrage indicator.** The current enrage stack (0–3) and its effect are shown, so the rising-danger tax is a read the player can act on, not a surprise.

**UI-5 — Break-pop readout.** When a region breaks, the UI confirms the specific break (`arm_broken`, etc.) so the player connects the shatter to the harvest condition they were targeting.

## Acceptance Criteria

Validated by `qa-lead` (2026-07-11). **30 criteria — 28 BLOCKING (Logic / Integration), 2 ADVISORY (Content Validation).** Every core rule (R1–R11), every formula (PB-F1–F5), and all 13 edge cases have a verifying AC. Formula ACs carry two fixture kinds where relevant: a **rounding-method discriminator** (input where floor ≠ round ≠ ceil) and an **epsilon regression** (input whose exact product is integer but whose naive float floor is one low). All fixtures are deterministic; enemy/build stats live in test fixtures, not inline.

### Formula criteria

**AC-PB-01 (PB-F1 Structure damage).** **[Logic, BLOCKING]** *(a) Rounding discriminator:* **GIVEN** `move_damage = 107`, `STRUCTURE_HEAVY` (`structure_mult = 1.25`), **WHEN** a Structure-target hit resolves, **THEN** `structure_damage == 133` (round/ceil give 134). *(b) Epsilon regression:* **GIVEN** `move_damage = 90`, `BREAK_HEAVY` (`structure_mult = 0.70`), **WHEN** it resolves, **THEN** `structure_damage == 63` (a naive float `floor(62.9999…)` returns 62 — load-bearing).

**AC-PB-02 (PB-F2 break damage).** **[Logic, BLOCKING]** *(a)* **GIVEN** `move_damage = 89`, `BREAK_HEAVY` (`break_mult = 1.40`), **WHEN** a region-target hit resolves, **THEN** `break_damage == 124` (round/ceil give 125). *(b) Epsilon regression:* **GIVEN** `move_damage = 165`, `break_mult = 1.40`, **THEN** `break_damage == 231` (naive `floor(230.9999…)` = 230 — the documented MOVE-F1 trap).

**AC-PB-03 (PB-F3 spillover).** **[Logic, BLOCKING]** **GIVEN** `move_damage = 107`, `BREAK_HEAVY` (`break_mult = 1.40`), `BREAK_SPILLOVER = 0.20`, **WHEN** a region-target hit resolves, **THEN** `spillover_damage == 29` (round/ceil give 30). *(PB-F3 epsilon is scan-verified defensive — no epsilon-regression fixture exists or is required.)*

**AC-PB-04 (PB-F5 enrage damage).** **[Logic, BLOCKING]** *(a) Rounding discriminator:* **GIVEN** `enemy_hit_resolved = 73`, `broken_region_count = 2` (×1.30), **WHEN** the enemy attack resolves, **THEN** `enraged_damage == 94` (exact 94.9; round/ceil give 95 — not an epsilon case). *(b) Epsilon regression:* **GIVEN** `enemy_hit_resolved = 100`, `broken_region_count = 1` (×1.15), **THEN** `enraged_damage == 115` (naive `floor(114.9999…)` = 114 — load-bearing). *(c) Identity:* **GIVEN** `broken_region_count = 0`, **THEN** `enraged_damage == enemy_hit_resolved` (multiplier exactly 1.0).

**AC-PB-05 (PB-F1/F2/F3 DAMAGE_FLOOR clamp).** **[Logic, BLOCKING]** *(a)* **GIVEN** `move_damage = 1`, `STRUCTURE_HEAVY` (`break_mult = 0.55`), **WHEN** a region hit resolves, **THEN** `break_damage == 1` (`floor(0.55) = 0`, clamped up). *(b)* **GIVEN** `move_damage = 1`, `BREAK_HEAVY` (`structure_mult = 0.70`), **THEN** `structure_damage == 1`. *(c)* **GIVEN** `move_damage = 1`, `STRUCTURE_HEAVY` (`break_mult = 0.55`), region-target, **THEN** `spillover_damage == 1` (`floor(0.11) = 0`, clamped up).

**AC-PB-06 (bias routing table).** **[Logic, BLOCKING]** **GIVEN** `move_damage = 100`, **WHEN** each bias resolves against Structure and against a region, **THEN** the three products per bias hold: `STRUCTURE_HEAVY` → (structure 125, break 55, spillover 11); `BALANCED` → (100, 100, 20); `BREAK_HEAVY` → (70, 140, 28). *(No epsilon risk at M=100 for any coefficient.)*

### Break-trigger & event criteria

**AC-PB-07 (deterministic break — no RNG).** **[Logic, BLOCKING]** **GIVEN** a region `{current_break_hp = 30}` and `break_damage = 30`, **WHEN** the break resolution is invoked repeatedly with identical state, **THEN** it breaks (emits the event, `broken_region_count → 1`) **every** invocation — the resolution touches no RNG. *(Negative:* **GIVEN** `break_damage = 29` on the same pool, **THEN** no break, `current_break_hp == 1`, no event.) This is the whole of DB3(a) — break is deterministic.

**AC-PB-08 (overkill discarded, spillover not inflated).** **[Logic, BLOCKING]** **GIVEN** a region `{current_break_hp = 30}`, `BREAK_HEAVY`, `move_damage = 200` (`break_damage = 280`), **WHEN** the region-target hit resolves, **THEN** `current_break_hp` floors at 0 (not −250), the region breaks exactly once, **and** `spillover_damage == floor(200 × 1.40 × 0.20 + ε) == 56` — computed from `move_damage`, never scaled to the 30 HP actually depleted.

**AC-PB-09 (all_boss_parts_broken emission).** **[Logic, BLOCKING]** **GIVEN** an enemy with `N` breakable regions, **WHEN** the last INTACT region breaks, **THEN** both `<region>_broken` and `all_boss_parts_broken` are emitted, and `broken_region_count == N` at emission. **WHEN** fewer than `N` are broken, `all_boss_parts_broken` is absent.

**AC-PB-10 (broken_region_count sequences correctly).** **[Logic, BLOCKING]** **GIVEN** an enemy with 3 regions each `break_hp = 10`, **WHEN** three sequential break hits (`break_damage = 10`) land, **THEN** `broken_region_count` reads 1, then 2, then 3 after each, and `all_boss_parts_broken` fires **only** on the third — never the first or second.

**AC-PB-11 (BREAK_HP_MIN one-shot).** **[Logic, BLOCKING]** **GIVEN** a region floored at `break_hp = 5` (EDB-1 minimum), **WHEN** a hit deals `break_damage ≥ 5`, **THEN** the region breaks in one hit and `broken_region_count` increments.

**AC-PB-12 (R4 sub-target routing path).** **[Logic, BLOCKING]** **GIVEN** a `BALANCED` move (both mults 1.00), `move_damage = 100`, **WHEN** the sub-target is `STRUCTURE`, **THEN** `structure_damage = 100` and no region pool changes; **WHEN** the sub-target is region A, **THEN** region A's pool drops by 100 and Structure drops by the spillover (20) only. *(Catches an impl that ignores the sub-target and always routes to Structure.)*

### Enrage criteria

**AC-PB-13 (enrage stacking via PB-F5 output).** **[Logic, BLOCKING]** **GIVEN** `enemy_hit_resolved = 100`, **WHEN** `broken_region_count` is 0, 1, 2, 3, **THEN** `enraged_damage` is 100, 115, 130, 145 respectively (the ×1.15 case is the load-bearing epsilon case from AC-PB-04b). Reset at battle end is covered by AC-PB-24.

**AC-PB-14 (enrage applied to real player-received damage).** **[Integration, BLOCKING]** **GIVEN** `broken_region_count = 1` and an enemy whose resolved hit is 100, **WHEN** the enemy attacks a player Symbot end-to-end through TBC, **THEN** the Symbot's `current_structure` drops by **115** (PB-F5 applied to outgoing enemy damage, not just computed). *(Catches an impl that computes the multiplier but never applies it.)*

### Pool-independence & lifecycle criteria

**AC-PB-15 (pool independence).** **[Logic, BLOCKING]** **GIVEN** an enemy with regions A and B, **WHEN** a Structure-target hit resolves, **THEN** neither region's pool changes; **WHEN** a region-A hit resolves, **THEN** only A's pool changes, B's pool is unchanged, and Structure changes by exactly the spillover amount (not by `break_damage`).

**AC-PB-16 (free targeting — no extra cost).** **[Logic, BLOCKING]** **GIVEN** one move with a fixed `energy_cost` and `heat_generation`, **WHEN** it is used against Structure versus against a region, **THEN** the Energy paid and Heat gained are identical, and exactly one action is consumed in both cases.

**AC-PB-17 (type effectiveness reaches break damage).** **[Logic, BLOCKING]** **GIVEN** two region-target hits identical except type effectiveness `T = 1.5` versus `T = 1.0` (T applied upstream inside DF-1, so it is baked into `move_damage`), **WHEN** they resolve, **THEN** the super-effective hit's `break_damage` is strictly larger — breaking respects type matchup (Rule 10).

**AC-PB-18 (already-broken hit redirects to Structure).** **[Logic, BLOCKING]** **GIVEN** a region already `BROKEN`, a `BREAK_HEAVY` move (`structure_mult = 0.70`), `move_damage = 100`, **WHEN** a hit is (via API) directed at it, **THEN** no re-break and no duplicate event, and `structure_damage == floor(100 × 0.70 + ε) == 70` is applied to Structure (redirect uses the move's own `structure_mult`); the region's pool stays 0.

**AC-PB-19 (region progress survives a switch).** **[Integration, BLOCKING]** **GIVEN** a region reduced to `current_break_hp = 40` by Symbot A, **WHEN** the player switches to Symbot B and B damages the same region, **THEN** B continues from 40 (progress is enemy-side battle state, not per-Symbot).

**AC-PB-20 (enemy with zero breakable regions).** **[Logic, BLOCKING]** **GIVEN** an enemy with empty `break_regions`, **WHEN** any DAMAGE hits resolve, **THEN** no break events fire, `broken_region_count` stays 0, and there is no crash.

### Battle-end & victory-interaction criteria

**AC-PB-21 (kill before break).** **[Logic, BLOCKING]** **GIVEN** a region INTACT and enemy Structure = 10, **WHEN** a `STRUCTURE_HEAVY` Structure-target hit (`move_damage = 8` → 10) drops Structure to 0, **THEN** the battle ends VICTORY, the region stays INTACT, and its `<region>_broken` key is absent from `fired_break_events`.

**AC-PB-22 (break and kill in the same hit — break counts).** **[Logic, BLOCKING]** **GIVEN** a region `break_hp = 5`, enemy Structure = 3, **WHEN** a `BREAK_HEAVY` region hit `move_damage = 11` resolves (`break_damage = 15 ≥ 5` breaks; `spillover = 3 ≥ 3` kills), **THEN** (per the fixed order) the region breaks and emits `<region>_broken` with a non-empty key payload **before** the victory check, the battle ends VICTORY, and the break event is present in the set handed to the Drop System.

**AC-PB-23 (spillover kills without breaking).** **[Logic, BLOCKING]** **GIVEN** a region `break_hp = 100`, enemy Structure = 3, **WHEN** a `BREAK_HEAVY` region hit `move_damage = 50` resolves (`break_damage = 70 < 100`, `spillover = 14 ≥ 3`), **THEN** the battle ends VICTORY, the region is NOT broken (`current_break_hp == 30`), and no `<region>_broken` is emitted.

**AC-PB-24 (break progress evaporates on non-victory).** **[Integration, BLOCKING]** **GIVEN** broken regions and non-zero enrage mid-battle, **WHEN** the player flees (scenario A) **or** is defeated (scenario B), **THEN** all region pools, `is_broken` flags, `broken_region_count`, and `fired_break_events` are discarded, and a fresh encounter with the same enemy starts every region INTACT with `broken_region_count = 0`.

**AC-PB-25 (non-DAMAGE move does no break progress).** **[Logic, BLOCKING]** **GIVEN** a STATUS / SCAN / UTILITY move targeting the enemy, **WHEN** it resolves, **THEN** no Structure or region damage is routed through Part-Break and no break progress occurs (the status itself still applies via TBC).

### Content-validation & invariant criteria

**AC-PB-26 (break-key vocabulary match).** **[Content Validation, ADVISORY]** **GIVEN** every break key Part-Break can emit, **WHEN** validated against the Drop System Rule 5 vocabulary (`design/gdd/drop-system.md` Rule 5), **THEN** every key is a member (`<region>_broken`, `all_boss_parts_broken`); zero keys fall outside it.

**AC-PB-27 (multi-target reserved — no MVP content).** **[Content Validation, ADVISORY]** **GIVEN** all MVP moves, **WHEN** validated, **THEN** zero moves author a non-null `target_profile` (Rule 11 is reserved; MVP is single-sub-target).

**AC-PB-28 (Pillar-2 harvest cost — BINDING).** **[Integration, BLOCKING]** **GIVEN** the reference fixture — enemy Structure 60 with 3 regions each `break_hp = 30`, one move `move_damage = 30`, unlimited uses — **WHEN** Route A (STRUCTURE_HEAVY on Structure: 37 dmg/turn) and Route B (BREAK_HEAVY breaking all 3 regions, +8 spillover each, then finishing at 21/turn) are each run with identical Symbot config, **THEN** Route A reaches VICTORY in **2** turns and Route B in **5** turns, and the assertion `harvest_turns (5) > fastest_kill_turns (2)` holds. Discharges the TBC BINDING Pillar-2 obligation: part-targeting is never free relative to fastest kill.

**AC-PB-29 (battle-local state, fresh init).** **[Logic, BLOCKING]** **GIVEN** any enemy, **WHEN** a battle begins, **THEN** every region initializes to `current_break_hp = EDB-1(structure, region_fraction)`, `is_broken = false`, and `broken_region_count = 0` — no value carries from any previous battle.

**AC-PB-30 (closed target-set invariant).** **[Logic, BLOCKING]** **GIVEN** an enemy with a specific set of unbroken regions, **WHEN** the legal sub-target set for a DAMAGE move is constructed, **THEN** it equals exactly `{STRUCTURE} ∪ {unbroken existing regions}` — no region absent from the enemy is selectable, and a broken region is excluded. **AND** (reserved) a multi-region `target_profile` whose `all_regions` selector is expanded on a 2-region enemy resolves against exactly those 2 regions, dropping any profile entry naming an absent region. There is no invalid-target runtime branch — validity is structural (Rule 2).

## Open Questions

**OQ-PB-1 — Per-region hitzone multipliers (post-MVP).** MVP regions inherit the enemy's single defense stat (Rule 10) — all regions on an enemy break at the same rate for a given hit. A Monster Hunter-style per-region hitzone (some parts softer/harder to break) is a natural depth enrichment. *Owner: game-designer, post-MVP. Deferred — MVP simplicity.*

**OQ-PB-2 — Multi-target `target_profile` content (Vertical Slice/Alpha).** Rule 11 reserves the schema; when the first sweep/cleave move is authored it needs a balance pass (the anti-"kills-and-fully-breaks" rule) and multi-target selection UI. *Owner: systems-designer + ux-designer, when the feature is scheduled.*

**OQ-PB-3 — `ENRAGE_PER_BREAK = 0.15` playtest validation.** The value is calibrated analytically against Structure ranges; whether full-dismantle risk *feels* right across archetypes (glass cannon vs. tank) is a playtest question. *Owner: playtest / balance-check.*

**OQ-PB-4 — Should WILD enemies enrage, or bosses only?** Enrage is currently a global constant (all enemies). It may feel better restricted to bosses (where full dismantle is the meaningful capstone) while WILD fights stay simpler. A per-enemy `enrage_enabled` flag (Enemy DB) would allow this — a possible refinement if playtest shows WILD enrage is noise. *Owner: game-designer, playtest-gated.*

**OQ-PB-5 — Should breaking grant a tactical combat benefit (not just loot)?** In MVP, breaking a region only affects drops + enrage cost. A Monster Hunter-style "break the arm → it hits softer / loses a skill" layer would make breaking valuable *even for pure killing*, deepening the tactical layer. Deliberately **out of MVP scope** (it would complicate the clean "harvest = optional detour" model), but a strong candidate for a later depth pass. *Owner: game-designer, post-MVP.*
