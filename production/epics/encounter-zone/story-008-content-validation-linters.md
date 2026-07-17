# Story 008: Content-validation linters

> **Epic**: Encounter Zone System
> **Status**: Done
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-009`, `TR-ez-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content is validated by an offline linter that reads typed defs through the catalog and reports errors/warnings; it never mutates defs and never scans content directories with `DirAccess`. These are ADVISORY gates — they gate content shipping, not code merge.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: Pure data linting over `ZoneDef` fixtures — no RNG, no scene. Density-band rate checks compare floats within `1e-9`. The linters run **now against test fixtures**; the real MVP zone `.tres` content is a deferred authoring pass (needs the ~8-WILD roster + the Art Bible terrain enum, OQ-EZ-1) — the linters are the acceptance gate that content will later have to pass.

**Control Manifest Rules (this layer)**:
- Required: read defs via the injected catalog/reader; diagnostics via LogSink `warn(code, detail)` with severity.
- Forbidden: content-directory `DirAccess` scanning; mutating or `duplicate()`-ing defs; content-enum reordering; `push_warning`/`push_error` from `src/`.
- Guardrail: ADVISORY severity — a linter failure blocks content shipping, not code merge (per the AC tags).

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

- [x] **AC-EZ-10** (ADVISORY, Content Val): `SPARSE` → `encounter_rate == 0.07` (`abs(rate − 0.07) < 1e-9`).
- [x] **AC-EZ-11** (ADVISORY, Content Val): `STANDARD` → `0.15` (within 1e-9).
- [x] **AC-EZ-12** (ADVISORY, Content Val): `DENSE` → `0.35` (within 1e-9).
- [x] **AC-EZ-13** (ADVISORY, Content Val): pacing ratio. `rate[DENSE] / rate[STANDARD] >= 1.6` (default 2.33 passes). Enforces Tuning Knob warning 2.
- [x] **AC-EZ-14** (ADVISORY, Content Val): unknown `density_class` (e.g. `"SWAMP"`) → content error logged + `encounter_rate` defaults to STANDARD 0.15 (conservative fallback, never DENSE).
- [x] **AC-EZ-47** (ADVISORY, Content Val): exactly 1 zone entry, `spawn_enabled = true`, valid `zone_id`.
- [x] **AC-EZ-48** (ADVISORY, Content Val): zone has 3–4 terrain patches; every patch `enemy_subpool.size() >= 1`; every entry `spawn_weight >= 1`.
- [x] **AC-EZ-49** (ADVISORY, Content Val): exactly 2 boss entries — Boss1 `WIN_COUNT`/`required_wins=6`/`regate 2`/`LIGHTER_REGATE`, Boss2 `WIN_COUNT`/`required_wins=10`/`regate 3`/`LIGHTER_REGATE`, both `OVERWORLD`. Boss2 carries `gate_params.requires_defeated == <Boss1 boss_id>`; Boss1 carries none. `required_wins[Boss2] − required_wins[Boss1] >= 3` (10 − 6 = 4 passes). No MVP boss uses `WAVE`/`REACH`/`DUNGEON_RUSH`.
- [x] **AC-EZ-50** (ADVISORY, Content Val): de-duplicated WILD enemy count across all patches ∈ [6, 10] (target ~8).
- [x] **AC-EZ-51** (ADVISORY, Content Val): every `boss_id` resolves to a `BOSS`-class, `spawn_enabled` Enemy DB entry.
- [x] **AC-EZ-54** (ADVISORY, Content Val): terrain-identity invariants (Rule 2a). **A (identity enemy):** every patch contains ≥ 1 `enemy_id` present in no other patch → error naming any failing patch. **A2 (identity-enemy weight floor):** at least one such patch-exclusive enemy is **≥ 10% of its patch's `total_weight`** → warning below the floor. **B (farmable weight floor):** every `SpawnEntry` with `is_farmable_target == true` has `spawn_weight >= 0.20 * patch.total_weight` → warning below the floor.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

