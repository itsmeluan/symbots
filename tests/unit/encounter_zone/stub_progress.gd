## Stub Exploration-Progress reader for Encounter Zone boss-gate specs (EZ-5+).
##
## Mirrors the persistent-progress read seam the boss gate consumes — a shared
## per-zone `win_count(zone_id) -> int` and a per-boss `is_boss_defeated(boss_id) ->
## bool`. Lets gate tests arrange win totals and defeat flags without a live save file
## or the (not-yet-shipped) Exploration Progress system. A `null` progress arg — the
## MVP dev-period fallback — is handled by the gate itself, NOT by this stub.
##
## preload()-ed, NOT class_name-declared — a class_name in tests/ would pollute the
## production global class registry (ADR-0002 §5).
extends RefCounted

var _wins: Dictionary = {}       # zone_id (StringName) -> win count (int)
var _defeated: Dictionary = {}   # boss_id (StringName) -> defeated_once (bool)
var _last_defeat: Dictionary = {} # boss_id (StringName) -> wins_at_last_defeat (int)


## Set a zone's shared win counter; returns self for chaining.
func set_wins(zone_id: StringName, n: int) -> RefCounted:
	_wins[zone_id] = n
	return self


## Mark a boss as defeated at least once (sets `defeated_once`); chainable.
func mark_defeated(boss_id: StringName) -> RefCounted:
	_defeated[boss_id] = true
	return self


## Snapshot the shared counter at a boss's last defeat (LIGHTER_REGATE delta base,
## EZ-6). Owned/written by Exploration Progress in production; set explicitly in tests.
## Chainable.
func set_last_defeat(boss_id: StringName, n: int) -> RefCounted:
	_last_defeat[boss_id] = n
	return self


## Shared per-zone win counter read seam. Unseen zones read 0.
func win_count(zone_id: StringName) -> int:
	return _wins.get(zone_id, 0)


## Per-boss `defeated_once` read seam. Unseen bosses read false (never defeated).
func is_boss_defeated(boss_id: StringName) -> bool:
	return _defeated.get(boss_id, false)


## Per-boss `wins_at_last_defeat` snapshot read seam (EZ-6). Unseen bosses read 0.
func wins_at_last_defeat(boss_id: StringName) -> int:
	return _last_defeat.get(boss_id, 0)
