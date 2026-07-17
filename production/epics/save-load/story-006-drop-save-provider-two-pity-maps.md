# Story 006: Drop save provider (two pity maps) + registration

> **Epic**: Save/Load
> **Status**: Done (2026-07-17)
> **Layer**: Foundation (persistence) / Core (Drop System)
> **Type**: Integration
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/drop-system.md` (DS-2 Prototype gradient pity, DS-3 Boss-grade break pity) + `design/gdd/exploration-progress.md` (provider contract)
**Requirement**: `TR-drop-003` (pity persistence)
**ADR Governing Implementation**: ADR-0001: Save/Load (provider contract) — primary; ADR-0006: RNG Service & Determinism (the pity maps are deterministic per-part-ID state)
**ADR Decision Summary**: `DropSystem` becomes the `&"drop"` **provider**: it implements `snapshot()`/`restore()`/`rederive()` over its two existing part-id-keyed pity maps (`_proto_pity_credit`, `_break_pity_counter` — both `String(part_id) → int`, per the 2026-07-17 ADR-0001 amendment). `snapshot()` emits plain data; `restore()` int-casts each counter (JSON floats → int); `rederive()` is a no-op (pity counters are source facts, nothing derived). Registration happens at the boot/autoload seam (`src/`), keeping `src/core/` pure.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: The three provider methods are added to `DropSystem` in `src/core/drop_system/drop_system.gd` and must stay **pure** — they read/write only its own maps, plain data, no file I/O, no global RNG, no `push_*`. Apply the SL-4 int-cast discipline in `restore()` (`int(v)` per counter) — the round-trip must assert `typeof == TYPE_INT` for restored counters. The existing seams `get/set_prototype_pity_credit(part_id: StringName)` and `get/set_break_pity_counter(part_id: StringName)` are the read/write surface. Registration wrapper lives in `src/` (NOT `src/core/`). Type every test `var`; `--import` before GUT; verify count.

**Control Manifest Rules (this layer)**:
- Required: both maps in `snapshot()`; `restore()` int-casts every counter to exact saved value; `rederive()` no-op; registration under `&"drop"`; provider methods pure (no I/O in `src/core/`).
- Forbidden: resetting a counter to 0 on restore; dropping a counter key; returning a live reference to an internal map from `snapshot()`; file I/O inside `src/core/`.
- Guardrail: a restored counter is `TYPE_INT` and equals its exact saved value; the map round-trips through the full SaveLoadService path (envelope → JSON → atomic write → parse → restore), not a bespoke shortcut.

---

## Acceptance Criteria

- [ ] **AC-SL-33** (snapshot shape): `DropSystem.snapshot()` returns `{ "proto_pity_credit": {<part_id>: <int>}, "break_pity_counter": {<part_id>: <int>} }` — plain data, both maps present (empty maps if no pity accrued). Unit test: seed both maps, assert the snapshot shape + values.
- [ ] **AC-SL-34** (snapshot is a copy, not a live map): mutating a map returned by `snapshot()` does not mutate the DropSystem's internal state. Unit test discriminator: snapshot, mutate the returned dict, assert internal counters unchanged (proves a copy, per ADR rule "no live reference").
- [ ] **AC-SL-35** (restore exact values + int type): `restore(data)` sets each counter to its exact saved value, `int`-cast. Unit test: restore from a dict whose values arrived as JSON `float`s (e.g. `72.0`); assert `get_*` returns `72` with `typeof == TYPE_INT`.
- [ ] **AC-SL-36** (rederive no-op): `rederive()` does not alter any counter (pity is a source fact). Unit test: snapshot counters before/after `rederive()`, assert identical.
- [ ] **AC-SL-37** (registration): the `&"drop"` provider is registered with `SaveLoadService`; a full `save(slot)` includes a `providers.drop` entry with both maps. Integration test: register, seed pity, `save`, assert the written envelope's `drop` provider holds both maps.
- [ ] **AC-SL-38** (full-path round-trip): both maps survive the **entire** SaveLoadService path — envelope → `JSON.stringify` → atomic write (fake backend) → parse → SL-PRED-1 RESTORE → `restore()` — with values identical and `int`-typed. Integration test: seed `proto_pity_credit['delta_core']=72` + `break_pity_counter['forge_core']=7`, save, reset DropSystem, load, assert both restored exactly as `int`.

---

## Implementation Notes

- Add to `src/core/drop_system/drop_system.gd`:
  ```gdscript
  func snapshot() -> Dictionary:
      return {
          "proto_pity_credit":  _proto_pity_credit.duplicate(true),
          "break_pity_counter": _break_pity_counter.duplicate(true),
      }
  func restore(data: Dictionary) -> void:
      _proto_pity_credit = _int_map(data.get("proto_pity_credit", {}))
      _break_pity_counter = _int_map(data.get("break_pity_counter", {}))
  func rederive() -> void:
      pass  # pity counters are source facts — nothing to recompute
  ```
  with a small `_int_map(raw: Dictionary) -> Dictionary` helper int-casting each value (JSON floats → `int`). Keys are part-id strings; preserve them verbatim.
- **Purity**: these methods touch only the two maps — no file access, no RNG, no `push_*`. The `.duplicate(true)` on snapshot prevents a live-reference leak (AC-SL-34).
- **Registration** lives in the boot/autoload seam (`src/`, out of `src/core/`): `save_load_service.register_provider(&"drop", drop_system)`. This story wires it (or a thin test harness that stands in for boot) and the integration test drives the full path.
- Confirm the actual internal field names against `src/core/drop_system/drop_system.gd` before writing — the summary recorded `_proto_pity_credit` and a boss map; verify the boss map's exact identifier (`_break_pity_counter` vs `_boss_pity_counter`) and match it.

---

## Out of Scope

- **AC-DS-28 (the pity-persistence integration capstone)** — that is **Story DS-009** in the Drop System epic, which this story unblocks. SL-6 proves the provider round-trips; DS-009 proves the **boundary semantics** (post-reload `+= c` / `+= 1` advance and the guarantee firing). Do not duplicate DS-28 here.
- The pity **mechanics** (`+= c`, `+= 1`, thresholds, guarantee) — owned by Drop Stories 004/005, already Done.
- The other four providers (`progression`, `inventory`, `workshop`, `settings`) — register when built.

---

## QA Test Cases

*Automated spec — `tests/unit/persistence/drop_provider_test.gd` (unit) + the integration assertion in `tests/integration/persistence/drop_roundtrip_test.gd`.*

- **AC-SL-33/34**: snapshot shape; snapshot is a copy (mutation-proof).
- **AC-SL-35/36**: restore exact + `TYPE_INT` from JSON floats; rederive no-op.
- **AC-SL-37/38**: registered under `&"drop"`; full-path round-trip (envelope→JSON→write→parse→restore) preserves both maps as ints.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/persistence/drop_provider_test.gd` + `tests/integration/persistence/drop_roundtrip_test.gd` — must exist and pass. BLOCKING.

**Status**: [x] Created & passing — 7 unit (AC-SL-33..36) + 3 integration (AC-SL-37/38) tests, all green in the 910-test suite (2026-07-17).

**Registration note**: No boot/autoload seam exists yet (the ADR-0004 boot sequencer is an unbuilt Technical-Setup deliverable). Per this story's allowance, registration is exercised by the integration harness standing in for boot (`register_provider(&"drop", drop_system)` through the real `SaveLoadService`). The real boot wiring registers `&"drop"` alongside the other four providers when they are built (see Out of Scope).

---

## Dependencies

- Depends on: SL-2 (provider contract + predicate) + SL-4 (int-cast discipline) + the built DropSystem (Drop Stories 004/005, Done).
- Unlocks: **DS-009** (AC-DS-28) — flips Blocked → Ready; the release-blocker capstone that closes the Drop System epic (9/9).
