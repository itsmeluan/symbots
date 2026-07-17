# Epic: Save/Load System

> **Layer**: Foundation (persistence)
> **ADR**: docs/architecture/adr-0001-save-load.md (Accepted; amended 2026-07-17)
> **GDD**: design/gdd/exploration-progress.md (the domain-envelope pattern ADR-0001 generalizes)
> **Architecture Module**: Save/Load (Foundation)
> **Status**: ✅ Complete (2026-07-17) — all 6 stories Done; DS-009 capstone Done; suite 913/913 green
> **Stories**: 6 stories (5 Logic, 1 Integration) + the DS-009 capstone (lives in the Drop System epic)

## Overview

The Save/Load System is the single unified way durable game state reaches disk and
comes back. It implements ADR-0001: a **single human-readable JSON file** whose top
level is a **provider-domain registry**, each provider contributing a plain-data
`snapshot()` and restoring via a two-phase `restore()` / `rederive()`. The file
carries a `save_format_version` predicate (SL-PRED-1: `==`→RESTORE, `<`→MIGRATE
[behaviorally REFUSE at v1], `>`→REFUSE, missing/non-int→REFUSE, and a REFUSE leaves
in-memory state untouched). Writes are **atomic** (tmp → verify the full failure
surface → `flush()` → `close()` → rotate `.bak` → `rename_absolute()`); an oversized
save is rejected by an explicit Release-firing budget guard (2 MiB); numeric fields
are `int`-cast on restore (JSON returns every number as `float`); an unregistered
provider key is preserved **opaquely**; an unparseable save is **never destroyed**
(falls back to `.bak`, else surfaces to the error path with bytes intact); and
`save_emergency()` reuses the identical envelope + atomic path for the iOS
app-pause lifecycle. Diagnostics route through an **injected LogSink** — never global
`push_warning`/`push_error`.

This epic delivers the **engine + the provider seam + the one provider the MVP needs
now (`drop`)**. The other four providers named in ADR-0001 (`progression`, `inventory`,
`workshop`, `settings`) register themselves when those Not-Started systems are built —
the ADR's "new provider, no format-version bump" design makes that additive. The
capstone that proves the whole path end-to-end is **DS-009** (pity-counter persistence,
AC-DS-28) — a release-blocker that lives in the Drop System epic and unblocks the moment
this epic lands.

## Placement & Purity

- **`SaveLoadService` is a Foundation autoload that does file I/O** — it lives in
  `src/` **but NOT `src/core/`**. This is ADR-0001's explicit carve-out: core stays
  pure (no `DirAccess`/`FileAccess`), the persistence host owns all disk contact.
- **Providers stay pure.** A provider's `snapshot()`/`restore()`/`rederive()` operate
  only on its own in-memory plain data — no file I/O, no global RNG, no `push_*`.
  The `drop` provider is `DropSystem` itself (already in `src/core/`, already pure):
  it gains the three provider methods over its two existing pity maps.
- **Injected everything.** LogSink injected (never global `push_*`); the file backend
  injected behind a thin seam so forced-failure paths (open-error, `store_string`
  bool `false`, post-write `get_error`) are GUT-testable without a real full disk.

## Governing ADR

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Save/Load Architecture & Serialization Format | Single-file human-readable JSON; provider-domain envelope; SL-PRED-1 version predicate; two-phase order-independent restore; source-facts-only; atomic write + `.bak`; opaque unknown providers; never-destroy-unparseable; injected logger; `save_emergency()`; 2 MiB / 50 ms iOS budget | HIGH (persistence/serialization; re-validated clean 4.6→4.7 on 2026-07-17) |

