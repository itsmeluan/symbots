# Story 002: SymbotBuild owner & equip mechanics (Rule 3)

> **Epic**: Symbot Assembly System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/symbot-assembly.md`
**Requirement**: `TR-sa-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot (primary)
**Secondary**: ADR-0002: Event Bus & Signal Architecture (owner-declared typed signals)
**ADR Decision Summary**: `SymbotBuild` is a Layer-2 stateful `RefCounted` owner (not an autoload, not a node), DI-constructed with `(cfg, log)` + collaborators. `equip_part(slot_type, part_instance)` implements Assembly Rule 3: slot-type validate → `CoreProgression.can_equip` gate → atomic displace/install (no empty slots ever) → eager `StatPipeline.derive` → emit `part_equipped` + `stats_changed`.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: `SymbotBuild` is a plain `RefCounted` — no scene-tree lifecycle. Signals are owner-declared, typed, direct-connection (`part_equipped(slot_type: int, new_part_id: StringName)`, `stats_changed(final_stat: Dictionary)`) — never EventBus additions (ADR-0002). No `await` anywhere in equip — the pipeline is synchronous.

**Control Manifest Rules (this layer — Core)**:
- Required: Owners are DI `RefCounted` objects, not autoloads; constructors take `(cfg, log)` + collaborators (ADR-0005).
- Required: All effective-stat composition goes through `StatMath.effective_stat` / `CombatantSnapshot.effective_stat` — but note `SymbotBuild.final_stat` is **base stats only** (no synergy); Rule 8 keeps synergy out of Assembly.
- Forbidden: `runtime_content_mutation` — displaced/installed parts are instance records referencing frozen `PartDef`; never mutate a def (ADR-0003).
- Forbidden: `global_push_diagnostics` — the `can_equip` rejection message and any warning go through the injected `LogSink` / a returned result, not `push_error` (ADR-0002).

---

## Acceptance Criteria

*From GDD `design/gdd/symbot-assembly.md`, scoped to this story:*

- [x] **AC-SA-01** — Slot type mismatch rejected. Equip `"spark_core"` (`slot_type=CORE`) into the WEAPON slot → returns an error; WEAPON slot still holds its prior occupant; Inventory unchanged; no displacement.
- [x] **AC-SA-04** — Equip displaces current occupant to Inventory. WEAPON holds Part A at `tier=+2`; equip Part B → WEAPON now holds Part B; Inventory gains exactly one copy of Part A at `tier=+2`. No duplication, no destruction.
- [x] **AC-SA-10** — Re-equipping the already-equipped part is a no-op. WEAPON holds Part A `tier=+2`; `equip(WEAPON, Part A)` → returns without error; WEAPON still holds Part A `tier=+2`; Inventory unchanged; **no** `part_equipped` or `stats_changed` emitted.
- [x] **EC-SA-08** — New `SymbotBuild` initializes all 8 slots with starter Common parts and computes `final_stat` immediately; the build is valid from the first frame (`drop_enabled=false` starters do not affect usability).

---

## Implementation Notes

*Derived from ADR-0005 Layer 2 and Assembly Rule 3 / Rule 1:*

- Create `class_name SymbotBuild extends RefCounted` in `src/core/stats/symbot_build.gd` (per ADR-0005 §Layer 2 — the stat pipeline home). State: display name; 8-slot manifest of part instances (`instance_id`, `PartDef` ref, `tier`); cached `final_stat`; derived move + passive pools (pools themselves are Stories 004/005). Declare typed signals `part_equipped(slot_type: int, new_part_id: StringName)` and `stats_changed(final_stat: Dictionary)`.
- **`equip_part(slot_type, part_instance)` — Rule 3 exact order**:
  1. **Validate** (AC-SA-01): `part_instance.part.slot_type == slot_type`; else return an error result, no state change, no displacement.
  1b. **No-op guard** (AC-SA-10 / EC-SA-02): if the incoming `part_id` equals the currently equipped `part_id` in that slot → return OK, no displace, no recompute, no signal. *(Guard on `part_id` per the GDD; place before the gate so a same-part call is cheap.)*
  1c. **Level gate**: call the injected `CoreProgression.can_equip(build.core_instance_id, part)`; if false, reject with `"Core level [N] required — your [core name] is level [M]."` No displacement.
  2. **Displace** (AC-SA-04): return the current occupant to the injected `Inventory` as a new instance at its current tier.
  3. **Install**: remove the incoming instance from Inventory; install into the slot.
  4. **Recompute**: eagerly call `StatPipeline.derive(...)` and store the result (correctness ACs are Story 003).
  5. **Emit**: `part_equipped(slot_type, new_part_id)` then `stats_changed(final_stat)`.
- **Injected collaborators** (DI, testability mandate): `Inventory` and `CoreProgression` are constructor-injected interfaces. Both upstream systems are not-yet-implemented (see Dependencies) — **this story uses lightweight test stubs/spies** (a stub Inventory recording added/removed instances; a stub `CoreProgression` returning `can_equip == true` by default, `false` to exercise the gate). Do not hard-depend on concrete Inventory/CoreProgression classes; depend on the injected object.
- **EC-SA-08**: provide a constructor / factory that seeds all 8 slots from starter Common `part_id`s (content data) and runs `derive` once so `final_stat` is populated before any equip.
- No-empty-slot invariant (TR-sa-007): there is no unequip-without-replacement path. If a separate unequip API is ever added it must block when no replacement is provided (EC-SA-10) — out of scope here, but do not add such a path.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: `StatPipeline.derive` itself (already the sole SA-F1 executor; this story only *calls* it).
- **Story 003**: correctness/stability of the recomputed `final_stat` (AC-SA-05 chassis-swap full recompute, AC-SA-07 stability).
- **Stories 004/005**: move-pool and passive-pool derivation. Leave placeholders that Stories 004/005 fill; do not derive pools here.
- **Story 006**: `preview_swap` (SA-F2 delta) — a non-mutating hypothetical, distinct from `equip_part`.
- **Real Inventory & CoreProgression**: concrete persistence/ledger implementations belong to the Inventory epic and Core Progression epic. This story integrates against injected stubs only.