- Implement offline linter functions that take a `ZoneDef` (and the injected Enemy-DB reader) and emit LogSink diagnostics — no RNG, no scene, no `DirAccess`.
- Density band linters (AC-EZ-10/11/12): compare `encounter_rate` to the band anchor within `1e-9`. Pacing ratio (AC-EZ-13): `rate[DENSE] / rate[STANDARD] >= 1.6`. Unknown band (AC-EZ-14): error + conservative fallback to STANDARD 0.15 (never DENSE).
- MVP scope linters (AC-EZ-47/48/49/50/51): assert the counts and boss-gate config exactly per Rule 11. AC-EZ-49 includes the machine-checkable escalation gap (`>= 3`) and the Boss2 `requires_defeated` back-reference to Boss1.
- Terrain-identity (AC-EZ-54): A = each patch has ≥1 zone-exclusive enemy (error); A2 = at least one exclusive enemy ≥ 10% of patch weight (warning); B = every `is_farmable_target == true` entry ≥ 20% of patch weight (warning). Query the `is_farmable_target` field directly — no farming-data inference (Drop System data is not read here).
- Author **test fixtures** exercising each linter's pass and fail branch (e.g. a cosmetic-terrain fixture where all patches share one pool fails AC-EZ-54 A; a token-exclusive fixture fails A2). These fixtures are the acceptance evidence; the real MVP zone `.tres` is authored later against these same linters.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001–007: the live resolution/gate engine (these linters are offline data checks, separate from the runtime path).
- **Deferred content pass (not this story):** authoring the real MVP zone `.tres` (one zone, 3–4 patches from ~8 WILD enemies, 2 bosses). This needs the ~8-WILD roster + the finalized Art Bible terrain enum (OQ-EZ-1). This story builds and proves the linters against fixtures; the content that must pass them is a later authoring pass — tracked in the epic's deferred-content note.

---

## QA Test Cases

*Automated content-validation specs — the developer implements against these (offline linter over fixtures).*

- **AC-EZ-10/11/12**: band anchors.
  - Given: patches at SPARSE/STANDARD/DENSE.
  - Then: rates 0.07 / 0.15 / 0.35 within 1e-9; a fixture off-anchor fails.
- **AC-EZ-13**: pacing ratio.
  - Given: DENSE 0.35, STANDARD 0.15.
  - Then: ratio 2.33 ≥ 1.6 passes; a fixture at ratio 1.4 fails.
- **AC-EZ-14**: unknown band.
  - Given: a patch with `density_class = "SWAMP"`.
  - Then: error logged; rate falls back to 0.15 (assert not DENSE).
- **AC-EZ-47/48**: zone + patch scope.
  - Given: a 1-zone, 3–4-patch fixture; a fixture violating each bound.
  - Then: valid passes; 0-zone / 5-patch / empty-patch / weight-0-entry fixtures each fail.
- **AC-EZ-49**: boss config.
  - Given: the canonical 2-boss fixture; mutated fixtures (missing `requires_defeated`, gap < 3, a WAVE boss).
  - Then: canonical passes; each mutation fails with a diagnostic.
- **AC-EZ-50**: WILD count.
  - Given: fixtures with 5, 8, 11 de-duped WILD enemies.
  - Then: 8 passes; 5 and 11 fail the [6, 10] bound.
- **AC-EZ-51**: boss_id resolution.
  - Given: a boss_id resolving to BOSS+enabled; one resolving to missing/disabled/wrong-class.
  - Then: valid passes; each fault fails.
- **AC-EZ-54**: terrain identity.
  - Given A: a cosmetic-terrain fixture (all patches share one pool).
  - Then A: fails (no identity enemy).
  - Given A2: a token-exclusive fixture (exclusive enemy at weight 1 in a 100-weight pool).
  - Then A2: warning (below 10%).
  - Given B: an `is_farmable_target = true` entry at 15% of its patch.
  - Then B: warning (below 20%).

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `tests/unit/encounter_zone/content_validation_test.gd` — offline linter over fixtures; must exist and pass. (Smoke-check parity with `production/qa/smoke-*.md` when the real zone `.tres` is later authored.)