Supporting: ADR-0002 (injected LogSink; save-trigger quiesce timing lives there, not here),
ADR-0004 (boot order: load → restore → rederive before gameplay), ADR-0006 (the `drop`
provider's pity maps are deterministic per-part-ID state).

## Requirements Covered

ADR-0001 Validation Criteria (the checklist this epic discharges):

| # | Criterion | Story |
|---|-----------|-------|
| VC-1 | Full envelope round-trip: all provider source facts identical, derived state recomputed | SL-2, SL-6 |
| VC-2 | SL-PRED-1: v1→RESTORE, v0→REFUSE, v2→REFUSE, missing/non-int→REFUSE; REFUSE leaves state untouched (spy confirms no `restore()` fired) | SL-2 |
| VC-3 | Forced write failure (open-error / `store_string` bool false / post-write `get_error`) aborts, prior save intact, no handle leaked | SL-3 |
| VC-4 | Unregistered provider key round-trips opaquely | SL-4 |
| VC-5 | Every `snapshot()` is plain data; `int` source facts stay `int` after restore (not `float`) | SL-4, SL-6 |
| VC-6 | Oversized-save budget guard rejects the write in a **Release** build | SL-4 |
| VC-7 | Measured save size + write time within budget on a physical iOS device | Deferred (on-device pass — not an MVP-code story; noted in SL-3 Out of Scope) |
| VC-8 | Reserved provider registers without a `save_format_version` bump | SL-4 (opaque-key test proves the additive property) |
| VC-9 | `save_emergency()` produces a file indistinguishable from `save(slot)`; interrupted emergency write leaves prior save intact | SL-5 |
| VC-10 | Never destroy an unparseable save: fall back to `.bak`, else surface with bytes intact | SL-5 |

## Definition of Done

This epic is complete when:
- All 6 stories are implemented, reviewed, and closed via `/story-done`.
- `SaveLoadService` lives in `src/` (NOT `src/core/`), registers providers, and its
  file I/O is behind an injectable backend so forced-failure paths are GUT-tested.
- SL-PRED-1, two-phase restore, atomic write + full failure surface + `.bak`, the
  Release-firing budget guard, int-cast discipline, opaque unknown providers,
  never-destroy-unparseable, and `save_emergency()` all have discriminating GUT
  fixtures (a pass fixture AND a fail/discriminator fixture per AC).
- The `drop` provider (`DropSystem.snapshot/restore/rederive` over both pity maps)
  round-trips both maps with correct **types**.
- **DS-009 (AC-DS-28) passes** — the integration capstone that closes the Drop System
  epic (9/9) and clears the release-blocker. It flips Blocked → Ready the moment SL-6
  lands, then is implemented and closed in the Drop System epic.
- Full GUT suite stays green throughout (baseline 869/869, 4606 asserts).

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | SaveLoadService host + provider registry | Logic | ✅ Done | ADR-0001 | registry, key-collision, injected LogSink |
| 002 | Envelope + SL-PRED-1 predicate + two-phase restore | Logic | ✅ Done | ADR-0001 | VC-1, VC-2 |
| 003 | Atomic file write + full failure surface + `.bak` | Logic | ✅ Done | ADR-0001 | VC-3 |
| 004 | Budget guard + int-cast + opaque unknown providers | Logic | ✅ Done | ADR-0001 | VC-4, VC-5, VC-6, VC-8 |
| 005 | Emergency save + never-destroy-unparseable | Logic | ✅ Done | ADR-0001 | VC-9, VC-10 |
| 006 | Drop save provider (two pity maps) + registration | Integration | ✅ Done | ADR-0001, ADR-0006 | VC-1, VC-5 (drop) |

**All 6 stories Done (2026-07-17).** Implemented in `src/persistence/save_load_service.gd`
+ `src/persistence/file_backend.gd` (both `src/`, NOT `src/core/`) with the `drop`
provider methods added to `src/core/drop_system/drop_system.gd` (structural provider
protocol — no core→persistence dependency). Test suites under
`tests/unit/persistence/` (SL-1..SL-6) + `tests/integration/persistence/` (SL-6 round-trip).
DS-009 capstone (`tests/integration/drop_system/pity_persistence_test.gd`) passes,
clearing the release-blocker and closing the Drop System epic 9/9.

**6 stories: 5 Logic, 1 Integration.** Build order: **001 (host/registry anchor) →
002 (envelope + predicate + two-phase, in-memory round-trip) → 003 (atomic write layer)
→ 004 (budget/int-cast/opaque) → 005 (emergency + never-destroy) → 006 (drop provider,
wires the first real provider through the whole path).** 002 depends on 001; 003 depends
on 002 (needs a serialized envelope to write); 004 and 005 depend on 003; 006 depends
on 002 (provider contract) + 004 (int-cast, since pity counters are ints). The
**DS-009 capstone** (Drop System epic) depends on 006.

**Testability seam (all stories):** the file backend is injected behind a thin interface
(default = real `FileAccess`/`DirAccess`; a fake in tests). SL-1..SL-2 need no disk
(in-memory round-trip); SL-3..SL-5 drive the fake to force each failure/corruption path
deterministically — no real full-disk or sandbox-denial needed.

## Out of Scope (this epic)

- **The four not-yet-built providers** (`progression`, `inventory`, `workshop`,
  `settings`) — they register when their systems are built (ADR-0001 additive design).
  This epic proves the seam holds an unknown/opaque key so they slot in later.
- **Save-trigger timing** (when `save()` fires — event-boundary quiesce points) —
  owned by ADR-0002 + EP OQ-EP-2, not here. This epic guarantees only that whatever
  reaches `save()` round-trips correctly.
- **Boot integration** (load → restore → rederive during boot) — owned by ADR-0004;
  this epic exposes `load(slot)` but does not wire the BootScreen sequence.
- **On-device iOS budget measurement** (VC-7) — a vertical-slice hardware pass, not
  an MVP-code story. The Release-firing budget guard (SL-4) is the code-side bound.
- **The player-facing save/load UI + error surfacing** — presentation-tier (ADR-0008).

## Next Step

Implement story-by-story keeping the suite green: **SL-1 → SL-2 → SL-3 → SL-4 → SL-5 →
SL-6**, then flip **DS-009** Blocked → Ready and implement the capstone in the Drop
System epic (closing it 9/9 and clearing the release-blocker). On-device iOS budget
measurement (VC-7) is scheduled into the vertical slice.
