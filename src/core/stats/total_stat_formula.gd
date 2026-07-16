## TotalStatFormula — GDD Formula 1, the total Symbot stat composition.
##
## Pure, stateless, static-only; the composition point of the ADR-0005 stat
## pipeline where per-part UPGRADED values (Formula 2 / 2b outputs, Story 004) are
## summed and the equipped Chassis part's archetype modifier is applied, producing
## the integer stat the battle snapshot ([CombatantSnapshot]) freezes at
## BATTLE_INIT. It consumes already-upgraded values — it must NEVER re-derive from
## raw [member PartDef.stat_bonuses] (the pipeline composition is mandatory; see
## the GDD Formula Pipeline and AC-05 (b) discriminator).
##
## Content defs are frozen shared instances: the chassis modifier table is read
## from the injected [BalanceConfig] (`runtime_content_mutation` is forbidden —
## nothing here mutates a def or the config).
class_name TotalStatFormula
extends RefCounted

## Multiplier used for a stat absent from the archetype's modifier row (or for an
## archetype absent from the table entirely) — the `.get(S, 1.0)` neutral element.
const NEUTRAL_MODIFIER := 1.0


## Formula 1: `max(0, floor(sum(upgraded_value[S]) × chassis_modifier.get(S, 1.0) + ε))`.
##
## [param stat_key] is the canonical stat name (e.g. &"structure"). [param
## upgraded_values] are the per-part Formula-2/2b outputs for THAT stat across the
## equipped parts — pass the composed values, not raw `stat_bonuses`. [param
## chassis_archetype] is the equipped Chassis part's [enum PartDef.ChassisArchetype];
## its per-stat multiplier is looked up from [param cfg]. The outer `max(0, …)` is
## load-bearing — `floor()` alone floors toward −∞, so a chassis penalty or an
## still-active Prototype drawback could otherwise yield a negative final stat.
static func compute_final_stat(
		stat_key: StringName,
		upgraded_values: Array[int],
		chassis_archetype: PartDef.ChassisArchetype,
		cfg: BalanceConfig) -> int:
	var total := 0
	for value in upgraded_values:
		total += value
	var modifier := _modifier_for(stat_key, chassis_archetype, cfg)
	return maxi(0, StatMath.floor_eps(float(total) * modifier))


## Per-stat chassis multiplier for [param stat_key] under [param archetype], read
## from the sparse [member BalanceConfig.chassis_modifiers] table. Absent
## archetype or absent stat → [constant NEUTRAL_MODIFIER] (×1.0).
static func _modifier_for(
		stat_key: StringName,
		archetype: PartDef.ChassisArchetype,
		cfg: BalanceConfig) -> float:
	var row: Dictionary = cfg.chassis_modifiers.get(archetype, {})
	return float(row.get(stat_key, NEUTRAL_MODIFIER))
