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

**Rule 2 — Target selection is free (no turn cost).** A DAMAGE-behavior move aimed at the ENEMY carries a **sub-target**: `STRUCTURE` or a specific un-broken `region_id`. Choosing the sub-target is part of choosing the move — it consumes no extra action, no extra Energy, no extra Heat. This resolves the region sub-targeting layer TBC deferred (Move Contract `targeting` = `ENEMY`; region sub-targeting is Part-Break's). Non-DAMAGE moves (STATUS / REPAIR / SCAN / UTILITY) and SELF moves have no sub-target. The Basic Attack (TBC built-in) may sub-target like any DAMAGE move; its `break_bias` is `BALANCED`.

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
