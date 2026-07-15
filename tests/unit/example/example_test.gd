## Example GUT test — proves the framework + CI are wired correctly.
##
## This is a scaffolding sanity check, NOT a real game-logic test. Delete it
## once the first real system test lands in tests/unit/[system]/. It exists so
## that /test-setup's CI has at least one passing test to run (a green pipeline
## from day one) and so new contributors have a copy-paste template.
##
## Framework: GUT v9.6.1 · base class: GutTest · Godot 4.6
extends GutTest


## A test function's name must start with `test_`. GUT discovers them by prefix.
func test_arithmetic_sanity_holds() -> void:
	# assert_eq(got, expected, message) — the workhorse GUT assertion.
	assert_eq(2 + 2, 4, "Basic arithmetic must hold — if this fails, the runner is broken")


## Demonstrates the determinism rule: seed the RNG, never call global randomize().
## Mirrors the ADR-0006 discipline every real random-using test will follow.
func test_seeded_rng_is_deterministic() -> void:
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 12345
	rng_b.seed = 12345
	assert_eq(rng_a.randi(), rng_b.randi(), "Same seed must yield the same draw (determinism contract)")
