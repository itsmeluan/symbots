# Story 007: ContentValidator consumable family

> **Epic**: Consumable Database
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-001` (effect_type ↔ effect_params match), `TR-cdb-006` (buy_price > sell_price strictly — BLOCKING anti-arbitrage), `TR-cdb-008` (flat-integer magnitudes)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: A single DI-testable `ContentValidator` (RefCounted) blocks CI and fail-louds dev boot; returns `{ok, errors, warnings}`; all diagnostics go through an injected `LogSink` (`_error`/`_warn`), never `push_error`/`push_warning`. "Extend never fork": add a new per-DB check family + dispatch wiring, never modify existing checks.

**Engine**: Godot 4.7 | **Risk**: MEDIUM (must integrate into the existing 1170-line `content_validator.gd` without touching sibling families; watch the DoD file-size trigger)
**Engine Notes**: Add `_validate_consumable_catalog` + per-check methods; dispatch it only when `catalogs.consumables != null` (append a `consumables: ConsumableCatalog` slot to `ContentCatalogs`, APPEND-ONLY). Error codes follow the existing naming (`content_consumable_*`). The `buy == sell` case is the canonical strict-invariant discriminator — a `<`-only impl passes it silently.

**Control Manifest Rules (this layer)**:
- Required: single `ContentValidator`, all diagnostics via injected `LogSink`; new family gated on injected catalog state; APPEND-ONLY `ContentCatalogs` slot — source: ADR-0003/0002
- Forbidden: `push_error`/`push_warning` (`global_push_diagnostics`); modifying existing check families ("extend never fork"); reordering the `ContentCatalogs` fields — source: ADR-0002/0003
- Guardrail: **if `content_validator.gd` crosses ~1500 lines, extract per-DB families into composed `RefCounted` helpers behind the single `validate()` entry** (EPIC DoD, provenance: `/code-review` 2026-07-16)

---

## Acceptance Criteria

*From GDD EC-CD-09/10/11 + roster rules, verified by AC-CD-15/16/17/18/19:*

- [ ] **Malformed effect_params** (EC-CD-09): RESTORE_STRUCTURE with `{}` (no `amount`) → error naming `consumable_id` + missing key; REDUCE_HEAT with `{"amount":"fifty"}` (wrong type) → error naming id + key; entry unusable — AC-CD-15
- [ ] **buy_price ≤ sell_price** (EC-CD-10, BLOCKING): `buy=10,sell=10` (equal) → error; `buy=9,sell=10` → error; `buy=11,sell=10` → no error — AC-CD-16
- [ ] **Unknown effect_type** (EC-CD-11): `"GRANT_XP"` → error naming id + type, unusable; a valid type → no error — AC-CD-17
- [ ] **MVP roster** (ADVISORY): exactly 8 entries (7/9 → error), 6 effect concepts present, no `BOSS_GRADE`, all `buy>sell`, all `effect_params` well-formed — AC-CD-18
- [ ] **use_context + target coherence** (ADVISORY): Beacon `BATTLE`/`CURRENT_BATTLE`; Jammer & Lure `WORLD`/`OVERWORLD`; 5 restoratives `BOTH`/`LIVING_TEAM_MEMBER`; no `BATTLE`-item with `target=OVERWORLD`, no `WORLD`-item with `target=LIVING_TEAM_MEMBER` — AC-CD-19

---

## Implementation Notes

*Derived from ADR-0003 + the existing validator families (Part/Move/Passive):*

Follow the Passive DB Story 004/005 pattern exactly. Add `consumables: ConsumableCatalog` to `content_catalogs.gd` (APPEND-ONLY, after the last slot). In `content_validator.gd`, add `_validate_consumable_catalog(catalogs, log)` dispatched from `validate()` **only when `catalogs.consumables != null`**, so existing part/move/passive-only fixtures are unaffected. Per-check methods: `_check_consumable_effect_params` (required key + type per `effect_type`), `_check_consumable_price_invariant` (strict `buy > sell`), `_check_consumable_effect_type_known` (enum membership), `_check_consumable_roster` (count==8, no BOSS_GRADE, 6 concepts — ADVISORY via `_warn`), `_check_consumable_context_target_coherence` (ADVISORY). Every diagnostic names the `consumable_id`. Error codes: `content_consumable_effect_params_malformed`, `content_consumable_price_invariant`, `content_consumable_unknown_effect_type`, `content_consumable_roster` (warn), `content_consumable_context_target_incoherent` (warn). Discriminating fixtures per the GDD (the equal-price case for AC-CD-16 is mandatory).

**Watch the file-size DoD trigger:** the validator is at ~1170 lines. If this family pushes it past ~1500, extract the per-DB families into composed `RefCounted` helpers behind `validate()` (pure structural split, suite green before + after) — per the EPIC Definition of Done.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Stories 003/004/005/006: the runtime formulas + use-transaction (the validator checks *content*, not runtime behavior)
- Story 008: the authored `.tres` entries the validator will lint at CI/boot
- Inventory overflow validation (AC-CD-23) — owned by Inventory

---

## QA Test Cases

- **AC-1** (AC-CD-15): malformed effect_params
  - Given: RESTORE_STRUCTURE with `{}`; REDUCE_HEAT with `{"amount":"fifty"}`
  - When: validate
  - Then: each emits an error naming the `consumable_id` + the offending key; entry flagged unusable
  - Edge cases: a generic-error impl fails the naming check; a silent-skip impl emits nothing
- **AC-2** (AC-CD-16): strict buy > sell
  - Given: `{buy=10,sell=10}`, `{buy=9,sell=10}`, `{buy=11,sell=10}`
  - When: validate
  - Then: first two → error, third → no error
  - Edge cases: **the `buy==sell` equal case is the canonical discriminator** — a `<`-only impl passes it silently
- **AC-3** (AC-CD-17): unknown effect_type
  - Given: `"GRANT_XP"`; `"RESTORE_STRUCTURE"`
  - When: validate
  - Then: first → error naming id + type; second → no error
  - Edge cases: a permissive check passes `GRANT_XP`; an over-strict check wrongly rejects the valid type
- **AC-4** (AC-CD-18, ADVISORY): roster
  - Given: the authored catalog (8 entries)
  - When: validate
  - Then: no roster warning; a 7-entry catalog or one containing a `BOSS_GRADE` → warning
- **AC-5** (AC-CD-19, ADVISORY): context/target coherence
  - Given: Beacon set to `WORLD`, or a Jammer set to `BATTLE`
  - When: validate
  - Then: incoherent pairing → warning; the coherent authored roster → none

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/consumable_validator_test.gd` — must exist and pass

**Status**: [x] Passing — full GUT suite 452/452 green (2026-07-16)

---

## Dependencies

- Depends on: Story 001 (schema + enums the validator reads)
- Unlocks: Story 008 (authored content passes this validator at CI/boot)
