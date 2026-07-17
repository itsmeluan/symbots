## EncounterResolver — the per-step encounter-resolution host for one zone.
##
## Pure DI core (ADR-0006): a [RefCounted] with no autoload and no scene. It draws
## from an injected, seeded [RandomNumberGenerator] (never global `randf()`),
## reports content diagnostics through an injected [LogSink] (never `push_warning`/
## `push_error`), and reads zone/patch defs read-only (never mutates or `duplicate()`s
## a content def). Resolution is called on a STEP EVENT by Overworld Navigation — it
## is turn/step-driven, never `_process`-polled (Control Manifest guardrail).
##
## Story 001 delivers EZ-1 (the encounter-trigger roll) + the value-type schema. The
## EZ-2 weighted enemy pick (Story 002), sub-pool validity filter (Story 003), and the
## boss-gate evaluation (Stories 005–007) build on this same host and its injected
## Enemy DB reader.
##
## Canonical EZ-1 encounter-trigger formula, evaluated per step within a terrain patch:
## [codeblock]
##   effective_rate = clamp(encounter_rate × active_modifier, 0.0, 1.0)
##   triggered      = rng.randf() < effective_rate            # strict <, half-open [0,1)
## [/codeblock]
## An out-of-range AUTHORED `encounter_rate` (< 0 or > 1) is a distinct concern: it is
## a content error, logged + clamped to [0,1] BEFORE the modifier multiply (AC-EZ-02).
## The modifier clamp (a Lure pushing rate over 1.0) is expected runtime behaviour and
## is NOT logged (AC-EZ-59 D). A zone with `spawn_enabled == false` short-circuits
## before any draw — no roll, no EZ-2 (AC-EZ-57).
##
## Usage:
## [codeblock]
##   var resolver := EncounterResolver.new(seeded_rng, log_sink)
##   if resolver.roll_encounter(zone, patch, active_modifier):
##       ...  # Story 002: pick an enemy from patch.enemy_subpool
## [/codeblock]
class_name EncounterResolver
extends RefCounted

## Boss-gate verdict (EZ-5). NOT a serialized content enum — a pure runtime result,
## so it deliberately breaks the project's `INVALID = 0` convention: `LOCKED = 0` is
## the fail-safe default. Every fall-through, unhandled gate type, or unresolvable
## input LANDS on LOCKED; the accessible state is only ever reached by an explicit,
## affirmative decision (Control Manifest guardrail: never fail-open).
enum GateState { LOCKED, UNLOCKED }

var _rng: RandomNumberGenerator
var _log: LogSink
## Enemy DB reader interface — borrowed, read-only. Unused by EZ-1; Stories 002/003
## consume it for weighted selection and sub-pool validity. Optional so lean EZ-1
## unit tests can omit it (typed as Variant: the reader interface lands in Story 003).
var _enemy_db: Variant
## TBC battle-start seam (EZ-4) — borrowed, called once per resolved encounter. Kept
## Variant/duck-typed on purpose: `src/core/` must NEVER hard-reference the live
## `BattleController` autoload (Control Manifest). The stub in tests records the
## `(enemy_id, is_boss, fleeable)` triple. Optional so EZ-1..EZ-3 unit tests omit it.
var _tbc: Variant


## Inject the seeded RNG, the diagnostics sink, and (optionally) the Enemy DB reader
## and TBC battle-start seam. All are borrowed references — the resolver never mutates
## the defs it reads. `log`, `enemy_db`, and `tbc` are optional so lean unit tests can
## omit whichever they don't exercise.
func _init(rng: RandomNumberGenerator, log: LogSink = null, enemy_db: Variant = null, tbc: Variant = null) -> void:
	_rng = rng
	_log = log
	_enemy_db = enemy_db
	_tbc = tbc


