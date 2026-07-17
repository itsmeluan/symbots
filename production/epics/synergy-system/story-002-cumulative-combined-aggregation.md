# Story 002: Cumulative & combined tier aggregation (SYN-F3 stat_delta)

> **Epic**: Synergy System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/synergy-system.md`
**Requirement**: `TR-syn-003`, `TR-syn-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: All effective-stat composition funnels through a single point; the synergy bonus block is produced by the pure formula core and folded in once. Aggregation is blind summation — it does not validate stat names.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Typed `Dictionary` accumulation; `.get(key, 0)` tolerant reads. No post-cutoff API required.

**Control Manifest Rules (this layer — Core)**:
- Required: pure formula core in `src/core/`; single SYN-F4 composition point downstream (consumer-owned, not here) — this story produces the `stat_delta` the consumer folds.
- Forbidden: reimplementing SYN-F4 here; validating/filtering stat keys during aggregation (blind sum is the spec).
- Guardrail: synchronous, testable computation.

---

## Acceptance Criteria

*From GDD `design/gdd/synergy-system.md`, scoped to this story:*

- [ ] **AC-SYN-02** — Cumulative tier stacking: VOLT=5, VOLT-3 `{energy_power:6}`, VOLT-5 `{energy_power:12, effects:[volt_test]}` → `stat_delta["energy_power"] == 18` (6+12). FAIL if 12 (5-piece-only, non-cumulative).
- [ ] **AC-SYN-03** — Combined synergy stacks additively with constituents (Scenario A + B): A (ironclad=3, VOLT=3): `armor == 13` (8+5), `energy_power == 10` (6+4). B (ironclad=3, VOLT=0): `armor == 8` (combined NOT active). FAIL A if 5/8/18; FAIL B if 13.
- [ ] **AC-SYN-09** — 5-piece boundary at exactly 5: 4 VOLT → `energy_power == 6` (3-piece only, 5-piece NOT active at 4); add 5th → `energy_power == 18` (cumulative). Guards off-by-one.
- [ ] **AC-SYN-15** — Tier deactivation below threshold: VOLT=5 → `energy_power == 18`, counter 1; drop to VOLT=4 → `energy_power == 6` (5-piece deactivated, 3-piece still active), counter 2. FAIL if 18 (stale cache) or 0 (3-piece wrongly dropped).
- [ ] **AC-SYN-17** — Unknown stat key does not crash aggregation (EC-SYN-06): VOLT-3 `{ speed: 10 }` (not in 11-stat schema) → no crash, counter 1, `stat_delta["speed"] == 10` (blind aggregation, no name validation). FAIL if crash or key dropped.
- [ ] **AC-SYN-27** — Seven simultaneously active tiers aggregate correctly (EC-SYN-02 max): ironclad=8, VOLT=5, KINETIC=3 → `active_synergies.size() == 7`; `armor == 40` (8+20+4+5+3); `energy_power == 22` (6+12+4). FAIL if size<7 or any sum short.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines and GDD Formula SYN-F3:*

