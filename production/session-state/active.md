# Active Session State

## Current Task
Symbot Assembly System GDD — In Design (2026-07-10). Skeleton created; working on Section A (Overview).

## Sections Complete
- None yet (skeleton created)

## Sections In Progress
- A: Overview

## Key Decisions Locked (from upstream GDDs)
- 8 slot types: CORE, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS, LEGS, WEAPON (Part DB Rule 2)
- 11 stats: Structure, Armor, Resistance, Physical Power, Energy Power, Mobility, Targeting, Processing, Cooling, Energy Capacity, Recharge (Part DB Rule 4)
- Formula pipeline: F2/2b → F1 (chassis modifier applied post-sum) — Assembly owns this computation
- Equip displaces current occupant to Inventory (Part DB EC-07)
- Every slot must have exactly 1 part; no empty slots (starter parts ship with each Symbot)
- 3 combat resources: max Structure/Energy derived from parts; Heat starts at 0; runtime values owned by Combat

## Files Being Worked On
- design/gdd/symbot-assembly.md (active)

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED
- Damage Formula GDD: APPROVED

## Next Steps (within this session)
1. Complete each GDD section through approval loop
2. Register cross-system entities in design/registry/entities.yaml
3. Update systems-index.md to "Designed" (then Approved after /design-review in fresh session)

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Design pipeline
Task: Symbot Assembly System — Section A (Overview)
<!-- /STATUS -->
