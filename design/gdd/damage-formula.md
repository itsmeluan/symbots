# Damage Formula System

> **Status**: Approved (Round 2) — errata applied 2026-07-10 (DF-1 input/output ranges updated per TBC re-derivation under SYNERGY_POWER_BUDGET=40)
> **Author**: Luan + Claude Code (systems-designer)
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 3 (Build Depth Over Content Breadth)

## Overview

The Damage Formula System is the mathematical layer that translates a Symbot's build statistics into concrete combat outcomes. When a Symbot uses a skill in battle, this system takes the attacker's relevant Power stat (Physical Power or Energy Power), the skill's damage type, the skill's element, and the target's corresponding defense stat (Armor or Resistance), and produces a final integer damage value that the Turn-Based Combat System applies to the target's Structure.

The system has three responsibilities: (1) route attacks through the correct defense path based on `damage_type` — Physical skills are reduced by Armor, Energy skills by Resistance; (2) apply type effectiveness multipliers based on the skill's element compared against the target's Core element (×1.5 super effective, ×1.0 neutral, ×0.75 not very effective); (3) guarantee a defined minimum damage floor so no attack is ever completely negated by defense. Critical hit modifiers are reserved for Full Vision and stubbed here. The Damage Formula System defines no runtime state — it is a pure function called by Turn-Based Combat on each skill use.

## Player Fantasy

Players never think "the damage formula ran." They think: *"My Volt build absolutely shreds that Thermal-core boss — every hit lands for 50% more."* The Damage Formula System is the contract that makes that moment real: the build the player painstakingly assembled in the Workshop has a mathematically precise combat advantage, and that advantage is legible in the numbers that appear over enemy heads.

The formula is infrastructure for two player-facing feelings: **type mastery** and **stat investment payoff**. A player who builds a Volt specialist and hunts a Thermal-core zone earns visibly bigger damage numbers — the game rewards the homework. A player who stacks Physical Power and faces a heavily Armored enemy learns that defense matters and adjusts their build. The formula is invisible when working correctly; it becomes visible only in these two directions — satisfaction when the build fires, and a comprehensible wall when the wrong tool meets a resistant target.

Critical hit mechanics (a third potential feeling: the gambling spike) are deferred to Full Vision. In MVP, the formula is deterministic: same stats, same element matchup, same damage every time. Tactical certainty over RNG excitement.

## Detailed Design

### Core Rules

**Rule 1 — Damage Type Routing**

Every skill in Symbots has a `damage_type` (PHYSICAL or ENERGY). The active Symbot's final stats — computed by Part Database Formula 1 — are routed through this system based on that type:

| Skill `damage_type` | Attack value used | Defense value used |
|---------------------|------------------|-------------------|
| `PHYSICAL` | `final_stat["physical_power"]` | `final_stat["armor"]` (target) |
| `ENERGY` | `final_stat["energy_power"]` | `final_stat["resistance"]` (target) |

Physical Power and Energy Power are independent stat tracks. A build investing in Physical Power is not investing in Energy Power — their attacks use entirely separate attack and defense pools.

---

**Rule 2 — Type Effectiveness**

