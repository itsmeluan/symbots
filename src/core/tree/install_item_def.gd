## InstallItemDef — hardware fitted into a SOCKET node to unlock it (Core Design §4.4).
##
## The second currency of the tree. Points alone cannot open a socket: the player must
## have dropped the right component. This is what makes a drop feel like progress on a
## build rather than a number going up, and it is why sockets sit on paths rather than at
## dead ends — a missing chip should block a *route*, which the player then goes hunting
## for, not a leaf they shrug at.
##
## Items are REMOVABLE at a cost in Scrap (Core Design §4.4). A system the player is
## afraid to touch is a system they do not engage with.
@tool
class_name InstallItemDef
extends Resource

## Category decides which sockets an item fits. Values are APPEND-ONLY.
enum Category {
	INVALID   = 0,
	RAM_CHIP  = 1,  ## cooldown, action economy, turn order
	PROCESSOR = 2,  ## crit, accuracy, skill scaling
	CAPACITOR = 3,  ## burst, charge, overload
	HEAT_SINK = 4,  ## survivability, damage reduction, regen
	SERVO     = 5,  ## speed, evasion, extra actions
}

## Tier scales the socket's effect. Same socket, better chip, stronger node — so a socket
## the player opened early stays worth revisiting.
enum Tier { INVALID = 0, T1 = 1, T2 = 2, T3 = 3, T4 = 4 }

## Effect multiplier per tier, in whole percent of the node's authored value.
const TIER_POWER := {Tier.T1: 100, Tier.T2: 140, Tier.T3: 190, Tier.T4: 250}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.INVALID
@export var tier: Tier = Tier.INVALID

## Scrap refunded/charged when pulling this item back out. Authored per item so a
## high-tier component is a heavier commitment than a starter chip.
@export var removal_scrap_cost: int = 0


## Whole-percent scale this item applies to its socket's authored effect.
func power_percent() -> int:
	return TIER_POWER.get(tier, 100)


## True when this item fits a socket declaring [param accepts].
func fits(accepts: StringName) -> bool:
	return accepts == category_key()


## Stable string form of the category, used as the socket's `socket_accepts` value so
## content authoring reads as words rather than enum ints.
func category_key() -> StringName:
	match category:
		Category.RAM_CHIP: return &"ram_chip"
		Category.PROCESSOR: return &"processor"
		Category.CAPACITOR: return &"capacitor"
		Category.HEAT_SINK: return &"heat_sink"
		Category.SERVO: return &"servo"
	return &""
