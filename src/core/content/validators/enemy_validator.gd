## EnemyValidator — Enemy-DB validation family for [ContentValidator]
## (ADR-0003 §5).
##
## Contains the full Enemy-DB schema-presence family extracted verbatim from
## [ContentValidator]: schema presence/type, id uniqueness, skills count,
## ai_profile non-empty + referential seam, tier advisory, and flavor_text length
## (Enemy-DB Story 004).
##
## The `ai_profile` referential seam is forwarded from [ContentValidator] via
## [member _ai_profile_checker] — call [method set_ai_profile_checker] before
## [method validate_catalog] to inject a non-default checker.
##
## Story 006 appended the break-region validation family:
## [method _check_enemy_break_regions] dispatches per-region checks:
##   - ≥1 region (TR-edb-022 / EC-ED-01)
##   - stored == derived via [BreakHpFormula.derive_break_hp] (TR-edb-002)
##   - break_hp < structure (TR-edb-004 / EDB-3)
##   - region_fraction ∈ [REGION_FRACTION_MIN, REGION_FRACTION_MAX] ± 1e-9 (TR-edb-014)
##   - region_id uniqueness within enemy (TR-edb-004 / EC-ED-08)
##   - loot connectivity: break_event matches ≥1 loot_pool entry's drop_condition
##     (TR-edb-004 / EDB-3)
## NOTE: break_event uniqueness is NOT checked — same break_event on multiple
## regions is legal set semantics (TR-edb-021 / EC-ED-07 / AC-ED-20).
##
## Composed by [ContentValidator]; never instantiated directly by game code.
##
## Call sequence (per validation run):
##   1. Set [member _errors], [member _warnings], [member _log] from
##      [ContentValidator] before calling [method validate_catalog].
##   2. Optionally call [method set_ai_profile_checker] to inject a non-default seam.
##   3. [method validate_catalog] populates [member _errors] / [member _warnings]
##      in-place; [ContentValidator] merges them into its own accumulators.
extends "content_validator_base.gd"

# ---------------------------------------------------------------------------
# Enemy-DB Story 004 — Enemy schema-presence family
# ---------------------------------------------------------------------------

## The accepted MVP `enemy_class` values. ELITE (3) and RIVAL (4) are reserved
## for Full Vision — they are declared in the GDD but NOT in EnemyDef.EnemyClass,
## so any .tres that somehow stores 3/4 reads back as INVALID. This check
## enforces {WILD, BOSS} exactly; INVALID (0) is the "missing" sentinel.
const VALID_ENEMY_CLASSES: Array[int] = [EnemyDef.EnemyClass.WILD, EnemyDef.EnemyClass.BOSS]

## MVP-only enemy tier value. `tier != 1` → advisory warning (AC-ED-13a).
const ENEMY_MVP_TIER := 1

## Maximum `skills` array size before an advisory warning (TR-edb-019). Size > 4
## is legal content (not a hard error) — it merely exceeds the MVP design intent
## of 2–4 skills per enemy.
const ENEMY_SKILLS_MAX := 4

## `flavor_text` length cap (AC-ED-13b). 100 characters inclusive — a 100-char
## string PASSES; 101 FAILS. Named constant so a Part DB ratification of a
## different value is a one-line change. GDD source: AC-ED-13b (FLAVOR_TEXT_MAX).
const FLAVOR_TEXT_MAX := 100

## ai_profile referential seam (injected Callable). Signature: `(profile: StringName) -> bool`.
## Default is accept-all — valid until the EnemyAI autoload is implemented.
## Inject via [method set_ai_profile_checker] before calling [method validate_catalog].
## Do NOT call EnemyAI directly here — that would create a hard compile-time
## dependency on a not-yet-existing class.
var _ai_profile_checker: Callable = func(_p: StringName) -> bool: return true


## Wire the `ai_profile` referential seam so tests (and eventually the real boot)
## can inject a non-default checker. Call before [method validate_catalog].
## [param checker] must have signature `(StringName) -> bool`.
func set_ai_profile_checker(checker: Callable) -> void:
	_ai_profile_checker = checker


