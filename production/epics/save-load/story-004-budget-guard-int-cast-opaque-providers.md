# Story 004: Budget guard + int-cast discipline + opaque unknown providers

> **Epic**: Save/Load
> **Status**: Not Started
> **Layer**: Foundation (persistence)
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/exploration-progress.md` (Rule 7 opaque unknown keys; Rule 4 source-vs-derived)
**ADR Governing Implementation**: ADR-0001: Save/Load Architecture & Serialization Format
**ADR Decision Summary**: Three resilience rules on the write/read path. (1) **Budget guard** — reject a save whose serialized size ≥ `MAX_SAVE_BYTES` (2 MiB) via an **explicit `if`** that fires in Release (`assert` is stripped from Release exports). (2) **Int-cast on restore** — JSON returns every number as `float`; `int`-cast numeric source facts or a monotonic-ID/counter bug results; the round-trip test asserts **types**. (3) **Opaque unknown providers** — a provider key in the file with no registered provider (newer build, or a removed provider) is preserved opaquely and written back on next save, with a warning; deep-copied on hold, never a live reference into the parsed blob.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: `json_str.to_utf8_buffer().size()` measures the real byte length — call it once per save, never per-frame. The budget check must be an explicit conditional (not `assert`-only) so it exists for real players. `int(...)` cast (or `roundi`) on every numeric source fact. The opaque-key round-trip is what proves the ADR's "new provider, no format-version bump" additive property (VC-8). Type every test `var`; `--import` before GUT; verify count.

**Control Manifest Rules (this layer)**:
- Required: Release-firing (explicit `if`) budget guard; `int`-cast of every numeric source fact on restore; opaque preservation of unknown provider keys (deep-copied).
- Forbidden: `assert`-only budget guard; trusting JSON floats as ints; dropping an unknown provider key; holding a live reference into the parsed blob.
- Guardrail: an unknown key survives a full save→load→save round-trip byte-identical; a restored `int` field is `typeof == TYPE_INT`, not `TYPE_FLOAT`.

---

## Acceptance Criteria

- [ ] **AC-SL-20** (budget guard rejects): a save whose serialized size ≥ `MAX_SAVE_BYTES` returns `{ok=false, reason="budget_exceeded"}` and writes nothing (prior save intact). Unit test: a provider producing an oversized snapshot (or a lowered test threshold) triggers rejection.
- [ ] **AC-SL-21** (budget guard is not assert-only): the guard is an explicit `if` returning `budget_exceeded`, verified by a test that runs the guard logic directly (not gated behind `assert`). Unit test asserts the code path returns the failure dict — proving it would fire in a Release export where `assert` is stripped. (A redundant dev-only `assert` may coexist but is not the guard.)
- [ ] **AC-SL-22** (under-budget passes): a normally-sized save is well under budget and writes fine. Unit test: a small envelope → `{ok=true}` (proves the guard is not over-eager).
- [ ] **AC-SL-23** (int-cast on restore): numeric source facts restored from a JSON round-trip are `int`, not `float`. Unit test: a provider with an `int` field survives stringify→parse→restore with `typeof(field) == TYPE_INT` (discriminator: without the cast, JSON.parse yields `TYPE_FLOAT`).
- [ ] **AC-SL-24** (opaque unknown provider preserved): a save file containing a provider key with **no** registered provider is preserved and written back **byte-identical** on the next save, with a warning through the injected LogSink. Unit test: load an envelope with an unregistered `&"future_system"` key, save, assert the key + its exact content survive AND the spy recorded a warning.
- [ ] **AC-SL-25** (opaque hold is a deep copy, not a live ref): mutating the parsed source blob after load does **not** change the held opaque data written on next save. Unit test: load, mutate the original parsed dict, save, assert the written opaque blob matches the ORIGINAL (proving a deep copy was held). Discriminator against a shared-reference bug.
- [ ] **AC-SL-26** (registered provider takes precedence over a stored blob for its own key): if a key is both registered AND present in the file, the registered provider's `snapshot()` is what gets written on the next save (the opaque path is only for **un**registered keys). Unit test.

---

## Implementation Notes

- Budget guard placement — in `save()`, **after** `JSON.stringify`, **before** the atomic write (SL-3):
  ```gdscript
  var json_str := JSON.stringify(envelope, "\t")
  if json_str.to_utf8_buffer().size() >= MAX_SAVE_BYTES:
      return {ok=false, reason="budget_exceeded"}   # explicit if — fires in Release
  # (optional redundant dev tripwire) assert(...)
  ```
- Int-cast: this story establishes the **discipline + a helper** (`_as_int(v) -> int` returning `int(v)`), and proves it on a stub provider. Each real provider applies it in its own `restore()` (the `drop` provider does so in SL-6). The round-trip test asserts `typeof == TYPE_INT`.
- Opaque unknown providers: on `load`, split the parsed `providers` map into **registered** (dispatch to the provider) and **unregistered** (deep-copy via `.duplicate(true)` into a `_held_opaque: Dictionary`). On the next `save`, merge `_held_opaque` into the `providers` map **before** stringify, so unknown keys are written back. Warn once per unknown key through the injected sink.
- **Deep copy is mandatory** — `.duplicate(true)`, not a shared reference — so a later mutation of the parsed blob cannot corrupt the held data (AC-SL-25). This mirrors ADR-0001 rule 3's "never a live reference into the parsed blob."

---

## Out of Scope

- The atomic write mechanics themselves (SL-3) — this story adds the guard **in front of** them and the opaque merge into the envelope.
- Emergency save + never-destroy-unparseable (SL-5).
- The `drop` provider's own int-cast application (SL-6) — this story proves the discipline on a stub.
- On-device budget **measurement** (VC-7) — this is the code-side guard, not the hardware pass.

---

## QA Test Cases

*Automated unit spec — `tests/unit/persistence/budget_opaque_test.gd`.*

- **AC-SL-20/21/22**: oversized → `budget_exceeded` (explicit-if path exercised directly); under-budget → ok.
- **AC-SL-23**: int field survives round-trip as `TYPE_INT`.
- **AC-SL-24/25/26**: unknown key preserved byte-identical + warned; held blob is a deep copy (mutation-proof); registered key beats a stored blob.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence/budget_opaque_test.gd` — must exist and pass. BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: SL-3 (the write path the guard fronts + the load path the opaque merge extends).
- Unlocks: SL-6 (the `drop` provider applies the int-cast discipline established here).
