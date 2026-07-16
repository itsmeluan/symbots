# Story 004: Formula 2 + 2b — per-part upgrade pipeline

> **Epic**: Part Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-15

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-008`, `TR-part-010`, `TR-part-023`, `TR-part-024`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot *(primary — controls where/how pure stat formulas live)*; ADR-0003: Content Resource Loading *(secondary — formulas read `PartDef` fields)*
**ADR Decision Summary**: ADR-0005 — pure formula core in `src/core/stats/` as pure functions + DI `RefCounted` owners; no new autoloads; formulas are deterministic and unit-testable in isolation. ADR-0003 — `stat_bonuses` values come from the frozen `PartDef`; never mutate the def (copy into runtime structs).

**Engine**: Godot 4.6 | **Risk**: LOW (pure integer/float math; no post-cutoff APIs)
**Engine Notes**: Numeric precision is the whole risk surface, not the engine. All multiply-then-round uses `floor(value + 0.0001)`; `ceil()` in F2b uses `ceil(value - 0.0001)`. **F2b's epsilon nudge is LOAD-BEARING** — verified by exhaustive IEEE 754 scan (2026-07-09): 26 inputs produce the wrong penalty without it (e.g. `15 × (1 − 1/3) = 10.000000000000002` → `ceil` without nudge returns −11 instead of −10). F2's nudge is a defensive convention (non-discriminating in current MVP ranges) but MUST remain. `python3`-scan any retune of these multipliers before shipping — specialists have erred in BOTH directions.

**Control Manifest Rules (this layer)**:
- Required: Content defs are frozen shared instances — copy stat values into runtime structs, never mutate the def — source: ADR-0003
- Forbidden: Never mutate a content def/catalog field at runtime (`runtime_content_mutation`) — source: ADR-0003
- Guardrail: pure functions, no allocations in the hot path

---

## Acceptance Criteria

*From GDD Formula 2, Formula 2b, Formula Pipeline + AC-06/07/08/16:*

- [ ] Formula 2: `upgraded_stat = floor(base_stat × upgrade_multiplier[tier] + 0.0001)` with the tier table (×1.00/1.15/1.30/1.50/1.70/2.00) — floors to int at each tier (TR-part-008/023/024)
- [ ] Common parts hard-capped at +3: `can_upgrade(common, 3) == true`, `can_upgrade(common, 4) == false`; `compute_upgraded_stat` silently caps at +3 (returns the +3 value, no throw) (TR-part-010)
- [ ] Formula 2b: `upgraded_drawback = -ceil(abs(base_stat) × max(0, 1.0 - tier × (1.0/3.0)) - 0.0001)` — reduces the penalty toward 0, never positive (TR-part-008)
- [ ] The `max(0, …)` clamp is present — without it tiers +4/+5 double-negate into a positive stat (BLOCK-6); tiers +3/+4/+5 all yield 0 (TR-part-024)
- [ ] Sign-routing (Prototype only): `stat_bonuses[S] > 0` → F2; `< 0` → F2b; `= 0` → 0. F2 and F2b run in parallel on the same source, outputs independent (TR-part-008)
- [ ] F2b applies independently per negative stat entry — no cross-contamination between stats (AC-16)
- [ ] Both epsilon nudges retained per the Numeric precision note; do not remove based on current-range behavior (TR-part-023/024)

---

## Implementation Notes

*Derived from GDD Formula 2 / Formula 2b / Formula Pipeline + ADR-0005 pure-core home:*

Place these as pure functions in `src/core/stats/` (ADR-0005). Signatures roughly: `compute_upgraded_stat(base_stat: int, tier: int) -> int` (F2) and `compute_upgraded_drawback(base_stat: int, tier: int) -> int` (F2b). Keep the tier→multiplier table as a config-sourced constant, not a magic array inline (data-driven standard). The Prototype sign-routing is the composition step: route each `stat_bonuses[S]` by sign. **Do not** feed raw `stat_bonuses` past this layer — Formula 1 (Story 005) consumes ONLY these outputs.

Implement the epsilon nudges exactly as written (`+ 0.0001` for floor, `- 0.0001` for ceil), or use equivalent integer-scaled arithmetic. Prove the F2b clamp with a test that asserts tiers +4 AND +5 (not just +3) — the double-negation bug manifests at +4/+5.

Worked reference values (use as discriminating fixtures — floor ≠ round ≠ ceil):
- F2 `base=13`: `[13, 14, 16, 19, 22, 26]` (`floor(13×1.15)=14`; ceil→15, round→15)
- F2 `base=7`: `[7, 8, 9, 10, 11, 14]` (`floor(7×1.15)=8`; ceil→9)
- F2b `base=-15`: `[-15, -10, -5, 0, 0, 0]`
- F2b `base=-1`: `[-1, -1, -1, 0, 0, 0]`

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: Formula 1 composition (sum of 8 parts + chassis modifier)
- Story 006: Formula 3 (drop rate)
- Workshop UI upgrade-button gating (Workshop epic) — this story only enforces the *formula* cap
- Story 009: `max_upgrade_tier` field validation (this story enforces the +3 cap behaviorally)

---

## QA Test Cases

*Extracted from GDD AC-06/07/08/16 — discriminating fixtures (floor ≠ round ≠ ceil).*

- **AC-1** (GDD AC-06): Formula 2 multiplier + floor at each tier
  - Given: `base_stat = 13`
  - When: tiers 0–5 computed
  - Then: exactly `[13, 14, 16, 19, 22, 26]` — asserts `floor(13×1.15)=14` (ceil/round give 15) and `floor(13×1.50)=19` (round gives 20)
  - Edge cases: `base=7` → `[7,8,9,10,11,14]`; epsilon regression `base=20, tier+1 == 23` (passes with or without nudge; retained as guard)

- **AC-2** (GDD AC-07): Common +3 hard cap
  - Given: a Common part, `base_stat = 10`
  - When: `can_upgrade(part, 3)`, `can_upgrade(part, 4)`, `compute_upgraded_stat(part, 3)`, `compute_upgraded_stat(part, 4)`
  - Then: `true`, `false`, `15`, `15` — assert both compute calls equal the literal `15` (not merely equal to each other); no throw
  - Edge cases: two-equal-wrong-values (both `12`) must fail the literal assertion

- **AC-3** (GDD AC-08): Formula 2b full sequence + clamp
  - Given: `stat_bonuses["armor"] = -15`, then `= -1`
  - When: tiers 0–5 computed
  - Then: `[-15,-10,-5,0,0,0]` and `[-1,-1,-1,0,0,0]`
  - Edge cases: MUST assert tiers +4 and +5 (the `max(0,…)` double-negation bug hides there); a +3-only test does not catch a missing clamp

- **AC-4** (GDD AC-16): F2b independence per stat
  - Given: Prototype with `stat_bonuses["armor"] = -15, stat_bonuses["mobility"] = -8`
  - When: at tier +2, `compute_upgraded_drawback("armor", part, 2)` and `("mobility", part, 2)`
  - Then: `-5` and `-3` respectively; neither affected by the other
  - Edge cases: a positive stat on the same part routes to F2, not F2b

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/part_database/upgrade_formula_test.gd` — must exist and pass (F2, F2b, cap, sign-routing, per-stat independence, epsilon)

