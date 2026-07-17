# Story 001: SynergySystem core — SYN-F1 counting, SYN-F2 activation, evaluate() + synergy_changed

> **Epic**: Synergy System
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/synergy-system.md`
**Requirement**: `TR-syn-001`, `TR-syn-002`, `TR-syn-007`, `TR-syn-011`, `TR-syn-012`, `TR-syn-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: The pure formula core lives in `src/core/` as DI RefCounted owners (not autoloads); cross-system signals are owner-declared and typed; diagnostics route through an injected `LogSink`.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Typed `Array[StringName]` returns and typed `Dictionary` fields; `Object.is_class()` takes `StringName` in 4.7 (not relevant here). No post-cutoff API required — this is pure GDScript logic.

**Control Manifest Rules (this layer — Core)**:
- Required: pure formula core in `src/core/`, owners are DI RefCounted objects, not autoloads; new cross-system signals are owner-declared + typed; diagnostics via injected `LogSink` (`warn(code, detail)`), never global `push_warning()`.
- Forbidden: `push_warning()` / `push_error()` from `src/`; a subscriber that depends on running before/after another subscriber of the same signal.
- Guardrail: computation is synchronous and testable — no `await`.

---

## Acceptance Criteria

*From GDD `design/gdd/synergy-system.md`, scoped to this story:*

- [ ] **AC-SYN-01** — Single-tag 3-piece activation: 3 ironclad-tagged parts → `cached_bonus_block.stat_delta["armor"] == 8` AND `stat_delta.size() == 1` AND `synergy_changed` emitted.
- [ ] **AC-SYN-04** — Wild parts contribute to element tag only: 4 THERMAL-only parts → `active_synergies == ["thermal_3_piece"]` (size 1), `stat_delta == { armor: 8 }`; NO manufacturer/combined tier ID appears (proven via the public `active_synergies`, not internal counts).
- [ ] **AC-SYN-07** — Empty build emits signal with empty block: `evaluate([null×8])` → signal counter == 1; `active_synergies` is an `Array[StringName]` (never null) of size 0; `bonus_block.stat_delta.is_empty()` AND `bonus_block.effects.is_empty()`.
- [ ] **AC-SYN-11** — `evaluate()` always emits `synergy_changed`: two identical calls → counter == 2; `cached_bonus_block` unchanged between calls.
- [ ] **AC-SYN-18** — Wrong-length array tolerance (EC-SYN-10): short array (5 entries) → missing indices treated null, `energy_power == 6`, error logged; long array (10 entries) → indices >7 ignored, VOLT=3 not 5, `energy_power == 6`, error logged; no crash either case.
- [ ] **AC-SYN-19** — Empty/null `synergy_tags` contributes no counts (EC-SYN-07): slot with `[]` (Scenario A) and slot with `null` (Scenario B) → `armor == 8`, `size() == 1`, `active_synergies.size() == 1`, no crash. Null field treated exactly as `[]`.
- [ ] **AC-SYN-21** — Duplicate tags within a part inflate the count (EC-SYN-11): parts with `[ironclad, ironclad, VOLT]` → ironclad=6 → `armor == 28` (8+20, both tiers), no crash, no within-part dedup.
- [ ] **AC-SYN-22** — Tier with empty `requirements` skipped and logged (EC-SYN-12): `"bad_tier"` with `requirements = []` on empty build → NOT activated, `active_synergies.size() == 0`, content error naming `"bad_tier"` logged; guards vacuous-truth bug.
- [ ] **AC-SYN-23** — Tier with `min_count = 0` skipped and logged (EC-SYN-13): `"zero_tier"` with `requirements = [(VOLT, 0)]` on empty build → NOT activated despite `0 ≥ 0`, content error naming `"zero_tier"` logged; guards min_count vacuous-activation.

---

## Implementation Notes

*Derived from ADR-0005 + ADR-0002 Implementation Guidelines and the GDD Formulas:*