## The EZ-1 effective encounter rate for one patch under an optional transient
## modifier (Signal Jammer / Scrap Lure — the modifier is passed in per step by
## Overworld Navigation and never stored here). `active_modifier` defaults to 1.0
## (the identity — base EZ-1 unchanged).
##
## Two distinct clamps (AC-EZ-02 vs AC-EZ-59 D):
## - The AUTHORED `encounter_rate` is validated to [0,1] first; an out-of-range value
##   is a content error (logged via the sink, naming the value) and clamped.
## - The post-modifier product is then clamped to [0,1] — expected runtime behaviour
##   (a Lure over 1.0), NOT a content error, so it is never logged.
func effective_encounter_rate(patch: TerrainPatch, active_modifier: float = 1.0) -> float:
	var base_rate: float = patch.encounter_rate
	if base_rate < 0.0 or base_rate > 1.0:
		if _log != null:
			_log.warn(&"ez_encounter_rate_out_of_range", {
				&"terrain_type": patch.terrain_type,
				&"encounter_rate": base_rate,
			})
		base_rate = clampf(base_rate, 0.0, 1.0)
	return clampf(base_rate * active_modifier, 0.0, 1.0)


## Roll a single step's encounter check (EZ-1). Returns `true` iff an encounter
## triggers this step. A zone with `spawn_enabled == false` short-circuits BEFORE the
## RNG draw — no roll advances the deterministic stream and EZ-2 is never reached
## (AC-EZ-57; the discriminator is a zero RNG call count on an inert zone).
##
## The trigger is strict `<` against the half-open `[0.0, 1.0)` draw: `effective_rate
## == 0.0` never triggers, `== 1.0` always triggers, and a draw exactly equal to the
## rate never triggers (a `<=` impl would — AC-EZ-03).
##
## [param zone] the owning [ZoneDef] — its `spawn_enabled` master switch is read.
## [param patch] the [TerrainPatch] the player is standing on — its `encounter_rate`.
## [param active_modifier] transient per-step rate modifier (default 1.0 identity).
func roll_encounter(zone: ZoneDef, patch: TerrainPatch, active_modifier: float = 1.0) -> bool:
	# Zone-level master switch (Rule 1 / AC-EZ-57): inert before any draw.
	if not zone.spawn_enabled:
		return false
	return _draw_randf() < effective_encounter_rate(patch, active_modifier)


## Select one enemy from a terrain patch's sub-pool by weighted random draw (EZ-2,
## Rule 4). Each entry's probability is `spawn_weight ÷ total_weight`.
##
## The walk is the load-bearing part: `roll = randi_range(1, total_weight)` (INCLUSIVE
## both ends), then a running `cumulative += spawn_weight; if roll <= cumulative: hit`.
## The `[1, total]` inclusive range makes the last entry reachable (a `[0, total-1)`
## draw would strand it — AC-EZ-07), and the `<=` walk lands every boundary on the
## correct entry (a `<` walk misplaces them all — AC-EZ-05/06). `total_weight` is
## recomputed fresh from the passed pool each call (no cached mutable weight state).
##
## The `subpool` MUST already be the filtered survivor set — Story 003 owns
## `filter_valid` (disabled / missing / wrong-class / weight <= 0 exclusions) and the
## empty-pool sentinel. EZ-2 assumes clean, positive-weight entries; the trailing
## `StringName("")` return is an unreachable-with-valid-input typed-return guard, not
## the empty-pool path.
##
## [param subpool] the already-filtered weighted [SpawnEntry] candidates.
## [return] the selected `enemy_id`, handed to TBC (Story 004) to instantiate.
func select_enemy(subpool: Array[SpawnEntry]) -> StringName:
	var total_weight: int = 0
	for entry in subpool:
		total_weight += entry.spawn_weight
	var roll: int = _draw_randi_range(1, total_weight)
	var cumulative: int = 0
	for entry in subpool:
		cumulative += entry.spawn_weight
		if roll <= cumulative:
			return entry.enemy_id
	return StringName("")