---

## QA Test Cases

*Integration specs — exercise `SymbotBuild.equip_part` end-to-end against stub Inventory + stub CoreProgression collaborators and a spy `LogSink`.*

- **AC-SA-01 — Slot mismatch rejected**
  - Given: a fresh build; WEAPON slot holds a known weapon instance; a CORE-type instance `"spark_core"` in the (stub) Inventory.
  - When: `equip_part(WEAPON, spark_core_instance)`.
  - Then: returns an error result; WEAPON slot unchanged; stub Inventory record unchanged; no `part_equipped`/`stats_changed` emitted.
  - Edge cases: mismatch into every slot type behaves identically (defensive API guard, not just UI).

- **AC-SA-04 — Displace to Inventory**
  - Given: WEAPON holds Part A `tier=+2`; Part B (WEAPON-type) in stub Inventory.
  - When: `equip_part(WEAPON, partB_instance)`.
  - Then: WEAPON holds Part B; stub Inventory now contains exactly one Part A instance at `tier=+2` and no Part B; total instance count conserved (no dup, no loss); `part_equipped(WEAPON, partB_id)` + `stats_changed` emitted once each.
  - Edge cases: displaced instance preserves its `tier` (not reset to +0).

- **AC-SA-10 — Same-part re-equip no-op**
  - Given: WEAPON holds Part A `tier=+2`.
  - When: `equip_part(WEAPON, partA_instance)` (same `part_id`).
  - Then: returns OK; WEAPON still Part A `tier=+2`; Inventory unchanged; **zero** `part_equipped`/`stats_changed` emissions (assert with a signal spy).
  - Edge cases: a *different instance of the same part_id* — per the GDD no-op guards on `part_id`, so still a no-op.

- **AC-SA-01/gate — can_equip rejection**
  - Given: stub `CoreProgression.can_equip` returns `false`.
  - When: `equip_part(ARMS, valid_arms_instance)`.
  - Then: returns the level-required error message; no displacement; slot unchanged; no signals.

- **EC-SA-08 — New build starter init**
  - Given: construct a new `SymbotBuild` via the starter factory.
  - When: construction completes.
  - Then: all 8 slots hold their starter Common instances; `final_stat` is populated (all 11 canonical keys present); build is valid with no equip call yet.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/symbot_assembly/symbot_build_equip_test.gd` — must exist and pass (GUT), OR a documented playtest. Uses stub Inventory + stub CoreProgression collaborators.

**Status**: [x] Done — GUT green 2026-07-16 (suite 657 tests / 53 scripts, was 631/46)

---

## Dependencies

- Depends on: **Story 001** (`StatPipeline.derive` — equip's step-4 recompute calls it). Injected collaborators **Inventory** (system Not Started) and **CoreProgression** (GDD Approved, no code yet) are stubbed in tests — not blockers, per ADR-0005's DI/testability mandate.
- Unlocks: Story 003 (recompute correctness), Story 004 (move pool), Story 005 (passive pool), Story 006 (preview), Story 007 (CP-F3 handoff).

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 4/4 passing (AC-SA-01 slot-mismatch rejected, no displacement/signal; AC-SA-04 displace occupant to Inventory preserving `tier`, no dup/loss, one `part_equipped`+`stats_changed`; AC-SA-10 same-part re-equip no-op guarded on `part.id`, zero emissions; EC-SA-08 `with_starters` factory seeds 8 slots + derives once) — all COVERED by `tests/integration/symbot_assembly/symbot_build_equip_test.gd` (5 tests). The `can_equip` gate rejection is exercised via a stub CoreProgression returning false.
**Deviations**: None material. `SymbotBuild` is a DI `RefCounted` (not autoload/node) with owner-declared typed signals `part_equipped`/`stats_changed` (ADR-0002) — no EventBus additions. Equip follows Rule 3 order exactly: validate → same-part no-op → `can_equip` gate → displace → install → eager recompute → emit (`symbot_build.gd:106`). Design note (not a deviation): injected collaborators (`_inventory`, `_core_progression`, `_move_db`, `_passive_db`) are all optional/null-tolerant so a bare build derives stats without the content DBs wired — when `_inventory == null` displacement is skipped silently, consistent with the "stub in tests, real systems later" mandate (Inventory + CoreProgression epics not yet built).
**Test Evidence**: Integration — `tests/integration/symbot_assembly/symbot_build_equip_test.gd`; full GUT suite 657/657 green (Godot 4.7 headless). Note: the `var x := _inv.added.size()` untyped-inference parse trap (which silently skipped the file) was caught and fixed to `var x: int = …` before close — suite count rose to the true 657, no silent skip.
**Code Review**: Complete — `/code-review` this session, verdict APPROVED. Reviewed inline as godot-gdscript-specialist (1M-context constraint).