Type effectiveness applies when a skill's element is compared against the **target's Core element** (the element of the part in the target's Core slot). The comparison is asymmetric — the same element attacks have a fixed matchup regardless of direction:

| Skill Element | vs. Target Core: Volt | vs. Target Core: Thermal | vs. Target Core: Kinetic |
|---------------|-----------------------|--------------------------|--------------------------|
| **Volt** | ×1.0 (neutral) | ×1.5 (super effective) | ×0.75 (not very effective) |
| **Thermal** | ×0.75 (not very effective) | ×1.0 (neutral) | ×1.5 (super effective) |
| **Kinetic** | ×1.5 (super effective) | ×0.75 (not very effective) | ×1.0 (neutral) |

**Fallback:** If the target has no Core element (null, missing, or a Full Vision reserved element not in the MVP type chart), type effectiveness defaults to ×1.0.

Type effectiveness multipliers are locked values from Part Database Rule 6. This GDD does not redefine them.

---

**Rule 3 — Damage Calculation**

Damage is computed in three steps:

**Step 1 — Base damage (divisive reduction model):**

```
base_damage = attack * attack / (attack + defense)
```

This produces diminishing returns on defense: as defense grows, each additional point of defense reduces damage by less. Defense never completely blocks damage (attack > 0 always produces base_damage > 0 when defense > 0). If `attack + defense == 0`, treat as `base_damage = 0` (see EC-01).

**Step 2 — Apply type effectiveness:**

```
scaled_damage = base_damage * type_effectiveness_mult
```

Type effectiveness multiplier from Rule 2.

**Step 3 — Apply floor and minimum:**

```
final_damage = max(DAMAGE_FLOOR, floor(scaled_damage + 0.0001))
```

`DAMAGE_FLOOR` is a tuning constant (default 1). The epsilon-nudge guards against IEEE 754 float imprecision on the floor step. `DAMAGE_FLOOR` ensures no attack is ever fully negated — even a ×0.75 hit against maximum defense deals at least 1 damage.

---

**Rule 4 — Critical Hits (Full Vision stub)**

In MVP, the critical hit multiplier is always ×1.0 — no crits fire. The formula expression reserves a `crit_mult` variable for Full Vision implementation. `Targeting` stat's derived `Critical Rate` output (noted in Part Database Rule 4) feeds into this multiplier in Full Vision.

---

**Rule 5 — Determinism**

The Damage Formula System is fully deterministic: given the same inputs (attacker stats, skill damage_type, skill element, target core element, target defense stats), it always returns the same integer. No RNG occurs inside the formula itself. Stochastic effects (accuracy, status chances, critical hits) are resolved by the Turn-Based Combat System before calling the damage formula.

---

### States and Transitions

The Damage Formula System has no runtime state. It is a stateless pure function: inputs → output. No state machine applies. It is called once per skill use and returns a single integer.

---

### Interactions with Other Systems

| System | Data Flow | Direction |
|--------|-----------|-----------|
| **Symbot Assembly System** | Provides `final_stat` values (outputs of Part Database Formula 1) for attacker and target | Upstream → this system |
| **Turn-Based Combat System** | Calls this system per skill use with: `(attacker_stats, skill_damage_type, skill_element, target_stats, target_core_element)`. Receives final integer damage back. | Bilateral |
| **Part Database** | Defines type effectiveness chart (×1.5/×1.0/×0.75) and type chart (Volt/Thermal/Kinetic). Values are locked — this system reads and applies them, does not redefine. | Upstream constraint |
| **Enemy Database** *(not yet designed)* | Must expose `core_element` per enemy definition — this is a hard interface requirement from the type effectiveness rule. Enemy Database GDD cannot be approved without this field. | Upstream → this system |
| **Move Database** *(not yet designed)* | In MVP, the skill's `damage_type` and element come from the equipped part's own `damage_type` and `element` fields (not from a move-level override). Move Database does not need to define per-move base power for stat-only model. **Hard constraint (DF1):** If a future move needs a damage-type or element override different from the part's fields, that override must be defined in the Move Database GDD and passed to this system — do not add per-move damage fields to Part Database. | Downstream constraint |
| **Combat UI** | Displays damage numbers and type-effectiveness indicator ("Super effective!", damage color). Reads final_damage integer and type_mult from this system's output. | Downstream reader |

## Formulas

### Formula DF-1 — Damage Calculation

```
pre_floor    = (A * A / (A + D)) × T × crit_mult
final_damage = max(DAMAGE_FLOOR, floor(pre_floor + EPSILON))
```

**Routing rule — variable binding by `damage_type`:**

| `skill.damage_type` | `A` binds to | `D` binds to |
|---------------------|-------------|-------------|
| `PHYSICAL` | `attacker.final_stat["physical_power"]` | `target.final_stat["armor"]` |
| `ENERGY` | `attacker.final_stat["energy_power"]` | `target.final_stat["resistance"]` |

The formula expression is identical for both paths — only the variable bindings differ.

**Variable table:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Attacker power | `A` | int | 0–150 | Resolved by routing rule: Physical Power (PHYSICAL) or Energy Power (ENERGY). Base max 110 (SA-F1); synergy-amplified to 150 (SYNERGY_POWER_BUDGET = 40). Minimum realistic build value: ~20. |
| Target defense | `D` | int | 0–182 | Resolved by routing rule: Armor (PHYSICAL) or Resistance (ENERGY). Base max 132 (SA-F1); synergy-amplified to 182 (SYNERGY_DEFENSE_BUDGET = 50). |
| Type effectiveness | `T` | float | {0.75, 1.0, 1.5} | Derived from skill element vs. target Core element via the type chart (Part Database Rule 6). Defaults to 1.0 if target Core element is null or unrecognized. |
| Critical multiplier | `crit_mult` | float | 1.0 (MVP) | Always 1.0 in MVP — no crits fire. Full Vision will supply values > 1.0 when a crit triggers via the Targeting-derived Critical Rate stat. Multiplied before `floor()` — do not apply post-floor. |
| Epsilon nudge | `EPSILON` | float | 0.0001 (fixed) | IEEE 754 guard applied inside `floor()` to correct floating-point underflow on mathematically-whole results. Not a tuning knob — fixed implementation constant. |
| Damage floor | `DAMAGE_FLOOR` | int | 1 (default, tunable) | Minimum damage guaranteed regardless of defense or type effectiveness. Applied after `floor()` via `max()`. See Tuning Knobs. |
| Intermediate value | `pre_floor` | float | 0.0–225.0 | Intermediate float before rounding. Not exposed outside the formula. |
| Output | `final_damage` | int | 1–225 (realistic: 3–164) | Integer damage applied to target Structure. Always ≥ `DAMAGE_FLOOR`. |

**Output range:**
- Absolute minimum: `DAMAGE_FLOOR` (1). Reached when `pre_floor` rounds to 0 — requires extremely low A against high D (e.g., A < 5 vs. D ≥ 60, ×0.75 type).
- Absolute maximum: 225. Requires A=150 (max synergy, SYNERGY_POWER_BUDGET=40), D=0, T=1.5 — theoretical only; no build zeros enemy defense.
- Realistic minimum: 3. (A=20, D=60, T=0.75: `400/80 × 0.75 = 3.75 → floor = 3`)
- Realistic maximum: 164. (A=150, D=55, T=1.5: `22500/205 × 1.5 = 164.63 → floor = 164`) — TBC reference build, re-derived 2026-07-10 under SYNERGY_POWER_BUDGET=40.
- No upper cap in MVP. If a damage ceiling is required, add it as a post-formula tuning knob in the Turn-Based Combat GDD.

**Precision ordering (load-bearing):** Both `T` and `crit_mult` must be applied to the float `pre_floor` **before** the single `floor()` call. An implementation that floors `base_damage` first and then multiplies by `T` produces a different output and is incorrect.

**Worked example (discriminating — floor ≠ round ≠ ceil):**

Scenario: Volt Energy skill (element: Volt) vs. a Thermal-Core enemy. Attacker Energy Power = 53, target Resistance = 30, T = 1.5 (Volt vs. Thermal = super effective), crit_mult = 1.0.

```
A = 53, D = 30, T = 1.5, crit_mult = 1.0

base_damage  = 53 × 53 / (53 + 30) = 2809 / 83 = 33.8433…
pre_floor    = 33.8433… × 1.5 × 1.0 = 50.7650…
floor(50.7650… + 0.0001) = floor(50.7651) = 50
final_damage = max(1, 50) = 50
```

Verification:
- `floor(50.7650…) = 50`
- `round(50.7650…) = 51` ← diverges from floor
- `ceil(50.7650…) = 51` ← diverges from floor

An implementation using `round()` or `ceil()` instead of `floor()` returns 51, not 50.

**GDScript implementation note — float arithmetic required:** A and D are `int` values. GDScript's native `int / int` performs integer division and silently truncates: `53 * 53 / 83 = 33` instead of `33.843…`, causing `floor(33 × 1.5 + 0.0001) = 49` instead of the correct `50`. Cast to float before dividing: `float(A) * float(A) / (float(A) + float(D))`.

**Implementation note — `crit_mult` must be a passable parameter:** `crit_mult` must be accepted as an explicit argument to `compute_damage()` with a default value of 1.0, not hardcoded internally. This allows AC-DF-18 to test the ordering invariant by injecting `crit_mult=2.0` without modifying production code. Full Vision will pass real values without a source change.

**EPSILON status:** `EPSILON = 0.0001` is a defensive convention in this formula. An exhaustive check of `A, D ∈ [0, 110]` and `T ∈ {0.75, 1.0, 1.5}` finds no input where the nudge changes the integer result — IEEE 754 double precision does not produce underflow cases in this range. The nudge is retained for uniformity with the Part Database formula pipeline and for safety if stat ranges are expanded.

**Worked example — DAMAGE_FLOOR activation:**

Attacker Physical Power = 4, target Armor = 80, T = 0.75 (resisted):

```
A = 4, D = 80, T = 0.75, crit_mult = 1.0

base_damage  = 4 × 4 / (4 + 80) = 16 / 84 = 0.1904…
pre_floor    = 0.1904… × 0.75 × 1.0 = 0.1428…
floor(0.1428… + 0.0001) = 0
final_damage = max(1, 0) = 1   ← DAMAGE_FLOOR kicks in
```

## Edge Cases

### EC-01 — Attack stat is zero (`A = 0`)
The attacker has zero Physical Power (for a PHYSICAL skill) or zero Energy Power (for an ENERGY skill). `A² = 0`, so `base_damage = 0 / D = 0`. `pre_floor = 0`, `floor(0 + EPSILON) = 0`, `final_damage = max(DAMAGE_FLOOR, 0) = 1`. The formula handles this correctly without a special case — DAMAGE_FLOOR absorbs it. This represents a build that has invested nothing in the relevant power track using a skill of that damage type; the skill deals minimum damage.

### EC-02 — Defense stat is zero (`D = 0`)
The target has zero Armor (PHYSICAL attack) or zero Resistance (ENERGY attack). `base_damage = A² / (A + 0) = A² / A = A`. The attack stat becomes the direct damage value — no reduction. This is the formula's upper-bound case for a given A and T. Handled correctly by the formula; no special case needed.

### EC-03 — Both `A = 0` and `D = 0`
`0 / 0` is undefined. Implementation must guard: `if A == 0 and D == 0: return DAMAGE_FLOOR` (equivalently: `if A + D == 0`). This short-circuit executes before the division and avoids a division-by-zero error. Result is always `DAMAGE_FLOOR = 1`. This state (zero power, zero defense) represents a degenerate build unlikely in real play but possible in tests or edge content. Note: `A = 0, D > 0` does **not** require a guard — the formula handles it correctly per EC-01 (`0²/D = 0`, DAMAGE_FLOOR absorbs it).

### EC-04 — Target Core element is null or unrecognized
The target has no Core slot, or its Core element is a Full Vision reserved value (`CRYO`, `CORROSIVE`, `DATA`) not present in the MVP type chart. Type effectiveness defaults to ×1.0 (neutral). This is not an error — null-element targets are valid content (e.g., mechanical constructs with no elemental affinity) and full-vision elements will eventually be supported. The fallback is silent and always valid.

### EC-05 — Skill element is null
A skill may have no element — if the part's `element` field is somehow null (a data validation gap, not intended content). Treat as ×1.0 (neutral type effectiveness). This case should be caught by Part Database content validation (AC-21) before reaching combat; if it does reach this system, neutral fallback is safe.

### EC-06 — `T` applied after `floor()` (implementation ordering error)
If an implementation computes `floor(base_damage) * T` instead of `floor(base_damage * T)`, it produces a different (wrong) result. This is not a design edge case — it is a correctness requirement enforced by AC-DF-04. Example: A=53, D=30, T=1.5: correct path → `floor(50.765) = 50`; wrong path → `floor(33.843) * 1.5 = 33 * 1.5 = 49.5` (not an integer, requires another floor → 49). The correct output is 50.

### EC-07 — High attack vs. low defense (realistic ceiling confirmation)
A=80, D=10, T=1.5: `base_damage = 80² / (80 + 10) = 6400 / 90 = 71.111…`, `pre_floor = 71.111… × 1.5 = 106.666…`, `final_damage = max(1, floor(106.666… + 0.0001)) = 106`. Confirming the formula handles high-end realistic inputs without overflow or degenerate output. Verification: floor=106, round=107, ceil=107 — this example is discriminating between floor and round/ceil. (Note: A=110, D=110, T=1.5 produces `pre_floor=82.5`. In GDScript 4, `round(82.5) = 83` (round-half-away-from-zero) while `floor(82.5) = 82` — this IS discriminating in GDScript. Avoid only if targeting a language with banker's rounding where `round(82.5) = 82`.)

### EC-08 — `crit_mult` applied post-floor (Full Vision concern)
If a Full Vision implementation applies `crit_mult` after `floor()` — e.g., `floor(pre_floor) * crit_mult` — it produces a fractional result requiring a second floor and may compound rounding differently. `crit_mult` must be applied to `pre_floor` before the single `floor()` call, as specified in the formula expression. This is a correctness requirement for the Full Vision implementation; flag it in the Turn-Based Combat GDD when critical hits are added.

## Dependencies

### Upstream Dependencies (what Damage Formula requires)

| System | What It Reads | Notes |
|--------|--------------|-------|
| **Part Database** | Type effectiveness multipliers (×1.5/×1.0/×0.75) and type chart (Volt/Thermal/Kinetic). Stat field names (`physical_power`, `energy_power`, `armor`, `resistance`). Damage type enum (`PHYSICAL`, `ENERGY`). Element enum (`VOLT`, `THERMAL`, `KINETIC`). | Values locked in Part Database Rule 6 and Rule 4. This GDD does not redefine them. |
| **Symbot Assembly System** *(via call context)* | `final_stat` dictionary per combatant — post-chassis, post-upgrade stat values from Part Database Formula 1. This system does not call Assembly directly; it receives final stats from Turn-Based Combat's call frame. | Assembly owns stat computation; this system receives its outputs. |
| **Enemy Database** *(not yet designed)* | `core_element` per enemy definition — required for type effectiveness comparison. **Hard constraint (DF3):** Enemy Database GDD cannot be approved without exposing a `core_element` field readable by this system. | Interface not yet defined; provisional field name `core_element`. |

### Downstream Dependents (what depends on Damage Formula)

| System | What It Uses | Notes |
|--------|-------------|-------|
| **Turn-Based Combat System** | Calls `compute_damage(attacker_stats, skill_damage_type, skill_element, target_stats, target_core_element)` and applies the returned integer to target's current Structure. Only caller in MVP. Owns accuracy resolution and status effects — resolved before calling this system. | |
| **Combat UI** | Reads `final_damage` for floating damage number display. Also needs `T` (or a type indicator) for "Super effective!" feedback and damage color. **Hard constraint (DF2):** Combat UI GDD must specify the interface for reading both `final_damage` and `type_mult` from a single damage resolution event. | |

### Bidirectionality Note

Each downstream system's GDD must reference this GDD in its own Dependencies section:
- Turn-Based Combat GDD must list Damage Formula as an upstream dependency and specify the call contract.
- Enemy Database GDD must list Damage Formula as a downstream dependent and expose `core_element`.
- Combat UI GDD must list Damage Formula as an upstream dependency and specify how it reads type effectiveness metadata.

## Tuning Knobs

| Knob | Current Value | Safe Range | What Changing It Does |
|------|--------------|------------|----------------------|
| `DAMAGE_FLOOR` | 1 | 0–5 | Minimum damage per hit. At 0: a fully defensive build can completely negate low-power attacks (may create frustrating invincibility feel). At 5+: even type-advantaged heavy attacks on glass-cannon builds deal noticeable minimum damage regardless of stats (reduces defense meaningfulness). |
| Type effectiveness: super effective | ×1.5 | ×1.2–×2.0 | Reward for type-matching. Below ×1.2, type advantage feels marginal — players stop hunting specific matchups. Above ×2.0, a mismatched type matchup becomes unwinnable regardless of build (stat gap too large to overcome). |
| Type effectiveness: not very effective | ×0.75 | ×0.5–×0.9 | Penalty for type mismatch. Below ×0.5 combined with low DAMAGE_FLOOR means a resisted hit can deal 1–2 damage on a tanky target — discouraging but still functional. Above ×0.9, type disadvantage is nearly imperceptible (reduces strategic depth). |

**Note — no damage cap knob in MVP.** A maximum damage ceiling, if desired, belongs in the Turn-Based Combat GDD as a post-formula clamp. The Damage Formula System does not own this value.

**Note — EPSILON is not a tuning knob.** `EPSILON = 0.0001` is a fixed implementation constant addressing IEEE 754 float behavior. Changing it would alter formula precision, not gameplay behavior.

**Note — type chart ratios are locked from Part Database (Rule 6).** The relative values (×1.5 and ×0.75) can be tuned independently using the knobs above; the type matchup structure (which element beats which) is part of the game's core world rules and is not a tuning knob.

## Visual/Audio Requirements

N/A — pure-math Foundation system. No visual or audio output. Visual and audio feedback for damage events (floating numbers, hit effects, type-effectiveness indicators) are owned by the Combat UI and Audio System GDDs respectively.

## UI Requirements

N/A — pure-math Foundation system. The Combat UI GDD is responsible for all display of damage values and type effectiveness feedback (per hard constraint DF2).

## Acceptance Criteria

All ACs are **blocking** (Logic-type). Automated unit tests in `tests/unit/damage-formula/` are required before any implementing story can be marked Done.

**AC-DF-01**: Formula DF-1 computes final_damage correctly using inputs that distinguish floor from round and ceil. **Pass when**: `compute_damage(A=53, D=30, T=1.5, crit_mult=1.0)` returns `50`. Verification: `floor(50.765…) = 50`; `round(50.765…) = 51`; `ceil(50.765…) = 51`. An implementation using `round()` or `ceil()` returns 51 and fails. **Test type**: Unit.

**AC-DF-02**: T is applied before `floor()`, not after. **Pass when**: `compute_damage(A=53, D=30, T=1.5)` returns `50`. The wrong-order path `floor(53²/83) × 1.5 = floor(33.843…) × 1.5 = 33 × 1.5 = 49.5 → floor = 49` returns 49 — the system must return 50, not 49. **Test type**: Unit.

**AC-DF-03**: A PHYSICAL-type skill uses `physical_power` as A and `armor` as D. **Pass when**: A combatant with `physical_power=53, energy_power=40` attacking a target with `armor=30, resistance=20` using a PHYSICAL skill (T=1.0) returns `final_damage=33`. Cross-check: the wrong binding (`energy_power=40` vs. `resistance=20`) gives **26** (`1600/60 = 26.67 → floor = 26`) — the system must return 33, not 26. **Test type**: Unit.

**AC-DF-04**: An ENERGY-type skill uses `energy_power` as A and `resistance` as D. **Pass when**: A combatant with `physical_power=60, energy_power=40` attacking a target with `armor=20, resistance=30` using an ENERGY skill (T=1.0) returns `final_damage=22`. Cross-check: the wrong binding (`physical_power=60` vs. `armor=20`) gives 45 — the system must return 22, not 45. **Test type**: Unit.

**AC-DF-05**: Volt skill vs. Thermal-core target applies ×1.5. **Pass when**: Volt-element skill with A=53, D=30, target Core element = THERMAL returns `50`. An implementation applying ×1.0 (failing to match) returns 33. **Test type**: Unit.

**AC-DF-06**: Volt skill vs. Volt-core target applies ×1.0. **Pass when**: Volt-element skill with A=53, D=30, target Core element = VOLT returns `33`. Verification: floor=33, round=34 — discriminating. **Test type**: Unit.

**AC-DF-07**: Volt skill vs. Kinetic-core target applies ×0.75. **Pass when**: Volt-element skill with A=53, D=30, target Core element = KINETIC returns `25`. The wrong-order path `floor(33.843…) × 0.75 = 33 × 0.75 = 24.75 → floor = 24` returns 24 — the system must return 25. **Test type**: Unit.

**AC-DF-08**: All 9 type chart cells return the correct multiplier. **Pass when**: All of the following assertions hold (A=53, D=30 throughout):

| Skill element | Target core | Expected T | Expected final_damage |
|---------------|-------------|------------|----------------------|
| VOLT | VOLT | ×1.0 | 33 |
| VOLT | THERMAL | ×1.5 | 50 |
| VOLT | KINETIC | ×0.75 | 25 |
| THERMAL | VOLT | ×0.75 | 25 |
| THERMAL | THERMAL | ×1.0 | 33 |
| THERMAL | KINETIC | ×1.5 | 50 |
| KINETIC | VOLT | ×1.5 | 50 |
| KINETIC | THERMAL | ×0.75 | 25 |
| KINETIC | KINETIC | ×1.0 | 33 |

Zero failures across all 9 assertions. **Test type**: Unit (9 sub-assertions; may be one parameterized test).

**AC-DF-09**: Null target Core element defaults to ×1.0. **Pass when**: Call with `target_core_element = null`, A=53, D=30, skill element = VOLT returns `33`. An implementation that throws on null, or defaults to ×1.5, fails. **Test type**: Unit.

**AC-DF-10**: Null skill element defaults to ×1.0. **Pass when**: Call with `skill_element = null`, target Core element = THERMAL, A=53, D=30 returns `33` (neutral — not the ×1.5 super-effective result of 50). **Test type**: Unit.

**AC-DF-11**: A=0 returns DAMAGE_FLOOR, not zero. **Pass when**: `compute_damage(A=0, D=30, T=1.5)` returns `1`. Worked math: `0²/30 = 0`; `pre_floor = 0`; `max(1, 0) = 1`. **Test type**: Unit.

**AC-DF-12**: D=0 makes base_damage equal to A. **Pass when**: `compute_damage(A=53, D=0, T=1.5)` returns `79`. Worked math: `53²/53 = 53`; `53 × 1.5 = 79.5`; `floor(79.5 + 0.0001) = 79`. Verification: floor=79, round=80 — discriminating. An implementation that errors on D=0 fails. **Test type**: Unit.

**AC-DF-13**: A=0 and D=0 returns DAMAGE_FLOOR without a division-by-zero crash. **Pass when**: `compute_damage(A=0, D=0, T=1.5)` returns `1` with no exception, NaN, or infinity. The guard `if A == 0: return DAMAGE_FLOOR` must execute before any division. **Test type**: Unit.

**AC-DF-14**: DAMAGE_FLOOR activates when `pre_floor` rounds to zero. **Pass when**: `compute_damage(A=4, D=80, T=0.75)` returns `1`. Worked math: `16/84 = 0.190…`; `× 0.75 = 0.142…`; `floor(0.142… + 0.0001) = 0`; `max(1, 0) = 1`. An implementation returning 0 (omitting the `max()`) fails. **Test type**: Unit.

**AC-DF-15**: DAMAGE_FLOOR is applied after `floor()`, not before. **Pass when**: `compute_damage(A=53, D=30, T=1.5)` returns `50`, not `1`. Must be run together with AC-DF-14 — the pair enforces DAMAGE_FLOOR only activates when `pre_floor` rounds below it, not unconditionally. **Test type**: Unit.

**AC-DF-16**: Identical inputs always produce identical output. **Pass when**: `compute_damage(A=53, D=30, T=1.5, crit_mult=1.0)` called five consecutive times returns `50` every call with no variance. **Test type**: Unit.

**AC-DF-17**: `crit_mult = 1.0` in MVP has no gameplay effect. **Pass when**: `compute_damage(A=53, D=30, T=1.5, crit_mult=1.0)` returns `50` — identical to the formula without the multiplier. No crit code path fires in MVP. **Test type**: Unit.

**AC-DF-18**: `crit_mult` is applied before `floor()` — Full Vision readiness. **Pass when**: `compute_damage(A=53, D=30, T=1.5, crit_mult=2.0)` returns `101`. Worked math: `33.843… × 1.5 × 2.0 = 101.530…`; `floor(101.530… + 0.0001) = 101`. Wrong-order path: `floor(50.765…) × 2.0 = 50 × 2.0 = 100` — diverges. Note: `crit_mult ≠ 1.0` does not fire in MVP gameplay; this AC validates Full Vision wiring using the passable parameter (see implementation note in Formulas section). **Test type**: Unit.

## Open Questions

1. **Combat UI type effectiveness interface (DF2):** How does the Combat UI read the type effectiveness multiplier `T` from a damage resolution event? Two approaches: (a) `compute_damage()` returns a struct `{final_damage, type_mult}` instead of a bare integer; (b) Turn-Based Combat independently looks up T and passes it alongside the damage integer to Combat UI. Decision belongs in the Combat UI GDD and the Turn-Based Combat call contract. Unblock when Combat UI GDD is drafted.

2. **Status effect damage routing:** If Turn-Based Combat adds status effects that deal damage per turn (e.g., "burning" deals 5 damage/turn), does that damage go through Formula DF-1 or bypass it? Likely bypass (status damage is fixed, not stat-scaled), but the Turn-Based Combat GDD must clarify. If a bypass path exists, it must be explicitly documented — Formula DF-1 should be the only path for skill damage.
