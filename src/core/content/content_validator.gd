## ContentValidator — the single content-integrity gate (ADR-0003 §5).
##
## A plain, fully dependency-injected [RefCounted]: it takes the loaded
## [ContentCatalogs] aggregate plus a [LogSink] and returns
## `{ok: bool, errors: Array[Dictionary], warnings: Array[Dictionary]}`. Two
## mounts share this ONE validator — the CI-blocking headless GUT run and the
## dev-boot fail-loud pass (release builds skip it). Every diagnostic is routed
## through the injected [LogSink] (`error(code, detail)`); it never calls
## `push_error`/`push_warning` (`global_push_diagnostics` is forbidden in `src/`,
## ADR-0002 §5 — direct engine pushes are invisible to GUT).
##
## Story 007 delivers the scaffold plus the schema / enum / nullability / range
## families for the Part DB (GDD AC-01/02/03/17/18/20/21/22/24). Story 008 EXTENDS
## this same validator (never a fork) with the content-composition families —
## synergy tags, Prototype ±/concentration, Boss-grade break condition, stat
## budgets, and Common-cap / Rare-floor primary bounds (AC-04/10/11/12/19/23).
## Those families read the [BalanceConfig] budget/cap/floor tables, so they run
## only when a config is injected via [member ContentCatalogs.balance]; the schema
## families need no config and always run. Story 009 adds the cross-DB referential
## integrity family (Part→Move / Part→Passive resolution, AC-13) plus the
## `level_requirement` rarity-floor and `level_growth` CORE-only structural checks
## (TR-part-011/012); that family runs only when a Move/Passive resolution index is
## mounted via [member ContentCatalogs.references_mounted]. Story 011 closes the
## Round-10/11 review debt: `_check_prototype_focus_floor` (AC-25), `_check_prototype_drop_conditions`
## (AC-26), the AC-27 symmetric negative bound on `_check_stat_budget`, and entry-shape
## validation for `upgrade_effects`/`drop_conditions` arrays. `&""` (empty StringName)
## is the null-equivalent (ADR-0003).
##
## Move-DB Story 004 EXTENDS this same validator with the Move schema family
## (required fields, DAMAGE→power_tier, REPAIR/UTILITY→SELF targeting); Story 005
## adds the Move authoring-rule family (energy band, REPAIR Energy-brake,
## status↔element, non-DAMAGE rider ban). Both run only when a `MoveCatalog` is
## mounted via [member ContentCatalogs.moves] — Part-only fixtures skip them.
##
## Internal structure: per-DB validation families are extracted into composed
## [RefCounted] helpers under `validators/`. [ContentValidator] remains the single
## public entry point; helpers share its [member _errors] / [member _warnings]
## / [member _log] accumulators by reference (Arrays in GDScript are reference
## types), so no post-call merge step is needed.
class_name ContentValidator
extends RefCounted

## Authored manufacturer affiliations. `&"wild"` is a real value ("no
## manufacturer"), NOT a null-equivalent; `&""` (the schema default) is invalid.
const VALID_MANUFACTURERS: Array[StringName] = [&"boltwell", &"ironclad", &"scrapjaw", &"wild"]

## MVP elemental affinities. CRYO/CORROSIVE/DATA are Full-Vision-reserved and
## must never appear in MVP content (AC-21).
const MVP_ELEMENTS: Array[int] = [
	PartDef.Element.VOLT, PartDef.Element.THERMAL, PartDef.Element.KINETIC,
]

## MVP damage types delivered by an active skill. DATA/TRUE are reserved.
const MVP_DAMAGE_TYPES: Array[int] = [PartDef.DamageType.PHYSICAL, PartDef.DamageType.ENERGY]

## Full-Vision-reserved damage types — rejected on any part, skill or not (AC-21).
const RESERVED_DAMAGE_TYPES: Array[int] = [PartDef.DamageType.DATA, PartDef.DamageType.TRUE]

## Recharge stat bound (AC-17): `stat_bonuses["recharge"]` ∈ [0, 15].
const RECHARGE_MAX := 15

## Heat generation bound (AC-22, Part-DB share only): `heat_generation` ∈ [0, 40].
const HEAT_MAX := 40

## Canonical stat key read for the recharge range/gating checks.
const RECHARGE_KEY := &"recharge"

