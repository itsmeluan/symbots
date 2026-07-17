## StatPipeline — the sole executor of the SA-F1 stat-derivation pipeline (ADR-0005).
##
## Pure, stateless, static-only Layer-1 core in `src/core/stats/`. Given the equipped
## parts, the chassis archetype, the core level and the CORE's level-growth table, it
## produces the `final_stat` dictionary the battle snapshot freezes at BATTLE_INIT.
## It is the SINGLE composition point for the SA-F1 → CP-F3 → (SYN-F4) order:
##
##   1. per-part per-stat upgrade   → [UpgradeFormula.upgraded_value_for_part] (F2/F2b sign-routed)
##   2. sum across the 8 parts      ┐
##   3. × chassis modifier          ├→ [TotalStatFormula.compute_final_stat] = max(0, floor(sum × mod))
##   4. floor + max(0, …)           ┘   = SA-F1 output
##   4b. + level_growth[S] × (core_level − 1)   = CP-F3 (flat, POST-floor, NOT re-multiplied)
##   → stored final_stat            synergy (SYN-F4) is NEVER folded in here (Rule 8)
##
## CP-F3 is a flat add AFTER the chassis floor — it is not amplified by the archetype
## modifier and not floored again (growth values are integers, `core_level − 1` is an
## integer). That is what makes the discriminating fixture land on 160, not 168
## (design/gdd/symbot-assembly.md AC-SA-15 / Core Progression AC-CP-18).
##
## Reuses the already-epsilon-scanned Foundation primitives — it introduces NO new
## floor/ceil expression of its own. Diagnostics route through the injected [LogSink]
## (`global_push_diagnostics` forbidden), so content anomalies are GUT-assertable.
## Frozen defs are read-only: values are copied out via `stat_bonuses.get(...)`,
## never mutated (`runtime_content_mutation` forbidden; ADR-0003).
class_name StatPipeline
extends RefCounted

## Design maximum for the summed `recharge` stat (Part DB Rule 4: at most two parts
## contribute 15 each → 30). A summed value above this is only reachable through a
## content-authoring violation; SA-F1 reports it but does NOT clamp (AC-SA-13).
const RECHARGE_DESIGN_MAX := 30
const RECHARGE_KEY := &"recharge"


## Runs SA-F1 (steps 1–4) then CP-F3 (step 4b) over [param equipped], returning the
## `final_stat` dictionary keyed by every canonical stat in `cfg.canonical_stat_keys`.
##
## [param equipped]: slot_type (int) → [PartInstance] (or null for an empty slot —
## Assembly forbids empty slots, but the derive is defensive). Iterated by value;
## order does not affect the sum. [param chassis_archetype]: the equipped CHASSIS
## part's [enum PartDef.ChassisArchetype] (0 = none). [param core_level]: the CORE's
## progression level (≥1); at level 1 CP-F3 contributes 0. [param level_growth]: the
## CORE part's `level_growth` dict (StringName → int); an empty dict yields no growth.
##
## Content diagnostics via [param log]: a part `stat_bonuses` key outside the
## canonical list is skipped with a `warn` (AC-SA-11); a summed `recharge` above
## [constant RECHARGE_DESIGN_MAX] emits an `error` on the pre-multiply sum without
## clamping (AC-SA-13); a `level_growth` key outside the canonical list is skipped
## with a `warn` (AC-SA-15 content case).
static func derive(
		equipped: Dictionary,
		chassis_archetype: PartDef.ChassisArchetype,
		core_level: int,
		level_growth: Dictionary,
		cfg: BalanceConfig,
		log: LogSink) -> Dictionary:
	var canonical: Array[StringName] = cfg.canonical_stat_keys
	_warn_unknown_part_keys(equipped, canonical, log)

	var final_stat: Dictionary = {}
	for stat_key in canonical:
		# Step 1: per-part upgraded contributions (sign-routed F2 / F2b).
		var upgraded_values: Array[int] = []
		for instance in equipped.values():
			if instance == null:
				continue
			upgraded_values.append(
				UpgradeFormula.upgraded_value_for_part(instance.part, stat_key, instance.tier, cfg))

		# AC-SA-13: report (do not clamp) a recharge sum over the design max, on the
		# pre-chassis-multiply sum — the value the content-authoring rule constrains.
		if stat_key == RECHARGE_KEY:
			var recharge_sum := 0
			for value in upgraded_values:
				recharge_sum += value
			if recharge_sum > RECHARGE_DESIGN_MAX:
				log.error(&"content_recharge_sum_exceeded",
					{"sum": recharge_sum, "max": RECHARGE_DESIGN_MAX})

		# Steps 2–4: sum → × chassis modifier → max(0, floor) = SA-F1 output.
		var sa_f1 := TotalStatFormula.compute_final_stat(
			stat_key, upgraded_values, chassis_archetype, cfg)

		# Step 4b (CP-F3): flat level-growth add, POST-floor, NOT chassis-amplified.
		var growth: int = level_growth.get(stat_key, 0)
		sa_f1 += growth * (core_level - 1)

		final_stat[stat_key] = sa_f1

	_warn_unknown_growth_keys(level_growth, canonical, log)
	return final_stat


## Introspection helper (AC-SA-02(a)): the single upgraded (F2/F2b) value a part
## contributes for [param stat_key] at [param tier], BEFORE summation and the chassis
## multiply — lets a test assert the intermediate integer (e.g. `8`, not `8.05`).
## Thin pass-through to [UpgradeFormula.upgraded_value_for_part]; no reimplementation.
static func compute_upgraded_stat(
		part: PartDef, stat_key: StringName, tier: int, cfg: BalanceConfig) -> int:
	return UpgradeFormula.upgraded_value_for_part(part, stat_key, tier, cfg)


## AC-SA-11 / EC-SA-05: warn once per part `stat_bonuses` key outside the canonical
## list. The key is never added to `final_stat` (the derive loop reads only canonical
## keys); this pass exists solely to surface the authoring error.
static func _warn_unknown_part_keys(
		equipped: Dictionary, canonical: Array[StringName], log: LogSink) -> void:
	for instance in equipped.values():
		if instance == null:
			continue
		for key in instance.part.stat_bonuses:
			if not canonical.has(key):
				log.warn(&"content_unknown_stat_key",
					{"part": instance.part.id, "key": key})


## AC-SA-15 (content case): warn per `level_growth` key outside the canonical list.
## Such a key is skipped (never added to `final_stat`) — mirrors the part-key rule.
static func _warn_unknown_growth_keys(
		level_growth: Dictionary, canonical: Array[StringName], log: LogSink) -> void:
	for key in level_growth:
		if not canonical.has(key):
			log.warn(&"content_unknown_growth_key", {"key": key})
