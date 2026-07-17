# Story 004: Prototype gradient pity (DS-2)

> **Epic**: Drop System
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-007`, `TR-drop-005` (partial)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism
**ADR Decision Summary**: The Prototype pity guarantee is checked **before** the RNG draw — a guaranteed drop skips the draw so the seeded stream never desyncs. The per-Prototype-ID credit counter is deterministic integer state read/updated within the same pass; `src/core` stays pure with the RNG injected.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Integer-only credit counter — no rounding, no epsilon. `PITY_THRESHOLD(p) = N_PROTO_PITY × C(p)` where `N_PROTO_PITY = 25` and `C(p)` = the part's total `drop_conditions` count (≥3). The check is `pity_credit >= PITY_THRESHOLD` evaluated **pre-roll**; a guaranteed drop must **not** call the RNG (assert stub call-count == 0). On a qualifying failed attempt, credit advances by `c` (conditions fired this attempt), **not** `+= 1` and **not** `+= C`. Any drop (guaranteed, natural, or base-rate) resets credit to 0.

**Control Manifest Rules (this layer)**:
- Required: pure core; injected seeded RNG; per-Prototype-ID credit map owned here (persisted later by Story 009).
- Forbidden: global `randf()`; post-roll pity override (roll-then-guarantee); reading global singletons from core.
- Guardrail: the pity guarantee is pre-roll — a guaranteed part never advances the RNG stream.

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [x] **AC-DS-13** (BLOCKING, Unit): credit-threshold boundary — guarantee at credit 75, not 72. `delta_core` Prototype (0.05), 3 conditions each ×1.5 → `C = 3`, `PITY_THRESHOLD = 25 × 3 = 75`, optimal rate = clamp(0.05 × 1.5³) = 0.16875. Scenario A: credit 72, all three fired (`c = 3`), draw 0.50 → `72 ≥ 75` false → roll fails → credit `+= 3` → **75**; no emit; one draw consumed. Scenario B: credit 75, all three fired → `75 ≥ 75` true → guaranteed drop, **RNG not called** (assert call-count == 0, stub armed with a 0.50 that a post-roll bug would consume), credit → 0, exactly one instance. FAIL: guarantee at 72 (unscaled raw 25); A increments by 1 (flat-counter); B calls RNG (post-roll check); B doesn't reset; B emits 0 or 2+.
- [x] **AC-DS-14** (BLOCKING, Unit): non-qualifying attempt (zero conditions fired) gets no credit. `delta_core` (3 conditions) credit 10, **zero** of its conditions fired (`c = 0`), draw 0.50 fails → credit stays **10**. FAIL: credit → 11+ (crediting a fight where none of the part's own conditions fired — anti-exploit).
- [x] **AC-DS-29** (BLOCKING, Unit): partial-credit increment — `+= c`, not `+= 1`, not `+= C`. `delta_core` credit 40, exactly **2 of 3** fired (`c = 2`), rate = clamp(0.05 × 1.5²) = 0.1125, draw 0.50 fails → credit `+= 2` → **42**. Second: from 42, a **1-of-3** attempt (`c = 1`, rate 0.075), draw 0.50 fails → credit → **43**. FAIL: 41 (flat `+= 1`); 43 on the first step (`+= C`); unchanged (treating 2-of-3 as non-qualifying).
- [x] **AC-DS-15** (BLOCKING, Unit): credit resets to 0 on any drop, even below threshold. `delta_core` credit 66, optimal attempt (`c = 3`), draw 0.10 (< 0.16875) → drops via the normal roll (threshold 75 not reached) → credit → **0**. FAIL: stays 66; becomes 69 (`+= c` applied on a *drop* instead of reset).

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- Own a per-Prototype-ID `pity_credit` int map. For each Prototype part in the roll loop, resolve the attempt type by `c` = number of the part's `drop_conditions` fired this fight:
  - **Qualifying (`c ≥ 1`):** if `pity_credit[p] >= N_PROTO_PITY × C(p)` → guaranteed drop, **skip the RNG draw**, reset credit to 0 (AC-DS-13 B). Else roll DS-1; on drop reset to 0 (AC-DS-15); on fail `pity_credit[p] += c` (AC-DS-29).
  - **Non-qualifying (`c == 0`):** roll DS-1 at base rate; on drop reset to 0 (natural base-rate drop still resets, per AC-DS-15 semantics); on fail credit **unchanged** (AC-DS-14, anti-exploit).
- The pity check is **inside** the per-part decision, pre-roll — never "roll everything then override." A guaranteed part must not touch the RNG (the call-count == 0 assertion in AC-DS-13 B catches a post-roll bug).
- `+= c` is the discriminator between the new gradient-credit model and both the old all-or-nothing model and a naive flat `+= 1` (AC-DS-29).
- "Non-qualifying" = none of **this part's** conditions fired this fight; the enemy need not be the part's host.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the DS-1 roll the pity check gates.
- Story 005: Boss-grade pity (DS-3) — a separate counter with different semantics (`+= 1`, `M = 8`).
- Story 006: multi-guarantee stream-sync (AC-DS-10), per-ID independence across systems (AC-DS-24 is Boss-grade), same-seed reproducibility (AC-DS-18) — this story proves the single-part Prototype credit path only.
- Story 009: persisting `pity_credit` across save/load (AC-DS-28, gated).

---

## QA Test Cases

*Automated GUT specs — the developer implements against these. RNG stub records call-count.*

- **AC-DS-13**: credit-threshold boundary.
  - Given A: credit 72, `c = 3`, draw 0.50.
  - Then A: `72 ≥ 75` false → roll fails → credit 75; one draw consumed.
  - Given B: credit 75, `c = 3`, stub armed with 0.50.
  - Then B: guaranteed drop, RNG call-count == 0, credit → 0, one instance.
  - Edge cases: 72-trigger / `+= 1` / RNG-called-in-B / no-reset / wrong-emit-count all fail.
- **AC-DS-14**: non-qualifying no credit.
  - Given: credit 10, `c = 0`, draw 0.50 fails.
  - Then: credit stays 10.
- **AC-DS-29**: `+= c`.
  - Given: credit 40, `c = 2`, draw 0.50 fails; then credit 42, `c = 1`, draw 0.50 fails.
  - Then: 40 → 42 → 43.
  - Edge cases: 41 (`+= 1`), 43-on-first (`+= C`), unchanged all fail.
- **AC-DS-15**: reset on drop below threshold.
  - Given: credit 66, `c = 3`, draw 0.10 (< 0.16875) drops.
  - Then: credit → 0.
  - Edge cases: stays 66 or becomes 69 both fail.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/prototype_pity_test.gd` — must exist and pass.

**Status**: [x] Complete — `tests/unit/drop_system/prototype_pity_test.gd`, 4 tests, all green (GUT 9.7.1, Godot 4.7.stable). Covers AC-DS-13/14/29/15.

---

## Completion Notes (2026-07-17)

- Roll loop now routes each part through `DropSystem._roll_part()`; Prototype rarity takes the `_roll_prototype()` gradient-pity path, everything else the bare `_bernoulli()` DS-1 roll.
- Per-Prototype-ID `_proto_pity_credit` int map with `N_PROTO_PITY = 25` (threshold `25 × C`). Pre-roll guarantee (skips the draw — verified via stub call-count == 0), `+= c` on a qualifying miss, reset-to-0 on any drop, credit unchanged on a `c == 0` non-qualifying miss.
- Added `get_prototype_pity_credit` / `set_prototype_pity_credit` accessors — the read/write seam Story 009 will use for save/load persistence, and the arrange seam these tests use.

---

## Dependencies

- Depends on: Story 001 (roll loop + pre-roll seam).
- Unlocks: Story 006 (determinism needs both pity systems), Story 007 (Scenario D guaranteed part), Story 009 (persistence).
