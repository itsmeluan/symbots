# Epic: Enemy Database

> **Layer**: Foundation
> **GDD**: design/gdd/enemy-database.md
> **Architecture Module**: Content DBs (Part/Move/Passive/Consumable/Enemy)
> **Status**: Ready
> **Stories**: 10 stories — see table below

## Overview

The Enemy Database is the read-only schema and catalog for every wild machine and
boss: class (WILD/BOSS), core element, the 11-stat block, break regions and their
`break_hp`, loot pools, XP value, and level. It is the harvest-target authority —
its break-region / loot-pool rules encode Pillar 2 ("every battle has a harvest
goal"), and its power caps keep early wild fights from one-shotting the player.
This epic delivers the typed `Enemy` resource, the catalog loader, and the dense
validation layer: the `break_hp` stored-equals-derived invariant, the TTK
calibration check, boss-grade exclusivity, floor-loot rarity gating, and the
`loot_pool > break_regions` non-degenerate-choice rule.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Content Resource Loading & Schema Mapping | Typed `.tres` defs, one catalog per DB, CI + dev-boot ContentValidator; read-only-at-runtime | MEDIUM (HIGH for typed-dict `@export` / `.tres` round-trip) |

## GDD Requirements

All 24 requirements are traced to ADR-0003 (architecture review: 0 Foundation gaps).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-edb-001 | Enemy schema: id, display_name, WILD\|BOSS, tier=1 MVP, nullable core_element, 11-stat Dictionary | ADR-0003 ✅ |
| TR-edb-002 | break_hp stored-equals-derived: max(BREAK_HP_MIN, floor(structure×fraction+0.0001)); validated on import | ADR-0003 ✅ |
| TR-edb-003 | break_hp epsilon load-bearing: valid-range inputs produce wrong results without +0.0001 | ADR-0003 ✅ |
| TR-edb-004 | Break region validity (EDB-3): break_hp < structure AND break_event matches ≥1 pool part's drop_conditions | ADR-0003 ✅ |
| TR-edb-005 | WILD power cap: physical/energy_power ≤ 39 prevents one-shot vs zero-armor super-effective | ADR-0003 ✅ |
| TR-edb-006 | WILD power derivation: A=39 D=0 T=1.5 → 58 < 60 min Structure safe; A=40 one-shots | ADR-0003 ✅ |
| TR-edb-007 | TTK calibration (EDB-2): computed check normative, not static ranges; bounds structure×defense | ADR-0003 ✅ |
| TR-edb-008 | Boss-grade exclusivity: BOSS pools 1–2 exclusives; WILD pools forbid Boss-grade | ADR-0003 ✅ |
| TR-edb-009 | Floor loot rarity: Common ungated valid; Rare/Boss-grade carry ≥1 break condition | ADR-0003 ✅ |
| TR-edb-010 | Harvest-decision rule (hard): loot_pool.size() > break_regions.size(); equality fails | ADR-0003 ✅ |
| TR-edb-011 | Stat keys use Part DB 11-name vocabulary; A/D constrained [0,110] (DF-1 verified range) | ADR-0003 ✅ |
| TR-edb-012 | Dead-data warning: no Heat/Energy MVP; cooling/energy_capacity/recharge warn if non-zero | ADR-0003 ✅ |
| TR-edb-013 | Boss-grade product invariant: BASE_DROP_BOSS_GRADE × multiplier ≥ 0.5 (base .001 ⇒ ×500) | ADR-0003 ✅ |
| TR-edb-014 | region_fraction bounds [0.15,0.55]: opener/mid/expert commit tiers | ADR-0003 ✅ |
| TR-edb-015 | xp_value stored-equals-derived: equals CP-F4 (XP_BASE+level×XP_PER_LEVEL)×role_mult | ADR-0003 ✅ |
| TR-edb-016 | completion_bonus_xp: ≥0, zero WILD, BOSS non-zero; added on first boss defeat only | ADR-0003 ✅ |
| TR-edb-017 | level field: ≥1 ≤10; zone [level_floor,level_roof] must include value | ADR-0003 ✅ |
| TR-edb-018 | loot_pool entries exist in Part DB; duplicates deduplicated with warning; all-disabled pool fails | ADR-0003 ✅ |
| TR-edb-019 | skills.size() ≥ 1 blocking; > 4 advisory warn | ADR-0003 ✅ |
| TR-edb-020 | Null core_element density: NULL_ELEMENT_MAX_WILD=1 per zone; null → ×1.0 effectiveness | ADR-0003 ✅ |
| TR-edb-021 | Region break events set semantics: same break_event fires once; Drop deduplicates | ADR-0003 ✅ |
| TR-edb-022 | Minimum 1 break region (EC-ED-01); zero violates Pillar 2 | ADR-0003 ✅ |
| TR-edb-023 | Ungated pool parts must be Common; Rare/Boss-grade ungated undermines Pillar 2 | ADR-0003 ✅ |
| TR-edb-024 | ≥2 break-gated parts advisory: <2 warns (degenerate harvest choice) | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/enemy-database.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The `break_hp` stored-equals-derived invariant has a GUT test with a discriminating
  fixture proving the epsilon is load-bearing (a bare floor produces a wrong value)
- The ContentValidator enforces TTK calibration, boss-grade exclusivity, floor-loot
  rarity gating, and `loot_pool > break_regions` (CI + dev-boot)
- If this epic's ContentValidator family pushes `src/core/content/content_validator.gd` past
  ~1500 lines, extract the per-DB check families into composed `RefCounted` helpers **behind
  the single `validate()` entry point** — preserving the ADR-0003 "single ContentValidator"
  contract (no behavior change; a pure structural split with the suite green before and after).
  Provenance: `/code-review` 2026-07-16 file-size watch (validator at 1170 lines after Story-011)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | EnemyDef schema, enums & EnemyCatalog | Logic | Ready | ADR-0003 |
| 002 | EnemyDB loader & null-safe lookup | Logic | Ready | ADR-0003 |
| 003 | EDB-1 break_hp derivation formula (epsilon load-bearing) | Logic | Ready | ADR-0003 |
| 004 | ContentValidator enemy schema-presence family | Logic | Ready | ADR-0003 |
| 005 | ContentValidator enemy stat-block family | Logic | Ready | ADR-0003 |
| 006 | ContentValidator break-region family (EDB-3 + stored-equals-derived) | Logic | Ready | ADR-0003 |
| 007 | ContentValidator loot-pool, rarity & boss-grade gating family | Logic | Ready | ADR-0003 |
| 008 | ContentValidator harvest-decision, TTK & density/spawn warnings | Logic | Ready | ADR-0003 |
| 009 | ContentValidator ELZS progression-field family | Logic | Ready | ADR-0003 |
| 010 | MVP enemy roster content authoring | Config/Data | Ready | ADR-0003 |

10 stories total: 9 Logic (7 Content-Val + 1 formula unit + 1 loader), 1 Config/Data.

**Two implementation seams flagged at storying (2026-07-16):**
- **Referential seams now live**: Part DB + Move DB are **Complete**, so loot referential
  integrity (Story 007) and skills referential (Story 010) wire against real lookups.
  `EnemyAI` is an *approved GDD only* — Story 004 builds `ai_profile` referential as an
  **injected accept-all predicate seam** (non-empty check active now; `has_profile` wired
  when EnemyAI lands). No false negatives in the interim.
- **Story 010 is dependency-gated**: authoring needs a richer Part-DB roster so each
  `loot_pool` references real part ids with matching `break_event` linkage. It is the
  epic's trailing story — flagged in the story to stop-and-flag rather than invent ids.

**Deferred cross-system integration (NOT storied here — tracked as errata on the owning epics):**
AC-ED-11 (Encounter Zone spawn-table exclusion of `spawn_enabled == false`), AC-ED-12 (Drop
System break-event set dedup at award time), AC-ED-16 (TBC null-`core_element` damage path).
Each is noted in the relevant story's `## Out of Scope`; the DB owns schema + formulas +
validation + content only.

## Next Step

Run `/story-readiness production/epics/enemy-database/story-001-enemydef-schema-enums-catalog.md` → `/dev-story` to begin implementation. Work stories in dependency order (each story's `Depends on:` field gates it); Story 010 trails until the Part-DB roster can back its loot pools.
