## BattleResolver — applies a resolved action to runtime state and fires the per-hit
## hook (ADR-0005 Rule 10 routing; ADR-0002 signal; Stories 009 + 010 + 012).
##
## A `RefCounted` owned by the battle orchestrator. It is the ONE place that:
##   - routes a DAMAGE move's [method DamagePipeline.resolve_move_damage] output to
##     STRUCTURE or a break-region and reduces [member Combatant.current_structure];
##   - emits [signal hit_resolved] EXACTLY once per DAMAGE-move resolution (never on
##     Repair / SCAN / Status moves or Burn ticks — those don't call the damage path);
##   - applies TBC-F7 enemy enrage POST-Stagger;
##   - restores structure for Repair (TBC-F6, capped, costs always paid) and consumes
##     the turn for a SCAN no-op;
##   - pays a move's Energy cost and the owning part's heat gain.
##
## [b]Part-Break boundary[/b]: the `break_bias → (structure_mult, break_mult)` table
## is OWNED by the Part-Break GDD, which isn't implemented yet. TBC owns PB-F1
## (STRUCTURE reduction) and PB-F3 (spillover) with the multiplier at IDENTITY (×1.0)
## until Part-Break lands; the full accrual chain (AC-TBC-INT-01a…f) is deferred. The
## spillover fraction ([member BalanceConfig.break_spillover]) IS ours and is applied.
class_name BattleResolver
extends RefCounted

## Sentinel routing target meaning "the body's shared Structure pool", as opposed to a
## break-region id (a real `StringName` like &"left_arm"). Distinguishable from any
## authored region id by the reserved dunder form.
const STRUCTURE := &"__structure__"

## Fired once per DAMAGE-move resolution, AFTER SYN-F4/MOVE-F1/Stagger, carrying the
## post-Stagger `move_damage` (pre-enrage, pre-routing-multiplier) and the CHOSEN
## [param sub_target] (STRUCTURE or a region id — never a hardcoded default). Part-Break
## subscribes to apply PB-F2/PB-F4 to the region's break-HP; Story 014 collects fired
## break events from it. Non-DAMAGE moves never emit.
signal hit_resolved(move: MoveDef, damage: int, target: Combatant, sub_target: StringName)

var _cfg: BalanceConfig
var _log: LogSink


func _init(cfg: BalanceConfig, log: LogSink) -> void:
	_cfg = cfg
	_log = log


## Resolve a DAMAGE move from [param attacker] to [param target], routed to
## [param sub_target] (STRUCTURE or an unbroken region id). Computes `move_damage` via
## the pipeline, emits [signal hit_resolved] ONCE with the post-Stagger value, then
## reduces structure:
##   - enemy attacker → TBC-F7 enrage on `move_damage` (POST-Stagger), then Structure;
##   - STRUCTURE hit → PB-F1 (structure_mult identity until Part-Break);
##   - region hit → PB-F3 spillover `floor(move_damage × BREAK_SPILLOVER)` (Part-Break
##     applies the region break-HP damage via the [signal hit_resolved] subscription).
##
## [param crit_mult] is the injected crit multiplier (1.0 default). [param enemy_broken_count]
## is the enemy's own broken-region count for enrage (STUBBED until Part-Break wires a
## real count). Returns the post-Stagger `move_damage` (the emitted payload value).
func resolve_damage_move(attacker: Combatant, target: Combatant, move: MoveDef,
		sub_target: StringName, crit_mult: float = 1.0, enemy_broken_count: int = 0) -> int:
	var move_damage: int = DamagePipeline.resolve_move_damage(
		attacker, target, move, _cfg, _log, crit_mult)
	# Emit BEFORE routing/enrage — the payload is the post-Stagger value (AC-TBC-34), and
	# `sub_target` carries the chosen routing, never a hardcoded STRUCTURE (Fixture B).
	hit_resolved.emit(move, move_damage, target, sub_target)
	var applied: int
	if attacker.is_enemy:
		applied = BattleFormulas.enrage_damage(move_damage, enemy_broken_count, _cfg)  # TBC-F7
	elif sub_target == STRUCTURE:
		applied = maxi(1, move_damage)  # PB-F1, structure_mult identity (Part-Break owns the mult)
	else:  # region hit — TBC's spillover share into the shared Structure pool (PB-F3)
		applied = maxi(1, StatMath.floor_eps(float(move_damage) * _cfg.break_spillover))
	target.current_structure = maxi(0, target.current_structure - applied)
	return move_damage


## Resolve a REPAIR move by [param user] (TBC-F6). Pays the move's Energy cost and the
## owning part's [param part_heat_generation] FIRST (costs always apply, even at full
## structure — overheal is discarded, not rejected), then restores
## `max(5, floor(effective_energy_power × 0.17 + 5))` structure capped at
## [member Combatant.max_structure]. Does NOT emit [signal hit_resolved] (DAMAGE-free).
## Returns the repair amount (before the cap discard).
func resolve_repair_move(user: Combatant, move: MoveDef, part_heat_generation: int) -> int:
	_pay_costs(user, move, part_heat_generation)
	var amount: int = BattleFormulas.repair_amount(user.effective_stat(&"energy_power"), _cfg)
	user.current_structure = mini(user.max_structure, user.current_structure + amount)
	return amount


## Resolve a SCAN move by [param user] (Rule 9 stub, EC-TBC-16): a turn-consuming
## no-op. Pays Energy + heat, consumes the action, applies NO damage and NO status,
## does not emit [signal hit_resolved], and never crashes. The reveal payload is Move
## DB's concern (AC-MDB-10) — out of scope here.
func resolve_scan_move(user: Combatant, move: MoveDef, part_heat_generation: int) -> void:
	_pay_costs(user, move, part_heat_generation)


## Pay a move's Energy cost and add the owning part's heat gain (Formula-5, Rule 5d).
## The single cost-application point shared by every action path. Energy/heat are
## [Combatant] runtime fields; the anti-stall Energy-brake is a Move-DB content rule
## (AC-TBC-38, deferred), not enforced here.
func _pay_costs(user: Combatant, move: MoveDef, part_heat_generation: int) -> void:
	user.current_energy -= move.energy_cost
	user.current_heat += part_heat_generation
