# Enemy AI System

> **Status**: **Designed — pending fresh-session `/design-review`** (lean mode; specialists consulted for Formulas + Acceptance Criteria: systems-designer, qa-lead. CD-GDD-ALIGN skipped per lean — manual pillar check before production.)
> **Author**: Luan + Claude Code Game Studios agents (systems-designer: EAI-1 scoring; qa-lead: Acceptance Criteria)
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

**No formula in this section uses `floor()`/`ceil()`.** EAI-1 and all four sub-factors are pure weighted sums, float divisions, `clamp()`, discrete lookups, and integer comparisons — **no epsilon nudge and no python3 float scan is required** (stated explicitly so a reviewer does not flag the absence). The only `floor()` in the pipeline lives inside the **DF-1 preview call** (Damage Formula, registered range [1, 225], epsilon load-bearing and scanned 2026-07-10) — EAI-1 calls DF-1 as-is and adds no new floor. All worked-example arithmetic below is python3-verified.

### EAI-1 — Move Scoring (master formula)

`score(m) = w_dmg · damage_factor(m) + w_type · type_factor(m) + w_stat · status_factor(m) + w_lethal · lethal_factor(m)`

The AI selects `argmax(score)` over the enemy's `skills`; ties resolve by the injected seeded RNG (uniform among the tied set), then ascending skill index (Rule 3).

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Candidate move | `m` | move | — | One of the enemy's 2–4 `skills` |
| Damage weight | `w_dmg` | float | [0, ∞) | Profile weight on damage potential |
| Type weight | `w_type` | float | [0, ∞) | Profile weight on type-effectiveness |
| Status weight | `w_stat` | float | [0, ∞) | Profile weight on status application |
| Lethal weight | `w_lethal` | float | [0, ∞) | Profile weight on securing the kill |
| Output | `score(m)` | float | ≥ −0.5·w_type | Composite; higher = preferred |

**Output range:** unbounded above; minimum `−0.5·w_type` (a not-very-effective DAMAGE move, no status, no kill). No floor/ceil — pure weighted sum.

### EAI-1a — damage_factor

`df1_preview(m) = DF-1(A_path, D_path, T, crit_mult = 1.0)`
`damage_factor(m) = clamp(float(df1_preview) / float(H_cur), 0.0, 1.0)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Attacker stat | `A_path` | int | [0, 110] | Enemy `physical_power` (PHYSICAL move) or `energy_power` (ENERGY move) |
| Defender stat | `D_path` | int | [0, 182] | Player `armor` (PHYSICAL) or `resistance` (ENERGY) |
| Type multiplier | `T` | float | {0.75, 1.0, 1.5} | `m.element` vs player Core element (DF-1 / Part DB Rule 6) |
| Preview damage | `df1_preview` | int | [1, 225] | DF-1 output, `crit_mult = 1.0`, no MOVE-F1 power tier |
| Current Structure | `H_cur` | int | [1, 594] | Player active Symbot's `current_structure`, floored at 1 |
| Output | `damage_factor` | float | [0.0, 1.0] | Fraction of current HP removed; clamped at 1.0 when lethal/overkill |

**Output range:** [0.0, 1.0]. Reaches 1.0 whenever `df1_preview ≥ H_cur`. **GDScript note:** cast to float before dividing (`float(a)/float(b)`) — int/int truncates. Compute `df1_preview` **once** and reuse in `lethal_factor` (do not call DF-1 twice).

### EAI-1b — type_factor

`type_factor(m) = +1.0 if T = 1.5 (super-effective); 0.0 if T = 1.0 (neutral); −0.5 if T = 0.75 (not very effective)`

STATUS/SELF moves with no elemental damage (`T = null`) use `type_factor = 0.0`. The asymmetry (+1.0 reward vs −0.5 penalty) makes landing super-effective a strong pull without making off-type a crippling avoid.

### EAI-1c — status_factor

`status_factor(m) = 0.0 if m has no status_proc; 0.0 if proc's status is already active on the target; else STATUS_BASE_VALUE (1.0)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Proc status | `m.status_proc.status_id` | StringName \| null | {BURN, SHOCK, STAGGER, null} | The status the move applies |
| Active statuses | `target_active_statuses` | Set | ⊆ {BURN, SHOCK, STAGGER} | Statuses on the player active Symbot |
| Base value | `STATUS_BASE_VALUE` | float | [0.0, 2.0] | Tuning knob; MVP = **1.0** (equal for all three statuses) |
| Output | `status_factor` | float | {0.0, 1.0} | 1.0 for a useful new status; 0.0 otherwise |

