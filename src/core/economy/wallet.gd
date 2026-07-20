## Wallet — the player's two currencies (Core Design §5.1).
##
## **Scrap** is the common currency: it levels parts and pays for respecs. It is ONE pool
## and every Symbot competes for it — that competition is the retention engine (§5.2), so
## nothing here should ever grow into per-Symbot sub-pools.
##
## **Alloy** is the rare one: it crafts new Symbots from blueprints. Deliberately not
## interchangeable with Scrap, because a conversion rate would collapse two decisions
## ("who do I level" and "who do I build") into one.
class_name Wallet
extends RefCounted

## Emitted whenever a balance changes, so the HUD renders from a signal rather than
## polling (ADR-0008 forbids view_state_polling).
signal balance_changed(currency: StringName, amount: int)

const SCRAP := &"scrap"
const ALLOY := &"alloy"

var scrap: int = 0
var alloy: int = 0


func balance(currency: StringName) -> int:
	match currency:
		SCRAP: return scrap
		ALLOY: return alloy
	return 0


func can_afford(currency: StringName, amount: int) -> bool:
	return amount >= 0 and balance(currency) >= amount


## Add currency. Negative amounts are ignored rather than treated as a spend — a caller
## that means to charge should call [method spend], and letting earn() go negative would
## make an off-by-one in a reward table quietly drain the player.
func earn(currency: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_set_balance(currency, balance(currency) + amount)


## Charge the player. Returns false and changes NOTHING when they cannot afford it — a
## partial spend that leaves the balance at zero and the purchase unmade is the worst of
## both outcomes.
func spend(currency: StringName, amount: int) -> bool:
	if amount < 0 or not can_afford(currency, amount):
		return false
	_set_balance(currency, balance(currency) - amount)
	return true


## Named _set_balance, NOT _set: `_set` is Object's virtual property-setter hook
## (`_set(property, value) -> bool`), and overriding it with a different signature makes
## the whole script fail to parse.
func _set_balance(currency: StringName, value: int) -> void:
	var clamped := maxi(0, value)
	match currency:
		SCRAP: scrap = clamped
		ALLOY: alloy = clamped
		_: return
	balance_changed.emit(currency, clamped)


func to_dict() -> Dictionary:
	return {"scrap": scrap, "alloy": alloy}


## JSON returns every number as float; both fields are integers and leaving them as floats
## would poison comparisons downstream (ADR-0001 implementation guideline).
static func from_dict(raw: Dictionary) -> Wallet:
	var w := Wallet.new()
	w.scrap = maxi(0, int(raw.get("scrap", 0)))
	w.alloy = maxi(0, int(raw.get("alloy", 0)))
	return w
