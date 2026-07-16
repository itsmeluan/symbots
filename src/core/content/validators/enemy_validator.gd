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
