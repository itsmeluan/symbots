# Story 004: Move pool derivation

> **Epic**: Symbot Assembly System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/symbot-assembly.md`
**Requirement**: `TR-sa-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary)
**Secondary**: ADR-0003: Content Resource Loading & Schema Mapping (`active_skill_id` read from frozen `PartDef`; Move DB resolution)
**ADR Decision Summary**: `SymbotBuild` derives the move pool in fixed order Basic / WEAPON / HEAD / ARMS; index `[3]` (ARMS) is nullable. Only WEAPON, HEAD, ARMS may contribute skills.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure data derivation over the 8-slot manifest. `active_skill_id` is a `StringName` field on `PartDef` (ADR-0003). Move DB entry existence is resolved via the Move Database catalog getter; a missing entry logs and yields `null` (EC-SA-04) — the Move DB itself is Foundation-Complete.

**Control Manifest Rules (this layer — Core)**:
- Required: DI RefCounted owner reads frozen `PartDef` primitive fields (ADR-0005/0003).
- Forbidden: `global_push_diagnostics` — the missing-Move-DB-entry content error goes to the injected `LogSink` (ADR-0002).
- Forbidden: `runtime_content_mutation` — read `active_skill_id`, never mutate the def (ADR-0003).

---

## Acceptance Criteria

*From GDD `design/gdd/symbot-assembly.md`, scoped to this story:*

- [x] **AC-SA-03a** — Common ARMS → Move 4 is null. Build with a `rarity=COMMON` ARMS part → `move_pool` length 4; `move_pool[3] == null`.
- [x] **AC-SA-03b** — Rare+ ARMS → Move 4 is non-null. Rare ARMS with `active_skill_id="iron_claw"` → `move_pool[3] == "iron_claw"`.
- [x] **AC-SA-06** — Missing Move DB entry → null, not crash. WEAPON part with `active_skill_id="nonexistent_skill"` → `move_pool[1] == null`; content error logged; no exception; build otherwise valid.
- [x] **AC-SA-12** — CORE / CHASSIS / CHIPSET / ENERGY_CELL never populate move slots. Build where those four parts each carry `active_skill_id="bad_skill"` (malformed content); WEAPON=`"cannon_shot"`, HEAD=`"scan_pulse"`, ARMS Common (`active_skill_id=null`) → `move_pool == ["basic_attack", "cannon_shot", "scan_pulse", null]`; `"bad_skill"` appears at no index; length 4.

---

## Implementation Notes

*Derived from Assembly Rule 4 (The Active Move Pool):*

- Derive `move_pool` as a fixed-length-4 `Array` on `SymbotBuild`, recomputed whenever the manifest changes (i.e., alongside the eager recompute in `equip_part`, Story 002 wiring — this story fills the pool-derivation placeholder left there):
  - `move_pool[0]` = the universal Basic Attack id (`"basic_attack"` — a constant identity, always present; the Basic Attack itself is defined in the TBC GDD, Assembly only slots its id).
  - `move_pool[1]` = WEAPON part's `active_skill_id` (always non-null in valid content, but pass through EC-SA-04 resolution).
  - `move_pool[2]` = HEAD part's `active_skill_id`.
  - `move_pool[3]` = ARMS part's `active_skill_id` (may be `null` for Common ARMS — AC-SA-03a).
