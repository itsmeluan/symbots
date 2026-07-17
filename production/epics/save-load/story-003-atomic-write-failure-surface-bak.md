# Story 003: Atomic file write + full failure surface + `.bak` rotation

> **Epic**: Save/Load
> **Status**: Not Started
> **Layer**: Foundation (persistence)
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/exploration-progress.md` (Rule 8 — Save/Load owns disk I/O)
**ADR Governing Implementation**: ADR-0001: Save/Load Architecture & Serialization Format
**ADR Decision Summary**: Writes are **atomic**: serialize → write `user://<slot>.json.tmp`, verifying the **full failure surface** (`get_open_error()` after `open()`, the `store_string()` bool, AND `get_error()` after write) and calling `flush()` **before** `close()` (mandatory on iOS) → on success rotate the current file to `<slot>.json.bak` → `rename_absolute()` tmp → final. A failed write leaves the previous save fully intact (tmp discarded). Every early-return path must `close()` the handle — a leaked handle to `.tmp` blocks later writes.

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: The write-failure surface is the ADR's #1 verification item. On iOS, `store_string()`'s bool alone misses full-disk / sandbox-denial — the error state does not. All three (`get_open_error`, bool, `get_error`) must be clean. `FileAccess.store_*` returns `bool` (4.4 change, **still current in 4.7** — confirmed `docs/engine-reference/godot/breaking-changes.md`); `DirAccess.rename_absolute()` unchanged in 4.7. **Inject a file backend behind a thin seam** so tests force each failure deterministically without a real full disk: default backend = real `FileAccess`/`DirAccess`; a fake backend returns scripted open-errors / bool-false / post-write-errors. Emit pretty JSON: `JSON.stringify(envelope, "\t")`. Run `--import` before GUT; verify count; type every test `var`.

**Control Manifest Rules (this layer)**:
- Required: verify all three failure-surface signals; `flush()` before `close()`; `close()` on every early-return path; atomic tmp→rename; one-generation `.bak`.
- Forbidden: treating the `store_string` bool as sufficient; overwriting the live save before the tmp write fully succeeds; leaking a `FileAccess` handle on an error path.
- Guardrail: a forced failure at ANY of the three points leaves the previous save byte-identical (the tmp is discarded, never promoted).

---

## Acceptance Criteria

- [ ] **AC-SL-13** (happy path): `save(slot)` with a healthy backend writes `<slot>.json.tmp`, rotates any existing `<slot>.json` to `<slot>.json.bak`, renames tmp → `<slot>.json`, and returns `{ok=true}`. Unit test with the fake backend: assert the final file holds the pretty-printed envelope and `has_save(slot)` is true.
- [ ] **AC-SL-14** (open failure): when the backend's `open()` fails (`get_open_error() != OK` / null handle), `save` returns `{ok=false, reason=...}` naming the open failure, writes nothing, and the previous `<slot>.json` is untouched. Unit test: pre-seed a prior save, force open-fail, assert prior bytes unchanged.
- [ ] **AC-SL-15** (store_string bool false): when `store_string()` returns `false`, `save` aborts with `{ok=false}`, the tmp is discarded, the prior save intact. Unit test discriminator: a bool-only check that ignored this would wrongly promote a partial tmp.
- [ ] **AC-SL-16** (post-write get_error): when `store_string()` returns `true` **but** `get_error() != OK` (the iOS full-disk/sandbox case), `save` still aborts with `{ok=false}`, tmp discarded, prior save intact. Unit test — this is the discriminator proving the bool alone is insufficient.
- [ ] **AC-SL-17** (no handle leak): on **every** failure path (open, bool, get_error), the opened handle is closed — a subsequent `save(slot)` on the same slot succeeds (a leaked handle would block it). Unit test: force a failure, then a healthy save on the same slot, assert the second succeeds.
- [ ] **AC-SL-18** (flush before close): the write path calls `flush()` before `close()`. Fake backend records the call sequence; assert `flush` precedes `close`. (iOS durability guarantee.)
- [ ] **AC-SL-19** (`.bak` one-generation): a second successful save rotates the first save's file to `.bak` (exactly one generation kept — the third save's `.bak` is the second save, not an accumulation). Unit test: save v1, save v2, assert `.bak` == v1 content; save v3, assert `.bak` == v2 content.

---

## Implementation Notes

- Backend seam: a tiny interface (`open(path, mode) -> handle`, `rename(from, to)`, `exists(path)`, `remove(path)`) with a real default and a `FakeFileBackend` test double. The double scripts: forced open-error, forced `store_string`-false, forced post-write `get_error`, and records the flush/close call order. **The double must not rely on statically-typed `FileAccess` calls being intercepted** (recall the ptrcall gotcha — the seam is a wrapper object, not a `FileAccess` subclass override).
- Write routine (mirror ADR-0001's snippet exactly):
  ```gdscript
  var fa := backend.open(tmp_path, WRITE)
  if fa == null:
      return {ok=false, reason="open failed: %s" % error_string(backend.last_open_error())}
  var wrote := fa.store_string(json_str)
  var err := fa.get_error()
  fa.flush()          # before close — mandatory on iOS
  fa.close()          # also on every early return above
  if not wrote or err != OK:
      backend.remove(tmp_path)   # discard the partial tmp
      return {ok=false, reason="write failed: %s" % error_string(err)}
  ```
- Rotation order: only **after** the tmp write fully succeeds — if `<slot>.json` exists, `rename` it to `.bak`, then `rename` tmp → `<slot>.json`. Never rotate before the tmp is proven good (else a failed write could leave no live save).
- `save(slot)` composes with SL-2: assemble envelope (SL-2) → `JSON.stringify(envelope, "\t")` → (SL-4 will add the budget guard here) → atomic write (this story).

---

## Out of Scope

- Budget guard + int-cast + opaque unknown providers (SL-4).
- Emergency save + never-destroy-unparseable / `.bak` **read** fallback on parse failure (SL-5) — this story writes the `.bak`; SL-5 reads it on a corrupt primary.
- On-device iOS write-time / size measurement (VC-7) — a vertical-slice hardware pass, not this story. The code-side bound is SL-4's budget guard.
- `load(slot)` parse path — SL-2 handles the in-memory predicate/restore; SL-5 adds the parse + `.bak` fallback around it.

---

## QA Test Cases

*Automated unit spec — `tests/unit/persistence/atomic_write_test.gd`.*

- **AC-SL-13**: happy path writes tmp → rename → final; `has_save` true.
- **AC-SL-14/15/16**: force open-error / bool-false / post-write get_error → `{ok=false}`, prior save byte-identical each time.
- **AC-SL-17**: after each forced failure, a healthy save on the same slot succeeds (no leaked handle).
- **AC-SL-18**: flush precedes close in the recorded call order.
- **AC-SL-19**: `.bak` holds exactly the previous generation across three saves.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence/atomic_write_test.gd` — must exist and pass. BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: SL-2 (the envelope this serializes + writes).
- Unlocks: SL-4 (budget guard sits in front of this write), SL-5 (reads the `.bak` this writes).
