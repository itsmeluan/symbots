## DropSystem — post-victory loot resolution host (Drop System epic; DS-1 core).
##
## Pure DI core (ADR-0006): a [RefCounted] with no autoload and no scene. It draws
## from an injected, seeded [RandomNumberGenerator] (never global `randf()`),
## reports diagnostics through an injected [LogSink] (never `push_warning`/
## `push_error`), reads per-rarity base rates read-only from an injected
## [BalanceConfig], and hands each successful drop to an injected [InventorySink].
## Resolution runs as a single synchronous pass triggered only by a VICTORY battle
## outcome (Rule 1) — there is no runtime state machine.
##
## Canonical DS-1 drop formula, evaluated per rolled part:
## [codeblock]
##   effective = clamp(base[rarity] × level_rarity_mult × Π(matching conds) × beacon, 0, 1)
##   drops     = pity_guaranteed OR (rng.randf() < effective)   # strict <
## [/codeblock]
## In this story `level_rarity_mult` and `beacon_factor` are pinned to 1.0 (Story
## 007 supplies their real values) and `pity_guaranteed` is always `false` (the two
## pity systems are Stories 004/005). The full canonical shape is built now on
## purpose: the two future factors are present so DS-F-LEVEL / Beacon can slot in
## later without restructuring the formula.
##
## Usage:
## [codeblock]
##   var ds := DropSystem.new(seeded_rng, balance_config, log_sink, inventory_sink)
##   var drops := ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired_conditions)
## [/codeblock]
class_name DropSystem
extends RefCounted

## COMBAT `Outcome.VICTORY` (ADR-0007 `BattleController.Outcome`). Drop resolves
## ONLY on this value (Rule 1); DEFEAT/FLED return zero drops with no RNG draw.
## Mirrored as a local const so `src/core/drop_system/` need not depend on the
## battle host to read the outcome int off the `battle_ended` signal.
const OUTCOME_VICTORY: int = 1

## Salvage Beacon multiplier (Rule 12a, DS-7). Applied to PART rates only (never
## the consumable channel), and only on VICTORY-with-Beacon. Doubles the pre-clamp
## product; a clamped rate ≥ 1.0 is a guaranteed drop.
const BEACON_MULTIPLIER: float = 2.0

## DS-F-LEVEL band floors (DS-7). `level < MID_FLOOR` = EARLY, `< HIGH_FLOOR` = MID,
## else HIGH. Half-open bands: EARLY = [0,3), MID = [3,6), HIGH = [6, ∞).
const LEVEL_BAND_MID_FLOOR: int = 3
const LEVEL_BAND_HIGH_FLOOR: int = 6

## DS-F-LEVEL bands (DS-7). Ordered EARLY < MID < HIGH.
enum LevelBand { EARLY, MID, HIGH }

## DS-F-LEVEL level-rarity multiplier table (DS-7). ONLY the Rare column varies with
## the enemy's level band; Common / Boss-grade / Prototype are all 1.0 at every band.
## The Prototype-row-is-1.0 invariant is load-bearing for DS-2's `N_PROTO_PITY`
## calibration — see `_level_rarity_mult`, which returns 1.0 for every non-Rare rarity.
## All listed products are exact in IEEE 754 (0.5 / 1.0 / 1.5) — no epsilon.
const _RARE_LEVEL_MULTS: Dictionary = {
	LevelBand.EARLY: 0.5,
	LevelBand.MID: 1.0,
	LevelBand.HIGH: 1.5,
}

## Prototype gradient-pity tuning (DS-2, Story 004). The per-Prototype-ID guarantee
## threshold is `N_PROTO_PITY × C`, where `C` is the part's total drop-condition
## count. Integer-only — no rounding, no epsilon.
const N_PROTO_PITY: int = 25

## Boss-grade floor-pity tuning (DS-3, Story 005). A Boss-grade part's break-pity
## counter increments `+= 1` (contrast DS-2's `+= c`) on each qualifying-break miss;
## the guarantee fires once the counter reaches `M_BOSS_PITY`.
const M_BOSS_PITY: int = 8

