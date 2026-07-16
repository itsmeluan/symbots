## PassiveDef — immutable definition of a single part passive (PASSIVE-CONTRACT-1).
##
## The Passive Database stores one PassiveDef per passive. This class is the typed
## schema that the Part Database (whose `passive_id` fields reference these ids),
## Turn-Based Combat's Rule 13 registry (which executes them), and the Workshop UI
## (which displays their text) type against. Where MoveDef defines what a part
## *does* when its skill fires, PassiveDef defines what a part *is always doing* —
## the automatic, persistent behaviour a part contributes to a build. It holds no
## runtime state: which passives are currently active on a combatant, and whether a
## trigger has fired this turn, are runtime state owned by Turn-Based Combat.
##
## It is a frozen shared instance — never mutate fields at runtime and never call
## duplicate() or duplicate_deep() on a def (ADR-0003).
##
## `heat_generation` and `energy_cost` are deliberately ABSENT (GDD Rule 1):
## passives fire automatically and consume no player resources — those fields live
## on the Part, not here. A well-formed passive carries no such property (AC-PDB-03).
##
## Enum fields default to 0 (reserved/invalid sentinel per ADR-0003) so a stale or
## unset .tres slot is caught by the ContentValidator (Stories 004/005). Enum values
## are APPEND-ONLY — never reorder, insert, or renumber existing entries; .tres
## stores raw integers and renumbering silently re-labels authored content.
class_name PassiveDef
extends Resource

## What the passive does (GDD Rule 3). **This is the authoritative resolution axis** —
## TBC's Rule 13 executor branches on `behavior_class`, not `passive_class` — and it
## also determines the `behavior_params` key set (Rule 3a) and the default
## `stacking_policy` (Rule 4, see [method default_stacking_policy]).
## Values are APPEND-ONLY.
enum BehaviorClass {
	STATUS_RIDER      = 1,
	STAT_AURA         = 2,
	RESOURCE_EFFECT   = 3,
	STRUCTURAL_EFFECT = 4,
}

## When the passive fires (GDD Rule 2). Mirrors TBC's Rule 13 trigger enum exactly —
## it is the shared vocabulary, not an independent spec. There is no `ON_WEAPON_HIT`:
## weapon narrowing is the `scope` field on an `ON_HIT` trigger. `PERSISTENT` is not
## an event trigger but an application mode (applied once at BATTLE_INIT, held for the
## battle). Legal trigger×behavior pairings are enforced by the validator (Story 004).
## Values are APPEND-ONLY.
enum TriggerCategory {
	ON_HIT          = 1,
	ON_TURN_START   = 2,
	ON_BATTLE_START = 3,
	ON_OVERHEAT     = 4,
	PERSISTENT      = 5,
}

## The move-slot filter for `ON_HIT` triggers (GDD Rule 1): `ANY_DAMAGE` fires on any
## DAMAGE move, `WEAPON_ONLY` only on WEAPON-slot DAMAGE moves. Meaningful only for
## `STATUS_RIDER` / `ON_HIT`; the null-equivalent (0) for all non-`ON_HIT` triggers.
## Values are APPEND-ONLY.
enum Scope {
	ANY_DAMAGE  = 1,
	WEAPON_ONLY = 2,
}

## How TBC handles the same passive id arriving from multiple sources (GDD Rule 4).
## Authored per entry but derived from `behavior_class` by default (Story 003,
## [method default_stacking_policy]); the validator flags a mismatch (Story 004).
## Values are APPEND-ONLY.
enum StackingPolicy {
	UNIQUE_PER_TRIGGER = 1,
	UNIQUE             = 2,
	STACKABLE          = 3,
}

## Pure authoring/display metadata (GDD Rule 1). It does NOT change resolution and
## does NOT derive stacking (Rule 4 keys on `behavior_class`); it is consumed only by
## content-validation tooling (the Core-trigger rule, Story 005 / AC-PDB-12) and by
## Workshop UI display. Shares the token STATUS_RIDER with [enum BehaviorClass] but
## is a different axis — `behavior_class` answers what the effect does, `passive_class`
## answers what authoring role the passive plays.
## Values are APPEND-ONLY.
enum PassiveClass {
	STATUS_RIDER    = 1,
	CORE_TRAIT      = 2,
	UPGRADE_PASSIVE = 3,
}

# ---------------------------------------------------------------------------
# Identity & display
# ---------------------------------------------------------------------------

