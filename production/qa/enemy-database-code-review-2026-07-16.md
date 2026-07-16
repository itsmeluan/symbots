# Enemy Database — Batch Code Review (Stories 001–009)

> **Date**: 2026-07-16
> **Reviewer**: inline (no subagents — session constraint `project-subagent-model-1m-resolved`)
> **Scope**: the deferred batch `/code-review` for the Enemy-DB implementation
> **Suite at review**: **623/623 GUT green**, 3815 asserts, 45 scripts (fresh headless run)

## Files reviewed

| File | Lines | Role |
|------|-------|------|
| `src/core/content/enemy_def.gd` | — | `EnemyDef` schema + `EnemyClass` enum (Story 001) |
| `src/core/content/enemy_catalog.gd` | — | `EnemyCatalog.entries` (Story 001) |
| `src/core/content/enemy_db.gd` | — | loader + null-safe lookup (Story 002) |
| `src/core/content/break_hp_formula.gd` | — | EDB-1 `derive_break_hp` (Story 003) |
| `src/core/content/xp_reward_formula.gd` | — | CP-F4 `derive_xp_value` (Story 009) |
| `src/core/content/validators/enemy_validator.gd` | 939 | all six ContentValidator families (Stories 004–009) |
| `src/core/content/content_validator.gd` | 345 | compositional root |

Validator surface is **1284 lines across two files** — well under the ADR-0003 1500-line
DoD split trigger (the per-DB helper extraction already happened).

## Verdict: PASS — no blocking issues

### Correctness spot-checks

- **EDB-2 TTK (lines 825–835)** — pure integer arithmetic. `dmg = (a_cal²)/(a_cal+D)`
  is int/int floor; `a_cal + D ≥ 35 > 0` so no div-by-zero, and the `dmg <= 0` guard
  covers the floor-to-zero tail. `ttk = (structure + dmg - 1)/dmg` is the integer-ceil
  identity. Matches the exhaustive python3 scan (A_cal ∈ {35,53}, D 0–200, structure
  1–700: ZERO divergences vs `math.ceil`; both GDD fixtures reproduced). No float/epsilon.
- **CP-F4 xp (lines 916–924)** — re-derives via `XpRewardFormula` (single formula home,
  no pasted math), exact int compare. Pure integer (WILD ×1 / BOSS ×2) → no epsilon.
- **AC-ED-19 min-break-gated (lines 650–661, const line 518)** — correctly implements the
  GDD "for every enemy entry" semantics (not the narrower Story-007 inline BOSS-only note);
  the doc comment flags the divergence and cites the GDD as source of truth. **This is the
  exact rule that gates Story 010** (see below).
- **Break-region fraction bounds (lines 435–444)** — uses `±1e-9` tolerance on the
  0.15/0.55 IEEE-754 boundaries; correct (a naked `>=`/`<=` would reject authored edges).
- **Boss-grade product invariant (lines 626–634)** — asserts `base × multiplier ≥ 0.5`
  as a product (not a hardcoded ×500), so it survives base-rate retuning. Exact at the
  boundary (`0.001 * 500.0 == 0.5`) — correctly no epsilon.

### Quality

- Every public method doc-commented with AC/TR provenance; all magic numbers are named,
  GDD-sourced constants. Full static typing. Diagnostics via injected `LogSink`
  (`_error`/`_warn`) — no `push_error`/`push_warning`. DI seams (`_part_lookup`,
  `_ai_profile_checker`) keep `src/core/` singleton-free and unit-testable. Matches
  ADR-0003 and the layer control manifest.

### Non-blocking notes

- `_check_enemy_xp_value` derives with `enemy.level` even when level is out of range; an
  out-of-range level then produces BOTH a `level_range` and an `xp_mismatch` error. This is
  acceptable (two genuinely distinct authored-value violations) and never crashes.

## Downstream consequence (Story 010)

The AC-ED-19 implementation (≥2 break-gated parts **per enemy**, WILD included) is the
binding constraint that makes Story 010 (MVP roster authoring) **unsatisfiable at 0 warnings**
against the current Part DB: only 2 of 14 parts carry break-gating `drop_conditions`, and one
is BOSS_GRADE (illegal on WILD), so no WILD can reach ≥2. Story 010 is BLOCKED-on-Part-content
by decision (2026-07-16) — see `story-010-*.md` Blocker. This is a content gap, not a code
defect; the validator is behaving exactly as the GDD specifies.
