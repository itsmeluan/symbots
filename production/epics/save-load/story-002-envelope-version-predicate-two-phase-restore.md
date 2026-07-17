# Story 002: Envelope assembly + SL-PRED-1 version predicate + two-phase restore

> **Epic**: Save/Load
> **Status**: Not Started
> **Layer**: Foundation (persistence)
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/exploration-progress.md` (EP-PRED-1 + Rule 9 — SL-PRED-1 is structurally identical, applied to the whole file)
**ADR Governing Implementation**: ADR-0001: Save/Load Architecture & Serialization Format
**ADR Decision Summary**: The save is a provider-domain envelope `{ "save_format_version": 1, "providers": { <key>: <snapshot>, ... } }`. `snapshot()` pulls plain data from every registered provider. Restore is **two-phase and order-independent**: Phase 1 every provider restores raw facts (no cross-provider reads), Phase 2 every provider `rederive()`s. SL-PRED-1 gates restore on `save_format_version`: `== CURRENT → RESTORE`, `< CURRENT → MIGRATE` (no hooks at v1 → behaviorally REFUSE), `> CURRENT → REFUSE`, missing/non-int → REFUSE. **A REFUSE leaves all in-memory state exactly as before `load()`.**

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: This story is **in-memory only** — no disk. `save()` assembles the envelope `Dictionary` and (for the test) the predicate + two-phase restore consume an envelope `Dictionary` directly (SL-3 adds the JSON encode + file write around it). Use a fake/stub provider that records call order and counts to prove Phase-1-before-Phase-2 and order-independence. Run `--import` before GUT if any new `class_name` is added; verify test count rose by exactly the number added; type every test `var`.

**Control Manifest Rules (this layer)**:
- Required: envelope carries `save_format_version` (owned by Save/Load) + a `providers` map; two-phase restore (all Phase-1, then all Phase-2); REFUSE leaves in-memory state untouched.
- Forbidden: a provider reading another provider's restored state in Phase 1; applying a partial restore on a REFUSE verdict; interpreting the inner `progress_format_version` (opaque to Save/Load).
- Guardrail: restore outcome is independent of provider registration order (order-independence is the whole point of two phases).

---

## Acceptance Criteria

- [ ] **AC-SL-06**: `save()` assembles `{ "save_format_version": <CURRENT>, "providers": { key → provider.snapshot() } }` for every registered provider. Unit test: two stub providers → envelope has both keys under `providers`, and `save_format_version == SAVE_FORMAT_VERSION`.
- [ ] **AC-SL-07** (SL-PRED-1, RESTORE): an envelope with `save_format_version == CURRENT` restores — every registered provider's `restore()` then `rederive()` is called. Unit test: spy providers confirm both were invoked.
- [ ] **AC-SL-08** (SL-PRED-1, REFUSE newer): `save_format_version > CURRENT` → REFUSE. **No** provider `restore()` or `rederive()` fires; `load` returns `{ok=false, reason=...}`; in-memory state untouched (call-count spy == 0). Unit test with a discriminator: a naive implementation that restores anyway would trip the spy.
- [ ] **AC-SL-09** (SL-PRED-1, REFUSE older/no-hook): `save_format_version < CURRENT` with no migration hook registered → behaviorally REFUSE (MIGRATE branch exists but has zero hooks at v1). No provider restore fires. Unit test.
- [ ] **AC-SL-10** (SL-PRED-1, REFUSE malformed): a **missing** `save_format_version` key, or a **non-int** value (e.g. `"1"` string, `1.5` float that is not integral) → REFUSE. No provider restore fires. Unit test covers both the missing case and the non-int case as separate discriminators.
- [ ] **AC-SL-11** (two-phase ordering): across all providers, **every** Phase-1 `restore()` completes **before** any Phase-2 `rederive()`. Unit test: an ordering-spy provider appends a marker in each method; assert all `restore` markers precede all `rederive` markers.
- [ ] **AC-SL-12** (order-independence): restoring the same envelope with providers registered in reversed order produces the identical restored state. Unit test: register `{A, B}` then `{B, A}`, restore the same envelope, assert both provider states match — proving Phase 1 does no cross-provider read.

---

## Implementation Notes

- `SAVE_FORMAT_VERSION := 1` (constant on the service, per ADR-0001).
- `save()` (this story: returns the envelope `Dictionary`; SL-3 wraps it with encode+write): iterate the registry, call each provider `snapshot()`, place under `providers[key]`. **Never** put the version inside a provider's blob — it is a file-level (outer) key.
- Predicate helper `_classify(version) -> {RESTORE|MIGRATE|REFUSE}`: exact-int-equality → RESTORE; strictly-less integer → MIGRATE (→ REFUSE at v1, no hooks); strictly-greater → REFUSE; missing key or non-integer value → REFUSE. Guard the int check carefully: JSON yields floats, so "is it an integer-valued number" is `typeof == INT or (typeof == FLOAT and value == floor(value))` — but a **string** version is REFUSE.
- Restore orchestration on a RESTORE verdict: **Phase 1** loop — for each registered provider, if the envelope has its key, call `restore(providers[key])`; **then** **Phase 2** loop — for each registered provider, call `rederive()`. Two separate loops — never interleaved (that is what guarantees no Phase-1 cross-provider read sees Phase-2 output).
- On REFUSE: return `{ok=false, reason=...}` **before** touching any provider. This is the "leaves in-memory state untouched" guarantee — the spy's call count must be 0.

---

## Out of Scope

- JSON encode/parse + all file I/O (SL-3) — this story consumes/produces `Dictionary` envelopes in memory.
- Budget guard, int-cast of provider fields, opaque unknown providers (SL-4).
- Emergency save, never-destroy-unparseable (SL-5).
- Real provider implementations — use stub/spy providers here; the `drop` provider is SL-6.

---

## QA Test Cases

*Automated unit spec — `tests/unit/persistence/envelope_predicate_test.gd`.*

- **AC-SL-06**: envelope shape + version + both provider keys.
- **AC-SL-07**: v==CURRENT → restore then rederive both fire.
- **AC-SL-08/09/10**: v>CURRENT, v<CURRENT-no-hook, missing key, non-int (string + non-integral float) → REFUSE, spy call-count 0, `{ok=false}`.
- **AC-SL-11**: all `restore` markers precede all `rederive` markers.
- **AC-SL-12**: reversed registration order → identical restored state.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence/envelope_predicate_test.gd` — must exist and pass. BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: SL-1 (the host + registry this orchestrates).
- Unlocks: SL-3 (wraps this envelope with JSON encode + atomic write).
