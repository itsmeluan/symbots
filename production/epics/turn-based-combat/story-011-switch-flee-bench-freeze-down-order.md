# Story 011: Switch, flee, bench-status freeze & down-ordering

> **Epic**: Turn-Based Combat
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rules 6–7, EC-TBC-04/06/12/13/14)
**Requirement**: `TR-tbc-014`, `TR-tbc-015`, `TR-tbc-016`, `TR-tbc-034`, `TR-tbc-042`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary)
**ADR Decision Summary**: A voluntary switch to a living benched Symbot consumes the turn; a forced switch (active DOWNED) is free and the incoming Symbot keeps its own independently-tracked resources (not reset) but does not act that round. Benched Symbots' heat/energy/statuses freeze and resume on return. DOWNED clears all statuses. Flee is WILD-only (rejected in BOSS), consumes the action, resolves after turn-start bookkeeping. A consumed turn advances initiative; a free action does not.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. Each of the 3 Symbots tracks Structure/Energy/Heat/statuses **independently** — benched state is frozen, not shared. Rejections (dead-bench switch, BOSS flee) log an error and change no state (never crash).

**Control Manifest Rules (Core layer)**:
- Required: per-combatant runtime state lives in `BattleContext`; the FSM `FORCED_SWITCH` state handles the free replacement.
- Forbidden: `battle_state_on_transient_node`; `coroutine_park_across_action` (the switch/flee choice arrives via `submit_action`, never `await`).

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-12**: *(Verifies EC-TBC-06)* switch with no living bench rejected; forced switch free and stateful. Scenario A: both benched DOWNED → switch absent from the action set; direct `switch_to(index)` rejected with logged error, no state change. Scenario B: active downed, one benched alive → replacement fields immediately, no turn consumed, arrives with its own tracked resources (not reset).
- [ ] **AC-TBC-37**: voluntary switch consumes the turn. Living bench exists, player chooses voluntary switch → action phase consumed (enemy acts next same round); incoming Symbot first acts at the next round's initiative. Contrast: forced switch (AC-TBC-12 B) consumes no turn — the two paths behave differently.
- [ ] **AC-TBC-17**: *(Verifies EC-TBC-12)* flee rejected in BOSS; succeeds in WILD. Scenario A (BOSS): flee absent; direct `flee()` rejected with logged error; no outcome; state unchanged. Scenario B (WILD): fleeing Symbot has Burn (tick 5), heat 20/cooling 10 → turn-start bookkeeping runs BEFORE `battle_ended(FLED, enemy_id, {})` (heat 10; Burn ticked); flee consumes the action; state discarded; no drops.
- [ ] **AC-TBC-18**: *(Verifies EC-TBC-13 + EC-TBC-14)* bench freezes statuses; DOWNED clears them. Scenario A: A active with Burn (2 left), switch to B; while B acts, A's Burn stays at 2 (no tick, no decrement); on switch back it ticks/decrements from A's next turn-start. Scenario B: A with Burn(1)+Shock(2) is downed → all statuses removed immediately.
- [ ] **AC-TBC-10**: *(Verifies EC-TBC-04)* Burn kill at turn start branches correctly. Scenario A (player): active structure 3, Burn tick 5, one living bench → DOWNED before acting; forced switch free; incoming does NOT act this round; round continues from next initiative slot. Scenario B (enemy): enemy structure 3, Burn tick 5 → `battle_ended(VICTORY,…)` immediately, no enemy action.

---

## Implementation Notes

*Derived from ADR-0007 Rules 6–7:*

- Voluntary switch (Rule 6): consumes the turn → advance initiative (enemy acts next same round); incoming Symbot's first turn is next round. Forced switch (active DOWNED): `FORCED_SWITCH` state, free (no turn consumed), incoming keeps its own frozen resources, does not act this round. Auto-field if exactly one bench lives; DEFEAT if none (Story 014 emits).
- Bench freeze: statuses/heat/energy tick and decrement ONLY on the owning combatant's own turns; benched combatants have no turns, so all their state freezes and resumes on return. DOWNED removes all statuses on that record immediately.
- Flee (Rule 7): present in the WILD action set only; absent (and a direct call rejected, no state change) in BOSS. On WILD flee, turn-start bookkeeping has already run (heat decay, Burn tick) before `battle_ended(FLED, enemy_id, {})` emits in the action phase; consumes the action; no drops/XP (Story 014 owns the payload shape).
- Burn-kill-at-turn-start (Rule 4.1c → DOWNED): if the tick downs the combatant, branch before the action phase — player → free forced switch, incoming does not act this round; enemy → VICTORY immediately.
- Rejections log via the injected LogSink and change no state; never crash.

