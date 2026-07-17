# Story 007: CP-F3 level-growth step (4b) & pipeline ordering

> **Epic**: Symbot Assembly System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: timeboxed 4h (carries the binding cross-system DoD gate)
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/symbot-assembly.md`
**Requirement**: `TR-sa-004` (CP-F3 level-growth added post-chassis-multiply, pre-synergy — Rule 6 step 4b)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: CP-F3 is inserted inside `StatPipeline.derive` **after** the chassis multiply + floor (SA-F1 output) and **before** synergy (SYN-F4, applied later at BATTLE_INIT): `final_stat[k] += level_growth[k] × (core_level − 1)`. It bypasses the chassis modifier (flat add, not amplified) and reads `level_growth` only from the CORE part.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Integer flat addition, no new floor/ceil expression (no float scan needed). `level_growth` is a `Dictionary[StringName, int]` on the CORE `PartDef` (ADR-0003). `core_level` arrives as an injected parameter to `derive` — sourced from `CoreProgression` (Approved GDD, no code yet); stub in tests.

**Control Manifest Rules (this layer — Core):**
- Required: The single SA-F1→CP-F3→SYN-F4 composition point — CP-F3 lives inside `StatPipeline.derive`, nowhere else (ADR-0005).
- Required: `final_stat` (post-CP-F3) is what downstream synergy composes on top of — synergy is still **not** included in Assembly's stored `final_stat` (Rule 8).
- Forbidden: `inline_stat_composition` — do not apply CP-F3 in a second location; one insertion point only.

---

## Acceptance Criteria

*From GDD `design/gdd/symbot-assembly.md`, scoped to this story:*

- [x] **AC-SA-15** — CP-F3 level-growth is inserted AFTER SA-F1 and BEFORE synergy. Setup: chassis archetype multiplier `M=1.2` on `target_stat`; CORE `level_growth={target_stat: 10}` at **level 5** (CP-F3 contribution `10×(5−1)=40`); equipped parts produce an SA-F1 output of **120** for `target_stat` (100 raw × 1.2 archetype). **Pass when**: the `final_stat["target_stat"]` exposed to downstream synergy is exactly **160** (`=120+40`, flat after the chassis multiply); **NOT 168** (`=(100+40)×1.2`, which results from inserting CP-F3 *before* SA-F1 so the chassis modifier wrongly amplifies growth); and **NOT** any value reflecting CP-F3 applied *after* synergy.
  - [x] At `core_level == 1`: CP-F3 contribution is 0 for all stats (`10×(1−1)=0`).
  - [x] Unknown stat key in `level_growth` is skipped with a content warning (same pattern as EC-SA-05 / TR-cp-014).

> **DoD gate (binding — qa-lead R3-C / R4-B1, ST-2).** AC-SA-15 **is the same test as Core Progression AC-CP-18** (DEFERRED there, awaiting this insertion). Passing AC-SA-15 is a **required Definition-of-Done item** on this story: it MUST NOT be marked complete with the CP-F3 step inserted but this ordering untested — a wrong insertion point (before SA-F1, or after synergy) produces a different `final_stat` that no other non-deferred AC catches. Cross-ref: `design/gdd/symbot-core-progression.md` AC-CP-18.

---

## Implementation Notes

*Derived from Assembly Rule 6 step 4b (CP-F3) and ADR-0005 pipeline order:*

- This story replaces the Story-001 step-4b stub in `StatPipeline.derive` with the real CP-F3 contribution. Insert it at exactly this point in the pipeline:
  ```
  → maxi(0, floor_eps(sum × chassis_modifier))         = SA-F1 output (steps 1–4)
  → + level_growth[S] × (core_level − 1)               = CP-F3 (step 4b — THIS story)
  → stored final_stat   (synergy NEVER included — Rule 8)
  ```
- CP-F3 is a **flat add after the floor** — it is not multiplied by the chassis modifier and is not floored again (the growth values are integers; `core_level − 1` is an integer). This is what makes 160 ≠ 168.
- Read `level_growth` **only** from the equipped CORE part (Assembly ignores `level_growth` on non-CORE parts — TR-cp-009 / TR-part-012). The `derive` signature already carries `level_growth` (the CORE part's dict) and `core_level`.
- **Unknown key in `level_growth`**: `log.warn` and skip (mirrors EC-SA-05 / TR-cp-014). Do not add the key to `final_stat`.
- Power stats (`physical_power` / `energy_power`) must never appear in `level_growth` (Core Progression Rule 6a / TR-cp-010) — that is enforced by content validation in the Core Progression epic, not here; but do not special-case them: derive generically over whatever keys `level_growth` carries, and the validator keeps power stats out.
- **`core_level` source**: injected via the `derive` call. In the equip path (Story 002), `SymbotBuild` obtains it from the injected `CoreProgression` (`CoreProgressionRecord.level`, re-derived from `cumulative_xp`). For this story's integration test, use a stub `CoreProgression` returning level 5 (and 1 for the boundary case).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: steps 1–4 of `derive` (the SA-F1 output this story adds onto).
- **Story 002**: equip mechanics — this story wires `core_level` through the equip → derive call it established.
- **Core Progression epic**: the `CoreProgression` ledger, `cumulative_xp` → level derivation (CP-F1), `register_core`, `apply_battle_result`, the `can_equip` gate. This story consumes `core_level` as an injected value only.
- **SYN-F4 / synergy**: applied later at BATTLE_INIT by TBC — this story only guarantees CP-F3 lands *before* it.

---

## QA Test Cases

*Integration spec — exercises the full equip → SA-F1 → CP-F3 → pre-SYN-F4 handoff with a stub `CoreProgression` (level fixture) and a spy `LogSink`.*

- **AC-SA-15 — CP-F3 ordering (160-not-168 discriminator)**
  - Given: test `BalanceConfig` with a chassis archetype applying ×1.2 to `target_stat`; equipped parts whose raw `stat_bonuses` sum to 100 on `target_stat` (SA-F1 output 120); CORE `level_growth={target_stat: 10}`; stub `CoreProgression` reporting level 5.
  - When: the build derives `final_stat` through the equip path (or a direct `derive` with these params).
  - Then: `final_stat["target_stat"] == 160`.
  - Edge cases: assert **not 168** (CP-F3-before-SA-F1) and **not** any post-synergy value; this is the load-bearing discriminator.

- **AC-SA-15 (boundary) — level 1 → zero growth**
  - Given: same fixture but stub `CoreProgression` reporting level 1.
  - When: derive.
  - Then: `final_stat["target_stat"] == 120` (CP-F3 contributes `10×0=0`).

- **AC-SA-15 (content) — unknown level_growth key skipped**
  - Given: CORE `level_growth={target_stat: 10, "bogus_key": 5}`, level 5, spy `LogSink`.
  - When: derive.
  - Then: `target_stat` grows by 40; `final_stat.has(&"bogus_key") == false`; spy recorded one warning; no exception.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/symbot_assembly/cp_f3_ordering_test.gd` — must exist and pass (GUT). **This is the DoD gate** — the story cannot close without AC-SA-15 passing (satisfies the deferred Core Progression AC-CP-18).

