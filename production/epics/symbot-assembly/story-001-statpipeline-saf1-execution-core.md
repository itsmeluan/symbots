# Story 001: StatPipeline SA-F1 execution core (steps 1–4)

> **Epic**: Symbot Assembly System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/symbot-assembly.md`
**Requirement**: `TR-sa-001`, `TR-sa-002`, `TR-sa-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary)
**Secondary**: ADR-0003: Content Resource Loading & Schema Mapping (frozen `PartDef` typed getters)
**ADR Decision Summary**: A pure-function formula core in `src/core/stats/` with an injected `BalanceConfig` + `LogSink`. `StatPipeline.derive(...)` is the *sole* SA-F1 executor — F2/F2b sign-routing per part → 8-part sum → chassis multiply → `maxi(0, floor_eps(·))`. No new autoloads; every function GUT-testable against the GDD worked examples.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure GDScript math — no scene/render surface. `maxi()`/`floori()`/`floor()` are pre-cutoff `@GlobalScope` stable. `Dictionary[StringName, int]` typed dicts (`stat_bonuses`) are 4.4+ and already committed by ADR-0003's `PartDef`; the `.tres` round-trip is verified by the Foundation content pass — this story consumes already-loaded defs, it does not author new `.tres`. Any *new* floor/ceil expression added here requires a python3 IEEE-754 scan logged in the story evidence (ADR-0005 constraint) — but SA-F1 reuses the existing `StatMath.floor_eps` / `UpgradeFormula` primitives, which are already scanned.

**Control Manifest Rules (this layer — Core)**:
- Required: The pure formula core lives in `src/core/stats/`; owners are DI RefCounted objects, not autoloads (ADR-0005).
- Required: A single `BalanceConfig` `.tres` is the sole tuning source; constants arrive injected (ADR-0005).
- Forbidden: `runtime_content_mutation` — copy primitive fields out of `PartDef`; never mutate or `duplicate()` a def (ADR-0003).
- Forbidden: `global_push_diagnostics` — content warnings go to the injected `LogSink`, never `push_warning`/`push_error` (ADR-0002), so they are assertable in GUT.

---

## Acceptance Criteria

*From GDD `design/gdd/symbot-assembly.md`, scoped to this story:*

- [x] **AC-SA-02** — Formula pipeline, 3 concrete non-degenerate sub-cases:
  - [x] *(a) F2 floor discrimination*: Part A `LEGS, mobility=7, tier=+1`; Light Frame chassis (×1.20 mobility). Pipeline yields `final_stat["mobility"] == 9` (not `10`, which `round()` at step 4 would give). The intermediate F2 output must be verifiably `8` (integer) via a `compute_upgraded_stat(part, stat_key)` (or equivalent) introspection method.
  - [x] *(b) F2b epsilon*: `base=-15, tier=+2` → returns `−5`, not `−6` (IEEE-754 `5.000000000000001` without the epsilon nudge would `ceil` to 6).
  - [x] *(c) F1 chassis floor*: single CHASSIS part `structure=10`, Balanced Frame (×1.00) → `final_stat["structure"] == 10`.
- [x] **AC-SA-11** — Unknown stat key in `stat_bonuses` is skipped without crash. Part with `stat_bonuses={"structure":10, "unknown_key":5}` → `final_stat["structure"]` normal; `"unknown_key"` absent from `final_stat`; content warning logged to the injected sink; no exception.
- [x] **AC-SA-13** — Recharge sum exceeding 30 is reported, not clamped. ENERGY_CELL/CORE/WEAPON each contribute `recharge=15` → after step-2 sum `sum["recharge"]==45`; a content **error** is logged on the pre-chassis-multiply sum noting it exceeds the design max of 30; `final_stat["recharge"]==45`; no crash; no silent clamp to 30.

---

## Implementation Notes

*Derived from ADR-0005 Layer 1 (`src/core/stats/`) and the SA-F1 pipeline contract:*

