# Story 003: MOVE-F1 — move power-multiply formula

> **Epic**: Move Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/move-database.md`
**Requirement**: `TR-mdb-002` (DAMAGE `power_tier` → multiplier `{0.70, 0.80, 1.00, 1.20, 1.40}`), `TR-mdb-008` (MOVE-F1 applies post-DF-1 with epsilon 0.0001 for IEEE-754 rounding)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary — pure formula core in `src/core/stats/`, DI `BalanceConfig`, no autoloads); ADR-0003 (secondary — `power_tier` is a `MoveDef` enum)
**ADR Decision Summary**: Pure, stateless, static-only formula constructs in `src/core/stats/`; the single tuning source is one injected `BalanceConfig`; the rounding epsilon is a fixed const in `StatMath`, NOT a tuning knob.

**Engine**: Godot 4.7 | **Risk**: LOW (pure math) — but the **epsilon is LOAD-BEARING** (see below)
**Engine Notes**: MOVE-F1 = `max(DAMAGE_FLOOR, floor(df1_output × power_mult + EPSILON))`. `StatMath.EPSILON` is already `0.0001` — reuse `StatMath.floor_eps(...)`; do NOT introduce a second epsilon. The epsilon is **empirically load-bearing** (python3-scanned 2026-07-10): 10 of 1,125 inputs return the wrong integer without it — e.g. `165 × 1.40 = 230.99999999999997` in IEEE-754 → bare `floor()` gives 230, wrong; the nudge gives 231. Full failing set: `0.70×{90,170,180}`, `1.40×{45,85,90,165,170,175,180}`. Re-run the scan if any multiplier is retuned.

**Control Manifest Rules (this layer)**:
- Required: Pure formula core in `src/core/stats/`, injected `BalanceConfig`, no allocations, no autoload coupling — source: ADR-0005
- Forbidden: relocating EPSILON into `BalanceConfig` (it defines the formula, it doesn't tune it) — source: ADR-0005 / StatMath doc
- Guardrail: DF-1 is UNCHANGED — MOVE-F1 multiplies DF-1's integer *output*; it does not call or modify DF-1

---

## Acceptance Criteria

*From GDD §Formulas MOVE-F1 + AC-MDB-02/03/04:*

- [ ] `power_mult` resolves from `power_tier` via the tier table `{BASIC 0.70, LIGHT 0.80, STANDARD 1.00, HEAVY 1.20, SIGNATURE 1.40}`, sourced from `BalanceConfig`
- [ ] Discriminating floor (AC-MDB-02): `df1=164, BASIC 0.70` → `floor(114.8001) = 114` (round/ceil give 115); `df1=187, SIGNATURE 1.40` → `261` (round/ceil give 262); sanity `df1=164, STANDARD 1.00` → 164
- [ ] Load-bearing epsilon + floor clamp (AC-MDB-03): `df1=165, SIGNATURE 1.40` → `231` (bare floor gives 230 — FAIL); `df1=90, BASIC 0.70` → `63` (bare floor gives 62 — FAIL); min clamp `df1=1, BASIC 0.70` → `max(1, floor(0.7001)) = 1`
- [ ] Tier ceilings / range (AC-MDB-04): `HEAVY df1=225` → 270; `SIGNATURE df1=225` → 315 (absolute output ceiling; never exceeds 315)

---

## Implementation Notes

*Derived from GDD §Formulas MOVE-F1 + `upgrade_formula.gd` (the sibling pure-formula pattern):*

New `src/core/stats/move_power_formula.gd`, `class_name MovePowerFormula extends RefCounted`, static-only. Core:
```gdscript
const DAMAGE_FLOOR := 1
static func move_damage(df1_output: int, power_tier: MoveDef.PowerTier, cfg: BalanceConfig) -> int:
    var power_mult: float = cfg.power_tier_multipliers[power_tier]
    return maxi(DAMAGE_FLOOR, StatMath.floor_eps(float(df1_output) * power_mult))
```
Append `power_tier_multipliers: Array[float] = [0.0, 0.70, 0.80, 1.00, 1.20, 1.40]` to `BalanceConfig` — indexed by the `PowerTier` enum value (index 0 = reserved sentinel, never looked up), mirroring the existing `drop_rate_by_rarity` index-0-reserved pattern. Add a doc-comment flagging `power_mult[SIGNATURE]` as a cross-document TTK-sensitive constant (GDD Tuning Knobs) and the strict-ordering invariant `BASIC < LIGHT < STANDARD < HEAVY < SIGNATURE`.

The `EPSILON`-omitted wrong path and the `round`/`ceil` wrong paths MUST be asserted to fail in the test (discriminating fixtures). Add a `python3` Fraction-oracle scan over all 1,125 inputs (`df1 ∈ [1,225]` × 5 multipliers) confirming 0 impl-vs-exact mismatches and re-confirming the 10 load-bearing inputs.

---

## Out of Scope

- The full damage pipeline `DF-1 → MOVE-F1 → TBC-F5` (AC-MDB-05) — **partly deferred**: DF-1 lives in the Damage Formula epic and TBC-F5 in the TBC epic, neither yet implemented. MOVE-F1's own contribution is fully tested here (it takes `df1_output: int`); the composed pipeline test is owned by the Damage-Formula / TBC epics once those formulas exist in code.
- Any runtime move resolution, `null`/stray `power_tier` fallback behaviour (AC-MDB-07/08 — TBC runtime)

---

## QA Test Cases

- **AC-1** (AC-MDB-02): discriminating floor — `df1=164,BASIC`→114; `df1=187,SIGNATURE`→261; `df1=164,STANDARD`→164. Edge: assert round()/ceil() paths (115/262) FAIL.
- **AC-2** (AC-MDB-03): load-bearing epsilon — `df1=165,SIGNATURE`→231; `df1=90,BASIC`→63; `df1=1,BASIC`→1. Edge: assert the epsilon-omitted path returns 230/62 and would FAIL; min clamp never returns 0.
- **AC-3** (AC-MDB-04): tier ceilings — `df1=225,HEAVY`→270; `df1=225,SIGNATURE`→315. Edge: output never exceeds 315; every tier maps to its exact multiplier.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/move_database/move_power_formula_test.gd` — must exist and pass (BLOCKING; discriminating + load-bearing-epsilon fixtures per AC-MDB-02/03/04)

**Status**: [x] Created & passing — `tests/unit/move_database/move_power_formula_test.gd` (11 tests incl. full-range sweep). python3 Fraction-oracle scan: 0 impl-vs-exact mismatches over 1,125 inputs; exactly 10 load-bearing inputs re-confirmed. Full suite 195/195 green, 2803 asserts (Godot 4.7 + GUT 9.7.1). `power_tier_multipliers` appended to BalanceConfig (append-only).

---

## Dependencies

- Depends on: Story 001 (`MoveDef.PowerTier` enum)
- Unlocks: the Damage-Formula / TBC pipeline composition (AC-MDB-05) once DF-1 + TBC-F5 exist
