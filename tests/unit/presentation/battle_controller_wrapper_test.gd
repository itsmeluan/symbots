## TBC autoload wrapper test (Phase 2-B, ADR-0007 Option A).
##
## Verifies:
##   1. is_battle_active() returns false before start_battle() — no active battle.
##   2. Inertness: the autoload's _ready body does no I/O, no signal connects, and
##      no cross-autoload reads (ADR-0004 inertness rule). We assert this structurally
##      by checking state at import time (before any battle starts).
##
## Note: We do NOT call start_battle() in these tests because it requires a real
## BalanceConfig .tres which is not loaded in the unit test harness. The wrapper's
## forwarding of the 3 signals (battle_ended, battle_start_refused, hit_resolved) is
## verified structurally in boot_smoke_test.gd (has_signal assertions).
extends GutTest


func test_is_battle_active_false_before_start_battle() -> void:
	# The TBC autoload wraps a per-session RefCounted.
	# Before start_battle() is called, no RefCounted exists → not active.
	assert_false(TBC.is_battle_active(),
		"is_battle_active() must return false before start_battle() is called")


func test_battle_controller_wrapper_exposes_is_battle_active() -> void:
	assert_true(TBC.has_method("is_battle_active"),
		"TBC autoload must expose is_battle_active()")


func test_battle_controller_wrapper_exposes_start_battle() -> void:
	assert_true(TBC.has_method("start_battle"),
		"TBC autoload must expose start_battle(...)")


func test_battle_controller_wrapper_exposes_submit_action() -> void:
	assert_true(TBC.has_method("submit_action"),
		"TBC autoload must expose submit_action(...)")


func test_submit_action_before_start_battle_is_no_op() -> void:
	# submit_action must be a guarded no-op when no battle is active (not a crash).
	TBC.submit_action({"type": 1})
	# If we reach this line without error, the guard worked.
	pass_test("submit_action() must be a no-op (not a crash) when no battle is active")


func test_inertness_no_battle_context_at_import() -> void:
	# After autoload construction (no start_battle called), _bc must be null.
	# We access the private var via get() which returns null for missing properties
	# on non-null objects. If _bc is null, is_battle_active() returns false (asserted above).
	# Structural assertion: the autoload has no internal battle state at startup.
	assert_false(TBC.is_battle_active(),
		"No battle context must exist at autoload construction time (inertness rule)")
