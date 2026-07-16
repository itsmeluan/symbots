# Story 006: Passive referential integrity & catalog wiring

> **Epic**: Passive Database
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/passive-database.md`
**Requirement**: `TR-pdb-001` (cross-DB `passive_id` reference resolution — the Part→Passive membership seam)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Cross-DB references are `StringName` IDs resolved via a lightweight `{StringName: true}` membership set (never a `Resource` link); a canonical static builder populates the set identically in the real boot and in every test fixture.

**Engine**: Godot 4.7 | **Risk**: LOW (mirror the existing `move_ids_from` builder; the consuming validator check already exists)
**Engine Notes**: The seam is **already half-built** — `content_catalogs.gd:43` reserves an empty `passive_ids: Dictionary` slot, and `content_validator.gd:766` already emits `content_dangling_passive_ref` when a `part.passive_id` is absent from `_passive_ids`. This story supplies the missing **builder** (`ContentCatalogs.passive_ids_from(catalog)`, mirroring `move_ids_from`, `content_catalogs.gd:58`) and wires the real Passive catalog into the boot path so `_passive_ids` is populated from real content instead of `{}`.

**Control Manifest Rules (this layer)**:
- Required: Cross-DB refs are `StringName` id-set membership checks (`.has(id)`), populated by one canonical builder shared by boot + tests — source: ADR-0003
- Forbidden: Never link content by `Resource` reference across DBs (`content_cross_db_resource_link`); never scan a dir to build the set — source: ADR-0003
- Guardrail: O(n) build once, O(1) `.has()` resolution

---

## Acceptance Criteria

*From GDD EC-PDB-01 downstream + AC-PDB-13:*

- [ ] `ContentCatalogs.passive_ids_from(catalog: PassiveCatalog) -> Dictionary` builds a `{StringName: true}` set from `catalog.entries` (null catalog / null entry contribute nothing) — mirrors `move_ids_from`
- [ ] A part whose `passive_id` references an id **not** in the Passive catalog produces a `content_dangling_passive_ref` error naming the **part id and the missing passive id** — **AC-PDB-13**
- [ ] A part whose `passive_id` **is** present in the catalog produces no such error; `&""` (no reference) is skipped
- [ ] The real boot populates `catalogs.passive_ids` from the loaded Passive catalog (no longer the empty `{}` placeholder)

---

## Implementation Notes

*Derived from ADR-0003 + the existing validator seam:*

This is primarily *wiring*, not new logic — the check at `content_validator.gd:766–767` already exists (shipped with Part-DB). Add the `passive_ids_from` static builder next to `move_ids_from` in `content_catalogs.gd`; populate `catalogs.passive_ids` at boot from the real `PassiveCatalog`; and add the `passives: PassiveCatalog` slot to `ContentCatalogs` if Story 004 has not already (APPEND-ONLY). Keep the `references_mounted` gating discipline: the dangling-ref family should behave for both a mounted-index fixture and prior-story fixtures that mount none (they stay green). Confirm existing Part-DB validator tests still pass unchanged.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Stories 004/005: in-catalog Passive schema/authoring validation
- Story 007: the rider content that makes real `passive_id` targets resolvable
- TBC epic: EC-PDB-02 / AC-PDB-02 — the *runtime* divergence between the Passive catalog and TBC's Rule 13 registry (skip + log). This story covers only the *authoring-time* Part→Passive reference check.

---

## QA Test Cases

- **AC-1** (AC-PDB-13): dangling reference errors
  - Given: a part with `passive_id = &"ghost_passive"` and a Passive catalog that does not contain it
  - When: the validator runs with the passive id-set mounted
  - Then: one `content_dangling_passive_ref` naming the part id and `&"ghost_passive"`
  - Edge cases: `passive_id = &""` produces no error; a part whose `passive_id` IS in the catalog produces no error
- **AC-2**: builder correctness
  - Given: a `PassiveCatalog` with three entries (one entry null)
  - When: `passive_ids_from(catalog)` is called
  - Then: the returned set has exactly the two non-null ids mapped to `true`
  - Edge cases: a null catalog returns `{}`; an empty catalog returns `{}`
- **AC-3**: boot population
  - Given: the real boot content-load path
  - When: catalogs are assembled
  - Then: `catalogs.passive_ids` is non-empty and contains the three MVP rider ids (post Story 007)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/passive_referential_integrity_test.gd` — must exist and pass

**Status**: [x] Created & passing (370/370 GUT, 2026-07-16)

---

## Dependencies

- Depends on: Story 002 (catalog loads), Story 004 (adds the `passives` catalog slot to `ContentCatalogs`, if not already present)
- Unlocks: Story 007 (rider ids become resolvable targets for Part `passive_id` references)
