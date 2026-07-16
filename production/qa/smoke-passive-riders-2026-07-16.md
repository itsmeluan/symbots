# Smoke Check — Passive Rider Content (Story 007)

> **Epic**: Passive Database · **Story**: 007 — Three MVP status riders content
> **Date**: 2026-07-16
> **Type**: Config/Data (ADVISORY gate)
> **Engine**: Godot 4.7 · GUT 9.7.1

## Scope

Verify the three authored MVP status riders and the `PassiveCatalog` manifest
load from disk and pass the full `ContentValidator` clean at boot.

## Artifacts

| Artifact | Path |
|---|---|
| Rider 1 | `assets/data/passives/volt_shock_on_hit.tres` |
| Rider 2 | `assets/data/passives/thermal_burn_on_weapon.tres` |
| Rider 3 | `assets/data/passives/kinetic_stagger_on_hit.tres` |
| Catalog manifest | `assets/data/catalogs/passive_catalog.tres` |
| Content gate test | `tests/unit/content/passive_riders_content_test.gd` |

## Authored contract values

| Rider | behavior_class | trigger | scope | stacking | status_id | duration |
|---|---|---|---|---|---|---|
| `volt_shock_on_hit` | STATUS_RIDER | ON_HIT | ANY_DAMAGE | UNIQUE_PER_TRIGGER | `shock` | 1 |
| `thermal_burn_on_weapon` | STATUS_RIDER | ON_HIT | WEAPON_ONLY | UNIQUE_PER_TRIGGER | `burn` | 2 |
| `kinetic_stagger_on_hit` | STATUS_RIDER | ON_HIT | ANY_DAMAGE | UNIQUE_PER_TRIGGER | `stagger` | 1 |

All three carry `passive_class = STATUS_RIDER` and are deliberately flat (no
investment-scaling — that is the separate OQ-PDB-1 charter). `stacking_policy`
equals the `STATUS_RIDER` default (`UNIQUE_PER_TRIGGER`), so Story 004's
mismatch check stays silent.

## Result — PASS

Command:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

- **370 / 370 tests passing · 3241 asserts · 0 failing.**
- `passive_riders_content_test.gd`: catalog loads 3 riders from disk (fresh
  `CACHE_MODE_REPLACE` parse); full `ContentValidator` returns `ok == true` with
  **zero errors** across every Passive family (Stories 004 + 005); zero
  diagnostics through the LogSink channel.
- All three rider ids resolve in the `passive_ids` membership set
  (`ContentCatalogs.passive_ids_from` — Story 006 seam).
- Catalog entry count (3) matches the `.tres` file count on disk; all ids unique.
- Typed-enum + `behavior_params` `.tres` round-trip verified on real content.

## Notes

- Runtime firing of these riders (status application, duration, scope gating) is
  owned by the TBC Rule 13 executor epic — **not** verified here.
- The shipped **Part** catalog still forward-references placeholder passive ids
  (`pass_overclock` / `pass_rend` / `pass_meltdown`) via its own explicit CI
  manifest; wiring parts to these real riders is a later integration concern, not
  Story 007.
