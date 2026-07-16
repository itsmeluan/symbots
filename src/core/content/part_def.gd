## PartDef — immutable definition of a single Sympart.
##
## The Part Database stores one PartDef per part type. This class is the typed
## schema that all downstream systems (Assembly, Combat, Drop, Inventory, Workshop)
## type against. It is a frozen shared instance — never mutate fields at runtime
## and never call duplicate() or duplicate_deep() on a def (ADR-0003, ADR-0001).
##
## Cross-DB references are StringName IDs; &"" is the null-equivalent (GDScript
## @export cannot express StringName | null). Each nullable field carries a doc
## comment. Enum fields default to 0 (reserved/invalid sentinel per ADR-0003) so
## that stale/unset .tres slots are caught by the ContentValidator (Story 009).
class_name PartDef
extends Resource

## Slot type this Sympart occupies on the Symbot body (Rule 2 — 8 MVP slots).
## Values are APPEND-ONLY — never reorder, insert, or renumber existing entries;
## .tres stores raw integers and renumbering silently re-labels authored content.
enum SlotType {
	CORE        = 1,
	CHASSIS     = 2,
	CHIPSET     = 3,
	ENERGY_CELL = 4,
	HEAD        = 5,
	ARMS        = 6,
	LEGS        = 7,
	WEAPON      = 8,
}

## Rarity tier controlling schema nullability rules (Rule 8).
## Values are APPEND-ONLY — never reorder, insert, or renumber.
enum Rarity {
	COMMON     = 1,
	RARE       = 2,
	BOSS_GRADE = 3,
	PROTOTYPE  = 4,
}

## Elemental affinity. VOLT, THERMAL, KINETIC are MVP values.
## CRYO, CORROSIVE, DATA are reserved for Full Vision — MVP content must never
## assign these values. Values are APPEND-ONLY — never reorder, insert, or renumber.
enum Element {
	VOLT      = 1,
	THERMAL   = 2,
	KINETIC   = 3,
	CRYO      = 4,  ## Reserved — Full Vision only.
	CORROSIVE = 5,  ## Reserved — Full Vision only.
	DATA      = 6,  ## Reserved — Full Vision only.
}

## Damage type delivered by this part's active skill. PHYSICAL and ENERGY are
## MVP values. DATA and TRUE are reserved for Full Vision.
## Values are APPEND-ONLY — never reorder, insert, or renumber.
enum DamageType {
	PHYSICAL = 1,
	ENERGY   = 2,
	DATA     = 3,  ## Reserved — Full Vision only.
	TRUE     = 4,  ## Reserved — Full Vision only.
}

## Combat role archetype for CHASSIS-slot parts (Rule 3).
## 0 (the enum default / unset sentinel) means "no archetype" — non-CHASSIS parts.
## Required when slot_type == CHASSIS; must be 0 (unset) for all other slots.
## Validator-enforced required-when-CHASSIS rule arrives in Story 009.
## Values are APPEND-ONLY — never reorder, insert, or renumber.
enum ChassisArchetype {
	LIGHT_FRAME     = 1,
	HEAVY_FRAME     = 2,
	BALANCED_FRAME  = 3,
	GUARDIAN_FRAME  = 4,
	ARTILLERY_FRAME = 5,
}

# ---------------------------------------------------------------------------
# Identifiers
# ---------------------------------------------------------------------------

## Unique identifier for this part type (e.g. &"boltwell_spark_core").
## Must be globally unique within the PartCatalog — enforced at load time by PartDB.
@export var id: StringName = &""

## Player-visible name shown in Workshop, Inventory, and Battle UI.
@export var display_name: String = ""

# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

## Slot this part occupies on the Symbot. Defaults to 0 (reserved/invalid) so
## that an unset .tres entry is caught by the ContentValidator (Story 009).
@export var slot_type: SlotType = 0

## Combat archetype for CHASSIS parts. 0 = no archetype (non-CHASSIS slot).
## Required when slot_type == CHASSIS; must be 0 otherwise.
## Validator-enforced in Story 009. Defaults to 0 (reserved/invalid sentinel).
@export var chassis_archetype: ChassisArchetype = 0

## Rarity tier (controls nullability per Rule 8). Defaults to 0 (reserved/invalid)
## so that an unset .tres entry is caught by the ContentValidator.
@export var rarity: Rarity = 0

## Manufacturer affiliation.
## Valid authored values: &"boltwell", &"ironclad", &"scrapjaw", &"wild".
## &"wild" means no manufacturer — it is a real value, not a null-equivalent.
## &"" (the default) is invalid and will be caught by the ContentValidator.
@export var manufacturer: StringName = &""

## Elemental affinity. MVP values: VOLT, THERMAL, KINETIC.
## Defaults to 0 (reserved/invalid) so an unset .tres entry is caught.
@export var element: Element = 0

## Damage type delivered by the active skill. MVP values: PHYSICAL, ENERGY.
## Defaults to 0 (reserved/invalid) so an unset .tres entry is caught.
@export var damage_type: DamageType = 0

# ---------------------------------------------------------------------------
# Stats & skills
# ---------------------------------------------------------------------------

