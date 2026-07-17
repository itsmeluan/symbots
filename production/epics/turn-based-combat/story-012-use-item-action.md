# Story 012: Use-item action (Rule 7a)

> **Epic**: Turn-Based Combat
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 7a — Consumable Database erratum)
**Requirement**: `TR-tbc-029`, `TR-tbc-030`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary)
**ADR Decision Summary**: Using a consumable is the 4th action. It targets a living team Symbot (active or benched — benched target is NOT switched in); a successful apply consumes the turn and decrements `qty`; a rejected use (no valid target / already-full / none in inventory) is a pre-action gate that consumes no turn and decrements nothing. Item use generates zero Heat and costs zero Energy. An Overheated turn skips the action phase entirely, so an item cannot clear an active Overheat (preventive-only).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. The Consumable DB (already implemented) owns the item schema/effects/constants — TBC only wires the action and mutates Structure/Heat/Energy per the clamped CD-1/2/3 formulas. Test with an injected stub Consumable DB + inventory.

**Control Manifest Rules (Core layer)**:
- Required: item effects mutate `BattleContext` runtime fields; the rejection gate runs before any state change.
- Forbidden: `coroutine_park_across_action` (the item/target choice arrives via `submit_action`, never `await`).

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-41**: use-item applies the effect, consumes the turn on success, resource-neutral.
  - Scenario A (apply): Weld Patch (+25) on a living target `current_structure=50`/`max=594` → target 75; `qty −1`; action consumed (enemy acts next); heat unchanged AND energy unchanged.
  - Scenario B (rejected — pre-gate): Weld Patch on a full-Structure target (zero-net) → rejected; turn NOT consumed (player may still act); `qty` unchanged; no Heat/Energy change.
  - Scenario C (preventive-only Overheat): active Symbot starts Overheated (Heat 100) → action phase skipped (Rule 4); item menu NOT reachable that turn — a Coolant Flush cannot clear the active Overheat.

---

## Implementation Notes

*Derived from ADR-0007 Rule 7a:*

- The action takes a target argument. RESTORE_STRUCTURE/REDUCE_HEAT/RESTORE_ENERGY items target a living team Symbot (Structure > 0), active or benched — **targeting a benched Symbot does NOT switch it in**. A DOWNED Symbot is not a valid target (no revive). Apply the CD-1/2/3 clamped effect to the target's runtime field.
- Turn cost on **successful apply only**: a use that applies consumes the turn and decrements `qty`. A rejected use (no valid target, zero-net/already-full, none in inventory, wrong context) is a pre-action validation gate — turn NOT consumed, `qty` unchanged, no Heat/Energy change; the player picks another action that same turn.
- Zero Heat, zero Energy — the item action never touches Formula-5 heat gain or the Energy-cost path.
- Overheat timing: the item action resolves within the action phase with NO carve-out ahead of the Rule 4 Overheat-skip check — an Overheated Symbot skips its action phase, so the item menu is unreachable (preventive-only; Coolant Flush is used on an earlier turn).

---

## Out of Scope

- Consumable DB schema/effects/constants (already implemented — injected here).
- Salvage Beacon drop-multiplier payout (Drop System — TBC only sets the `beacon_used_this_battle` flag; Story 014 discards it at teardown).
- WORLD-only consumables filtering (Consumable Rule 3 — the in-battle menu only offers BATTLE/BOTH items).

---

## QA Test Cases

- **AC-TBC-41 Scenario A**: successful apply
  - Given: active turn, Weld Patch (+25), living target structure 50 / max 594
  - When: use-item resolves
  - Then: target structure 75; `qty −1`; action consumed (enemy next); heat AND energy unchanged
- **AC-TBC-41 Scenario B**: rejected pre-gate
  - Given: Weld Patch, target already at full Structure
  - When: use-item attempted
  - Then: rejected; turn NOT consumed; `qty` unchanged; no Heat/Energy change
  - Edge cases: item generating Heat or costing Energy is a FAIL; a rejected use consuming the turn/decrementing is a FAIL
- **AC-TBC-41 Scenario C**: preventive-only Overheat
  - Given: active Symbot starts Overheated (Heat 100)
  - When: the turn resolves
  - Then: action phase skipped; item menu not reachable; Overheat not cleared by an item
  - Edge cases: a benched target being switched in on use is a FAIL

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/use_item_action_test.gd` — must exist and pass. Uses injected stub Consumable DB + inventory. Rejected-use-no-cost + resource-neutral required.

**Status**: [x] Complete — `tests/unit/tbc/battle_controller_switch_item_test.gd`

---

## Completion Notes

**Completed**: 2026-07-17 · **Criteria**: 1/1 (AC-TBC-41) verified against source + discriminating tests.

- AC-TBC-41: an item restores a LIVING team member (active or benched — no switch-in), consuming the turn ONLY on a net-positive apply; a full-pool use and a DOWNED target are both rejected without consuming the turn. Three dedicated test functions.

**Test Evidence**: `battle_controller_switch_item_test.gd` — full GUT suite **762/762 green, 4268 asserts** (Godot 4.7 · GUT 9.7.1).
**Code Review**: inline as godot-gdscript-specialist (lean per-story gate) — no blocking issues.

---

## Dependencies

- Depends on: Story 001 (`submit_action` seam), Story 006 (Overheat-skip interaction), Story 011 (action-set composition)
- Unlocks: None (leaf action)
