## StatusInstance — one active status on one combatant (ADR-0007 Rule 11).
##
## A `RefCounted` value record: the status [member type], the applier's PRE-synergy
## [member snapshotted_processing] captured at application, the [member duration] in
## the afflicted combatant's own turns, and the [member magnitude] computed ONCE at
## application and never re-read live (GDD "Status potency snapshot contract").
##
## Exactly three statuses exist in MVP, one per element (Rule 11):
##   Volt → SHOCK   (mobility reduction, TBC-F4; magnitude 0–33, stored positive)
##   Thermal → BURN (DoT per tick, TBC-F3; bypasses DF-1; magnitude 2–8)
##   Kinetic → STAGGER (outgoing-damage %, TBC-F5 step 1; magnitude 0–27)
##
## The magnitude's MEANING depends on [member type]; [method compute_magnitude] is the
## single place each is derived, so the snapshot can never diverge from the formula.
class_name StatusInstance
extends RefCounted

## The three MVP status kinds. APPEND-ONLY (raw ints if ever serialized). Mapped
## from the applying move/part element by [method type_for_element].
enum Type {
	SHOCK   = 1,
	BURN    = 2,
	STAGGER = 3,
}

## Which status an element applies (Rule 11: Volt→Shock, Thermal→Burn, Kinetic→Stagger).
## Returns 0 (invalid) for an unmapped/absent element — the caller treats that as "no
## status" rather than crashing (defensive; STATUS moves are element-validated upstream).
static func type_for_element(element) -> Type:
	match element:
		PartDef.Element.VOLT: return Type.SHOCK
		PartDef.Element.THERMAL: return Type.BURN
		PartDef.Element.KINETIC: return Type.STAGGER
		_: return 0 as Type

## The status kind (see [enum Type]).
var type: Type = 0

## The applier's PRE-synergy `final_stat["processing"]` at the moment of application
## (GDD ratified: never SYN-F4, never re-read live).
var snapshotted_processing: int = 0

## Remaining duration in the afflicted combatant's own turns. Ticks/decrements only on
## its turns (benched → frozen, Story 011). Removed when it reaches 0.
var duration: int = 0

## The computed effect magnitude, meaning per [member type]: SHOCK = mobility penalty,
## BURN = per-tick structure loss, STAGGER = percentage reduction. Frozen at application.
var magnitude: int = 0


func _init(status_type: Type = 0, applier_processing: int = 0, full_duration: int = 0,
		cfg: BalanceConfig = null) -> void:
	type = status_type
	snapshotted_processing = applier_processing
	duration = full_duration
	if cfg != null:
		magnitude = compute_magnitude(status_type, applier_processing, cfg)


## Re-snapshot in place for a same-type reapplication (EC-TBC-07, newest-wins
## ENTIRELY — no max(), no averaging): refresh [member duration] to [param full_duration]
## AND replace [member snapshotted_processing] + [member magnitude] with the new
## applier's, even when the new processing is LOWER.
func refresh(applier_processing: int, full_duration: int, cfg: BalanceConfig) -> void:
	snapshotted_processing = applier_processing
	duration = full_duration
	magnitude = compute_magnitude(type, applier_processing, cfg)


## The single magnitude derivation per status kind — routes to the matching
## [BattleFormulas] method so the frozen snapshot equals the formula exactly. Pure.
static func compute_magnitude(status_type: Type, applier_processing: int,
		cfg: BalanceConfig) -> int:
	match status_type:
		Type.SHOCK: return BattleFormulas.shock_magnitude(applier_processing, cfg)
		Type.BURN: return BattleFormulas.burn_damage(applier_processing, cfg)
		Type.STAGGER: return BattleFormulas.stagger_pct(applier_processing, cfg)
		_: return 0