## Catalog-level dispatch: per-entry schema validation, plus catalog-wide id
## uniqueness. Mirrors [method _validate_consumable_catalog].
func validate_catalog(catalog: EnemyCatalog) -> void:
	_check_enemy_id_uniqueness(catalog)
	for enemy in catalog.entries:
		_validate_enemy(enemy)


## Per-enemy dispatch. A null entry is fatal and short-circuits.
func _validate_enemy(enemy: EnemyDef) -> void:
	if enemy == null:
		_error(&"content_null_entry", {"db": &"enemy"})
		return
	_check_enemy_schema_presence(enemy)
	_check_enemy_skills_count(enemy)
	_check_enemy_ai_profile(enemy)
	_check_enemy_tier(enemy)
	_check_enemy_flavor_length(enemy)
	# Story 005 — stat-block value checks
	_check_enemy_stat_structure(enemy)
	_check_enemy_stat_ranges(enemy)
	_check_enemy_wild_power_cap(enemy)
	_check_enemy_stat_unknown_keys(enemy)
	_check_enemy_stat_dead_data(enemy)


## AC-ED-01: required fields present and correctly typed.
## Checks: `id` non-empty, `display_name` non-empty, `enemy_class` ∈ {WILD,BOSS}
## (INVALID(0) = missing; any value outside {1,2} = unknown/reserved class),
## `stats` non-empty Dictionary, `skills` non-null (count checked separately),
## `ai_profile` StringName (presence only — referential seam lives in
## [method _check_enemy_ai_profile]).
## Every finding names the `enemy_id`.
func _check_enemy_schema_presence(enemy: EnemyDef) -> void:
	if enemy.id == &"":
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"id", "display_name": enemy.display_name})
	if enemy.display_name == "":
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"display_name"})
	# enemy_class: INVALID (0) is the unset sentinel; any value not in VALID_ENEMY_CLASSES
	# (which is {WILD=1, BOSS=2}) is a reserved/unknown class (ELITE/RIVAL are reserved
	# and not yet declared in EnemyClass, so they can only appear as INVALID=0 from
	# a stale .tres — but we guard the positive set explicitly anyway).
	if not VALID_ENEMY_CLASSES.has(int(enemy.enemy_class)):
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"enemy_class", "value": int(enemy.enemy_class)})
	if enemy.stats.is_empty():
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"stats"})


## AC-ED-02: every `id` is globally unique within the catalog. Two entries sharing
## the same id → error naming the duplicate. All-unique → no error.
func _check_enemy_id_uniqueness(catalog: EnemyCatalog) -> void:
	var seen := {}
	for enemy in catalog.entries:
		if enemy == null:
			continue
		if seen.has(enemy.id):
			_error(&"content_enemy_duplicate_id", {"enemy_id": enemy.id})
		else:
			seen[enemy.id] = true


## AC-ED-03 / TR-edb-019: skills count rules.
## `skills.size() == 0` → BLOCKING error (an enemy must have ≥1 skill to act);
## `skills.size() > ENEMY_SKILLS_MAX (4)` → ADVISORY warning (exceeds MVP intent).
## Size 1..4 → clean. The discriminating boundary: size 4 is clean, size 5 warns.
func _check_enemy_skills_count(enemy: EnemyDef) -> void:
	if enemy.skills.size() == 0:
		_error(&"content_enemy_skills_empty", {"enemy_id": enemy.id})
	elif enemy.skills.size() > ENEMY_SKILLS_MAX:
		_warn(&"content_enemy_skills_excess",
			{"enemy_id": enemy.id, "count": enemy.skills.size(), "max": ENEMY_SKILLS_MAX})


## AC-ED-03 / AC-ED-01(d): ai_profile checks.
## (1) Non-empty: `ai_profile == &""` → BLOCKING error.
## (2) Referential seam: a non-empty ai_profile is passed to the injected
##     `_ai_profile_checker` Callable. Default is accept-all (seam is inert until
##     the EnemyAI epic ships). Inject a reject-all Callable in tests to prove
##     the seam is wired — a non-empty ai_profile then errors with
##     `content_enemy_ai_profile_missing`.
func _check_enemy_ai_profile(enemy: EnemyDef) -> void:
	if enemy.ai_profile == &"":
		_error(&"content_enemy_ai_profile_missing",
			{"enemy_id": enemy.id, "reason": &"empty"})
		return
	# Seam: referential check via injected Callable. Default=accept-all until EnemyAI exists.
	if not _ai_profile_checker.call(enemy.ai_profile):
		_error(&"content_enemy_ai_profile_missing",
			{"enemy_id": enemy.id, "ai_profile": enemy.ai_profile, "reason": &"not_registered"})


