# Story 001: DF-1 kernel — `compute_damage()` + `damage_floor` config

> **Epic**: Damage Formula
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/damage-formula.md`
**Requirement**: `TR-df-001`, `TR-df-002`, `TR-df-003`, `TR-df-004`, `TR-df-005`, `TR-df-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary); ADR-0006: RNG Service & Determinism (secondary — `crit_mult` injection)
**ADR Decision Summary**: DF-1 lives in `src/core/stats/` as a pure static function `DamageFormula.compute_damage(a, d, type_mult, cfg, log, crit_mult := 1.0) -> int`. Guard `a == 0 and d == 0` → return `cfg.damage_floor` **before** any division (TR-df-006); cast to float before dividing (TR-df-004); multiply `type_mult` and `crit_mult` **pre-floor** (TR-df-002); `maxi(cfg.damage_floor, StatMath.floor_eps(pre_floor))` (TR-df-005). `crit_mult` is a passable parameter, never hardcoded (ADR-0006 — the formula rolls no RNG; determinism is Rule 5).

**Engine**: Godot 4.7 | **Risk**: LOW (all APIs — static funcs, `maxi`, `floori` via `StatMath.floor_eps` — are 4.0-era stable; `StatMath` + `BalanceConfig` already exist)
**Engine Notes**: Reuse the existing `StatMath.floor_eps(x) = floori(x + EPSILON)` — **do not introduce a second epsilon** (ADR-0005: EPSILON is a fixed const in `StatMath`, not a tuning knob). GDScript `int / int` truncates silently: `53 * 53 / 83 == 33`, not `33.84` — the float cast is load-bearing (GDD implementation note). `damage_floor` is a **new** `@export` on `BalanceConfig` (append-only — add after the last existing field, never reorder).

**Control Manifest Rules (this layer — Core)**:
- Required: the pure formula core lives in `src/core/stats/`, DI RefCounted / static — no autoload; damage is computed via the `compute_damage` pure static function (`damage_computation` contract); a single `BalanceConfig` `.tres` is the sole tuning source — source: ADR-0005
- Forbidden: reading any runtime state or singleton inside the formula (TR-df-001); calling `@GlobalScope` `randf()/randi()/randomize()` in formula code (`global_rng_access`) — source: ADR-0005/0006
- Guardrail: `EPSILON` stays a `StatMath` const, never relocated to `BalanceConfig`; every new floor/ceil expression gets a python3 IEEE-754 scan logged in story evidence — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/damage-formula.md`, scoped to the pure kernel (inputs are explicit `a` / `d` / `type_mult` — routing and T-derivation are Stories 003 / 002):*

- [ ] **AC-DF-01** — `compute_damage(a=53, d=30, type_mult=1.5, crit_mult=1.0)` returns `50` (floor, not round/ceil which give 51)
- [ ] **AC-DF-02** — `type_mult` applied **before** `floor()`: the same call returns `50`, not the wrong-order `49`
- [ ] **AC-DF-11** — `compute_damage(a=0, d=30, type_mult=1.5)` returns `1` (DAMAGE_FLOOR, not 0) — handled by the `max()`, no special case
- [ ] **AC-DF-12** — `compute_damage(a=53, d=0, type_mult=1.5)` returns `79` (`53²/53 = 53`; `×1.5 = 79.5 → floor = 79`); no divide error
- [ ] **AC-DF-13** — `compute_damage(a=0, d=0, type_mult=1.5)` returns `1` with **no** exception / NaN / infinity — the `a==0 and d==0` guard fires before division
- [ ] **AC-DF-14** — `compute_damage(a=4, d=80, type_mult=0.75)` returns `1` (pre_floor `0.142… → floor 0 → max(1,0)=1`)
- [ ] **AC-DF-15** — DAMAGE_FLOOR is applied **after** `floor()`: `compute_damage(a=53, d=30, type_mult=1.5)` returns `50`, not `1` (floor only clamps when pre_floor rounds below it)
- [ ] **AC-DF-16** — determinism: the same call five consecutive times returns `50` every time, no variance
- [ ] **AC-DF-17** — `crit_mult=1.0` has no gameplay effect: returns `50`, identical to the un-multiplied formula
- [ ] **AC-DF-18** — `crit_mult` applied **pre-floor**: `compute_damage(a=53, d=30, type_mult=1.5, crit_mult=2.0)` returns `101` (`33.843…×1.5×2.0 = 101.53 → 101`), not the post-floor `100`
- [ ] `compute_damage` reads no singleton, no engine RNG, no `@GlobalScope` random (verified by construction — pure static)
- [ ] `BalanceConfig.damage_floor` added (append-only), authored in `assets/data/balance_config.tres` = `1`, and ContentValidator asserts `damage_floor >= 0` (GDD safe range 0–5)

---

## Implementation Notes

*Derived from ADR-0005 Layer 1 (`DamageFormula`) + GDD Formula DF-1:*

Add to `src/core/stats/damage_formula.gd`:

```gdscript
class_name DamageFormula
extends RefCounted

## DF-1 pure kernel. crit_mult is a passable parameter (default 1.0) — never
## hardcoded — so Full Vision wiring and AC-DF-18 inject values without a source
## change. Reads no runtime state (TR-df-001).
static func compute_damage(a: int, d: int, type_mult: float, cfg: BalanceConfig,
        log: LogSink, crit_mult: float = 1.0) -> int:
    if a == 0 and d == 0:                       # TR-df-006 — guard BEFORE divide
        return cfg.damage_floor
    var base := float(a) * float(a) / (float(a) + float(d))   # TR-df-004 float cast
    var pre_floor := base * type_mult * crit_mult             # TR-df-002 pre-floor
    return maxi(cfg.damage_floor, StatMath.floor_eps(pre_floor))  # TR-df-005
