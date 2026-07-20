## ExpeditionBoard — timed offline missions for the bench (Core Design §7).
##
## Expeditions are the reason to own more Symbots than fit in a squad, and the reason the
## bench is not dead weight. A Symbot on an expedition is unavailable to fight, which is
## what makes sending one a decision rather than free money.
##
## The clock is INJECTED. A board that read the system clock directly could only be tested
## by waiting an hour, so the tests would either not exist or be flaky — and time bugs
## (negative durations, a save restored on a machine with a different clock) are exactly
## the ones you cannot afford to leave untested.
class_name ExpeditionBoard
extends RefCounted

## Emitted when a slot is filled, collected, or cancelled.
signal board_changed

## Durations the design fixes (§7): a lunch-break check-in and an overnight one.
enum Duration { INVALID = 0, SHORT = 1, MEDIUM = 2, LONG = 3 }

const DURATION_SECONDS := {
	Duration.SHORT: 3600,       ## 1h
	Duration.MEDIUM: 14400,     ## 4h
	Duration.LONG: 28800,       ## 8h
}

## Reward multiplier per duration. Deliberately SUPERLINEAR — 8h pays more than eight 1h
## runs — so the overnight slot is worth using rather than a worse version of checking in
## all day. The opposite shape would punish players who cannot check in often, which is the
## group offline rewards exist for.
const DURATION_YIELD := {
	Duration.SHORT: 100,
	Duration.MEDIUM: 480,
	Duration.LONG: 1100,
}

## Slots start at 2 and expand (§7).
const STARTING_SLOTS := 2
const MAX_SLOTS := 6

var slots: int = STARTING_SLOTS

## Active expeditions, one entry per occupied slot:
## `{symbot_id, duration (int), started_at (int unix seconds)}`
var active: Array[Dictionary] = []

## Injected clock: a Callable returning unix seconds. Defaults to the real one.
var clock: Callable = Callable(Time, "get_unix_time_from_system")


func now() -> int:
	return int(clock.call())


func free_slots() -> int:
	return maxi(0, slots - active.size())


func is_busy(symbot_id: StringName) -> bool:
	for e in active:
		if e.get("symbot_id") == symbot_id:
			return true
	return false


## Send [param symbot_id] out. Returns false when there is no room, the Symbot is already
## out, or it is currently fielded — a Symbot cannot be on an expedition and in the squad,
## or the player would field a unit that is supposed to be away.
func send(symbot_id: StringName, duration: Duration, roster: PlayerRoster) -> bool:
	if free_slots() <= 0 or symbot_id == &"" or is_busy(symbot_id):
		return false
	if not DURATION_SECONDS.has(duration):
		return false
	if roster != null:
		if not roster.owns(symbot_id) or roster.squad.has(symbot_id):
			return false
	active.append({
		"symbot_id": symbot_id,
		"duration": int(duration),
		"started_at": now(),
	})
	board_changed.emit()
	return true


## Seconds left on [param index], or 0 when it is ready.
##
## A negative elapsed time — a save restored on a machine whose clock is behind the one
## that wrote it — is treated as "just started" rather than allowed to produce a
## nonsensically huge remaining time.
func seconds_remaining(index: int) -> int:
	if index < 0 or index >= active.size():
		return 0
	var entry := active[index]
	var elapsed: int = maxi(0, now() - int(entry.get("started_at", 0)))
	var total: int = int(DURATION_SECONDS.get(int(entry.get("duration", 0)), 0))
	return maxi(0, total - elapsed)


func is_ready(index: int) -> bool:
	return index >= 0 and index < active.size() and seconds_remaining(index) == 0


## Collect a finished expedition. Returns the payout as
## `{symbot_id, scrap, items: Array[StringName]}`, or an empty Dictionary when it is not
## finished — an early collect that paid anything would make the timer decorative.
func collect(index: int, cfg: BalanceConfig, roster: PlayerRoster,
		rng: RandomNumberGenerator) -> Dictionary:
	if not is_ready(index):
		return {}
	var entry := active[index]
	var symbot_id: StringName = entry.get("symbot_id", &"")
	var payout := _payout(entry, cfg, roster, rng)
	active.remove_at(index)
	board_changed.emit()
	payout["symbot_id"] = symbot_id
	return payout


## Recall a Symbot early. Pays NOTHING — that is the cost of changing your mind, and it is
## what stops a player parking the bench on 8h runs and yanking them back the moment a
## stage needs a fifth body.
func cancel(index: int) -> bool:
	if index < 0 or index >= active.size():
		return false
	active.remove_at(index)
	board_changed.emit()
	return true


## Scrap scales with the Symbot's level, so the bench keeps pace with the squad instead of
## falling permanently behind. Item drops are one roll per expedition, weighted by duration.
func _payout(entry: Dictionary, cfg: BalanceConfig, roster: PlayerRoster,
		rng: RandomNumberGenerator) -> Dictionary:
	var duration := int(entry.get("duration", 0))
	var yield_scale: int = int(DURATION_YIELD.get(duration, 100))
	var level := 1
	if roster != null:
		var symbot := roster.get_symbot(entry.get("symbot_id", &""))
		if symbot != null:
			level = symbot.level

	var scrap: int = (cfg.expedition_scrap_base + cfg.expedition_scrap_per_level * level) \
		* yield_scale / 100

	var items: Array[StringName] = []
	if rng != null and int(rng.call(&"randi") % 100) < _item_chance(duration, cfg):
		items.append(cfg.expedition_item_pool[
			int(rng.call(&"randi") % maxi(1, cfg.expedition_item_pool.size()))])
	return {"scrap": scrap, "items": items}


func _item_chance(duration: int, cfg: BalanceConfig) -> int:
	return mini(100, cfg.expedition_item_chance_base
		* int(DURATION_YIELD.get(duration, 100)) / 100)


func to_dict() -> Dictionary:
	return {"slots": slots, "active": active.duplicate(true)}


## Entries naming a Symbot the roster no longer has are dropped: an expedition that can
## never be collected would occupy a slot forever with no way to clear it.
static func from_dict(raw: Dictionary, roster: PlayerRoster = null) -> ExpeditionBoard:
	var board := ExpeditionBoard.new()
	board.slots = clampi(int(raw.get("slots", STARTING_SLOTS)), STARTING_SLOTS, MAX_SLOTS)
	for entry in raw.get("active", []):
		if not (entry is Dictionary):
			continue
		var symbot_id := StringName(str(entry.get("symbot_id", "")))
		if symbot_id == &"":
			continue
		if roster != null and not roster.owns(symbot_id):
			continue
		board.active.append({
			"symbot_id": symbot_id,
			"duration": int(entry.get("duration", Duration.SHORT)),
			"started_at": int(entry.get("started_at", 0)),
		})
	return board
