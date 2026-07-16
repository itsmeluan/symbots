# Story 010: MVP enemy roster content authoring

> **Epic**: Enemy Database
> **Status**: BLOCKED — Part-DB content gate (see Blocker below)
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## ⛔ Blocker (2026-07-16) — insufficient break-gated Part-DB content

The dependency gate (line 22) has tripped at implementation time. The story's own
pass condition is **0 errors AND 0 roster/coherence warnings** (AC line 40) with
**each enemy gating ≥2 parts behind breaks** (AC-ED-19, AC line 38). A full scan of
the 14 authored parts in `assets/data/parts/` finds only **two** with non-empty
`drop_conditions`:

| Part | Rarity | Break condition | Legal on |
|---|---|---|---|
| `scrapjaw_rustcrawler_claw` | 3 (BOSS_GRADE) | `arm_broken` | BOSS only (boss-grade on WILD → BLOCKING error, Story 007) |
| `wild_overdrive_cannon` | 4 (PROTOTYPE) | `overheat_kill` | any |

The four authored RARE parts have **empty** `drop_conditions` → they cannot appear
in any loot pool without an AC-ED-18 (un-gated Rare) warning.

**Consequence:** every WILD needs ≥2 break-gated parts, but only ONE non-boss-grade
break-gated part exists (`wild_overdrive_cannon`) → all ~8 WILD entries trip
AC-ED-19. Zero-warning authoring is impossible against the current Part roster.
Per the story's explicit instruction, we stop and flag rather than invent part ids
the validator would reject. Stories 001–009 (schema + all validator families) are
**Complete and green** — this trailing content-authoring story is the only gated
item, and it is gated on Part-DB *content*, not on any Enemy-DB code.

**Unblock paths:** (a) flesh out the Part-DB roster with break-gated parts across a
small break-event vocabulary (arm/leg/head/overheat/core), then author this roster;
or (b) co-author a minimal matching break-gated part set alongside the enemy roster.
Both cross into Part-DB *content* authoring, which this story lists as Out of Scope.

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: realizes `TR-edb-018` (floor-loot rarity), `TR-edb-019` (skills present), `TR-edb-023` (min break-gated parts) as authored data
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping — pure data configuration against the Story-001 schema.
**ADR Decision Summary**: Content ships as typed `.tres` defs resolved through one explicit catalog; validated at CI + dev-boot by the ContentValidator (Stories 004–009).