**Status**: [x] Created and passing — `tests/unit/part_database/upgrade_formula_test.gd` (13 tests; full suite 44/44, 164 asserts, Godot 4.7 + GUT 9.7.1). Independently corroborated by an exhaustive `python3` Fraction-oracle scan: 0 impl-vs-exact mismatches for F2 (base 0–55) and F2b (base −55–0) across all tiers; the −ε nudge rescues exactly 26 F2b inputs (matches the GDD's empirical count).

---

## Dependencies

- Depends on: Story 002 (`PartDef` supplies `stat_bonuses`, `max_upgrade_tier`, `rarity`)
- Unlocks: Story 005 (Formula 1 consumes F2/F2b outputs), Story 010 (content upgrade behavior)

---

## Completion Notes
**Completed**: 2026-07-15
**Criteria**: 7/7 passing.
**Files created**:
- `src/core/stats/stat_math.gd` — ADR-0005 Layer-1 primitive: `floor_eps`/`ceil_eps` + the fixed `EPSILON` const (deliberately NOT in BalanceConfig).
- `src/core/stats/balance_config.gd` — ADR-0005 Layer-4 `class_name BalanceConfig extends Resource`; introduces `upgrade_multipliers` (append-only schema; later stories add their tables).
- `src/core/stats/upgrade_formula.gd` — the F2/F2b pure static-function module + sign-router + part-level cap.
- `tests/unit/part_database/upgrade_formula_test.gd` — 13 discriminating tests.
**Deviations** (all advisory, logged to `docs/tech-debt-register.md`):
1. **StatMath + BalanceConfig prerequisites**: this is the first ADR-0005 stat-formula story, so it births the shared Layer-1 primitive (`StatMath`) and the Layer-4 tuning Resource (`BalanceConfig`). Both are ADR-0005-owned infra, not Story-004-exclusive; Stories 005/006/007+ extend them. Same "born-here" pattern as LogSink in Story 003.
2. **`assets/data/balance_config.tres` NOT authored here**: ADR-0005 loads it at BootScreen step 2b and ContentValidator asserts it against the GDD — both are boot/validator/content concerns explicitly out of scope for a pure-formula story (cf. ADR-0004 boot-wiring carve-out). Unit tests inject `BalanceConfig.new()`, whose `@export` defaults mirror the GDD tier table. The authored `.tres` + boot load + validator balance-section are downstream (boot epic / Stories 007+ / 010).
3. **Stale engine label**: story-004 Context reads "Godot 4.6" (line 20) — folds into the pending 4.6→4.7 ADR/doc re-validation sweep.
**Verification note**: beyond the 13 GUT tests, an exhaustive `python3` `Fraction`-oracle scan proved the epsilon'd implementation equals the mathematically-exact value for every in-range input (F2: base 0–55; F2b: base −55–0; all tiers) — 0 mismatches — and confirmed the `−ε` nudge is load-bearing for exactly 26 F2b inputs (matches the GDD's 2026-07-09 IEEE-754 scan).
**Test Evidence**: Logic — `tests/unit/part_database/upgrade_formula_test.gd` (BLOCKING gate satisfied).
**Code Review**: Complete — inline (lean mode; subagents unavailable — persistent "Usage credits" API error). ADR-0005/0003 compliant; pure functions, doc-commented, data-driven tier table (config-sourced, no inline magic array), no runtime def mutation.