## AC-ED-13a (ADVISORY): `tier != 1` → warning. Only tier 1 is live in MVP; higher
## tiers are reserved for Full Vision. A warning (never fatal) so the content
## pipeline can flag reserved-tier authoring without blocking the CI gate.
func _check_enemy_tier(enemy: EnemyDef) -> void:
	if enemy.tier != ENEMY_MVP_TIER:
		_warn(&"content_enemy_tier_reserved",
			{"enemy_id": enemy.id, "tier": enemy.tier, "expected": ENEMY_MVP_TIER})


## AC-ED-13b (BLOCKING): `flavor_text.length() > FLAVOR_TEXT_MAX` → error naming
## the `enemy_id`. A 100-char string PASSES; a 101-char string FAILS (boundary is
## inclusive ≤ 100). Empty flavor_text (length 0) passes this check; schema
## presence is [method _check_enemy_schema_presence]'s concern.
func _check_enemy_flavor_length(enemy: EnemyDef) -> void:
	if enemy.flavor_text.length() > FLAVOR_TEXT_MAX:
		_error(&"content_enemy_flavor_text_too_long",
			{"enemy_id": enemy.id, "length": enemy.flavor_text.length(), "max": FLAVOR_TEXT_MAX})


# ---------------------------------------------------------------------------
# Enemy-DB Story 005 — Enemy stat-block value family
# ---------------------------------------------------------------------------

## The four A/D stats that must stay within [STAT_AD_MIN, STAT_AD_MAX] per DF-1.
## `structure` is the HP pool and is NOT in this list (see GDD Rule 3 — structure
## is exempt from the [0,110] constraint). `mobility`, `processing`, and
## `output_power` have no hard content-validator bounds in this story.
## GDD source: Rule 3 — "physical_power, energy_power, armor, and resistance must
## stay within [0, 110]."
const STAT_AD_KEYS: Array[StringName] = [
	&"armor", &"resistance", &"physical_power", &"energy_power"
]

## Inclusive lower bound for A/D stats. 0 is a legal authored value (EC-ED-06:
## "physical_power = 0 is legal enemy content"). GDD source: Rule 3 "[0, 110]".
const STAT_AD_MIN := 0

## Inclusive upper bound for A/D stats. 110 PASSES; 111 FAILS. AC-ED-05(b):
## "implement as <= 110, not < 110". GDD source: Rule 3 "[0, 110]".
const STAT_AD_MAX := 110

## WILD power cap — physical_power and energy_power must not exceed this value
## for WILD enemies. GDD source: Tuning Knobs — WILD_POWER_CAP = 39.
## Derivation (GDD Rule 3): at A=40, D=0, T=1.5 → floor(1600/40 × 1.5) = 60 ≥ 60
## (one-shot); at A=39 → floor(1521/39 × 1.5) = 58 < 60 (no one-shot).
const WILD_POWER_CAP := 39

## The two power stats governed by the WILD_POWER_CAP. Both channels are checked
## independently (GDD Rule 3: "physical_power AND energy_power must not exceed 39").
const WILD_POWER_KEYS: Array[StringName] = [&"physical_power", &"energy_power"]

## The canonical 11-stat allow-list (TR-edb-011). Keys matching Part DB Rule 4
## vocabulary. An unknown key → ADVISORY warn. GDD source: Rule 3 — "identical
## 11-stat vocabulary from Part Database Rule 4". Same order as enemy_def.gd doc.
const STAT_ALLOW_LIST: Array[StringName] = [
	&"structure", &"armor", &"resistance", &"physical_power", &"energy_power",
	&"mobility", &"processing", &"cooling", &"energy_capacity", &"recharge",
	&"output_power",
]

## Dead-data keys: enemies have no Heat or Energy systems in MVP (TBC Rule 8 /
## TR-edb-012). Non-zero values for these are authored by mistake — warn.
## GDD source: Rule 3 dead-data note — "cooling, energy_capacity, and recharge
## keys are dead data in enemy stat blocks for MVP."
const DEAD_DATA_KEYS: Array[StringName] = [
	&"cooling", &"energy_capacity", &"recharge"
]


