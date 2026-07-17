# Test Infrastructure

**Engine**: Godot 4.7
**Test Framework**: GUT (Godot Unit Testing) v9.6.1 — https://github.com/bitwes/Gut
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-07-14 (engine re-pinned 4.6 → 4.7 on 2026-07-15)

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

**From the command line (headless — same command CI runs):**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

Discovery is driven by `.gutconfig.json` (`dirs` + `suffix: "_test.gd"`).
⚠️ Do **not** use the bare `-gdir=res://tests` form: GUT's default discovery
matches a `test_` *prefix*, but this project names test files with a `_test.gd`
*suffix* (`combat_damage_test.gd`), so `-gdir` alone finds **nothing**. The
config carries `prefix: ""` + `suffix: "_test.gd"` to match the convention.

**From the editor:** open the project in Godot 4.7, then use the **GUT** bottom
panel (the plugin is enabled in `project.godot`). Point it at `res://tests` and
run.

## GUT Install

GUT is **vendored** into `addons/gut/` (committed to the repo, v9.6.1) — there is
no separate install step. It is enabled in `project.godot` under `[editor_plugins]`.
To upgrade GUT later, replace `addons/gut/` with a newer release and update the
version noted here.

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Test class**: `extends GutTest`
- **Functions**: `test_[scenario]_[expected]()`
- **Example**: `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Test Authoring Rules (from coding-standards.md)

- **Determinism**: same result every run — no `randomize()`, no wall-clock
  assertions. Inject a `seed: int` / `RandomNumberGenerator` (per ADR-0006).
- **Isolation**: each test sets up and tears down its own state; no dependence on
  execution order.
- **No hardcoded data**: use factory functions/constants, not inline magic numbers
  (exception: boundary-value tests where the number IS the point).
- **Independence**: no external APIs, DBs, or file I/O — use dependency injection.

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate |
|---|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## Minimum Coverage

**80%** for game-logic systems (combat formulas, synergy calculations, part stat
aggregation) — per `technical-preferences.md`.

## CI

Tests run automatically on every push to `main` and on every pull request
(`.github/workflows/tests.yml`). A failed suite blocks merging. GUT's command-line
runner exits non-zero when any test fails, which fails the CI job.
