## StatusEffect — one active buff or debuff on a [BattleUnit] (Core Design §3.5).
##
## Effects are DATA, not stat mutations. A unit's stat() reads the modifiers off its
## active effects rather than having them written into its snapshot, so an expiring buff
## restores the original value exactly. The alternative — add on apply, subtract on
## expire — drifts as soon as two effects overlap or one is cleansed out of order, and
## the drift is invisible until a player notices their tank got quietly weaker.
class_name StatusEffect
extends RefCounted

## Values are APPEND-ONLY — saves and content reference the int.
enum Kind {
	INVALID = 0,
	## Damage over time
	BURN = 1, CORRODE = 2, SHOCK = 3,
	## Control
	STUN = 10, SLOW = 11, TAUNT_BREAK = 12,
	## Tempo — HASTE is the positive counterpart of SLOW (mobility up), used by the
	## tactician support to move an ally up the turn order.
	HASTE = 13,
	## Defensive
	REGEN = 20, DAMAGE_REDUCTION = 21,
	## Offensive
	ATTACK_UP = 30, ATTACK_DOWN = 31, CRIT_UP = 32, PIERCE = 33,
	## Utility
	COOLDOWN_REDUCTION = 40,
}

## Player-facing name per kind, the single home of the mapping — the battle log, skill
## info and any future status icons all read it from here.
const KIND_NAMES := {
	Kind.BURN: "Burn", Kind.CORRODE: "Corrode", Kind.SHOCK: "Shock",
	Kind.STUN: "Stun", Kind.SLOW: "Slow", Kind.TAUNT_BREAK: "Taunt Break",
	Kind.HASTE: "Haste",
	Kind.REGEN: "Regen", Kind.DAMAGE_REDUCTION: "Damage Reduction",
	Kind.ATTACK_UP: "Attack Up", Kind.ATTACK_DOWN: "Attack Down",
	Kind.CRIT_UP: "Crit Up", Kind.PIERCE: "Pierce",
	Kind.COOLDOWN_REDUCTION: "Cooldown Reduction",
}


static func kind_name(kind_value: int) -> String:
	return KIND_NAMES.get(kind_value, "Effect")


var kind: Kind = Kind.INVALID
var remaining: int = 0
var is_debuff: bool = false

## Damage or healing per tick, for the over-time kinds.
var tick_amount: int = 0

## Stat modifiers this effect contributes while active.
var flat_mods: Dictionary = {}      ## stat_key -> int
var percent_mods: Dictionary = {}   ## stat_key -> whole percent

## Who applied it, for logs and for effects that credit the source.
var source_id: StringName = &""


func _init(p_kind: Kind = Kind.INVALID, p_remaining: int = 0, p_debuff: bool = false) -> void:
	kind = p_kind
	remaining = p_remaining
	is_debuff = p_debuff


func flat_modifier(key: StringName) -> int:
	return int(flat_mods.get(key, 0))


func percent_modifier(key: StringName) -> int:
	return int(percent_mods.get(key, 0))


## True when this effect makes the unit skip its turn.
func prevents_action() -> bool:
	return kind == Kind.STUN


## True when this effect stops the unit's taunt from redirecting attacks (§3.3).
## Note this is applied TO a tank by an attacker, so it is a debuff on the tank.
func suppresses_taunt() -> bool:
	return kind == Kind.TAUNT_BREAK


## True when this effect lets its holder attack past an enemy tank (§3.3 Pierce).
func grants_taunt_pierce() -> bool:
	return kind == Kind.PIERCE


## Damage this effect deals at tick time. Positive = damage to the holder.
func damage_per_tick() -> int:
	return tick_amount if kind in [Kind.BURN, Kind.CORRODE, Kind.SHOCK] else 0


## Healing this effect restores at tick time.
func heal_per_tick() -> int:
	return tick_amount if kind == Kind.REGEN else 0


# ---------------------------------------------------------------------------
# Constructors for the common cases — keeping the shapes here means content and
# tests cannot disagree about, say, whether SLOW is a debuff.
# ---------------------------------------------------------------------------

static func burn(amount: int, turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.BURN, turns, true)
	e.tick_amount = amount
	e.source_id = source
	return e


static func regen(amount: int, turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.REGEN, turns, false)
	e.tick_amount = amount
	e.source_id = source
	return e


static func stun(turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.STUN, turns, true)
	e.source_id = source
	return e


static func taunt_break(turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.TAUNT_BREAK, turns, true)
	e.source_id = source
	return e


static func pierce(turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.PIERCE, turns, false)
	e.source_id = source
	return e


static func slow(percent: int, turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.SLOW, turns, true)
	e.percent_mods[&"mobility"] = -absi(percent)
	e.source_id = source
	return e


static func attack_up(percent: int, turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.ATTACK_UP, turns, false)
	e.percent_mods[&"physical_power"] = percent
	e.percent_mods[&"energy_power"] = percent
	e.source_id = source
	return e


static func damage_reduction(percent: int, turns: int, source: StringName = &"") -> StatusEffect:
	var e := StatusEffect.new(Kind.DAMAGE_REDUCTION, turns, false)
	e.percent_mods[&"armor"] = percent
	e.percent_mods[&"resistance"] = percent
	e.source_id = source
	return e
