# Story 003: Damage-type routing + full routed composition

> **Epic**: Damage Formula
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/damage-formula.md`
**Requirement**: `TR-df-001`, `TR-df-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*
> ⚠ **TR gap**: the DF-1 **damage-type routing table** (Rule 1 — PHYSICAL→physical_power/armor, ENERGY→energy_power/resistance) has no dedicated TR-ID in `tr-registry.yaml`; it is part of Formula DF-1's variable-binding rule. Verified here by AC-DF-03 / AC-DF-04 (both GDD-blocking Logic ACs). Flag at `/story-readiness` if a `TR-df-007` is later added for the routing rule.

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: DF-1's expression is identical for both damage paths — only the variable binding differs by `damage_type`. This story adds the routed entry point that binds `A`/`D` from a combatant's `final_stat` (the ADR's `effective_stat` outputs), derives `T` via Story 002's `type_effectiveness`, and calls Story 001's `compute_damage` kernel — giving Turn-Based Combat the exact GDD call contract `(attacker_stats, skill_damage_type, skill_element, target_stats, target_core_element)` without any caller re-deriving the formula.

**Engine**: Godot 4.7 | **Risk**: LOW (pure composition of two existing pure functions + a `Dictionary.get` stat read)
**Engine Notes**: `damage_type` keys are `PartDef.DamageType` enum values (`PHYSICAL`/`ENERGY`); stat keys are the canonical StringNames `&"physical_power"`, `&"energy_power"`, `&"armor"`, `&"resistance"`. Read stats with `.get(key, 0)` so a missing stat degrades to 0 (which the kernel's `A=0`/`D=0` paths already handle correctly). Do **not** reach into `SymbotBuild` or the evaluator cache — take already-composed `final_stat` dictionaries (or `CombatantSnapshot.effective_stat` outputs) as parameters (`mid_battle_stat_recompute` forbidden).

**Control Manifest Rules (this layer — Core)**:
- Required: all effective-stat composition goes through `StatMath.effective_stat` / `CombatantSnapshot.effective_stat` — this function receives their outputs, it does not recompute stats; damage via the `compute_damage` pure static function — source: ADR-0005
- Forbidden: reimplementing SYN-F4 or the type chart here (`inline_stat_composition`); holding a reference into the live build/evaluator from this call (`mid_battle_stat_recompute`) — source: ADR-0005
- Guardrail: pure function — reads no runtime state, no RNG; `crit_mult` stays a passable pass-through parameter — source: ADR-0005/0006

---

## Acceptance Criteria

*From GDD `design/gdd/damage-formula.md`, scoped to routing + end-to-end composition:*

- [ ] **AC-DF-03** — a PHYSICAL skill binds `A = physical_power`, `D = armor`: attacker `{physical_power=53, energy_power=40}` vs target `{armor=30, resistance=20}`, `T=1.0` (neutral) → `final_damage = 33`. Cross-check: the wrong binding (`energy_power=40` vs `resistance=20`) gives 26 — must return 33, not 26
- [ ] **AC-DF-04** — an ENERGY skill binds `A = energy_power`, `D = resistance`: attacker `{physical_power=60, energy_power=40}` vs target `{armor=20, resistance=30}`, `T=1.0` → `final_damage = 22`. Cross-check: the wrong binding (`physical_power=60` vs `armor=20`) gives 45 — must return 22, not 45
- [ ] **AC-DF-05** — end-to-end element path: a VOLT skill (A=53, D=30) vs a THERMAL-Core target derives `T=1.5` and returns `final_damage = 50` (×1.0 would give 33)
- [ ] **AC-DF-06** — VOLT skill vs VOLT-Core target → `T=1.0` → `33` (floor=33 discriminates from round=34)
- [ ] **AC-DF-07** — VOLT skill vs KINETIC-Core target → `T=0.75` → `25` (the wrong post-floor order `33×0.75=24.75→24` must NOT be returned)
- [ ] The routed function is pure and reads no runtime state; `crit_mult` remains a passable pass-through defaulting to 1.0

---

## Implementation Notes

*Derived from ADR-0005 (routing rule) + GDD Formula DF-1 routing table:*

Add the routed entry point to `src/core/stats/damage_formula.gd`:

```gdscript
## Routed DF-1 — the Turn-Based Combat call contract. Binds A/D from already-
## composed final_stat dicts by damage_type, derives T via type_effectiveness,
## then defers to the compute_damage kernel. Pure: no runtime state, no RNG.
static func resolve(attacker_stat: Dictionary, damage_type: int, skill_element,
        target_stat: Dictionary, target_core_element, cfg: BalanceConfig,
        log: LogSink, crit_mult: float = 1.0) -> int:
    var a: int
    var d: int
    if damage_type == PartDef.DamageType.PHYSICAL:
        a = target_stat_get(attacker_stat, &"physical_power")
        d = target_stat_get(target_stat, &"armor")
    else:  # ENERGY
        a = target_stat_get(attacker_stat, &"energy_power")
        d = target_stat_get(target_stat, &"resistance")
    var t := type_effectiveness(skill_element, target_core_element, cfg)
    return compute_damage(a, d, t, cfg, log, crit_mult)
```

(Use `int(dict.get(key, 0))` inline rather than a helper if that reads cleaner in the surrounding style — the point is a null-safe stat read defaulting to 0.)

- Bind exactly per the DF-1 routing table — PHYSICAL → `physical_power` / `armor`; ENERGY → `energy_power` / `resistance`. AC-DF-03/04's cross-checks exist precisely to catch a swapped binding, so keep the two branches explicit and unambiguous.
- `T` is derived **only** via `type_effectiveness` (Story 002) — never inline the chart here.
- `damage_type` typed `int` (a `PartDef.DamageType` value) is safe — routing always receives a concrete type. `skill_element` / `target_core_element` stay untyped for the null fallback (delegated to `type_effectiveness`).
- This is the sole call site TBC needs: TBC passes `CombatantSnapshot.final_stat` (or the `effective_stat`-composed dict) for both sides plus the move's `damage_type` / `element` and the target's `core_element`. TBC does not re-derive `A`/`D`/`T`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: the `compute_damage` kernel math + `damage_floor` (this story calls it)
- **Story 002**: the `type_effectiveness` chart + `type_chart` config (this story calls it)
- Reading `core_element` off an `EnemyDef` — Enemy DB epic exposes that field (GDD hard constraint DF3); this function receives it as a parameter
- MOVE-F1 power-tier scaling that multiplies DF-1 output — Move DB (already shipped) / TBC pipeline; DF-1 is the input to it, not the composer of it

---

## QA Test Cases

*Authored inline (lean mode — no qa-plan exists). Automated unit specs.*

- **AC-DF-03** (PHYSICAL binding):
  - Given: attacker `{physical_power:53, energy_power:40}`, target `{armor:30, resistance:20}`, `cfg`, spy
  - When: `resolve(attacker, PartDef.DamageType.PHYSICAL, null, target, null, cfg, spy)` (null elements → T=1.0)
  - Then: `assert_eq(result, 33)`
  - Edge cases: assert the wrong-binding value 26 is NOT returned (guards a physical/energy swap)
- **AC-DF-04** (ENERGY binding):
  - When: attacker `{physical_power:60, energy_power:40}` vs `{armor:20, resistance:30}`, ENERGY, null elements → `assert_eq(result, 22)`
  - Edge cases: assert the wrong-binding value 45 is NOT returned
- **AC-DF-05 / 06 / 07** (element end-to-end, A=53, D=30 via stats):
  - Given: attacker `{energy_power:53}` (ENERGY skill), target `{resistance:30, ...}`, VOLT skill element
  - When: `resolve(..., VOLT, target, THERMAL, cfg, spy)` → `assert_eq(result, 50)` (05); `core=VOLT` → `33` (06); `core=KINETIC` → `25` (07)
  - Edge cases: 06 is floor-vs-round discriminating (33 not 34); 07 catches wrong-order (25 not 24)
- **purity / crit pass-through**:
  - Call `resolve` twice with identical args → identical result (no state); pass `crit_mult=2.0` on the (53,30,VOLT,THERMAL) case → 101 (proves pass-through to the kernel)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage-formula/damage_routing_test.gd` — must exist and pass (routing cross-checks + element end-to-end + crit pass-through).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`compute_damage` kernel), Story 002 (`type_effectiveness` lookup)
- Unlocks: Turn-Based Combat damage resolution (consumes `DamageFormula.resolve` as its per-skill-use call); closes the DF-1→MOVE-F1→TBC-F5 pipeline entry point (AC-MDB-05 full-pipeline verification once TBC-F5 exists)
