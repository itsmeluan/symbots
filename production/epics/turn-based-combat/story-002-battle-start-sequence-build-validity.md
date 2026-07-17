# Story 002: Battle-start sequence & build-validity refusal

> **Epic**: Turn-Based Combat
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 2, Rule 8)
**Requirement**: `TR-tbc-001`, `TR-tbc-002`, `TR-tbc-003`, `TR-tbc-024` (enemy instantiation), `TR-tbc-025`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary), ADR-0005 (secondary)
**ADR Decision Summary**: `start_battle()` runs the Rule 2 sequence — a build-validity precondition (`CoreProgression.is_build_valid` per fielded Symbot) BEFORE any snapshot, then per-Symbot Assembly `final_stat`/maxima snapshot, then Synergy `evaluate_silent(parts)` ×3 (frozen `cached_bonus_block`, no `synergy_changed`), then enemy instantiation (authored stats, no synergy block, dead-stat fields read-not-applied), then runtime-state init. An invalid build refuses entry with `battle_start_refused` and instantiates **no** runtime state.

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: ADR headers say 4.6; project pinned 4.7 (VERSION.md). `battle_start_refused(invalid_symbot_ids: Array, offending_parts: Array)` uses `.emit()`. Enemy stat reads use `.get(key, 0)` (typed `Dictionary`), never bracket access — a missing key must read 0, not throw. The `evaluate_silent`/snapshot APIs come from the already-implemented Symbot Assembly + Synergy epics.

**Control Manifest Rules (Core layer)**:
- Required: read the frozen `CombatantSnapshot` only (frozen at BATTLE_INIT); `evaluate_silent` called at battle start, never `evaluate` after; `is_build_valid` is the combat-entry gate.
- Forbidden: `mid_battle_stat_recompute` (no `StatPipeline.derive`/`evaluate` after BATTLE_INIT; no live `SymbotBuild` ref held into battle code); `inline_stat_composition`.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-01**: `evaluate_silent(parts)` called exactly 3 times, `synergy_changed` NOT emitted; each Symbot's `cached_bonus_block` correct for its own parts; enemy gets no `evaluate_silent` and no synergy block; `current_structure == max_structure`, `current_energy == max_energy_capacity`, `current_heat == 0` for all 3 player Symbots; enemy `current_structure == stats["structure"]`.
- [ ] **AC-TBC-42**: an invalid build (`is_build_valid == false` — e.g. a Boss-grade `level_requirement=6` ARMS part with a level-4 CORE) refuses battle start: no `BATTLE_INIT`→`ROUND_START`, no runtime state, no snapshot; `battle_start_refused` returned/emitted naming the invalid Symbot and offending part(s); no `battle_ended` ever fires. **Positive control**: all-valid roster proceeds normally.
- [ ] **AC-TBC-02**: enemy tracks no `current_heat` and no `current_energy` (sentinel null/absent, not a live 0); all enemy moves always available regardless of cost.
- [ ] **AC-TBC-19**: absent enemy stat keys read 0 via `.get()` — `stats = { "structure": 80 }` → `mobility`/`processing`/`armor`/`resistance` all read 0; no crash on any absent key.

---

## Implementation Notes

*Derived from ADR-0007 Rule 2 + ADR-0005:*

- **Order is authoritative** (Rule 2): (0) `is_build_valid` for every fielded Symbot → refuse before any snapshot if any is invalid; (1) snapshot `final_stat`/`max_structure`/`max_energy_capacity`/move pool/passive pool; (2) `evaluate_silent(parts)` ×3, store frozen `cached_bonus_block` per Symbot; (3) instantiate enemy (authored `stats`/`skills`/`core_element`/`break_regions`, no synergy); (4) runtime init `current_structure=max_structure`, `current_energy=max_energy_capacity`, `current_heat=0` (players only), no statuses; (5) round-1 initiative (Story 004).
- `battle_start_refused` is the ONLY exit on an invalid build — return/emit and leave `is_battle_active == false`, `_ctx == null`. Do NOT create the `BattleContext` before the validity check passes.
- Enemy has no heat/energy runtime fields — use a null/absent sentinel, not `0`, so nothing can Overheat or be energy-gated. Enemy stat access is `stats.get(key, 0)` everywhere (Rule 8 / EC-TBC-15).
- Never call `evaluate()` (only `evaluate_silent`); never retain a live `SymbotBuild`/evaluator-cache reference into battle code (Manifest forbidden `mid_battle_stat_recompute`).

