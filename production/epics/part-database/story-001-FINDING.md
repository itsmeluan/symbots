# FINDING — typed-dict `.tres` round-trip gate (Part-DB Story 001)

> **Verdict: ✅ PASS** — the `Dictionary[StringName, int]` `@export` round-trips
> through `.tres` with runtime types intact on the shipping toolchain.
> **Cite this finding from the other four content-DB epics** (Move / Passive /
> Consumable / Enemy) — the round-trip does NOT need re-verifying per-DB.

| Field | Value |
|-------|-------|
| **Date** | 2026-07-15 |
| **Engine** | Godot 4.7.stable.official.5b4e0cb0f (confirmed `--version`) |
| **Runner** | Headless GUT v9.6.1 — `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json` |
| **Result** | 7/7 tests, 27 asserts, 0 failures |
| **Test** | `tests/unit/part_database/tres_typed_dict_roundtrip_test.gd` |
| **Fixture** | `tests/unit/part_database/stat_bonuses_probe.{gd,tres}` (throwaway probe, not shipped schema) |

## What was proven

1. **StringName keys survive** — after `.tres` write + `ResourceLoader.load()`,
   every key is `TYPE_STRING_NAME` and is **NOT** `TYPE_STRING`. The feared
   silent String-coercion does **not** occur on 4.7. Verified on BOTH paths:
   a committed editor-format fixture (load-only) and a fresh in-code
   `ResourceSaver.save` → reload round-trip.
2. **int values survive** — every value reloads as `TYPE_INT`.
3. **Typed accessor is usable** — `func get_bonus(k: StringName) -> int` returns
   a real `int` usable in arithmetic without a cast (not `Variant`). Confirms
   4.7 GH-115763 does not bite: `get_bonus` is not an override.
4. **Edge cases hold** — missing key returns typed `0` (not `null`); an empty
   typed dict round-trips as an empty dict.

## On-disk serialization format (Godot 4.7)

```
stat_bonuses = Dictionary[StringName, int]({
&"armor": 5,
&"structure": 10
})
```

The typed annotation and `&`-prefixed StringName keys are both persisted — this
is what makes the load-side type preservation reliable.

## Consequence

- **ADR-0003 verification gate item (2) is CLOSED (PASS).** No ADR-0003
  amendment needed; the typed `Dictionary[StringName, int]` schema stands.
- **Story 002 (PartDef schema) is UNBLOCKED**, and with it all content authoring
  across the five content DBs.
- Fallback (untyped `Dictionary` + validator-enforced schema) is **not** needed.