## AC-01 (Rule 8) — slots permitted to carry an active skill. CORE and
## ENERGY_CELL are support slots (passive + stats only): an active skill on
## either is a `content_active_skill_forbidden`.
const SKILL_CAPABLE_SLOTS: Array[int] = [
	PartDef.SlotType.HEAD, PartDef.SlotType.ARMS, PartDef.SlotType.WEAPON,
	PartDef.SlotType.CHASSIS, PartDef.SlotType.LEGS, PartDef.SlotType.CHIPSET,
]

## AC-01 (Rule 8) — effect-capacity band per rarity, where an effect is a
## non-null `active_skill_id` or `passive_id` (counted separately). CEILING caps
## how many a part may carry; FLOOR is the minimum it must carry. Common is the
## only tier with a 0 floor — every Rare-or-above part brings at least one effect.
const EFFECT_CEILING: Dictionary = {
	PartDef.Rarity.COMMON: 0, PartDef.Rarity.RARE: 1,
	PartDef.Rarity.BOSS_GRADE: 2, PartDef.Rarity.PROTOTYPE: 2,
}
const EFFECT_FLOOR: Dictionary = {
	PartDef.Rarity.COMMON: 0, PartDef.Rarity.RARE: 1,
	PartDef.Rarity.BOSS_GRADE: 1, PartDef.Rarity.PROTOTYPE: 1,
}

# --- Story 008: content-composition families (run only when a BalanceConfig is
# injected via ContentCatalogs.balance; the schema families above always run) ---

## Canonical synergy tag for each MVP element (AC-04). A part's element tag must
## appear in its `synergy_tags`. Reserved elements have no MVP tag — AC-21 rejects
## those first, so this table intentionally omits them.
const ELEMENT_TAGS: Dictionary = {
	PartDef.Element.VOLT: &"volt",
	PartDef.Element.THERMAL: &"thermal",
	PartDef.Element.KINETIC: &"kinetic",
}

## Real manufacturer tags (AC-04). A non-wild part must carry its manufacturer as a
## synergy tag; a wild part must carry NONE of these. `&"wild"` is excluded — it is
## the "no manufacturer" value and never appears as a synergy tag.
const MANUFACTURER_TAGS: Array[StringName] = [&"boltwell", &"ironclad", &"scrapjaw"]

## AC-04: a part with this `manufacturer` carries no manufacturer synergy tag.
const WILD_MANUFACTURER := &"wild"

## Slot → primary stat key (AC-23 slot primary-stat mapping). ARMS and WEAPON are
## resolved per-part by `damage_type` (see [method _primary_stat_for]) and are
## intentionally absent from this table.
const PRIMARY_STAT: Dictionary = {
	PartDef.SlotType.CORE: &"energy_capacity",
	PartDef.SlotType.CHASSIS: &"structure",
	PartDef.SlotType.CHIPSET: &"processing",
	PartDef.SlotType.ENERGY_CELL: &"energy_capacity",
	PartDef.SlotType.HEAD: &"targeting",
	PartDef.SlotType.LEGS: &"mobility",
}

## AC-23 per-part primary stat for the damage_type-split ARMS / WEAPON slots.
const PHYSICAL_PRIMARY := &"physical_power"
const ENERGY_PRIMARY := &"energy_power"

## AC-11: a Boss-grade part needs a `drop_conditions` entry with `multiplier` at
## least this, so `clamp(0.001 × mult, 0, 1) >= 0.5` (the 50% break design target).
const BOSS_BREAK_MIN_MULTIPLIER := 500.0

## AC-12 multi-stat cap: no single positive `stat_bonuses` value may exceed this
## (the Formula 1 variable range); larger budgets must spread across ≥2 stats.
const MAX_SINGLE_STAT := 55

## AC-19 Prototype concentration threshold: `top_two_sum / positive_total >= 0.70`.
const CONCENTRATION_MIN := 0.70

## AC-DF (Damage-Formula Story 001): `BalanceConfig.damage_floor` must be `>= 0` —
## a negative floor would let `max(damage_floor, …)` return negative damage. The GDD
## safe range is 0–5; only the negative case is a hard error (a high floor is a
## tuning choice, not a schema violation).
const DAMAGE_FLOOR_MIN := 0

## AC-DF (Damage-Formula Story 002): the MVP `type_chart` grid is the 3×3 Cartesian
## product of these skill/Core elements — every one of the 9 cells must be present
## (a missing cell would silently degrade to ×1.0 at runtime, hiding an authoring
## gap). Reserved Full-Vision elements (CRYO/CORROSIVE/DATA) are intentionally NOT
## required — they legitimately fall through to the ×1.0 default.
const TYPE_CHART_MVP_ELEMENTS: Array[int] = [
	PartDef.Element.VOLT, PartDef.Element.THERMAL, PartDef.Element.KINETIC,
]