## Canonical drop-condition vocabulary (Rule 5) — the closed set of valid condition
## keys the Drop System OWNS. A part condition key outside this set is a content
## error: logged once via the LogSink and skipped, its multiplier never applied and
## never a crash (EC-DS-03 / AC-DS-07). Stored as a Dictionary used as a set for
## O(1) membership.
##
## [b]Vocabulary drift (flagged 2026-07-17):[/b] the GDD Rule 5 enumerated list, the
## shipped Part-DB `.tres` roster, and the pity-story ACs disagree on the exact key
## set. The three groups below are Rule 5 canonical; the final group are keys the
## authored roster / ACs use that are NOT in Rule 5, admitted here so real content
## does not emit spurious runtime content errors. They need a Rule-5-vs-roster
## reconciliation (rename to canonical, or extend Rule 5) — a doc decision, not a
## code blocker. `UNKNOWN_KEY_XYZ` and any genuine typo stay correctly excluded.
const _CANONICAL_CONDITION_KEYS: Dictionary = {
	# Break events (Part-Break anatomy vocabulary; shared with enemy break_regions).
	&"head_broken": true, &"arm_broken": true, &"leg_broken": true,
	&"weapon_broken": true, &"chassis_cracked": true, &"core_exposed": true,
	&"core_broken": true, &"all_boss_parts_broken": true,
	# Finish-damage-type facts.
	&"defeated_by_physical": true, &"defeated_by_energy": true,
	&"defeated_by_thermal": true, &"defeated_by_volt": true, &"defeated_by_kinetic": true,
	# Style / state facts (Rule 5).
	&"targeting_active": true, &"zero_defeats": true,
	&"no_repairs_used": true, &"flawless": true,
	# Authored-drift keys (roster + pity ACs; pending Rule 5 reconciliation).
	&"low_hp_victory": true, &"overheat_kill": true, &"thermal_finish": true,
	&"core_overload": true,
}

var _rng: RandomNumberGenerator
var _balance: BalanceConfig
var _log: LogSink
var _inventory: InventorySink

## Observable set by the most recent `resolve_drops` (DS-7, AC-DS-31): `true` iff that
## resolution was a VICTORY with `beacon_used == true` (the Beacon multiplier fed the
## part rates). Reset to `false` at the start of every `resolve_drops`, so a flee/loss
## — which returns before the Beacon is ever applied — always leaves it `false`.
var beacon_drop_multiplier_applied: bool = false

## Per-Prototype-ID pity credit: `String(part_id)` → accumulated int credit (DS-2).
## Owned here in-memory; Story 009 persists it across save/load. Never negative.
var _proto_pity_credit: Dictionary = {}

## Per-Boss-grade-ID break-pity counter: `String(part_id)` → consecutive qualifying-
## break misses (DS-3). Owned here in-memory; Story 009 persists it. Never negative.
var _boss_pity_counter: Dictionary = {}


## Inject the seeded RNG, the balance config (per-rarity base rates), the
## diagnostics sink, and the inventory sink. All are borrowed references — the
## Drop System never mutates the balance config or the content defs it reads.
## `log` and `inventory` are optional so lean unit tests can omit them.
func _init(
		rng: RandomNumberGenerator,
		balance: BalanceConfig,
		log: LogSink = null,
		inventory: InventorySink = null) -> void:
	_rng = rng
	_balance = balance
	_log = log
	_inventory = inventory


## Current Prototype pity credit for a part ID (0 if never accrued). Read seam for
## tests and for Story 009 persistence.
func get_prototype_pity_credit(part_id: StringName) -> int:
	return _proto_pity_credit.get(String(part_id), 0)


