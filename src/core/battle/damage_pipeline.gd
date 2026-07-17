## DamagePipeline — the DAMAGE-move number, composed in ONE authoritative order
## (ADR-0005 Rule 10; TBC-F5; Story 008). Pure, stateless, static-only.
##
## It stitches four already-owned pieces and adds no math of its own:
##   1. SYN-F4  — effective A/D via [method Combatant.damage_stat_block]
##                (`max(0, base + synergy + aura)`, the single composition point).
##   2. DF-1    — [method DamageFormula.resolve] binds A/D by `damage_type`, derives T.
##   3. MOVE-F1 — [method MovePowerFormula.move_damage] applies the power-tier multiplier.
##   4. TBC-F5  — [method BattleFormulas.apply_stagger] reduces the attacker's OWN
##                outgoing damage if it is Staggered (Kinetic status).
##
## The output is the pre-ROUTING, pre-ENRAGE `move_damage` (Story 008's contract): it
## is what Story 009 then routes to STRUCTURE-or-region and — for the enemy side —
## feeds into TBC-F7 enrage. Crit is an INJECTED multiplier (default 1.0); the seed is
## vended by the orchestrator, never rolled here (ADR-0006 `rng_service_in_formula_code`).
class_name DamagePipeline
extends RefCounted

## Compute a DAMAGE move's post-Stagger damage from [param attacker] to [param target].
##
## SYN-F4 is applied through [method Combatant.damage_stat_block] on BOTH sides (the
## attacker carries synergy+aura; an enemy defender carries neither — Rule 8), so the
## AC-TBC-22 traps are structurally impossible: the pipeline never reads a base stat
## directly, and the attacker's synergy can never leak onto the enemy's defense.
##
## [param crit_mult] defaults to 1.0 (no crit); when a crit is rolled the orchestrator
## passes the drawn multiplier in. Returns the integer `move_damage` (≥ DAMAGE_FLOOR),
## post-Stagger, BEFORE sub-target routing and enemy enrage (both Story 009).
static func resolve_move_damage(attacker: Combatant, target: Combatant, move: MoveDef,
		cfg: BalanceConfig, log: LogSink, crit_mult: float = 1.0) -> int:
	var atk_block: Dictionary = attacker.damage_stat_block()   # SYN-F4 both sides
	var tgt_block: Dictionary = target.damage_stat_block()
	var raw: int = DamageFormula.resolve(                       # DF-1 (binds A/D + T)
		atk_block, move.damage_type, move.element,
		tgt_block, target.core_element, cfg, log, crit_mult)
	var powered: int = MovePowerFormula.move_damage(raw, move.power_tier, cfg)  # MOVE-F1
	return BattleFormulas.apply_stagger(powered, attacker.statuses.stagger_percentage(), cfg)  # TBC-F5
