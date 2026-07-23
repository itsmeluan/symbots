## DiscoveryCodex — the silhouette rule's ledger (Core Design §2; unit info modal).
extends GutTest

const DiscoveryCodexScript := preload("res://src/core/species/discovery_codex.gd")


func test_nothing_is_discovered_until_marked() -> void:
	var codex := DiscoveryCodexScript.new()
	assert_false(codex.is_discovered(&"gravelock", 1))


func test_seeing_one_mark_reveals_only_that_mark() -> void:
	var codex := DiscoveryCodexScript.new()
	codex.mark_seen(&"gravelock", 2)
	assert_false(codex.is_discovered(&"gravelock", 1))
	assert_true(codex.is_discovered(&"gravelock", 2))
	assert_false(codex.is_discovered(&"gravelock", 3),
		"meeting a Mk II reveals nothing about the Mk III — that reveal is earned")


func test_owning_reveals_every_mark_walked_through() -> void:
	var codex := DiscoveryCodexScript.new()
	codex.mark_owned(&"gravelock", 2)
	assert_true(codex.is_discovered(&"gravelock", 1),
		"a Retrofit walked through Mk I, so the player has seen it")
	assert_true(codex.is_discovered(&"gravelock", 2))
	assert_false(codex.is_discovered(&"gravelock", 3))


func test_the_codex_round_trips_through_its_dict() -> void:
	var codex := DiscoveryCodexScript.new()
	codex.mark_seen(&"gravelock", 1)
	codex.mark_seen(&"sumpcoil", 3)

	var restored := DiscoveryCodexScript.new()
	restored.load_dict(codex.to_dict())
	assert_true(restored.is_discovered(&"gravelock", 1))
	assert_false(restored.is_discovered(&"gravelock", 2))
	assert_true(restored.is_discovered(&"sumpcoil", 3))


func test_a_blank_species_id_is_ignored() -> void:
	var codex := DiscoveryCodexScript.new()
	codex.mark_seen(&"", 1)
	assert_eq(codex.to_dict().get("seen", {}).size(), 0,
		"an unset species id must not create a phantom codex entry")
