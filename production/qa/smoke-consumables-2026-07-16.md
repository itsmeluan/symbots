# Smoke Check — Consumable Content (Story 008)

> **Epic**: Consumable Database · **Story**: 008 — Author 8 MVP consumables + catalog
> **Date**: 2026-07-16
> **Type**: Config/Data (ADVISORY gate)
> **Engine**: Godot 4.7 · GUT 9.7.1

## Scope

Verify the eight authored MVP consumables and the `ConsumableCatalog` manifest
load from disk and pass the full `ContentValidator` consumable family clean
(zero errors AND zero warnings) at boot.

## Artifacts

| Artifact | Path |
|---|---|
| Weld Patch | `assets/data/consumables/weld_patch.tres` |
| Repair Kit | `assets/data/consumables/repair_kit.tres` |
| Field Forge | `assets/data/consumables/field_forge.tres` |
| Coolant Flush | `assets/data/consumables/coolant_flush.tres` |
| Power Cell | `assets/data/consumables/power_cell.tres` |
| Salvage Beacon | `assets/data/consumables/salvage_beacon.tres` |
| Signal Jammer | `assets/data/consumables/signal_jammer.tres` |
| Scrap Lure | `assets/data/consumables/scrap_lure.tres` |
| Catalog manifest | `assets/data/catalogs/consumable_catalog.tres` |
| Content gate test | `tests/unit/content/consumable_catalog_ci_test.gd` |

## Authored contract values

| Consumable | rarity | effect_type | effect_params | context | target | stack | buy | sell |
|---|---|---|---|---|---|---|---|---|
| `weld_patch` | COMMON | RESTORE_STRUCTURE | amount 25 | BOTH | LIVING_TEAM_MEMBER | 20 | 12 | 2 |
| `repair_kit` | RARE | RESTORE_STRUCTURE | amount 50 | BOTH | LIVING_TEAM_MEMBER | 10 | 36 | 8 |
| `field_forge` | PROTOTYPE | RESTORE_STRUCTURE | amount 120 | BOTH | LIVING_TEAM_MEMBER | 5 | 75 | 15 |
| `coolant_flush` | COMMON | REDUCE_HEAT | amount 50 | BOTH | LIVING_TEAM_MEMBER | 20 | 12 | 2 |
| `power_cell` | COMMON | RESTORE_ENERGY | amount 25 | BOTH | LIVING_TEAM_MEMBER | 20 | 12 | 2 |
| `salvage_beacon` | RARE | BOOST_DROP | multiplier 2.0 | BATTLE | CURRENT_BATTLE | 10 | 48 | 10 |
| `signal_jammer` | RARE | MODIFY_ENCOUNTER_RATE | rate_multiplier 0.1, duration_steps 20 | WORLD | OVERWORLD | 10 | 45 | 10 |
| `scrap_lure` | COMMON | MODIFY_ENCOUNTER_RATE | rate_multiplier 2.5, duration_steps 15 | WORLD | OVERWORLD | 20 | 15 | 3 |

Every item's `buy_price` strictly exceeds its `sell_price` (economy invariant),
each `effect_type`'s `(use_context, target)` pairing matches its designed
coherence, and all five effect families are represented — so the schema, economy,
coherence-advisory, and family-coverage checks all stay silent.

## Result — PASS

Command:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

- **452 / 452 tests passing · 3467 asserts · 0 failing.**
- `consumable_catalog_ci_test.gd`: catalog loads all 8 consumables from disk
  (fresh `CACHE_MODE_REPLACE` parse); full `ContentValidator` returns
  `ok == true` with **zero errors and zero warnings**; zero diagnostics through
  either the LogSink error or warn channel.
- Catalog entry count (8) matches the `.tres` file count on disk; all ids unique.
- All 5 effect families present; rarity spread covers COMMON / RARE / PROTOTYPE.
- Typed enum + untyped `effect_params` `.tres` round-trip verified on real content.

## Notes

- Runtime application of these effects (assigning the healed value to a live
  Symbot and consuming the turn) is owned by the **TBC erratum AC-CD-20/21** and
  the **Encounter Zone erratum AC-CD-22** — **not** verified here. The pure
  formulas + state models they will call are unit-covered (Stories 003–006).
- No BOSS_GRADE consumable ships in the MVP set (the fourth rarity tier is
  reserved); the coverage advisory keys on effect family, not rarity, so this is
  intentional and produces no warning.
