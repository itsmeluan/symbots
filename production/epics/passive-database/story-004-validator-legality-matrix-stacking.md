# Story 004: Passive validator — schema-family + trigger×behavior legality matrix

> **Epic**: Passive Database
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/passive-database.md`
**Requirement**: `TR-pdb-002` (trigger×behavior legality matrix enforced) + `TR-pdb-004` (authored `stacking_policy` matches the `behavior_class` default)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content correctness is enforced by a `ContentValidator` run in CI and at dev-boot; each violation is a typed error code naming the offending id; the validator is pure (catalog in → error list out), never mutating content.

**Engine**: Godot 4.7 | **Risk**: LOW (table-driven checks over loaded defs; no post-cutoff API)
**Engine Notes**: Extend the existing `ContentValidator` (`src/core/content/content_validator.gd`) — do not create a parallel validator. Follow its established `_error(&"code", {...})` convention and the per-family gating pattern (a family runs only when its catalog slot is mounted, like the Move families gate on `catalogs.moves != null`). Read the Rule 3 legality table from GDD; encode it as a `const` set of legal `(trigger_category, behavior_class)` pairs.

**Control Manifest Rules (this layer)**:
- Required: A dev-boot + CI `ContentValidator` rejects malformed content with a typed, id-naming error — source: ADR-0003
- Forbidden: Never mutate/`duplicate()` a def inside the validator; never skip a failing content check to make CI pass — source: ADR-0003 / coding-standards
- Guardrail: validator is pure and deterministic — same catalog → same error list

---

## Acceptance Criteria

*From GDD Rule 3 (legality matrix) + Rule 4 + AC-PDB-15:*

- [ ] An entry with an **illegal** `trigger_category × behavior_class` pairing (per Rule 3 — e.g. `STATUS_RIDER` + `ON_BATTLE_START`) is rejected, the error naming the passive id **and** the illegal pairing — **AC-PDB-15**
- [ ] Every **legal** pairing in the Rule 3 matrix passes (positive cases: `STATUS_RIDER×ON_HIT`, `STAT_AURA×PERSISTENT`, `RESOURCE_EFFECT×{ON_BATTLE_START,ON_OVERHEAT,ON_TURN_START}`, `STRUCTURAL_EFFECT×{ON_BATTLE_START,ON_OVERHEAT}` — mirror the exact table in the GDD)
- [ ] Structural schema checks: required fields present, each enum within range (not the 0 INVALID sentinel where a real value is required)
- [ ] An authored `stacking_policy` that does **not** match its `behavior_class` default (Story 003 table) is flagged, naming the id and the expected policy — **TR-pdb-004**

---

## Implementation Notes

*Derived from ADR-0003 + GDD Rule 3 / Rule 4:*

Add a Passive schema/legality family to `ContentValidator`, gated on `catalogs.passives != null` (append a `passives: PassiveCatalog` slot to `ContentCatalogs` alongside `parts`/`moves` — APPEND-ONLY, mirror the existing slot doc-comments). Encode Rule 3 as a `const` `Dictionary`/set of legal pairs and check membership; on miss emit `content_illegal_passive_pairing` with `{id, trigger, behavior}`. Reuse Story 003's default table for the stacking check (`content_passive_stacking_mismatch`). Copy the exact legality table from the GDD — do NOT infer it; an author reading the error must see the same matrix the GDD documents.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 005: `behavior_params` payload validation, STRUCTURAL non-negative, Core trigger restriction (AC-PDB-12/14/16)
- Story 006: cross-DB `passive_id` referential integrity (AC-PDB-13)
- TBC epic: any runtime firing — the validator only rejects *authoring* errors, it does not execute passives

---

## QA Test Cases

- **AC-1** (AC-PDB-15): illegal pairing rejected
  - Given: a `PassiveDef` with `behavior_class = STATUS_RIDER`, `trigger_category = ON_BATTLE_START`
  - When: the validator runs
  - Then: exactly one error `content_illegal_passive_pairing` naming the id and the pairing
  - Edge cases: one legal + one illegal entry in the same catalog → only the illegal one errors; a def at the INVALID enum sentinel errors as malformed, not as an illegal pairing
- **AC-2**: legal pairings pass
  - Given: one `PassiveDef` per legal Rule-3 pairing
  - When: the validator runs
  - Then: zero legality errors across all legal pairings
- **AC-3** (TR-pdb-004): stacking mismatch flagged
  - Given: a `STAT_AURA` passive authored with `stacking_policy = STACKABLE` (default is `UNIQUE`)
  - When: the validator runs
  - Then: one `content_passive_stacking_mismatch` error naming the id and expected `UNIQUE`
  - Edge cases: a passive whose policy matches its default produces no error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/passive_validator_schema_test.gd` — must exist and pass

**Status**: [x] Created & passing (370/370 GUT, 2026-07-16)

---

## Dependencies

- Depends on: Story 002 (validator runs over a loaded catalog), Story 003 (stacking default table)
- Unlocks: Story 007 (riders must pass this validator)
