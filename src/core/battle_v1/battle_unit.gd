## BattleUnit — one combatant on the field (Core Design §3).
##
## A frozen stat snapshot plus the mutable state of a single fight. Stats are captured
## when the battle starts and never recomputed mid-fight: a levelled part or an allocated
## node cannot change the numbers of a battle already in progress, which is what keeps a
## replay of the same seed deterministic.
##
## Buffs and debuffs do NOT rewrite the snapshot. They live as status effects and are
## applied on read, so removing a debuff restores the original value exactly rather than
## by subtracting whatever was added — the failure mode where a stat drifts after a few
## apply/expire cycles.
class_name BattleUnit
extends RefCounted

const SpeciesDefScript := preload("res://src/core/species/species_def.gd")

## Which side of the field. Not a team index — a unit needs to answer "is this one of
## mine?" constantly, and an enum reads better than comparing team ints.
enum Side { PLAYER = 0, ENEMY = 1 }

var unit_id: StringName = &""
var display_name: String = ""

## Which sprite to draw. Carried on the combat unit so the view can render art without
## reaching back into the roster or the catalog — the snapshot holds everything the panel
## needs. `art_mark` is 1-3; a Retrofit changes it.
var species_id: StringName = &""
var art_mark: int = 1
## Stored as int, not as `Side`. A `class_name` script's own enum resolves to a
## different type identity when read from outside the script, so a typed property
## rejects `BattleUnit.Side.ENEMY` from a caller. Same idiom as `role` below.
var side: int = Side.PLAYER
var role: int = 0                       ## SpeciesDef.Role
var slot: int = 0                       ## 0-3, the row this unit occupies in its column

## Frozen at battle start (see class docstring).
var base_stats: Dictionary = {}

var current_structure: int = 0
var max_structure: int = 0

## Absorbs damage before structure. Spent first and never healed — a shield is a budget,
## not a second health bar.
var shield: int = 0

## Active status effects. See status_effect.gd.
var statuses: Array = []

## skill_id -> turns remaining. Absent or 0 means ready.
var cooldowns: Dictionary = {}

## Skill ids this unit can use, slot order. Index 0 is always the basic attack.
var skills: Array[StringName] = []

## The one ult this unit has slotted, or empty (§3.4b). Held separately from `skills`
## because the ult has its own slot and its own gate — folding it into the rotation would
## mean it competed with the actives, and a skill that costs a rotation slot to hold is a
## skill most players never slot.
var ultimate_skill: StringName = &""

## Ult charge, filled through the fight. Starts at 0 every battle: an ult that opens the
## fight is not an ult, it is a long-cooldown skill.
var ultimate_charge: int = 0


## Charge gained per action taken and per hit absorbed. Both, so a tank that never lands a
## hit still reaches its ult — otherwise the role that survives longest charges slowest,
## which is exactly backwards.
const CHARGE_PER_ACTION := 10
const CHARGE_PER_HIT_TAKEN := 5


func has_ultimate() -> bool:
	return ultimate_skill != &""


## True when the ult is charged enough to fire. [param cost] comes from the SkillDef, so
## a cheap ult and an expensive one share this one gate.
func is_ultimate_ready(cost: int) -> bool:
	return has_ultimate() and ultimate_charge >= cost


func gain_charge(amount: int) -> void:
	if has_ultimate() and amount > 0:
		ultimate_charge += amount


## Spend the meter. Charge is CONSUMED, not zeroed — overfill carries toward the next
## cast, so a long fight is not silently wasting the charge a player earned.
func spend_charge(cost: int) -> void:
	ultimate_charge = maxi(0, ultimate_charge - cost)


func is_alive() -> bool:
	return current_structure > 0


func is_tank() -> bool:
	return role == SpeciesDefScript.Role.TANK


## Read a stat with every active modifier applied. Flat modifiers land first, then
## percentage ones, so a +10 and a +50% do not depend on application order.
func stat(key: StringName) -> int:
	var flat := 0
	var pct := 0
	for s in statuses:
		flat += s.flat_modifier(key)
		pct += s.percent_modifier(key)
	var base: int = int(base_stats.get(key, 0)) + flat
	return maxi(0, base + (base * pct) / 100)


## Speed for turn ordering. Named separately from stat() so the ordering rule has one
## place to change if speed ever stops being plain mobility.
func speed() -> int:
	return stat(&"mobility")


## True when a status prevents this unit from acting this turn.
func is_stunned() -> bool:
	for s in statuses:
		if s.prevents_action():
			return true
	return false


## True when this unit's taunt is suppressed, so enemies may look past it even though it
## is a living tank (§3.3 taunt-break).
func is_taunt_suppressed() -> bool:
	for s in statuses:
		if s.suppresses_taunt():
			return true
	return false


## True when this unit ignores enemy taunt entirely — the Backline passive (§3.3).
func ignores_taunt() -> bool:
	for s in statuses:
		if s.grants_taunt_pierce():
			return true
	return false


## Apply damage through the shield first. Returns the amount actually taken off
## structure, which the caller needs for lifesteal, thorns and the combat log — a caller
## that assumed "damage dealt == structure lost" would over-credit every shielded hit.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var remaining := amount
	if shield > 0:
		var absorbed: int = mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining <= 0:
		return 0
	var before := current_structure
	current_structure = maxi(0, current_structure - remaining)
	return before - current_structure


## Heal, clamped to max. Returns the amount actually restored so an overheal reads as 0
## rather than as a successful heal.
func heal(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var before := current_structure
	current_structure = mini(max_structure, current_structure + amount)
	return current_structure - before


func add_shield(amount: int) -> void:
	if amount > 0:
		shield += amount


## Cooldowns tick at the START of the unit's turn, not the end of the round. Ticking per
## round would make a fast unit and a slow unit recover at different real rates, which is
## invisible to the player and impossible to reason about.
func tick_cooldowns() -> void:
	for id in cooldowns.keys():
		var left: int = int(cooldowns[id]) - 1
		if left <= 0:
			cooldowns.erase(id)
		else:
			cooldowns[id] = left


func is_skill_ready(skill_id: StringName) -> bool:
	return not cooldowns.has(skill_id)


func put_on_cooldown(skill_id: StringName, turns: int) -> void:
	if turns > 0:
		cooldowns[skill_id] = turns


## Advance every status by one turn and drop the expired ones. Returns the effects that
## expired so the caller can log them — a buff falling off silently is a common source of
## "why did I suddenly start losing".
func tick_statuses() -> Array:
	var expired: Array = []
	var kept: Array = []
	for s in statuses:
		s.remaining -= 1
		if s.remaining <= 0:
			expired.append(s)
		else:
			kept.append(s)
	statuses = kept
	return expired


func add_status(effect) -> void:
	statuses.append(effect)


## Remove all debuffs. Buffs survive — a cleanse that stripped the caster's own buffs
## would be a trap the player only discovers by losing a fight to it.
func cleanse() -> int:
	var before := statuses.size()
	statuses = statuses.filter(func(s): return not s.is_debuff)
	return before - statuses.size()
