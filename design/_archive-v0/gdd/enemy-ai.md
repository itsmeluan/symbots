# Enemy AI System

> **Status**: **Approved — 2026-07-12 (2nd full-panel `/design-review`, fresh session — NEEDS REVISION → fixed & fix-confirmed same session, commit-to-Approve ruling)** (game-designer, systems-designer, ai-programmer, qa-lead + creative-director). The 2026-07-12 1st-pass approval was **reopened**: the re-review found two confirmed spec-wrong gaps in the flagship kill-securing fix itself. Both fixed this session (commit-to-Approve on fix-confirmation): **(B1)** `df1_preview` now applies **MOVE-F1** (power-tier multiplier) — previously it previewed DF-1 alone, so the kill-securing invariant silently failed for any non-STANDARD move tier (a SIGNATURE kill was under-previewed 40% and declined); **(B2)** the kill-securing invariant is corrected to `w_lethal ≥ w_type + w_stat · STATUS_BASE_VALUE` (was `w_lethal ≥ w_type + w_stat`, valid only at SBV=1.0) and STATUS_BASE_VALUE safe range narrowed [0.5, 2.0]→[0.5, 1.5] (SBV>1.5 re-opened the exploit). Also: RNG contract bound to an injected **seed int** + fresh per-call RNG (B3); AC-EAI-04 split into 4 independent guard sub-cases (B4); AC-EAI-09/12 GDScript traps closed — float phase-division + write-intercepting determinism mock (B5). 1st-pass changes retained: TACTICAL `w_lethal` 1.0→5.0; data-driven profile storage (Rule 2); EC-EAI-10. All example arithmetic python3-verified.
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

**Rule 2 — Profile resolution (owns Enemy DB ED4).** Each enemy's `ai_profile: StringName` (Enemy DB) resolves here to a **Profile** — a named preset of scoring weights. MVP defines three (Rule 5). **Profiles are data-driven, not hardcoded** (coding standard: gameplay values live in external config): the three presets are authored in an `ai_profiles` resource (a Godot `Resource`/`.tres` — a registry keyed by `StringName` → `{w_dmg, w_type, w_stat, w_lethal, phase_threshold?, phase_profile?}`), loaded once at startup; changing a weight is a data edit, never a code edit. `has_profile(id)` (see Dependencies) tests membership in this registry. An unknown or missing `ai_profile` is a **content error**: the AI logs it naming the enemy + profile id and **falls back to `AGGRESSIVE`** (fail-safe — never crashes, never returns no move).

**Rule 3 — Scored selection.** For each move `m` in the enemy's `skills`, the AI computes `score(m)` = the profile-weighted sum of the scoring factors (Rule 4 / Formula EAI-1). It selects `argmax(score)`. Ties are broken by a **seeded RNG** (uniform pick among the tied set), then — if no seed is supplied in a test — by ascending skill index (stable fallback). **RNG contract (normative):** `request_move` receives an **injected integer `seed`** (`int`, or a sentinel `null`/absent meaning "no-RNG, use the index fallback"), and constructs a **fresh `RandomNumberGenerator` seeded with that value at the start of each call**. It never shares a persistent RNG instance across calls and never touches global `randf()`. This is what makes the AI a **pure function of `(battle_state, profile, seed)`** — no RNG state bleeds between calls, so identical inputs yield an identical move (required for testable ACs, and immune to the cross-call sequence-consumption hazard a shared instance would carry). The uniform pick is `rng.randi_range(0, tied_count − 1)` on that fresh instance.

**Rule 4 — Scoring factors.** Every move is scored on four normalized factors (defined numerically in Formulas):
- **`damage_factor`** — the move's expected damage this turn, previewed through the **DF-1 → MOVE-F1** composition (the same pipeline TBC resolves the hit through: enemy stats as attacker, the move's `damage_type`/`element` and `power_tier`, the player active Symbot's **effective post-SYN-F4 defense stat** + Core element). Previewing DF-1 without MOVE-F1's power-tier multiply, or against raw instead of effective defense, desyncs the prediction from the real hit — see EAI-1a and the Damage Formula interaction row. Normalized against the target's current Structure.
- **`type_factor`** — a bonus when the move's element is **super-effective** (×1.5) against the player Core element, zero at neutral, negative at ×0.75. This is the "exploit your weakness" lever.
- **`status_factor`** — the value of a `STATUS` move's rider (Burn/Shock/Stagger), **discounted to ~0 if the target already carries that status** (reapplication only refreshes duration — TBC newest-wins — so it is rarely worth a turn).
- **`lethal_factor`** — a large bonus if the move's previewed damage **≥ the target's current Structure** (securing the kill this turn). This is what makes OPPORTUNIST finish low targets.

**Rule 5 — MVP profiles (weight presets).** Each profile is a weight vector over the four factors:

| Profile | damage | type | status | lethal | Character |
|---------|--------|------|--------|--------|-----------|
| `AGGRESSIVE` | **high** | low | ~0 | med | Bruiser — hits hard, ignores finesse. Default fallback. |
| `TACTICAL` | med | **high** | **high** | **high** | Exploiter — leans on type advantage and status setup, but never passes up a securable kill. Boss/elite. |
| `OPPORTUNIST` | high | med | low | **very high** | Closer — plays for damage, spikes hard to secure kills. |

(Exact weight numbers → Formulas / Tuning Knobs.)

**Rule 6 — Optional phase shift (stateless).** A profile MAY declare `phase_threshold` (a Structure fraction, e.g. `0.40`) and a `phase_profile`. When the enemy's `current_structure / max_structure < phase_threshold`, the AI scores with `phase_profile`'s weights instead (e.g. a boss `TACTICAL → OPPORTUNIST` at 40%). This reads only battle state TBC already exposes (current/max Structure) — **no persistent AI state**. WILD enemies omit both fields (no phase). At most one threshold per profile in MVP.

**Rule 7 — Targeting is implicit.** The player fields exactly one active Symbot (TBC Rule 1), so offensive moves (`DAMAGE`/`STATUS`) target it with no choice to make; the AI selects a *move*, not a target. A `SELF`-behavior move (e.g. a self-repair/buff) targets the enemy and is scored on its own effect — **defined for extensibility but MVP enemy content authors offensive skills only** (a reserved path, not required content).

**Rule 8 — Fail-safes.** The AI never returns `null`, never returns a move outside the enemy's `skills`, and never returns a move requiring a target that does not exist. Enemy DB guarantees `skills.size() ≥ 1` (EC-ED-10), so a valid move always exists; a fully-degenerate score tie resolves via seeded RNG (Rule 3).

### States and Transitions

The Enemy AI has **no state machine and no persistent state of its own** — it is a pure function invoked once per enemy turn. The only "state" it observes is the **phase** (Rule 6), which is *derived* each call from the enemy's current Structure fraction (owned by TBC), not stored.