**Reapplication discount:** setting the already-active case to 0.0 stops the AI wasting a turn refreshing a status (TBC newest-wins reapplication only extends duration). Post-MVP extension: per-status values (`SHOCK_VALUE`/`BURN_VALUE`/`STAGGER_VALUE`) if playtest shows one dominates.

### EAI-1d — lethal_factor

`lethal_factor(m) = 1 if df1_preview(m) ≥ H_cur; else 0`

Binary — overkill has no mechanical value in TBC, and `damage_factor` already encodes magnitude via the 1.0 clamp. Uses the same `df1_preview` as EAI-1a.

### Profile weights (Rule 5)

| Profile | `w_dmg` | `w_type` | `w_stat` | `w_lethal` | Character |
|---------|---------|----------|----------|------------|-----------|
| `AGGRESSIVE` | **3.0** | 0.2 | 0.0 | 1.0 | Bruiser — damage dominates; ignores status; modest kill bonus. Default fallback. |
| `TACTICAL` | 1.0 | **2.0** | **2.0** | 1.0 | Exploiter — type + status each as valuable as a full-damage turn. |
| `OPPORTUNIST` | 2.0 | 0.5 | 0.0 | **4.0** | Closer — strong damage; lethal bonus (4.0 on a {0,1} factor) beats any non-lethal combo. |

**Weight-scale rationale:** factors are bounded [−0.5, 1.0], so weights are the only comparable lever. `w_lethal = 4.0` on OPPORTUNIST guarantees it takes any available kill (4.0 exceeds its max non-lethal total of `2.0·1.0 + 0.5·1.0 = 2.5`). Keep AGGRESSIVE's `w_stat ≤ 0.5` or it applies status unpredictably.

### Worked examples (python3-verified)

Shared enemy: `physical_power = 70`, `energy_power = 40`; player `armor = 22`, `resistance = 22`. Target has no active status unless stated.

- **Move X** (Heavy Strike, PHYSICAL, neutral): `df1 = floor(70²/(70+22) × 1.0 + ε) = floor(53.26) = 53` *(floor 53 ≠ ceil 54 — discriminating)*.
- **Move Y** (Volt Jab, ENERGY, super-effective, SHOCK proc): `df1 = floor(40²/(40+22) × 1.5 + ε) = floor(38.71) = 38` *(floor 38 ≠ round 39 ≠ ceil 39 — discriminating)*.