## Seed the Prototype pity credit for a part ID. The write seam Story 009 uses to
## restore persisted credit on load; also lets tests arrange a starting credit.
func set_prototype_pity_credit(part_id: StringName, credit: int) -> void:
	_proto_pity_credit[String(part_id)] = credit


## Current Boss-grade break-pity counter for a part ID (0 if never accrued). Read
## seam for tests and for Story 009 persistence.
func get_break_pity_counter(part_id: StringName) -> int:
	return _boss_pity_counter.get(String(part_id), 0)


## Seed the Boss-grade break-pity counter for a part ID. Write seam for Story 009
## load restore and for test arrangement.
func set_break_pity_counter(part_id: StringName, counter: int) -> void:
	_boss_pity_counter[String(part_id)] = counter


## Rule 9 Scrap yield for a part of the given rarity (DS-8), read read-only from the
## injected [BalanceConfig] (`@export` defaults, never a literal here). The source
## side of the Scrap economy — the player-initiated scrap ACTION is Inventory's and
## the sink is Workshop's; this only vends the per-rarity yield.
##
## The load-bearing invariant `COMMON < RARE < PROTOTYPE < BOSS_GRADE` lives in the
## authored yield table, not here; the DS-8 unit test asserts it programmatically so
## an inverted retune fails the build. An out-of-range rarity is a content error:
## logged through the injected sink and treated as yield 0 (graceful degradation,
## matching `_base_rate`).
func get_scrap_yield(rarity: int) -> int:
	if rarity <= 0 or rarity >= _balance.scrap_yield_by_rarity.size():
		if _log != null:
			_log.warn(&"drop_unknown_rarity", {&"rarity": rarity})
		return 0
	return _balance.scrap_yield_by_rarity[rarity]


## Resolve drops for a finished battle. Returns the Phase-6 drop list (possibly
## empty). Only a VICTORY outcome rolls; DEFEAT/FLED return `[]` with no RNG draw
## (Rule 1 / AC-DS-11). Parts are rolled in ID-ascending order — Story 006 proves
## the full ordering/reproducibility guarantee; the sorted iteration is established
## here so later stories inherit it.
##
## [param outcome] the COMBAT battle outcome int (VICTORY == 1).
## [param pool] the already-resolved candidate [PartDef]s (Story 003 owns dedup /
##   `drop_enabled` / empty-pool resolution from the raw enemy loot pool).
## [param fired_conditions] the set of fired drop-condition keys — a [Dictionary]
##   used as a set (key present == condition fired). Story 002 owns the exact-match
##   assembly + unknown-key tolerance; here the product multiplies the multiplier of
##   every part condition whose key is present.
## [param enemy_level] the defeated enemy's level, resolved INTERNALLY to a DS-F-LEVEL
##   band → Rare multiplier (DS-7). A negative value (the default) applies NO level
##   scaling (mult 1.0) — the opt-out unit tests and any caller precomputing the mult
##   externally use. This is the documented production interface (AC-ELZS-11 binds here).
## [param beacon_used] whether a Salvage Beacon was active this battle (DS-7). On
##   VICTORY it multiplies every PART rate by [constant BEACON_MULTIPLIER] and sets the
##   observable [member beacon_drop_multiplier_applied]; it never touches the consumable
##   channel, and a flee/loss spends it with no effect (the flag stays `false`).
func resolve_drops(
		outcome: int,
		pool: Array[PartDef],
		fired_conditions: Dictionary,
		enemy_level: int = -1,
		beacon_used: bool = false) -> Array[PartInstance]:
	# Reset the observable up front: a flee/loss returns below without ever applying
	# the Beacon, so the flag must read `false` there (AC-DS-31 B).
	beacon_drop_multiplier_applied = false
	var drops: Array[PartInstance] = []
	# Rule 1 victory-only gate — return before any RNG draw on a non-victory
	# outcome so the deterministic stream is untouched (AC-DS-11).
	if outcome != OUTCOME_VICTORY:
		return drops
	# Beacon feeds the DS-1 product only on VICTORY (Rule 12a); the observable records it.
	var beacon_factor: float = BEACON_MULTIPLIER if beacon_used else 1.0
	beacon_drop_multiplier_applied = beacon_used
	# Reduce the raw pool to the retained candidates (drop_enabled + unique id,
	# ID-ascending) BEFORE any draw — a disabled or deduped-away part must never
	# advance the RNG stream (AC-DS-06 / AC-DS-08; draw count is the discriminator).
	for part in _resolved_pool(pool):
		if _roll_part(part, fired_conditions, enemy_level, beacon_factor):
			var inst := PartInstance.new(&"", part, 0)  # fresh instance at upgrade tier 0 (AC-DS-20)
			drops.append(inst)
			if _inventory != null:
				_inventory.receive_part_instance(inst)
	return drops


