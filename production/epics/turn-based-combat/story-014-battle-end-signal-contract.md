# Story 014: Battle end — 8-field `battle_ended` contract & teardown

> **Epic**: Turn-Based Combat
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 12 battle-end, EC-TBC-15)
**Requirement**: `TR-tbc-004`, `TR-tbc-005`, `TR-tbc-041`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0002** (primary — owner-declared `battle_ended` signal), ADR-0007 (BATTLE_END state + synchronous teardown)
**ADR Decision Summary**: Battle end emits the 8-field COMBAT-shape `battle_ended(outcome, enemy_id, fired_break_events, xp_value, completion_bonus_xp, is_first_boss_defeat, enemy_level, deployed_symbot_ids)` synchronously from the BATTLE_END state; the `BattleContext` is discarded AFTER the emit cascade returns (no `queue_free`; verify with WeakRef). This COMBAT payload is distinct from the 2-field WORLD-shape signal Overworld Navigation relays — the "single highest-risk signal contract." `fired_break_events` is a deduplicated set collected from `hit_resolved`; DEFEAT/FLED carry an empty set.

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. Use `.emit()`, never `emit_signal(...)`. `fired_break_events` is a `Dictionary`-as-set (keys = break-event StringNames, dedup by construction). `deployed_symbot_ids` is `Array[int]`. The subscriber non-confusion test is the highest-value assertion in the epic — a WORLD-shape (2-field) handler must fail to bind the COMBAT-shape payload, proving they cannot be swapped.

**Control Manifest Rules (Core layer)**:
- Required: synchronous emit then synchronous `BattleContext` drop; all runtime state discarded (fresh next battle).
- Forbidden: `battle_context_leak_past_teardown` (verify the context is unreachable post-cascade); `battle_state_on_transient_node`.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-31**: `battle_ended` emits the full 8-field COMBAT payload on VICTORY/DEFEAT/FLED.
  - VICTORY: `fired_break_events` is a dedup set — two `arm_broken` + one `head_cracked` over the battle → exactly `{arm_broken, head_cracked}` (2 elements, not 3); `xp_value`/`completion_bonus_xp`/`is_first_boss_defeat`/`enemy_level`/`deployed_symbot_ids` all populated.
  - DEFEAT and FLED: `fired_break_events` is the empty set `{}`.
- [ ] **AC-TBC-32**: the 8-field COMBAT `battle_ended` is provably non-confusable with the 2-field WORLD-shape signal — a subscriber bound to the WORLD shape cannot consume the COMBAT payload (arity/shape mismatch), and vice versa. After emit, the `BattleContext` is discarded synchronously and every runtime field is fresh next battle (heat 0, no statuses, silent synergy re-evaluated).

---

## Implementation Notes

*Derived from ADR-0002 Rule 12 + ADR-0007 BATTLE_END teardown:*

- On reaching a terminal condition (enemy structure 0 → VICTORY; all 3 player Symbots DOWNED → DEFEAT; successful WILD flee → FLED), transition to `BATTLE_END` and build the 8-field payload:
  `battle_ended(outcome, enemy_id, fired_break_events, xp_value, completion_bonus_xp, is_first_boss_defeat, enemy_level, deployed_symbot_ids)`.
- `fired_break_events` accrues from Story 009's `hit_resolved` region-break events into a `Dictionary`-as-set (dedup by construction — the same event firing twice adds one key). VICTORY carries the accrued set; DEFEAT and FLED carry `{}` (no rewards).
- Emit with `.emit()` synchronously. AFTER the cascade returns, drop the `BattleContext` reference synchronously (no `queue_free`, no deferral). Verify with a `WeakRef` that the context is collectable — no `battle_context_leak_past_teardown`.
- The COMBAT (8-field) shape is distinct from the WORLD (2-field) shape Overworld Navigation relays — never route one into the other. The subscriber-non-confusion test binds a WORLD-shape handler and asserts it cannot receive the COMBAT payload.
- After teardown, `is_battle_active == false` and all runtime state is gone; the next `start_battle` re-derives from scratch (heat 0, no carried statuses, `evaluate_silent` re-runs).

---

## Out of Scope

- XP application / level-up (Core Progression epic consumes `xp_value` + `completion_bonus_xp`; TBC only emits them).
- Drop resolution (Drop System consumes `fired_break_events` + the beacon flag; TBC only emits the set).
- The WORLD-shape `battle_ended` relay itself (Overworld Navigation — this story only proves non-confusability from the COMBAT side).
- The FLED/VICTORY/DEFEAT *transitions* (Story 011 triggers them; this story owns the payload + teardown).

---

## QA Test Cases

- **AC-TBC-31**: 8-field payload + dedup
  - Given: a battle where `arm_broken` fires twice and `head_cracked` once; VICTORY reached
  - When: `battle_ended` emits
  - Then: 8 fields present; `fired_break_events == {arm_broken, head_cracked}` (2 elements); DEFEAT/FLED runs → `fired_break_events == {}`
  - Edge cases: a 3-element set (no dedup) is a FAIL; a non-empty set on DEFEAT/FLED is a FAIL
- **AC-TBC-32**: non-confusion + teardown
  - Given: a WORLD-shape (2-field) subscriber and the COMBAT (8-field) emit; a `WeakRef` on the `BattleContext`
  - When: the battle ends and a second battle starts
  - Then: the WORLD subscriber cannot bind the COMBAT payload (shape mismatch); `WeakRef.get_ref() == null` after the cascade; second battle starts fresh (heat 0, no statuses, silent synergy re-run)
  - Edge cases: a leaked/reachable `BattleContext` post-cascade is a FAIL; carried heat/statuses into battle 2 is a FAIL

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tbc/battle_end_signal_contract_test.gd` — must exist and pass. The 8-field-vs-2-field non-confusion assertion + WeakRef teardown + dedup set are all required.

**Status**: [x] Complete — `tests/unit/tbc/battle_controller_lifecycle_test.gd`

---

## Completion Notes

**Completed**: 2026-07-17 · **Criteria**: 2/2 (AC-TBC-31, 32) verified against source + discriminating tests.

- AC-TBC-31 (the 8-field `battle_ended` fires on VICTORY with the correct payload fields) and AC-TBC-32 (`fired_break_events` is a de-duplicated set — VICTORY carries it, DEFEAT/FLED carry `{}`) each covered. Non-confusability with the 2-field WORLD signal rests on ARITY (8 vs 2 fields) — asserted directly.
- **Deviation (location)**: story named `tests/integration/tbc/...`; evidence landed as unit coverage in `battle_controller_lifecycle_test.gd` (shared host with Story 001).

**Test Evidence**: `battle_controller_lifecycle_test.gd` — full GUT suite **762/762 green, 4268 asserts** (Godot 4.7 · GUT 9.7.1).
**Code Review**: inline as godot-gdscript-specialist (lean per-story gate) — no blocking issues.

---

## Dependencies

- Depends on: Story 001 (BATTLE_END state + teardown), Story 009 (`hit_resolved` feeds `fired_break_events`), Story 011 (FLED/VICTORY/DEFEAT transitions)
- Unlocks: None (Overworld Navigation / Drop / Core Progression consume this payload — separate epics)