**Status**: [x] Done — GUT green 2026-07-16 (suite 657 tests / 53 scripts, was 631/46)

---

## Dependencies

- Depends on: **Story 001** (SA-F1 steps 1–4, with the step-4b stub this story replaces), **Story 002** (equip → derive call carrying `core_level`). Injected **CoreProgression** (Approved GDD, no code) stubbed in tests — not a blocker.
- Unlocks: Story 006's preview inherits CP-F3 automatically; satisfies Core Progression **AC-CP-18** (cross-epic).

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 1/1 AC (3 sub-cases) passing — AC-SA-15 the **binding DoD gate**: CP-F3 inserted AFTER SA-F1 and BEFORE synergy → `final_stat["target_stat"] == 160` (`=120 + 10×(5−1)`, flat post-floor add), **NOT 168** (`=(100+40)×1.2`, the wrong before-SA-F1 insertion) and not any post-synergy value; level-1 boundary → contribution 0 (120); unknown `level_growth` key skipped + one warn. COVERED by `tests/integration/symbot_assembly/cp_f3_ordering_test.gd` (3 tests).
**DoD gate DISCHARGED**: AC-SA-15 **is the same test as Core Progression AC-CP-18** (deferred there awaiting this insertion — `design/gdd/symbot-core-progression.md:412`). The story does NOT close with the CP-F3 step inserted-but-untested; the 160-not-168 discriminator is green. **Cross-epic note (not this epic's edit):** AC-CP-18 in the Core Progression GDD stays marked DEFERRED because that epic has no code/stories yet — when the Core Progression epic is built it may reference this passing test to satisfy AC-CP-18 rather than re-authoring it.
**Deviations**: None. CP-F3 lives at exactly one insertion point inside `StatPipeline.derive` (`stat_pipeline.gd:86` — `sa_f1 += growth * (core_level - 1)`), a flat add after the chassis floor, not re-multiplied and not re-floored (`inline_stat_composition` forbidden — no second location). `level_growth` is read ONLY from the CORE slot (`symbot_build.gd:227`, TR-cp-009). Integer flat add → no new floor/ceil, no python3 scan owed. `core_level` arrives injected (stub CoreProgression at level 5 / 1 in tests; real ledger is the Core Progression epic).
**Test Evidence**: Integration — `tests/integration/symbot_assembly/cp_f3_ordering_test.gd` (**the DoD gate**); full GUT suite 657/657 green (Godot 4.7 headless).
**Code Review**: Complete — `/code-review` this session, verdict APPROVED. Reviewed inline as godot-gdscript-specialist (1M-context constraint).