## Decide whether a single retained part drops this fight, updating any pity state.
## Returns `true` on a drop. Rarity routes the decision:
## - [b]Prototype[/b] → the DS-2 gradient-pity path (Story 004): a pre-roll guarantee,
##   `+= c` partial credit on a qualifying miss, reset-on-drop.
## - [b]Everything else[/b] → the bare DS-1 Bernoulli roll (Boss-grade pity is Story
##   005, wired in here later; Commons/Rares never pity).
func _roll_part(part: PartDef, fired_conditions: Dictionary, enemy_level: int, beacon_factor: float) -> bool:
	var rate: float = _effective_drop_rate(part, fired_conditions, enemy_level, beacon_factor)
	if part.rarity == PartDef.Rarity.PROTOTYPE:
		return _roll_prototype(part, rate, fired_conditions)
	if part.rarity == PartDef.Rarity.BOSS_GRADE:
		return _roll_boss_grade(part, rate, fired_conditions)
	return _bernoulli(rate)


## Prototype gradient-pity decision (DS-2, Story 004). `c` = how many of THIS part's
## drop conditions fired this fight; `C` = its total condition count; the guarantee
## threshold is `N_PROTO_PITY × C`.
##
## - [b]Qualifying[/b] (`c ≥ 1`): if credit has reached the threshold → guaranteed
##   drop, [i]skip the RNG draw[/i] (pre-roll — a guaranteed part must never advance
##   the stream, AC-DS-13 B), reset credit. Otherwise roll DS-1; on drop reset credit
##   (AC-DS-15), on miss advance credit by `c` (AC-DS-29 — not `+= 1`, not `+= C`).
## - [b]Non-qualifying[/b] (`c == 0`): roll DS-1 at base rate; on drop reset credit; on
##   miss leave credit unchanged (AC-DS-14 anti-exploit — a fight where none of the
##   part's own conditions fired earns no pity progress).
func _roll_prototype(part: PartDef, rate: float, fired_conditions: Dictionary) -> bool:
	var id_key := String(part.id)
	var c: int = _fired_condition_count(part, fired_conditions)
	var credit: int = _proto_pity_credit.get(id_key, 0)
	if c >= 1:
		var threshold: int = N_PROTO_PITY * part.drop_conditions.size()
		if credit >= threshold:
			_proto_pity_credit[id_key] = 0  # guaranteed — no draw
			return true
		if _bernoulli(rate):
			_proto_pity_credit[id_key] = 0
			return true
		_proto_pity_credit[id_key] = credit + c
		return false
	# Non-qualifying: natural base-rate roll; credit only ever resets, never advances.
	if _bernoulli(rate):
		_proto_pity_credit[id_key] = 0
		return true
	return false


