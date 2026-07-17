## BossEncounter — one boss and how the player earns first-access to it (Rule 6).
##
## A typed, `.tres`-backed value object read read-only through the content catalog
## (ADR-0003). This story (001) declares the FIELD SHAPES only; the gate-evaluation
## LOGIC that consumes them lives in Stories 005 (WIN_COUNT first-access + sequencing),
## 006 (repeat policy), and 007 (gate-param validation + reserved-gate fail-safe).
##
## Enum members are APPEND-ONLY — `.tres` stores raw ints, so reordering silently
## re-labels authored content. Enum default 0 = INVALID sentinel, caught by the
## Story 008 / Story 007 validators.
class_name BossEncounter
extends Resource

## Where the boss lives (Rule 6). MVP authors OVERWORLD only; DUNGEON/HIDDEN are
## reserved (need spatial systems that do not exist yet). APPEND-ONLY.
enum Placement {
	INVALID   = 0,  ## Reserved/unset sentinel.
	OVERWORLD = 1,  ## MVP: the only authored placement.
	DUNGEON   = 2,  ## Reserved (Zone & World Map #12).
	HIDDEN    = 3,  ## Reserved.
}

## How first-access is earned — the reward-vector taxonomy (Rule 7). MVP fills two
## (OPEN, WIN_COUNT); WAVE/REACH/DUNGEON_RUSH keep their values reserved so the
## schema never changes when they ship. A reserved gate authored in MVP content is a
## fail-safe LOCKED (Story 007). APPEND-ONLY.
enum GateType {
	INVALID      = 0,  ## Reserved/unset sentinel — fail-safe LOCKED (Story 007).
	OPEN         = 1,  ## Always accessible — no gate.
	WIN_COUNT    = 2,  ## MVP: grind N WILD wins (shared cumulative counter, Rule 8a).
	WAVE         = 3,  ## Reserved (arena gauntlet).
	REACH        = 4,  ## Reserved (spatial).
	DUNGEON_RUSH = 5,  ## Reserved (spatial).
}

## Re-access model after first defeat (Rule 9). MVP default LIGHTER_REGATE.
## APPEND-ONLY.
enum RepeatPolicy {
	INVALID        = 0,  ## Reserved/unset sentinel.
	LIGHTER_REGATE = 1,  ## MVP default: repeatable behind a reduced, delta-measured gate.
	ALWAYS_OPEN    = 2,  ## Permanently accessible after first clear.
	FULL_REGATE    = 3,  ## Reserved: re-pay the original gate every time.
}

## References an Enemy DB entry with `enemy_class == BOSS`. &"" = invalid sentinel.
@export var boss_id: StringName = &""

## Where the boss lives (Rule 6). Defaults to INVALID (0).
@export var placement: Placement = Placement.INVALID

## First-access gate type (Rule 7). Defaults to INVALID (0) — a fail-safe LOCKED
## state (Story 007), never fail-open.
@export var gate_type: GateType = GateType.INVALID

## First-access gate parameters (Rule 8). MVP: `{ required_wins: int }` for WIN_COUNT,
## plus optional `requires_defeated: StringName` naming a prerequisite `boss_id` (the
## Rule 8 sequencing precondition). OPEN uses `{}`. Consumed by Stories 005/007.
@export var gate_params: Dictionary = {}

## Re-access gate parameters, parallel to `gate_params` (Rule 6/9). MVP:
## `{ required_wins: int }`, read only under LIGHTER_REGATE and measured as a DELTA
## against `wins_at_last_defeat` (Rule 8a). Must be strictly lighter than
## `gate_params` and >= 1. Consumed by Story 006.
@export var regate_params: Dictionary = {}

## Re-access policy after first defeat (Rule 9). Defaults to INVALID (0).
@export var repeat_policy: RepeatPolicy = RepeatPolicy.INVALID
