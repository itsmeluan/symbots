# Epic: Part Database

> **Layer**: Foundation
> **GDD**: design/gdd/part-database.md
> **Architecture Module**: Content DBs (Part/Move/Passive/Consumable/Enemy)
> **Status**: Ready
> **Stories**: 10 stories created (2026-07-15)

## Overview

The Part Database is the read-only schema and catalog for every collectible
Sympart: slot type, the 11 canonical stat bonuses, element, synergy tags, moves,
rarity, upgrade tiers, and drop conditions. It is the root Foundation content
system — Assembly, Combat, Drop tables, Inventory, and Workshop all query it to
understand what a part does. Parts are immutable `.tres` definitions loaded once
at boot; instances (owned copies) are Inventory's concern, never this DB's. This
epic delivers the typed `Sympart` resource schema, the catalog loader, the
authoring/validation rules (Formulas 1/2/2b/3, rarity gates, referential
integrity to Move/Passive DB), and the content-validation pass that runs in CI
and at dev boot.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Content Resource Loading & Schema Mapping | Typed `.tres` defs, one catalog per DB, CI + dev-boot ContentValidator; read-only-at-runtime posture | MEDIUM (HIGH for typed-dict `@export` / `.tres` round-trip) |

## GDD Requirements

All 25 requirements are traced to ADR-0003 (architecture review: 0 Foundation gaps).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-part-001 | Sympart schema fields and types (StringName id, String display_name, enum slot_type, nullable chassis_archetype) | ADR-0003 ✅ |
| TR-part-002 | stat_bonuses constrained to 11 canonical keys; non-zero recharge only CORE/ENERGY_CELL | ADR-0003 ✅ |
| TR-part-003 | Rarity gates skills/passives: Common none; Rare+ skill (non-Core) or passive (Core); Core blocks active skills | ADR-0003 ✅ |
| TR-part-004 | Prototype parts require ≥1 negative stat; Formula 2b reduces toward zero, never positive | ADR-0003 ✅ |
| TR-part-005 | synergy_tags mandatory: element tag all parts; manufacturer tag non-wild only; wild exclude manufacturer | ADR-0003 ✅ |
| TR-part-006 | chassis_archetype non-null CHASSIS only; valid enum (LIGHT/HEAVY/BALANCED/GUARDIAN/ARTILLERY) | ADR-0003 ✅ |
| TR-part-007 | Boss-grade parts need ≥1 drop_conditions entry multiplier ≥500 to reach 50% effective rate | ADR-0003 ✅ |
| TR-part-008 | Formula 2b: per-stat drawback reduction via max(0, 1−tier/3); clamp before negation | ADR-0003 ✅ |
| TR-part-009 | Formula 1: composes Formula 2/2b from 8 parts, applies chassis modifier, floors, clamps to 0+ | ADR-0003 ✅ |
| TR-part-010 | Upgrade tiers: Common +0..+3 cap; Rare/Boss/Proto +0..+5; multipliers ×1.00..×2.00 | ADR-0003 ✅ |
| TR-part-011 | level_requirement field: rarity floors (C1/R3/B6/P8); parts can exceed, never lower | ADR-0003 ✅ |
| TR-part-012 | level_growth (per-level flat bonus): non-null only CORE; Assembly ignores elsewhere | ADR-0003 ✅ |
| TR-part-013 | Skill/passive ID referential integrity: active_skill_id, passive_id resolve to valid Move/Passive entries | ADR-0003 ✅ |
| TR-part-014 | Rare primary floor ≥ Common primary cap: Rare+0 beats Common+3 in slot primary stat | ADR-0003 ✅ |
| TR-part-015 | heat_generation range [0,40]; null active_skill_id ⇒ heat=0; THERMAL +5 bonus | ADR-0003 ✅ |
| TR-part-016 | Formula 3 drop rate: conditions multiply base; clamp [0,1]; base C .70 / R .25 / B .001 / P .05 | ADR-0003 ✅ |
| TR-part-017 | Prototype gradient: ≥3 conditions product ≥3.0 reach 15–20% optimal; partial fire partial rate | ADR-0003 ✅ |
| TR-part-018 | drop_enabled=false excludes from drop tables, preserves inventory validity | ADR-0003 ✅ |
| TR-part-019 | Part variants: same part_family, distinct id/rarity/stats/skills across Common/Rare/Boss | ADR-0003 ✅ |
| TR-part-020 | sprite_id non-null non-empty all parts; renderer sprite-swap identifier | ADR-0003 ✅ |
| TR-part-021 | upgrade_effects array tiers 1–5: {tier, effect_type, description, skill_id}; SKILL_UNLOCK/ENHANCE | ADR-0003 ✅ |
| TR-part-022 | Prototype concentration: ≥70% positive budget in 1–2 stats; at ×2.0 exceeds spread Boss focus | ADR-0003 ✅ |
| TR-part-023 | Formula 2 epsilon non-discriminating MVP ranges, Formula 2b load-bearing; retain both | ADR-0003 ✅ |
| TR-part-024 | Numeric precision: floor() not round/ceil; Formula 2b double-negation max(0,…) guard tier ≥4 | ADR-0003 ✅ |
| TR-part-025 | Reserved Full Vision fields null in MVP (motherboard_slot_type, ram_cost, weight_class, …) | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/part-database.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The typed-dict `.tres` round-trip is verified on Godot 4.6 (StringName keys survive
  serialization) — **the load-bearing Foundation engine spike; resolve here first and
  reuse the finding across the other content-DB epics**
- Formulas 1/2/2b/3 have GUT unit tests using discriminating fixtures (floor ≠ round ≠ ceil)
- The ContentValidator rejects every authoring-rule violation above (CI + dev-boot)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Engine spike — typed-dict `.tres` round-trip gate | Integration | Ready | ADR-0003 |
| 002 | PartDef schema + enums + PartCatalog | Logic | Ready | ADR-0003 |
| 003 | PartDB singleton — load / index / expose read-only | Integration | Ready | ADR-0003 |
| 004 | Formula 2 + 2b — per-part upgrade pipeline | Logic | Ready | ADR-0005 / ADR-0003 |
| 005 | Formula 1 — total Symbot stat composition | Logic | Ready | ADR-0005 / ADR-0003 |
| 006 | Formula 3 — effective drop rate | Logic | Ready | ADR-0003 |
| 007 | ContentValidator — schema & enum-integrity family | Logic | Ready | ADR-0003 |
| 008 | ContentValidator — content-rule, budget & synergy family | Logic | Ready | ADR-0003 |
| 009 | ContentValidator — cross-DB referential integrity + level fields | Integration | Ready | ADR-0003 |
| 010 | Author MVP part content + wire CI content suite | Config/Data | Ready | ADR-0003 |

**Build order:** 001 gates everything (engine spike — must PASS before content authoring).
Then 002 (schema) → 003 (loader) / 004 (F2/F2b) → 005 (F1) / 006 (F3) / 007 (validator scaffold)
→ 008 + 009 (extend validator) → 010 (author content + CI, closes the epic).
Each story's `Depends on:` field is authoritative.

## Next Step

Run `/story-readiness production/epics/part-database/story-001-tres-typed-dict-roundtrip-spike.md`
then `/dev-story` to begin implementation with the load-bearing engine gate.
