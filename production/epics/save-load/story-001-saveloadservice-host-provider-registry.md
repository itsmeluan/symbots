# Story 001: SaveLoadService host + provider registry

> **Epic**: Save/Load
> **Status**: Not Started
> **Layer**: Foundation (persistence)
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/exploration-progress.md` (Rule 8 — the EP↔Save/Load split this host implements)
**ADR Governing Implementation**: ADR-0001: Save/Load Architecture & Serialization Format (Accepted; amended 2026-07-17)
**ADR Decision Summary**: Save/Load is a **Foundation autoload that does file I/O** — it lives in `src/` but NOT `src/core/` (ADR-0001's explicit purity carve-out). It owns a registry of provider domains keyed by a stable `StringName`, each implementing `snapshot()`/`restore()`/`rederive()`. This story delivers the host shell + the registry + the injected LogSink seam; the envelope, predicate, and disk I/O land in SL-2/SL-3.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: `SaveLoadService` is an autoload (ADR-0001 Foundation slot). For unit testing it must be constructible as a plain object with injected dependencies (LogSink, file backend) — do not hard-couple to `Engine.get_singleton()` or a global. `class_name SaveLoadService` — run `Godot --headless --import` before GUT so the new `class_name` compiles (else GUT silently skips the `_test.gd` and stays green at the old count; verify the count rose by exactly the number of tests added). No file I/O in this story.

**Control Manifest Rules (this layer)**:
- Required: provider registered under a stable `StringName` key; injected LogSink for all diagnostics; host constructible with dependency injection (no global singleton reach).
- Forbidden: global `push_warning`/`push_error`; silent overwrite of an already-registered key; file I/O in `src/core/`.
- Guardrail: a duplicate key registration is a hard programmer error (assert/error via the sink), never a silent last-wins.

---

## Acceptance Criteria

- [ ] **AC-SL-01**: `register_provider(key: StringName, provider)` stores the provider under `key`. A subsequent internal lookup for `key` returns the same provider instance. Unit test: register one provider, assert it is retrievable.
- [ ] **AC-SL-02**: Registering two different keys keeps both — the registry holds N providers after N distinct-key registrations. Unit test: register `&"drop"` and `&"settings"`; assert both present, count == 2.
- [ ] **AC-SL-03**: Registering a **duplicate** key is a hard error — it routes an `error(code, detail)` through the injected LogSink (SpyLogSink records exactly one error) and does **not** silently replace the first provider (fail-loud, not last-wins). Unit test: register `&"drop"` twice; assert the spy recorded ≥1 error AND the originally-registered instance is the one retained (discriminator: a last-wins implementation would keep the second).
- [ ] **AC-SL-04**: All host diagnostics route through the **injected** LogSink — never global `push_warning`/`push_error`. Unit test: a SpyLogSink injected at construction captures the duplicate-key error (proves the seam is wired, not bypassed to a global).
- [ ] **AC-SL-05**: The host is constructible for tests with injected dependencies (LogSink + file backend) — no reach into `Engine`/autoload globals in the constructor path. Unit test: construct with a SpyLogSink and a fake backend; no crash, no global access.

---

## Implementation Notes

- Create `src/persistence/save_load_service.gd` (`class_name SaveLoadService extends RefCounted` for now — the autoload wrapper is wired at boot per ADR-0004, out of scope here). **This file lives in `src/persistence/`, NOT `src/core/`** — it is the ADR-0001 I/O carve-out.
- `_init(log: LogSink = null, backend = null)` — inject the LogSink and (in SL-3) the file backend. A `null` LogSink may default to a no-op sink; production wires the real one at boot.
- Registry is a `Dictionary[StringName, Object]` (or untyped `Dictionary` keyed by `StringName`). On `register_provider`, check `has(key)` first: if present, `error(&"save_provider_duplicate_key", {"key": key})` and **return without replacing**.
- The provider contract is duck-typed here (`snapshot`/`restore`/`rederive` are called in later stories); this story only stores and retrieves. Do not validate method presence yet unless it is free to do so.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The envelope assembly, `save_format_version`, SL-PRED-1 predicate, and two-phase restore orchestration (SL-2).
- All file I/O — `save(slot)`/`load(slot)` disk contact, atomic write, `.bak` (SL-3).
- Budget guard, int-cast, opaque unknown providers (SL-4); emergency save + never-destroy (SL-5).
- The autoload registration + boot sequence (ADR-0004).

---

## QA Test Cases

*Automated unit spec — `tests/unit/persistence/save_load_service_test.gd`.*

- **AC-SL-01/02**: register one → retrievable; register two distinct → both present, count 2.
- **AC-SL-03**: register duplicate key → spy has ≥1 error AND first instance retained (not replaced).
- **AC-SL-04/05**: SpyLogSink injected at construction captures the error; construct with fake backend, no global reach.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence/save_load_service_test.gd` — must exist and pass. BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (epic anchor). Reuses the existing `LogSink` + `tests/unit/tbc/spy_log_sink.gd`.
- Unlocks: SL-2 (envelope + predicate), which orchestrates the registered providers.