---

## Out of Scope

- Story 014: the `battle_ended` payload construction (this story triggers FLED/VICTORY/DEFEAT transitions; the 8-field shape + dedup live there).
- Story 007: the status tick/decrement lifecycle itself (this story governs *when* it is frozen/cleared by bench/DOWNED).
- Story 012: the use-item action (a separate 4th action).

---

## QA Test Cases

- **AC-TBC-12**: dead-bench reject / forced-switch stateful
  - Given: A: both benched DOWNED; B: active downed, one bench alive (with its own heat/energy)
  - When: A → switch attempted; B → forced replacement
  - Then: A → switch absent + `switch_to` rejected, no change; B → replacement fields free, resources not reset
- **AC-TBC-37**: voluntary switch consumes turn
  - Given: active turn, living bench
  - When: voluntary switch chosen
  - Then: turn consumed (enemy next same round); incoming acts next round; distinct from forced switch (free)
- **AC-TBC-17**: flee BOSS/WILD
  - Given: A (BOSS): flee attempted; B (WILD): fleeing Symbot Burn tick 5, heat 20/cooling 10
  - When: flee resolves
  - Then: A → rejected, no outcome, state unchanged; B → heat 10 + Burn ticked BEFORE `battle_ended(FLED, enemy_id, {})`; action consumed; no drops
  - Edge cases: FLED before bookkeeping is a FAIL; flee in the WILD action set required
- **AC-TBC-18**: bench freeze / DOWNED clears
  - Given: A: Burn(2), switch to B; B: A Burn(1)+Shock(2), A downed
  - When: B takes turns / A is downed
  - Then: A Burn stays 2 while benched, resumes on return; all A statuses removed at DOWNED
- **AC-TBC-10**: Burn-kill branching
  - Given: A (player): active structure 3, Burn tick 5, one bench; B (enemy): structure 3, Burn tick 5
  - When: the afflicted turn starts
  - Then: A → DOWNED pre-action, free forced switch, incoming does not act this round; B → VICTORY immediately

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/switch_flee_down_order_test.gd` — must exist and pass. Voluntary-vs-forced contrast + WILD-flee bookkeeping-before-FLED required.

**Status**: [x] Complete — `tests/unit/tbc/battle_controller_switch_item_test.gd`

---

## Completion Notes

**Completed**: 2026-07-17 · **Criteria**: 5/5 (AC-TBC-12, 37, 17, 18, 10) verified against source + discriminating tests.

- AC-TBC-12 (voluntary switch keeps the incoming's FROZEN runtime), AC-TBC-37 (voluntary switch consumes the turn), AC-TBC-17 (flee succeeds WILD / rejected BOSS) were already covered.
- **Gate findings closed (4 new tests)**: the switch-test header mislabels its AC IDs, and cross-checking by scenario content exposed three untested BLOCKING Logic behaviors — all present in source but unproven. Closed this gate in `battle_controller_switch_item_test.gd`:
  - AC-TBC-10 Scenario A — `test_burn_kill_at_turn_start_downs_active_and_clears_all_statuses` + `test_burn_kill_of_active_with_living_bench_parks_forced_switch` (turn-start Burn downs the active before it acts → FORCED_SWITCH park → free replacement pick accepted).
  - AC-TBC-10 Scenario B — `test_enemy_burn_death_at_turn_start_ends_in_victory`.
  - AC-TBC-18 Scenario A — `test_benched_statuses_freeze_while_active_takes_its_turn` (a benched 1-turn Burn neither ticks nor decrements while the active takes its turn — a stray decrement would have expired it).
  - AC-TBC-18 Scenario B (DOWNING clears ALL statuses) is now integration-proven via the first new test (was only isolated `StatusSet.clear()` unit coverage before).

**Test Evidence**: `battle_controller_switch_item_test.gd` — full GUT suite **762/762 green, 4268 asserts** (Godot 4.7 · GUT 9.7.1).
**Code Review**: inline as godot-gdscript-specialist (lean per-story gate) — no blocking issues.

---

## Dependencies

- Depends on: Story 001 (FSM `FORCED_SWITCH`), Story 005/007 (turn-start bookkeeping + statuses), Story 004 (initiative advance)
- Unlocks: Story 014 (FLED/DEFEAT/VICTORY transitions feed the payload)