## AC-DF (Story 002): every authored `type_chart` cell must be one of the three
## locked Part DB Rule 6 ratios — ×0.75 resisted, ×1.0 neutral, ×1.5 super-effective.
## Any other value (a typo, a drifted retune) is a hard error: this validator is the
## BalanceConfig-vs-GDD drift guard the ADR mandates.
const TYPE_CHART_RATIOS: Array[float] = [0.75, 1.0, 1.5]

# --- Story 009: cross-DB referential integrity + level fields (run only when a
# Move/Passive resolution index is mounted via ContentCatalogs.references_mounted) ---

## TR-part-011 per-rarity `level_requirement` floors. A part's effective requirement
## (0 → treated as 1) must be `>=` its rarity floor; it may exceed it, never go below.
const RARITY_LEVEL_FLOORS: Dictionary = {
	PartDef.Rarity.COMMON: 1,
	PartDef.Rarity.RARE: 3,
	PartDef.Rarity.BOSS_GRADE: 6,
	PartDef.Rarity.PROTOTYPE: 8,
}

var _errors: Array[Dictionary] = []
var _warnings: Array[Dictionary] = []
var _log: LogSink

## The injected balance tables (ADR-0005). Null in a schema-only validation — the
## content-composition families skip when it is absent.
var _cfg: BalanceConfig

## The mounted Move/Passive resolution index (Story 009). `_refs_mounted` gates the
## referential + level-field family; the id sets answer the AC-13 `.has(id)` checks.
var _refs_mounted := false
var _move_ids: Dictionary = {}
var _passive_ids: Dictionary = {}

## ai_profile referential seam (injected Callable). Signature: `(profile: StringName) -> bool`.
## Default is accept-all — valid until the EnemyAI autoload is implemented.
## Inject via [method ContentValidator.new] or the `ai_profile_checker` setter
## in tests by replacing this field before calling validate().
## Do NOT call EnemyAI directly here — that would create a hard compile-time
## dependency on a not-yet-existing class.
var _ai_profile_checker: Callable = func(_p: StringName) -> bool: return true

## Part-DB referential seam (Enemy-DB Story 007). Signature: `(id: StringName) -> PartDef`
## (`null` for an unresolved id). Default is an INVALID Callable — the enemy loot family
## stays inert until injected, so fixtures that mount no Part DB stay green. Inject via
## [method set_part_lookup]. Kept DI (no hard PartDatabase singleton) per Control Manifest.
var _part_lookup: Callable = Callable()

# ---------------------------------------------------------------------------
# Composed per-DB helper instances (lazy-allocated once, reused across calls).
# ---------------------------------------------------------------------------
var _part_validator: RefCounted
var _move_validator: RefCounted
var _passive_validator: RefCounted
var _consumable_validator: RefCounted
var _enemy_validator: RefCounted


## Validate every catalog in [param catalogs], routing each fatal finding through
## [param log_sink]. Returns `{ok, errors, warnings}` where `ok` is
## `errors.is_empty()`. Safe to re-run on the same instance — state is reset each
## call. Story 007 validates the Part DB; later stories append more catalogs.
func validate(catalogs: ContentCatalogs, log_sink: LogSink) -> Dictionary:
	_errors = []
	_warnings = []
	_log = log_sink
	_cfg = catalogs.balance
	_refs_mounted = catalogs.references_mounted
	_move_ids = catalogs.move_ids
	_passive_ids = catalogs.passive_ids

	# Config-level balance checks (Damage-Formula Story 001) — run once when a
	# BalanceConfig is injected; validate the config itself before the catalogs.
	if _cfg != null:
		var pv := _get_part_validator()
		pv.check_balance_config()

	_get_part_validator().validate_catalog(catalogs.parts)

	# Move DB family (Move-DB Stories 004/005) — only when a move catalog is mounted;
	# Part-only fixtures leave it null and skip it, staying green.
	if catalogs.moves != null:
		_get_move_validator().validate_catalog(catalogs.moves)

	# Passive DB family (Passive-DB Stories 004/005) — only when a passive catalog is
	# mounted; fixtures that mount none leave it null and skip it, staying green.
	if catalogs.passives != null:
		_get_passive_validator().validate_catalog(catalogs.passives)

	# Consumable DB family (Consumable-DB Story 007) — only when a consumable catalog
	# is mounted; fixtures that mount none leave it null and skip it, staying green.
	if catalogs.consumables != null:
		_get_consumable_validator().validate_catalog(catalogs.consumables)

	# Enemy DB family (Enemy-DB Story 004) — only when an enemy catalog is mounted;
	# all prior-story fixtures leave it null and skip it, staying green.
	if catalogs.enemies != null:
		_get_enemy_validator().validate_catalog(catalogs.enemies)

	return {"ok": _errors.is_empty(), "errors": _errors, "warnings": _warnings}