## Filter a raw terrain sub-pool to the valid survivor set before EZ-2 (EZ-3, Rule
## 2 / EC-EZ-02/03/04/10). Each entry is validated against the injected Enemy-DB
## reader; defs are read read-only and never mutated. Exclusion rules, with their
## DELIBERATELY DISTINCT severities (Control Manifest guardrail):
## - `spawn_weight < 0` → content **error**, excluded (AC-EZ-33 / EC-EZ-04 negative).
## - `spawn_weight == 0` → content **warning**, excluded (AC-EZ-32 / EC-EZ-04 zero).
## - `enemy_id` resolves to no Enemy-DB entry → content **error**, excluded (AC-EZ-28).
## - resolves to a `spawn_enabled == false` entry → excluded with **NO diagnostic**
##   (retirement is graceful, EC-EZ-10 / AC-EZ-27 asserts no error for the survivor).
## - resolves to a non-`WILD` class in this terrain slot → content **error**, excluded
##   (a BOSS mistakenly placed in a terrain pool, AC-EZ-30 / EC-EZ-03).
##
## The weight checks run BEFORE Enemy-DB resolution so a zero/negative-weight entry is
## reported on its weight regardless of whether its id resolves. Callers recompute
## `total_weight` from the returned survivors (this method never caches weight state).
##
## [param raw_subpool] the authored, unvalidated [SpawnEntry] list.
## [param terrain_type] the owning patch's terrain type, named in the wrong-class error.
## [return] the retained survivors, in authored order (EZ-2 re-sums their weights).
func filter_valid(raw_subpool: Array[SpawnEntry], terrain_type: int = 0) -> Array[SpawnEntry]:
	var survivors: Array[SpawnEntry] = []
	for entry in raw_subpool:
		# Weight severity discipline (distinct channels) — checked before resolution.
		if entry.spawn_weight < 0:
			if _log != null:
				_log.error(&"ez_spawn_weight_negative", {&"enemy_id": entry.enemy_id, &"weight": entry.spawn_weight})
			continue
		if entry.spawn_weight == 0:
			if _log != null:
				_log.warn(&"ez_spawn_weight_zero", {&"enemy_id": entry.enemy_id})
			continue
		var def: EnemyDef = _enemy_db.get_enemy(entry.enemy_id) if _enemy_db != null else null
		# Missing id: error AND exclusion (contrast disabled, which is silent).
		if def == null:
			if _log != null:
				_log.error(&"ez_spawn_enemy_missing", {&"enemy_id": entry.enemy_id})
			continue
		# Retired enemy: graceful silent exclusion, no diagnostic (EC-EZ-10).
		if not def.spawn_enabled:
			continue
		# Wrong class for a terrain slot (BOSS in a WILD pool): error + exclusion.
		if def.enemy_class != EnemyDef.EnemyClass.WILD:
			if _log != null:
				_log.error(&"ez_spawn_enemy_wrong_class", {
					&"enemy_id": entry.enemy_id,
					&"terrain_type": terrain_type,
					&"enemy_class": def.enemy_class,
				})
			continue
		survivors.append(entry)
	return survivors


## Resolve one triggered encounter to an `enemy_id`: filter the patch's sub-pool
## (EZ-3), then weighted-select from the survivors (EZ-2). Returns the empty-pool
## sentinel `StringName("")` — treated by the caller as "no encounter, start no
## battle" — when the survivor set is empty (authored `[]` or drained by filtering,
## AC-EZ-26/29 / EC-EZ-01), logging a content error naming `zone_id` + `terrain_type`.
##
## This is the post-trigger seam: the caller runs [method roll_encounter] first and
## only calls this when EZ-1 fired. A `spawn_enabled == false` zone never reaches here
## (that short-circuit is in [method roll_encounter]).
func resolve_enemy(zone: ZoneDef, patch: TerrainPatch) -> StringName:
	var pool := filter_valid(patch.enemy_subpool, patch.terrain_type)
	if pool.is_empty():
		if _log != null:
			_log.error(&"ez_empty_subpool", {&"zone_id": zone.zone_id, &"terrain_type": patch.terrain_type})
		return StringName("")
	return select_enemy(pool)


## Resolve one triggered WILD encounter and hand it to TBC (EZ-4 WILD path). The
## caller has already confirmed EZ-1 fired; this composes EZ-3 filter + EZ-2 select
## ([method resolve_enemy]) and, on a real pick, hands the enemy to TBC exactly ONCE
## as a WILD encounter (`is_boss = false` ⇒ fleeable, TBC Rule 7). A sentinel result
## (empty / drained pool, Story 003) produces NO handoff — "no encounter" starts no
## battle (the impl-note guard for the deferred live AC-EZ-42).
##
## [return] the resolved `enemy_id`, or the sentinel `StringName("")` on an empty pool.
func start_wild_encounter(zone: ZoneDef, patch: TerrainPatch) -> StringName:
	var enemy_id := resolve_enemy(zone, patch)
	if enemy_id == StringName(""):
		return enemy_id  # sentinel — no handoff, no battle
	_hand_to_tbc(enemy_id, false)
	return enemy_id