## Boss-grade floor-pity decision (DS-3, Story 005). A [b]qualifying break[/b] means at
## least one of the part's break-event conditions fired this fight — the same
## fired-condition count as Prototype (`c ≥ 1`). Break-gated Boss-grade parts only
## make progress toward the floor when their break actually fires; Part-Break is
## deterministic, so there is no break-failure tail.
##
## - [b]Qualifying[/b]: if the counter has reached `M_BOSS_PITY` → guaranteed drop,
##   [i]skip the RNG draw[/i] (pre-roll, AC-DS-16 B), reset the counter. Otherwise roll
##   DS-1; on drop reset (AC-DS-30), on miss increment `+= 1` (AC-DS-16 A / AC-DS-17).
## - [b]Non-qualifying[/b] (no break fired): roll DS-1 at base rate; the counter never
##   increments (AC-DS-09), only resetting if the improbable natural drop lands.
##
## `drop_enabled == false` parts never reach here — `_resolved_pool` filters them out
## before the loop, so their counter never advances and they never emit (AC-DS-26 A).
func _roll_boss_grade(part: PartDef, rate: float, fired_conditions: Dictionary) -> bool:
	var id_key := String(part.id)
	var qualifying: bool = _fired_condition_count(part, fired_conditions) >= 1
	var counter: int = _boss_pity_counter.get(id_key, 0)
	if qualifying:
		if counter >= M_BOSS_PITY:
			_boss_pity_counter[id_key] = 0  # guaranteed — no draw
			return true
		if _bernoulli(rate):
			_boss_pity_counter[id_key] = 0
			return true
		_boss_pity_counter[id_key] = counter + 1
		return false
	# Non-qualifying: natural base-rate roll; counter only ever resets, never advances.
	if _bernoulli(rate):
		_boss_pity_counter[id_key] = 0
		return true
	return false


## Number of THIS part's drop conditions that fired this fight (`c`). Only canonical,
## fired keys count — an unknown key (skipped by `_condition_product`) earns no credit,
## matching the rate it never contributes to. Order-independent.
func _fired_condition_count(part: PartDef, fired_conditions: Dictionary) -> int:
	var count: int = 0
	for entry in part.drop_conditions:
		var key := StringName(entry.get("condition", &""))
		if _CANONICAL_CONDITION_KEYS.has(key) and fired_conditions.has(key):
			count += 1
	return count


## The canonical DS-1 Bernoulli trial: strict `<` against `[0.0, 1.0)`, so a clamped
## rate of 1.0 always drops and a draw exactly equal to the rate never does (AC-DS-03
## / AC-DS-04). The draw goes through `call(&"randf")` (see `_draw_randf`) so a
## GDScript test double dispatches; the real seeded RNG dispatches to native.
func _bernoulli(rate: float) -> bool:
	return _draw_randf() < rate


## Canonical DS-1 effective drop rate for a single part, clamped to `[0.0, 1.0]`.
## A pre-clamp product > 1.0 (heavy condition stacking, Beacon, or a HIGH-band Rare)
## becomes exactly 1.0 and thus always drops (AC-DS-03 / AC-DS-31 C).
##   effective = clamp(base × level_rarity_mult × Π(conditions) × beacon_factor, 0, 1)
func _effective_drop_rate(
		part: PartDef,
		fired_conditions: Dictionary,
		enemy_level: int,
		beacon_factor: float) -> float:
	var base_rate: float = _base_rate(part.rarity)
	var level_mult: float = _level_rarity_mult(part.rarity, enemy_level)
	var condition_product: float = _condition_product(part, fired_conditions)
	var raw: float = base_rate * level_mult * condition_product * beacon_factor
	return clampf(raw, 0.0, 1.0)


## DS-F-LEVEL level-rarity multiplier (DS-7). Only Rare parts are level-scaled; every
## other rarity — including Prototype, whose 1.0 row is load-bearing for DS-2 pity
## calibration — returns 1.0 at every band. A negative `enemy_level` (the documented
## no-scaling sentinel) also returns 1.0, so the DS-1..DS-6 unit callers are unaffected.
func _level_rarity_mult(rarity: int, enemy_level: int) -> float:
	if enemy_level < 0 or rarity != PartDef.Rarity.RARE:
		return 1.0
	return _RARE_LEVEL_MULTS[_level_band(enemy_level)]


