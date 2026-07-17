# Story 009: Pity-counter persistence across save/load

> **Epic**: Drop System
> **Status**: Done (2026-07-17)
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

> **UNBLOCKED & DONE (2026-07-17):** the Save/Load epic (SL-1..SL-6) shipped the
> provider-envelope system and the `&"drop"` provider (SL-6). AC-DS-28 now passes
> against the real path — `tests/integration/drop_system/pity_persistence_test.gd`
> drives DropSystem.snapshot() → SaveLoadService envelope → JSON → atomic write →
> parse → SL-PRED-1 RESTORE → restore(), then proves the post-reload boundary:
> both counters reload identical (72 / 7), advance from the restored value
> (`+= c` → 75, `+= 1` → 8), and the next qualifying attempt fires the pre-roll
> guarantee (drop + reset, RNG untouched). Release-blocker cleared.

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: The two pity-counter maps (`pity_credit` Prototype, `break_pity_counter` Boss-grade) are deterministic per-part-ID state owned by the Drop System (ADR-0006); they persist across sessions via the Save/Load serialization envelope (ADR-0001, provides the interface — Not Started).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Integration test in `tests/integration/drop_system/`. Round-trips **both** pity maps through serialize → teardown → reload and proves not just integer equality but **boundary semantics**: a restored counter advances with the correct increment (`+= c` for DS-2, `+= 1` for DS-3) and the next qualifying attempt fires the guarantee. Non-persistence silently resets bad-luck protection every session — hence release-blocking. The serialization key/shape is owned by Save/Load; bind fixtures to that interface once defined.

**Control Manifest Rules (this layer)**:
- Required: both counter maps included in the serialized payload; reload restores exact per-part-ID values; pure-core counters, save envelope injected.
- Forbidden: resetting counters to 0 on load; dropping a counter key from the payload; advancing from 0 instead of the restored value.
- Guardrail: post-reload the pity boundary must still fire (semantics preserved, not just integer values).

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [ ] **AC-DS-28** (GATED → BLOCKING once Save/Load exists; **release-blocker**): pity-counter persistence across save/load, including the post-reload guarantee boundary. Integration test. GIVEN `pity_credit['delta_core'] = 72` (Prototype, 3 conditions, threshold 75) and `break_pity_counter['forge_core'] = 7` (Boss-grade, threshold 8); WHEN the game serializes state, tears down the DropSystem, and reloads from the saved data. THEN:
  - (a) both maps reload **identical** — `pity_credit['delta_core'] == 72` AND `break_pity_counter['forge_core'] == 7`;
  - (b) a subsequent **failing** optimal attempt (`c = 3`) on `delta_core` advances to **75** (72 + 3, `+= c` from the *restored* value, not from 0), and a failing qualifying break on `forge_core` advances to **8**;
  - (c) the **next** qualifying attempt on each then fires the guarantee — `delta_core` at 75 → guaranteed drop → 0, `forge_core` at 8 → guaranteed drop → 0.
  - FAIL: either counter reloads as 0 or a wrong value; a counter absent from the payload; the advance uses `+= 1` instead of `+= c`; the guarantee fails to fire post-reload (boundary semantics lost across serialization).

---

## Implementation Notes

*Derived from ADR-0006 + ADR-0001 (Save/Load) Implementation Guidelines:*

- Include **both** pity maps in the Drop System's serialized state (per the Save/Load envelope, ADR-0001). On reload, restore each per-part-ID counter to its exact saved value — never reset to 0, never drop a key.
- The post-reload advance must proceed **from the restored value**: `delta_core` 72 → 75 via `+= c` (c = 3), `forge_core` 7 → 8 via `+= 1` (AC-DS-28 b). This is the discriminator against a load that restores a value but then advances from 0.
- The next qualifying attempt at threshold must fire the pre-roll guarantee (AC-DS-28 c) — proving the reloaded counters preserve pity-boundary semantics, not merely their integers.
- Bind the test fixtures to whatever serialization interface the Save/Load GDD defines for the two counter maps; do not invent a bespoke format that Save/Load will not honor.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 004/005: the in-memory pity counter mechanics (`+= c`, `+= 1`, thresholds, guarantee) — this story round-trips the state they own.
- The full Save/Load serialization envelope + atomic-write lifecycle (ADR-0001, owned by the Save/Load system) — this story is the Drop System's participation in it.

---

## QA Test Cases

*Automated integration spec — the developer implements against this once Save/Load exists.*

- **AC-DS-28**: persistence + post-reload boundary.
  - Given: `pity_credit['delta_core'] = 72`, `break_pity_counter['forge_core'] = 7`.
  - When: serialize → tear down DropSystem → reload.
  - Then (a): both maps reload identical (72 and 7).
  - Then (b): a failing optimal `delta_core` attempt → 75 (`+= c` from 72); a failing `forge_core` qualifying break → 8.
  - Then (c): next qualifying attempt each fires the guarantee → both reset to 0.
  - Edge cases: reload-as-0, absent key, `+= 1` instead of `+= c`, or guarantee failing post-reload all fail.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/drop_system/pity_persistence_test.gd` — must exist and pass. **Release-blocker**: this must pass before ship.

**Status**: [x] Created & passing — 3 integration tests covering AC-DS-28 (a)/(b)/(c), green in the 913-test suite (2026-07-17). Round-trips through the real SaveLoadService path (not a bespoke shortcut) and proves boundary semantics, not just integer equality.

---

## Dependencies

- Depends on: Story 004 (DS-2 counter) + Story 005 (DS-3 counter); **BLOCKED on** the Not-Started Save/Load system (ADR-0001 serialization interface).
- Unlocks: None (release gate).