- **Only** WEAPON/HEAD/ARMS are read for skills (AC-SA-12). CORE, CHASSIS, CHIPSET, ENERGY_CELL are **never** consulted for `active_skill_id`, even if malformed content sets one — the pool is built by reading those three specific slots, not by scanning all 8 for non-null `active_skill_id`.
- **EC-SA-04 / AC-SA-06**: before placing a non-null `active_skill_id` into the pool, resolve it against the Move Database catalog. If the entry does not exist, `log.error` (content error) and place `null` at that index. Never raise. The same graceful-null rule applies to WEAPON/HEAD, not only ARMS.
- Keep the pool a stored field returned passively (consistent with AC-SA-07's passive-read discipline) — recompute only on manifest change.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: equip mechanics and the recompute trigger. This story fills the move-pool derivation the trigger calls; it does not re-implement equip.
- **Story 005**: passive pool derivation.
- **TBC epic**: how the Basic Attack computes damage, and how Combat greys out a null Move 4 ("—") — Assembly only exposes the pool with `null` at the unavailable index (AC-SA-03a).

---

## QA Test Cases

*Logic specs — construct `SymbotBuild`s with the specified slot contents (stub Inventory/CoreProgression, spy `LogSink`) and read `move_pool`.*

- **AC-SA-03a — Common ARMS → null Move 4**
  - Given: build with a `rarity=COMMON` ARMS part (`active_skill_id=null`); valid WEAPON/HEAD skills.
  - When: read `move_pool`.
  - Then: `move_pool.size()==4`; `move_pool[3]==null`.

- **AC-SA-03b — Rare+ ARMS → non-null Move 4**
  - Given: build with a Rare ARMS part `active_skill_id="iron_claw"` (entry exists in Move DB).
  - When: read `move_pool`.
  - Then: `move_pool[3]=="iron_claw"`.

- **AC-SA-06 — Missing Move DB entry → null, no crash**
  - Given: WEAPON part `active_skill_id="nonexistent_skill"` (no such Move DB entry).
  - When: `move_pool` derived, spy `LogSink` attached.
  - Then: `move_pool[1]==null`; spy recorded a content error; no exception; other move slots resolve normally.
  - Edge cases: a missing HEAD skill nulls `move_pool[2]` identically (rule is not ARMS-only).

- **AC-SA-12 — Prohibited slots never populate moves**
  - Given: CORE/CHASSIS/CHIPSET/ENERGY_CELL each carry `active_skill_id="bad_skill"` (malformed); WEAPON `"cannon_shot"`, HEAD `"scan_pulse"`, ARMS Common (null).
  - When: read `move_pool`.
  - Then: `move_pool == ["basic_attack", "cannon_shot", "scan_pulse", null]`; `"bad_skill"` at no index; length 4.
  - Edge cases: assert explicitly that none of the four prohibited `active_skill_id` values appear anywhere in `move_pool`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/symbot_assembly/move_pool_test.gd` — must exist and pass (GUT).

**Status**: [x] Done — GUT green 2026-07-16 (suite 657 tests / 53 scripts, was 631/46)

---

## Dependencies

- Depends on: **Story 002** (`SymbotBuild` exists; recompute trigger calls pool derivation). Move Database is Foundation-Complete (resolution target).
- Unlocks: None directly (consumed by the TBC epic at battle start).

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 4/4 passing (AC-SA-03a Common ARMS → `move_pool[3]==null`, length 4; AC-SA-03b Rare ARMS `active_skill_id` → non-null at index 3; AC-SA-06 missing Move DB entry → `null` + content error, no crash, applies to WEAPON/HEAD not just ARMS; AC-SA-12 CORE/CHASSIS/CHIPSET/ENERGY_CELL never populate moves even with malformed `active_skill_id` — pool built by reading the three specific slots, not scanning all 8) — all COVERED by `tests/unit/symbot_assembly/move_pool_test.gd` (4 tests).
**Deviations**: None. Fixed-order derivation `[basic_attack, WEAPON, HEAD, ARMS]` (`symbot_build.gd:245`); `_resolve_skill` gates on empty-`&""` → null and Move-DB `has_move` membership → error+null uniformly across the three skill slots (`:257`). `BASIC_ATTACK_ID` is a constant identity (the Basic Attack itself is defined by the TBC GDD — Assembly only slots its id). Missing-entry diagnostics route through the injected `LogSink`.
**Test Evidence**: Logic — `tests/unit/symbot_assembly/move_pool_test.gd`; full GUT suite 657/657 green (Godot 4.7 headless). Move Database is Foundation-Complete (resolution target live).
**Code Review**: Complete — `/code-review` this session, verdict APPROVED. Reviewed inline as godot-gdscript-specialist (1M-context constraint).
