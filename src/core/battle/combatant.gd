## Combatant — one battler's FROZEN snapshot + MUTABLE runtime state (ADR-0005 /
## ADR-0007). A `RefCounted` owned by [BattleContext]; discarded at teardown.
##
## The snapshot half is captured ONCE at BATTLE_INIT and never recomputed
## (`mid_battle_stat_recompute` forbidden): the SA-F1/CP-F3 [member final_stat], the
## frozen [member synergy_delta] (Synergy `cached_bonus_block["stat_delta"]` via
## `evaluate_silent`), the frozen [member passive_aura] (Story 013 PERSISTENT auras),
## and the [member core_element] for type effectiveness. Effective stats read through
## [method effective_stat] — the single SYN-F4 point ([StatMath.effective_stat]).
##
## The runtime half is the ONLY mutable battle state: [member current_structure],
## [member current_energy], [member current_heat], the [member statuses] set, and the
## [member is_downed] flag. Each of the three team Symbots tracks these INDEPENDENTLY
## — a benched Combatant's runtime simply isn't advanced, so it freezes (Story 011).
##
## Enemies use the same class ([member is_enemy] true): their `stats` dict is the
## [member final_stat] (Enemy DB), [member synergy_delta] is empty (Rule 8), and
## lookups tolerate absent keys via `.get(key, 0)` (EC-TBC-15).
class_name Combatant
extends RefCounted

## Player-team identity (0-based team slot) or enemy marker. Team Symbots 0/1/2;
## enemies carry their own id in [member enemy_id].
var slot_index: int = 0

## True for the enemy side (Rule 8: no synergy, enrage pipeline applies to its output).
var is_enemy: bool = false

## Enemy content id (for the `battle_ended` payload). &"" for player Symbots.
var enemy_id: StringName = &""

## The player Symbot's team id (for `deployed_symbot_ids`). -1 for enemies.
var symbot_id: int = -1

# --- Frozen snapshot (captured at BATTLE_INIT; never recomputed) ---

## SA-F1 + CP-F3 `final_stat` (player) or Enemy DB `stats` (enemy). All 11 canonical keys.
var final_stat: Dictionary = {}

## Frozen synergy `stat_delta` (empty for enemies — Rule 8).
var synergy_delta: Dictionary = {}

## Frozen PERSISTENT-passive stat aura (Story 013; empty in MVP).
var passive_aura: Dictionary = {}

## The Core part's [enum PartDef.Element], for DF-1 type effectiveness (null → neutral).
var core_element = null

# --- Mutable runtime state (the only mid-battle mutation) ---

var max_structure: int = 0
var current_structure: int = 0
var max_energy_capacity: int = 0
var current_energy: int = 0
var current_heat: int = 0
var is_downed: bool = false

## True for the single turn after heat hit the overheat threshold (Story 006): the
## turn-start anatomy resets heat flat, skips the action phase, then clears this flag.
var is_overheated: bool = false

## Active statuses on THIS combatant (frozen while benched — the caller stops ticking).
var statuses: StatusSet = null


func _init() -> void:
	statuses = StatusSet.new()


## Build a player-team Combatant from its frozen snapshot. [param final_stat] is the
## SA-F1/CP-F3 output; [param synergy_delta]/[param passive_aura] the frozen blocks;
## structure/energy pools seed from the EFFECTIVE stats (SYN-F4) at full. Heat starts 0.
static func make_player(slot: int, team_symbot_id: int, final_stat: Dictionary,
		synergy_delta: Dictionary, passive_aura: Dictionary, core_element) -> Combatant:
	var c := Combatant.new()
	c.slot_index = slot
	c.symbot_id = team_symbot_id
	c.is_enemy = false
	c.final_stat = final_stat
	c.synergy_delta = synergy_delta
	c.passive_aura = passive_aura
	c.core_element = core_element
	c.max_structure = c.effective_stat(&"structure")
	c.current_structure = c.max_structure
	c.max_energy_capacity = c.effective_stat(&"energy_capacity")
	c.current_energy = c.max_energy_capacity
	c.current_heat = 0
	return c


## Build the enemy Combatant from its Enemy DB stats (Rule 8: no synergy/aura).
## Absent stat keys resolve to 0 via [method effective_stat]'s `.get` (EC-TBC-15).
static func make_enemy(enemy_content_id: StringName, stats: Dictionary,
		core_element) -> Combatant:
	var c := Combatant.new()
	c.is_enemy = true
	c.enemy_id = enemy_content_id
	c.symbot_id = -1
	c.final_stat = stats
	c.synergy_delta = {}
	c.passive_aura = {}
	c.core_element = core_element
	c.max_structure = c.effective_stat(&"structure")
	c.current_structure = c.max_structure
	c.max_energy_capacity = c.effective_stat(&"energy_capacity")
	c.current_energy = c.max_energy_capacity
	c.current_heat = 0
	return c


## SYN-F4 effective value of [param key] — `max(0, base + synergy + aura)`. The single
## composition point; the damage pipeline / repair / status potency all read through it
## (or its pre-synergy sibling [method snapshot_stat]), never re-summing inline.
func effective_stat(key: StringName) -> int:
	return StatMath.effective_stat(final_stat, synergy_delta, passive_aura, key)


## The PRE-synergy base stat (status potency snapshot contract, GDD ratified):
## `final_stat.get(key, 0)`, NOT the SYN-F4 value. Used to snapshot status magnitudes.
func snapshot_stat(key: StringName) -> int:
	return int(final_stat.get(key, 0))


## The four DF-1 binding stats (physical_power/energy_power/armor/resistance) as a
## dict of SYN-F4 EFFECTIVE values, ready for [method DamageFormula.resolve] to `.get`
## on. Built fresh per hit — turn-based, not a per-frame hot path, so the small alloc
## is fine, and it guarantees the pure kernel reads composed (never base) stats.
func damage_stat_block() -> Dictionary:
	return {
		&"physical_power": effective_stat(&"physical_power"),
		&"energy_power": effective_stat(&"energy_power"),
		&"armor": effective_stat(&"armor"),
		&"resistance": effective_stat(&"resistance"),
	}


## True once structure hits 0 (checked by the orchestrator, not self-maintained).
func is_alive() -> bool:
	return not is_downed and current_structure > 0
