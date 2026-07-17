# Story 003: Eager recompute & chassis-swap correctness

> **Epic**: Symbot Assembly System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/symbot-assembly.md`
**Requirement**: `TR-sa-006` (final stats locked/stable; no recompute without an equip), exercises `TR-sa-003` (chassis modifier re-applied across all 11 stats)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: SA-F1 runs eagerly on every equip; the stored `final_stat` is a full 11-key dictionary. A chassis swap re-applies the archetype modifier table across all stats (not only stats the new chassis contributes to). Between equips, reads are passive — no recompute, no signal.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure integer stat math. The battle-start snapshot half of TR-sa-006 (immutable-at-BATTLE_INIT) lives in `CombatantSnapshot` (TBC epic, TR-tbc-002) — **out of scope here**; this story covers only the Assembly-side "stable between equip events" guarantee.

**Control Manifest Rules (this layer — Core)**:
- Required: `final_stat` is base stats only (no synergy) — Rule 8; composition with synergy happens later via `effective_stat` (ADR-0005).
- Forbidden: `mid_battle_stat_recompute` — never call `StatPipeline.derive` after BATTLE_INIT; the Assembly-side eager recompute happens only on Workshop equips (ADR-0005).
- Forbidden: `runtime_content_mutation` — recompute reads frozen `PartDef`, never mutates (ADR-0003).

---

## Acceptance Criteria

*From GDD `design/gdd/symbot-assembly.md`, scoped to this story:*

- [x] **AC-SA-05** — Chassis swap forces a full 11-stat recompute. Pre-swap (Light Frame `structure=10` ×0.85, ×1.20 mobility; LEGS `swift_legs mobility=7`; all others 0): `final_stat["structure"]==8`, `final_stat["mobility"]==8`. Equip Heavy Frame (`structure=8`, ×1.25 structure, ×0.80 mobility). **Pass when**: `final_stat["structure"]==10`; `final_stat["mobility"]==5`; `final_stat["targeting"]==0`. The mobility change (8→5) proves the chassis multiplier re-applies to the non-CHASSIS LEGS part; the `targeting==0` present-key assertion proves all 11 keys are recomputed (an impl that only touches chassis-contributed stats would omit uncontributed keys).
- [x] **AC-SA-07** — `final_stat` is stable between equip events. Using the AC-SA-05 post-swap Heavy Frame state: (a) `final_stat["structure"]==10` and `final_stat["mobility"]==5` (stored values correct, not merely stable); (b) a second read with no intervening equip returns a dictionary identical to the first; (c) **no** `stats_changed` emits during the second read (the read is passive, not a pipeline re-trigger).

---

## Implementation Notes

*Derived from ADR-0005 SA-F1 pipeline order and Assembly Rules 3/6:*

- This story validates the **wiring** established in Story 002 (equip → eager `derive` → store) produces correct, stable output. If Stories 001/002 are implemented per contract, this is largely a test-authoring + defect-catching story; add fixes to `StatPipeline`/`SymbotBuild` only if an AC fails.
- **AC-SA-05 correctness hinges on Story 001 iterating the canonical 11 keys**, not the union of contributing part keys — confirm `final_stat` always carries all 11 keys after a swap (the `targeting==0` assertion is the guard). If it does not, the fix belongs in `StatPipeline.derive` (Story 001 territory) — flag it.
- **AC-SA-07 (c)** requires that a plain read of `final_stat` does not call `derive` or emit `stats_changed`. Ensure `final_stat` is a stored/cached field returned directly (optionally a copy for caller-immutability), not a computed property that re-runs the pipeline on access. Use a `stats_changed` signal spy to assert zero emissions across a double-read.
- The chassis modifier values in the ACs (Light Frame ×0.85 structure / ×1.20 mobility; Heavy Frame ×1.25 structure / ×0.80 mobility) come from `BalanceConfig.chassis_modifiers` — build the test `BalanceConfig` with exactly these rows so the fixture is discriminating.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: the `derive` implementation itself.
- **Story 002**: equip mechanics (validate/displace/install/no-op/signals).
- **TBC epic (`CombatantSnapshot`, TR-tbc-002)**: the battle-start immutable snapshot — the other half of TR-sa-006. This story covers only Assembly-side stability between equips.

---

## QA Test Cases

*Logic specs — drive equips on a `SymbotBuild` (stub Inventory/CoreProgression) with a test `BalanceConfig` whose `chassis_modifiers` carry the exact rows below; use a `stats_changed` signal spy.*

- **AC-SA-05 — Chassis swap full 11-stat recompute**
  - Given: build with CHASSIS = Light Frame (`structure=10`; modifiers structure ×0.85, mobility ×1.20), LEGS = `swift_legs` (`mobility=7`), all other parts contributing 0 to all stats. Pre-swap assert `final_stat["structure"]==8` and `final_stat["mobility"]==8`.
  - When: `equip_part(CHASSIS, heavy_frame_instance)` where Heavy Frame `structure=8`, modifiers structure ×1.25, mobility ×0.80.
  - Then: `final_stat["structure"]==10`; `final_stat["mobility"]==5`; `final_stat.has(&"targeting") and final_stat["targeting"]==0`.
  - Edge cases: assert all 11 canonical keys present post-swap (present-key guard, not just the three asserted values).

- **AC-SA-07 — Stable between equips + passive read**
  - Given: the post-swap Heavy Frame state from AC-SA-05.
  - When: read `final_stat` twice with no intervening equip.
  - Then: (a) first read has `structure==10`, `mobility==5`; (b) second read `== ` first read (deep-equal dictionary); (c) signal spy recorded **zero** `stats_changed` emissions across the two reads.
  - Edge cases: mutating the returned dictionary (if a copy is returned) must not corrupt the stored `final_stat` on the next read.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/symbot_assembly/symbot_build_recompute_test.gd` — must exist and pass (GUT).

**Status**: [x] Done — GUT green 2026-07-16 (suite 657 tests / 53 scripts, was 631/46)

---

## Dependencies

- Depends on: **Story 001** (`StatPipeline.derive`), **Story 002** (`equip_part` + eager recompute + `stats_changed`).
- Unlocks: None directly (validates the recompute path Stories 006/007 also rely on).

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 2/2 passing (AC-SA-05 chassis swap forces a full 11-stat recompute — structure 8→10, mobility 8→5 proving the modifier re-applies to the non-CHASSIS LEGS contribution, `targeting==0` present-key guard proving all 11 keys recomputed; AC-SA-07 `final_stat` stable between equips — stored values correct, deep-equal on double read, **zero** `stats_changed` on passive read) — all COVERED by `tests/unit/symbot_assembly/symbot_build_recompute_test.gd` (2 tests).
**Deviations**: None. This was primarily a defect-catching / test-authoring story over the Story 001+002 wiring; no fix was needed — `StatPipeline.derive` already iterates the canonical 11 keys so the present-key guard holds, and `get_final_stat()` returns a `.duplicate()` copy (`symbot_build.gd:151`) so a caller mutating the returned dict cannot corrupt the cache and a read never re-runs the pipeline or emits. Scope boundary preserved: the battle-start immutable-snapshot half of TR-sa-006 (`CombatantSnapshot` at BATTLE_INIT) is the TBC epic (TR-tbc-002) — correctly out of scope; this story covers only Assembly-side stability between equips.
**Test Evidence**: Logic — `tests/unit/symbot_assembly/symbot_build_recompute_test.gd`; full GUT suite 657/657 green (Godot 4.7 headless).
**Code Review**: Complete — `/code-review` this session, verdict APPROVED. Reviewed inline as godot-gdscript-specialist (1M-context constraint).
