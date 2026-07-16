# Story 010: MVP enemy roster content authoring

> **Epic**: Enemy Database
> **Status**: Ready — Part-DB content gate CLEARED 2026-07-16 (see Unblock Record)
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## ✅ Unblock Record (2026-07-16) — break-gated Part-DB roster authored

The earlier BLOCKED gate (only 2 of 14 parts carried `drop_conditions`, one
BOSS-only) is **resolved**. The Part-DB roster was enriched with an anatomy-linked
break-event vocabulary (GDD Rule 5, "anatomy-linked loot") shared by enemy
`break_regions` and part `drop_conditions`:

| break_event | Slot yielded | Gated parts (rarity) |
|---|---|---|
| `head_broken` | HEAD | `wild_optic_sensor`(C), `boltwell_targeting_array`(R) |
| `arm_broken` | ARMS | `scrapjaw_servo_arm`(C), `scrapjaw_reinforced_servo_arm`(R), `scrapjaw_rustcrawler_claw`(BOSS) |
| `leg_broken` | LEGS | `wild_tread_legs`(C) |
| `weapon_broken` | WEAPON | `scrapjaw_bash_hammer`(C), `boltwell_arc_blaster`(R), `boltwell_storm_lance`(BOSS) |
| `chassis_cracked` | CHASSIS | `ironclad_bulwark_frame`(C) |
| `core_exposed` | CORE/CHIPSET/ENERGY_CELL | `scrapjaw_scrap_core`(C), `boltwell_logic_chip`(C), `boltwell_cell_mk1`(C), `boltwell_surge_core`(R) |

**Changes** (part_catalog_ci_test 623/623 green, 15 parts, 0 validator errors):
- 12 existing parts enriched with slot-matched `drop_conditions` (commons ×2.5,
  rares ×3.0). RARE parts each keep exactly 1 effect — enrichment is effect-neutral.
- **New** `boltwell_storm_lance` — a 2nd BOSS_GRADE exclusive (Boltwell/Volt WEAPON,
  `weapon_broken` ×600, product 0.6 ≥ 0.5 guarantee) so the two MVP bosses drop
  distinct exclusives (kinetic arm vs volt weapon). CI manifest extended with its
  `skill_storm_lance` / `pass_overload` forward-refs.

**Now authorable at 0 warnings:** every WILD with ≥2 distinct anatomy regions fields
≥2 break-gated pool parts (AC-ED-19); the 2 bosses each gate a distinct BOSS_GRADE
exclusive (AC-ED-09). **Content-variety note for authoring:** THERMAL has no RARE
(only `ironclad_bulwark_frame` common) — spread THERMAL wilds' Rare loot across
neighbouring elements or accept a Volt/Kinetic-leaning Rare pool for MVP.

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

**Status**: [ ] Not started — Part-DB gate CLEARED 2026-07-16 (see Unblock Record). The break-gated roster now supports a 0-warning enemy roster; enemy `.tres` authoring + smoke pass still to be done.

---

## Dependencies

- Depends on: Story 001 (schema), Stories 003–009 (formula + validator families lint this content), Part DB (Complete — loot referential source; **needs a richer authored roster**), Move DB (Complete — skills referential)
- Unlocks: Encounter Zone / TBC / Drop System errata (they read this authored roster)
