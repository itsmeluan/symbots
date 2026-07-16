## ConsumableDef — immutable definition of a single salvage-tech consumable (TR-cdb-001).
##
## The Consumable Database stores one ConsumableDef per item. This class is the typed
## schema that Turn-Based Combat's use-item action, the Drop System's consumable
## channel, the Encounter Zone modifier hook, and the Inventory/Shop UI all type
## against. Unlike MoveDef/PassiveDef, a consumable does NOT reference the Part DB —
## the Consumable DB is its own schema authority (GDD Rule 9). It holds no runtime
## state: how many the player owns, whether a Beacon flag is set this battle, and the
## live encounter-modifier countdown are runtime state owned by the Inventory / TBC /
## Overworld contexts, never stored here.
##
## It is a frozen shared instance — never mutate fields at runtime and never call
## duplicate() or duplicate_deep() on a def (ADR-0003).
##
## `effect_params` is an *untyped* Dictionary whose key set varies per `effect_type`
## (Rule 2) — the exact keys are validated in Story 007, not enforced by the schema
## type. This deliberately mirrors PassiveDef's `behavior_params` pattern.
##
## Enum fields default to 0 (reserved/invalid sentinel per ADR-0003) so a stale or
## unset .tres slot is caught by the ContentValidator (Story 007). Enum values are
## APPEND-ONLY — never reorder, insert, or renumber existing entries; .tres stores raw
## integers and renumbering silently re-labels authored content.
class_name ConsumableDef
extends Resource

## Content rarity band (GDD Rule 1). `BOSS_GRADE` is reserved but never authored in
## MVP (AC-CD-18 flags a BOSS_GRADE consumable as a roster error). Values are
## APPEND-ONLY.
enum Rarity {
	COMMON     = 1,
	RARE       = 2,
	PROTOTYPE  = 3,
	BOSS_GRADE = 4,
}

## What the consumable does (GDD Rule 2) — the authoritative resolution axis. It also
## determines the `effect_params` key set (validated in Story 007) and the coherent
## `use_context`/`target` pairing (Story 007 advisory). Values are APPEND-ONLY.
enum EffectType {
	RESTORE_STRUCTURE     = 1,
	REDUCE_HEAT           = 2,
	RESTORE_ENERGY        = 3,
	BOOST_DROP            = 4,
	MODIFY_ENCOUNTER_RATE = 5,
}

## Where the item may be used (GDD Rule 3) — gates the pre-action validation (Story
## 004). `BOTH` is valid in either context. Values are APPEND-ONLY.
enum UseContext {
	BATTLE = 1,
	WORLD  = 2,
	BOTH   = 3,
}

## Who/what the item acts on (GDD Rule 1). Restoratives target a living team member;
## the Beacon targets the current battle; encounter modifiers target the overworld.
## Values are APPEND-ONLY.
enum Target {
	LIVING_TEAM_MEMBER = 1,
	CURRENT_BATTLE     = 2,
	OVERWORLD          = 3,
}

# ---------------------------------------------------------------------------
# Identity & display
# ---------------------------------------------------------------------------

## Unique identifier for this consumable (e.g. &"weld_patch"). Must be globally unique
## within the ConsumableCatalog — enforced at load time by ConsumableDB (Story 002).
## `&""` is the null-equivalent / invalid id.
@export var consumable_id: StringName = &""

## Player-visible item name shown in the Inventory, Shop, and use menus.
@export var display_name: String = ""

# ---------------------------------------------------------------------------
# Classification (the resolution axes — see the enum doc-comments)
# ---------------------------------------------------------------------------

## Content rarity band (Rule 1). Defaults to 0 (reserved/invalid) so an unset .tres
## entry is caught by the ContentValidator (Story 007).
@export var rarity: Rarity = 0

## What the item does (Rule 2) — the runtime resolution axis. Defaults to 0
## (reserved/invalid). Governs the `effect_params` key set and the coherent
## context/target pairing (both Story 007).
@export var effect_type: EffectType = 0

## The per-`effect_type` payload holding the numeric data the effect needs (Rule 2) —
## the one field whose key set varies by `effect_type`. Untyped Dictionary (keys
## validated against the type in Story 007): RESTORE_STRUCTURE / REDUCE_HEAT /
## RESTORE_ENERGY → { amount: int }; BOOST_DROP → { multiplier: float };
## MODIFY_ENCOUNTER_RATE → { rate_multiplier: float, duration_steps: int }. Defaults
## to {} (the null-equivalent). The runtime formulas (Stories 003/005/006) read these
## keys; caps/thresholds live on the runtime target, not here.
@export var effect_params: Dictionary = {}

## Where the item may be used (Rule 3). Defaults to 0 (reserved/invalid) so an unset
## entry is caught. Gates the use-transaction context check (Story 004).
@export var use_context: UseContext = 0

## Who/what the item acts on (Rule 1). Defaults to 0 (reserved/invalid). Its coherence
## with `use_context` is an advisory validator check (Story 007 / AC-CD-19).
@export var target: Target = 0

# ---------------------------------------------------------------------------
# Economy (authored now, inert in MVP — no shops yet; validated in Story 007)
# ---------------------------------------------------------------------------

## Maximum quantity of this item a single inventory slot may hold (GDD Rule 10 stack
## caps). Inventory overflow handling is the Inventory epic's concern (AC-CD-23), not
## this DB.
@export var max_stack: int = 1

## Shop purchase price. Must be strictly greater than `sell_price` for every entry —
## the anti-arbitrage invariant enforced by the ContentValidator (Story 007 /
## TR-cdb-006). Inert in MVP (no shops) but shipped as a typed field.
@export var buy_price: int = 0

## Shop sell-back price. Strictly less than `buy_price` (Story 007). Inert in MVP.
@export var sell_price: int = 0
