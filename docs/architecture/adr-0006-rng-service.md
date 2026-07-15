# ADR-0006: RNG Service & Determinism

## Status
Accepted (2026-07-14)

> Accepted by architecture-review 2026-07-14: covers TR-df-003, TR-eai-004/005, TR-drop-001/005 (+ TR-test-001 determinism); engine-safe on Godot 4.6 (RandomNumberGenerator APIs stable, PCG32 within-build-only determinism correctly scoped); dependencies (ADR-0002, ADR-0004) Accepted, no cycles. Root-seed logging depends on `LogSink.info`, added to ADR-0002 §5 (conflict C-2) as part of acceptance. Open item retained: AC-EAI-06 pinned seeds re-verify on engine bump. TR-eai-006/007/008/009 are NOT RNG concerns and are re-pointed to ADR-0007 in the traceability index.

## Date
2026-07-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (pure GDScript entropy source — no scene, physics, or rendering surface) |
| **Knowledge Risk** | MEDIUM — the API used (`RandomNumberGenerator`, `.seed`, `.randi()`, `.randomize()`) is 4.0-era stable, **but** the underlying PCG32 sequence for a given seed changed across 4.4→4.6 (verified: `enemy-ai.md` AC-EAI-06 records the algorithm shift). Any hard-coded seed→sequence expectation is engine-version-fragile |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (no RNG entry), `deprecated-apis.md` (no RNG entry), `design/gdd/enemy-ai.md` AC-EAI-06 |
| **Post-Cutoff APIs Used** | None. `RandomNumberGenerator` and all methods used predate the cutoff. The *risk* is a post-cutoff behavioral change (seed→sequence mapping), not a new API |
| **Verification Required** | (1) **State-reset semantics — CONFIRMED** (godot-specialist, 2026-07-14): setting `.seed` fully resets the PCG32 state deterministically (`.state` defaults to `0` after a `.seed` assignment; not additive). No separate `.state` handling is needed for this design. Retained as a regression check on engine bumps. (2) **AC-EAI-06 hard-coded seeds** (`SEED_A`/`SEED_B`) — **OPEN, standing obligation**: must be computed against the pinned 4.6 `randi_range(0, tied_count-1)` and re-verified on any engine bump. This is the one genuinely open determinism gate this ADR inherits. (3) **`.seed` readable after `randomize()` — CONFIRMED** (godot-specialist, 2026-07-14): `randomize()` writes the entropy value to `.seed` immediately, so `_root_seed = _root.seed` is correct. Retained as an engine-bump regression check |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted — injected `LogSink`; `global_push_diagnostics` forbidden pattern — the root-seed log line uses `LogSink.info`, never `print`/`push_warning`), ADR-0004 (Accepted — autoload **slot 9 `RngService`** already reserved; `init()` runs at BootScreen `run_boot()` **step 4**, never in `_ready` per the `autoload_ready_work` forbidden pattern) |
| **Enables** | ADR-0007 (TBC state machine — owns the crit roll that produces `crit_mult` for DF-1, and pulls the `seed:int` it injects into Enemy AI `request_move`; both entropy handles come from this service) |
| **Blocks** | Drop System implementation stories (need `make_rng`), Enemy AI implementation stories (need the `seed:int` source), any TBC crit-resolution story |
| **Ordering Note** | Fully **independent of ADR-0005** — DF-1 is deterministic and consumes no RNG (Damage Formula Rule 5; registry `damage_computation`). This ADR can be authored, accepted, and implemented in either order relative to 0005. It **must** precede ADR-0007, which is the sole orchestrator that consumes both vending methods |

## Context

### Problem Statement

Three approved systems consume randomness, and they demand **two structurally incompatible shapes** of it:

