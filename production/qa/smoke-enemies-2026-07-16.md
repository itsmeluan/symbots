# Smoke Check — Enemy Database MVP Roster (Story 010)

**Date**: 2026-07-16
**Story**: `production/epics/enemy-database/story-010-mvp-roster-content-authoring.md`
**Type**: Config/Data
**Engine**: Godot 4.7.stable.official
**Result**: ✅ PASS

---

## What was authored

10 MVP `EnemyDef` `.tres` under `assets/data/enemies/`, plus the manifest
`assets/data/catalogs/enemy_catalog.tres`.

Additionally, a prerequisite Part-DB add — **`ironclad_aegis_frame`** (RARE / CHASSIS /
Thermal / Ironclad, passive `pass_ablative`, `chassis_cracked` ×3.0) — so the two
Thermal wilds drop a native Thermal Rare instead of scavenging Kinetic/Volt Rares.
Part catalog is now 16 entries (Part CI gate updated + green).

| # | Enemy | Class | Elem | S | A/R | Lvl | XP | +Bonus | Regions (break_event → break_hp) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Rustcrawler | WILD | Kinetic | 85 | 20/18 | 2 | 55 | 0 | arm→29, head→18 |
| 2 | Scrapjaw Skirmisher | WILD | Kinetic | 78 | 16/16 | 2 | 55 | 0 | weapon→23, leg→15 |
| 3 | Husk Walker | WILD | null | 88 | 18/18 | 3 | 65 | 0 | leg→22, head→15 |
| 4 | Dune Prowler | WILD | Kinetic | 72 | 18/15 | 2 | 55 | 0 | arm→23, core→15 |
| 5 | Volt Sentinel | WILD | Volt | 120 | 28/32 | 3 | 65 | 0 | head→28, core→36 |
| 6 | Arc Drone | WILD | Volt | 105 | 22/30 | 3 | 65 | 0 | core→29, weapon→36 |
| 7 | Ironclad Sentry | WILD | Thermal | 140 | 35/28 | 4 | 75 | 0 | chassis→56, arm→42 |
| 8 | Slag Hauler | WILD | Thermal | 150 | 34/30 | 4 | 75 | 0 | chassis→67, weapon→45 |
| 9 | Rust Tyrant | BOSS | Kinetic | 440 | 35/30 | 5 | 170 | 310 | arm→154, head→110, core→176 |
| 10 | Storm Warden | BOSS | Volt | 450 | 30/38 | 6 | 190 | 180 | weapon→180, core→135, head→99 |

- **8 WILD + 2 BOSS** per the GDD density guideline ✓
- **All 3 MVP elements** (Volt/Thermal/Kinetic) + **1 null-element** (Husk Walker, the NULL_ELEMENT_MAX_WILD = 1 cap) ✓
- **Both bosses gate a distinct BOSS_GRADE exclusive**: Rust Tyrant → `scrapjaw_rustcrawler_claw` (arm), Storm Warden → `boltwell_storm_lance` (weapon) ✓

## Smoke checks performed

| Check | Method | Result |
|---|---|---|
| Enemy catalog loads from disk headless | `ResourceLoader.load(..., CACHE_MODE_REPLACE)` | ✅ EnemyCatalog, 10 entries |
| Full enemy validator green (schema/stat/break-region/progression/density) | `ContentValidator.validate` | ✅ `ok == true`, 0 errors |
| Loot family active (Part-DB seam injected) | `set_part_lookup` over real `part_catalog.tres` index | ✅ connectivity + AC-ED-18/19 pass |
| Every `break_hp` == EDB-1 derived | `derive_break_hp(structure, fraction)` cross-check (python3 + validator) | ✅ all 24 regions match |
| Every `xp_value` == CP-F4 derived | `(35 + level×10) × role_mult` (WILD=1, BOSS=2) | ✅ all 10 match |
| Every `loot_pool` id resolves in Part DB | injected lookup returns non-null for all | ✅ all resolve |
| WILD carry no boss-grade parts | validator AC-ED-09/17 | ✅ none |
| `completion_bonus_xp` zero on WILD, positive on BOSS | authored values | ✅ 8×0, 310 / 180 |
| Catalog completeness | `.tres` file count == `entries.size()` | ✅ 10 == 10 |
| TTK within class bands (AC-ED-14) | `floor(A_cal²/(A_cal+D))` both channels, `ceil(S/dmg)` | ✅ all in band (see below) |

## TTK band verification (AC-ED-14, both armor + resistance channels)

- **WILD-early** (structure <90, A_cal=35, band 2–4): Rustcrawler 4/4, Skirmisher 4/4, Husk Walker 4/4, Dune Prowler 4/3 — all in [2,4] ✓
- **WILD-mid** (structure ≥90, A_cal=53, band 3–5): Volt Sentinel 4/4, Arc Drone 3/4, Ironclad Sentry 5/5, Slag Hauler 5/5 — all in [3,5] ✓
- **BOSS** (A_cal=53, band 12–18): Rust Tyrant 15/14, Storm Warden 14/15 — all in [12,18] ✓

## Automated evidence

- **`tests/unit/content/enemy_catalog_ci_test.gd`** — 8 tests, the blocking CI gate.
  Loads the real roster headless, injects the Part-DB seam, mounts every enemy
  validator family, asserts `ok == true` + zero errors + zero warnings +
  completeness + roster structure (8W/2B, element coverage).
- **Full suite**: **631/631 passing, 3853 asserts** (Godot 4.7 headless GUT);
  count rose +8 from the new file (verified — no silent skip).
- Auto-discovered by `.gutconfig.json`; runs in CI as a blocking gate.

## Advisory warnings

**None.** The roster is designed to land clean — all TTK bands, pool-size bands
(WILD 2–4, BOSS 4–6), floor-loot (AC-ED-18), and min-break-gated (AC-ED-19) satisfied.
The CI test's `ALLOWED_WARNING_CODES` set is empty; any future warning is a regression.

## Notes / flags for follow-up

- **Enemy skill IDs are forward-references.** No `move_catalog` is authored yet, and
  the enemy validator checks `skills` **count-only** (≥1 blocking, >4 advisory) — there
  is no referential check wiring enemy skills to a Move DB. The 14 distinct skill IDs
  used across the roster (e.g. `skill_arc_pulse`, `skill_crusher_claw`, `skill_storm_lance`)
  are the contract the Move DB content pass owes, mirroring the Part-DB CI manifest.
  The story AC's "resolving in the Move DB (Complete)" is only true at the *code/schema*
  level — no move content exists to resolve against, and none is required for this gate.
- **`ai_profile` tags** ({AGGRESSIVE, TACTICAL, OPPORTUNIST}) are validated as non-empty
  StringNames against a default accept-all seam; no AI profile registry consumes them yet
  (Enemy AI is a DEFERRED integration).
- **DEFERRED consumers** (Encounter Zone / TBC / Drop / Enemy AI) do not read this roster
  yet — a full integration smoke (mounting enemy + part catalogs together in the live boot
  path with the seam wired) belongs to those epics.