- Create `src/core/synergy/synergy_tier_def.gd` (`class_name SynergyTierDef extends RefCounted` — the runtime tier type; **not** yet a `.tres` — content authoring format is OQ-1, deferred). Fields: `id: StringName`, `requirements: Array` of `[StringName, int]` pairs `(tag, min_count)`, `stat_delta: Dictionary` (`StringName → int`), `effects: Array[StringName]`.
- Create `src/core/synergy/synergy_system.gd` (`class_name SynergySystem extends RefCounted`). Constructor injects the tier registry (`Array[SynergyTierDef]`) and a `LogSink`. Holds `var cached_bonus_block` — **never null**; initialize to an empty block `{ stat_delta: {}, effects: [] }` on construction.
- **SYN-F1 (counting)**: iterate slots 0–7 only. For each non-null part, for each tag in `part.synergy_tags` (guard `null → []` per EC-SYN-07), increment `tag_count[tag]`. Count **each occurrence** (no within-part dedup — EC-SYN-11). Indices beyond 7 ignored; missing indices treated null (EC-SYN-10).
- **SYN-F2 (activation)**: a tier activates iff **every** `(tag, min_count)` requirement satisfies `tag_count.get(tag, 0) >= min_count` (AND logic). **Guard before evaluating**: if `requirements.is_empty()` → skip + `LogSink.warn` naming the tier (EC-SYN-12); if any `min_count < 1` → skip + `LogSink.warn` naming the tier (EC-SYN-13). Both guards prevent vacuous activation on the empty build.
- `active_synergies` is the list of activated tier IDs — typed `Array[StringName]`, **never null** (empty build → empty list, TR-syn-012). Ordering (alphabetical) is Story 003's concern; here just produce the list.
- `evaluate(parts)` computes → writes `cached_bonus_block` → **always** emits `synergy_changed(active_synergies, cached_bonus_block)` (Rule 7 — emit even when the block is identical; TR-syn-011). Declare the signal on `SynergySystem` (owner-declared, typed).
- Aggregation here is minimal (sum `stat_delta` across active tiers into the block) — the cumulative/combined depth is Story 002, effect dedup/order is Story 003. Deliver just enough that single-tier ACs (01, 04) observe a correct block.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: cumulative multi-tier stacking, combined synergies, deactivation, unknown-stat-key aggregation, 7-tier stress.
- **Story 003**: effect-ID dedup, alphabetical `String(tier_id)` ordering of effects AND `active_synergies`, unregistered-ID passthrough.
- **Story 004**: `evaluate_silent()`.
- **Story 005**: `preview()`.
- **Consumer-owned (not this epic)**: SYN-F4 `max(0, base+delta)` (AC-SYN-06/10) — applied in TBC + Workshop UI, per control manifest `StatMath.effective_stat`.

---

## QA Test Cases

*Embedded from the GDD's AC fixtures (already discriminating). Implement against these — do not invent new cases.*

- **AC-SYN-01**: Given slots 0–2 `[ironclad, KINETIC]`, slots 3–7 `[KINETIC]`, Ironclad-3-piece `{armor:8}`; When `evaluate(parts)`; Then `stat_delta["armor"]==8` AND `stat_delta.size()==1` AND `synergy_changed` emitted.
- **AC-SYN-04**: Given slots 0–3 `[THERMAL]`, slots 4–7 null, THERMAL-3-piece `{armor:8}`; When `evaluate(parts)`; Then `active_synergies==["thermal_3_piece"]` (size 1) AND `stat_delta=={armor:8}` AND no manufacturer/combined ID present. Edge: assert on the **public** `active_synergies`, not an internal count map.
- **AC-SYN-07**: Given `evaluate([null×8])`, counter=0; Then counter==1, `active_synergies` non-null `Array[StringName]` size 0, block empties true. Edge: `active_synergies != null` (Rule 7 never-null).
- **AC-SYN-11**: Given 3 VOLT parts, counter=0; When `evaluate` twice identical; Then counter==2, cache unchanged.
- **AC-SYN-18**: Scenario A `evaluate([volt,volt,volt,null,null])` → `energy_power==6`, error logged, no crash. Scenario B `evaluate([volt,volt,volt,null,null,null,null,null,volt,volt])` → VOLT=3, `energy_power==6`, error logged. Edge: no index-out-of-bounds.
- **AC-SYN-19**: Scenario A slot 3 `synergy_tags=[]`, Scenario B slot 3 `synergy_tags=null`; When `evaluate`; Then both → `armor==8`, `size()==1`, `active_synergies.size()==1`, no crash. Edge: `for tag in null` must be guarded.
- **AC-SYN-21**: Given slots 0–2 `[ironclad,ironclad,VOLT]`, Ironclad-3 `{armor:8}`, Ironclad-5 `{armor:20}`; When `evaluate`; Then ironclad=6 → `armor==28`, no crash, no within-part dedup.
- **AC-SYN-22**: Given `bad_tier` `requirements=[]`, empty build; When `evaluate([null×8])`; Then `active_synergies.size()==0`, error names `bad_tier`, counter==1. Edge: vacuous-truth must not fire.
- **AC-SYN-23**: Given `zero_tier` `requirements=[(VOLT,0)]`, empty build; When `evaluate([null×8])`; Then `active_synergies.size()==0`, error names `zero_tier`, counter==1. Edge: `0 ≥ 0` must NOT activate.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/synergy/synergy_core_evaluate_test.gd` — must exist and pass.

**Status**: [x] Created — 11 tests, all passing (full suite 689/689 green, 2026-07-16)

---

## Dependencies

- Depends on: None (epic anchor)
- Unlocks: Story 002, Story 003, Story 004, Story 005