- **Enemy AI** (`enemy-ai.md` Rule 3) requires an injected **integer `seed`** from which it builds a *fresh* `RandomNumberGenerator` **per call**, making `request_move` a pure function of `(battle_state, profile, seed)`. It must never share a persistent RNG instance across calls and never touch `@GlobalScope` `randf()`.
- **Drop System** (`drop-system.md` Rule 10, EC-DS-06) requires an injected **`RandomNumberGenerator` instance** threaded through its entire ID-ascending roll loop, where **stream position is semantically load-bearing**: a pity-guaranteed part *skips its draw* precisely so the stream stays synchronized with the non-guaranteed rolls (AC-DS-10, AC-DS-13).
- **Turn-Based Combat** (ADR-0007, not yet written) will roll crits and pass `crit_mult` into DF-1 (`damage-formula.md` TR-df-003 — "crit_mult must be passable, not hardcoded internally").

No document decides *where the entropy comes from*, *how production seeds are generated without persisting stream state*, or *how to keep gameplay and pure-formula code from reaching for a global `randf()`* — the pattern that would silently destroy per-resolution determinism and every seeded AC. ADR-0001 already made the load-bearing adjacent decision: it persists **pity counters** but **no RNG seed or stream state**, which fixes the reproducibility model to *per-resolution seeding* before this ADR starts. 9 technical requirements (traceability-index.md § ADR-0006) are gapped here.

### Constraints

- **Fixed 10-autoload roster** (ADR-0004) — `RngService` is slot 9; no additional autoload may be introduced.
- **`init()` in `run_boot()`, not `_ready`** (ADR-0004 `autoload_ready_work`) — the service is a thin host; its root stream is seeded at boot **step 4**, after DBs/validation, before any screen that could roll.
- **No global diagnostics** (ADR-0002 `global_push_diagnostics`) — the root-seed log uses the injected `LogSink`.
- **No RNG state in the save** (ADR-0001) — the reproducibility model is already fixed to per-resolution seeding; this ADR must **not** reopen it by persisting stream state.
- **80% GUT coverage; DI over singletons; deterministic, isolated, injection-friendly tests** (TR-test-001) — the service must be **fully bypassable**: no test should be forced to route through it.
- **Determinism is engine-version-scoped** — the PCG32 sequence changed 4.4→4.6; determinism guarantees hold *within one engine build*, not across upgrades. (Internal PRNG changes may not surface in user-facing breaking-change logs — the engine reference is silent on RNG — so treat all seed→sequence stability as within-build only regardless of patch notes.)
- **`randi()` output space is 2³²** — `RandomNumberGenerator.randi()` returns a 32-bit unsigned value in `[0, 2³²−1]` zero-extended to a GDScript `int` (always non-negative, never above 4,294,967,295). Seed space is therefore 2³², not 2⁶⁴ — entirely adequate for short single-player sessions, and it confirms a vended `0` is a valid seed (no sentinel needed).

### Requirements

- Provide a fresh **`int` seed** on demand for build-your-own-per-call consumers (TR-eai-004, TR-eai-005).
- Provide a fresh **seeded `RandomNumberGenerator`** on demand for stream consumers (TR-drop-001, TR-drop-005).
- Provide the entropy handle TBC uses for crit rolls and for supplying AI seeds (TR-df-003, via ADR-0007).
- Keep all randomness injectable/stubbable so seeded ACs are writable (TR-test-001).
- Log a coarse **root seed** for bug reproduction without persisting anything (user decision, 2026-07-14).

## Decision

**A single thin `RngService` autoload (slot 9) that is the sole entropy *source*, vending two shapes — a fresh `int` seed and a fresh seeded `RandomNumberGenerator` — from one root stream, with the root seed logged (not persisted). Gameplay and pure-formula code never call the service mid-resolution: orchestrators pull a seed/instance at the *start* of a resolution unit and inject it downward, exactly mirroring ADR-0005's "pure core + injected owners" philosophy. The service is fully bypassable, so tests inject stub seeds/instances directly.**

The **determinism boundary is the resolution unit** — one `request_move` call; one drop roll pass; one crit roll. Within that boundary, given the injected seed/instance, output is bit-reproducible on the pinned engine. Across the whole session, reproducibility is *coarse* (the root seed is logged, not a replay guarantee — UI-driven vend order is not fixed), which is honest and sufficient for bug repro and matches ADR-0001's decision not to persist stream state.

### Layer 1 — The entropy source (`RngService`, autoload slot 9)