**Example A — `H_cur = 80` (neither lethal).** X: dmg 53/80 = 0.663, type 0, status 0, lethal 0. Y: dmg 38/80 = 0.475, type 1.0, status 1.0, lethal 0.
- **AGGRESSIVE:** X = 3·0.663 = **1.99**, Y = 3·0.475 + 0.2 = **1.63** → **picks X** (raw damage; type bonus can't close the gap).
- **TACTICAL:** X = **0.66**, Y = 0.475 + 2.0 + 2.0 = **4.48** → **picks Y** (type + new status worth 4× the damage lead).

**Example B — `H_cur = 42` (X lethal, Y not).** X: dmg clamp(53/42) = 1.0, type 0, status 0, lethal 1. Y: dmg 38/42 = 0.905, type 1.0, status 1.0, lethal 0.
- **OPPORTUNIST:** X = 2·1.0 + 4·1 = **6.0**, Y = 2·0.905 + 0.5 = **2.31** → **picks X** (the kill — lethal bonus dominates).
- **TACTICAL:** X = 1.0 + 1.0 = **2.0**, Y = 0.905 + 2.0 + 2.0 = **4.91** → **picks Y** (sets up status/type *over* the available kill — surviving a TACTICAL enemy is a reward for its restraint).

**Example C — `H_cur = 42`, SHOCK already active (reapplication discount).** Y's `status_factor` → 0.0.
- **TACTICAL:** X = **2.0**, Y = 0.905 + 2.0 + 0.0 = **2.91** → **still picks Y** — the discount drops Y from 4.91 to 2.91, but Y's super-effective `type_factor` (2.0) alone still beats X. *The discount is a real factor but decisive only when the status is the move's sole edge: had Y been neutral-type, its score would fall to 0.905 and TACTICAL would flip to the lethal X.*

*(Example C corrected during authoring — a specialist draft mis-scored this as flipping to X; the python3 check showed Y still wins. Documented so the discount's actual behavior is not overstated.)*

## Edge Cases

- **EC-EAI-01 — Unknown/missing `ai_profile`.** The profile id resolves to no defined Profile: the AI **falls back to `AGGRESSIVE`** and logs a content error naming the enemy id + the bad profile id. Never crashes, never returns no move (Rule 2). *Verified by AC-EAI-08.*
- **EC-EAI-02 — Score tie across moves.** Two or more moves share the top score: the **injected seeded RNG** picks uniformly among the tied set (deterministic for a given seed). If no RNG is injected (isolated unit test), the tiebreak falls to the **lowest skill index** (stable). *Verified by AC-EAI-06.*
- **EC-EAI-03 — Single-skill enemy.** `skills.size() == 1`: `argmax` trivially returns the one move; no RNG is consumed. *Verified by AC-EAI-07.*
- **EC-EAI-04 — No "good" option (all factors ≈ 0).** Every move scores 0 or negative (e.g. all off-type, no status value, none lethal): the AI still returns a **legal move** via the tie path (seeded/index) — never `null`, never a move outside `skills`. *Verified by AC-EAI-07.*
- **EC-EAI-05 — Player Core element is null.** An elementless player Symbot (or no Core part): DF-1's EC-04 fallback makes `T = 1.0` for every move, so `type_factor = 0` for all — the AI scores purely on damage/status/lethal. No crash; the enemy simply cannot type-exploit an elementless target. *Verified by AC-EAI-05.*
- **EC-EAI-06 — Enemy has 0 in a move's power stat.** A move whose `damage_type` maps to an enemy stat of 0 (`A = 0`): DF-1's EC-01 floors it to `DAMAGE_FLOOR = 1`, so `damage_factor = 1/H_cur` (tiny but valid) and `lethal_factor = 0` (unless `H_cur = 1`). No divide-by-zero, no crash. *Verified by AC-EAI-04.*
- **EC-EAI-07 — `H_cur` divide guard.** `current_structure` is **floored at 1** for the `damage_factor` division. The AI is never invoked against a downed (Structure 0) target — TBC ends the battle before the enemy's next turn — but the floor prevents a divide-by-zero if the hook is ever called defensively. *Verified by AC-EAI-04.*
- **EC-EAI-08 — Malformed or boundary phase (Rule 6).** (a) A `phase_profile` that resolves to no Profile, or a `phase_threshold` outside `[0.0, 1.0]`: the AI **ignores the phase and uses the base profile**, logging a content error. (b) **Boundary:** the shift is strict `<` — at exactly `current/max == phase_threshold` the base profile is still used; the phase applies only *below* it. *Verified by AC-EAI-09.*
- **EC-EAI-09 — `SELF`-behavior move in `skills` (reserved path).** If an enemy authors a `SELF` move (self-repair/buff — not MVP content), it is scored on its own effect; with no MVP SELF-scoring authored it yields `damage_factor = type_factor = status_factor = lethal_factor = 0` (score ≈ 0), so it is **deprioritized under any offensive move**. No crash. *Advisory — verified by AC-EAI-10 (advisory).*

## Dependencies

### Upstream (Enemy AI reads from these)

| System | What Enemy AI reads | Status | Hard/Soft |
|--------|--------------------|--------|-----------|
| **Turn-Based Combat** | `battle_state` at enemy `ACTION_PENDING`: enemy `skills`/`stats`/`current`+`max` Structure; player active Symbot's Core element, defense stats, `current_structure`, active statuses; the injected seed | Approved | Hard |
| **Enemy Database** | `ai_profile`, `skills`, `stats`, `core_element` per enemy | Approved | Hard |
| **Damage Formula** | DF-1 read-only preview (pure function) for `damage`/`type`/`lethal` factors | Approved | Hard |
| **Move Database** | each skill's `behavior`, `damage_type`, `element`, `status_proc` | Approved | Hard |

### Downstream (these read from / realize this one)

| System | Interface | Status |
|--------|-----------|--------|
| **Combat UI** *(Not Started)* | which move the enemy chose + the type-effectiveness readout (Player Fantasy legibility) | Not Started |

**Interface this GDD exposes:** `request_move(battle_state) → Move` (TBC's AI hook) and `has_profile(id) → bool` (true for `AGGRESSIVE`/`TACTICAL`/`OPPORTUNIST`) — the lookup Enemy DB needs to validate `ai_profile` referentially.

### Errata obligations this GDD creates on Approved documents

Each errata'd doc needs a light re-review touch; source GDD + registry updated together.

1. **Turn-Based Combat** — un-defer **AC-TBC-INT-02** (the Enemy AI hook `request_move(battle_state)` is now defined: returns exactly one legal move, resolved through the normal pipeline like player input, no Heat/Energy gating). Update the Downstream "Enemy AI System" row status Not Started → Designed/Approved.
2. **Enemy Database** — the `ai_profile` referential-integrity check (**AC-ED-01(d)**, currently BLOCKED "until Enemy AI defines its profile schema and a `has_profile(id)` lookup") **un-blocks**: content validation may now reject an `ai_profile` outside `{AGGRESSIVE, TACTICAL, OPPORTUNIST}` via `EnemyAI.has_profile(id)`. Mark AC-ED-01(d) unblocked, citing this GDD.

*(Damage Formula and Move Database are read-only public contracts — Enemy AI adds itself as a downstream reader with no reciprocal change required.)*

### Bidirectionality

- **TBC** already lists Enemy AI downstream (Not Started) and states "Enemy AI … must list TBC when authored" — this GDD does; on approval TBC's row updates and AC-TBC-INT-02 un-defers.
- **Enemy Database** already carries the `ai_profile` field + ED4 obligation ("Enemy AI owns the profile schema") — this GDD defines it and `has_profile`; on approval Enemy DB AC-ED-01(d) un-blocks.
- **Combat UI** (Not Started) must list Enemy AI when authored.

## Tuning Knobs

### Profile weights (the primary tuning surface)

| Knob | Value | Safe Range | What Changing It Does |
|------|-------|------------|----------------------|
| `AGGRESSIVE` `(w_dmg,w_type,w_stat,w_lethal)` | `(3.0, 0.2, 0.0, 1.0)` | dmg 2–4 | The damage-max bruiser. Raise `w_dmg` to make it ignore everything but the biggest hit. Keep `w_stat ≤ 0.5` (warning 2). |
| `TACTICAL` `(w_dmg,w_type,w_stat,w_lethal)` | `(1.0, 2.0, 2.0, 1.0)` | type/stat 1.5–2.5 | The exploiter. `w_type`+`w_stat` set how far it sacrifices raw damage for matchup/status. At type/stat < ~1.3 it collapses toward AGGRESSIVE behavior. |
| `OPPORTUNIST` `(w_dmg,w_type,w_stat,w_lethal)` | `(2.0, 0.5, 0.0, 4.0)` | lethal 3–6 | The closer. `w_lethal` must exceed its max non-lethal score (2.5) or it stops reliably finishing (warning 1). |
| `STATUS_BASE_VALUE` | 1.0 | 0.5–2.0 | Base value of applying any new status. Effective pull = `w_stat × STATUS_BASE_VALUE`; tune this **or** `w_stat`, not both (warning 4). |
| `type_factor` reward / penalty | +1.0 / −0.5 | reward 0.75–1.5, penalty 0 to −1.0 | The super-effective bonus and off-type penalty. Keep reward > \|penalty\| (warning 3). |

### Per-enemy content values (authored in Enemy DB data, not global knobs)

| Value | Typical | Safe Range | Note |
|-------|---------|------------|------|
| `phase_threshold` (bosses only) | 0.40 | 0.25–0.50 | Structure fraction below which the phase profile takes over. Omitted on WILD enemies. Strict `<` (EC-EAI-08b). |
| `phase_profile` (bosses only) | `OPPORTUNIST` | any defined profile | The desperation profile. Typical pairing: `TACTICAL → OPPORTUNIST`. |

### Knob interaction warnings

1. **`w_lethal` must exceed the profile's max non-lethal score** or "secure the kill" fails *silently* — the enemy walks past lethal moves. For OPPORTUNIST that ceiling is `w_dmg·1.0 + w_type·1.0 = 2.5`; the authored 4.0 clears it. Re-check this inequality whenever any OPPORTUNIST weight changes.
2. **AGGRESSIVE `w_stat` ≤ 0.5** — above that, the "dumb bruiser" starts applying status, blurring its identity against TACTICAL.
3. **`type_factor` reward > |penalty|** — if the off-type penalty is as harsh as the super-effective reward, TACTICAL over-avoids off-type moves; keep the reward the larger magnitude.
4. **`STATUS_BASE_VALUE` × `w_stat` are one lever** — both scale the status pull. Change one; leaving both cranked double-counts and makes TACTICAL ignore damage entirely.
5. **`phase_threshold ∈ (0, 1)`** — at ≥ 1.0 the phase profile is always active (base profile never used); at ≤ 0 it never triggers. Keep bosses in 0.25–0.50 so the shift reads as a distinct "desperation" beat, not an immediate or never-seen change.

**Owned elsewhere — referenced, not duplicated:** DF-1 and its inputs (Damage Formula); the type chart Volt/Thermal/Kinetic (Part DB Rule 6); status durations/potencies (TBC-F3/F4/F5 + Passive DB); enemy `stats`/`skills`/`ai_profile` values (Enemy DB content).

## Visual/Audio Requirements

> **Ownership note**: The Enemy AI is a decision layer — it owns no assets. The requirements below are obligations on the presentation systems (Combat UI, Audio System, Art Bible) so the enemy's reasoning is legible (Player Fantasy).

**VA-1 — Move telegraph (binding).** When the enemy acts, Combat UI must clearly show *which move* it used (name/icon) and the **type-effectiveness result** of that move against the player's active Symbot ("Super effective!" / neutral / "Not very effective"), matching DF-1's readout. This is what lets the player reconstruct *why* the enemy chose it — the legibility the Player Fantasy depends on. *(Combat UI / Audio System.)*

**VA-2 — Phase-shift tell (advisory).** When a boss crosses its `phase_threshold` and swaps to its `phase_profile` (Rule 6), a legible beat — audio sting + a visual "desperate/enraged" state change — should mark it so the behavior shift reads as intentional, not random. *(Combat UI / Audio System / Art Bible.)*

**Audio intent:** a distinct enemy-move-use cue per element (Volt / Thermal / Kinetic) reusing the shared combat SFX palette; a super-effective hit already carries its emphasis from the damage layer.

## UI Requirements

Obligations on Combat UI (Not Started) — layout and interaction belong to that GDD.

1. **Enemy action readout.** After `request_move` resolves, show the enemy's chosen move (name/icon) and its type-effectiveness vs the player active Symbot. The Player Fantasy's legibility promise ("of course it used Volt — I'm Thermal") lives here (mirrors VA-1).
2. **Boss phase indicator.** When a boss is below its `phase_threshold`, a persistent "desperate/enraged" state marker communicates the behavior shift (mirrors VA-2).
3. **No internal-score exposure.** The AI's numeric scores, weights, and profile id are **not** shown — legibility comes from the observable move + matchup, not from surfacing the heuristic (mirrors the Drop System hiding pity counters).

> **📌 UX Flag — Enemy AI**: this system places enemy-action-readout, type-effectiveness feedback, and boss-phase-indicator requirements on Combat UI. In Pre-Production, run `/ux-design` for the Combat UI **before** writing epics; stories should cite the resulting `design/ux/` spec, not this GDD directly.

## Acceptance Criteria

**Tags:** BLOCKING (automated test, gates story completion) · ADVISORY · DEFERRED (needs a Not-Started system / integration). **Test types:** Unit (GUT, `tests/unit/enemy_ai/`) · Content-Validation (offline linter) · Integration. All RNG is **injected** (a seeded `RandomNumberGenerator` parameter), never global `randf()`; "no-RNG" = that parameter is `null`. Fixtures use the shared enemy (`physical_power=70`, `energy_power=40`; player `armor=22`, `resistance=22`) unless stated. All fixture numbers are python3-verified.

**AC-EAI-01** (BLOCKING, Unit): **Profile discrimination on the same move-set (Example A).** GIVEN Move X (PHYSICAL, T=1.0, no status), Move Y (ENERGY, T=1.5, SHOCK proc), `H_cur=80`, no active statuses, no-RNG. WHEN `request_move` runs with AGGRESSIVE, then TACTICAL. THEN AGGRESSIVE → **X** (X=1.99, Y=1.63); TACTICAL → **Y** (X=0.66, Y=4.48). FAIL: either returns the opposite move or null. Discriminator: same two moves, opposite picks — an always-highest-damage impl passes AGGRESSIVE but fails TACTICAL; an always-super-effective impl fails AGGRESSIVE.

**AC-EAI-02** (BLOCKING, Unit): **OPPORTUNIST takes the kill; TACTICAL declines it (Example B).** GIVEN `H_cur=42`, no active statuses, no-RNG. WHEN OPPORTUNIST, then TACTICAL. THEN OPPORTUNIST → **X** (6.0 vs 2.31; `lethal_factor=1` since df1(X)=53 ≥ 42); TACTICAL → **Y** (4.91 vs 2.0; X is lethal but `w_lethal=1.0` can't overcome Y's type+status). FAIL: OPPORTUNIST skips the kill, or TACTICAL takes it. Discriminator: an always-take-lethal impl passes OPPORTUNIST but fails TACTICAL.

**AC-EAI-03** (BLOCKING, Unit): **Factor arithmetic + floor-not-ceil preview (Example A intermediates).** THEN Move X: `df1_preview=53` (floor, not ceil 54), `damage_factor=53/80=0.6625`, `type_factor=0.0`, `status_factor=0.0`, `lethal_factor=0`. Move Y: `df1_preview=38` (floor, not round/ceil 39), `damage_factor=0.475`, `type_factor=1.0`, `status_factor=1.0`, `lethal_factor=0`. FAIL: df1(X)=54, df1(Y)=39, or integer-division truncation of `damage_factor`. Discriminator: catches ceil-instead-of-floor in the DF-1 call path and GDScript int/int truncation.

**AC-EAI-04** (BLOCKING, Unit): **A=0 and H_cur=1 guards (EC-EAI-06, EC-EAI-07).** GIVEN enemy `physical_power=0`, player `armor=10`, `H_cur=1`, T=1.0, no-RNG. THEN `df1_preview = DAMAGE_FLOOR = 1` (no crash/zero/negative); `damage_factor = clamp(1/1) = 1.0` (float divide, no div-by-zero); `lethal_factor = 1`; a legal non-null move returns. FAIL: divide-by-zero, `df1_preview=0`, or `damage_factor` NaN/inf. Discriminator: two independent guards (A=0 in DF-1, H_cur floor-at-1) — either absent faults.

**AC-EAI-05** (BLOCKING, Unit): **Null player Core element (EC-EAI-05).** GIVEN player Core element = null, Moves X/Y, `H_cur=80`, no-RNG. THEN `type_factor = 0.0` for every move (T=1.0 fallback, DF-1 EC-04); no crash/null-deref; AGGRESSIVE returns the higher-damage move (X, df1 53 > 38). FAIL: any non-zero `type_factor`, an exception on null Core access, or wrong pick. Discriminator: catches null-deref and the nonsense "exploit a null type" result.

**AC-EAI-06** (BLOCKING, Unit): **Tie-breaking (EC-EAI-02).** GIVEN two moves that score identically. (a) With the same seeded RNG (reset between calls) → both calls return the same move; across ≥2 distinct seeds, picks may differ (proves the RNG is consulted). (b) With no-RNG → the **lowest skill index** returns. FAIL: same seed → different moves; the tiebreak calls global `randf()`; no-RNG returns a higher-index move. Discriminator: catches global-RNG usage, missing seed injection, and descending-index tiebreak.

**AC-EAI-07** (BLOCKING, Unit): **Single-skill & all-zero paths (EC-EAI-03, EC-EAI-04).** (a) `skills.size()==1` → that move returns, **RNG call count = 0** (fast path, no tie branch). (b) every move scores ≤ 0 → a non-null move in `skills` returns. FAIL: null returned, a move outside `skills`, or RNG consumed in the single-skill case. Discriminator: catches null-on-degenerate and needless RNG consumption.

**AC-EAI-08** (BLOCKING, Unit): **Unknown `ai_profile` → AGGRESSIVE fallback (EC-EAI-01).** GIVEN `ai_profile="BERSERKER"`. THEN the move matches AGGRESSIVE's pick for the same inputs; **exactly one** content error logged containing the enemy id + `"BERSERKER"`; no other error/warning; no exception. FAIL: no error (silent), two errors (per-invocation spam), error omits an id, or a crash. Discriminator: catches silent fallback, noisy fallback, and crash-on-unknown.

**AC-EAI-09** (BLOCKING, Unit): **Phase shift — strict `<` boundary + malformed fallback (EC-EAI-08).** GIVEN a boss: base TACTICAL, `phase_threshold=0.40`, `phase_profile=OPPORTUNIST`. (a) `current/max == 0.40` exactly → **base TACTICAL** used (strict `<` not satisfied) — verify the pick matches TACTICAL's argmax, not OPPORTUNIST's. (b) `= 0.39` → **OPPORTUNIST** used. (c) `phase_profile="UNDEFINED_PROFILE"` at 0.39 → base TACTICAL used, one content error naming the bad id, no crash. FAIL: phase active at equality (`≤` bug), base active below threshold, or crash on malformed phase. Discriminator: the one-character `≤`-vs-`<` boundary bug.

**AC-EAI-10** (ADVISORY, Unit): **SELF move deprioritized (EC-EAI-09).** GIVEN one SELF-behavior move + one DAMAGE move (A>0), any profile, any `H_cur>0`. THEN the DAMAGE move is selected (SELF scores 0 on all four factors; DAMAGE scores >0 on `damage_factor`). FAIL: the SELF move is selected over a positive-scoring DAMAGE move. Discriminator: catches a SELF move inadvertently receiving a `type_factor` boost. (Advisory — SELF content is not MVP-authored.)

**AC-EAI-11** (BLOCKING, Unit): **Reapplication discount (Example C — corrected).** GIVEN `H_cur=42`, **SHOCK already active** on the player, no-RNG, TACTICAL. THEN Move Y `status_factor = 0.0` (discounted); Y score `= 0.905 + 2.0 + 0.0 + 0 = 2.91`; X score `= 1.0 + 0 + 0 + 1.0 = 2.0`; TACTICAL returns **Y** (2.91 > 2.0). FAIL: Y's `status_factor = 1.0` when SHOCK is active (discount missing); or TACTICAL returns X (Y still wins on its type edge — X only wins if the status were Y's *sole* advantage). Discriminator: an impl that discounts *and* mis-scores type passes the discount check but fails the final pick. *(Fixture corrected during authoring from a mis-scored specialist draft — do not revert.)*

**AC-EAI-12** (BLOCKING, Unit): **Determinism (Rule 3).** GIVEN any fixed `(battle_state, profile, seed)`. WHEN `request_move` runs twice, state unmutated. THEN both return the same skill index. FAIL: call-internal random state bleeds across invocations, or same seed → different result. Discriminator: catches shared global RNG state and hidden mutable state — load-bearing for replay/save/deterministic tests.

**AC-EAI-13** (DEFERRED, Integration): **TBC hook end-to-end (discharges TBC AC-TBC-INT-02).** GIVEN a live battle at enemy `ACTION_PENDING`. WHEN TBC calls `request_move(battle_state)`. THEN exactly one move returns, resolved through TBC's normal pipeline, with **no Heat/Energy gating** applied to selection. FAIL: null, a move outside `skills`, or energy-cost filtering. *Activate when: TBC's `ACTION_PENDING` state is implemented.*

**AC-EAI-14** (BLOCKING, Content-Validation): **`has_profile(id)` (unblocks Enemy DB AC-ED-01d).** THEN `has_profile` → true for `"AGGRESSIVE"`/`"TACTICAL"`/`"OPPORTUNIST"`; false for `"BERSERKER"`, `""`, and `null` (no crash). FAIL: an MVP profile returns false, an unknown returns true, or null crashes. Discriminator: an always-true stub passes positives, fails negatives; an always-false stub fails all.

### EC ↔ AC Coverage

EC-01→08, EC-02→06, EC-03→07, EC-04→07, EC-05→05, EC-06→04, EC-07→04, EC-08→09, EC-09→10(ADVISORY). **Rule/formula coverage:** EAI-1→03; damage_factor→03/04; type_factor→03/05; status_factor→11; lethal_factor→02; profile weights→01/02; argmax+tiebreak→06/07; determinism→12; phase→09; fallback→08; `has_profile`→14; TBC integration→13(DEFERRED). **14 ACs: 12 BLOCKING (11 Unit + 1 Content-Validation) / 1 ADVISORY / 1 DEFERRED.** No untestable ("feels-smart") criteria — every AC has a discriminating fixture.

**QA carry-forwards:** (1) AC-EAI-03's floor-discrimination overlaps Damage Formula's own DF-1 tests — belt-and-suspenders if those enforce 53/38, sole guard otherwise. (2) AC-EAI-11 must keep the corrected THEN clause (TACTICAL picks Y). (3) AC-EAI-06 requires a ≥2-seed variability check to prove the RNG is actually consulted, not bypassed.

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-EAI-1 | **Per-status `status_factor` differentiation.** MVP treats Burn/Shock/Stagger as equal value (`STATUS_BASE_VALUE = 1.0`). Playtest may show one status is strictly stronger for the enemy (e.g. Shock's initiative denial), warranting per-status values. | systems-designer / balance | TACTICAL move-choice nuance; post-MVP |
| OQ-EAI-2 | **Multi-phase bosses.** MVP allows one `phase_threshold` per profile. A boss might want two shifts (e.g. 60% and 30%). Extend the schema if desired. | game-designer | Boss identity depth; post-MVP schema extension |
| OQ-EAI-3 | **Weight tuning at playtest.** The profile weights are first-pass values chosen to satisfy the discriminating examples. Does TACTICAL *declining a kill* to set up status feel smart or exploitable? Does OPPORTUNIST's phase shift read as menacing? **The #1 feel watch.** | playtest / balance | The core feel of every enemy encounter |
| OQ-EAI-4 | **WILD phases?** MVP restricts the phase mechanic to bosses (WILD omit it). Confirm at content authoring whether any WILD enemy should have a phase. | game-designer | WILD variety vs. simplicity |
| OQ-EAI-5 | **SELF-move scoring value model (reserved).** If post-MVP enemies get self-repair/buff moves, the SELF scoring path (currently ≈ 0) needs a real model (e.g. score self-repair by missing Structure). | systems-designer | Post-MVP enemy variety |
| OQ-EAI-6 | **Lookahead depth.** MVP AI is single-turn — it does not model the player's likely response. A smarter boss could weight setup moves by expected follow-up. **Deliberately out of MVP scope** (legibility > depth — an unpredictable enemy teaches nothing, per Player Fantasy). | game-designer / ai-programmer | Post-MVP boss sophistication |
