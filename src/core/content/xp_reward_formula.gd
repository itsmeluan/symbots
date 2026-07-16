## XpRewardFormula — pure CP-F4 derivation for enemy XP awards (Enemy Level & Zone
## Scaling / Core Progression).
##
## One pure static function implementing GDD Formula CP-F4:
##   `xp_value = (XP_BASE + level × XP_PER_ENEMY_LEVEL) × role_multiplier`
## with `XP_BASE = 35`, `XP_PER_ENEMY_LEVEL = 10`, and the role multiplier keyed by
## class: WILD = 1, BOSS = 2 (GDD enemy-database.md Rule 1 `xp_value` row / ELZS Rule 2).
##
## [b]No epsilon[/b]: every CP-F4 term is an integer in MVP (`XP_BASE`,
## `XP_PER_ENEMY_LEVEL`, `level`, and both role multipliers), so the derivation is
## exact integer arithmetic — unlike EDB-1's float `break_hp`, there is no rounding
## boundary and no load-bearing nudge. If a future retune makes `role_multiplier`
## fractional, revisit this note and python3-verify the rounding rule before shipping.
##
## This is the single derivation path for both:
##   - Story 009 ContentValidator (`_check_enemy_xp_value` asserts authored
##     `xp_value == derive_xp_value(level, enemy_class)` — stored-equals-derived,
##     the same discipline as EDB-1's `break_hp`)
##   - The ELZS XP-award path and any authoring tool that pre-computes the value.
##
## Usage: `XpRewardFormula.derive_xp_value(level, EnemyDef.EnemyClass.BOSS)`
## Never instanced — call statically.
class_name XpRewardFormula
extends RefCounted

## CP-F4 base XP before per-level scaling (GDD `xp_value` row). Named constant —
## never inline the literal 35 in the validator or authoring tools.
const XP_BASE := 35

## CP-F4 XP added per enemy level (GDD `xp_value` row). Named constant — never inline 10.
const XP_PER_ENEMY_LEVEL := 10

## Role multiplier for a WILD enemy (CP-F4). WILD fights award the base curve.
const ROLE_MULTIPLIER_WILD := 1

## Role multiplier for a BOSS enemy (CP-F4). Bosses award double — the gate reward.
const ROLE_MULTIPLIER_BOSS := 2

## The CP-F4 role multiplier for [param enemy_class]: BOSS → 2, everything else → 1.
##
## Only WILD and BOSS are meaningful callers; an INVALID class maps to the WILD
## multiplier (1) but the validator should skip the xp check for INVALID entirely
## (Story 004 already errors on the class), so this branch is never asserted against
## real content — it is a total-function safety default, not a supported case.
static func role_multiplier(enemy_class: EnemyDef.EnemyClass) -> int:
	if enemy_class == EnemyDef.EnemyClass.BOSS:
		return ROLE_MULTIPLIER_BOSS
	return ROLE_MULTIPLIER_WILD


## CP-F4: `(XP_BASE + level × XP_PER_ENEMY_LEVEL) × role_multiplier(enemy_class)`.
##
## [param level] — the enemy's authored `level` (validator enforces the [1, 10] range;
## this formula does not clamp — it derives faithfully for whatever level it is given).
## [param enemy_class] — WILD or BOSS; selects the role multiplier.
##
## Returns the derived XP award as an exact [int]. Examples (python3-verified):
##   WILD level 1  → (35 + 10) × 1 = 45      WILD level 10 → (35 + 100) × 1 = 135
##   BOSS level 1  → (35 + 10) × 2 = 90      BOSS level 10 → (35 + 100) × 2 = 270
static func derive_xp_value(level: int, enemy_class: EnemyDef.EnemyClass) -> int:
	return (XP_BASE + level * XP_PER_ENEMY_LEVEL) * role_multiplier(enemy_class)
