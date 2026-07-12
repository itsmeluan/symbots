# Enemy AI System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 1 (Engineer, Don't Collect)

## Overview

The **Enemy AI System** is the decision layer that chooses what an enemy does on its turn. In Symbots' MVP a battle is one enemy versus the player's one active Symbot, and an enemy's only action is to use one of its **2–4 moves** — so the Enemy AI answers exactly one question each enemy turn: *which move?* It resolves the `ai_profile` reference that every Enemy Database entry carries (Enemy DB ED4) into a concrete move-selection behavior, and hands Turn-Based Combat exactly one legal move when TBC requests one at the enemy's `ACTION_PENDING` state (the TBC AI hook). It holds no combat state of its own — it reads the visible battle state TBC provides, scores each of the enemy's available moves, and returns the best one.

The system is a **scored heuristic**: each candidate move earns a score from weighted factors — type-effectiveness against the player's active Symbot, raw damage potential, the value of a status it would apply, and whether it can secure a kill this turn — and the weights come from the enemy's `ai_profile` (an AGGRESSIVE bruiser weights damage; a TACTICAL enemy weights type-exploitation and status). The highest-scoring move wins; a seeded RNG breaks ties deterministically. This makes enemies **legible opponents that reward player knowledge**: a player who understands type matchups and status threats can predict and counter enemy behavior through better build choices (Pillar 1), and an enemy that actively exploits weaknesses makes surviving-while-harvesting a real decision rather than a formality (Pillar 2). Without this system, enemy turns would be random or scripted noise, and the "can I survive the extra turns to break the arm?" tension at the heart of the game would collapse.

## Player Fantasy

The player never thinks "the enemy AI scored its moves." They think: *"It's going to hit my Thermal core with that Volt move again — I need to switch or eat it."*

The Enemy AI's fantasy is **the opponent that reads you back**. In a build-craft game the player spends the pre-fight in the Workshop making a hypothesis: this Symbot, these parts, this element. Combat is where the hypothesis meets resistance — and an enemy that picks moves at random provides no resistance worth respecting. The fantasy the Enemy AI serves is the **worthy opponent**: an enemy that notices your Thermal Symbot is weak to its Volt move and leans on it, that lands a Shock to slow you when it's losing the initiative race, that goes for the kill when you're one hit from down. When the player counters — swapping to a Kinetic Symbot that resists the Volt, or breaking the enemy's weapon arm to blunt its damage — and *watches the enemy's behavior change in response*, the loop pays off: the build was tested against a thinking opponent and won.

Crucially, the enemy is **legible, not unfair**. The player should always be able to reconstruct *why* the enemy did what it did ("of course it used the Volt move — I'm Thermal"), because that legibility is what makes the counter-play learnable. An enemy that surprises you with a move you could not have predicted teaches nothing; an enemy whose logic you can read teaches you to build better. The two named bosses are where this peaks: a boss that exploits your weakness relentlessly turns "did I bring the right build?" into the fight's central question — the harvest dilemma sharpened by an opponent that punishes a lazy build.

This is delivered jointly: the Enemy AI *decides*, but the player only *feels* the decision through Combat UI (which move fired, the type-effectiveness readout) and the damage they take. The AI builds the intent; the presentation layer makes it legible.

## Detailed Design

### Core Rules

**Rule 1 — The single decision.** At the enemy's `ACTION_PENDING` state, TBC calls `request_move(battle_state)` (discharges AC-TBC-INT-02). The Enemy AI returns **exactly one legal move** from the enemy's `skills` pool. An enemy has no switch, flee, or item action, and (TBC Rule 8) **no Heat/Energy gating** — every skill is always affordable, so the AI never filters by cost. The chosen move resolves through TBC's normal pipeline exactly as player input would.

**Rule 2 — Profile resolution (owns Enemy DB ED4).** Each enemy's `ai_profile: StringName` (Enemy DB) resolves here to a **Profile** — a named preset of scoring weights. MVP defines three (Rule 5). An unknown or missing `ai_profile` is a **content error**: the AI logs it naming the enemy + profile id and **falls back to `AGGRESSIVE`** (fail-safe — never crashes, never returns no move).

**Rule 3 — Scored selection.** For each move `m` in the enemy's `skills`, the AI computes `score(m)` = the profile-weighted sum of the scoring factors (Rule 4 / Formula EAI-1). It selects `argmax(score)`. Ties are broken by an **injected seeded RNG** (uniform pick among the tied set), then — if the RNG is absent in a test — by ascending skill index (stable fallback). The AI is a **pure function of `(battle_state, profile, seed)`** — identical inputs yield an identical move (required for testable ACs).

