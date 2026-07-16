## EnemyDef — immutable definition of a single enemy combatant (TR-edb-001).
##
## The Enemy Database stores one EnemyDef per enemy type. This class is the typed
## schema that Turn-Based Combat's battle initialiser, the Drop System, Encounter
## Zone pools, and the ContentValidator all type against. It holds no runtime state:
## current HP, active break events, and in-progress drop rolls are all owned by
## TBC's BattleContext, never stored here.
##
## It is a frozen shared instance — never mutate fields at runtime and never call
## duplicate() or duplicate_deep() on a def (ADR-0003, ADR-0001).
##
## Cross-DB references are StringName IDs; &"" is the null-equivalent for any
## nullable StringName field (GDScript @export cannot express StringName | null).
## Each nullable field carries a doc comment stating that empty means "none".
##
## The `core_element` field reuses PartDef.Element (single enum source of truth).
## The INVALID (0) sentinel means "no elemental affinity", which is a legal
## authored state — null-element enemies are supported by the combat resolver.
##
## Enum fields default to 0 (reserved/invalid sentinel per ADR-0003) so stale or
## unset .tres slots are caught by the ContentValidator (Story 004). Enum values
## are APPEND-ONLY — never reorder, insert, or renumber existing entries; .tres
## stores raw integers and renumbering silently re-labels authored content.
class_name EnemyDef
extends Resource

## Combat class of this enemy, determining loot rules, AI behaviour, and
## region-break constraints. Values are APPEND-ONLY.
## ELITE and RIVAL are reserved for Full Vision — do NOT add them until their
## systems are implemented. Defaults to 0 (reserved/invalid sentinel).
enum EnemyClass {
	INVALID = 0,  ## Reserved/unset sentinel — no authored enemy should carry this value.
	WILD    = 1,  ## Standard wild combatant. Power capped per GDD (anti-one-shot rule).
	BOSS    = 2,  ## Boss enemy. Two break-region guarantee; 12–18 TTK band.
	# ELITE = 3,  ## Reserved for Full Vision — not declared yet.
	# RIVAL = 4,  ## Reserved for Full Vision — not declared yet.
}

# ---------------------------------------------------------------------------
# Identity & display
# ---------------------------------------------------------------------------

## Unique identifier for this enemy type (e.g. &"rust_hound"). Must be globally
## unique within the EnemyCatalog — enforced at load time by EnemyDB (Story 002).
## &"" is the null-equivalent / invalid id sentinel.
@export var id: StringName = &""

## Player-visible name shown in the Battle UI, Encounter summaries, and Lore.
@export var display_name: String = ""

# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

## Combat class. Defaults to INVALID (0) so an unset .tres entry is caught by
## the ContentValidator (Story 004).
@export var enemy_class: EnemyClass = EnemyClass.INVALID

## Content tier. Must equal 1 for all MVP entries — other tiers are reserved for
## Full Vision (AC-ED-16 MVP-legality check). The ContentValidator enforces
## tier == 1 (Story 008). Default: 1 (the only legal MVP value).
@export var tier: int = 1

## Elemental affinity of this enemy, reusing PartDef.Element (single enum
## source of truth). 0 (the enum default / unset sentinel) means "no elemental
## affinity" — a null-element enemy is a legal authored state, not a bug.
## The element affects elemental-weakness damage routing (damage_formula.gd).
## MVP values: VOLT=1, THERMAL=2, KINETIC=3. CRYO/CORROSIVE/DATA are reserved.
@export var core_element: PartDef.Element = 0

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

## The 11-stat combat block for this enemy (TR-edb-011). Keys use the canonical
## Part-DB vocabulary (String keys, not StringName — matching the authored .tres
## convention for untyped Dictionary fields):
##
##   "structure"       — total HP pool. Attack/defence stats constrained [0,110] (DF-1).
##   "armor"           — flat physical damage reduction. Range [0,110].
##   "resistance"      — flat energy damage reduction. Range [0,110].
##   "physical_power"  — physical attack output scalar. Range [0,110].
##   "energy_power"    — energy attack output scalar. Range [0,110].
##   "mobility"        — initiative / turn-order weight. Range [0,110].
##   "processing"      — AI decision quality modifier. Range [0,110].
##   "cooling"         — dead-data key: enemies have no heat system. Author 0;
##                       the ContentValidator (Story 005) emits a warning if
##                       this key is non-zero.
##   "energy_capacity" — dead-data key: enemies have no energy gauge. Author 0;
##                       warned by Story 005 if non-zero.
##   "recharge"        — dead-data key: enemies have no recharge mechanic. Author 0;
##                       warned by Story 005 if non-zero.
##   "output_power"    — composite output power (reserved for Full Vision —
##                       author 0 in MVP).
##
## Range validation ([0,110] for A/D stats) is enforced by ContentValidator
## Story 005, not here. Defaults to {} (empty, caught by Story 004 AC-ED-06).
@export var stats: Dictionary = {}