## Hand an accessible boss to TBC (EZ-4 BOSS path). Called when the player initiates
## against an offerable boss — gate accessibility (OPEN / WIN_COUNT / sequencing) is
## Stories 005–007 and is assumed satisfied here. Hands off exactly ONCE as a boss
## encounter (`is_boss = true` ⇒ NOT fleeable). `fleeable` is decided in one place
## ([method _hand_to_tbc]) as a function of class, so the boss path cannot inherit a
## stray WILD-path `true` (AC-EZ-15 B is the discriminator).
func start_boss_encounter(boss: BossEncounter) -> void:
	_hand_to_tbc(boss.boss_id, true)


## The single battle-start handoff — the ONE place fleeability is decided. `fleeable`
## is derived structurally from the encounter class (`not is_boss`: WILD flees, BOSS
## does not — TBC Rule 7), never passed in as a constant, so the WILD and BOSS paths
## cannot diverge into a copy-paste `fleeable` bug. Fires once; no-op if no TBC seam
## was injected (lean tests).
func _hand_to_tbc(enemy_id: StringName, is_boss: bool) -> void:
	if _tbc != null:
		_tbc.start_battle(enemy_id, is_boss, not is_boss)


## Evaluate a boss's accessibility gate to a [enum GateState] verdict (EZ-5). A pure
## function of `(boss, zone, progress)` — no live scene, no mid-battle re-eval (the
## caller re-runs this only at battle-lifecycle boundaries per ADR-0007). `progress`
## is the injected persistent-progress reader (`win_count(zone_id)` +
## `is_boss_defeated(boss_id)`); a `null` progress is the MVP dev-period fallback until
## Exploration Progress ships (AC-EZ-40a).
##
## Access is routed on the boss's OWN `defeated_once` (EZ-6):
## - not yet defeated → the FIRST-ACCESS gate ([member gate_type]) applies, regardless
##   of `repeat_policy` (EC-EZ-09 / AC-EZ-39).
## - defeated at least once → the REPEAT gate ([member repeat_policy]) applies.
##
## First-access gates:
## - `OPEN` → always `UNLOCKED` (even with absent progress).
## - `WIN_COUNT` → `UNLOCKED` iff `zone_win_count >= required_wins` (a `>` impl would
##   stay LOCKED at exactly the threshold — AC-EZ-17/19) AND, when a
##   `requires_defeated` prerequisite is present, that prerequisite boss's
##   `defeated_once` is true. The two zone bosses read ONE shared counter but each
##   compares it to its OWN `required_wins` (never a single "any boss unlocked" flag —
##   AC-EZ-20).
##
## Repeat gates (post-first-defeat):
## - `ALWAYS_OPEN` → permanently `UNLOCKED`, no re-gate (AC-EZ-52).
## - `LIGHTER_REGATE` → `UNLOCKED` iff `zone_win_count − wins_at_last_defeat >=
##   regate_params.required_wins` — a DELTA against the per-boss last-defeat snapshot,
##   never the raw counter (a raw read collapses re-gate into ALWAYS_OPEN — AC-EZ-22).
##
## Any other (reserved `FULL_REGATE` / unimplemented) gate or repeat type → fail-safe
## `LOCKED` (Story 007 adds the reserved diagnostic).
##
## Fail-safe: any unresolvable input (dangling `requires_defeated`, absent progress on
## a WIN_COUNT gate) yields `LOCKED`, never `UNLOCKED` (AC-EZ-58 / AC-EZ-40a).
func evaluate_boss_gate(boss: BossEncounter, zone: ZoneDef, progress: Variant = null) -> GateState:
	# EZ-7: validate the gate's structure BEFORE evaluation. Any structural fault
	# (reserved gate type, missing required key, WILD-class boss slot) is fail-safe
	# LOCKED — never fall through to accessible.
	if not validate_gate(boss):
		return GateState.LOCKED
	var defeated_once: bool = progress.is_boss_defeated(boss.boss_id) if progress != null else false
	if not defeated_once:
		return _evaluate_first_access(boss, zone, progress)
	return _evaluate_repeat_access(boss, zone, progress)


