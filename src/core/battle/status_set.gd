## StatusSet — the active statuses on ONE combatant, with the per-turn lifecycle
## (ADR-0007 Rule 11; EC-TBC-07/09/13/14).
##
## A `RefCounted` owned by a combatant's runtime record in `BattleContext`. Holds at
## most one instance per [enum StatusInstance.Type] (no stacking — reapply refreshes,
## Rule 11), keyed by type so the three statuses coexist independently.
##
## Lifecycle (driven by the turn phases, Story 005):
##   apply(...)        — apply or newest-wins refresh (any phase / on hit).
##   burn_tick()       — turn-START: the Burn DoT this turn (bypasses DF-1), or 0.
##   decrement_turn()  — turn-END: every duration −1, expired removed.
##   clear()           — on DOWNED (EC-TBC-14): remove everything.
##
## Benched combatants have no turns, so a benched StatusSet is simply never ticked or
## decremented — its statuses freeze by construction (EC-TBC-13, Story 011). This
## class holds no "benched" flag; the caller just doesn't call the lifecycle hooks.
class_name StatusSet
extends RefCounted

# type (int) → StatusInstance. At most one per type.
var _by_type: Dictionary = {}


## Apply [param status_type] from an applier whose PRE-synergy processing is
## [param applier_processing], for [param full_duration] of the afflicted's turns.
## If the same type is already active, refresh it newest-wins (EC-TBC-07); otherwise
## add a fresh instance. Different types are untouched (AC-TBC-24). A 0/invalid type
## is ignored (no status). Zero-potency statuses still apply — legal no-ops (EC-TBC-09).
func apply(status_type: StatusInstance.Type, applier_processing: int,
		full_duration: int, cfg: BalanceConfig) -> void:
	if status_type == 0:
		return
	if _by_type.has(status_type):
		_by_type[status_type].refresh(applier_processing, full_duration, cfg)
	else:
		_by_type[status_type] = StatusInstance.new(
			status_type, applier_processing, full_duration, cfg)


## True if a status of [param status_type] is currently active.
func has(status_type: StatusInstance.Type) -> bool:
	return _by_type.has(status_type)


## The active [StatusInstance] of [param status_type], or null if absent.
func get_status(status_type: StatusInstance.Type) -> StatusInstance:
	return _by_type.get(status_type, null)


## SHOCK mobility penalty currently in effect (TBC-F4 magnitude), or 0 if not Shocked.
## Consumed by initiative (Story 004) — never re-derived there.
func shock_penalty() -> int:
	var s: StatusInstance = _by_type.get(StatusInstance.Type.SHOCK, null)
	return s.magnitude if s != null else 0


## STAGGER percentage currently in effect (TBC-F5 step-1 magnitude), or 0. Consumed by
## the damage pipeline (Story 008) as `stagger_pct` — never re-derived there.
func stagger_percentage() -> int:
	var s: StatusInstance = _by_type.get(StatusInstance.Type.STAGGER, null)
	return s.magnitude if s != null else 0


## Turn-START Burn DoT (TBC-F3): the structure loss to apply this turn, or 0 if not
## Burning. BYPASSES DF-1 — this is the raw magnitude; the caller subtracts it from
## `current_structure` directly (no Armor/Resistance/type, AC-TBC-23). Not reduced by
## Stagger (DoT is not a move).
func burn_tick() -> int:
	var s: StatusInstance = _by_type.get(StatusInstance.Type.BURN, null)
	return s.magnitude if s != null else 0


## Turn-END: decrement every active status by one turn and remove any that reach 0
## (AC-TBC-36). Modifiers stop applying the moment a status is removed.
func decrement_turn() -> void:
	var expired: Array = []
	for t in _by_type:
		var s: StatusInstance = _by_type[t]
		s.duration -= 1
		if s.duration <= 0:
			expired.append(t)
	for t in expired:
		_by_type.erase(t)


## Remove all statuses (EC-TBC-14 — a DOWNED combatant is cleansed; a future revive
## would start clean).
func clear() -> void:
	_by_type.clear()


## Number of active statuses (test/introspection helper).
func count() -> int:
	return _by_type.size()