- Create `class_name StatPipeline extends RefCounted` in `src/core/stats/stat_pipeline.gd`. Static-only, pure. Signature per ADR-0005:
  `derive(equipped, chassis_archetype, core_level, level_growth, cfg: BalanceConfig, log: LogSink) -> Dictionary`.
  **This story implements steps 1–4 only** (part-derived SA-F1 output). CP-F3 step 4b (`core_level`, `level_growth`) is Story 007 — accept the params in the signature now but leave step 4b as a no-op stub with a `# Story 007` marker so the contract is stable.
- Reuse the existing Foundation primitives — **do not reimplement**:
  - Per-part per-stat: route by sign via `UpgradeFormula.upgraded_value_for_part(part, stat, tier, cfg)` (`>0`→F2, `<0`→F2b, `=0`→0). The sign-routing already lives in `UpgradeFormula`.
  - Sum + chassis multiply + floor + clamp: `TotalStatFormula.compute_final_stat(stat_key, upgraded_values: Array[int], chassis_archetype, cfg)` already does `maxi(0, floor_eps(sum × modifier))` per stat. `StatPipeline` iterates the canonical 11 keys and calls it once per key.
- Iterate the **canonical 11 stat keys** from `cfg` (Assembly key list), not the union of part keys — this guarantees every stat is present in `final_stat` even when no part contributes (needed downstream by AC-SA-05's `targeting==0` present-key assertion).
- **AC-SA-11**: when a part's `stat_bonuses` carries a key outside the canonical 11, `log.warn` and skip that key (EC-SA-05 / Part DB EC-08). Do not add it to `final_stat`.
- **AC-SA-13**: after step-2 summation, if `sum["recharge"] > 30`, `log.error` on that pre-multiply value. Do **not** clamp — F1's `maxi(0, floor_eps(·))` still applies and the final value may exceed 30. This is a content-validation backstop, not a runtime clamp.
- Expose `compute_upgraded_stat(part, stat_key, tier, cfg) -> int` (or reuse `UpgradeFormula.upgraded_value_for_part`) so AC-SA-02(a) can assert the intermediate F2 output is the integer `8`, not `8.05`.
- `EPSILON` stays a `const` in `StatMath` — never relocate to `BalanceConfig` (F2b nudge is load-bearing: 26 inputs flip without it).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 007**: CP-F3 level-growth (Rule 6 step 4b) and its post-chassis/pre-synergy ordering. Accept the `core_level`/`level_growth` params but stub step 4b.
- **Story 002**: `SymbotBuild.equip_part`, the eager recompute trigger, and `stats_changed` emission. `StatPipeline.derive` is pure and emits nothing.
- **Story 003**: equip-triggered chassis-swap recompute correctness (AC-SA-05) and stability (AC-SA-07).
- **Stories 004/005**: move-pool and passive-pool derivation.
- **Story 006**: `preview_swap` (SA-F2 delta).

---

## QA Test Cases

*Derived from the GDD acceptance criteria (test-spec grade). Implement against these — do not invent new cases during implementation. Use a spy `LogSink` and a test `BalanceConfig`.*

- **AC-SA-02 (a) — F2 floor discrimination**
  - Given: Part A `slot_type=LEGS, stat_bonuses["mobility"]=7, upgrade_tier=+1`; chassis = Light Frame (×1.20 mobility); all other parts contribute 0 to mobility.
  - When: `StatPipeline.derive(...)` runs.
  - Then: `final_stat["mobility"] == 9`; and `compute_upgraded_stat(partA, &"mobility", 1, cfg) == 8` (intermediate integer, not 8.05).
  - Edge cases: assert **not** `10` (proves `floor`, not `round`, at step 4).

- **AC-SA-02 (b) — F2b epsilon (load-bearing)**
  - Given: a part stat `base=-15, upgrade_tier=+2`.
  - When: the F2b path runs (`UpgradeFormula.upgraded_drawback` / `upgraded_value_for_part`).
  - Then: result `== −5`.
  - Edge cases: assert **not** `−6` (epsilon nudge on `5.000000000000001`).

- **AC-SA-02 (c) — F1 chassis floor**
  - Given: single CHASSIS part `stat_bonuses["structure"]=10`, Balanced Frame (×1.00); all others 0 structure.
  - When: `derive(...)` runs.
  - Then: `final_stat["structure"] == 10`.

- **AC-SA-11 — Unknown stat key skipped**
  - Given: a part `stat_bonuses={"structure":10, "unknown_key":5}`.
  - When: `derive(...)` runs with a spy `LogSink`.
  - Then: `final_stat["structure"]` computed normally; `final_stat.has(&"unknown_key") == false`; spy sink recorded exactly one warning; no exception raised.
  - Edge cases: a part whose ONLY key is unknown → all canonical stats still present in `final_stat`.

- **AC-SA-13 — Recharge sum > 30 reported, not clamped**
  - Given: ENERGY_CELL `recharge=15`, CORE `recharge=15`, WEAPON `recharge=15` (content violation); all other stats 0.
  - When: `derive(...)` runs with a spy `LogSink`.
  - Then: the step-2 sum is 45; spy sink recorded a content **error** citing the >30 breach on the pre-multiply sum; `final_stat["recharge"] == 45`; no crash; no clamp to 30.
  - Edge cases: `sum["recharge"] == 30` → no error (boundary, inclusive max is allowed).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/symbot_assembly/stat_pipeline_derive_test.gd` — must exist and pass (GUT).
Any new floor/ceil expression introduced here also needs a python3 IEEE-754 scan logged in the evidence (ADR-0005). Reusing `StatMath`/`UpgradeFormula`/`TotalStatFormula` avoids introducing one.

**Status**: [x] Done — GUT green 2026-07-16 (suite 657 tests / 53 scripts, was 631/46)

---

## Dependencies

- Depends on: None — the Foundation primitives (`StatMath`, `UpgradeFormula`, `TotalStatFormula`, `BalanceConfig`) already exist and are green.
- Unlocks: Story 002 (equip calls `derive`), Story 003, Story 006, Story 007.

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 3/3 passing (AC-SA-02 pipeline discrimination — (a) F2 floor 9-not-10 + intermediate integer `8` via `compute_upgraded_stat`, (b) F2b epsilon −5-not-6, (c) F1 chassis floor; AC-SA-11 unknown `stat_bonuses` key skipped + one warn; AC-SA-13 recharge sum 45 reported-not-clamped, boundary 30 inclusive) — all COVERED by `tests/unit/symbot_assembly/stat_pipeline_derive_test.gd` (7 tests).
**Deviations**: None. `StatPipeline.derive` is the single SA-F1 composition point (`stat_pipeline.gd:50`); it reuses the already-epsilon-scanned `UpgradeFormula`/`TotalStatFormula`/`StatMath` primitives and introduces **no new floor/ceil** — no python3 IEEE-754 scan owed (ADR-0005 reuse). Diagnostics route through the injected `LogSink` (no `push_error`/`push_warning`); frozen `PartDef`s read-only via `stat_bonuses.get(...)`. Step-4b CP-F3 was left a real add here (not a stub) since Story 007 landed in the same pass — the ordering is verified by Story 007's DoD-gate test, not weakened here.
**Test Evidence**: Logic — `tests/unit/symbot_assembly/stat_pipeline_derive_test.gd`; full GUT suite 657/657 green, 3934 asserts, 53 scripts (Godot 4.7 headless).
**Code Review**: Complete — `/code-review` this session, verdict APPROVED (no required changes). Reviewed inline as godot-gdscript-specialist (subagents unavailable this session-mode per the 1M-context constraint).
