# Story 005: Emergency save + never-destroy-unparseable (`.bak` read fallback)

> **Epic**: Save/Load
> **Status**: Not Started
> **Layer**: Foundation (persistence)
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/exploration-progress.md` (Rule 9 REFUSE guarantee — never lose player bytes)
**ADR Governing Implementation**: ADR-0001: Save/Load Architecture & Serialization Format
**ADR Decision Summary**: Two lifecycle-critical rules. (1) **`save_emergency()`** is the API behind ADR-0004's `NOTIFICATION_APPLICATION_PAUSED` mitigation — a synchronous save to the active slot using the **identical** envelope + atomic-write path (no special format, no shortcuts). Called ONLY from the app-lifecycle handler on the `Game` root. If the OS cuts it off mid-tmp, the atomic design already guarantees the prior save survives. (2) **Never destroy an unparseable save** — if the primary file fails to parse, attempt `.bak`; if both fail, surface to the error path and **do not overwrite** the bytes. Missing file (not corrupt) → new game.

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: `save_emergency()` must reuse the exact `save()` envelope + atomic path — a divergent emergency format is a footgun (a corrupted emergency save is worse than none). The parse path uses `JSON.parse_string()` and checks for `null` / non-Dictionary before predicate evaluation. The `.bak` fallback reads the one-generation backup SL-3 rotates. A **missing** file is distinct from a **corrupt** one: missing → `{ok=false, reason="no_save"}` (new game); corrupt-both → `{ok=false, reason="corrupt"}` with bytes left intact. Type every test `var`; `--import` before GUT; verify count.

**Control Manifest Rules (this layer)**:
- Required: emergency save reuses the identical envelope + atomic write; corrupt-primary falls back to `.bak`; unparseable bytes are never overwritten; missing ≠ corrupt.
- Forbidden: a bespoke emergency format; overwriting a save that failed to parse; treating a missing file as corruption (or vice-versa).
- Guardrail: after a failed load (corrupt both), the primary + `.bak` bytes on disk are byte-identical to before the load attempt.

---

## Acceptance Criteria

- [ ] **AC-SL-27** (emergency save == normal save): `save_emergency()` produces a file **indistinguishable** from `save(active_slot)` — same envelope shape, same `save_format_version`, loadable by SL-PRED-1. Unit test: `save_emergency()` then `load(slot)` round-trips identically to a normal save.
- [ ] **AC-SL-28** (interrupted emergency write is non-destructive): an emergency write that fails mid-tmp (forced via the fake backend) leaves the prior save fully intact. Unit test: seed a prior save, force the emergency write to fail, assert prior bytes unchanged and `load` still returns the prior save.
- [ ] **AC-SL-29** (corrupt primary → `.bak` fallback): when `<slot>.json` fails to parse but `<slot>.json.bak` is valid, `load(slot)` restores from `.bak` and returns `{ok=true, reason?="recovered_from_bak"}`. Unit test: write a valid save (creating a `.bak` on the second save), corrupt the primary, assert load recovers from `.bak`.
- [ ] **AC-SL-30** (both corrupt → surface, do not destroy): when both `<slot>.json` and `.bak` fail to parse, `load` returns `{ok=false, reason="corrupt"}` and **neither file is overwritten** — the bytes are left for inspection/recovery. Unit test discriminator: assert both files' bytes are byte-identical after the failed load (a naive "reset to new game" would clobber them).
- [ ] **AC-SL-31** (missing ≠ corrupt): a slot with **no** file returns `{ok=false, reason="no_save"}` (→ new game), distinct from the `corrupt` reason. Unit test: `has_save(slot)` false → load returns `no_save`, not `corrupt`.
- [ ] **AC-SL-32** (parse guard): a file containing valid JSON that is **not** a Dictionary (e.g. a bare array or `null`) is treated as corrupt (→ `.bak` fallback), not passed to the predicate. Unit test: a `[]`-content primary with a valid `.bak` recovers from `.bak`.

---

## Implementation Notes

- `save_emergency() -> Dictionary`: resolve the active slot, then call the **same** internal `save(slot)` routine (envelope assembly + budget guard + atomic write). No separate code path — that is the whole point. It returns the same `{ok}` dict.
- Load path (wraps SL-2's predicate/restore): read `<slot>.json` bytes → `JSON.parse_string` → if `null` or `typeof != TYPE_DICTIONARY` → try `.bak` the same way → if both fail, return `{ok=false, reason="corrupt"}` **without** writing anything. Only a successfully-parsed Dictionary reaches SL-PRED-1.
- **Never overwrite on a parse failure.** The load path is read-only until a successful parse + RESTORE verdict. A REFUSE or a corrupt-both both leave disk untouched (SL-2 already guarantees REFUSE touches no in-memory state; this story guarantees corrupt touches no disk bytes).
- Distinguish missing (`not backend.exists(path)`) → `no_save` from present-but-unparseable → `corrupt`. Two different reasons, two different downstream behaviors (new game vs. surface-an-error).

---

## Out of Scope

- The player-facing corrupt-save error UI + the app-lifecycle notification wiring (presentation-tier / ADR-0004/0008) — this story exposes `save_emergency()` and the `{ok=false, reason="corrupt"}` surface; the UI consumes it.
- The atomic write + `.bak` **rotation** (SL-3) — this story **reads** the `.bak` SL-3 writes.
- Boot-time load orchestration (ADR-0004).

---

## QA Test Cases

*Automated unit spec — `tests/unit/persistence/emergency_recovery_test.gd`.*

- **AC-SL-27/28**: emergency save == normal save; interrupted emergency non-destructive.
- **AC-SL-29/32**: corrupt (or non-Dictionary) primary → `.bak` recovery.
- **AC-SL-30**: both corrupt → `{ok=false, reason="corrupt"}`, both files byte-identical after (not destroyed).
- **AC-SL-31**: missing file → `no_save`, distinct from `corrupt`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/persistence/emergency_recovery_test.gd` — must exist and pass. BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: SL-3 (atomic write + `.bak` rotation this reads) + SL-2 (the predicate the parsed Dictionary feeds).
- Unlocks: the never-lose-bytes guarantee the vertical slice relies on; the DS-009 capstone (via SL-6) round-trips through this hardened path.