**Rule 4 — Scoring factors.** Every move is scored on four normalized factors (defined numerically in Formulas):
- **`damage_factor`** — the move's expected damage this turn, previewed through **DF-1** (the same pure call TBC uses: enemy stats as attacker, the move's `damage_type`/`element`, the player active Symbot's defense stat + Core element). Normalized against the target's current Structure.
- **`type_factor`** — a bonus when the move's element is **super-effective** (×1.5) against the player Core element, zero at neutral, negative at ×0.75. This is the "exploit your weakness" lever.
- **`status_factor`** — the value of a `STATUS` move's rider (Burn/Shock/Stagger), **discounted to ~0 if the target already carries that status** (reapplication only refreshes duration — TBC newest-wins — so it is rarely worth a turn).
- **`lethal_factor`** — a large bonus if the move's previewed damage **≥ the target's current Structure** (securing the kill this turn). This is what makes OPPORTUNIST finish low targets.

**Rule 5 — MVP profiles (weight presets).** Each profile is a weight vector over the four factors:

| Profile | damage | type | status | lethal | Character |
|---------|--------|------|--------|--------|-----------|
| `AGGRESSIVE` | **high** | low | ~0 | med | Bruiser — hits hard, ignores finesse. Default fallback. |
| `TACTICAL` | med | **high** | **high** | med | Exploiter — leans on type advantage and status setup. Boss/elite. |
| `OPPORTUNIST` | high | med | low | **very high** | Closer — plays for damage, spikes hard to secure kills. |

(Exact weight numbers → Formulas / Tuning Knobs.)

**Rule 6 — Optional phase shift (stateless).** A profile MAY declare `phase_threshold` (a Structure fraction, e.g. `0.40`) and a `phase_profile`. When the enemy's `current_structure / max_structure < phase_threshold`, the AI scores with `phase_profile`'s weights instead (e.g. a boss `TACTICAL → OPPORTUNIST` at 40%). This reads only battle state TBC already exposes (current/max Structure) — **no persistent AI state**. WILD enemies omit both fields (no phase). At most one threshold per profile in MVP.

**Rule 7 — Targeting is implicit.** The player fields exactly one active Symbot (TBC Rule 1), so offensive moves (`DAMAGE`/`STATUS`) target it with no choice to make; the AI selects a *move*, not a target. A `SELF`-behavior move (e.g. a self-repair/buff) targets the enemy and is scored on its own effect — **defined for extensibility but MVP enemy content authors offensive skills only** (a reserved path, not required content).

**Rule 8 — Fail-safes.** The AI never returns `null`, never returns a move outside the enemy's `skills`, and never returns a move requiring a target that does not exist. Enemy DB guarantees `skills.size() ≥ 1` (EC-ED-10), so a valid move always exists; a fully-degenerate score tie resolves via seeded RNG (Rule 3).

### States and Transitions

The Enemy AI has **no state machine and no persistent state of its own** — it is a pure function invoked once per enemy turn. The only "state" it observes is the **phase** (Rule 6), which is *derived* each call from the enemy's current Structure fraction (owned by TBC), not stored.

| Invocation | Input | Output |
|------------|-------|--------|
| `request_move(battle_state)` at enemy `ACTION_PENDING` | Visible battle state (enemy `skills`/`stats`/`current_structure`/`max_structure`; player active Symbot's Core element, defense stats, `current_structure`, active statuses); resolved profile; injected seed | Exactly one move from `skills` (Rule 1) |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Turn-Based Combat** | ← called by | `request_move(battle_state)` at enemy `ACTION_PENDING`; returns one legal move, resolved like player input (discharges AC-TBC-INT-02). Reads visible battle state; respects no-Heat/Energy gating (TBC Rule 8). |
| **Enemy Database** | ← reads | `ai_profile` (→ Profile, discharges ED4), `skills`, `stats`, `core_element`. Profile ids resolve here. |
| **Damage Formula** | ← previews | Calls **DF-1** read-only to preview each move's expected damage for `damage_factor`/`lethal_factor`/`type_factor` (no state change — DF-1 is a pure function). |
| **Move Database** | ← reads | Each skill's `behavior`, `damage_type`, `element`, `status_proc` — the raw material the factors score. |
| **Combat UI** *(Not Started)* | → surfaced by | Which move the enemy chose + the type-effectiveness readout, so the enemy's logic is legible (Player Fantasy). The AI decides; UI communicates. |

*Provisional: Combat UI is Not Started. TBC / Enemy DB / Damage Formula / Move DB are all Approved — this GDD discharges TBC's AC-TBC-INT-02 and Enemy DB's ED4 obligation.*

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
