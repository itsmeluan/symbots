## MoveDef — immutable definition of a single move (MOVE-CONTRACT-1, ratified).
##
## The Move Database stores one MoveDef per move. This class is the typed schema
## that Assembly (to populate a build's move pool) and Turn-Based Combat (to
## resolve a used move) type against. Where PartDef defines what a part *is*,
## MoveDef defines what a part *does* when its skill fires. It holds no runtime
## state — turn resolution, resource spending, and the damage math all live in
## Turn-Based Combat; MoveDef supplies only the static contract each move obeys.
##
## It is a frozen shared instance — never mutate fields at runtime and never call
## duplicate() or duplicate_deep() on a def (ADR-0003, ADR-0001).
##
## Cross-DB references are StringName IDs; &"" is the null-equivalent (GDScript
## @export cannot express StringName | null). Enum fields default to 0
## (reserved/invalid sentinel per ADR-0003) so that stale/unset .tres slots are
## caught by the ContentValidator (Stories 004/005) — the single exception is
## break_bias, whose meaningful default is BALANCED (Rule 1 / Rule 4).
##
## Element and DamageType are reused from PartDef so the Part and Move DBs share a
## single enum source of truth (Rule 1: a move's element/damage_type derive from
## the owning part in MVP).
class_name MoveDef
extends Resource

## Move behavior class (Rule 2). Governs which fields are meaningful and how
## Turn-Based Combat resolves the move.
## Values are APPEND-ONLY — never reorder, insert, or renumber existing entries;
## .tres stores raw integers and renumbering silently re-labels authored content.
enum Behavior {
	DAMAGE  = 1,
	STATUS  = 2,
	REPAIR  = 3,
	SCAN    = 4,
	UTILITY = 5,
}

## Power tier for DAMAGE moves — maps to the MOVE-F1 multiplier and the expected
## energy-cost band (Rule 3). BASIC is the built-in Basic Attack tier (Rule 4,
## mult 0.70); the GDD Rule 1 table omits it because it is engine-registered, not
## authored, but it IS a real tier value (TR-mdb-002 lists five multipliers).
## Tiers must stay strictly ordered BASIC < LIGHT < STANDARD < HEAVY < SIGNATURE.
## null-equivalent (0) for non-DAMAGE behaviors.
## Values are APPEND-ONLY — never reorder, insert, or renumber.
enum PowerTier {
	BASIC     = 1,
	LIGHT     = 2,
	STANDARD  = 3,
	HEAVY     = 4,
	SIGNATURE = 5,
}

## Move targeting (Rule 1). Region sub-targeting within ENEMY is the Part-Break
## System's layer, not a move field.
## Values are APPEND-ONLY — never reorder, insert, or renumber.
enum Targeting {
	ENEMY = 1,
	SELF  = 2,
}

## Break bias for DAMAGE+ENEMY moves — maps to a (structure_mult, break_mult)
## pair via Part-Break's BREAK_BIAS_MULTIPLIERS table (Part-Break Rule 3). The
## multiplier VALUES are owned by Part-Break; the Move DB references the enum
## only. Default is BALANCED (Rule 1 / Rule 4 Basic Attack). Ignored for
## non-DAMAGE or SELF-targeted moves.
## Values are APPEND-ONLY — never reorder, insert, or renumber.
enum BreakBias {
	STRUCTURE_HEAVY = 1,
	BALANCED        = 2,
	BREAK_HEAVY     = 3,
}

## Payload delivered by a SCAN move (Rule 6). BREAK_REGIONS reveals the enemy's
## break_regions + drop hints for the rest of the battle (Enemy DB ED6).
## null-equivalent (0) for non-SCAN behaviors.
## Values are APPEND-ONLY — never reorder, insert, or renumber.
enum ScanPayload {
	BREAK_REGIONS = 1,
}

# ---------------------------------------------------------------------------
# Identifiers
# ---------------------------------------------------------------------------

## Unique identifier for this move (e.g. &"boltwell_arc_bolt"). Referenced by a
## part's active_skill_id. Must be globally unique within the MoveCatalog —
## enforced at load time by MoveDB (Story 002).
@export var id: StringName = &""