## AC-ED-05(a) — `structure` must be ≥ 1. A value of 0 (or absent key → defaults
## to 0 via .get) means the enemy has no HP pool and dies on contact — never valid
## content (EC-ED-06). Uses safe `.get` access: a missing key is treated as 0 and
## fails here (not a crash). Story 004 owns `stats` *presence*; this method owns
## the *value* of `structure`. Named constant `STAT_AD_MIN` does not apply here —
## structure has its own semantics (HP pool, not an A/D input).
func _check_enemy_stat_structure(enemy: EnemyDef) -> void:
	var structure: int = enemy.stats.get("structure", 0)
	if structure < 1:
		_error(&"content_enemy_stat_structure_invalid", {"enemy_id": enemy.id, "value": structure})


## AC-ED-05(b) — armor, resistance, physical_power, energy_power ∈ [STAT_AD_MIN,
## STAT_AD_MAX] (inclusive [0, 110]). Boundaries 0 and 110 PASS; 111 fails; -1
## fails. Uses safe `.get(key, 0)` — a missing key is 0 and passes (Story 004
## owns presence; here a missing key yields 0, which is in-range). Error names
## both the stat key and the enemy id so the author knows which stat to fix.
func _check_enemy_stat_ranges(enemy: EnemyDef) -> void:
	for stat_key: StringName in STAT_AD_KEYS:
		var value: int = enemy.stats.get(stat_key, 0)
		if value < STAT_AD_MIN or value > STAT_AD_MAX:
			_error(&"content_enemy_stat_out_of_range",
				{"enemy_id": enemy.id, "stat": stat_key, "value": value,
				"min": STAT_AD_MIN, "max": STAT_AD_MAX})


## AC-ED-05(c/d) — WILD power cap. Only fires when `enemy_class == WILD`; BOSS
## entries are explicitly exempt (GDD Rule 3: "BOSS power is exempt, up to 70").
## Checks both `physical_power` and `energy_power`. A WILD with power = 39 PASSES
## (boundary is inclusive ≤ 39); power = 40 FAILS. Uses safe `.get(key, 0)`.
func _check_enemy_wild_power_cap(enemy: EnemyDef) -> void:
	if enemy.enemy_class != EnemyDef.EnemyClass.WILD:
		return
	for power_key: StringName in WILD_POWER_KEYS:
		var value: int = enemy.stats.get(power_key, 0)
		if value > WILD_POWER_CAP:
			_error(&"content_enemy_stat_wild_power_cap",
				{"enemy_id": enemy.id, "stat": power_key, "value": value,
				"cap": WILD_POWER_CAP})


## TR-edb-011 (ADVISORY) — any `stats` key not in the 11-stat allow-list is a
## likely typo (e.g., `"powr"` instead of `"physical_power"`). Warns with the
## unknown key name so the author can correct it. Unknown keys are otherwise
## ignored per GDD Rule 3 / Part DB EC-08: "warn and ignore."
func _check_enemy_stat_unknown_keys(enemy: EnemyDef) -> void:
	for key: String in enemy.stats.keys():
		var sn_key: StringName = StringName(key)
		if not STAT_ALLOW_LIST.has(sn_key):
			_warn(&"content_enemy_stat_unknown_key",
				{"enemy_id": enemy.id, "key": sn_key})


## TR-edb-012 (ADVISORY) — cooling, energy_capacity, and recharge are dead data
## in enemy stat blocks (TBC Rule 8: enemies track no Heat or Energy). A non-zero
## value means the author copied from a Part def without clearing enemy-irrelevant
## fields. Warns per offending key. Zero values (the correct authored state) are
## silently accepted. Uses `.get(key, 0)` — absent key is 0 and passes.
func _check_enemy_stat_dead_data(enemy: EnemyDef) -> void:
	for dd_key: StringName in DEAD_DATA_KEYS:
		var value: int = enemy.stats.get(dd_key, 0)
		if value != 0:
			_warn(&"content_enemy_stat_dead_data",
				{"enemy_id": enemy.id, "stat": dd_key, "value": value})