**Status**: [x] Complete — `tests/unit/encounter_zone/content_validation_test.gd`, 21 tests, all green (GUT 9.7.1, Godot 4.7.stable). Each linter is exercised with a pass fixture AND a fail/discriminator fixture: density anchors 0.07/0.15/0.35 + off-band (AC-EZ-10/11/12), pacing ratio 2.33-pass / 1.4-fail (AC-EZ-13), unknown band → error + STANDARD-not-DENSE fallback (AC-EZ-14), zone scope valid / empty-id / disabled (AC-EZ-47), patch scope valid / 5-patch / empty-pool + weight-0 (AC-EZ-48), boss config canonical / missing back-reference / gap-2 / WAVE-gate (AC-EZ-49), WILD count 8-pass / 5-fail / 11-fail (AC-EZ-50), boss-id resolution BOSS+enabled / wrong-class + missing (AC-EZ-51), terrain identity valid / cosmetic-shared-pool (54A error) / token-exclusive (54A2 warning) / farmable-at-15% (54B warning).

---

## Completion Notes (2026-07-17)

- Implemented as a **separate** `ZoneContentLinter` (`src/core/encounter_zone/zone_content_linter.gd`) — a `class_name … extends RefCounted` with no RNG and no scene, distinct from `EncounterResolver`. The linter needs neither an RNG resolver nor the TBC seam, so keeping it off the resolver keeps the runtime path's dependency surface honest. Constructor injects the LogSink + (optional) Enemy-DB reader only.
- **Severity is spec-load-bearing** (matches the AC tags): structural/scope faults (unknown density band, zone/patch scope, boss config, WILD count, boss-id resolution, terrain-identity **A** "no exclusive enemy") are **errors** that flip the return `false`; the Rule 2a weight-floor shortfalls (**A2** identity-enemy < 10%, **B** farmable < 20%) are **warnings** that log but never flip the return — authoring nudges, not shipping blockers.
- `density_band_rate` unknown-band fallback is **conservative STANDARD (0.15), never DENSE** (AC-EZ-14) — an unrecognized band must not silently become a fast-farm biome. `INVALID (0)` and any out-of-range int both hit the `match` default arm → `ez_unknown_density_class` error + 0.15.
- `validate_pacing_ratio(dense, standard)` takes rates as **params** (not read off a def) so a fixture can drive both a passing 2.33 and a failing 1.4 ratio without authoring an off-band patch.
- `validate_boss_config` enforces the **structure** of Rule 11 (2 bosses / OVERWORLD / WIN_COUNT / LIGHTER_REGATE / Boss2→Boss1 `requires_defeated` back-reference / escalation gap `w2−w1 >= 3`), NOT the literal 6/10 tuning values — so a future re-tune of the win thresholds doesn't have to touch the linter, only the eventual `.tres`.
- Terrain identity (AC-EZ-54) uses a `_patch_membership` helper that counts, per `enemy_id`, how many DISTINCT patches contain it (dedup within a patch); an enemy with membership 1 is patch-exclusive. **A** requires ≥1 exclusive per patch (else error); **A2** requires ≥1 exclusive at ≥10% of that patch's total weight (else warning) — the two-tier check closes the token-exclusive loophole a plain "has an exclusive" test would miss.
- Content defs are read **read-only** throughout — no `duplicate()`, no field mutation, no `DirAccess` scanning (ADR-0003 / Control Manifest). The real MVP zone `.tres` remains a **deferred** authoring pass (OQ-EZ-1); these linters are the acceptance gate it will later be validated against.
- New global `class_name ZoneContentLinter` required `--import` before GUT (silent-skip trap avoided). Suite rose by exactly **+21 to 869 tests / 4606 asserts**, all green (EZ dir 47→68).

---

## Dependencies

- Depends on: Story 001 (value types + injected Enemy-DB reader).
- Unlocks: None. (The real MVP zone `.tres` authoring pass — deferred, OQ-EZ-1 — will be validated by these linters.)