# ---------------------------------------------------------------------------
# Skills & AI
# ---------------------------------------------------------------------------

## IDs of MoveDef entries this enemy may use in combat. References the MoveDB
## (cross-DB StringName ID). &"" entries are invalid; validator enforced in
## Story 006. An empty array is valid only if the AI profile implements a
## built-in no-move behaviour.
@export var skills: Array[StringName] = []

## ID of the AI behaviour profile governing this enemy's decision making.
## References the AI profile registry (not a separate DB — string key only).
## &"" = no profile / use default AI. Validator enforced in Story 007.
@export var ai_profile: StringName = &""

# ---------------------------------------------------------------------------
# Break regions
# ---------------------------------------------------------------------------

## Destructible regions on this enemy body (TR-edb-014). Each entry is a
## Dictionary with String keys (NOT StringName — matches the authored .tres
## convention for untyped Dictionary entries):
##
##   "region_id"        : String  — unique identifier within this enemy's regions
##                                  (e.g. "left_arm"). Vocabulary validated by
##                                  the ContentValidator (Story 006).
##   "region_fraction"  : float   — fraction of max structure that this region's
##                                  HP represents. Legal range [0.15, 0.55]
##                                  (TR-edb-014). Documented here; validated by
##                                  Story 005 (EDB-1 derivation) and Story 004.
##   "break_hp"         : int     — derived HP threshold at which this region
##                                  breaks. Computed by EDB-1 (Story 003):
##                                  max(5, floor(structure × region_fraction + 0.0001)).
##                                  The +0.0001 epsilon is load-bearing (F2b class
##                                  of float-floor hazard). Stored and validated
##                                  against the formula by Story 005.
##   "break_event"      : String  — vocabulary key linking this region to its
##                                  loot_pool drop_condition entries. Every
##                                  break_event must match ≥1 drop_condition in
##                                  loot_pool (Story 006 validator AC-ED-10).
##   Loot linkage keys (optional, shape validated in Story 006):
##   "loot_min"         : int     — minimum extra drop count on region break.
##   "loot_max"         : int     — maximum extra drop count on region break.
##
## BOSS enemies require ≥2 break_regions (AC-ED-15 / Story 004).
## WILD loot_pool.size() must exceed break_regions.size() (AC-ED-15c / Story 006).
## Defaults to [] (empty, caught by ContentValidator Story 004 for BOSS entries).
@export var break_regions: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# Loot
# ---------------------------------------------------------------------------

## The loot table entries for this enemy. Each entry is a Dictionary with
## String keys (NOT StringName — authored .tres convention):
##
##   "id"             : String  — ID of the PartDef (or consumable) this entry
##                                awards. Cross-DB reference; validated by Story
##                                006 (referential integrity check).
##   "drop_condition" : String  — condition key for conditional drops. Matches
##                                vocabulary in break_regions "break_event" keys.
##                                Empty String = always eligible (base drop).
##   "break_event"    : String  — alternative linkage key to a specific region
##                                break. Matches "break_event" in break_regions.
##                                Empty = not break-conditional.
##   "enabled"        : bool    — whether this drop is active. false = retired
##                                entry; remains in authored data but never rolls.
##
## WILD loot_pool.size() must exceed break_regions.size() (AC-ED-15c).
## Defaults to [] (empty, caught by ContentValidator Story 006).
@export var loot_pool: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# Spawn & meta
# ---------------------------------------------------------------------------

## Whether this enemy appears in Encounter Zone spawn pools.
## false = retired from encounter tables; existing battle references remain valid.
@export var spawn_enabled: bool = true

## One-line lore description shown in the Battle UI and Bestiary (Full Vision).
@export var flavor_text: String = ""

# ---------------------------------------------------------------------------
# Core Progression / ELZS fields (ELZS erratum 2026-07-16)
# ---------------------------------------------------------------------------

## The effective level of this enemy, used by CP-F4 to compute xp_value and
## for TTK-band calibration (AC-ED-14). Legal range: ≥ 1. Validated by Story
## 008 (AC-ED-16 ELZS fields check). Default 1.
@export var level: int = 1

## XP awarded to the player's Symbot Core on defeating this enemy. Stored and
## derived (CP-F4): (35 + level × 10) × role_mult where role_mult is WILD=1.0,
## BOSS=2.0. The ContentValidator (Story 008) asserts stored == derived.
## Default 0 (sentinel — unset entries caught by Story 008).
@export var xp_value: int = 0

## Bonus XP awarded on first defeat of this enemy (completion bonus). Separate
## from xp_value; not covered by CP-F4. Author explicitly; validated by Story 008
## for positive-integer invariant. Default 0.
@export var completion_bonus_xp: int = 0