**Engine**: Godot 4.7 | **Risk**: MEDIUM (data authoring, but every enemy's `loot_pool` cross-references real Part-DB ids with matching `break_event`/`drop_condition` linkage, and every `break_hp` must equal the EDB-1 derivation — mis-authoring reds the validator)
**Engine Notes**: Author the MVP roster (~8 WILD + 2 BOSS per the GDD content-density guideline) as `EnemyDef` `.tres` in `assets/data/enemies/` + one `EnemyCatalog` `.tres` in `assets/data/catalogs/` (mirror `passive_catalog.tres`). All values come from the GDD roster/tuning tables + the manufacturer identity map (Ironclad/Boltwell/Scrapjaw/wild) — no invented numbers. Each `break_hp` is the **EDB-1-derived** value (compute via Story-003's function, don't eyeball). `loot_pool` part ids must resolve in the Part DB and obey the class/rarity rules (Story 007).

> ⚠ **Dependency gate**: this story needs a Part-DB roster rich enough that each enemy's `loot_pool` references real authored parts with matching `break_event`/`drop_condition` linkage. Currently the Part DB has sparse authored content. **This is the epic's trailing story** — author it once the Part-DB roster is fleshed out, or co-author a minimal matching part set first. If Part content is insufficient at pickup time, flag it and stop rather than inventing part ids the validator will reject.

**Control Manifest Rules (this layer)**:
- Required: content is data-driven `.tres`, resolved via the explicit catalog; passes the ContentValidator (Stories 004–009) at CI/boot; `break_hp` = EDB-1 derived — source: ADR-0003 / GDD EDB-1
- Forbidden: `ELITE`/`RIVAL` enemies (reserved); `loot_pool` part ids absent from the Part DB; boss-grade parts on WILD enemies; hand-eyeballed `break_hp`; invented stat/xp numbers — source: GDD Rules / Story 007
- Guardrail: ~8 WILD + 2 BOSS per the GDD density guideline; every enemy `loot_pool.size() > break_regions.size()` (harvest-decision, Story 008)

---

## Acceptance Criteria

*From GDD roster/tuning tables + manufacturer identities, realizing AC-ED-18/19:*

- [ ] ~8 WILD + 2 BOSS `EnemyDef` `.tres` authored with exact GDD stat/level/xp/loot values (no invented numbers)
- [ ] Every enemy: ≥1 skill (resolving in the Move DB — Complete), a valid `ai_profile` tag, ≥1 break region, `loot_pool.size() > break_regions.size()`
- [ ] Every `break_hp` equals `derive_break_hp(structure, region_fraction)` (Story 003)
- [ ] Every `loot_pool` part id resolves in the Part DB; WILD carry no boss-grade exclusives; each BOSS gates ≥2 distinct parts behind breaks (AC-ED-19); floor loot within the rarity ceiling (AC-ED-18)
- [ ] `completion_bonus_xp` zero on WILD, positive only on the 2 BOSSes
- [ ] One `EnemyCatalog` `.tres` references all entries; the ContentValidator passes with 0 errors and 0 roster/coherence warnings

---

## Implementation Notes

*Derived from GDD roster tables + manufacturer identity map + the passive/consumable catalog precedent:*

Every number is in the GDD — do not invent. Stats from the roster table; `level`/`xp_value`/`completion_bonus_xp` from the ELZS-erratum columns (xp_value = CP-F4 derived, Story 009); `break_hp` = EDB-1 derived (Story 003 — compute each, don't guess). Element/manufacturer flavor from the identity map (project memory `manufacturer-identities`). Wire the catalog exactly like `assets/data/catalogs/passive_catalog.tres`. After authoring, run the suite headless — Stories 004–009's `_validate_enemy_catalog` must pass clean. Produce a smoke doc recording the validator pass + a spot-check that each `break_hp` round-trips against the formula and each `loot_pool` id resolves. **If the Part-DB roster can't back the loot pools yet, stop and flag** (see the dependency gate above) — a green validator on invented part ids is impossible, and inventing ids to force green defeats the referential check.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Stories 004–009: the validator family that lints this content (this story produces the content it lints)
- The runtime that *spawns* / *fights* / *awards loot from* these enemies (Encounter Zone / TBC / Drop — DEFERRED integrations AC-ED-11/12/16)
- Part-DB content authoring (a separate epic — this story *references* parts, doesn't author them)
- Icons / sprites / VFX (Art Bible, not this DB)

---

## QA Test Cases

**Config/Data — smoke check:**

- **Setup**: load the authored `EnemyCatalog` headless through the ContentValidator (Stories 004–009 families active), with the Part DB + Move DB catalogs also loaded (referential checks live)
- **Verify**: ~8 WILD + 2 BOSS entries; every `break_hp` == EDB-1 derived; every `loot_pool` id resolves in the Part DB; WILD carry no boss-grade parts; each BOSS gates ≥2 parts; `loot_pool.size() > break_regions.size()` for all; `completion_bonus_xp` zero on WILD; `xp_value` == CP-F4 derived
- **Pass condition**: validator returns `ok == true`, 0 errors, 0 roster/coherence warnings; full GUT suite green

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass — `production/qa/smoke-enemies-[date].md`

**Status**: [ ] BLOCKED — cannot produce a 0-warning smoke pass; only 2 break-gated parts exist in the Part DB (see Blocker above). No content authored (would require inventing part ids the validator rejects).

---

## Dependencies

- Depends on: Story 001 (schema), Stories 003–009 (formula + validator families lint this content), Part DB (Complete — loot referential source; **needs a richer authored roster**), Move DB (Complete — skills referential)
- Unlocks: Encounter Zone / TBC / Drop System errata (they read this authored roster)
