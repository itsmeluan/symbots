## UnitPanel sprite rendering (art wiring).
##
## Pins the two things that are silent when wrong: that a bound unit actually loads its
## sprite, and that an enemy is flipped rather than facing the wrong way. A panel with no
## texture and a panel facing backwards both "work" — they just look broken.
extends GutTest

const UnitPanelScript := preload("res://src/ui/battle/unit_panel.gd")


func _unit(species: StringName, side: int, mark := 1) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = &"probe"
	u.species_id = species
	u.art_mark = mark
	u.side = side
	u.max_structure = 100
	u.current_structure = 100
	return u


func _panel(u: BattleUnit) -> UnitPanel:
	var p := UnitPanelScript.new()
	add_child_autofree(p)
	p.bind(u)
	return p


func test_a_player_unit_loads_its_sprite() -> void:
	var p := _panel(_unit(&"rustcrawler", BattleUnit.Side.PLAYER))
	assert_not_null(p._sprite.texture, "the Rustcrawler PNG should have loaded")
	assert_false(p._sprite.flip_h, "a player Symbot faces right, unflipped")


func test_an_enemy_is_flipped_to_face_left() -> void:
	# Enemies face the player. A mirror on disk was rejected in favour of runtime flip_h, so
	# this is the check that the flip actually happens.
	var p := _panel(_unit(&"rustcrawler", BattleUnit.Side.ENEMY))
	assert_true(p._sprite.flip_h, "an enemy must be mirrored to face the player")


func test_the_mark_selects_the_sprite() -> void:
	# A retrofitted Symbot shows its Mk III art; loading the wrong mark is invisible until
	# someone notices the sprite never changed.
	var p1 := _panel(_unit(&"rustcrawler", BattleUnit.Side.PLAYER, 1))
	var p3 := _panel(_unit(&"rustcrawler", BattleUnit.Side.PLAYER, 3))
	assert_not_null(p3._sprite.texture)
	assert_ne(p1._sprite.texture.resource_path, p3._sprite.texture.resource_path,
		"Mk I and Mk III must resolve to different files")


func test_every_slice_species_has_all_three_marks_on_disk() -> void:
	# The wiring is only as good as the art it points at. This catches a missing or
	# misnamed file before it shows up as a blank slot in a fight.
	for species in ["rustcrawler", "voltfang", "boltshell", "ironmaul",
			"solderfly", "nanoweave", "coilsprite", "hexcircuit"]:
		for mark in [1, 2, 3]:
			var path := "res://assets/art/symbots/%s_mk%d.png" % [species, mark]
			assert_true(ResourceLoader.exists(path), "missing %s" % path)


func test_a_species_with_no_art_yet_leaves_the_slot_blank_not_broken() -> void:
	# The 8 unauthored species have no SpeciesDef yet but their absence must not crash a
	# panel: a unit with an unknown species id simply shows no portrait.
	var p := _panel(_unit(&"not_a_real_species", BattleUnit.Side.PLAYER))
	assert_null(p._sprite.texture, "an unresolved sprite is blank, not an error")


func test_every_sprite_is_drawn_at_the_common_height() -> void:
	# The whole point of normalising: a 102px Quillrack and a 323px Splicewyrm must read at
	# the same scale on the field.
	var p := _panel(_unit(&"rustcrawler", BattleUnit.Side.PLAYER))
	assert_eq(p._sprite.custom_minimum_size.y, float(UnitPanelScript.SPRITE_HEIGHT))
