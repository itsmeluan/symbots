# Epic: Passive Database

> **Layer**: Foundation
> **GDD**: design/gdd/passive-database.md
> **Architecture Module**: Content DBs (Part/Move/Passive/Consumable/Enemy)
> **Status**: Ready
> **Stories**: 7 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | PassiveDef schema, enums & PassiveCatalog | Logic | Ready | ADR-0003 |
| 002 | PassiveDB loader & null-safe lookup | Logic | Ready | ADR-0003 |
| 003 | Stacking-policy defaults by behavior_class | Logic | Ready | ADR-0003 |
| 004 | Passive validator — schema-family + legality matrix | Logic | Ready | ADR-0003 |
| 005 | Passive validator — behavior_params, STRUCTURAL non-negative & Core restriction | Logic | Ready | ADR-0003 |
| 006 | Passive referential integrity & catalog wiring | Logic | Ready | ADR-0003 |
| 007 | Three MVP status riders — content authoring | Config/Data | Ready | ADR-0003 |

**Scope boundary**: this epic delivers the schema, catalog, loader, validators, and
the 3 MVP status-rider content. **Runtime firing** (AC-PDB-02, 04–11, 17 — status
application, stacking dedup, aura/structure clamps) is owned by the **TBC Rule 13
executor epic**. The **MVP Core passive roster** (OQ-PDB-1, deferred AC-PDB-D1–D4,
capped at 5 mechanically-distinct Cores) is a separate critical-path content pass
with game-designer, not a story here.

## Overview

The Passive Database is the read-only schema and catalog for part passives — the
always-on or triggered effects a part contributes to a build. Each passive
declares a `behavior_class` (STATUS_RIDER / STAT_AURA / RESOURCE_EFFECT /
STRUCTURAL_EFFECT) and a `trigger_category`, and the two axes are governed by a
legality matrix that TBC's Rule 13 registry consumes at runtime. This epic
delivers the typed `Passive` resource, the catalog loader, the trigger×behavior
legality validation, the stacking-policy assignments per behavior class, and the
three MVP status riders.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Content Resource Loading & Schema Mapping | Typed `.tres` defs, one catalog per DB, CI + dev-boot ContentValidator; read-only-at-runtime | MEDIUM (HIGH for typed-dict `@export` / `.tres` round-trip) |

## GDD Requirements

All 8 requirements are traced to ADR-0003 (architecture review: 0 Foundation gaps).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-pdb-001 | Every passive declares behavior_class + trigger_category; behavior_class is the runtime resolution axis | ADR-0003 ✅ |
| TR-pdb-002 | Trigger×behavior legality matrix enforced (STATUS_RIDER+ON_HIT only; STAT_AURA+PERSISTENT only; …) | ADR-0003 ✅ |
| TR-pdb-003 | ON_HIT scope=WEAPON_ONLY fires only on WEAPON-slot DAMAGE moves; ANY_DAMAGE fires on all | ADR-0003 ✅ |
| TR-pdb-004 | Stacking by behavior_class: STATUS_RIDER→UNIQUE_PER_TRIGGER, STAT_AURA→UNIQUE, STRUCTURAL→UNIQUE, RESOURCE→STACKABLE | ADR-0003 ✅ |
| TR-pdb-005 | Three MVP status riders: volt_shock_on_hit, thermal_burn_on_weapon, kinetic_stagger_on_hit | ADR-0003 ✅ |
| TR-pdb-006 | STAT_AURA params {stat, delta} via SYN-F4 clamp; RESOURCE_EFFECT {resource, amount} clamped by cap | ADR-0003 ✅ |
| TR-pdb-007 | STRUCTURAL_EFFECT amount non-negative for both targets; negatives rejected at authoring | ADR-0003 ✅ |
| TR-pdb-008 | Core passives restricted to ON_BATTLE_START/ON_OVERHEAT/PERSISTENT; no ON_HIT | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/passive-database.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The trigger×behavior legality matrix is enforced by the ContentValidator with a
  GUT test asserting each illegal pairing is rejected
- The three MVP status riders resolve correctly against the TBC Rule 13 registry contract

## Next Step

Run `/create-stories passive-database` to break this epic into implementable stories.
