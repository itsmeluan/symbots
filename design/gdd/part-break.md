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