## Validate a boss gate's STRUCTURE before evaluation (EZ-7, EC-EZ-07/08). Returns
## `true` when the gate is offerable, `false` (fail-safe → caller LOCKS) on a
## structural fault. Every fault logs a content diagnostic; the single invariant is
## that no fault ever falls through to accessible (Control Manifest guardrail).
##
## - WILD-class `enemy_id` in a `boss_encounters` slot → **error**, `false` (AC-EZ-31;
##   the boss-slot half of the class check — the terrain-slot half is Story 003).
## - `OPEN` → `true`; empty params are valid + silent (AC-EZ-36), spurious params are a
##   **warning** and ignored, never read as a WIN_COUNT threshold (AC-EZ-35).
## - `WIN_COUNT` → `true` iff `gate_params` HAS `required_wins`; a missing key is an
##   **error** + `false` (AC-EZ-34 — NOT defaulted to 0, which would open the boss).
## - Reserved (`WAVE` / `REACH` / `DUNGEON_RUSH`) / `INVALID` gate types → **error** +
##   `false` (AC-EZ-24/37/38); the enum values exist but are not fulfillable in MVP.
##
## `regate_params` validity (strictly-lighter-and-≥1) is a separate content linter —
## see [method validate_regate_params] — decoupled so a repeat-param typo does not lock
## first access.
func validate_gate(boss: BossEncounter) -> bool:
	# WILD-class boss slot (fault regardless of gate type). Skipped when no Enemy DB
	# was injected (lean tests / gates that don't exercise the class check).
	if _enemy_db != null:
		var def: EnemyDef = _enemy_db.get_enemy(boss.boss_id)
		if def != null and def.enemy_class == EnemyDef.EnemyClass.WILD:
			if _log != null:
				_log.error(&"ez_boss_slot_wild_class", {&"boss_id": boss.boss_id, &"enemy_class": def.enemy_class})
			return false
	match boss.gate_type:
		BossEncounter.GateType.OPEN:
			# Spurious params on an OPEN gate: warn + ignore (never a WIN_COUNT threshold).
			if not boss.gate_params.is_empty():
				if _log != null:
					_log.warn(&"ez_open_spurious_params", {&"boss_id": boss.boss_id})
			return true
		BossEncounter.GateType.WIN_COUNT:
			if not boss.gate_params.has(&"required_wins"):
				if _log != null:
					_log.error(&"ez_gate_missing_required_wins", {&"boss_id": boss.boss_id, &"missing_key": &"required_wins"})
				return false
			return true
		_:
			# Reserved / INVALID gate types are not fulfillable in MVP → fail-safe LOCK.
			if _log != null:
				_log.error(&"ez_gate_type_reserved", {&"boss_id": boss.boss_id, &"gate_type": boss.gate_type})
			return false


## Content linter for `LIGHTER_REGATE` `regate_params` (EZ-7 / AC-EZ-25). A valid
## re-gate is STRICTLY lighter than first-access and at least 1:
## `1 <= regate_required < gate_required`. Returns `false` + a content **error** naming
## both values when `regate >= first-access` (degenerates to `FULL_REGATE`) or
## `regate < 1` (degenerates to `ALWAYS_OPEN`). Decoupled from [method
## evaluate_boss_gate] on purpose: this flags bad authoring, it does not lock a boss on
## first access.
func validate_regate_params(boss: BossEncounter) -> bool:
	var first_access: int = boss.gate_params.get(&"required_wins", 0)
	var regate: int = boss.regate_params.get(&"required_wins", 0)
	if regate < 1 or regate >= first_access:
		if _log != null:
			_log.error(&"ez_regate_not_lighter", {
				&"boss_id": boss.boss_id,
				&"regate_required": regate,
				&"first_access_required": first_access,
			})
		return false
	return true


## First-access gate branch (boss not yet defeated). Applies [member gate_type].
func _evaluate_first_access(boss: BossEncounter, zone: ZoneDef, progress: Variant) -> GateState:
	match boss.gate_type:
		BossEncounter.GateType.OPEN:
			return GateState.UNLOCKED
		BossEncounter.GateType.WIN_COUNT:
			return _evaluate_win_count_gate(boss, zone, progress)
		_:
			# Reserved / unimplemented gate types are fail-safe LOCKED (Story 007 logs).
			return GateState.LOCKED


