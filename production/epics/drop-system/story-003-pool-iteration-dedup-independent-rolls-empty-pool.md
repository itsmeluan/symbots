# Story 003: Pool iteration — unique-ID dedup, independent rolls, empty/disabled pool

> **Epic**: Drop System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: The loot pool is iterated over **unique** part IDs — one Bernoulli roll per unique ID — so a duplicate ID contributes no extra RNG draw (dedup keeps the seeded stream reproducible, ADR-0006). The candidate pool comes from the Enemy-DB loot pool read read-only (ADR-0002/0003 catalog).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure iteration over the enemy loot pool. **No `÷ pool_size` normalization** — each part rolls at its own effective rate regardless of pool size. Dedup to unique IDs *before* rolling (a duplicate ID = exactly one roll). `drop_enabled = false` parts are excluded before rolling and never consume a draw. GDScript `Dictionary` iterates in insertion order — dedup + the ID-ascending sort (Story 006) must be explicit, not relied upon.

**Control Manifest Rules (this layer)**:
- Required: pure core; injected seeded RNG; content defs (incl. `drop_enabled`) read-only via the catalog.
- Forbidden: `÷ pool_size` rate normalization; global `randf()`; content-def mutation.
- Guardrail: a disabled or deduped-away part must **not** advance the RNG stream (draw count is the discriminator).

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [ ] **AC-DS-12** (BLOCKING, Unit): independent per-part rolls, no pool dilution *(verifies R2)*. 5-part pool [Common `bolt_plate` 0.70, Common `wire_coil` 0.70, Common `grip_ring` 0.70, Rare `servo_arm` 0.25, Common `armor_seal` 0.70], no conditions, draws ID-asc [0.65, 0.65, 0.65, **0.10**, 0.65] → all 5 drop; `servo_arm` rate = 0.25; RNG called exactly 5×. Second: 10-part pool, `servo_arm` draw 0.10 → drops (rate still 0.25, not ÷10). FAIL: `servo_arm` fails to drop at 0.10 (pool-normalization bug: 0.25÷5 = 0.05, draw 0.10 ≥ 0.05 → no drop).
- [ ] **AC-DS-08** (BLOCKING, Unit): duplicate part ID → deduped to one roll *(verifies EC-DS-08)*. Pool lists `servo_arm` (Rare 0.25) twice, RNG stub one draw 0.20 (< 0.25) → RNG called **exactly once**, **exactly one** `servo_arm` instance. Second: draw 0.30 (≥ 0.25) → RNG called once, zero instances. FAIL: RNG called twice / two instances (independent-trials bug); zero rolls (over-dedup dropping the part entirely).
- [ ] **AC-DS-06** (BLOCKING, Unit): empty/disabled pool → zero drops, no crash *(verifies EC-DS-02)*. A: empty pool → `[]`. B: all `drop_enabled = false` → `[]`. C: mixed → only the enabled part rolled (disabled not rolled, stream not advanced for it). FAIL: exception; disabled emitted; disabled consumes a draw.

---

## Implementation Notes

*Derived from ADR-0006 + ADR-0002 Implementation Guidelines:*

- Before rolling, reduce the enemy loot pool to its **unique** part IDs (dedup). A duplicate ID contributes exactly one roll — at most one instance from that ID per fight (AC-DS-08). Align with Enemy DB EC-ED-08 (the content validator already warns on duplicate pool entries).
- Exclude `drop_enabled = false` parts **before** rolling — they are never iterated, never emitted, never consume a draw (AC-DS-06 C).
- Each retained unique part is an **independent Bernoulli trial** at its own `effective_drop_rate`. There is **no `÷ pool_size`** term — a 5-part and a 10-part pool roll `servo_arm` at the identical 0.25 (AC-DS-12).
- An empty pool (or a fully-disabled pool) yields an empty drop list and no crash (AC-DS-06 A/B).
- Draw-count is the load-bearing assertion: use an RNG stub that records call count and assert it equals the number of retained unique enabled parts.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the per-part DS-1 roll (this story governs *which* parts get a roll and *how many* rolls).
- Story 002: condition assembly (pool parts here roll at base or an already-assembled rate).
- Story 006: the explicit ID-ascending ordering + reproducibility proof (this story only needs correct roll *count*, not the ordering guarantee).
- Story 005: the `drop_enabled`-gates-**pity** path (AC-DS-26) — this story covers `drop_enabled` gating the *roll/emit*, the pity-update gate is Boss-grade Story 005.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these. Use a call-count-recording RNG stub.*

- **AC-DS-12**: no pool dilution.
  - Given: 5-part pool, draws [0.65,0.65,0.65,0.10,0.65]; then 10-part pool, `servo_arm` draw 0.10.
  - Then: all 5 drop, RNG called 5×, `servo_arm` rate 0.25; 10-pool `servo_arm` drops.
  - Edge cases: ÷pool_size impl (0.05) fails `servo_arm` at 0.10.
- **AC-DS-08**: duplicate ID dedup.
  - Given: `servo_arm` listed twice, one draw 0.20; then draw 0.30.
  - Then: RNG called once, one instance; then once, zero instances.
  - Edge cases: two calls/two instances = trials bug; zero rolls = over-dedup.
- **AC-DS-06**: empty/disabled pool.
  - Given: A empty; B all disabled; C one enabled + one disabled.
  - Then: A `[]`; B `[]`; C only enabled rolled, draw count = 1, disabled not emitted.
  - Edge cases: no exception; disabled must not consume a draw.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/pool_iteration_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (host + per-part DS-1 roll).
- Unlocks: None (Story 006 reuses the unique-ID iteration for its ordering proof).
