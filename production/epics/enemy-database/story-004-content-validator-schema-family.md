# Story 004: ContentValidator enemy schema-presence family

> **Epic**: Enemy Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-001` (schema presence/type + id uniqueness), `TR-edb-019` (skills count: ≥1 blocking, >4 advisory)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: A single DI-testable `ContentValidator` (RefCounted) blocks CI and fail-louds dev boot; returns `{ok, errors, warnings}`; all diagnostics go through an injected `LogSink` (`_error`/`_warn`), never `push_error`/`push_warning`. "Extend never fork": add a new per-DB check family + dispatch wiring gated on the injected catalog, never modify existing checks.

**Engine**: Godot 4.7 | **Risk**: MEDIUM (integrate into the existing validator without touching sibling families; establishes the enemy dispatch seam the later stories extend)
**Engine Notes**: Add `consumables`-style: append an `enemies: EnemyCatalog` slot to `ContentCatalogs` (**APPEND-ONLY**, after the last slot). Add `_validate_enemy_catalog(catalogs, log)` dispatched from `validate()` **only when `catalogs.enemies != null`** — so existing part/move/passive/consumable-only fixtures are unaffected. This story owns the *schema-presence* checks; Stories 005–009 add sibling `_check_enemy_*` methods to the same family. Error codes: `content_enemy_*`. Every diagnostic names the `enemy_id`.

**ai_profile referential seam**: `ai_profile` non-empty (`!= &""`) is checked **now** (BLOCKING). The referential half — `EnemyAI.has_profile(ai_profile)` — is built as an **injected predicate seam** (a `Callable`/interface defaulting to "accept-all" until the EnemyAI implementation lands), mirroring how Part↔Move referential integrity was seam-built. Wire it live when EnemyAI exists; the seam keeps this story shippable now.

**Control Manifest Rules (this layer)**:
- Required: single `ContentValidator`; diagnostics via injected `LogSink`; family gated on `catalogs.enemies != null`; APPEND-ONLY `ContentCatalogs` slot — source: ADR-0003/0002
- Forbidden: `push_error`/`push_warning`; modifying sibling families ("extend never fork"); reordering `ContentCatalogs` fields; declaring `ELITE`/`RIVAL` as accepted classes — source: ADR-0002/0003
- Guardrail: **if `content_validator.gd` crosses ~1500 lines, extract per-DB families into composed `RefCounted` helpers behind the single `validate()` entry** (EPIC DoD, provenance: `/code-review` 2026-07-16)

---

## Acceptance Criteria

*From GDD AC-ED-01 (presence/type), AC-ED-02 (uniqueness), AC-ED-03 (skills count + ai_profile), AC-ED-13a (tier), AC-ED-13b (flavor length):*

- [ ] **Presence/type** (AC-ED-01): missing/wrong-typed required field → error naming `enemy_id` + field; `enemy_class == INVALID` (or an unlisted class) → error
- [ ] **id uniqueness** (AC-ED-02): two entries sharing an `id` → error naming the duplicate; all-unique → no error
- [ ] **skills count** (AC-ED-03/TR-edb-019): `skills.size() == 0` → error (an enemy must have ≥1 skill); `> 4` → ADVISORY warning
- [ ] **ai_profile** (AC-ED-03): `ai_profile == &""` → error; referential `has_profile` checked via the injected seam (accept-all until EnemyAI lands, no false-negative now)
- [ ] **tier** (AC-ED-13a, ADVISORY): `tier != 1` → warning (only tier 1 is live; higher tiers reserved)
- [ ] **flavor length** (AC-ED-13b): `flavor_text` over the GDD length cap → error naming the id
- [ ] Error codes: `content_enemy_schema_missing_field`, `content_enemy_duplicate_id`, `content_enemy_skills_empty`, `content_enemy_ai_profile_missing`, plus warn codes `content_enemy_skills_excess`, `content_enemy_tier_reserved`

---

## Implementation Notes

*Derived from ADR-0003 + the Consumable/Passive validator families:*

Follow the Consumable Story 007 pattern exactly. Append `enemies: EnemyCatalog` to `content_catalogs.gd` (APPEND-ONLY). Add `_validate_enemy_catalog` dispatched only when `catalogs.enemies != null`. Per-check methods this story: `_check_enemy_schema_presence`, `_check_enemy_id_uniqueness`, `_check_enemy_skills_count`, `_check_enemy_ai_profile` (non-empty + seam predicate), `_check_enemy_tier` (warn), `_check_enemy_flavor_length`. Introduce the `ai_profile` seam as a constructor-injected `Callable` (default `func(_p): return true`) so the referential check is *present but inert* until EnemyAI is real — do not stub a fake EnemyAI. Each diagnostic names the `enemy_id`. Discriminating fixtures: a duplicate-id pair; a `skills=[]` entry; a `skills` of size 5 (warn, not error); an `INVALID`-class entry.

**Watch the file-size DoD trigger:** validator ~1170 lines pre-Consumable. This enemy family is the largest yet (spread across Stories 004–009). If cumulative growth crosses ~1500 lines, extract the per-DB families into composed `RefCounted` helpers behind `validate()` (pure structural split, suite green before + after) — per the EPIC Definition of Done.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: stat-block range validation
- Story 006: break-region validity (EDB-1/EDB-3)
- Story 007: loot-pool + rarity + boss-grade gating
- Story 008: TTK / density / spawn warnings
- Story 009: ELZS `level`/`xp_value`/`completion_bonus_xp` validation
- The real `EnemyAI.has_profile` wiring (seam only here — EnemyAI implementation is a separate epic)

---

## QA Test Cases

- **AC-1** (AC-ED-01 presence): missing field / bad class
  - Given: an entry missing `stats`; an entry with `enemy_class = INVALID`
  - When: validate
  - Then: each → error naming `enemy_id` + the offending field/class
  - Edge cases: a generic-error impl fails the naming check; an `ELITE` value (not yet declared) → error
- **AC-2** (AC-ED-02 uniqueness): duplicate id
  - Given: two entries both `id = &"wild_dupe"`
  - When: validate
  - Then: error naming the duplicate id; a unique-id catalog → no error
- **AC-3** (AC-ED-03 skills count): empty vs excess
  - Given: `skills=[]`; `skills` of size 5
  - When: validate
  - Then: empty → error; size-5 → ADVISORY warning (not error)
  - Edge cases: size-1 and size-4 → clean; a `>`-off-by-one impl wrongly warns at 4
- **AC-4** (AC-ED-03 ai_profile): empty + seam
  - Given: `ai_profile = &""`; a non-empty `ai_profile` with the default accept-all seam
  - When: validate
  - Then: empty → error; non-empty → no error (seam inert); injecting a reject-all seam makes the non-empty case error (proves the seam is wired)
- **AC-5** (AC-ED-13a/b): tier + flavor
  - Given: `tier = 2`; a `flavor_text` exceeding the GDD cap
  - When: validate
  - Then: tier → warning; over-length flavor → error naming the id

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/enemy_schema_validator_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema + enums), Story 002 (catalog wiring reference)
- Unlocks: Stories 005–009 (they extend the `_validate_enemy_catalog` family this story creates)