- **SYN-F3 (stat aggregation)**: for every active tier (from Story 001's `active_synergies`), sum each `stat_delta[S]` into the block: `block.stat_delta[S] = block.stat_delta.get(S, 0) + tier.stat_delta[S]`. All active tiers contribute — **both** the 3-piece and the 5-piece of the same element stack (TR-syn-003), and combined synergies (e.g. `ironclad_volt_3_piece`) are just additional active tiers that stack **on top of** their constituents, never replacing them (TR-syn-004).
- Aggregation is **blind**: never look up `S` against Assembly's 11-stat schema; sum whatever key the tier authored (EC-SYN-06 — an unknown key like `"speed"` lands inert in the block; a downstream consumer reading via `.get(S, 0)` over the known stats never sees it).
- Deactivation falls out of recomputing from scratch each `evaluate()` — do **not** diff against the previous block. A dropped count → the tier is absent from `active_synergies` → its delta simply isn't summed. Recompute-from-scratch is what makes AC-SYN-15 pass without stale-cache handling.
- The 7-tier case (AC-SYN-27) is the accumulation stress path — verify the dictionary-merge has no collision/overwrite bug when multiple tiers write the same stat key (`armor` written by 5 tiers).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: counting, activation, tier guards, `evaluate()` + signal.
- **Story 003**: the `effects` array (dedup + alphabetical ordering) — this story only aggregates `stat_delta`. (AC-SYN-02's `effects:[volt_test]` assertion is satisfied once Story 003 lands; scope the Story 002 test to the `stat_delta` assertions.)
- **Consumer-owned**: SYN-F4 `max(0, base+delta)` clamp (AC-SYN-06/10).

---

## QA Test Cases

*Embedded from the GDD's AC fixtures. Implement against these.*

- **AC-SYN-02**: Given VOLT=5 (slots 0–4), VOLT-3 `{energy_power:6}`, VOLT-5 `{energy_power:12}`; When `evaluate`; Then `energy_power==18`. Edge: FAIL==12 (non-cumulative).
- **AC-SYN-03 Scenario A**: Given slots 0–2 `[ironclad,VOLT]`, slots 3–7 `[KINETIC]`, Ironclad-3 `{armor:8}`, VOLT-3 `{energy_power:6}`, Ironclad-VOLT-3 `{armor:5,energy_power:4}`; Then `armor==13` AND `energy_power==10`. Edge: FAIL 5/8/18.
- **AC-SYN-03 Scenario B**: Given slots 0–2 `[ironclad,KINETIC]`, VOLT=0; Then `armor==8` (combined not active). Edge: FAIL 13.
- **AC-SYN-09**: Step 1 VOLT=4 → `energy_power==6`; Step 2 VOLT=5 → `energy_power==18`. Edge: off-by-one at exactly 5.
- **AC-SYN-15**: Step 1 VOLT=5 → 18, counter 1; Step 2 VOLT=4 → 6, counter 2. Edge: stale-cache (18) and over-deactivation (0).
- **AC-SYN-17**: Given VOLT-3 `{speed:10}`, VOLT=3; Then no crash, counter 1, `stat_delta["speed"]==10`. Edge: crash on schema lookup; silent drop.
- **AC-SYN-27**: Given ironclad=8/VOLT=5/KINETIC=3 (7 tiers, see GDD content anchors); Then `active_synergies.size()==7`, `armor==40`, `energy_power==22`. Edge: tier lost at high count; merge collision.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/synergy/synergy_aggregation_test.gd` — must exist and pass.

**Status**: [x] Complete — `tests/unit/synergy/synergy_aggregation_test.gd`, 7 tests, all passing (full suite 762/762 green, 4268 asserts, 2026-07-17)

---

## Dependencies

- Depends on: Story 001 (SynergySystem owner, counting, activation, evaluate())
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-07-17 (lean per-story gate — `/code-review` + `/story-done`, inline as godot-gdscript-specialist)

**Criteria**: 6/6 acceptance criteria verified against source (SYN-F3 aggregation in `synergy_system.gd`) + tests (content-matched).

**Deviations**: None. Each AC has a discriminating fixture in `synergy_aggregation_test.gd` (7 tests) carrying an explicit failure witness: AC-SYN-02 cumulative "FAIL 12 = non-cumulative"; AC-SYN-03 combined stacks (armor 8+5=13, energy 6+4=10) with a companion test proving combined stays inactive when VOLT=0 ("FAIL 13"); AC-SYN-09 off-by-one boundary at exactly 5; AC-SYN-15 deactivation recomputes-from-scratch ("FAIL 18 stale / 0 over-drop"); AC-SYN-17 unknown stat key passes through verbatim; AC-SYN-27 seven simultaneously-active tiers accumulate with no merge collision (armor written by 5 tiers → 40).

**Test Evidence**: `tests/unit/synergy/synergy_aggregation_test.gd` — 7 tests. Full suite 762/762 green, 4268 asserts (Godot 4.7 · GUT 9.7.1).

**Code Review**: Pass. Aggregation is a blind additive sum over active tiers (no schema lookup on stat keys — AC-SYN-17 confirms), recompute-from-scratch each `evaluate` (no stale cache — AC-SYN-15). No blocking issues.
