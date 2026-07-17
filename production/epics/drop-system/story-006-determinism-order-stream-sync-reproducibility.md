# Story 006: Determinism — ID-ascending order, stream-sync on guarantees, reproducibility

> **Epic**: Drop System
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-001`, `TR-drop-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism
**ADR Decision Summary**: A given `(seed, pool, fired conditions, pity state)` reproduces the exact drop set — parts roll in a defined **ID-ascending** order and a pity-guaranteed part **skips** the RNG draw so the seeded stream stays synchronized. Each DropSystem instance owns its own RNG and pity maps (no static/global sharing).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: This is the capstone determinism story — it composes the roll loop (001), both pity systems (004/005), and the pool iteration (003). GDScript `Dictionary` iterates in **insertion** order, so the ID-ascending sort must be **explicit** before both the roll pass and the Phase-6 report assembly (the two must not diverge). A guaranteed part consumes zero draws — the multi-guarantee case is the stream-position discriminator. Reproducibility requires per-instance RNG + per-instance pity maps (a static map would leak state across instances).

**Control Manifest Rules (this layer)**:
- Required: pure core; injected seeded RNG per instance; explicit ID-ascending sort; per-instance pity maps.
- Forbidden: global `randf()`; a module-level/static RNG or pity map shared across instances; insertion-order iteration on the roll or report pass.
- Guardrail: a guaranteed part never advances the RNG stream; roll order == report order.

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [x] **AC-DS-21** (BLOCKING, Unit): parts rolled AND reported in ID-ascending order *(verifies R10 ordering)*. Pool with IDs sorting alpha < beta < gamma (inserted non-alphabetically), a call-recording stub returning draws that make all three drop → (a) RNG calls issued alpha→beta→gamma, AND (b) the Phase-6 drop list (filtered to dropped) is ordered alpha→beta→gamma (matching roll order, not insertion order). FAIL: insertion-order iteration on the roll pass; or the report list diverges from roll order.
- [x] **AC-DS-10** (BLOCKING, Unit): pity guarantee skips the RNG draw *(verifies EC-DS-06)*. A (single guarantee): pool [`forge_core` guaranteed, `servo_arm` 0.25], stub one draw 0.20 → `forge_core` drops via guarantee (no draw), `servo_arm` consumes 0.20 and drops, total RNG calls = **1**. B (**two simultaneous guarantees — stream-position discriminator**): pool ID-asc [`alpha_core` guaranteed, `beta_core` guaranteed, `gamma_arm` Rare 0.25], stub armed with a **single** draw 0.20 → both cores drop via guarantee (neither consumes a draw), `gamma_arm` consumes the one 0.20 (< 0.25) and drops, total RNG calls = **1**, three instances. FAIL: 2+ draws consumed (a guaranteed part advanced the stream); `gamma_arm` reads a stale/absent draw (stub exhausted → error).
- [x] **AC-DS-18** (BLOCKING, Unit): deterministic reproducibility *(verifies R10)*. Two DropSystem instances, same injected seed, same two populated pity maps (`pity_credit['delta_core'] = 42` AND `break_pity_counter['forge_core'] = 5`); pool [`delta_core` Prototype all 3 fired, `forge_core` Boss-grade qualifying break, `servo_arm` Rare no conditions]; both resolve the same VICTORY payload → (a) identical drop lists (same part_ids, same order), AND (b) identical post-resolution state on **both** maps (`pity_credit['delta_core']` = 0 if dropped else 45; `break_pity_counter['forge_core']` = 0 if dropped else 6). FAIL: divergence in the drop list or *either* map (a shared global RNG singleton, or a shared static pity map).
- [x] **AC-DS-02** (BLOCKING, Unit): defeat/flee → no drops, no pity change *(verifies EC-DS-07)*. `pity_credit['proto_arms'] = 12` and `break_pity_counter['forge_core'] = 5`, non-empty fired set; DEFEAT (then FLED) → zero emits, **both** maps unchanged, RNG not called. FAIL: any emit; either counter changes.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- Sort the deduped, enabled pool by part ID ascending **once**, and drive both the roll pass and the Phase-6 report from that same ordered sequence so their orders cannot diverge (AC-DS-21). Do not assemble the report from a separate insertion-ordered structure.
- Confirm the pre-roll guarantee (Stories 004/005) skips the draw even when **multiple** parts guarantee in one pass — the stream position after the pass equals `#non-guaranteed-drops-attempted` draws, regardless of how many guarantees preceded (AC-DS-10 B).
- Reproducibility (AC-DS-18): construct two instances with the same seed and identically-populated pity maps; assert identical drop lists and identical post-state on **both** maps. Populating both maps is deliberate — a one-map fixture would miss a shared-static-state bug in the other. Ensure the RNG and both pity maps are **per-instance**, never static/module-level.
- Defeat/flee (AC-DS-02) is the pity-aware half of the victory gate (the pity-free half is AC-DS-11 in Story 001): on non-VICTORY, return immediately — zero emits, RNG untouched, both pity maps unchanged.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the victory-only gate without pity (AC-DS-11) and the basic ID-asc iteration seam.
- Stories 004/005: the single-system pity mechanics (this story composes them for cross-cutting determinism).
- Story 009: persistence of the pity maps across save/load (AC-DS-28, gated) — this story proves *in-memory* reproducibility only.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these. Use a call-recording RNG stub; construct two instances for AC-DS-18.*