```

- `type_mult` here is the already-derived `T` — Story 002 owns the chart lookup, Story 003 owns binding `a`/`d` from stats. This kernel never inspects elements or damage types.
- The `log` parameter matches the ADR signature (injected `LogSink`) even if unused in the happy path — keep it for signature stability and future content-warning hooks. Never `push_error`/`push_warning` (`global_push_diagnostics` forbidden).
- **BalanceConfig**: append `@export var damage_floor: int = 1` after the last existing field. The default keeps a bare `BalanceConfig.new()` valid for unit-test DI; the authored `.tres` is the production source. Author `damage_floor = 1` in `assets/data/balance_config.tres`.
- **ContentValidator**: extend the existing balance family with a `damage_floor >= 0` check (mirror the existing gated-family pattern; emit an error code such as `content_balance_damage_floor_negative` on violation).
- **Epsilon scan**: `pre_floor = A²/(A+D) × T × crit` introduces no *new* floor expression — it routes through the existing `StatMath.floor_eps`. The GDD already logged the exhaustive scan (`A,D ∈ [0,110]`, `T ∈ {0.75,1.0,1.5}` — no nudge-flip). Re-log a confirming python3 scan in the story evidence per the ADR guardrail.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: the `type_effectiveness(skill_element, target_core_element, cfg)` chart lookup that derives `T` and the `type_chart` config field
- **Story 003**: binding `a`/`d` from combatant `final_stat` by `damage_type` (PHYSICAL/ENERGY routing) and the full routed composition entry point
- Critical hits actually firing (`crit_mult > 1.0` in gameplay) — Full Vision, TBC-owned

---

## QA Test Cases

*Authored inline (lean mode — no qa-plan exists). Automated unit specs; implement against these — do not invent new cases.*

- **AC-DF-01 / AC-DF-02** (floor discipline + pre-floor T):
  - Given: `cfg = BalanceConfig.new()` (damage_floor 1), spy LogSink
  - When: `compute_damage(53, 30, 1.5, cfg, spy, 1.0)`
  - Then: `assert_eq(result, 50)` — asserts floor (round/ceil give 51) AND pre-floor order (wrong order gives 49)
  - Edge cases: none — this is the discriminating anchor
- **AC-DF-11** (A=0 → floor, no special case):
  - Given/When: `compute_damage(0, 30, 1.5, cfg, spy)`
  - Then: `assert_eq(result, 1)`
- **AC-DF-12** (D=0 → base equals A, no divide error):
  - When: `compute_damage(53, 0, 1.5, cfg, spy)` → `assert_eq(result, 79)`
  - Edge cases: confirm no error/NaN raised
- **AC-DF-13** (A=0 ∧ D=0 guard):
  - When: `compute_damage(0, 0, 1.5, cfg, spy)` → `assert_eq(result, 1)`; assert no exception, result is finite (not NaN/inf)
  - Edge cases: this is the boundary the guard exists for — must execute before division
- **AC-DF-14 / AC-DF-15** (floor activation vs floor-after-floor):
  - `compute_damage(4, 80, 0.75, cfg, spy)` → `assert_eq(result, 1)` (14); paired with the `(53,30,1.5)→50` anchor (15) to prove the floor only clamps sub-floor pre_floor, not unconditionally
- **AC-DF-16** (determinism):
  - Loop the `(53,30,1.5,1.0)` call 5×; assert all five equal `50`
- **AC-DF-17 / AC-DF-18** (crit injectable, pre-floor):
  - `crit_mult=1.0` → `50` (17); `crit_mult=2.0` → `assert_eq(result, 101)` (18, wrong-order gives 100)
  - Edge cases: `crit_mult` must be a passable arg (compile-time proof the parameter exists)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage-formula/damage_formula_kernel_test.gd` — must exist and pass. Include the confirming python3 IEEE-754 scan output (or a note citing the GDD's logged scan) per the ADR guardrail.

**Status**: [x] Created — `tests/unit/damage-formula/damage_formula_kernel_test.gd` (14 test functions, all passing). python3 IEEE-754 exact-oracle scan: 0 mismatches across 131,769 inputs (A,D∈[0,120] × T∈{0.75,1.0,1.5} × crit∈{1.0,1.5,2.0}); `floor_eps` agrees with the exact rational floor everywhere — no new nudge-flip.

---

## Dependencies

- Depends on: None (`StatMath` + `BalanceConfig` already exist from the stat-pipeline epic)
- Unlocks: Story 002 (shares `damage_formula.gd`), Story 003 (calls this kernel)

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 12/12 passing (0 deferred) — all ACs mapped to discriminating unit tests
**Deviations**: OUT OF SCOPE (benign) — code review added a `bounds.size() < 2` defensive guard to `content_validator.gd::_check_stat_budget` (Story-008 `stat_budgets` code, not the `damage_floor` addition); review-driven robustness fix, suite green.
**Test Evidence**: Logic — `tests/unit/damage-formula/damage_formula_kernel_test.gd` (14 functions, passing); python3 IEEE-754 scan 0/131,769 mismatches. Full suite 243/243 green (Godot 4.7).
**Code Review**: Complete — `/code-review` 2026-07-16, APPROVED WITH SUGGESTIONS. Advisory follow-ups (add before Story 003): `damage_floor = 0` validator boundary test; guard-branch DI seam test (`compute_damage(0,0,1.5,cfg_floor_3,spy) == 3`).