## Resolve an enemy level to its DS-F-LEVEL band via the half-open floors.
func _level_band(enemy_level: int) -> LevelBand:
	if enemy_level < LEVEL_BAND_MID_FLOOR:
		return LevelBand.EARLY
	if enemy_level < LEVEL_BAND_HIGH_FLOOR:
		return LevelBand.MID
	return LevelBand.HIGH


## Per-rarity base drop rate from the injected BalanceConfig (Formula 3), indexed
## by the [enum PartDef.Rarity] value. An out-of-range rarity is a content error:
## logged through the injected sink and treated as rate 0.0 (graceful degradation).
func _base_rate(rarity: int) -> float:
	if rarity <= 0 or rarity >= _balance.drop_rate_by_rarity.size():
		if _log != null:
			_log.warn(&"drop_unknown_rarity", {&"rarity": rarity})
		return 0.0
	return _balance.drop_rate_by_rarity[rarity]


## Multiplicative product of every matching drop-condition multiplier (Story 002).
##
## Assembly rules:
## - [b]Exact match[/b] (AC-DS-22): a condition contributes only when its key is
##   present in the fired set. Keys are [StringName]-normalized on both sides so an
##   authored `String` key and a fired `StringName` compare equal, but no fuzzy /
##   case-folded / prefix matching happens — `arm_broken` never matches `arm_break`.
## - [b]Multiplicative stacking[/b] (AC-DS-23): every matching condition's multiplier
##   is multiplied in; order is irrelevant (multiplication commutes).
## - [b]Unknown-key tolerance[/b] (AC-DS-07 / EC-DS-03): a condition key outside the
##   canonical vocabulary is a content error — logged once through the injected sink
##   and skipped (multiplier never applied), never crashing resolution. A fired-but-
##   -unknown key is likewise ignored: only canonical keys can ever affect the rate.
##
## An empty fired set yields the neutral product 1.0 → the bare base rate (AC-DS-05).
func _condition_product(part: PartDef, fired_conditions: Dictionary) -> float:
	var product: float = 1.0
	for entry in part.drop_conditions:
		var key := StringName(entry.get("condition", &""))
		# Unknown-key content error: skip and log, never apply, never crash.
		if not _CANONICAL_CONDITION_KEYS.has(key):
			if _log != null:
				_log.warn(&"drop_unknown_condition_key", {&"part_id": part.id, &"key": key})
			continue
		# Exact-match: contribute only when the (canonical) key actually fired.
		if fired_conditions.has(key):
			product *= float(entry.get("multiplier", 1.0))
	return product


## Draw a uniform float in [0.0, 1.0) from the injected RNG. Dispatched via
## `call()` so a GDScript test double that overrides the native `randf()` is
## actually invoked (a statically-typed call would ptrcall past the override).
func _draw_randf() -> float:
	return _rng.call(&"randf")


## Reduce the raw enemy loot pool to the retained roll candidates (Story 003):
## drop the `drop_enabled == false` parts, dedup to unique part IDs (a duplicate ID
## contributes exactly one roll — at most one instance per fight), and return them
## ID-ascending. Order-independent membership is decided first, then the sort makes
## the draw order deterministic (Story 006 leans on this). The caller's array is
## never mutated. There is deliberately NO `÷ pool_size` term — each retained part
## is an independent Bernoulli trial at its own rate regardless of pool size
## (AC-DS-12).
func _resolved_pool(pool: Array[PartDef]) -> Array[PartDef]:
	var by_id: Dictionary = {}  # String(id) -> PartDef, first occurrence wins (dedup)
	for part in pool:
		if part == null or not part.drop_enabled:
			continue
		var id_key := String(part.id)
		if not by_id.has(id_key):
			by_id[id_key] = part
	var retained: Array[PartDef] = []
	retained.assign(by_id.values())
	retained.sort_custom(func(a: PartDef, b: PartDef) -> bool: return String(a.id) < String(b.id))
	return retained