## Player-visible name shown in the Combat UI move panel.
@export var display_name: String = ""

# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

## Behavior class (Rule 2). Defaults to 0 (reserved/invalid) so an unset .tres
## entry is caught by the ContentValidator (Story 004).
@export var behavior: Behavior = 0

## Power tier (Rule 3) — meaningful only for DAMAGE moves. Defaults to 0
## (reserved/invalid, the "null" for non-DAMAGE behaviors). Validation (Story
## 004/005) enforces a non-null power_tier on DAMAGE moves.
@export var power_tier: PowerTier = 0

## Damage type delivered by this move. From the owning part's damage_type in MVP
## (DF constraint DF1). MVP values: PHYSICAL, ENERGY. Defaults to 0 (reserved/
## "null" for non-DAMAGE). Reuses PartDef.DamageType (single enum source of truth).
@export var damage_type: PartDef.DamageType = 0

## Elemental affinity — drives type effectiveness and status identity. From the
## owning part's element in MVP. MVP values: VOLT, THERMAL, KINETIC. Defaults to
## 0 (reserved/invalid). Reuses PartDef.Element (single enum source of truth).
@export var element: PartDef.Element = 0

# ---------------------------------------------------------------------------
# Cost & effects
# ---------------------------------------------------------------------------

## Energy cost to use this move (0–40). Must fall in the power_tier's band for
## DAMAGE moves (Rule 3); REPAIR moves author > BASE_ENERGY_REGEN as an anti-stall
## brake (Rule 7). Band/floor validation enforced by ContentValidator (Story 005).
@export var energy_cost: int = 0

## Status application for STATUS moves, shape { status_id: StringName,
## duration: int }. STATUS moves apply it guaranteed on hit (Rule 5); its
## status_id must match this move's element (Volt→Shock, Thermal→Burn,
## Kinetic→Stagger). DAMAGE moves carry riders only via passives, never innately —
## so a non-STATUS move leaves this empty. Defaults to {} (the null-equivalent).
## Element-match + no-innate-rider validation enforced by ContentValidator (Story 005).
@export var status_proc: Dictionary = {}

# ---------------------------------------------------------------------------
# Targeting & break routing
# ---------------------------------------------------------------------------

## Move targeting (Rule 1). Defaults to 0 (reserved/invalid) so an unset .tres
## entry is caught by the ContentValidator. UTILITY Vent and REPAIR author SELF;
## DAMAGE and most STATUS author ENEMY.
@export var targeting: Targeting = 0

## Break bias for DAMAGE+ENEMY moves (Part-Break Rule 3). Defaults to BALANCED
## (Rule 1) — the one enum field with a meaningful non-sentinel default.
## Ignored for non-DAMAGE / SELF-targeted moves. When target_profile is set it
## replaces break_bias (a move is single-bias OR profiled, never both).
@export var break_bias: BreakBias = BreakBias.BALANCED

# ---------------------------------------------------------------------------
# Behavior-specific payloads
# ---------------------------------------------------------------------------

## SCAN payload (Rule 6). BREAK_REGIONS reveals enemy break_regions + drop hints.
## Defaults to 0 (the null-equivalent) — meaningful only for SCAN moves.
@export var scan_payload: ScanPayload = 0

## Heat removed by a UTILITY Vent move (Rule 8), floored at 0 by TBC at runtime.
## 0 = not a Vent move (the null-equivalent). Tuning range 15–45 (GDD Tuning Knobs).
@export var vent_amount: int = 0

# ---------------------------------------------------------------------------
# Reserved for Full Vision (empty in MVP)
# ---------------------------------------------------------------------------

## Reserved multi-hit extension hook (Part-Break Rule 11): an ordered list of
## (target, damage_mult) sub-hits. When present it replaces break_bias for the
## move. Reserved per the Part-Break erratum (2026-07-11) — no MVP move authors
## it; defaults to [] (the null-equivalent).
@export var target_profile: Array = []