## Repeat-access gate branch (boss defeated at least once). Applies
## [member repeat_policy]. `FULL_REGATE` is reserved (Story 007); an unset/reserved
## policy is fail-safe LOCKED.
func _evaluate_repeat_access(boss: BossEncounter, zone: ZoneDef, progress: Variant) -> GateState:
	match boss.repeat_policy:
		BossEncounter.RepeatPolicy.ALWAYS_OPEN:
			return GateState.UNLOCKED
		BossEncounter.RepeatPolicy.LIGHTER_REGATE:
			return _evaluate_lighter_regate(boss, zone, progress)
		_:
			# FULL_REGATE reserved (Story 007) / INVALID → fail-safe LOCKED.
			return GateState.LOCKED


## LIGHTER_REGATE delta re-gate (EZ-6). `UNLOCKED` iff the wins BANKED SINCE this boss's
## last defeat meet the (lighter) re-gate threshold: `(win_count − wins_at_last_defeat)
## >= regate_params.required_wins`. The delta — not the raw counter — is load-bearing:
## at the defeat instant the delta is 0, so the boss re-locks (DEFEATED is a genuine
## resting state, AC-EZ-22). Reached only when `defeated_once` is true, so progress is
## non-null here; the guard is defensive.
func _evaluate_lighter_regate(boss: BossEncounter, zone: ZoneDef, progress: Variant) -> GateState:
	var required_wins: int = boss.regate_params.get(&"required_wins", 0)
	var wins: int = 0
	var last_defeat: int = 0
	if progress != null:
		wins = progress.win_count(zone.zone_id)
		last_defeat = progress.wins_at_last_defeat(boss.boss_id)
	var delta: int = wins - last_defeat
	return GateState.UNLOCKED if delta >= required_wins else GateState.LOCKED


## WIN_COUNT branch of [method evaluate_boss_gate]. Threshold test is `>=`; sequencing
## (optional `requires_defeated`) AND-gates it with the prerequisite boss's
## `defeated_once`. A prerequisite that resolves to no boss in this zone is a content
## error and fail-safe LOCKED (never "no prerequisite" — AC-EZ-58).
func _evaluate_win_count_gate(boss: BossEncounter, zone: ZoneDef, progress: Variant) -> GateState:
	var required_wins: int = boss.gate_params.get(&"required_wins", 0)
	var wins: int = 0
	if progress != null:
		wins = progress.win_count(zone.zone_id)
	elif _log != null:
		# Exploration Progress not yet connected: provisional WARNING (not error),
		# counter reads 0 → WIN_COUNT bosses LOCK. Live for the whole MVP dev period.
		_log.warn(&"ez_progress_absent", {&"boss_id": boss.boss_id, &"zone_id": zone.zone_id})
	# Threshold: >= (not >) — a `> required_wins` impl stays LOCKED at exactly N.
	if wins < required_wins:
		return GateState.LOCKED
	# Sequencing precondition (optional): prerequisite boss must be defeated_once.
	var prereq: StringName = boss.gate_params.get(&"requires_defeated", &"")
	if prereq != &"":
		if not _zone_has_boss(zone, prereq):
			# Dangling reference: content error, fail-safe LOCKED (never fail-open).
			if _log != null:
				_log.error(&"ez_requires_defeated_unresolved", {&"boss_id": boss.boss_id, &"requires_defeated": prereq})
			return GateState.LOCKED
		var prereq_defeated: bool = progress.is_boss_defeated(prereq) if progress != null else false
		if not prereq_defeated:
			return GateState.LOCKED
	return GateState.UNLOCKED


## True iff `boss_id` names a [BossEncounter] in this zone (read-only). Used to resolve
## a `requires_defeated` prerequisite; an unresolved name is fail-safe LOCKED.
func _zone_has_boss(zone: ZoneDef, boss_id: StringName) -> bool:
	for b in zone.boss_encounters:
		if b.boss_id == boss_id:
			return true
	return false


## Draw a uniform float in [0.0, 1.0) from the injected RNG. Dispatched via `call()`
## so a GDScript test double that overrides the native `randf()` is actually invoked
## (a statically-typed call would ptrcall past the override — see the RNG-ptrcall
## project memory, shared with DropSystem).
func _draw_randf() -> float:
	return _rng.call(&"randf")


## Draw an inclusive integer in [from, to] from the injected RNG. Dispatched via
## `call()` for the same ptrcall-override reason as `_draw_randf` — a GDScript RNG
## double overriding `randi_range` is only invoked through the dynamic call.
func _draw_randi_range(from: int, to: int) -> int:
	return _rng.call(&"randi_range", from, to)
