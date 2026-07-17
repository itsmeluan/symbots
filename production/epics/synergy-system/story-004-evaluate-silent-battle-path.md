# Story 004: evaluate_silent() battle path (no emit, no self-lock)

> **Epic**: Synergy System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/synergy-system.md`
**Requirement**: `TR-syn-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: The cached bonus block is frozen during battle — but as a **caller contract**, not a self-lock. TBC snapshots synergy at BATTLE_INIT via a silent path that must not fire `synergy_changed` into Workshop subscribers.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API required. Signal-emission counting via a spy connected to `synergy_changed`.

**Control Manifest Rules (this layer — Core)**:
- Required: pure formula core; `evaluate_silent()` shares the identical private compute path as `evaluate()`.
- Forbidden: `mid_battle_stat_recompute` — never call `evaluate/evaluate_silent` after BATTLE_INIT from battle code (this story provides the pre-battle silent entry, not a mid-battle one); no self-lock after silent call.
- Guardrail: synchronous, testable.

---

## Acceptance Criteria

*From GDD `design/gdd/synergy-system.md`, scoped to this story:*

- [ ] **AC-SYN-14** — `evaluate_silent()` computes correctly and does not emit (Scenario A + B):
  - A (single-tag cumulative): VOLT=5, VOLT-3 `{energy_power:6}`, VOLT-5 `{energy_power:12, effects:[volt_test]}` → signal counter == 0; `cached_bonus_block.stat_delta["energy_power"] == 18`; `effects == [volt_test]`. FAIL if counter>0, `energy_power!=18`, or block empty (silent path didn't cache).
  - B (combined via silent path): AC-SYN-03 Scenario A content/build (ironclad=3, VOLT=3) → counter == 0; `armor == 13` AND `energy_power == 10` (identical to `evaluate()` outputs). FAIL if counter>0, or `armor==8`/`energy_power==6` (silent path diverges from evaluate()).
- [ ] **AC-SYN-25** — `evaluate()` after `evaluate_silent()` overwrites the cache (Rule 8 behavioral, not a lock): `evaluate_silent(VOLT=5)` → `energy_power == 18`; then `evaluate([null×8])` → `cached_bonus_block.stat_delta.is_empty() == true` (cache replaced, not frozen), counter == 1. FAIL if `energy_power` still 18 (self-locked) or counter 0.

---

## Implementation Notes

*Derived from ADR-0005 + ADR-0002 Implementation Guidelines and GDD Rule 8:*

- Extract the count → activate → aggregate → dedup pipeline (Stories 001–003) into **one private compute function** (e.g. `_compute_block(parts) -> {active_synergies, bonus_block}`). Both `evaluate()` and `evaluate_silent()` delegate to it — path divergence becomes impossible by construction (the GDD's explicit guidance for AC-SYN-14 Scenario B, which shares AC-SYN-03's combined fixture precisely to catch a divergent silent path).
- `evaluate_silent(parts)`: call `_compute_block`, write `cached_bonus_block` + `active_synergies`, **do not** emit `synergy_changed`. This is TBC's BATTLE_INIT entry — a `synergy_changed` here would wake Workshop UI subscribers at battle start (TR-syn-008).
- **Rule 8 is behavioral, not a lock**: `evaluate_silent()` must NOT set any "frozen" flag that blocks later writes. `evaluate()` after `evaluate_silent()` must fully overwrite the cache (AC-SYN-25) — the freeze is a *caller* discipline (battle code simply doesn't call recompute), enforced by the control-manifest forbidden `mid_battle_stat_recompute`, not by the system self-locking. A self-lock would silently break Workshop live recalculation after the first battle.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001–003**: the compute pipeline this story factors into `_compute_block` and reuses.
- **Story 005**: `preview()`.
- **Consumer-owned**: TBC's actual BATTLE_INIT call site and the `mid_battle_stat_recompute` guard enforcement live in the TBC epic — this story only provides the emit-free entry point.

---

## QA Test Cases

*Embedded from the GDD's AC fixtures. Implement against these.*

- **AC-SYN-14 Scenario A**: Given VOLT=5, VOLT-3 `{energy_power:6}`, VOLT-5 `{energy_power:12, effects:[volt_test]}`, counter=0; When `evaluate_silent(parts)`; Then counter==0, `energy_power==18`, `effects==[volt_test]`. Edge: counter>0 (spurious emit); block empty (didn't cache).
- **AC-SYN-14 Scenario B**: Given AC-SYN-03 Scenario A content/build (ironclad=3, VOLT=3), counter=0; When `evaluate_silent(parts)`; Then counter==0, `armor==13`, `energy_power==10`. Edge: divergence from `evaluate()` (armor==8 / energy_power==6). *(Compare outputs against AC-SYN-02/03 paired ACs to prove no path divergence.)*
- **AC-SYN-25**: Given `evaluate_silent(VOLT=5)` → `energy_power==18`, counter=0; When `evaluate([null×8])`; Then `stat_delta.is_empty()==true`, counter==1. Edge: `energy_power` still 18 (self-lock — forbidden).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/synergy/synergy_evaluate_silent_test.gd` — must exist and pass. Contributes the epic DoD proof that `evaluate_silent()` is emit-free.

**Status**: [x] Complete — `tests/unit/synergy/synergy_evaluate_silent_test.gd`, 3 tests, all passing (full suite 762/762 green, 4268 asserts, 2026-07-17)

---

## Dependencies

- Depends on: Story 001 (SynergySystem owner + compute pipeline); benefits from Stories 002–003 being present so Scenario B's combined path is exercised.
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-07-17 (lean per-story gate — `/code-review` + `/story-done`, inline as godot-gdscript-specialist)

**Criteria**: 2/2 acceptance criteria verified against source (`evaluate_silent` sharing the private `_compute` path) + tests (content-matched).

**Deviations**: None. AC-SYN-14 is proven emit-free by `assert_signal_emit_count(sys, "synergy_changed", 0)` on both the single-tag cumulative path (energy 6+12=18) and the combined path (armor 13 / energy 10, identical to `evaluate()` — proving no path divergence). The load-bearing **no-self-lock** contract (AC-SYN-25) is genuinely discriminating: `evaluate_silent(VOLT=5)` caches 18, then `evaluate([])` asserts the cache is emptied with note "FAIL 18 = self-locked" and exactly 1 emit — proving Rule 8 is caller discipline, not a system self-lock that would break Workshop live recalc.

**Test Evidence**: `tests/unit/synergy/synergy_evaluate_silent_test.gd` — 3 tests. Full suite 762/762 green, 4268 asserts (Godot 4.7 · GUT 9.7.1).

**Code Review**: Pass. `evaluate` and `evaluate_silent` delegate to one private compute core (divergence impossible by construction); the silent path writes cache + `active_synergies` but never emits; no frozen flag. This is the emit-free entry point TBC's BATTLE_INIT depends on. No blocking issues.