## Unique identifier for this passive (e.g. &"volt_shock_on_hit"). Referenced by a
## part's `passive_id`, a Synergy tier `effects` array, or a Move DB SKILL_ENHANCE
## upgrade. Must be globally unique within the PassiveCatalog — enforced at load
## time by PassiveDB (Story 002).
@export var id: StringName = &""

## Player-visible passive name shown in the Workshop and the battle proc log.
@export var display_name: String = ""

## 1–2 sentence player-facing description of what the passive does. For a Prototype
## Core passive this names the expected tradeoff (GDD Rule 6, constraint 3).
@export var short_description: String = ""

# ---------------------------------------------------------------------------
# Classification (the two axes — see the enum doc-comments)
# ---------------------------------------------------------------------------

## When the passive fires (Rule 2). Defaults to 0 (reserved/invalid) so an unset
## .tres entry is caught by the ContentValidator (Story 004).
@export var trigger_category: TriggerCategory = 0

## What the passive does (Rule 3) — the runtime resolution axis. Defaults to 0
## (reserved/invalid). Governs the legal `trigger_category` set (Story 004), the
## `behavior_params` key set (Story 005), and the default `stacking_policy` (Story 003).
@export var behavior_class: BehaviorClass = 0

## The `ON_HIT` move-slot filter (Rule 1). Defaults to 0 (the null-equivalent for all
## non-`ON_HIT` triggers). Meaningful only when `trigger_category == ON_HIT`.
@export var scope: Scope = 0

## How duplicate sources of this id resolve (Rule 4). Defaults to 0 (reserved/invalid)
## so an unset entry is caught; authoring sets it to the `behavior_class` default
## (Story 003) or the validator flags a mismatch (Story 004).
@export var stacking_policy: StackingPolicy = 0

## Authoring/display metadata only (Rule 1) — never a runtime gate. Defaults to 0
## (reserved/invalid). Drives the Core-trigger authoring rule (Story 005) and Workshop UI.
@export var passive_class: PassiveClass = 0

# ---------------------------------------------------------------------------
# Behaviour payload
# ---------------------------------------------------------------------------

## The per-`behavior_class` payload holding the numeric/target data the effect needs
## (Rule 3a) — the one field whose key set varies by `behavior_class`. Untyped
## Dictionary (its keys are validated against the class in Story 005): STATUS_RIDER
## → { status_id, duration }, STAT_AURA → { stat, delta }, RESOURCE_EFFECT →
## { resource, amount }, STRUCTURAL_EFFECT → { target, amount }. Defaults to {} (the
## null-equivalent). TBC reads these keys to execute the effect; magnitude/potency is
## TBC's (TBC-F3/F4/F5), not stored here.
@export var behavior_params: Dictionary = {}

# ---------------------------------------------------------------------------
# Stacking-policy defaults (Story 003 — GDD Rule 4 / TR-pdb-004)
# ---------------------------------------------------------------------------

## The canonical `behavior_class -> StackingPolicy` default table (GDD Rule 4) — the
## single source of truth for how a passive's stacking is derived. Kept adjacent to
## the schema so a future [enum BehaviorClass] addition forces a compile-visible gap
## here. `passive_class` deliberately does NOT participate: the default keys on
## `behavior_class` only (Rule 4). The validator (Story 004) reads this to flag an
## authored `stacking_policy` that diverges from its class default. The INVALID (0)
## sentinel is intentionally absent — it maps to nothing.
##
## Every non-INVALID [enum BehaviorClass] value has exactly one entry (asserted by
## the Story 003 test: `DEFAULT_STACKING.size() == BehaviorClass.size() - 1`).
const DEFAULT_STACKING: Dictionary = {
	BehaviorClass.STATUS_RIDER: StackingPolicy.UNIQUE_PER_TRIGGER,
	BehaviorClass.STAT_AURA: StackingPolicy.UNIQUE,
	BehaviorClass.RESOURCE_EFFECT: StackingPolicy.STACKABLE,
	BehaviorClass.STRUCTURAL_EFFECT: StackingPolicy.UNIQUE,
}

## The default [enum StackingPolicy] for [param p_behavior_class] (GDD Rule 4). A pure
## lookup — same input, same output, no side effects. Returns 0 (the INVALID
## sentinel) for the reserved/0 behavior class or any value not in the table, so the
## caller can distinguish "no default" from a real policy. Both the validator (Story
## 004) and any authoring tooling read through this one function.
static func default_stacking_policy(p_behavior_class: BehaviorClass) -> StackingPolicy:
	return DEFAULT_STACKING.get(p_behavior_class, 0)
