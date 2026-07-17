# Story 005: Passive pool derivation

> **Epic**: Symbot Assembly System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/symbot-assembly.md`
**Requirement**: `TR-sa-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary)
**Secondary**: ADR-0003: Content Resource Loading & Schema Mapping (`passive_id` read from frozen `PartDef`; Passive DB resolution)
**ADR Decision Summary**: `SymbotBuild` collects all non-null `passive_id`s in a fixed order — CORE, LEGS, then all other slots in slot-type order — exposing an ordered `Array[StringName]`. Common parts contribute no passive (`null`); an all-Common build has an empty pool (valid).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure ordered collection over the 8-slot manifest. `passive_id` is a `StringName` on `PartDef` (ADR-0003). Missing Passive DB entries resolve to skip-with-log (EC-SA-04) — the Passive Database is Foundation-Complete. `passive_pool` is `Array[StringName]` per the `CombatantSnapshot.passive_pool` typing.

**Control Manifest Rules (this layer — Core)**:
- Required: DI RefCounted owner reads frozen `PartDef` primitive fields (ADR-0005/0003).
- Forbidden: `global_push_diagnostics` — a missing-Passive-DB-entry content error goes to the injected `LogSink` (ADR-0002).
- Forbidden: `runtime_content_mutation` — read `passive_id`, never mutate the def (ADR-0003).

---

## Acceptance Criteria

*From GDD `design/gdd/symbot-assembly.md`, scoped to this story:*

- [x] **AC-SA-09** — Passive pool: CORE and LEGS appear first, in that order. CORE `passive_id="pulse_core"`, LEGS `passive_id="heavy_step"`, all others null → `passive_pool == ["pulse_core", "heavy_step"]`.
- [x] **AC-SA-14** — "Others" ordering CHASSIS → CHIPSET → ENERGY_CELL → HEAD → ARMS → WEAPON. CORE `"pulse_core"`, LEGS `"heavy_step"`, ARMS `"iron_grip"` (Boss-grade), all others null → `passive_pool == ["pulse_core", "heavy_step", "iron_grip"]` (CORE first, LEGS second, then ARMS in slot-type order; no phantom entries for null-passive slots).

---

## Implementation Notes

*Derived from Assembly Rule 5 (The Passive Pool):*

- Derive `passive_pool: Array[StringName]` on `SymbotBuild`, recomputed on manifest change (alongside the eager recompute in `equip_part`, Story 002 — this story fills the passive-pool placeholder there).
- **Ordering is fixed and explicit**: iterate slots in the order `CORE, LEGS, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS, WEAPON`. Append each slot's `passive_id` **only if non-null**. Do not append `null` — null-passive slots produce no entry (no phantom slots, AC-SA-14).
- Per Rule 2, most slots never carry a passive (CORE required at Rare+, LEGS always has a movement passive; others `null` in MVP content), but derive generically from `passive_id` presence so future content that adds a passive to any slot orders correctly.
- **EC-SA-04**: resolve each `passive_id` against the Passive Database catalog; if the entry does not exist, `log.error` (content error) and **skip** it (do not append). Never raise. (This mirrors the move-pool EC-SA-04 rule; the passive variant skips rather than inserting `null`, because the pool is a compact list, not a fixed-index array.)
- Empty pool (all-Common build) is valid — return `[]`, handled gracefully (Rule 5).
- Keep the pool a stored field returned passively (AC-SA-07 passive-read discipline).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: equip mechanics / recompute trigger.
- **Story 004**: move pool derivation.
- **Synergy epic & TBC epic**: how passives are *evaluated* (STAT_AURA / STATUS_RIDER dispatch, ON_HIT/ON_BATTLE_START triggers). Assembly only exposes the ordered id list; it does not resolve passive behavior.

---

## QA Test Cases

*Logic specs — construct `SymbotBuild`s with the specified `passive_id`s (stub Inventory/CoreProgression, spy `LogSink`) and read `passive_pool`.*

- **AC-SA-09 — CORE then LEGS first**
  - Given: CORE `passive_id="pulse_core"`, LEGS `passive_id="heavy_step"`, all other slots `passive_id=null` (entries exist in Passive DB).
  - When: read `passive_pool`.
  - Then: `passive_pool == ["pulse_core", "heavy_step"]` (exact order and length).

- **AC-SA-14 — "Others" slot-type ordering, no phantom nulls**
  - Given: CORE `"pulse_core"`, LEGS `"heavy_step"`, ARMS `"iron_grip"` (Boss-grade); CHASSIS/CHIPSET/ENERGY_CELL/HEAD/WEAPON all `null`.
  - When: read `passive_pool`.
  - Then: `passive_pool == ["pulse_core", "heavy_step", "iron_grip"]` — length 3; ARMS appears after CORE and LEGS per the CHASSIS→CHIPSET→ENERGY_CELL→HEAD→ARMS→WEAPON order; no `null` entries.
  - Edge cases: all-Common build (every `passive_id==null`) → `passive_pool == []`.

- **EC-SA-04 — Missing Passive DB entry skipped, no crash**
  - Given: LEGS `passive_id="ghost_passive"` with no Passive DB entry; CORE `"pulse_core"` valid.
  - When: `passive_pool` derived with a spy `LogSink`.
  - Then: `"ghost_passive"` absent from `passive_pool`; spy recorded a content error; no exception; `"pulse_core"` still present.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/symbot_assembly/passive_pool_test.gd` — must exist and pass (GUT).

**Status**: [x] Done — GUT green 2026-07-16 (suite 657 tests / 53 scripts, was 631/46)

---

## Dependencies

- Depends on: **Story 002** (`SymbotBuild` exists; recompute trigger calls pool derivation). Passive Database is Foundation-Complete (resolution target).
- Unlocks: None directly (consumed by Synergy + TBC epics).

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 2/2 ACs + the EC passing (AC-SA-09 CORE then LEGS first — exact order/length; AC-SA-14 "others" order CHASSIS→CHIPSET→ENERGY_CELL→HEAD→ARMS→WEAPON with no phantom-null entries; EC-SA-04 missing Passive DB entry skipped-not-inserted + content error, all-Common build → `[]`) — all COVERED by `tests/unit/symbot_assembly/passive_pool_test.gd` (3 tests).
**Deviations**: None. Ordering is the explicit `PASSIVE_SLOT_ORDER` const `[CORE, LEGS, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS, WEAPON]` (`symbot_build.gd:40`); `_derive_passive_pool` appends a `passive_id` only if non-empty AND resolvable, **skips** (never appends null) on a missing entry — correctly distinct from the move-pool's fixed-index null (`:273`). `passive_pool` typed `Array[StringName]` per the `CombatantSnapshot.passive_pool` contract. Scope boundary preserved: how passives are *evaluated* (STAT_AURA/STATUS_RIDER dispatch, trigger firing) is the Synergy + TBC epics — Assembly only exposes the ordered id list.
**Test Evidence**: Logic — `tests/unit/symbot_assembly/passive_pool_test.gd`; full GUT suite 657/657 green (Godot 4.7 headless). Passive Database is Foundation-Complete (resolution target live).
**Code Review**: Complete — `/code-review` this session, verdict APPROVED. Reviewed inline as godot-gdscript-specialist (1M-context constraint).