| Invocation | Input | Output |
|------------|-------|--------|
| `request_move(battle_state)` at enemy `ACTION_PENDING` | Visible battle state (enemy `skills`/`stats`/`current_structure`/`max_structure`; player active Symbot's Core element, **effective post-SYN-F4 defense stats**, `current_structure`, active statuses); resolved profile; injected integer `seed` (or `null` = no-RNG) | Exactly one move from `skills` (Rule 1) |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Turn-Based Combat** | ← called by | `request_move(battle_state)` at enemy `ACTION_PENDING`; returns one legal move, resolved like player input (discharges AC-TBC-INT-02). Reads the **post-turn-start snapshot** — TBC ticks statuses at turn start (TBC Rule 4) *before* `ACTION_PENDING`, so the `active_statuses` the AI scores already reflect this turn's ticks (a status that expired at the enemy's own turn-start is correctly absent for `status_factor`). This snapshot moment is fixed by TBC's turn order and is part of the integration contract. Respects no-Heat/Energy gating (TBC Rule 8). |
| **Enemy Database** | ← reads | `ai_profile` (→ Profile, discharges ED4), `skills`, `stats`, `core_element`. Profile ids resolve here. |
| **Damage Formula + Move DB** | ← previews | Calls **DF-1** read-only, then applies **MOVE-F1** (`× power_mult` from the move's `power_tier`) to preview each move's *actual* expected damage for `damage_factor`/`lethal_factor` (`type_factor` reads `T` alone). The preview MUST mirror the pipeline TBC deals (DF-1 → MOVE-F1 → …) or `lethal_factor` mis-fires (B1). **DF-1 must be side-effect-free and injectable** (static/pure or fresh instance) — the determinism guarantee (AC-EAI-12) and single-call rule (AC-EAI-15) depend on it; if DF-1's own GDD does not already assert purity, this is a hard precondition on integration. **Effective-stats contract:** the preview must use the **effective post-SYN-F4 defense** TBC will use for the real hit (the same value TBC passes into DF-1), not the player's raw `final_stat` — otherwise `lethal_factor` under-predicts against a player carrying synergy defense bonuses. DF-1 is invoked **once per move** and cached; the MOVE-F1 multiply reuses that cached output (not a second DF-1 call). |
| **Move Database** | ← reads | Each skill's `behavior`, `damage_type`, `element`, `status_proc` — the raw material the factors score. |
| **Combat UI** *(Not Started)* | → surfaced by | Which move the enemy chose + the type-effectiveness readout, so the enemy's logic is legible (Player Fantasy). The AI decides; UI communicates. |

*Provisional: Combat UI is Not Started. TBC / Enemy DB / Damage Formula / Move DB are all Approved — this GDD discharges TBC's AC-TBC-INT-02 and Enemy DB's ED4 obligation.*

## Formulas

**EAI-1 and its four sub-factors add no `floor()`/`ceil()` of their own** — they are pure weighted sums, float divisions, `clamp()`, discrete lookups, and integer comparisons, so **no epsilon nudge or python3 float scan is required on the scoring layer** (stated explicitly so a reviewer does not flag the absence). The `floor()`s in the pipeline live inside the **damage-preview call** (`df1_preview`, EAI-1a) — which composes **DF-1** (Damage Formula, epsilon load-bearing, scanned 2026-07-10) with **MOVE-F1** (Move DB power-tier multiply, epsilon load-bearing, scanned 2026-07-10). EAI-1 calls that composed preview as-is and adds no new floor. Because `df1_preview` now includes MOVE-F1, its worked values are python3-verified with the epsilon nudge applied at *both* floor steps. All worked-example arithmetic below is python3-verified.

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

`df1_raw(m)     = DF-1(A_path, D_path, T, crit_mult = 1.0)`
`df1_preview(m) = max(DAMAGE_FLOOR, floor(df1_raw(m) × power_mult(m) + EPSILON))`   *(MOVE-F1 applied)*
`damage_factor(m) = clamp(float(df1_preview) / float(H_cur), 0.0, 1.0)`

`df1_preview` is the enemy move's **actual expected damage this turn** — the same composition TBC deals: **DF-1 → MOVE-F1**. It **must** include MOVE-F1's `power_mult` (from the move's `power_tier`, Move DB Rule 3), because TBC applies it before the hit lands. Previewing DF-1 alone under-counts a HEAVY (×1.20) / SIGNATURE (×1.40) move and over-counts a BASIC (×0.70) / LIGHT (×0.80) move — which would make `lethal_factor` fire late for heavy hits and early for light ones, silently breaking the kill-securing invariant (this was the B1 defect fixed in the 2026-07-12 re-review). A `STANDARD`-tier move has `power_mult = 1.00`, so `df1_preview = df1_raw` for STANDARD moves (why the STANDARD-tier worked examples below are unchanged). `EPSILON = 0.0001` and `DAMAGE_FLOOR = 1` are the same constants MOVE-F1 uses (Move DB); the nudge is load-bearing at this floor exactly as it is in MOVE-F1's own GDD.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Attacker stat | `A_path` | int | [0, 110] | Enemy `physical_power` (PHYSICAL move) or `energy_power` (ENERGY move) |
| Defender stat | `D_path` | int | [0, 182] | Player `armor` (PHYSICAL) or `resistance` (ENERGY) — **effective (post-SYN-F4) value TBC will use for the actual hit** (see Interactions: the preview must use the same effective defense TBC resolves with, or `lethal_factor` mis-predicts when the player has synergy defense bonuses) |
| Type multiplier | `T` | float | {0.75, 1.0, 1.5} | `m.element` vs player Core element (DF-1 / Part DB Rule 6) |
| Power multiplier | `power_mult(m)` | float | {0.70, 0.80, 1.00, 1.20, 1.40} | MOVE-F1 tier multiplier from `m.power_tier` (Move DB Rule 3); STANDARD = 1.00 |
| Raw DF-1 output | `df1_raw` | int | [1, 225] | DF-1 output, `crit_mult = 1.0` (pre-MOVE-F1) |
| Preview damage | `df1_preview` | int | [1, 315] | DF-1 × MOVE-F1 — the actual expected damage; the value `lethal_factor` compares against `H_cur` |
| Current Structure | `H_cur` | int | [1, 594] | Player active Symbot's `current_structure`, floored at 1 |
| Output | `damage_factor` | float | [0.0, 1.0] | Fraction of current HP removed; clamped at 1.0 when lethal/overkill |

**Output range:** [0.0, 1.0]. Reaches 1.0 whenever `df1_preview ≥ H_cur`. **GDScript note:** cast to float before dividing (`float(a)/float(b)`) — int/int truncates. Compute `df1_preview` (the full DF-1×MOVE-F1 composition) **once per move** and reuse it in `lethal_factor` — one DF-1 invocation per move (the single-call rule, AC-EAI-15); applying MOVE-F1 to that cached DF-1 output is a cheap float multiply, not a second DF-1 call.

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

Binary — overkill has no mechanical value in TBC, and `damage_factor` already encodes magnitude via the 1.0 clamp. Uses the same **MOVE-F1-composed** `df1_preview` as EAI-1a (the cached value, not a fresh DF-1 call). This is load-bearing: comparing the *raw* DF-1 output against `H_cur` would make TACTICAL/OPPORTUNIST decline a kill that only becomes lethal after the power-tier multiply (the B1 defect). Worked Example D demonstrates this flip.

### Profile weights (Rule 5)

| Profile | `w_dmg` | `w_type` | `w_stat` | `w_lethal` | Character |
|---------|---------|----------|----------|------------|-----------|
| `AGGRESSIVE` | **3.0** | 0.2 | 0.0 | 1.0 | Bruiser — damage dominates; ignores status; modest kill bonus. Default fallback. |
| `TACTICAL` | 1.0 | **2.0** | **2.0** | **5.0** | Exploiter — type + status each as valuable as a full-damage turn, **but a securable kill always wins** (`w_lethal ≥ w_type + w_stat · STATUS_BASE_VALUE`; = 4.0 at MVP SBV 1.0). |
| `OPPORTUNIST` | 2.0 | 0.5 | 0.0 | **4.0** | Closer — strong damage; lethal bonus (4.0 on a {0,1} factor) beats any non-lethal combo. |

**Weight-scale rationale:** `type_factor ∈ [−0.5, 1.0]` and `status_factor ∈ {0, STATUS_BASE_VALUE}`, so weights are the primary comparable lever. **The kill-securing invariant is `w_lethal ≥ w_type + w_stat · STATUS_BASE_VALUE`** — when it holds, a bare kill (damage clamps to 1.0, no type/status) at `w_dmg·1.0 + w_lethal` always outscores the best non-lethal setup (strictly under `w_dmg·1.0 + w_type·1.0 + w_stat·STATUS_BASE_VALUE`, because a non-lethal move's `damage_factor < 1.0`), so the profile never passes up a securable kill. **The `STATUS_BASE_VALUE` coefficient is essential and was missing from the 1st-pass invariant (the B2 defect):** `status_factor` returns `STATUS_BASE_VALUE`, not a bare 1.0, so a status move's pull is `w_stat · STATUS_BASE_VALUE`. At the MVP `STATUS_BASE_VALUE = 1.0` the two forms coincide, but `STATUS_BASE_VALUE` is a tuning knob — at the old-documented ceiling of 2.0 the TACTICAL invariant `5.0 ≥ 2.0 + 2.0·2.0 = 6.0` **fails**, re-opening the exact harvest exploit. At the current cap `STATUS_BASE_VALUE = 1.5`, TACTICAL is `5.0 ≥ 2.0 + 2.0·1.5 = 5.0` — holds exactly (the kill still wins by the `damage_factor < 1.0` margin). AGGRESSIVE (`1.0 ≥ 0.2 + 0` — `w_stat = 0`) and OPPORTUNIST (`4.0 ≥ 0.5 + 0`) are robust to `STATUS_BASE_VALUE` because both have `w_stat = 0`; TACTICAL is the only `STATUS_BASE_VALUE`-sensitive profile. TACTICAL was also the **sole violator** at the old `w_lethal = 1.0 < 4.0` (declined kills to farm status — the Pillar-2 exploit), now `5.0` with margin. Keep AGGRESSIVE's `w_stat ≤ 0.5` or it applies status unpredictably.

### Worked examples (python3-verified)

Shared enemy: `physical_power = 70`, `energy_power = 40`; player `armor = 22`, `resistance = 22`. Target has no active status unless stated. **Examples A–C use `STANDARD`-tier moves (`power_mult = 1.00`), so `df1_preview = df1_raw` and their arithmetic is unaffected by the MOVE-F1 fix.** Example D uses a HEAVY-tier move to demonstrate the MOVE-F1 composition.

- **Move X** (Strike, **STANDARD** PHYSICAL, neutral): `df1_raw = floor(70²/(70+22) × 1.0 + ε) = floor(53.26) = 53`; `df1_preview = floor(53 × 1.00 + ε) = 53` *(floor 53 ≠ ceil 54 — discriminating at the DF-1 floor)*.
- **Move Y** (Volt Jab, **STANDARD** ENERGY, super-effective, SHOCK proc): `df1_raw = floor(40²/(40+22) × 1.5 + ε) = floor(38.71) = 38`; `df1_preview = 38 × 1.00 = 38` *(floor 38 ≠ round 39 ≠ ceil 39 — discriminating)*.

**Example A — `H_cur = 80` (neither lethal).** X: dmg 53/80 = 0.663, type 0, status 0, lethal 0. Y: dmg 38/80 = 0.475, type 1.0, status 1.0, lethal 0.
- **AGGRESSIVE:** X = 3·0.663 = **1.99**, Y = 3·0.475 + 0.2 = **1.63** → **picks X** (raw damage; type bonus can't close the gap).
- **TACTICAL:** X = **0.66**, Y = 0.475 + 2.0 + 2.0 = **4.48** → **picks Y** (type + new status worth 4× the damage lead).

**Example B — `H_cur = 42` (X lethal, Y not).** X: dmg clamp(53/42) = 1.0, type 0, status 0, lethal 1. Y: dmg 38/42 = 0.905, type 1.0, status 1.0, lethal 0.
- **OPPORTUNIST:** X = 2·1.0 + 4·1 = **6.0**, Y = 2·0.905 + 0.5 = **2.31** → **picks X** (the kill — lethal bonus dominates).
- **TACTICAL:** X = 1.0 + 5·1 = **6.0**, Y = 0.905 + 2.0 + 2.0 = **4.905** → **picks X** (a securable kill wins even against a full type+status setup: `w_lethal = 5.0 ≥ w_type + w_stat·STATUS_BASE_VALUE = 2.0 + 2.0·1.0 = 4.0` at MVP SBV). *This is the corrected kill-seeking behavior — the old `w_lethal = 1.0` made TACTICAL decline the kill (Y = 4.91 > X = 2.0), a Pillar-2 harvest exploit closed in the 2026-07-12 review.*

**Example C — reapplication discount as a decisive pick-flip (`H_cur = 80`, nothing lethal).** A third move **Yn** (Volt Jab (neutral), ENERGY, *neutral*-type, SHOCK proc): `df1 = floor(40²/(40+22) × 1.0 + ε) = floor(25.81) = 25` *(floor 25 ≠ ceil 26 — discriminating)*. Compared against Move X (`df1 = 53`, neutral, no status). Both are non-lethal at `H_cur = 80`, so `lethal_factor = 0` for both and the raised `w_lethal` is inert — the status is Yn's **sole** edge (neutral type), so the discount is decisive:
- **TACTICAL, no active status:** X = 1·0.6625 = **0.66**, Yn = 1·0.3125 + 2·0.0 + 2·1.0 = **2.31** → **picks Yn** (the new SHOCK is worth more than X's damage lead).
- **TACTICAL, SHOCK already active:** Yn's `status_factor` → 0.0, so Yn = 0.3125 + 0.0 = **0.31**, X = **0.66** → **flips to X** — reapplying a live status is worthless, so the AI stops wasting the turn on it.

*This replaces the earlier `H_cur = 42` Example C, now moot: at low Structure the raised `w_lethal` makes TACTICAL take the kill regardless of any status discount (Example B). The discount only changes a pick in a **non-lethal, status-is-the-sole-edge** situation — exactly this fixture. A super-effective Yn would NOT flip (its `type_factor` = 2.0 alone beats X), which is why the fixture uses a neutral-type Yn.*

**Example D — MOVE-F1 makes a HEAVY kill securable (`H_cur = 60`, the B1 regression fixture).** A **Move Z** (Crusher, **HEAVY** PHYSICAL, neutral, no status, `power_mult = 1.20`): `df1_raw = floor(70²/(70+22) × 1.0 + ε) = 53`; `df1_preview = floor(53 × 1.20 + ε) = floor(63.6) = 63` *(floor 63 ≠ round 64 ≠ ceil 64 — discriminating at the MOVE-F1 floor; the IEEE product is 63.599… so the ε nudge is required)*. Compared against Move Y (super-effective SHOCK, `df1_preview = 38`, non-lethal at 60). `H_cur = 60` sits **between** Z's raw DF-1 (53) and its true post-MOVE-F1 damage (63):
- **TACTICAL, if `df1_preview` wrongly used raw DF-1 (the old B1 bug):** Z sees `53 ≥ 60 = false` → `lethal_factor = 0`, `damage_factor = 53/60 = 0.883`; Z = `0.883`, Y = `0.633 + 2.0 + 2.0 = 4.633` → **picks Y, declining a kill it could actually land** (Pillar-2 harvest exploit re-opened through the preview).
- **TACTICAL, with MOVE-F1 (correct):** Z sees `63 ≥ 60 = true` → `lethal_factor = 1`, `damage_factor = clamp(63/60) = 1.0`; Z = `1.0 + 5·1 = 6.0`, Y = `4.633` → **picks Z, the kill** (`w_lethal = 5.0` secures it). *This is the fixture AC-EAI-19 pins: a HEAVY/SIGNATURE move whose kill is invisible without MOVE-F1. Keep Z HEAVY-tier — a STANDARD Z (mult 1.00) would not flip and would silently weaken the test.*

## Edge Cases

- **EC-EAI-01 — Unknown/missing `ai_profile`.** The profile id resolves to no defined Profile: the AI **falls back to `AGGRESSIVE`** and logs a content error naming the enemy id + the bad profile id. Never crashes, never returns no move (Rule 2). *Verified by AC-EAI-08.*
- **EC-EAI-02 — Score tie across moves.** Two or more moves share the top score: a **fresh RNG seeded from the injected `seed`** picks uniformly among the tied set via `randi_range(0, tied_count − 1)` (deterministic for a given seed). If no `seed` is injected (isolated unit test), the tiebreak falls to the **lowest skill index** (stable). *Verified by AC-EAI-06.*
- **EC-EAI-03 — Single-skill enemy.** `skills.size() == 1`: `argmax` trivially returns the one move; no RNG is consumed. *Verified by AC-EAI-07.*
- **EC-EAI-04 — No "good" option (all scores ≤ 0, possibly negative-but-distinct).** Every move scores ≤ 0 (e.g. all off-type, no status value, none lethal — a TACTICAL enemy facing all off-type moves scores each at `damage_factor − 1.0 < 0`). `argmax` still returns the **least-negative** move (not a tie unless scores are exactly equal); only exact ties fall to the seeded/index path. Never `null`, never a move outside `skills`. *Verified by AC-EAI-07.*
- **EC-EAI-05 — Player Core element is null.** An elementless player Symbot (or no Core part): DF-1's EC-04 fallback makes `T = 1.0` for every move, so `type_factor = 0` for all — the AI scores purely on damage/status/lethal. No crash; the enemy simply cannot type-exploit an elementless target. *Verified by AC-EAI-05.*
- **EC-EAI-06 — Enemy has 0 in a move's power stat.** A move whose `damage_type` maps to an enemy stat of 0 (`A = 0`): DF-1's EC-01 floors it to `DAMAGE_FLOOR = 1`, so `damage_factor = 1/H_cur` (tiny but valid) and `lethal_factor = 0` (unless `H_cur = 1`). No divide-by-zero, no crash. *Verified by AC-EAI-04.*
- **EC-EAI-07 — `H_cur` divide guard.** `current_structure` is **floored at 1** for the `damage_factor` division. The AI is never invoked against a downed (Structure 0) target — TBC ends the battle before the enemy's next turn — but the floor prevents a divide-by-zero if the hook is ever called defensively. *Verified by AC-EAI-04.*
- **EC-EAI-08 — Malformed or boundary phase (Rule 6).** (a) A `phase_profile` that resolves to no Profile, or a `phase_threshold` outside `[0.0, 1.0]`: the AI **ignores the phase and uses the base profile**, logging a content error. (b) **Boundary:** the shift is strict `<` — at exactly `current/max == phase_threshold` the base profile is still used; the phase applies only *below* it. *Verified by AC-EAI-09.*
- **EC-EAI-09 — `SELF`-behavior move in `skills` (reserved path).** If an enemy authors a `SELF` move (self-repair/buff — not MVP content), it is scored on its own effect; with no MVP SELF-scoring authored it yields `damage_factor = type_factor = status_factor = lethal_factor = 0` (score ≈ 0), so it is **deprioritized under any offensive move**. No crash. *Advisory — verified by AC-EAI-10 (advisory).*
- **EC-EAI-10 — Low-Structure `damage_factor` saturation (outcome-neutral).** As `H_cur` shrinks, `damage_factor = clamp(df1/H_cur, 0, 1)` reaches 1.0 for a move **exactly when that move is lethal** (`df1 ≥ H_cur` ⇒ both `damage_factor = 1.0` **and** `lethal_factor = 1`). So the moves whose `damage_factor` "saturates together" at low `H_cur` are precisely the mutually-lethal ones — and picking any of them **kills the target this turn regardless**, so the outcome is identical. Non-lethal moves keep `damage_factor < 1.0` and stay discriminated. At the `H_cur = 1` floor (EC-EAI-07) every damage move is lethal, so the choice among them is cosmetic only (a playtester may see AGGRESSIVE pick a smaller hit — legibility is preserved because the target dies either way and Combat UI's VA-1 move readout still names the move). **No dedicated AC** — the mutually-lethal tie is already covered by AC-EAI-06 (tiebreak) and the `H_cur = 1` arithmetic by AC-EAI-04, and the result (target downed) is invariant under the pick, so a dedicated assertion would test nothing observable.

## Dependencies

### Upstream (Enemy AI reads from these)

| System | What Enemy AI reads | Status | Hard/Soft |
|--------|--------------------|--------|-----------|
| **Turn-Based Combat** | `battle_state` at enemy `ACTION_PENDING`: enemy `skills`/`stats`/`current`+`max` Structure; player active Symbot's Core element, defense stats, `current_structure`, active statuses; the injected seed | Approved | Hard |
| **Enemy Database** | `ai_profile`, `skills`, `stats`, `core_element` per enemy | Approved | Hard |
| **Damage Formula** | DF-1 read-only preview (pure function) for `damage`/`lethal` factors, composed with **MOVE-F1** (Move DB); uses effective post-SYN-F4 defense | Approved | Hard |
| **Move Database** | each skill's `behavior`, `damage_type`, `element`, `status_proc`, **`power_tier`** (→ MOVE-F1 `power_mult` in the damage preview) | Approved | Hard |

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
| `TACTICAL` `(w_dmg,w_type,w_stat,w_lethal)` | `(1.0, 2.0, 2.0, 5.0)` | type/stat 1.5–2.5; **lethal ≥ type + stat·STATUS_BASE_VALUE** | The exploiter. `w_type`+`w_stat` set how far it sacrifices raw damage for matchup/status. At type/stat < ~1.3 it collapses toward AGGRESSIVE behavior. **`w_lethal` must stay ≥ `w_type + w_stat · STATUS_BASE_VALUE` (currently 5.0 ≥ 2.0 + 2.0·1.0 = 4.0; at the SBV cap 1.5 → 5.0 ≥ 5.0 exactly)** or it starts declining securable kills to set up status — the Pillar-2 harvest exploit closed in review (warning 1). Re-derive this bound whenever `w_type`, `w_stat`, **or** `STATUS_BASE_VALUE` changes. |
| `OPPORTUNIST` `(w_dmg,w_type,w_stat,w_lethal)` | `(2.0, 0.5, 0.0, 4.0)` | lethal 3–6 | The closer. `w_lethal` must exceed its max non-lethal score (2.5) or it stops reliably finishing (warning 1). `w_stat = 0`, so robust to `STATUS_BASE_VALUE`. |
| `STATUS_BASE_VALUE` | 1.0 | **0.5–1.5** | Base value of applying any new status. Effective pull = `w_stat × STATUS_BASE_VALUE`; tune this **or** `w_stat`, not both (warning 4). **Ceiling is 1.5, not 2.0:** above `STATUS_BASE_VALUE = (w_lethal − w_type)/w_stat = 1.5` for current TACTICAL weights, the kill-securing invariant breaks and the harvest exploit re-opens (the B2 fix). `0.0` is a **kill-switch, not a tune** — it nullifies all status incentive for every profile regardless of `w_stat` (warning 4). |
| `type_factor` reward / penalty | +1.0 / −0.5 | reward 0.75–1.5, penalty 0 to −1.0 | The super-effective bonus and off-type penalty. Keep reward > \|penalty\| (warning 3). |

### Per-enemy content values (authored in Enemy DB data, not global knobs)

| Value | Typical | Safe Range | Note |
|-------|---------|------------|------|
| `phase_threshold` (bosses only) | 0.40 | 0.25–0.50 | Structure fraction below which the phase profile takes over. Omitted on WILD enemies. Strict `<` (EC-EAI-08b). |
| `phase_profile` (bosses only) | `OPPORTUNIST` | any defined profile | The desperation profile. Typical pairing: `TACTICAL → OPPORTUNIST`. |

### Knob interaction warnings

1. **`w_lethal ≥ w_type + w_stat · STATUS_BASE_VALUE` (the kill-securing invariant)** for *every* profile, or "secure the kill" fails *silently* — the enemy walks past lethal moves. A bare kill scores `w_dmg·1.0 + w_lethal`; the best non-lethal stays strictly under `w_dmg·1.0 + w_type·1.0 + w_stat·STATUS_BASE_VALUE` (its `damage_factor < 1.0`), so the kill wins iff `w_lethal ≥ w_type + w_stat·STATUS_BASE_VALUE`. **The `STATUS_BASE_VALUE` coefficient is not optional** — it was dropped in the 1st-pass invariant (the B2 defect), which made the bound look satisfied at `STATUS_BASE_VALUE = 2.0` when it actually fails there. OPPORTUNIST (4.0 ≥ 0.5) and AGGRESSIVE (1.0 ≥ 0.2) clear it at any `STATUS_BASE_VALUE` (both `w_stat = 0`); TACTICAL clears it only while `STATUS_BASE_VALUE ≤ (w_lethal − w_type)/w_stat = 1.5` — hence the [0.5, 1.5] range cap on that knob. Re-check whenever `w_type`, `w_stat`, `w_lethal`, **or** `STATUS_BASE_VALUE` changes. *(A standing content-validation AC over all three profiles is the recommended enforcement — see Acceptance Criteria carry-forwards.)*
2. **AGGRESSIVE `w_stat` ≤ 0.5** — above that, the "dumb bruiser" starts applying status, blurring its identity against TACTICAL.
3. **`type_factor` reward > |penalty|** — if the off-type penalty is as harsh as the super-effective reward, TACTICAL over-avoids off-type moves; keep the reward the larger magnitude.
4. **`STATUS_BASE_VALUE` × `w_stat` are one lever** — both scale the status pull. Change one; leaving both cranked double-counts and makes TACTICAL ignore damage entirely. **`STATUS_BASE_VALUE = 0.0` is a kill-switch, not a low tune:** it zeroes `status_factor` for *every* profile regardless of `w_stat`, silently stripping TACTICAL's status behavior (a worse degradation than the statusless-moveset case AC-EAI-18 warns on — that at least fires a linter warning; this does not). Keep it in `[0.5, 1.5]`; treat `0.0` as "disable status scoring globally," never as a per-profile tune.
5. **`phase_threshold ∈ (0, 1)`** — at ≥ 1.0 the phase profile is always active (base profile never used); at ≤ 0 it never triggers. Keep bosses in 0.25–0.50 so the shift reads as a distinct "desperation" beat, not an immediate or never-seen change.
6. **TACTICAL enemies need ≥1 status-proc move** (content-authoring, enforced by AC-EAI-18). `w_stat = 2.0` is dead weight on a statusless moveset — a TACTICAL enemy with no Burn/Shock/Stagger move silently degrades to a low-damage type-picker (effectively `w_dmg=1.0, w_type=2.0`). The Enemy DB linter warns on this; author at least one status move per TACTICAL enemy so the profile behaves as named.

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

**Tags:** BLOCKING (automated test, gates story completion) · ADVISORY · DEFERRED (needs a Not-Started system / integration). **Test types:** Unit (GUT, `tests/unit/enemy_ai/`) · Content-Validation (offline linter) · Integration. **RNG contract (Rule 3):** `request_move` takes an injected **integer `seed`** and builds a fresh `RandomNumberGenerator` per call; never global `randf()`; "no-RNG" = `seed` is `null`/absent (→ lowest-index tiebreak). Fixtures use the shared enemy (`physical_power=70`, `energy_power=40`; player `armor=22`, `resistance=22`) unless stated. All fixture numbers are python3-verified. **Two GDScript hazards apply throughout** and are called out where load-bearing: (i) `int/int` truncates — every ratio must use `float()` casts / float fields; (ii) `Resource.duplicate()` is shallow — nested Arrays/Dictionaries share references, so a read-only/determinism assertion needs a write-intercepting mock, not a post-call value comparison.

**AC-EAI-01** (BLOCKING, Unit): **Profile discrimination on the same move-set (Example A).** GIVEN Move X (PHYSICAL, T=1.0, no status), Move Y (ENERGY, T=1.5, SHOCK proc), `H_cur=80`, no active statuses, no-RNG. WHEN `request_move` runs with AGGRESSIVE, then TACTICAL. THEN AGGRESSIVE → **X** (X=1.99, Y=1.63); TACTICAL → **Y** (X=0.66, Y=4.48). FAIL: either returns the opposite move or null. Discriminator: same two moves, opposite picks — an always-highest-damage impl passes AGGRESSIVE but fails TACTICAL; an always-super-effective impl fails AGGRESSIVE.

**AC-EAI-02** (BLOCKING, Unit): **A securable kill is always taken — even by TACTICAL (Example B).** GIVEN `H_cur=42`, no active statuses, no-RNG. WHEN OPPORTUNIST, then TACTICAL. THEN **both → X** (the kill): OPPORTUNIST 6.0 vs 2.31; TACTICAL 6.0 vs 4.905 (`w_lethal=5.0 > w_type+w_stat=4.0`, so the kill beats the full type+status setup). `lethal_factor=1` since df1(X)=53 ≥ 42. FAIL: either profile returns **Y** (declines the kill). Discriminator: an impl that left TACTICAL's `w_lethal ≤ 4.0` picks Y and fails — this AC is the regression guard on the kill-securing invariant.

**AC-EAI-03** (BLOCKING, Unit): **Factor arithmetic + floor-not-ceil preview (Example A intermediates).** THEN Move X: `df1_preview=53` (floor, not ceil 54), `damage_factor=53/80=0.6625`, `type_factor=0.0`, `status_factor=0.0`, `lethal_factor=0`. Move Y: `df1_preview=38` (floor, not round/ceil 39), `damage_factor=0.475`, `type_factor=1.0`, `status_factor=1.0`, `lethal_factor=0`. FAIL: df1(X)=54, df1(Y)=39, or integer-division truncation of `damage_factor`. Discriminator: catches ceil-instead-of-floor in the DF-1 call path and GDScript int/int truncation.

**AC-EAI-04** (BLOCKING, Unit): **Independent guard sub-cases (EC-EAI-06, EC-EAI-07).** Four **separately-asserted** sub-cases so a single missing guard is isolable — the 1st-pass fixture conflated `A=0` and `H_cur=1` and never exercised the energy path or the `A+D=0` divide (the B4 defect). All no-RNG, STANDARD tier (`power_mult=1.0`).
- **(a) A=0, physical path, safe defender.** enemy `physical_power=0`, player `armor=10`, PHYSICAL move, `H_cur=80`, T=1.0. THEN `df1_raw = DAMAGE_FLOOR = 1`, `df1_preview = 1`, `damage_factor = clamp(1/80) ≈ 0.0125`, `lethal_factor = 0`; legal non-null move. FAIL: `df1_preview=0`, crash, NaN.
- **(b) A=0 AND D=0 (the 0/0 divide).** enemy `physical_power=0`, player `armor=0`, PHYSICAL move, `H_cur=80`. THEN `df1_raw = DAMAGE_FLOOR = 1` — **this asserts DF-1 guards `A+D=0` (0/0), a precondition on the Damage Formula GDD, not something Enemy AI can floor itself** (EC-EAI-06 note). No divide-by-zero, no crash. FAIL: exception / NaN from `A²/(A+D)` — if this fires, DF-1's `A+D=0` guard is the missing piece and must be fixed there.
- **(c) Energy path A=0.** enemy `energy_power=0`, player `resistance=10`, ENERGY move, `H_cur=80`. THEN same as (a) via the energy stat path (`df1_preview=1`, `lethal_factor=0`). FAIL: the energy path is unguarded while the physical path is guarded (a copy-paste guard on only one path). Discriminator: this sub-case is the only one exercising `energy_power`/`resistance` through the DF-1 floor.
- **(d) H_cur=1 divide floor + lethal boundary.** enemy `physical_power=70`, `H_cur=1`, PHYSICAL neutral. THEN `df1_preview=53`, `damage_factor = clamp(53/1) = 1.0` (float divide, no div-by-zero from `H_cur`), `lethal_factor = 1` (`53 ≥ 1`); legal move. FAIL: divide-by-zero on `H_cur`, `damage_factor` inf/NaN, or `lethal_factor=0` at `df1_preview ≥ H_cur`.

Discriminator: four independent guards (DF-1 `A=0`, DF-1 `A+D=0`, energy-path floor, `H_cur` floor-at-1) — any one absent faults exactly one sub-case, and the split localizes which.

**AC-EAI-05** (BLOCKING, Unit): **Null player Core element (EC-EAI-05).** GIVEN player Core element = null, Moves X/Y, `H_cur=80`, no-RNG. THEN `type_factor = 0.0` for every move (T=1.0 fallback, DF-1 EC-04); no crash/null-deref; AGGRESSIVE returns the higher-damage move (X, df1 53 > 38). FAIL: any non-zero `type_factor`, an exception on null Core access, or wrong pick. Discriminator: catches null-deref and the nonsense "exploit a null type" result.

**AC-EAI-06** (BLOCKING, Unit): **Tie-breaking (EC-EAI-02).** GIVEN two moves **engineered to score exactly equal** (identical factor inputs: same `damage_type` → same enemy power stat, same `T`, both no status, both non-lethal — so `score` is bitwise-equal, not merely close). **PRECONDITION (binds the RNG API — the fixture is otherwise unwritable):** the tiebreak constructs a fresh `RandomNumberGenerator` seeded with the injected `seed` and calls `rng.randi_range(0, tied_count − 1)` (Rule 3). `SEED_A` and `SEED_B` MUST be **pre-computed and hard-coded as named constants in the test file** — the implementing programmer verifies, once, that against this exact call on the pinned Godot 4.6 `RandomNumberGenerator` they draw different indices on a 2-element tie (`SEED_A → index 0`, `SEED_B → index 1`) and records the values; leaving the seeds as TBD is a failing AC, and the seeds must be re-verified if the engine version bumps (RNG algorithm changed across 4.4–4.6). (a) With `seed = SEED_A` fixed, the pick is stable across repeated calls (fresh RNG each call, same seed → same index). With `SEED_A` vs `SEED_B` the two picks differ — proving the RNG is actually consulted. (b) With no-RNG (`seed = null`) → the **lowest skill index** returns. FAIL: same seed → different moves; the tiebreak calls global `randf()` or reuses a shared RNG instance; no-RNG returns a higher-index move; or `SEED_A`/`SEED_B` return the same index (RNG bypassed); or the seed constants are left unresolved. Discriminator: the forced exact tie guarantees the RNG branch is reached — an organic near-tie could pass an RNG-bypassing impl vacuously.

**AC-EAI-07** (BLOCKING, Unit): **Single-skill & all-zero paths (EC-EAI-03, EC-EAI-04).** (a) `skills.size()==1` → that move returns, **RNG call count = 0** (fast path, no tie branch). (b) every move scores ≤ 0 → a non-null move in `skills` returns. FAIL: null returned, a move outside `skills`, or RNG consumed in the single-skill case. Discriminator: catches null-on-degenerate and needless RNG consumption.

**AC-EAI-08** (BLOCKING, Unit): **Unknown `ai_profile` → AGGRESSIVE fallback (EC-EAI-01).** GIVEN `ai_profile="BERSERKER"`. THEN the move matches AGGRESSIVE's pick for the same inputs; **exactly one** content error logged containing the enemy id + `"BERSERKER"`; no other error/warning; no exception. FAIL: no error (silent), two errors (per-invocation spam), error omits an id, or a crash. Discriminator: catches silent fallback, noisy fallback, and crash-on-unknown.

**AC-EAI-09** (BLOCKING, Unit): **Phase shift — strict `<` boundary + malformed fallback (EC-EAI-08).** GIVEN a boss: base TACTICAL, `phase_threshold=0.40`, `phase_profile=OPPORTUNIST`. **PRECONDITION (GDScript int-division trap):** the phase comparison MUST be float division — the fixture uses **`current_structure` and `max_structure` as floats** (or the implementation casts `float(current)/float(max)`), and the sub-cases use `max_structure = 100.0` so the ratio is exact. If the Structure fields were `int`, `current/max` truncates to `0` in GDScript for any `current < max`, which is always `< 0.40`, so the phase would fire for every case and sub-case (a) would pass a `≤` bug vacuously. (a) `current_structure=40.0, max_structure=100.0` → ratio `0.40` exactly → **base TACTICAL** used (strict `<` not satisfied) — verify the pick matches TACTICAL's argmax, not OPPORTUNIST's. (b) `current_structure=39.0` (ratio `0.39`) → **OPPORTUNIST** used. (c) `phase_profile="UNDEFINED_PROFILE"` at ratio `0.39` → base TACTICAL used, one content error naming the bad id, no crash. FAIL: phase active at equality (`≤` bug); base active below threshold; crash on malformed phase; **or int-typed Structure fields making the ratio truncate to 0 (the boundary test then passes vacuously)**. Discriminator: the one-character `≤`-vs-`<` boundary bug — only catchable with exact float ratios.

**AC-EAI-10** (ADVISORY, Unit): **SELF move deprioritized (EC-EAI-09).** GIVEN one SELF-behavior move + one DAMAGE move (A>0), any profile, any `H_cur>0`. THEN the DAMAGE move is selected (SELF scores 0 on all four factors; DAMAGE scores >0 on `damage_factor`). FAIL: the SELF move is selected over a positive-scoring DAMAGE move. Discriminator: catches a SELF move inadvertently receiving a `type_factor` boost. (Advisory — SELF content is not MVP-authored.)

**AC-EAI-11** (BLOCKING, Unit): **Reapplication discount as a decisive pick-flip (Example C).** GIVEN `H_cur=80` (nothing lethal), no-RNG, TACTICAL, and two moves: **X** (PHYSICAL, neutral, no status, df1=53) and **Yn** (ENERGY, *neutral*-type, SHOCK proc, df1=25 — floor, not ceil 26). (a) **No active status:** Yn `status_factor=1.0`; Yn `= 0.3125 + 2.0 = 2.3125`, X `= 0.6625` → TACTICAL returns **Yn**. (b) **SHOCK already active:** Yn `status_factor=0.0` (discounted); Yn `= 0.3125 + 0.0 = 0.3125`, X `= 0.6625` → TACTICAL **flips to X**. FAIL: Yn's `status_factor=1.0` when SHOCK is active (discount missing → still returns Yn), or the pick does not flip between (a) and (b). Discriminator: the flip is impossible unless the discount is both applied *and* decisive — Yn's neutral type makes the status its sole edge, so a missing discount is caught by the **pick**, not just the score. *(Fixture uses a neutral-type Yn deliberately — a super-effective Yn would not flip; do not revert to super-effective.)*

**AC-EAI-12** (BLOCKING, Unit): **Determinism + no state mutation (Rule 3).** GIVEN the concrete Example A state (Move X + Move Y, `H_cur=80`), AGGRESSIVE, `seed=0`. **PRECONDITION (GDScript shallow-duplicate trap):** `battle_state` MUST be passed as a **write-intercepting mock** — a wrapper that records (or throws on) any setter call on itself *and on every nested object* (Arrays, Dictionaries, sub-Resources). A post-call value comparison against a `duplicate()` snapshot is **insufficient**: `Resource.duplicate()` is shallow, so nested `active_statuses` Arrays share references and a mutation-then-revert (or a mutation of a shared nested Array) passes a value comparison vacuously. WHEN `request_move` runs twice with identical inputs. THEN (i) both calls return the same skill index (**X**); (ii) the mock records **zero writes** on both calls (self or any nested object). FAIL: second call differs from first (call-internal mutable/RNG state bleeds); same seed → different result; or the mock records any write. Discriminator: the throwing mock is the *only* reliable enforcement in GDScript — a shallow snapshot comparison is explicitly rejected as able to pass a mutating implementation. Load-bearing for replay/save/deterministic tests.

**AC-EAI-13** (DEFERRED, Integration): **TBC hook end-to-end (discharges TBC AC-TBC-INT-02).** GIVEN a live battle at enemy `ACTION_PENDING`. WHEN TBC calls `request_move(battle_state)`. THEN exactly one move returns, resolved through TBC's normal pipeline, with **no Heat/Energy gating** applied to selection. FAIL: null, a move outside `skills`, or energy-cost filtering. *Activate when: TBC's `ACTION_PENDING` state is implemented.*

**AC-EAI-14** (BLOCKING, Content-Validation): **`has_profile(id)` (unblocks Enemy DB AC-ED-01d).** THEN `has_profile` → true for `"AGGRESSIVE"`/`"TACTICAL"`/`"OPPORTUNIST"`; false for `"BERSERKER"`, `""`, and `null` (no crash). FAIL: an MVP profile returns false, an unknown returns true, or null crashes. Discriminator: an always-true stub passes positives, fails negatives; an always-false stub fails all.

**AC-EAI-15** (BLOCKING, Unit): **DF-1 evaluated once per move (EAI-1a single-call rule).** GIVEN an enemy with `N` moves — **including at least one move where `df1_preview ≥ H_cur` so the `lethal_factor` branch is exercised** (the branch most likely to re-call DF-1) — and a DF-1 call-counting spy/double injected. WHEN `request_move` runs. THEN the spy's call count `== N` (one DF-1 evaluation per move; both `damage_factor` and `lethal_factor` reuse the single cached `df1_preview`, and the MOVE-F1 `× power_mult` step is a float multiply on that cached output, **not** a second DF-1 call). FAIL: count `== 2N` (DF-1 called twice per move — e.g. `lethal_factor` re-invoking it) or `> N`. Discriminator: the mandatory lethal-branch move guarantees the re-call path is reached; catches a `lethal_factor` that re-calls DF-1 instead of reusing the cached preview — load-bearing for determinism if DF-1 is ever non-pure. Requires DF-1 to be injectable (see Dependencies: DF-1 purity contract).

**AC-EAI-19** (BLOCKING, Unit): **MOVE-F1 makes a heavy-tier kill securable (Example D — the B1 regression guard).** GIVEN Move Z (**HEAVY** PHYSICAL, neutral, no status, `df1_raw=53`, `power_mult=1.20` → `df1_preview=63`) and Move Y (STANDARD ENERGY, super-effective, SHOCK proc, `df1_preview=38`), `H_cur=60`, no active statuses, TACTICAL, no-RNG. THEN `df1_preview(Z) = floor(53 × 1.20 + ε) = 63` (floor, not round/ceil 64); `lethal_factor(Z) = 1` (`63 ≥ 60`); `damage_factor(Z) = clamp(63/60) = 1.0`; TACTICAL returns **Z** (Z = 6.0 > Y = 4.633) — it takes the kill. FAIL: `df1_preview(Z) = 53` (MOVE-F1 not applied → `lethal_factor=0`, Z=0.883, returns **Y**, declining a landable kill — the exact B1 defect); or `df1_preview(Z) = 64` (ceil/round instead of floor at the MOVE-F1 step). Discriminator: `H_cur=60` sits strictly between Z's raw DF-1 (53) and its true post-MOVE-F1 damage (63), so an implementation that previews DF-1 alone picks the *wrong* move — the pick, not just the score, exposes the bug. *Keep Z HEAVY-tier — a STANDARD Z (mult 1.00) would not flip.*

**AC-EAI-16** (BLOCKING, Unit): **No Heat/Energy cost filtering (Rule 1, unit-level).** GIVEN a single-move enemy whose move carries `energy_cost=999` and `heat_generation=999`, AGGRESSIVE, no-RNG. THEN that move is returned — the AI never inspects or filters by cost. FAIL: the move is filtered out (null or empty selection) or a cost field is read as a gate. Discriminator: unit-level guard for the "every skill always affordable" contract, complementary to the DEFERRED integration AC-EAI-13 (which only fires once TBC's `ACTION_PENDING` exists).

**AC-EAI-17** (BLOCKING, Content-Validation): **At most one `phase_threshold` per profile (Rule 6).** GIVEN a profile/enemy data entry declaring two `phase_threshold` values. THEN the content linter **rejects** the entry with exactly one error naming the enemy/profile id and `"duplicate phase_threshold"`; no entry with >1 threshold validates. FAIL: a second threshold is silently accepted (first/last used), or the linter crashes on the duplicate. Discriminator: enforces the MVP "at most one threshold" schema limit that no runtime AC covers.

**AC-EAI-18** (BLOCKING, Content-Validation): **TACTICAL enemies must carry ≥1 status-proc move.** GIVEN an enemy authored with `ai_profile=TACTICAL` whose `skills` contain **no** `status_proc` move. THEN the content linter emits a **warning** naming the enemy id (`w_stat=2.0` is dead weight → the enemy silently degrades to a low-damage type-picker). A TACTICAL enemy with ≥1 status move produces no warning. FAIL: no warning on a statusless TACTICAL moveset. Discriminator: catches the silent behavioral-degradation authoring trap (a TACTICAL name that does not behave tactically). *The test that the warning fires is BLOCKING; the warning itself is advisory to the content author (does not reject the entry).*

### EC ↔ AC Coverage

EC-01→08, EC-02→06, EC-03→07, EC-04→07, EC-05→05, EC-06→04, EC-07→04, EC-08→09, EC-09→10(ADVISORY), EC-10→(no dedicated AC — see EC-EAI-10; covered by AC-06 tiebreak + AC-04 arithmetic, outcome-invariant). **Rule/formula coverage:** EAI-1→03; damage_factor→03/04; **MOVE-F1 preview composition→19**; type_factor→03/05; status_factor→11; lethal_factor→02/19; kill-securing invariant→02/19; **STATUS_BASE_VALUE-dependent invariant→(warning 1 + recommended all-profile content-validation AC, carry-forward 6)**; profile weights→01/02; argmax+tiebreak→06/07; DF-1 single-call→15; no-cost-filter→16(unit)/13(integration); determinism→12; phase→09; phase threshold-count→17; TACTICAL status-authoring→18; fallback→08; `has_profile`→14; TBC integration→13(DEFERRED). **19 ACs: 17 BLOCKING (14 Unit + 3 Content-Validation) / 1 ADVISORY / 1 DEFERRED.** No untestable ("feels-smart") criteria — every AC has a discriminating fixture.

**QA carry-forwards:** (1) AC-EAI-03's floor-discrimination overlaps Damage Formula's own DF-1 tests — belt-and-suspenders if those enforce 53/38, sole guard otherwise. (2) AC-EAI-11 tests the discount as a **pick-flip** (Yn↔X at `H_cur=80`) — keep the neutral-type Yn fixture; a super-effective Yn would not flip and would silently weaken the test. (3) AC-EAI-06 needs **pre-computed, hard-coded seeds** verified against the pinned Godot 4.6 `RandomNumberGenerator` on `randi_range(0, tied_count−1)`; re-verify on any engine bump (RNG algorithm changed 4.4–4.6). (4) AC-EAI-15 requires DF-1 to be injectable (spy/mock) and now mandates a lethal-branch move so the re-call path is exercised — coordinate with the Damage Formula GDD's purity assertion. (5) AC-EAI-18 is a linter warning, not a hard reject — ensure it surfaces at content-authoring time, not runtime. **(6) STRONGLY RECOMMENDED new AC (deferred — out of this blocker pass, flagged for follow-up):** a content-validation AC that loads the actual `ai_profiles.tres` and asserts `w_lethal ≥ w_type + w_stat · STATUS_BASE_VALUE` for **every** profile (not just TACTICAL via AC-EAI-02). This is a ~5-line standing test that would have auto-caught both the B1 and B2 defects (a balance pass setting `AGGRESSIVE w_stat=1.5` or `STATUS_BASE_VALUE=2.0` would fail it). Also verifies `has_profile` against the loaded registry rather than a hardcoded stub (Rule 2 data-driven contract). **(7) B1 preview composition:** AC-EAI-19 pins the DF-1→MOVE-F1 composition via a pick-flip; any future change to the damage pipeline (a new MOVE-F1 tier, a crit path) must re-verify that `df1_preview` still mirrors what TBC deals, or `lethal_factor` desyncs again.

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-EAI-1 | **Per-status `status_factor` differentiation.** MVP treats Burn/Shock/Stagger as equal value (`STATUS_BASE_VALUE = 1.0`). Playtest may show one status is strictly stronger for the enemy (e.g. Shock's initiative denial), warranting per-status values. | systems-designer / balance | TACTICAL move-choice nuance; post-MVP |
| OQ-EAI-2 | **Multi-phase bosses.** MVP allows one `phase_threshold` per profile. A boss might want two shifts (e.g. 60% and 30%). Extend the schema if desired. | game-designer | Boss identity depth; post-MVP schema extension |
| OQ-EAI-3 | **Weight tuning at playtest.** The profile weights are first-pass values chosen to satisfy the discriminating examples. **RESOLVED in review (2026-07-12):** TACTICAL *declining a securable kill* was ruled an exploit, not a feature — `w_lethal` raised 1.0→5.0 so every profile takes a guaranteed kill (kill-securing invariant). Remaining feel watch: does OPPORTUNIST's phase shift read as menacing, and does TACTICAL's type/status *setup* (in non-lethal turns) feel smart rather than fussy? **Still the #1 feel watch.** | playtest / balance | The core feel of every enemy encounter |
| OQ-EAI-4 | **WILD phases?** MVP restricts the phase mechanic to bosses (WILD omit it). Confirm at content authoring whether any WILD enemy should have a phase. | game-designer | WILD variety vs. simplicity |
| OQ-EAI-5 | **SELF-move scoring value model (reserved).** If post-MVP enemies get self-repair/buff moves, the SELF scoring path (currently ≈ 0) needs a real model (e.g. score self-repair by missing Structure). | systems-designer | Post-MVP enemy variety |
| OQ-EAI-6 | **Lookahead depth.** MVP AI is single-turn — it does not model the player's likely response. A smarter boss could weight setup moves by expected follow-up. **Deliberately out of MVP scope** (legibility > depth — an unpredictable enemy teaches nothing, per Player Fantasy). | game-designer / ai-programmer | Post-MVP boss sophistication |
