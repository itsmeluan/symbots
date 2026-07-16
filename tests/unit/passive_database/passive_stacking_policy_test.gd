## Passive-DB Story 003 — stacking-policy defaults by behavior_class.
##
## Covers the Story 003 ACs (GDD Rule 4 / TR-pdb-004):
##   The canonical behavior_class -> StackingPolicy default table is correct for
##   all four BehaviorClass values; default_stacking_policy() is a pure lookup
##   (same input → same output, no side effects); the INVALID (0) sentinel maps to
##   nothing; and the table stays exhaustive (one entry per non-INVALID class).
##
## This is the single source of truth the validator (Story 004) reads to flag an
## authored stacking_policy that diverges from its class default. Framework: GUT.
extends GutTest


# ---------------------------------------------------------------------------
# Default table correctness — GDD Rule 4
# ---------------------------------------------------------------------------

func test_stacking_default_status_rider_is_unique_per_trigger() -> void:
	assert_eq(
		PassiveDef.default_stacking_policy(PassiveDef.BehaviorClass.STATUS_RIDER),
		PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER,
		"STATUS_RIDER defaults to UNIQUE_PER_TRIGGER (Rule 4)")


func test_stacking_default_stat_aura_is_unique() -> void:
	assert_eq(
		PassiveDef.default_stacking_policy(PassiveDef.BehaviorClass.STAT_AURA),
		PassiveDef.StackingPolicy.UNIQUE,
		"STAT_AURA defaults to UNIQUE (Rule 4)")


func test_stacking_default_resource_effect_is_stackable() -> void:
	assert_eq(
		PassiveDef.default_stacking_policy(PassiveDef.BehaviorClass.RESOURCE_EFFECT),
		PassiveDef.StackingPolicy.STACKABLE,
		"RESOURCE_EFFECT defaults to STACKABLE (Rule 4)")


func test_stacking_default_structural_effect_is_unique() -> void:
	assert_eq(
		PassiveDef.default_stacking_policy(PassiveDef.BehaviorClass.STRUCTURAL_EFFECT),
		PassiveDef.StackingPolicy.UNIQUE,
		"STRUCTURAL_EFFECT defaults to UNIQUE (Rule 4)")


# ---------------------------------------------------------------------------
# Sentinel handling — 0 / unknown maps to nothing
# ---------------------------------------------------------------------------

## The INVALID (0) sentinel is deliberately absent from the table, so the default
## lookup returns 0 — letting the validator distinguish "no default" from a policy.
func test_stacking_default_invalid_sentinel_returns_zero() -> void:
	assert_eq(
		int(PassiveDef.default_stacking_policy(0)),
		0,
		"the 0 / INVALID behavior class has no default policy (returns 0)")


# ---------------------------------------------------------------------------
# Table exhaustiveness — one entry per non-INVALID BehaviorClass
# ---------------------------------------------------------------------------

## Every non-INVALID BehaviorClass member has exactly one default entry. A future
## BehaviorClass addition (APPEND-ONLY) that forgets the table forces this to fail.
func test_stacking_default_table_covers_every_behavior_class() -> void:
	# Arrange — BehaviorClass has no 0 member, so size() counts only real classes.
	var expected_entries := PassiveDef.BehaviorClass.size()

	# Assert — the table has exactly one row per class, and none maps to 0.
	assert_eq(PassiveDef.DEFAULT_STACKING.size(), expected_entries,
		"DEFAULT_STACKING has exactly one entry per BehaviorClass value")
	for bc in PassiveDef.BehaviorClass.values():
		assert_ne(int(PassiveDef.default_stacking_policy(bc)), 0,
			"BehaviorClass %d must have a non-INVALID default policy" % bc)


## The INVALID sentinel (0) must NOT appear as a key in the default table.
func test_stacking_default_table_excludes_invalid_key() -> void:
	assert_false(PassiveDef.DEFAULT_STACKING.has(0),
		"DEFAULT_STACKING must not key the 0/INVALID sentinel")


# ---------------------------------------------------------------------------
# Purity — same input, same output, no side effects
# ---------------------------------------------------------------------------

## Repeated calls with the same input yield the identical result — the lookup is
## pure (a precondition for both the validator and authoring tooling reusing it).
func test_stacking_default_policy_is_pure() -> void:
	# Act — call twice for each class.
	var first := PassiveDef.default_stacking_policy(PassiveDef.BehaviorClass.STAT_AURA)
	var second := PassiveDef.default_stacking_policy(PassiveDef.BehaviorClass.STAT_AURA)

	# Assert — deterministic, and the shared table is unchanged in size.
	assert_eq(first, second, "default_stacking_policy is deterministic")
	assert_eq(PassiveDef.DEFAULT_STACKING.size(), PassiveDef.BehaviorClass.size(),
		"the shared default table is not mutated by lookups")
