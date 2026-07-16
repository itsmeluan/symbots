# Smoke Check — Part Database MVP Content (Story 010)

**Date**: 2026-07-15
**Story**: `production/epics/part-database/story-010-author-content-wire-ci.md`
**Type**: Config/Data
**Engine**: Godot 4.7.stable.official (`5b4e0cb0f`)
**Result**: ✅ PASS

---

## What was authored

14 MVP `PartDef` `.tres` under `assets/data/parts/`, plus the manifest
`assets/data/catalogs/part_catalog.tres` and `assets/data/balance_config.tres`.

| Slot | Common (starter) | Rare | Boss | Prototype |
|---|---|---|---|---|
| Core | scrapjaw_scrap_core | boltwell_surge_core | — | — |
| Chassis | ironclad_bulwark_frame | — | — | — |
| Chipset | boltwell_logic_chip | — | — | — |
| Energy Cell | boltwell_cell_mk1 | — | — | — |
| Head | wild_optic_sensor | boltwell_targeting_array | — | — |
| Arms | scrapjaw_servo_arm | scrapjaw_reinforced_servo_arm | scrapjaw_rustcrawler_claw | — |
| Legs | wild_tread_legs | — | — | — |
| Weapon | scrapjaw_bash_hammer | boltwell_arc_blaster | — | wild_overdrive_cannon |

- **All 8 slots** have a Common starter ✓
- **All 4 rarities** represented ✓
- **`servo_arm_family`** variant chain spans Common → Rare → Boss (3 rarities) ✓
- **All 3 MVP elements** (Volt/Thermal/Kinetic) and **3 manufacturers + wild** present ✓

## Smoke checks performed

| Check | Method | Result |
|---|---|---|
| Catalog loads from disk headless | `ResourceLoader.load(..., CACHE_MODE_REPLACE)` | ✅ PartCatalog, 14 entries |
| BalanceConfig loads from disk headless | same | ✅ BalanceConfig |
| Nested-dict `.tres` round-trip on REAL content | disk reparse + `.get(&"key")` reads inside validator | ✅ StringName keys resolve (budget family passes) |
| Full validator green (007+008+009 families) | `ContentValidator.validate` w/ balance + refs mounted | ✅ `ok == true`, 0 errors |
| Catalog completeness | `.tres` file count == `entries.size()` | ✅ 14 == 14 |
| No `DirAccess` in load path | grep `src/core/content/` | ✅ none (test-only usage) |

## Automated evidence

- **`tests/unit/content/part_catalog_ci_test.gd`** — 9 tests, the blocking CI gate.
  Loads real content headless, mounts all three validator families, asserts
  `ok == true` + completeness + roster structure.
- **Full suite**: **153/153 passing, 410 asserts** (Godot 4.7 headless GUT).
- Auto-discovered by `.gutconfig.json` (`include_subdirs` over `res://tests/unit`);
  runs in `.github/workflows/tests.yml` as a blocking gate — no workflow edit needed.

## Advisory warnings (expected, non-blocking)

6 AC-23 coverage warnings — slots/subgroups without a Common+Rare pair in the
MVP-minimum set (`content_primary_group_no_rare` ×5: Chassis, Chipset, Energy Cell,
Legs, Weapon-physical; `content_primary_group_no_common` ×1: Weapon-energy). These
are advisory by design — they resolve when the later content pass adds variants.

## Notes / flags for follow-up

- **CI Godot version stale**: `.github/workflows/tests.yml` pins `4.6.0`; project is
  on 4.7. Part of the known 4.6→4.7 sweep — flag, not a Story 010 change.
- **Forward-reference IDs**: 5 skill IDs + 3 passive IDs are declared as the CI
  manifest the future Move DB / Passive DB epics must provide.
- **Higher-rarity parts only in skill-native slots** (Core/Head/Arms/Weapon): a
  deliberate sidestep of the GDD Rule 2 ↔ Rule 8 contradiction (see tech-debt register).
