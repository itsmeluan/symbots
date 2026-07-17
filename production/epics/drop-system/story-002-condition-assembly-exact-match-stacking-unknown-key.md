# Story 002: Condition assembly — exact-match, multiplicative stacking, unknown-key tolerance

> **Epic**: Drop System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping (primary); ADR-0006: RNG Service & Determinism
**ADR Decision Summary**: A part's `drop_conditions` are read read-only from the typed catalog; an unknown condition key is **logged as a content error and skipped**, never a crash, and its multiplier is not applied (ADR-0003). The assembled multiplier product feeds the DS-1 roll on the injected seeded RNG (ADR-0006).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure logic over the fired-condition Set and each part's `drop_conditions` array. Matching is **exact string** — no case-fold, no substring. Multipliers compose **multiplicatively** (`Π`), only for conditions present in the fired set. `0.05 × 1.5 × 1.5 = 0.11250000000000002` and `0.25 × 1.5 = 0.375` in IEEE 754 — the stated draws clear the ulp; assert with `< 1e-9` where comparing rates. Break-event keys and outcome-fact keys are plain strings handled identically.

**Control Manifest Rules (this layer)**:
- Required: content defs read-only via the injected catalog; diagnostics via LogSink `warn(code, detail)`; exactly one content error per unknown key.
- Forbidden: content-def mutation; `push_warning`/`push_error` from `src/`; content-enum reordering.
- Guardrail: an unknown key never aborts the roll — all valid conditions on the part still evaluate.

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [ ] **AC-DS-22** (BLOCKING, Unit): condition matching is exact-string *(verifies R5)*. Part condition `arm_broken`; fired set = {`ARM_BROKEN`, `arm_break`} (neither is `arm_broken`) → no multiplier applied, rate = 0.25, no log error. FAIL: case-insensitive/substring match applies ×1.5.
- [ ] **AC-DS-23** (BLOCKING, Unit): multipliers stack multiplicatively; unfired conditions excluded *(verifies R3)*. Prototype `delta_core` (0.05), three ×1.5 conditions, exactly 2 of 3 fired → rate = clamp(0.05 × 1.5 × 1.5) = **0.1125**. Scenario A: draw 0.11 → drops (none-applied impl at 0.05 and additive impl at 0.10 both fail to drop). Scenario B: draw 0.15 → no drop (an all-three-applied impl at 0.16875 would wrongly drop). FAIL: A does not drop, or B drops.
- [ ] **AC-DS-07** (BLOCKING, Unit): unknown condition key logged + skipped *(verifies EC-DS-03)*. Rare `servo_arm` with `arm_broken`(×1.5), `UNKNOWN_KEY_XYZ`(×2.0), `targeting_active`(×1.3); `arm_broken`+`targeting_active` fired; draw 0.41 → rate = clamp(0.25 × 1.5 × 1.3) = 0.4875, drops, exactly one content error names `UNKNOWN_KEY_XYZ`, no crash. Second: draw 0.70 → no drop (applying the ×2.0 would give 0.975 and falsely drop). FAIL: exception; unknown multiplier applied; no log.
- [ ] **AC-DS-25** (BLOCKING, Unit): outcome-fact conditions apply their multipliers — unit half of AD-1. Part with `zero_defeats`(×1.5), base 0.25; fired set = {`zero_defeats`} (injected directly as a Set of strings) → rate = clamp(0.25 × 1.5) = **0.375**. Scenario A: draw 0.30 → drops (an ignore-multiplier impl at 0.25 does not). Scenario B: draw 0.40 → no drop (an additive `0.25 + 0.5 = 0.75` impl would wrongly drop). FAIL: A does not drop; B drops.

---

## Implementation Notes

*Derived from ADR-0003 + ADR-0006 Implementation Guidelines:*

- Build the fight's fired-condition set from `fired_break_events` + injected outcome facts (Rule 3). For each rolled part, walk its `drop_conditions` array; a condition contributes its multiplier **iff its key is exactly in the fired set** (AC-DS-22). Match with plain `==`/`Set.has` on the string — no normalization.
- Compose contributions as a running product (`Π`), starting at 1.0 (AC-DS-23). Only fired conditions multiply in; unfired ones are excluded (not additively summed).
- Outcome-fact keys (`zero_defeats`, `defeated_by_thermal`, `no_repairs_used`, `flawless`) are plain strings and multiply identically to break-event keys (AC-DS-25). This story injects the fired set directly; the TBC-provenance wire is deferred (AD-1, epic note).
- An unknown condition key (not in the Rule 5 vocabulary) is logged once via LogSink as a content error and **skipped** — its multiplier is not applied, all valid conditions still evaluate, no crash (AC-DS-07). Do not throw; do not apply the unknown multiplier.
- The assembled product is handed to the DS-1 clamp/roll built in Story 001.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the DS-1 clamp + strict-`<` roll (this story assembles the multiplier product that feeds it).
- Story 003: pool dedup / independent rolls / empty pool.
- Stories 004/005: pity credit from fired conditions (this story only assembles the per-fight multiplier; DS-2's `c` credit is Story 004).
- **Deferred (epic note):** AD-1 (TBC outcome-fact provenance — the wire that populates the fired set with real outcome facts); AD-5 (Part-Break key-match integration test). This story assumes a directly-injected fired set.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-DS-22**: exact-string match.
  - Given: part condition `arm_broken`; fired set {`ARM_BROKEN`, `arm_break`}.
  - Then: rate = 0.25, no multiplier, no log error.
  - Edge cases: case-insensitive/substring impl applies ×1.5 and fails.
- **AC-DS-23**: multiplicative stacking, 2-of-3.
  - Given: Prototype 0.05, three ×1.5, 2 fired → 0.1125.
  - Then: draw 0.11 drops; draw 0.15 no drop.
  - Edge cases: none-applied (0.05), additive (0.10), all-three (0.16875) each break on one of the two draws.
- **AC-DS-07**: unknown key.
  - Given: `arm_broken`(×1.5), `UNKNOWN_KEY_XYZ`(×2.0), `targeting_active`(×1.3); first two-of-three fired minus unknown; draw 0.41 then 0.70.
  - Then: rate 0.4875, drops at 0.41, no drop at 0.70; exactly one error names the unknown key; no crash.
- **AC-DS-25**: outcome-fact multiplier.
  - Given: `zero_defeats`(×1.5), base 0.25, fired {`zero_defeats`} → 0.375.
  - Then: draw 0.30 drops; draw 0.40 no drop.
  - Edge cases: ignore-multiplier (0.25) fails A; additive (0.75) fails B.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/condition_assembly_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DS-1 clamp/roll + host).
- Unlocks: None directly (feeds pity stories' condition-credit, but those depend on 001).
