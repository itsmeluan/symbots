# Story 005: Formula 1 — total Symbot stat composition

> **Epic**: Part Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot *(primary — F1 is the composition point of the stat pipeline)*; ADR-0003: Content Resource Loading *(secondary — chassis modifier + stat_bonuses come from `PartDef`)*
**ADR Decision Summary**: ADR-0005 — pure formula core in `src/core/stats/`; the total-stat composition is where per-part upgraded values (Story 004 outputs) are summed and the chassis modifier applied, feeding the battle snapshot (`CombatantSnapshot`) frozen at BATTLE_INIT. Pure + DI, no autoloads.

**Engine**: Godot 4.6 | **Risk**: LOW (pure math)
**Engine Notes**: `floor(sum × modifier + 0.0001)` — the epsilon is a defensive convention here (non-discriminating in current MVP ranges: sums −440–880 × all tabled chassis modifiers) but retained for uniformity and retune safety. The outer `max(0, …)` is mandatory — `floor()` alone floors toward −∞ and would let a chassis penalty or an active Prototype drawback produce a negative final stat. `python3`-scan any chassis-modifier retune before shipping.

**Control Manifest Rules (this layer)**:
- Required: Content defs are frozen shared instances — read chassis modifier + stat_bonuses from the def, never mutate — source: ADR-0003
- Forbidden: Never mutate a content def/catalog field at runtime (`runtime_content_mutation`) — source: ADR-0003
- Guardrail: recomputed at battle start and on Workshop part-swap; pure, no allocations

---

## Acceptance Criteria

*From GDD Formula 1 + Formula Pipeline + AC-05:*

- [ ] `final_stat[S] = max(0, floor(sum(upgraded_value[S] for 8 parts) × chassis_modifier.get(S, 1.0) + 0.0001))`
- [ ] Chassis modifier is looked up per-stat from the archetype table keyed by the equipped Chassis part's `chassis_archetype`; stats not in the table use ×1.0 (`.get(S, 1.0)`)
- [ ] The sum uses **upgraded** values (Formula 2 / 2b outputs from Story 004), NEVER raw `stat_bonuses` — the Pipeline composition is mandatory (AC-05 (b) discriminator)
- [ ] `floor` (not round/ceil) and the outer `max(0, …)` clamp are both applied — a negative pre-clamp sum yields 0, not a negative stat
- [ ] Recomputed at battle start and on Workshop part-swap (behavioral contract; the trigger wiring is Assembly/Workshop's concern)

---

## Implementation Notes

*Derived from GDD Formula 1 + Formula Pipeline + ADR-0005:*

Pure function in `src/core/stats/`, e.g. `compute_final_stat(stat_key: StringName, upgraded_values: Array[int], chassis_archetype) -> int`. It receives the already-upgraded per-part values (Story 004 output) — it must NOT re-derive from raw `stat_bonuses`. The chassis modifier table is the authoritative, complete source (Balanced Frame's ×1.05 Processing/Cooling is IN the table; nothing exists outside it). Keep the table config-sourced.

The AC-05 (b) discriminator is the important one: a Prototype at tier +1 with `stat_bonuses["armor"] = -15` (F2b → −10) plus a +12 part at +0, Balanced Frame → `max(0, floor((−10 + 12) × 1.0)) = 2`. An implementation that skips F2b and feeds raw −15 computes `max(0, floor((−15 + 12))) = 0 ≠ 2`. The test MUST use the composed pipeline to pass.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: Formulas 2 / 2b (this story consumes their outputs)
- Assembly System epic: slot validation, gathering the 8 equipped parts, the `CombatantSnapshot` freeze, and the recompute *triggers* (ADR-0005 owns the snapshot; this story owns only the pure composition function)
- Formulas 4/5/6 (Heat decay, Overheat, Energy regen) — Combat/TBC epics

---

## QA Test Cases

*Extracted from GDD AC-05 — distinguishes floor from round/ceil and enforces the pipeline.*

- **AC-1** (GDD AC-05 (a)): floor + max(0) + chassis modifier
  - Given: 8 parts summing (upgraded) Mobility = 7, Heavy Frame (×0.80)
  - When: `compute_final_stat("mobility", …)`
  - Then: `max(0, floor(5.6)) = 5` — NOT 6 (round) and NOT 6 (ceil)
  - Edge cases: a sum that produces an exact integer after modifier; a sum that would go negative pre-clamp → 0

- **AC-2** (GDD AC-05 (b)): pipeline composition, never raw stat_bonuses
  - Given: Prototype part at tier +1 with `stat_bonuses["armor"] = -15` (F2b output −10) + a part with `stat_bonuses["armor"] = +12` at tier +0, Balanced Frame (×1.0)
  - When: `compute_final_stat("armor", …)` via the composed pipeline
  - Then: `max(0, floor((−10 + 12) × 1.0)) = 2`
  - Edge cases: the raw-feed wrong implementation yields `max(0, −3) = 0` and MUST fail this test

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/part_database/total_stat_formula_test.gd` — must exist and pass (floor/max0, chassis lookup, pipeline-composition discriminator)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (Formula 1 consumes Formula 2 / 2b upgraded values)
- Unlocks: Story 010 (content stat budgets validated against final-stat behavior); Assembly/Combat epics consume this function