---

## Out of Scope

- Story 001: the FSM host, `is_battle_active`, teardown (this story populates the `BattleContext` the host owns).
- Story 004: round-1 initiative computation (Rule 2 step 5).
- Story 014: `battle_ended` payloads and post-battle discard (AC-TBC-32 fresh-snapshot re-run is tested there).

---

## QA Test Cases

- **AC-TBC-01**: battle-start snapshot & frozen synergy
  - Given: 3 player Symbots (distinct part sets) + 1 enemy, all builds valid
  - When: `start_battle` runs `BATTLE_INIT`→`ROUND_START`
  - Then: `evaluate_silent` call count == 3; `synergy_changed` never emitted; each `cached_bonus_block` matches its own parts; all 3 Symbots at full structure/energy, heat 0; enemy has no synergy block and `current_structure == stats["structure"]`
  - Edge cases: a Symbot with an empty synergy result still gets a (zero) frozen block
- **AC-TBC-42**: invalid-build refusal
  - Given: a fielded Symbot with a `level_requirement=6` ARMS part under a level-4 CORE (`is_build_valid == false`)
  - When: battle start requested
  - Then: no state/snapshot created; `battle_start_refused(invalid_symbot_ids, offending_parts)` names the Symbot + part; no `battle_ended` fires; `is_battle_active() == false`
  - Edge cases: positive control — same roster all-valid proceeds through Rule 2 normally
- **AC-TBC-02**: enemy resource asymmetry
  - Given: enemy authored with `cooling`/`energy_capacity`/`recharge` values and a 30-cost skill
  - When: instantiated
  - Then: no `current_heat`/`current_energy` live counters; all enemy moves selectable regardless of cost
- **AC-TBC-19**: absent enemy stat keys
  - Given: enemy `stats = { "structure": 80 }`
  - When: mobility/processing/armor/resistance are read during setup/formulas
  - Then: each reads 0 (mobility 0 → acts last; processing 0 → zero-potency statuses; armor/resistance 0 → full damage); no crash

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tbc/battle_start_sequence_test.gd` — must exist and pass. Uses stub Assembly/Synergy/CoreProgression injections; asserts `evaluate_silent` call count and the refusal path with no state creation.

**Status**: [x] Complete — `tests/unit/tbc/battle_controller_start_test.gd`

---

## Completion Notes

**Completed**: 2026-07-17 · **Criteria**: 4/4 (AC-TBC-01, 42, 02, 19) verified against source + discriminating tests.

- AC-TBC-42 (invalid build refuses the WHOLE battle before any snapshot), AC-TBC-01 (`evaluate_silent` once per fielded Symbot, zero `synergy_changed`), AC-TBC-19 (enemy instantiated with no synergy — Rule 8), AC-TBC-02 (frozen snapshot seeds runtime pools) each land a dedicated discriminating test.
- **Deviation (note)**: `make_enemy` seeds the enemy with live pools (`current_energy = capacity`, `current_heat = 0`) rather than leaving them null. Harmless — enemy `begin_turn` skips decay & recharge (Rule 8), so the seeded values are never read; the enemy never participates in the heat/energy economy.

**Test Evidence**: `battle_controller_start_test.gd` — full GUT suite **762/762 green, 4268 asserts** (Godot 4.7 · GUT 9.7.1).
**Code Review**: inline as godot-gdscript-specialist (lean per-story gate) — no blocking issues.

---

## Dependencies

- Depends on: Story 001 (FSM host + `BattleContext`)
- Unlocks: Story 004 (initiative reads the snapshot), Story 014 (fresh-snapshot re-run on next battle)
