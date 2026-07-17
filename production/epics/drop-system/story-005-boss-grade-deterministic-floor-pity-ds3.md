# Story 005: Boss-grade deterministic floor pity (DS-3)

> **Epic**: Drop System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-008`, `TR-drop-010`, `TR-drop-005` (partial)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: The Boss-grade guarantee is checked **before** the RNG draw (skips it → no stream desync); the per-Boss-grade-ID break counter is deterministic integer state (ADR-0006). A dropped instance is emitted at `upgrade_tier = 0` to the Inventory sink and the counter reset (ADR-0002).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Integer counter of consecutive **qualifying breaks** that failed the drop roll. `M_BOSS_PITY = 8`; guarantee fires on the (M+1)th qualifying break worst case. Increment is `+= 1` (contrast DS-2's `+= c`). Only a **qualifying break** (required break fired, part eligible) touches the counter — a Boss-grade win without the break leaves it unchanged (breaks are deterministic; there is no break-failure tail). Any drop (guaranteed or natural-below-threshold) resets to 0. The guarantee must **not** call the RNG (call-count == 0).

**Control Manifest Rules (this layer)**:
- Required: pure core; injected seeded RNG; per-Boss-grade-ID counter map owned here; emit at `upgrade_tier = 0` to the injected Inventory sink; diagnostics via LogSink.
- Forbidden: global `randf()`; post-roll pity override; `push_warning`/`push_error` from `src/`.
- Guardrail: the guarantee is pre-roll — a guaranteed part never advances the RNG stream; per-ID counters resolve independently.

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [ ] **AC-DS-16** (BLOCKING, Unit): trigger at counter = 8, not 7 *(verifies EC-16/DS-3 boundary)*. A: counter 7, qualifying break `core_broken`, draw 0.60 (> 0.5) → `7 ≥ 8` false → fails → counter 8. B: counter 8, qualifying break → guaranteed, RNG not called, counter → 0, emitted. FAIL: fires at 7; B calls RNG or no reset.
- [ ] **AC-DS-17** (BLOCKING, Unit): nominal increment from a low counter. `forge_core` counter **0**, qualifying break (effective rate 0.001 × 500 = 0.5), draw 0.60 (> 0.5) → no drop → counter → **1**. Second: from 1, qualifying break, draw 0.60 → counter → **2**. FAIL: stays 0 (increment path never taken); jumps past 1; resets on failure.
- [ ] **AC-DS-09** (BLOCKING, Unit): Boss-grade won without qualifying break → counter NOT incremented *(verifies EC-DS-05)*. `forge_core` counter 3, empty fired set, draw 0.5 → rate 0.001, 0.5 ≥ 0.001 → no drop, counter stays **3**. FAIL: → 4; reset to 0; drop true.
- [ ] **AC-DS-30** (BLOCKING, Unit): counter resets to 0 on a NATURAL drop below threshold. `forge_core` counter **5**, qualifying break, draw 0.30 (< 0.5) → natural drop (threshold 8 not reached) → counter → **0**, one instance. FAIL: stays 5; → 6 (`+= 1` on a *drop* instead of reset).
- [ ] **AC-DS-24** (BLOCKING, Unit): pity counters are per-part-ID, not global. A (one at pity): `forge_core` counter 8 (qualifying break) + `volt_cannon` counter 2 (qualifying break), `volt_cannon` draw 0.60 → `forge_core` guaranteed (counter → 0, emitted, RNG not consumed); `volt_cannon` roll 0.60 ≥ 0.5 → no drop, counter → 3. B (**both at pity, joint guarantee**): both counter 8, both qualifying breaks, stub armed with **zero** draws → both guaranteed, both counters → 0, total RNG calls = **0**, **two** instances. FAIL: shared-counter reset; missing update; any RNG call; either instance missing.
- [ ] **AC-DS-01** (BLOCKING, Unit): emit contract *(verifies EC-DS-09)*. A pity-guaranteed `forge_core` on VICTORY → Inventory mock receives exactly one `receive_part_instance({part_id:'forge_core', upgrade_tier:0})` and `break_pity_counter['forge_core']` resets to 0. FAIL: 0 or 2+ calls; `upgrade_tier ≠ 0`; counter not reset.
- [ ] **AC-DS-26** (BLOCKING, Unit): `drop_enabled` gates the pity update — negative AND positive. A (negative): `forge_core` `drop_enabled = false`, counter 3, qualifying break → counter stays **3**, no emit, RNG not consumed. B (**positive companion**): same fixture `drop_enabled = true`, counter 3, qualifying break, draw 0.60 (roll fails) → counter → **4**, no emit. FAIL: A → 4 (pity update before the enabled check); **B stays 3** (increment omitted entirely — A alone passes trivially for that bug).

---

## Implementation Notes

*Derived from ADR-0006 + ADR-0002 Implementation Guidelines:*

- Own a per-Boss-grade-ID `break_pity_counter` int map. For each Boss-grade part in the roll loop, only when a **qualifying break** fired (the part's required break event is in the fired set and the part is eligible):
  - if `break_pity_counter[p] >= M_BOSS_PITY (8)` → guaranteed drop, **skip the RNG draw**, reset to 0 (AC-DS-16 B).
  - else roll DS-1; on drop reset to 0 (AC-DS-30); on fail `break_pity_counter[p] += 1` (AC-DS-16 A / AC-DS-17).
- A Boss-grade win **without** the qualifying break leaves the counter untouched (AC-DS-09) — no break-failure tail exists (Part-Break is deterministic).
- The `drop_enabled` check runs **before** any pity update: a disabled part is not rolled, not emitted, and its counter does not advance (AC-DS-26 A) — but an enabled part's counter *does* advance on a failed roll (AC-DS-26 B is the discriminator against omitting the increment entirely).
- Counters are strictly per-part-ID — two Boss-grade parts at threshold in one pass each guarantee independently with zero RNG draws (AC-DS-24 B).
- Emit each dropped instance at `upgrade_tier = 0` to the injected Inventory sink and reset that part's counter (AC-DS-01).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: Prototype pity (DS-2) — separate counter, `+= c`, threshold `N × C`.
- Story 006: cross-system reproducibility (AC-DS-18), the generic multi-guarantee stream-sync across Prototype+Boss-grade (AC-DS-10), and the defeat/flee no-change gate (AC-DS-02).
- Story 003: `drop_enabled` gating the *roll/emit* (AC-DS-06 C) — this story covers `drop_enabled` gating the *pity update* (AC-DS-26).
- Story 009: persisting `break_pity_counter` across save/load (AC-DS-28, gated).

---

## QA Test Cases

*Automated GUT specs — the developer implements against these. RNG stub records call-count; Inventory is a mock.*

- **AC-DS-16**: boundary 8 not 7.
  - Given A: counter 7, qualifying break, draw 0.60. Given B: counter 8, qualifying break.
  - Then A: counter 8. Then B: guaranteed, RNG uncalled, counter → 0, emitted.
- **AC-DS-17**: increment from 0.
  - Given: counter 0 then 1, qualifying break, draw 0.60 each.
  - Then: 0 → 1 → 2.
- **AC-DS-09**: no break → no increment.
  - Given: counter 3, empty fired set, draw 0.5.
  - Then: no drop, counter stays 3.
- **AC-DS-30**: reset on natural drop.
  - Given: counter 5, qualifying break, draw 0.30 (< 0.5).
  - Then: natural drop, counter → 0, one instance.
- **AC-DS-24**: per-part-ID.
  - Given A: `forge_core` 8 + `volt_cannon` 2, `volt_cannon` draw 0.60. Given B: both 8, stub with zero draws.
  - Then A: `forge_core` guaranteed → 0 (RNG uncalled), `volt_cannon` → 3. Then B: both guaranteed → 0, RNG calls 0, two instances.
- **AC-DS-01**: emit contract.
  - Given: pity-guaranteed `forge_core`, VICTORY.
  - Then: one `receive_part_instance({part_id:'forge_core',upgrade_tier:0})`, counter → 0.
- **AC-DS-26**: drop_enabled gates pity.
  - Given A: `drop_enabled=false`, counter 3, qualifying break. Given B: `drop_enabled=true`, counter 3, qualifying break, draw 0.60.
  - Then A: counter stays 3, no emit, RNG uncalled. Then B: counter → 4, no emit.
  - Edge cases: A→4 (update-before-check) and B-stays-3 (increment omitted) both fail.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/boss_grade_pity_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (roll loop + emit contract + pre-roll seam).
- Unlocks: Story 006 (determinism), Story 007 (Scenario D guaranteed part), Story 009 (persistence).