Thin `Node` host. `_ready` does nothing (ADR-0004). All setup is in `init()`, called at boot step 4. Holds exactly one root `RandomNumberGenerator` and the captured root seed. Owns no gameplay state and is never read by pure code.

### Layer 2 — The injection discipline (project-wide rule, not a class)

Randomness flows **downward as parameters**, never sideways through the autoload:

- **Orchestrators** (BootScreen, TBC per ADR-0007, the Drop resolver's owner) are the *only* callers of `RngService`. They pull a `seed:int` or a `RandomNumberGenerator` at the start of a resolution.
- **Pure formula core** (`src/core/`, ADR-0005) and **gameplay resolvers** receive `seed:int` / `rng:RandomNumberGenerator` as parameters. They must not reference the `RngService` autoload — that would make them impure and untestable.
- **Fresh-per-call** — a pure-function resolver (Enemy AI) rebuilds its RNG from the injected seed on every call and never caches an instance between calls (`enemy-ai.md` Rule 3).

### Architecture Diagram

```
                    ┌─────────────────────────────────────────┐
  BootScreen ──────▶│  RngService (autoload slot 9)            │
  run_boot() step 4 │  _root: RandomNumberGenerator  ← seeded  │
                    │  _root_seed: int   (logged, NOT saved)   │
                    └───────────────┬─────────────────────────┘
                    vend (orchestrators only)   │
        ┌───────────────────────────┼───────────────────────────┐
        ▼                           ▼                            ▼
  next_seed(&"ai") : int     make_rng(&"drop")            next_seed(&"crit")
        │                     : RandomNumberGenerator            │  (ADR-0007)
        ▼                           ▼                            ▼
  TBC injects seed ──▶     Drop resolver threads         TBC rolls crit,
  AI.request_move(         one rng through the           passes crit_mult
  battle_state, seed)      ID-ascending roll loop         into DF-1
  builds FRESH rng         (pity skip = no draw,          (deterministic,
  per call                  stream stays synced)           consumes no RNG)
```

### Key Interfaces

```gdscript
class_name RngService extends Node   # autoload slot 9 (ADR-0004); thin host

var _root: RandomNumberGenerator     # the one root stream; vends every sub-seed
var _root_seed: int                  # captured for logging; NEVER serialized
var _log: LogSink                    # injected at boot step 4 (ADR-0002)

## Called by BootScreen.run_boot() step 4 — NOT _ready (ADR-0004 autoload_ready_work).
## root_seed == 0 → draw OS entropy (production). Nonzero → deterministic root
## (soak tests, CI, whole-session repro). The effective root seed is logged once.
func init(log_sink: LogSink, root_seed: int = 0) -> void

## Fresh int seed for build-your-own-per-call consumers (Enemy AI, TBC crit).
## label is an optional domain tag written to the seed log (&"" = untagged).
func next_seed(label: StringName = &"") -> int

## Fresh, seeded RandomNumberGenerator for stream consumers (Drop roll loop).
## The caller owns the returned instance and its stream position.
func make_rng(label: StringName = &"") -> RandomNumberGenerator
```

**Reference behaviour (implementation guide, not normative wording):**

```gdscript
func init(log_sink: LogSink, root_seed: int = 0) -> void:
    _log = log_sink
    _root = RandomNumberGenerator.new()
    if root_seed == 0:
        _root.randomize()            # OS entropy (production)
        _root_seed = _root.seed      # capture what randomize() chose (VERIFY on 4.6)
    else:
        _root.seed = root_seed       # deterministic root (tests / CI / soak)
        _root_seed = root_seed
    _log.info(&"rng_root_seeded", { "root_seed": _root_seed })

func next_seed(label := &"") -> int:
    var s := _root.randi()           # draw one value off the root stream
    _log.info(&"rng_seed_issued", { "seed": s, "label": label })
    return s

func make_rng(label := &"") -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = next_seed(label)      # a valid seed of 0 is fine — no sentinel
    return rng
```

**Why no `seed` parameter on the vending methods:** the service is *bypassable by construction*. A test that needs a specific seed injects the `int` directly into the consumer (Enemy AI `request_move(state, SEED_A)`) or injects a stub `RandomNumberGenerator` subclass into the Drop resolver (`drop-system.md` AC-DS-04 stubs `randf()`). Nothing is ever forced through the service, so the vending methods never need a caller-supplied seed — which also removes the `0`-as-sentinel ambiguity (a vended `randi()` of `0` is a perfectly valid seed).

## Alternatives Considered

### Alternative 1: Global mutable singleton with ad-hoc `randf()`/`randi()`
- **Description**: One long-lived `RandomNumberGenerator` on the autoload; any system calls `RngService.randf()` wherever it needs a number.
- **Pros**: Fewer call sites; no seed threading.
- **Cons**: Destroys per-resolution determinism (Enemy AI cannot be a pure function of an injected seed; cross-call sequence bleed is exactly the hazard `enemy-ai.md` Rule 3 forbids). Drop's skip-draw stream-sync semantics become impossible to reason about when other systems share the stream. Un-stubbable → seeded ACs (AC-DS-04, AC-EAI-06) can't be written.
- **Rejection Reason**: Directly contradicts two approved GDD contracts and the injectable-tests mandate (TR-test-001).

### Alternative 2: No service — each system calls `@GlobalScope` `randi()`/`randf()`
- **Description**: Skip the autoload; systems use engine globals.
- **Pros**: Zero infrastructure.
- **Cons**: No seed control at all → nothing is reproducible; every seeded AC is unwritable; no bug-repro handle whatsoever. `randomize()`-at-startup global state is the least testable option in Godot.
- **Rejection Reason**: Fails determinism, testability, and reproducibility simultaneously.

### Alternative 3: Persist a master seed + vend log for full session replay
- **Description**: Store a master seed in the save file and replay the exact vend sequence.
- **Pros**: Full deterministic replay in principle.
- **Cons**: Fragile — UI-driven vend order isn't fixed, so replay desyncs on the first out-of-order player action. Lets players save-scum drops by reloading into the identical stream. **Contradicts ADR-0001**, which deliberately persists pity but not RNG state; adopting this would require reopening an Accepted ADR.
- **Rejection Reason**: High cost, false guarantee, and it reverses a settled decision. The chosen *log-for-repro* model gives the 90% of the benefit (a reported root seed narrows repro) at near-zero cost.

## Consequences

### Positive
- Both incompatible consumer contracts are satisfied by one small service via two vending shapes.
- Pure-formula code (ADR-0005) and gameplay resolvers stay pure and GUT-testable — randomness is always a parameter.
- The service is bypassable, so every seeded AC (AC-DS-04, AC-DS-10, AC-EAI-06) is writable exactly as the GDDs specify.
- Coarse bug reproduction from the logged root seed, with labeled vends giving a readable per-resolution trace — at the cost of a couple of log lines.
- Nothing new to persist; ADR-0001 stays closed.

### Negative
- Orchestrators must thread `seed`/`rng` explicitly — more parameters than a global would need. (Accepted: this is the same DI cost ADR-0005 already pays, and it is what makes the ACs writable.)
- Determinism is engine-version-scoped: a Godot upgrade can change the seed→sequence mapping, forcing re-verification of any pinned-seed test (AC-EAI-06).

### Risks
- **PCG32 sequence drift across engine versions** — *Mitigation*: Verification Required note (1)/(2); AC-EAI-06's pinned seeds are re-verified on every engine bump; determinism guarantees are documented as within-build only.
- **A developer reaches for `@GlobalScope` `randf()` out of habit** — *Mitigation*: `global_rng_access` forbidden pattern + a static test that greps `src/` for `randf(`/`randi(`/`randf_range(`/`randi_range(` calls that are not method calls on an injected `RandomNumberGenerator` (mirrors ADR-0002's connection-auditor test strategy).
- **Formula/pure code imports the `RngService` autoload** — *Mitigation*: `rng_service_in_formula_code` forbidden pattern; `src/core/` must not reference the autoload symbol.
- **`randomize()` `.seed` readback** — *Resolved* (godot-specialist, 2026-07-14): `.randomize()` writes the entropy value to `.seed` on 4.6, so `_root_seed = _root.seed` is correct; retained only as an engine-bump regression check (Verification Required 3). No fallback path needed.
- **Root RNG passed across a thread boundary** — `RandomNumberGenerator` is not thread-safe; concurrent `randi()` on one instance is undefined. The design is single-threaded (all vends on the main thread from orchestrators), so this is implicitly safe today. *Mitigation*: if threaded AI batch evaluation is ever added, each thread must receive a pre-vended `int` seed (which Enemy AI already takes) and build its own RNG — never share the root instance or call `next_seed()` off-thread.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| enemy-ai.md | TR-eai-004 — Seeded RNG injected per call, fresh instance, no persistent state | `next_seed()` vends the `int`; the injection discipline (Layer 2) mandates fresh-per-call construction and bans a shared instance |
| enemy-ai.md | TR-eai-005 — Pure function of `(battle_state, profile, seed)`; deterministic tiebreak | Seed is a parameter, not a service call; AC-EAI-06's pinned seeds inherited as a determinism obligation (Verification Required 2) |
| drop-system.md | TR-drop-001 — RNG draws seeded, deterministic, part-ID-ascending roll order | `make_rng()` vends a `RandomNumberGenerator` the resolver threads through the ordered loop; caller owns stream position |
| drop-system.md | TR-drop-005 — Pity-guaranteed drops skip RNG draw; stream stays synchronized | Caller-owned stream position makes "skip the draw" a caller decision, not a service concern — the service never advances a stream the caller doesn't drive |
| damage-formula.md | TR-df-003 — `crit_mult` must be a passable parameter, not hardcoded internally | Crit is rolled by the orchestrator (TBC, ADR-0007) using `next_seed(&"crit")`, then `crit_mult` is passed into the deterministic DF-1 (ADR-0005); DF-1 consumes no RNG |
| coding-standards.md | TR-test-001 — deterministic, isolated, injection-friendly tests | Service is fully bypassable; consumers accept injected `int`/`RandomNumberGenerator`; no test is forced through the autoload |

## Performance Implications
- **CPU**: Negligible. One `randi()` per vend; one `RandomNumberGenerator.new()` per drop pass / AI call. No per-frame work.
- **Memory**: One root generator on the autoload (~tens of bytes); vended instances are short-lived and owned by the caller.
- **Load Time**: `init()` at boot step 4 is a single `randomize()` (or seed assignment) + one log line — sub-microsecond.
- **Network**: N/A (offline single-player).

## Migration Plan
No existing code. New system. `src/core/` has no RNG references to migrate; the injection discipline is enforced from first implementation.

## Validation Criteria
- Given the same injected seed, `request_move` returns the identical move across repeated calls (fresh-per-call determinism — AC-EAI-06).
- Given the same injected stub `RandomNumberGenerator`, the Drop roll loop is bit-reproducible, and a pity-guaranteed part leaves the stream position unchanged (AC-DS-10, AC-DS-13).
- The static forbidden-`randf()` grep test passes over `src/` (no `@GlobalScope` random calls; no autoload reference in `src/core/`).
- `init()` logs exactly one `rng_root_seeded` line; a deterministic `root_seed` reproduces the same vend sequence within one engine build.
- Pinned-seed sequence verified on Godot 4.6 (Verification Required 1/2).

## Related Decisions
- ADR-0001 — Save/Load (persists pity, **not** RNG state — fixes the reproducibility model this ADR inherits)
- ADR-0002 — Event Bus (injected `LogSink`; `global_push_diagnostics` forbidden — the root-seed log uses it)
- ADR-0004 — Scene/Boot (autoload slot 9 reserved; `init()` at `run_boot()` step 4)
- ADR-0005 — Stat Pipeline (DF-1 deterministic, consumes no RNG; "pure core + injected owners" philosophy mirrored here)
- ADR-0007 — TBC state machine (**forward**: sole orchestrator consuming both vending methods; owns the crit roll)
- design/gdd/enemy-ai.md (Rule 3 RNG contract, AC-EAI-06), design/gdd/drop-system.md (Rule 10, EC-DS-06), design/gdd/damage-formula.md (TR-df-003)