## Record a fatal finding: append to the returned `errors` array AND surface it
## through the injected [LogSink]. The two stay in lock-step so a GUT spy can
## assert on either.
func _error(code: StringName, detail: Dictionary) -> void:
	_errors.append({"code": code, "detail": detail})
	_log.error(code, detail)


## Record a non-fatal authoring warning: append to `warnings` AND surface it
## through the [LogSink]. Warnings never affect `ok` (AC-23 empty-group coverage).
func _warn(code: StringName, detail: Dictionary) -> void:
	_warnings.append({"code": code, "detail": detail})
	_log.warn(code, detail)


## Wire the `ai_profile` referential seam so tests (and eventually the real boot)
## can inject a non-default checker. Call before `validate()`.
## [param checker] must have signature `(StringName) -> bool`.
func set_ai_profile_checker(checker: Callable) -> void:
	_ai_profile_checker = checker
	# Forward to enemy validator if already allocated.
	if _enemy_validator != null:
		_enemy_validator.set_ai_profile_checker(checker)


## Wire the Part-DB referential seam (Enemy-DB Story 007) so tests (and eventually the
## real boot) can inject a live `(StringName) -> PartDef` lookup. Call before `validate()`.
func set_part_lookup(lookup: Callable) -> void:
	_part_lookup = lookup
	# Forward to enemy validator if already allocated.
	if _enemy_validator != null:
		_enemy_validator.set_part_lookup(lookup)


# ---------------------------------------------------------------------------
# Helper factory — allocate once, wire shared state each call
# ---------------------------------------------------------------------------

## Return the PartValidator, allocating it on first use and wiring the shared
## accumulator arrays + state fields so it writes directly into [member _errors]
## / [member _warnings] (Array reference semantics in GDScript).
func _get_part_validator() -> RefCounted:
	if _part_validator == null:
		_part_validator = load("res://src/core/content/validators/part_validator.gd").new()
	_part_validator._errors = _errors
	_part_validator._warnings = _warnings
	_part_validator._log = _log
	_part_validator._cfg = _cfg
	_part_validator._refs_mounted = _refs_mounted
	_part_validator._move_ids = _move_ids
	_part_validator._passive_ids = _passive_ids
	return _part_validator


## Return the MoveValidator, allocating it on first use and wiring shared state.
func _get_move_validator() -> RefCounted:
	if _move_validator == null:
		_move_validator = load("res://src/core/content/validators/move_validator.gd").new()
	_move_validator._errors = _errors
	_move_validator._warnings = _warnings
	_move_validator._log = _log
	return _move_validator


## Return the PassiveValidator, allocating it on first use and wiring shared state.
func _get_passive_validator() -> RefCounted:
	if _passive_validator == null:
		_passive_validator = load("res://src/core/content/validators/passive_validator.gd").new()
	_passive_validator._errors = _errors
	_passive_validator._warnings = _warnings
	_passive_validator._log = _log
	return _passive_validator


## Return the ConsumableValidator, allocating it on first use and wiring shared state.
func _get_consumable_validator() -> RefCounted:
	if _consumable_validator == null:
		_consumable_validator = load("res://src/core/content/validators/consumable_validator.gd").new()
	_consumable_validator._errors = _errors
	_consumable_validator._warnings = _warnings
	_consumable_validator._log = _log
	return _consumable_validator


## Return the EnemyValidator, allocating it on first use and wiring shared state.
## Forwards the injected [member _ai_profile_checker] seam.
func _get_enemy_validator() -> RefCounted:
	if _enemy_validator == null:
		_enemy_validator = load("res://src/core/content/validators/enemy_validator.gd").new()
		_enemy_validator.set_ai_profile_checker(_ai_profile_checker)
		_enemy_validator.set_part_lookup(_part_lookup)
	_enemy_validator._errors = _errors
	_enemy_validator._warnings = _warnings
	_enemy_validator._log = _log
	return _enemy_validator
