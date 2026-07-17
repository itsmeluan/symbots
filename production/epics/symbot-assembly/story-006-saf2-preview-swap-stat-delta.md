# Story 006: SA-F2 preview_swap (stat delta)

> **Epic**: Symbot Assembly System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/symbot-assembly.md`
**Requirement**: `TR-sa-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: `SymbotBuild.preview_swap(candidate, slot) -> Dictionary` (SA-F2): a **full-pipeline hypothetical recompute** in memory — including CP-F3, excluding synergy — with no signal, no state change, no Inventory write. The stat delta is `hypothetical_final_stat[S] − current_final_stat[S]` across all 11 keys.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Reuses the same Layer-1 `StatPipeline.derive` over hypothetical inputs — the pipeline-composition lesson: a preview that composes only the *head* of the pipeline is a defect class this project has shipped once (the MOVE-F1 seam). Preview must run the whole pipeline, not a partial diff. Purity is engine-unenforced — proven by test.

**Control Manifest Rules (this layer — Core / cross-ref Presentation):**
- Required: Previews reuse the pure core (`StatPipeline` hypothetical derive) — never reimplement a formula for display (ADR-0005 / ADR-0008 Presentation rule).
- Required: `final_stat` / delta are base stats only (no synergy) — Rule 8; Workshop UI must not read a synergy-inclusive total for the delta.
- Forbidden: `runtime_content_mutation` — the hypothetical build is in-memory; the live manifest, `final_stat` cache, signals, and Inventory are untouched (ADR-0003/0005).

---

## Acceptance Criteria

*From GDD `design/gdd/symbot-assembly.md`, scoped to this story:*

- [x] **AC-SA-08** — SA-F2 delta is correctly signed and emits no signals. Setup: CHASSIS = `balanced_frame` (`BALANCED_FRAME`, ×1.0 all stats; `stat_bonuses["structure"]=10, ["mobility"]=5`); all other parts 0. `current_final_stat["structure"]=10, ["mobility"]=5`. Candidate CHASSIS: `BALANCED_FRAME`, `structure=12, mobility=2`. Call `compute_stat_delta(CHASSIS, candidate_part)`. **Pass when**: `delta["structure"]==+2`; `delta["mobility"]==-3`; `delta["targeting"]==0` (full 11-stat hypothetical recompute, not a partial diff on changed keys only); **no** `part_equipped`/`stats_changed` emitted; CHASSIS slot still holds `balanced_frame`; `current_final_stat["structure"]` unchanged at 10 (hypothetical does not write live); Inventory count unchanged (no displacement).
- [x] **EC-SA-09** — Chassis-swap preview may be non-zero for all 11 stats (the archetype modifier re-applies across the full pipeline). The delta surfaces all 11 stat changes, not just stats the new chassis contributes to. *(Verified within AC-SA-08 by the full-11-key recompute; the `delta["targeting"]==0` present-key assertion is the discriminator against a partial diff.)*

---

## Implementation Notes

*Derived from ADR-0005 Layer 2 `preview_swap` and Assembly SA-F2:*

