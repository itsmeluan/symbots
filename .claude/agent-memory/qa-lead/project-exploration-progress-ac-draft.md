---
name: project-exploration-progress-ac-draft
description: Exploration Progress System (#14) AC authoring session — 15 BLOCKING unit ACs drafted, 2 DEFERRED integration, 3 delegated; all 17 ECs mapped
metadata:
  type: project
---

AC section drafted for exploration-progress.md on 2026-07-13 (GDD #14, persistence contract layer).

**Why:** Sections C/D/E approved; AC section was the sole remaining gap. All 17 ECs forward-reference specific AC numbers which were fixed by the prompt — the AC numbers could not shift.

**Status:** Draft delivered to user for approval before Write to file.

## Key design decisions in the ACs

- All 15 BLOCKING ACs are Unit tests in `tests/unit/exploration_progress/`. No integration ACs are BLOCKING — both integration ACs (disk round-trip, error-path handshake) are DEFERRED pending Save/Load #17.
- AC-EP-14 assigned to: Phase 1 no-cross-domain-reads architectural contract assertion. This was the unassigned slot from the prompt; the Phase 1 isolation guarantee is the highest-value structural test left uncovered by AC-EP-10.
- EC-EP-09 (serialize mid-restore): Advisory, no AC. Sequencing is Save/Load's responsibility; all EP source facts are always serializable (Rule 4) so no EP state corruption is possible. Noted for Save/Load GDD.

## GDScript traps explicitly called out in ACs

1. `Dictionary.get()` vs bracket access on missing version key (AC-EP-02 sub-case d — crashes vs REFUSEs)
2. Dictionary insertion order ≠ sorted order for world_loot snapshot (AC-EP-01, AC-EP-08 Part A)
3. Duplicate-key Dictionary construction collapses last-value-wins in GDScript (AC-EP-08 Part B — fixture must use JSON parse)
4. Deep-copy vs reference for opaque unknown-key store (AC-EP-09 — noted as implementation trap, complex to automate in GUT)

## Anti-hardcoding fixtures

- AC-EP-06: zone "z_synth", core "cx-synth-99"
- AC-EP-08 Part A: "chest_synth_1/2/3"
- AC-EP-08 Part B: "cx-dupe-A"
- AC-EP-09: "key_items" with "golden_badge" and "founder_token"

## Boundary discriminators included

- AC-EP-01: cumulative_xp=364 = threshold[4] exactly (discriminates `<` vs `<=` in CP-F1)
- AC-EP-03: cumulative_xp=220 = threshold[3] exactly
- AC-EP-05: wins_at_last_defeat == win_count exactly MUST pass EP-INV-1 (discriminates strict `<` implementations)
- AC-EP-05: wins_at_last_defeat == win_count − 1 passes with no warning
- AC-EP-10: cumulative_xp=993 = threshold[7] exactly

## EC coverage

All 17 ECs covered: 13 by BLOCKING ACs, 1 (EC-EP-06) delegated to Core Progression, 1 (EC-EP-09) advisory-only, 1 (EC-EP-14) delegated to ZWM AC-ZWM-15.

**How to apply:** If a future AC review session finds gaps, check (1) the GDScript traps list above — these are the highest-yield re-check targets, (2) boundary fixtures on all `>=` / `<=` conditions, (3) AC-EP-14 is structural/white-box — confirm the domain interface supports injectable cross-domain accessor before implementation begins.
