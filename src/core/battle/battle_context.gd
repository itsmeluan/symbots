## BattleContext — the per-battle mutable world, owned solely by [BattleController]
## (ADR-0007). A `RefCounted` created at BATTLE_INIT and dropped synchronously after the
## `battle_ended` cascade (WeakRef-verified teardown, Story 014). It holds NO back-
## reference to the controller and the frozen [Combatant] snapshots hold none to it —
## so clearing the controller's single `_ctx` reference frees the whole graph (no cycle).
##
## Everything here is battle-scoped: the three team [Combatant]s (each with independent
## runtime state — benched ones simply aren't ticked, Story 011), the single enemy, the
## per-round recomputed [member turn_order], the accreting [member fired_break_events]
## set (Story 014 dedup), and the reward metadata echoed into `battle_ended`.
class_name BattleContext
extends RefCounted

## Team Combatants (1–3), index = team slot. [member active_index] points at the fielded one.
var team: Array = []
var active_index: int = 0

## Frozen per-team-slot move pools (`Array` of MoveDef-or-null, length 4) and passive
## effect-id pools, aligned with [member team]. Held here (not on the frozen [Combatant]
## snapshot) so the move panel (Story 003) and ON_HIT riders (Story 013) read them
## without a mid-battle DB reach-in.
var move_pools: Array = []
var passive_pools: Array = []

## The enemy Combatant (Rule 8: no synergy/heat/energy participation).
var enemy: Combatant = null

# --- reward / identity metadata (echoed into the 8-field battle_ended) ---
var enemy_id: StringName = &""
var enemy_level: int = 1
var xp_value: int = 0
var completion_bonus_xp: int = 0
var is_first_boss_defeat: bool = false

## Encounter kind ([enum BattleController.EncounterType]) — gates flee (WILD only, Story 011).
var encounter_type: int = 0

# --- per-round / running battle state ---
var round_number: int = 0

## Living combatants in initiative order, recomputed every ROUND_START (Story 004).
var turn_order: Array = []

## Index into [member turn_order] of the actor whose turn is resolving.
var turn_cursor: int = 0

## Fired break events as a Dictionary-set (dedup, Story 014): 2×arm_broken + 1×head →
## 2 keys. VICTORY carries this whole set; DEFEAT/FLED carry {}.
var fired_break_events: Dictionary = {}

## Resolved outcome ([enum BattleController.Outcome]), set once at battle end.
var outcome: int = 0


## The currently-fielded team Combatant.
func active() -> Combatant:
	return team[active_index]


## Living team Combatants (structure > 0, not downed) — the switch/defeat candidates.
func living_team() -> Array:
	return team.filter(func(c: Combatant) -> bool: return c.is_alive())


## True when every team Symbot is downed (DEFEAT condition, Story 011/014).
func team_wiped() -> bool:
	return living_team().is_empty()


## Team ids of every fielded Symbot, for the `deployed_symbot_ids` payload (Story 014).
func deployed_symbot_ids() -> Array:
	return team.map(func(c: Combatant) -> int: return c.symbot_id)
