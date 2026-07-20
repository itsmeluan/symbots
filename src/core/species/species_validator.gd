## SpeciesValidator — content gate for the species catalog (ADR-0003 pattern).
##
## Runs in CI and at dev boot. Every check here exists because the failure it catches is
## INVISIBLE at authoring time and only surfaces as "why is this Symbot weak" or "why did
## nothing happen at level 15" — a content bug that reaches playtest costs far more than
## the check that would have stopped it.
##
## Pure and injected: takes the catalogs, writes diagnostics to the [LogSink], returns the
## error count. Never calls push_error (ADR-0002 §5). Diagnostics follow the project
## contract — a StringName code plus a structured detail Dictionary, never a prose string,
## so CI can assert on codes rather than grepping messages.
class_name SpeciesValidator
extends RefCounted

const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

## Roles that must each be represented, so a squad can always field one of every role.
const REQUIRED_ROLES: Array[int] = [
	SpeciesDefScript.Role.DPS, SpeciesDefScript.Role.TANK,
	SpeciesDefScript.Role.HEALER, SpeciesDefScript.Role.SUPPORT,
]


## Validate [param species] against [param skills]. Returns the number of ERRORS found;
## warnings are logged but do not count toward the return.
##
## Example:
##     var errors := SpeciesValidator.validate(species_catalog, skill_catalog, log)
##     assert(errors == 0)
static func validate(species: SpeciesCatalog, skills: SkillCatalog, log: LogSink) -> int:
	var errors := 0
	var seen_ids: Dictionary = {}
	var seen_entries: Dictionary = {}
	var roles_present: Dictionary = {}

	for s in species.entries:
		if s == null:
			log.error(&"species_null_entry", {})
			errors += 1
			continue

		errors += _check_identity(s, seen_ids, log)
		errors += _check_stats(s, log)
		errors += _check_passives(s, log)
		errors += _check_skill_refs(s, skills, log)
		errors += _check_growth(s, log)

		roles_present[s.role] = true
		if s.tree_entry_node != &"":
			seen_entries[s.tree_entry_node] = int(seen_entries.get(s.tree_entry_node, 0)) + 1

	for role in REQUIRED_ROLES:
		if not roles_present.has(role):
			log.error(&"species_role_unrepresented", {"role": role})
			errors += 1

	# More than two species per entry point contradicts §4.1 ("two species share an entry
	# at full scope"). A warning, not an error: a design smell, not a broken build.
	for entry in seen_entries:
		if int(seen_entries[entry]) > 2:
			log.warn(&"species_entry_overshared",
				{"entry": entry, "count": seen_entries[entry], "allowed": 2})

	return errors


static func _check_identity(s: SpeciesDef, seen: Dictionary, log: LogSink) -> int:
	var errors := 0
	if s.id == &"":
		log.error(&"species_empty_id", {})
		return 1
	if seen.has(s.id):
		log.error(&"species_duplicate_id", {"species": s.id})
		errors += 1
	seen[s.id] = true
	if s.role == SpeciesDefScript.Role.INVALID:
		log.error(&"species_role_invalid", {"species": s.id})
		errors += 1
	if s.rarity == SpeciesDefScript.Rarity.INVALID:
		log.error(&"species_rarity_invalid", {"species": s.id})
		errors += 1
	if s.tree_entry_node == &"":
		# No entry node means no path into the tree, so the species could never gain a
		# skill — it would be permanently stuck with its basic attack.
		log.error(&"species_no_tree_entry", {"species": s.id})
		errors += 1
	return errors


static func _check_stats(s: SpeciesDef, log: LogSink) -> int:
	var errors := 0
	if int(s.base_stats.get(&"structure", 0)) <= 0:
		# It would enter battle already destroyed.
		log.error(&"species_no_structure", {"species": s.id})
		errors += 1

	# The offensive stat a species' own skills read must be its LARGER one. Getting this
	# backwards is invisible in the .tres and surfaces only as "why is this Symbot weak" —
	# the exact bug this catalog was generated with once already, caught by adding a check
	# rather than by re-reading the numbers.
	var phys := int(s.base_stats.get(&"physical_power", 0))
	var ener := int(s.base_stats.get(&"energy_power", 0))
	var wants_energy := String(s.basic_attack_id).contains("pulse")
	if wants_energy and ener < phys:
		log.error(&"species_scaling_stat_mismatch",
			{"species": s.id, "expects": "energy_power",
			 "physical_power": phys, "energy_power": ener})
		errors += 1
	elif not wants_energy and phys < ener:
		log.error(&"species_scaling_stat_mismatch",
			{"species": s.id, "expects": "physical_power",
			 "physical_power": phys, "energy_power": ener})
		errors += 1
	return errors


## Passive count must match what the rarity promises (§2.2). A missing passive is
## invisible until someone levels that far and wonders why nothing happened.
static func _check_passives(s: SpeciesDef, log: LogSink) -> int:
	var errors := 0
	var expected := s.expected_unique_passive_count()
	if s.unique_passives.size() != expected:
		log.error(&"species_passive_count_mismatch",
			{"species": s.id, "rarity": s.rarity,
			 "expected": expected, "actual": s.unique_passives.size()})
		errors += 1

	var seen_levels: Dictionary = {}
	for p in s.unique_passives:
		var pid: StringName = p.get("passive_id", &"")
		var lvl := int(p.get("unlock_level", 0))
		if pid == &"":
			log.error(&"species_passive_no_id", {"species": s.id})
			errors += 1
		if lvl <= 0:
			log.error(&"species_passive_never_unlocks",
				{"species": s.id, "passive": pid, "unlock_level": lvl})
			errors += 1
		if seen_levels.has(lvl):
			log.warn(&"species_passives_share_level", {"species": s.id, "level": lvl})
		seen_levels[lvl] = true
	return errors


## Every skill a species references must exist in the shipped catalog, and its ultimate
## must actually be flagged as one.
static func _check_skill_refs(s: SpeciesDef, skills: SkillCatalog, log: LogSink) -> int:
	var errors := 0
	if skills.get_skill(s.basic_attack_id) == null:
		log.error(&"species_missing_skill",
			{"species": s.id, "skill": s.basic_attack_id, "kind": "basic_attack"})
		errors += 1
	for sid in s.starting_skills:
		if skills.get_skill(sid) == null:
			log.error(&"species_missing_skill",
				{"species": s.id, "skill": sid, "kind": "starting_skill"})
			errors += 1

	if s.starting_ultimate == &"":
		log.error(&"species_no_ultimate", {"species": s.id})
		return errors + 1

	var ult := skills.get_skill(s.starting_ultimate)
	if ult == null:
		log.error(&"species_missing_skill",
			{"species": s.id, "skill": s.starting_ultimate, "kind": "ultimate"})
		errors += 1
	elif not ult.is_ultimate:
		# It would be gated by cooldown instead of charge, so it could open the fight.
		log.error(&"species_ultimate_not_flagged",
			{"species": s.id, "skill": s.starting_ultimate})
		errors += 1
	return errors


## Every part slot must contribute something. A slot that feeds nothing is Scrap the
## player spends for no effect — the worst kind of upgrade.
static func _check_growth(s: SpeciesDef, log: LogSink) -> int:
	var errors := 0
	for slot in SymbotInstanceScript.PART_COUNT:
		if not s.part_growth.has(slot):
			log.error(&"species_part_slot_no_growth", {"species": s.id, "slot": slot})
			errors += 1
			continue
		var gains: Dictionary = s.part_growth[slot]
		if gains.is_empty():
			log.error(&"species_part_slot_empty_growth", {"species": s.id, "slot": slot})
			errors += 1
	return errors
