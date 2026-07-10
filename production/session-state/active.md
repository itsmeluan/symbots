# Active Session State

## Current Task
Symbot Assembly System GDD — Designed (2026-07-10). All 8 required sections written. Awaiting /design-review in a fresh session.

## Sections Complete (symbot-assembly.md)
- A: Overview ✓
- B: Player Fantasy ✓
- C: Detailed Design ✓
- D: Formulas ✓
- E: Edge Cases ✓
- F: Dependencies ✓
- G: Tuning Knobs ✓
- H: Visual/Audio Requirements ✓ (added after qa-lead review — modular sprite composite, slot layers, rarity effects, audio events)
- I: Acceptance Criteria ✓ (14 ACs, all qa-lead findings resolved)

## Sections Deferred (optional, not required by GDD standard)
- UI Requirements — deferred to /ux-design (Workshop screen + Combat screen)
- Open Questions — no open questions identified; section left as placeholder

## Part Database Amendment (2026-07-10)
- `sprite_id` field added to Rule 1 schema table (visual reference per part, required non-null)
- AC-24 added: validator confirms zero null/empty sprite_id entries
- Status updated: Approved (Round 8 + visual amendment 2026-07-10)

## Entity Registry Updated (2026-07-10)
- SA-F1 formula (stat derivation pipeline, 11-stat output ranges)
- SA-F2 formula (stat delta, Workshop UI preview)
- TEAM_ROSTER_CAP = 3
- ACTIVE_MOVE_SLOTS = 4

## Key Decisions Locked
- 8 slot types: CORE, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS, LEGS, WEAPON
- 11 stats (Part DB Rule 4)
- Formula pipeline: F2/F2b (per-part) → sum → F1 (chassis + floor + clamp)
- Equip displaces current occupant to Inventory
- Every slot must have exactly 1 part; no empty slots
- 3 combat resources: max Structure/Energy derived from parts; Heat starts at 0
- 4 move slots: Basic Attack + WEAPON + HEAD + ARMS (null if Common)
- Synergy reads final_stat from Assembly; Assembly does not read Synergy (one-way)
- part_equipped signal drives visual sprite swap in Workshop UI and battle scene
- Eager recomputation on every equip event

## Files Being Worked On
- design/gdd/symbot-assembly.md (complete — ready for review)

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: DESIGNED 2026-07-10

## Next Steps
1. /clear — fresh session before review
2. /design-review design/gdd/symbot-assembly.md — review to Approved verdict
3. /design-system synergy-system — #5 in design order (depends on Part DB + Assembly)

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Design pipeline
Task: Symbot Assembly System — Designed, awaiting /design-review
<!-- /STATUS -->
