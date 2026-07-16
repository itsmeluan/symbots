# Story 005: Move authoring-rule validation

> **Epic**: Move Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/move-database.md`
**Requirement**: `TR-mdb-003` (STATUS status_id↔element), `TR-mdb-004` (DAMAGE energy band per tier), `TR-mdb-005` (REPAIR brake > BASE_ENERGY_REGEN), `TR-mdb-009` (non-DAMAGE no innate rider), `TR-mdb-010` (Core no SKILL_UNLOCK)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: `ContentValidator` CI-blocking + dev-boot gate over `ContentCatalogs`; diagnostics via injected `LogSink`; cross-schema (part↔move) checks read the aggregate.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: `BASE_ENERGY_REGEN = 10` is a TBC constant (not yet in code). Define it as a named const in the validator (or a `MoveDef` const) tied to the GDD, with a forward-work note to source it from the TBC `BalanceConfig` field once TBC ships. The DAMAGE energy bands are `LIGHT 5–8, STANDARD 12–18, HEAVY 22–30, SIGNATURE 32–40` (GDD Rule 3). The STATUS element↔status map is `VOLT→shock, THERMAL→burn, KINETIC→stagger` (GDD Rule 5 / TBC Rule 11). **AC-MDB-17 (Core no SKILL_UNLOCK) is already enforced Part-DB-side** as `content_upgrade_skill_unlock_forbidden` (`content_validator.gd _check_upgrade_effects`, added 2026-07-16) — this story cross-references and regression-guards it from the Move DB angle, it does not re-implement the check.

**Control Manifest Rules (this layer)**:
- Required: CI-blocking content validation; diagnostics via injected `LogSink` — source: ADR-0003
- Forbidden: `global_push_diagnostics` — route through the sink — source: ADR-0002
- Guardrail: pure over the injected aggregate; cross-DB reads use `StringName` id membership, never `Resource` links

---

## Acceptance Criteria

*From GDD AC-MDB-14/15/16/17, TR-mdb-009, EC-MDB-02/03/08/10:*

- [ ] AC-MDB-14 (energy band): a `DAMAGE` move whose `energy_cost` falls outside its `power_tier` band errors naming the id — `content_move_energy_band`
- [ ] AC-MDB-15 (REPAIR brake): a `REPAIR` move with `energy_cost <= BASE_ENERGY_REGEN` errors — `content_move_repair_brake` (Move DB side of TBC AC-TBC-38)
- [ ] AC-MDB-16 (status↔element): a `STATUS` move whose `status_proc.status_id` does not match its `element` map errors — `content_move_status_element_mismatch`
- [ ] TR-mdb-009 (no innate rider): a non-`DAMAGE`... rather a `DAMAGE` move carrying an innate `status_proc` (non-empty) errors — `content_move_innate_rider` (riders come only via passives, TBC Rule 13)
- [ ] AC-MDB-17 (Core skill-unlock): confirmed already covered by the Part-DB `content_upgrade_skill_unlock_forbidden` check — a regression test asserts a Core part with a SKILL_UNLOCK upgrade_effect still errors

---

## Implementation Notes

*Derived from GDD Rule 3/5/9 + the existing `_check_upgrade_effects` (Part DB):*

Extend the `_validate_move` dispatch (Story 004) with the cross-field checks. Energy bands: a `Dictionary` keyed by `PowerTier` → `[min,max]` (BASIC is cost 0, exempt). Status map: a `Dictionary` keyed by `PartDef.Element` → expected `status_id: StringName`. The innate-rider rule: `DAMAGE` behaviour with a non-empty `status_proc` is illegal (Rule 5 — DAMAGE riders are passives, never move fields); STATUS moves REQUIRE a `status_proc`. For AC-MDB-17, add a test only (no new production code) — the Part validator already rejects it; assert the code fires and note the shared coverage in the story completion notes. Every check pairs a CLEAN + CORRUPTED fixture.

---

## Out of Scope

- Story 004: schema-shape validation (required fields, targeting, DAMAGE→power_tier presence)
- Story 006: referential integrity (`active_skill_id` → move resolution)
- Runtime clamping of a SKILL_ENHANCE tier bump above SIGNATURE (AC-MDB-12 — TBC/upgrade runtime)
- Wiring these into the CI content gate against real authored move `.tres` (deferred until a move content-authoring pass exists — the GDD's ADVISORY-DEFERRED trigger)

---

## QA Test Cases

- **AC-1** (AC-MDB-14): `SIGNATURE` move at `energy_cost=10` (band 32–40) → `content_move_energy_band`; an in-band move is clean. Edge: boundary values 32 and 40 pass; 31 and 41 fail.
- **AC-2** (AC-MDB-15): `REPAIR` at `energy_cost=10` (`<=` regen 10) → `content_move_repair_brake`; at 11 clean. Edge: exactly `BASE_ENERGY_REGEN` fails; `+1` passes.
- **AC-3** (AC-MDB-16): a `VOLT` `STATUS` move with `status_id=burn` → `content_move_status_element_mismatch`; `status_id=shock` clean. Edge: each of the 3 element→status pairs.
- **AC-4** (TR-mdb-009): a `DAMAGE` move with a non-empty `status_proc` → `content_move_innate_rider`; a `STATUS` move REQUIRES `status_proc` (empty → error).
- **AC-5** (AC-MDB-17): a Core `PartDef` with a `SKILL_UNLOCK` upgrade_effect still logs `content_upgrade_skill_unlock_forbidden` (regression; shared with Part DB).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/move_database/move_validator_authoring_test.gd` — must exist and pass

**Status**: [x] Created & passing — `tests/unit/move_database/move_validator_authoring_test.gd` (12 tests: AC-1 energy band incl. inclusive edges 32/40 pass + 31/41 fail + all-tier midpoints + BASIC-exempt; AC-2 REPAIR brake at ==10 fails / 11 clean; AC-3 mismatch + all 3 element→status pairs clean; AC-4 DAMAGE-innate-rider + STATUS-riderless-via-mismatch; AC-5 Core SKILL_UNLOCK regression via shared Part-DB check). Validator extended with `_check_move_energy_band`/`_check_move_repair_brake`/`_check_move_status_element`/`_check_move_innate_rider` + consts `ENERGY_BANDS`, `BASE_ENERGY_REGEN=10` (forward-work: source from TBC BalanceConfig once TBC ships), `STATUS_BY_ELEMENT`, `STATUS_ID_KEY`. Error codes: `content_move_energy_band`, `content_move_repair_brake`, `content_move_status_element_mismatch` (also covers AC-4's STATUS-riderless case — empty proc can't match element), `content_move_innate_rider`. AC-MDB-17 needed NO new Move code (shared `content_upgrade_skill_unlock_forbidden`). Story-004 clean fixtures updated to be fully-valid under the extended validator (in-band energy, element-matched rider, braked REPAIR). Full suite **221/221 green, 2862 asserts** (Godot 4.7 + GUT 9.7.1).

---

## Dependencies

- Depends on: Story 004 (shared `_validate_move` dispatch), Part-DB `_check_upgrade_effects` (AC-MDB-17 coverage)
- Unlocks: Story 006 (referential integrity is the last validation layer)
