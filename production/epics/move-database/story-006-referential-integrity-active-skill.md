# Story 006: Referential integrity — active_skill_id ↔ Move DB

> **Epic**: Move Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/move-database.md`
**Requirement**: EPIC Definition of Done — "Referential integrity to the Part DB (`active_skill_id` resolution) is verified"; GDD EC-MDB-01 (a part's `active_skill_id` pointing at a missing move) and the Part↔Move linkage (GDD Dependencies)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Cross-DB references are `StringName` IDs resolved through a membership set, never `Resource` links; `ContentCatalogs` already carries a `move_ids` seam and a `references_mounted` gate for exactly this class of check.

**Engine**: Godot 4.7 | **Risk**: LOW (uses the existing `move_ids` / `references_mounted` seam)
**Engine Notes**: `ContentCatalogs.move_ids` (a `{StringName: true}` set) and `references_mounted` already exist for cross-DB resolution. This story populates that set from the loaded `MoveCatalog` and adds the resolution check. The Story-009 Part-DB referential family established the pattern (`references_mounted`-gated so prior fixtures stay green).

**Control Manifest Rules (this layer)**:
- Required: cross-DB references resolved via `StringName` id membership; CI-blocking validation — source: ADR-0003
- Forbidden: `Resource`-link cross-DB references; `global_push_diagnostics` — source: ADR-0003/0002
- Guardrail: O(1) `.has(id)` membership; validation pure over the aggregate

---

## Acceptance Criteria

*From EPIC DoD + GDD EC-MDB-01 + Part↔Move linkage:*

- [ ] The `MoveCatalog`'s ids are mountable into `ContentCatalogs.move_ids` (populate the existing seam from the loaded catalog)
- [ ] With references mounted, every `PartDef` with a non-null `active_skill_id` that does not resolve to a Move DB id errors naming both part and skill id — `content_active_skill_unresolved`
- [ ] A part with `active_skill_id == &""` (no active skill) is never flagged (support slots, Commons)
- [ ] The check is gated by `references_mounted` — prior-story fixtures that mount no reference index skip it and stay green
- [ ] Integration test builds a Part catalog + Move catalog together and proves both the resolving (clean) and dangling (error) cases

---

## Implementation Notes

*Derived from the Part-DB Story-009 referential family + `content_catalogs.gd`:*

Add a `_validate_active_skill_refs(catalogs)` path in `ContentValidator`, run only when `catalogs.references_mounted`. For each part, if `active_skill_id != &""` and not `catalogs.move_ids.has(active_skill_id)` → `content_active_skill_unresolved`. Provide a small helper to build `move_ids` from a `MoveCatalog` (`for m in catalog.entries: move_ids[m.id] = true`) so the real boot and the test fixture populate it identically. This is the Move-DB fulfilment of EC-MDB-01's lookup contract at the *content* layer (the *runtime* null-return is Story 002/AC-MDB-01).

---

## Out of Scope

- Runtime resolution of a dangling `active_skill_id` at battle time (Assembly EC-SA-04 / TBC EC-TBC-11 render it "—")
- Enemy `skills` → Move DB resolution (Enemy DB epic; same pattern, its own story)
- Move → Passive rider resolution (Passive DB epic)

---

## QA Test Cases

- **AC-1** (referential resolve): a Part catalog where every `active_skill_id` matches a move in the Move catalog → validator clean
  - Given: parts A(`skill_x`), B(`skill_y`) + moves `skill_x`, `skill_y`, `references_mounted = true`
  - When: validate
  - Then: no `content_active_skill_unresolved`
- **AC-2** (dangling reference): a part with `active_skill_id = &"skill_ghost"` absent from the Move catalog → `content_active_skill_unresolved` naming part + `skill_ghost`
  - Edge: a part with `active_skill_id == &""` is never flagged; with `references_mounted = false` the whole check is skipped

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/content/move_referential_integrity_test.gd` — must exist and pass (builds Part + Move catalogs together)

**Status**: [x] Created & passing — `tests/integration/content/move_referential_integrity_test.gd` (8 tests: canonical builder incl. null-catalog + null-entry; AC-1 all-resolve clean; AC-2 dangling names part+skill + partial-dangling isolates the bad part; edge &"" never flagged + unmounted-skip). Builds Part + Move catalogs together; `move_ids` populated via the canonical `ContentCatalogs.move_ids_from(catalog)` builder (the real-boot path). **Seam reconciliation (user-approved, Option A):** the Story-009 placeholder `content_dangling_skill_ref` was unified into the single canonical Part↔Move code `content_active_skill_unresolved` — validator + the 3 Story-009 integration asserts updated; tech-debt register line 24 marked RESOLVED. Full suite **229/229 green, 2881 asserts** (Godot 4.7 + GUT 9.7.1).

---

## Dependencies

- Depends on: Story 001 (MoveCatalog), Story 002 (MoveDB), Story 004 (`_validate_move` dispatch + `moves` on `ContentCatalogs`)
- Unlocks: Enemy DB skill-resolution + Passive rider-resolution stories reuse this cross-DB pattern