- Add `preview_swap(candidate_part, slot_type) -> Dictionary` (the GDD also names the read-only entry `compute_stat_delta(slot, candidate)` — expose one method; keep naming consistent with the ADR `preview_swap`, and alias/label to match the AC's `compute_stat_delta` call if the test references that name).
- Build a **hypothetical manifest** = current 8-slot manifest with `candidate_part` installed in `slot_type` and the current occupant removed (in memory only — do **not** touch Inventory, do **not** mutate the live manifest).
- Run the **same** `StatPipeline.derive(...)` over the hypothetical manifest — full pipeline including CP-F3 (Story 007), excluding synergy (Rule 8). Compute `delta[S] = hypothetical[S] − current_final_stat[S]` for all 11 canonical keys.
- **Purity is the load-bearing property**: no `part_equipped`/`stats_changed` emit; no write to the cached `final_stat`; no Inventory add/remove; the live manifest slot unchanged after the call. Assert every one of these in the test (signal spy + Inventory spy + slot re-read).
- **Chassis previews are the critical case** (EC-SA-09): because the candidate changes `chassis_archetype`, the modifier table re-applies across all 11 stats, so the delta is non-zero for stats the candidate contributes nothing to via `stat_bonuses`. This falls out naturally from running the full pipeline — but only if the hypothetical recompute iterates all 11 keys (Story 001 guarantee). Do not shortcut to diffing only the candidate's `stat_bonuses` keys.
- Depends on Story 007's CP-F3 step being present in `derive` for the CP-F3-inclusive guarantee; if Story 007 is not yet merged, the preview is still correct for the AC-SA-08 fixture (level-1 core → CP-F3 contribution 0), but note the ordering dependency so the preview inherits CP-F3 automatically once wired.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: the committing `equip_part` path (preview is its non-mutating twin).
- **Story 007**: the CP-F3 step itself — preview reuses `derive`, so it inherits CP-F3 for free.
- **Synergy epic & Workshop UI GDD**: synergy-inclusive delta at threshold crossings (a Deferred Design Obligation) — Assembly's delta is base-stat only (Rule 8); surfacing synergy impact separately is Workshop UI's job.
- **Workshop UI**: the tap-to-preview / long-press trigger and the visual sprite preview — Assembly only exposes the read-only delta call.

---

## QA Test Cases

*Logic specs — drive `preview_swap`/`compute_stat_delta` on a `SymbotBuild` (stub Inventory/CoreProgression, signal + Inventory spies).*

- **AC-SA-08 — Signed delta, full recompute, zero side effects**
  - Given: CHASSIS = `balanced_frame` (`BALANCED_FRAME`, ×1.0 all; `structure=10, mobility=5`); all others 0. Assert `current_final_stat["structure"]==10, ["mobility"]==5`. Candidate CHASSIS `BALANCED_FRAME` `structure=12, mobility=2` present in stub Inventory.
  - When: `compute_stat_delta(CHASSIS, candidate)`.
  - Then: `delta["structure"]==+2`; `delta["mobility"]==-3`; `delta["targeting"]==0`; signal spy zero emissions; Inventory spy zero add/remove; CHASSIS slot still `balanced_frame`; `current_final_stat["structure"]` still 10.
  - Edge cases: `delta` contains all 11 canonical keys (present-key guard against partial diff).

- **EC-SA-09 — Chassis-swap non-zero across uncontributed stats**
  - Given: current chassis with a ×1.20 mobility modifier and a LEGS `mobility` contributor; candidate chassis with a ×0.80 mobility modifier and `stat_bonuses` that do **not** include mobility.
  - When: `compute_stat_delta(CHASSIS, candidate)`.
  - Then: `delta["mobility"] != 0` even though the candidate contributes no mobility via `stat_bonuses` (proves modifier re-application through the full pipeline).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/symbot_assembly/preview_swap_test.gd` — must exist and pass (GUT). The purity assertions (no signals / no Inventory write / no live-cache mutation) are part of the required suite (ADR-0005 Validation Criteria: "purity tests").

**Status**: [x] Done — GUT green 2026-07-16 (suite 657 tests / 53 scripts, was 631/46)

---

## Dependencies

- Depends on: **Story 001** (`StatPipeline.derive`), **Story 002** (`SymbotBuild` manifest + `final_stat` cache). Soft-ordering after **Story 007** so the preview inherits CP-F3 (not required for the level-1 AC-SA-08 fixture).
- Unlocks: Workshop UI stat-delta preview (Presentation epic, later).

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 2/2 passing (AC-SA-08 SA-F2 delta correctly signed — structure `+2`, mobility `-3`, `targeting==0` present-key guard proving a full 11-stat hypothetical recompute not a partial diff; **zero** `part_equipped`/`stats_changed` emissions; Inventory count unchanged; live CHASSIS slot + `current_final_stat` untouched. EC-SA-09 chassis-swap delta non-zero across stats the candidate contributes nothing to, from the modifier re-applying through the full pipeline) — all COVERED by `tests/unit/symbot_assembly/preview_swap_test.gd` (2 tests).
**Deviations**: None to the AC. `preview_swap`/`compute_stat_delta` reuse the pure `StatPipeline.derive` over a `_manifest.duplicate()` hypothetical (`symbot_build.gd:181`) — the whole pipeline (incl. CP-F3), never a formula reimplemented for display (the MOVE-F1 pipeline-composition lesson honored). Purity is the load-bearing property and is engine-unenforced → proven by the signal/Inventory/slot spies in the test.
**Advisory (logged, NOT blocking)**: the preview takes a `PartDef` and hard-codes the hypothetical candidate at **tier +0** (`symbot_build.gd:183`), while equip installs the real `PartInstance` at its `tier`. A future Workshop preview of an *owned* candidate at tier > 0 would show a delta that differs from what equip realizes (F2/F2b scale by tier). AC-SA-08 is a tier-0 fixture so it passes and the pipeline is correct — this is a latent API limitation for the Presentation/Workshop-UI epic (add an instance-taking overload then). Logged ADVISORY to `docs/tech-debt-register.md`.
**Test Evidence**: Logic — `tests/unit/symbot_assembly/preview_swap_test.gd` (includes the ADR-0005 purity assertions); full GUT suite 657/657 green (Godot 4.7 headless).
**Code Review**: Complete — `/code-review` this session, verdict APPROVED WITH NOTES (the tier-0 preview advisory above; no required change). Reviewed inline as godot-gdscript-specialist (1M-context constraint).
