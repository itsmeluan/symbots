# Story 004: Use-transaction validation, targeting & resource-neutrality

> **Epic**: Consumable Database
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-002` (use-context gates pre-action validation; rejected use consumes no turn, no decrement), `TR-cdb-003` (RESTORE_* targets a living team Symbot; downed never valid), `TR-cdb-007` (REDUCE_HEAT preventive-only — cannot rescue an already-Overheated Symbot)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: The DB owns the pure use-transaction contract (validate → apply → decrement) as testable logic with injected stubs (no live scene); RNG-free; the resources it restores are owned by TBC (read via injected target state).

**Engine**: Godot 4.7 | **Risk**: MEDIUM (the reject-vs-apply gate is the load-bearing contract — a wrong gate silently wastes items or turns)
**Engine Notes**: The transaction is atomic: **validate → apply → decrement by 1**. A rejected use decrements **nothing** and (in battle) consumes **no turn** — rejection is a *pre-action* gate (Rule 3). A use that applies **no Heat and no Energy cost** (AC-CD-25). Target/context stubs are injected — no live TBC scene. Beacon (Story 005) and encounter modifiers (Story 006) have their own rejection paths; this story covers zero-net / downed / wrong-context / quantity-0 and the positive living-target path.

**Control Manifest Rules (this layer)**:
- Required: dependencies injected (stub target + battle context), DI-testable — source: coding-standards / ADR-0005
- Forbidden: routing item-use through the move damage/Heat/Energy pipeline (would leak Heat/Energy — fails AC-CD-25); consuming a turn or decrementing on a rejected use — source: GDD Rule 3
- Guardrail: pure/stubbed — no live scene, no global RNG

---

## Acceptance Criteria

*From GDD Rule 3 / Rule 4, EC-CD-01/02/03/04, verified by AC-CD-05/06/07/08/24/25:*

- [ ] **Zero-net-effect rejected, partial allowed** (EC-CD-01): full-Structure / Heat-0 / full-Energy target → `USE_REJECTED`, not consumed; a partial heal (e.g. current 580 / max 594) → `USE_OK`, consumed — AC-CD-05
- [ ] **Downed target rejected** (EC-CD-02): `RESTORE_*` on `structure == 0` → `USE_REJECTED`, not consumed — AC-CD-06
- [ ] **Wrong context rejected** (EC-CD-03): `BATTLE`-only in world / `WORLD`-only in battle → `USE_REJECTED`; `BOTH` valid in either — AC-CD-07
- [ ] **Quantity 0 rejected** (EC-CD-04): `qty=0` → `USE_REJECTED`, no underflow to −1; `qty=1` → `USE_OK`, `qty→0` — AC-CD-08
- [ ] **Living-target predicate** (positive path): `is_valid_target` true for `structure ∈ {1, 45, 594}`, false for `structure=0` — AC-CD-24
- [ ] **Resource-neutral use** (Rule 3): a successful BATTLE `RESTORE_*` use emits `heat_generated == 0` AND `energy_consumed == 0` — AC-CD-25

---

## Implementation Notes

*Derived from GDD Rule 3 / Rule 4 + EC-CD-01…04:*

Build a `ConsumableUse` transaction (pure, DI). Signature roughly: given a `ConsumableDef`, an injected target state (`structure`, `max_structure`, `heat`, `energy`, `max_energy`), a context enum (`BATTLE`/`WORLD`), and a quantity, return a result `{outcome: USE_OK | USE_REJECTED, reason, new_qty, applied_delta}`. Order: (1) quantity > 0; (2) context match against `use_context`; (3) valid target (`RESTORE_*` needs `structure > 0`); (4) net-effect > 0 (a use that would clamp to exactly the current value is rejected — a *partial* effect is allowed and consumed). Only after all gates pass does it apply (via the Story-003 pure formulas) and decrement. `is_valid_target(structure)` is a clean boolean predicate reused by the UI grey-out. AC-CD-25 is asserted with a stub battle context that records any Heat/Energy hooks the use touches — the item pathway must invoke none.

**Preventive-only Coolant Flush (TR-cdb-007):** this DB does *not* implement the Overheat-skip itself (that's TBC Rule 4). The contract to preserve: item-use is an in-action-phase action with **no carve-out** ahead of the Overheat skip. No special-casing here beyond CD-2's `max(0, …)` floor; document the boundary so the TBC erratum doesn't add a rescue path.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 003: the CD-1/2/3 pure formulas (this story calls them)
- Story 005: the second-Beacon rejection + Beacon flag (EC-CD-05, AC-CD-11/12)
- Story 006: the encounter-modifier replace path (EC-CD-06, AC-CD-13)
- **TBC erratum** (AC-CD-20, DEFERRED): actual turn-consumption on apply + the live 4th-action wiring — this story asserts resource-neutrality with a stub, not turn-consumption

---

## QA Test Cases

- **AC-1** (AC-CD-05): zero-net rejected, partial allowed
  - Given: Weld Patch, `current==max==594`, `qty=1`
  - When: use
  - Then: `USE_REJECTED`, structure 594, `qty==1`
  - Edge cases: Coolant Flush `heat=0` → rejected, `qty==1`; Weld Patch `max=594, current=580` (heals 14) → `USE_OK`, `current==594`, `qty==0` (a reject-any-clamped-heal impl wrongly rejects this)
- **AC-2** (AC-CD-06): downed target rejected
  - Given: Repair Kit, target `structure=0`, `qty=1`
  - When: use
  - Then: `USE_REJECTED`, structure 0, `qty==1`
- **AC-3** (AC-CD-07): wrong context rejected
  - Given: Beacon (`BATTLE`) used in world; Jammer (`WORLD`) used in battle; Weld Patch (`BOTH`) in battle with a valid target
  - When: use
  - Then: first two `USE_REJECTED` (`qty==1`), the `BOTH` item `USE_OK`; a context-ignoring impl wrongly returns `USE_OK` for the first two
- **AC-4** (AC-CD-08): quantity 0 rejected
  - Given: `qty=0`, valid target/context
  - When: use
  - Then: `USE_REJECTED`, `qty==0` (no underflow to −1); `qty=1` → `USE_OK`, `qty==0`
- **AC-5** (AC-CD-24): living-target predicate
  - Given: Repair Kit
  - When: `is_valid_target(structure)` for `{1, 45, 594}` and `0`
  - Then: `{1,45,594}` → `true`, `0` → `false`; a `structure>=5` threshold wrongly fails the boundary `structure=1`
- **AC-6** (AC-CD-25): resource-neutral use
  - Given: Weld Patch against a stub battle context with a living target, successful apply
  - When: resolve
  - Then: `heat_generated == 0` AND `energy_consumed == 0`; an impl routing item-use through the move pipeline reports a non-zero delta

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/consumable_database/consumable_use_transaction_test.gd` — must exist and pass

**Status**: [x] Passing — full GUT suite 452/452 green (2026-07-16)

---

## Dependencies

- Depends on: Story 001 (schema), Story 003 (CD-1/2/3 formulas)
- Unlocks: Story 005 (Beacon reuses the transaction gate), Story 006 (encounter items reuse context validation), TBC erratum (AC-CD-20)