## Stat name → flat integer bonus contributed by this part at upgrade tier +0.
## Keys are canonical stat StringNames (e.g. &"structure", &"armor").
## Scaled at upgrade tiers by Formula 2. Verified round-trip on 4.7 (Story 001).
@export var stat_bonuses: Dictionary[StringName, int] = {}

## Reference to a MoveDef entry by ID. &"" = no active skill.
## Nullability is rarity- and slot-gated — validator-enforced in Story 008.
## Core parts must never have an active skill at any rarity (Rule 8 Core exception).
@export var active_skill_id: StringName = &""

## Reference to a PassiveDef entry by ID. &"" = no passive.
## Nullability is rarity- and slot-gated — validator-enforced in Story 008.
@export var passive_id: StringName = &""

# ---------------------------------------------------------------------------
# Tags & drop
# ---------------------------------------------------------------------------

## Synergy group IDs this part belongs to (e.g. [&"volt", &"boltwell"]).
## Never empty for any authored part — at minimum carries the element tag.
## Authoring rule enforced by ContentValidator (Story 007).
@export var synergy_tags: Array[StringName] = []

## Drop-condition modifiers. Each entry is a Dictionary with shape:
##   { "condition": StringName, "multiplier": float }
## Multipliers stack multiplicatively; evaluated by the Drop System (Rule 9).
## Entry-shape enforced by ContentValidator._check_drop_condition_entries (Story 011).
@export var drop_conditions: Array[Dictionary] = []

## Whether this part appears in drop tables.
## false = retired from drops but remains valid in all existing inventories (EC-04).
@export var drop_enabled: bool = true

# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

## Maximum upgrade tier: 3 for Common, 5 for Rare/Boss-grade/Prototype (Rule 10).
@export var max_upgrade_tier: int = 3

## Per-tier skill unlocks or enhancements. Each entry has shape:
##   { "tier": int, "effect_type": StringName, "description": String,
##     "skill_id": StringName }
## effect_type ∈ { &"SKILL_UNLOCK", &"SKILL_ENHANCE" }.
## STAT_BONUS is reserved for Full Vision and must not appear in MVP content.
## Empty for Common parts and Rare+ parts with no defined unlocks (Rule 10).
## Entry-shape enforced by ContentValidator._check_upgrade_effects (Story 011);
## SKILL_UNLOCK support-slot legality enforced there too.
@export var upgrade_effects: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# Grouping & meta
# ---------------------------------------------------------------------------

## Optional grouping ID for thematic variants (e.g. &"servo_arm_family").
## &"" = unique part with no variants.
@export var part_family: StringName = &""

## Heat generated per use of active_skill. 0 if no skill or skill generates no heat.
@export var heat_generation: int = 0

## Ammo consumed per skill use. 0 if not ammo-based.
@export var ammo_cost: int = 0

## One-line lore description shown in Workshop and inventory UI.
@export var flavor_text: String = ""

## Art asset identifier used by the Symbot renderer and Workshop UI to swap the
## sprite for the affected visual zone when this part is equipped.
## Required non-empty for all parts — non-empty enforcement arrives in Story 009 (AC-24).
@export var sprite_id: StringName = &""

# ---------------------------------------------------------------------------
# Progression (Core Progression erratum 2026-07-12)
# ---------------------------------------------------------------------------

## Minimum Core level required to equip this part.
## Authoring floors by rarity: COMMON=1, RARE=3, BOSS_GRADE=6, PROTOTYPE=8.
## 0 is treated as no gate (equivalent to 1). Never lower than the rarity floor.
## Range and floor validation enforced by ContentValidator (Story 009, AC-27).
@export var level_requirement: int = 0

## Per-level flat stat bonus applied by CP-F3 (Core Progression Formula 3).
## Non-empty ONLY on CORE-slot parts — all other slots must have an empty dict.
## Key = canonical stat name (StringName, e.g. &"structure"); value = flat bonus
## per Core level. StringName keys are required: CP-F3 looks up with &"stat"
## literals and typed Dictionaries do NOT coerce String↔StringName — a
## String-keyed dict would silently return 0 growth for every stat.
## CORE-only rule enforced by ContentValidator (Story 009).
@export var level_growth: Dictionary[StringName, int] = {}

# ---------------------------------------------------------------------------
# Reserved for Full Vision (null/empty in MVP)
# ---------------------------------------------------------------------------

## Identifies which motherboard slot this part occupies (Full Vision hardware layer).
## &"" = not applicable (MVP default). TR-part-025.
@export var motherboard_slot_type: StringName = &""

## RAM budget consumed by this part when installed (Full Vision software/RAM system).
## 0 = not applicable (MVP default). TR-part-025.
@export var ram_cost: int = 0

## Weight class tier affecting mobility calculations (Full Vision weight system).
## &"" = not applicable (MVP default). TR-part-025.
@export var weight_class: StringName = &""

## Number of open modification slots on this part (Full Vision modding system).
## 0 = not applicable (MVP default). TR-part-025.
@export var modification_slots: int = 0

## Critical hit output bonus specific to this part (Full Vision crit system).
## 0 = not applicable (MVP default). TR-part-025.
@export var critical_output: int = 0

## Defensive firewall rating against DATA-type attacks (Full Vision DATA system).
## 0 = not applicable (MVP default). TR-part-025.
@export var firewall: int = 0