- **AC-DS-21**: roll + report order.
  - Given: IDs alpha<beta<gamma inserted non-alphabetically, all drop.
  - Then: RNG calls alpha→beta→gamma; report list alpha→beta→gamma.
  - Edge cases: insertion-order roll or a divergent report list both fail.
- **AC-DS-10**: guarantee skips draw.
  - Given A: [`forge_core` guaranteed, `servo_arm` 0.25], one draw 0.20. Given B: [`alpha_core` g, `beta_core` g, `gamma_arm` 0.25], single draw 0.20.
  - Then A: RNG calls = 1, both drop. Then B: RNG calls = 1, three instances.
  - Edge cases: 2+ draws or stub-exhaustion error both fail.
- **AC-DS-18**: reproducibility.
  - Given: two instances, same seed, `pity_credit['delta_core']=42` + `break_pity_counter['forge_core']=5`, same pool + VICTORY.
  - Then: identical drop lists; identical post-state on both maps (0/45 and 0/6).
  - Edge cases: divergence in list or either map = shared global/static bug.
- **AC-DS-02**: defeat/flee no change.
  - Given: `pity_credit['proto_arms']=12` + `break_pity_counter['forge_core']=5`, non-empty fired set, DEFEAT then FLED.
  - Then: zero emits, both maps unchanged, RNG uncalled.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/determinism_test.gd` — must exist and pass.

**Status**: [x] Complete — `tests/unit/drop_system/determinism_test.gd`, 5 tests, all green (GUT 9.7.1, Godot 4.7.stable). Covers AC-DS-21/10/18/02.

---

## Completion Notes (2026-07-17)

- **No new production code.** DS-6 is a capstone that proves emergent determinism properties already composed by Stories 001/003/004/005: the ID-ascending sort in `_resolved_pool` drives both the roll pass and the report list (they iterate the same ordered sequence, so they cannot diverge — AC-DS-21); the pre-roll guarantee in both `_roll_prototype`/`_roll_boss_grade` skips the draw (AC-DS-10); `_rng` + `_proto_pity_credit` + `_boss_pity_counter` are all instance fields, never static (AC-DS-18); the victory-only early return precedes every draw (AC-DS-02).
- **AC-DS-21 order discriminator**: three Rare parts are sculpted to distinct rates (0.10/0.20/0.30) via a single fired ×0.4/×0.8/×1.2 condition, inserted non-alphabetically. Queued draws [0.05, 0.15, 0.25] make **all three** drop *only* when consumed in ID-ascending order — any other iteration order shrinks the drop set. The test therefore witnesses draw order, not merely report order.
- **AC-DS-18 reproducibility** uses two independent instances built from two `RandomNumberGenerator`s seeded identically (production draws via `call(&"randf")`, which dispatches to the native method on a real generator). Both pity maps are populated so a shared-static-state bug in *either* map would surface; post-state is also asserted consistent with each part's drop outcome (credit 0-or-45, counter 0-or-6).
- **AC-DS-02** loops DEFEAT (2) and FLED (3) through the same assertions — every non-VICTORY int is gated identically, with a `Const(0.01)` stub that would drop everything if a draw ever leaked past the gate (call_count 0 proves it did not).

---

## Dependencies

- Depends on: Story 004 (Prototype pity) + Story 005 (Boss-grade pity) — both pity maps must exist for AC-DS-10/18/02.
- Unlocks: None.
