# Story 003: Move pool & action availability (Rule 5 gate, null slot)

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 5, Rule 8, Rule 9, EC-TBC-02/EC-TBC-11)
**Requirement**: `TR-tbc-010`, `TR-tbc-020`, `TR-tbc-024` (enemy-moves-always-available part)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary)
**ADR Decision Summary**: The active Symbot's 4-slot move pool (Basic Attack + WEAPON + HEAD + ARMS; slot 4 may be null) exposes an availability state: the Basic Attack costs 0 Energy and is always available; other moves are greyed when `current_energy < energy_cost`; a null slot is a distinct unavailable entry. No turn can soft-lock. Enemy moves are always available (no energy gate, Rule 8).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. This AC asserts the **exposed state object only** — rendering (greyed costs, the "—" glyph) is the Combat UI GDD's concern. Null move slots arrive pre-resolved from Assembly (EC-SA-04) as `null`; querying the panel state must not throw.

**Control Manifest Rules (Core layer)**:
- Required: read the frozen `CombatantSnapshot` (move pool is snapshotted at BATTLE_INIT); the Basic Attack is a TBC-owned built-in.
- Forbidden: `mid_battle_stat_recompute`.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-06**: *(Verifies EC-TBC-02 + EC-TBC-11)*
  - Fixture A: `current_energy = 5`, Moves 1–3 cost 15/22/30 → Basic Attack in the available set (cost 0); Moves 1–3 in the unavailable set with costs readable from the state; an action is always selectable (no soft-lock).
  - Fixture B: Move 4 = null → exposed as a distinct null entry (not an available move); querying the panel state does not throw; other moves unaffected. Both fixtures required.
- [ ] **AC-TBC-21**: enemy moves always available — no energy gating, no Overheat. Enemy with `energy_capacity = 80` and a 30-cost skill → all skills selectable by the AI hook; no energy check; never enters OVERHEATED; no heat tracking.

---

## Implementation Notes

*Derived from ADR-0007 Rule 5 / Rule 9:*

- The move-panel state is a pure query over the frozen snapshot + live `current_energy`: for each of the 4 slots return `{ available: bool, cost: int }` (or a null-slot marker). Availability = `slot != null AND current_energy >= energy_cost`; the Basic Attack (`energy_cost = 0`, TBC-owned built-in) is always available.
- The Basic Attack built-in: `behavior=DAMAGE`, `energy_cost=0`, `heat_generation=0`, `damage_type`/`element` from the equipped WEAPON, `break_bias = BALANCED` (Story 009 uses the bias; this story only needs it present).
- Enemy side: no energy gate — every authored skill is selectable by the AI hook; no heat field exists (Story 002 sets that up). This story asserts availability, not selection logic (Enemy AI is a separate epic).
- Do NOT throw on a null slot — return the null marker so the panel query is total.

---

## Out of Scope

- Combat UI rendering of greyed costs / the "—" glyph (Combat UI GDD).
- Actual move resolution/damage (Story 008) and heat/energy payment (Stories 005/006).
- Enemy AI move selection (Enemy AI epic).

---

## QA Test Cases

- **AC-TBC-06 Fixture A**: no-affordable-non-basic-move
  - Given: `current_energy = 5`; Moves 1–3 cost 15/22/30
  - When: the move-panel state is queried
  - Then: Basic Attack available (cost 0); Moves 1–3 unavailable with costs 15/22/30 readable; at least one action always selectable
  - Edge cases: `current_energy = 0` still leaves Basic Attack available
- **AC-TBC-06 Fixture B**: null slot 4
  - Given: Move 4 == null (Common ARMS, EC-SA-04)
  - When: the panel state is queried
  - Then: slot 4 is a distinct null entry (not available); no throw; slots 1–3 unaffected
- **AC-TBC-21**: enemy moves ungated
  - Given: enemy `energy_capacity = 80`, a skill costing 30
  - When: it is the enemy's turn
  - Then: all skills selectable; no energy check; enemy never OVERHEATED; no heat tracking exists

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/move_pool_availability_test.gd` — must exist and pass. Both AC-TBC-06 fixtures required together.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (snapshot provides the move pool; enemy setup provides ungated moves)
- Unlocks: Story 008 (resolving an available move)
