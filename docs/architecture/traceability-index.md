# Architecture Traceability Index
Last Updated: 2026-07-14
Engine: Godot 4.6

> First population — produced by `/architecture-review` (full mode). Requirement
> IDs are stable and live in `tr-registry.yaml`; this index maps each to its ADR
> coverage. "System-internal" = a GDD-defined rule implemented inside one system,
> guarded by unit tests per coding standards; it needs no ADR. The prior planning
> baseline in architecture.md counted 148 coarse requirements; this extraction is
> finer-grained (277 registered) and supersedes those counts and the TR citations
> in architecture.md's Required-ADRs section.

## Coverage Summary
- Total requirements: 277
- Covered by a written ADR (0001-0006): 197 (71%)
- System-internal (no ADR required): 24 (9%)
- Partial: 5
- Gaps (await planned ADR-0007..0008): 51 (18%)

> Update 2026-07-14 (architecture-review): ADR-0005 and ADR-0006 both **Accepted**; their
> gap TRs closed, coverage rose 145 -> 197. Remaining 51 gaps are owned entirely by planned
> ADR-0007 (45) + ADR-0008 (6). TR-eai-006/007/008/009 were re-pointed off ADR-0006 (they are
> not RNG concerns): 006/007 -> ADR-0005-provides / ADR-0007-consumes (Partial), 008/009 -> ADR-0007 (Gap).

## Full Matrix

| TR-ID | System | Requirement | Coverage | Status |
|-------|--------|-------------|----------|--------|
| TR-ep-001 | ep | Registry of progression domains (zones, cores, world_loot) with StringName keys | ADR-0001 | ✅ Covered |
| TR-ep-002 | ep | Domain contract: snapshot()->Dictionary, restore(data), rederive() three-operation interface | ADR-0001 | ✅ Covered |
| TR-ep-003 | ep | Two-phase restore: Phase 1 cross-domain-read-free, Phase 2 re-derivation | ADR-0001 | ✅ Covered |
| TR-ep-004 | ep | Restore must run before any derivation (restore -> rederive ordering; one derivation path) | ADR-0001, ADR-0004 | ✅ Covered |
| TR-ep-005 | ep | Serialize validation: refuses bad snapshot (non-Dictionary), returns {ok, blob} or {ok:false, failed_domain, error} | ADR-0001 | ✅ Covered |
| TR-ep-006 | ep | Serialize produces {domain_key: snapshot()} plus progress_format_version | ADR-0001 | ✅ Covered |
| TR-ep-007 | ep | Blob carries progress_format_version=1; version check before restore | ADR-0001 | ✅ Covered |
| TR-ep-008 | ep | EP-PRED-1 version predicate: RESTORE/MIGRATE/REFUSE logic | ADR-0001 | ✅ Covered |
| TR-ep-009 | ep | EP-INV-1 boss-progress invariant: wins_at_last_defeat <= win_count (clamped on violation) | ADR-0001 | ✅ Covered |
| TR-ep-010 | ep | Corruption pass clamps: win_count<0 -> 0, then re-check invariant; cumulative_xp<0 -> 0 | ADR-0001 | ✅ Covered |
| TR-ep-011 | ep | Save timing owned by Save/Load at event-boundary quiesce points (OQ-EP-2 / Rule 8) | ADR-0001 | ✅ Covered |
| TR-ep-012 | ep | Zone LOCKED/ACCESSIBLE/CLEARED always re-derived via ZWM-F2, never trusted from disk | ADR-0001 | ✅ Covered |
| TR-ep-013 | ep | Core level always re-derived from cumulative_xp via CP-F1, never trusted from disk | ADR-0001 | ✅ Covered |
| TR-ep-014 | ep | Unknown domain keys preserved opaquely in session memory, round-tripped on next serialize | ADR-0001 | ✅ Covered |
| TR-ep-015 | ep | Replacement semantics: restore() unconditionally replaces all source facts, never merges | ADR-0001 | ✅ Covered |
| TR-ep-016 | ep | Duplicate core_instance_id: first occurrence wins + warning | ADR-0001 | ✅ Covered |
| TR-ep-017 | ep | Duplicate loot IDs: deduped via Set reconstruction + warning | ADR-0001 | ✅ Covered |
| TR-inv-001 | inv | Persist part_instances + next_instance_id (monotonic) — primary inventory persistence requirement | ADR-0001 | ✅ Covered |
| TR-inv-002 | inv | PartInstance schema: instance_id (int, stable, never reused), part_id (StringName), upgrade_tier (int) | ADR-0001 | ✅ Covered |
| TR-inv-003 | inv | Parts never merged/stacked/deduplicated — N copies = N distinct instances | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-inv-004 | inv | Consumable stacks: single count per id, 0 <= quantity <= max_stack (from Consumable DB) | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-inv-005 | inv | Persist scrap + consumable counts (Rule 8 split: Inventory owns model, Save/Load owns disk) | ADR-0001 | ✅ Covered |
| TR-inv-006 | inv | INV-1 consumable overflow: accepted=min(qty, max_stack-current), rejected=qty-accepted (reported) | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-inv-007 | inv | Scrap balance clamped at SCRAP_MAX; excess reported as rejected, never silently dropped | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-inv-008 | inv | Scrap part yields SCRAP_YIELD[rarity], tier-independent (total sink MVP) | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-inv-009 | inv | Scrap blocked if equipped (Workshop's equipped set queried via accessor) | ADR-0002 | ✅ Covered |
| TR-inv-010 | inv | Consumable decrement blocked at 0 (never negative) | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-inv-011 | inv | next_instance_id serialized, never rebuilt from max(live_ids)+1 on load | ADR-0001 | ✅ Covered |
| TR-inv-012 | inv | Save/Load clamps stale over-cap consumable count <= max_stack on deserialize | ADR-0001 | ✅ Covered |
| TR-inv-013 | inv | Unknown part_id/consumable_id on add rejected + logged, never stored | ADR-0003 | ✅ Covered |
| TR-inv-014 | inv | Absent consumable key equivalent to 0 (no null return) | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-inv-015 | inv | Four stores serialized: part_instances, consumable_stacks, scrap, next_instance_id | ADR-0001 | ✅ Covered |
| TR-cp-001 | cp | Persist CoreProgressionRecord.cumulative_xp; level re-derived on load (never stored) | ADR-0001 | ✅ Covered |
| TR-cp-002 | cp | CoreProgressionRecord keyed by core_instance_id (Inventory instance_id) | ADR-0001 | ✅ Covered |
| TR-cp-003 | cp | Level derived via CP-F1 XP-to-level threshold lookup (pure integer lookup, no float) | ADR-0005 | ✅ Covered |
| TR-cp-004 | cp | Max level cap: level-10 cores discard XP beyond threshold[10] | ADR-0005 | ✅ Covered |
| TR-cp-005 | cp | XP award split: deployed=full_xp, benched=floor(full_xp*BENCH_XP_SHARE) | ADR-0005 | ✅ Covered |
| TR-cp-006 | cp | Bench-level cap: benched_level >= enemy_level+BENCH_LEVEL_LEAD_CAP -> earn 0 XP | ADR-0005 | ✅ Covered |
| TR-cp-007 | cp | Boss completion bonus awarded only if is_first_boss_defeat=true (once-per-boss) | ADR-0002 | ✅ Covered |
| TR-cp-008 | cp | level_requirement equip gate: core.level < part.level_requirement blocks equip | ADR-0005 | ✅ Covered |
| TR-cp-009 | cp | level_growth dictionary on CORE-slot parts only; non-CORE ignored | ADR-0005 | ✅ Covered |
| TR-cp-010 | cp | Power stats forbidden in level_growth (physical_power, energy_power) | ADR-0003 | ✅ Covered |
| TR-cp-011 | cp | CP-F3 stat contribution applied after SA-F1, before SYN-F4 (pipeline order) | ADR-0005 | ✅ Covered |
| TR-cp-012 | cp | Core swap: over-level parts flagged invalid; not auto-unequipped | ADR-0008 (planned: UI architecture & screen contracts) | ❌ Gap |
| TR-cp-013 | cp | Register core on Inventory add; duplicate register no-op + warning | ADR-0002 | ✅ Covered |
| TR-cp-014 | cp | Unknown level_growth stat key skipped + warning (mirrors SA-EC-05) | ADR-0003 | ✅ Covered |
| TR-cp-015 | cp | Negative cumulative_xp on load clamped to 0 + error | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-cp-016 | cp | Multi-level XP gain: single core_leveled_up signal with (old, new) span | ADR-0002 | ✅ Covered |
| TR-cp-017 | cp | No XP on DEFEAT or FLED outcome | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-cp-018 | cp | Injected logger (not global push_warning/error) for unit-test capture | ADR-0002 | ✅ Covered |
| TR-cp-019 | cp | CP-F4: xp_value=(XP_BASE+enemy_level*XP_PER_ENEMY_LEVEL)*role_multiplier | ADR-0005 | ✅ Covered |
| TR-cp-020 | cp | BENCH_XP_SHARE must be power-of-2 (0.5) or epsilon-guarded | ADR-0005 | ✅ Covered |
| TR-tbc-001 | tbc | Three-Symbot team structure: exactly 1 active, 2 benched; only active acts/targeted | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-002 | tbc | Assembly final_stat snapshot at battle start, immutable for battle duration | ADR-0005 | ✅ Covered |
| TR-tbc-003 | tbc | Synergy evaluate_silent() called once per Symbot, frozen cached_bonus_block contract | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-004 | tbc | battle_ended 8-field payload: outcome, enemy_id, fired_break_events, xp_value, completion_bonus_xp, is_first_boss_defeat, enemy_level, deployed_symbot_ids | ADR-0002 | ✅ Covered |
| TR-tbc-005 | tbc | Synchronous battle_ended emit; runtime state discarded only after all subscribers return | ADR-0002 | ✅ Covered |
| TR-tbc-006 | tbc | Initiative recomputed every round start; tiebreak player acts first | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-007 | tbc | Turn phases ordered: heat decay, energy recharge, status ticks, action, turn-end decrement | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-008 | tbc | Overheat skips action only; sets heat 20 carry-in; preserves turn bookkeeping except decay | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-009 | tbc | Energy recharge: min(capacity, current+10+recharge_stat) per turn start | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-010 | tbc | Basic Attack 0 energy always available; move 4 may be null; no soft-lock | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-011 | tbc | Damage pipeline: DF-1 -> MOVE-F1 power-tier -> Stagger reduction -> break-bias routing | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-012 | tbc | SYN-F4 clamped stat on both sides before DF-1; passive aura frozen at BATTLE_INIT | ADR-0005 | ✅ Covered |
| TR-tbc-013 | tbc | hit_resolved(move, damage, target, sub_target) 4-arg hook post-Stagger carries sub_target | ADR-0002 | ✅ Covered |
| TR-tbc-014 | tbc | Benched Symbots: frozen heat/energy/statuses per Symbot; resume on return | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-015 | tbc | Forced switch free on DOWNED; voluntary switch consumes turn | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-016 | tbc | Flee WILD-only; consumes action; no drops/XP | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-017 | tbc | Status decrement at turn-end; expire at 0; Burn ticks at turn-start | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-018 | tbc | Reapplication newest-wins: refresh duration AND re-snapshot processing | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-019 | tbc | Unknown passive effect ID logged error, skipped, no crash | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-020 | tbc | Move pool: Basic Attack + WEAPON + HEAD + ARMS; slot 4 nullable | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-021 | tbc | Three statuses: Shock(Volt,2T), Burn(Thermal,2T), Stagger(Kinetic,2T); no stacking | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-022 | tbc | Heat: cap 100; Overheat 10% self-damage + skip turn + carry 20 | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-023 | tbc | Repair: max(5, floor(energy_power*0.17+5+eps)); capped max_structure; costs always apply | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-024 | tbc | Enemy: .get(stat,0) reads; no heat/energy; moves always available | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-025 | tbc | is_build_valid() precondition called pre-snapshot; invalid build refuses entry with battle_start_refused | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-026 | tbc | Type multiplier T baked into DF-1 output before Stagger/break-bias | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-027 | tbc | Burn bypasses DF-1: fixed potency damage; armor/resistance/type never reduce | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-028 | tbc | SCAN no-op: costs paid, heat applied, action consumed, no damage/status | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-029 | tbc | Item use: targets living Symbot; success consumes turn; rejection pre-gates, no cost | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-030 | tbc | Item action: zero heat, zero energy cost; Overheat prevents use preventively | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-031 | tbc | Victory checked before heat gain; kill+self-down = VICTORY, no self-damage | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-032 | tbc | Overheat-skip turn: status ticks run; turn-end decrements; turn bookkeeping except decay | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-033 | tbc | SYNERGY_POWER_BUDGET=40, SYNERGY_DEFENSE_BUDGET=50; DF-1 range [1,225] boss ceiling 164 | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-tbc-034 | tbc | DOWNED clears all statuses; benched status frozen mid-battle | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-035 | tbc | Passive ON_HIT at hit_resolved; ON_BATTLE_START once at BATTLE_INIT; PERSISTENT no re-fire | ADR-0002 | ✅ Covered |
| TR-tbc-036 | tbc | PERSISTENT aura captured at BATTLE_INIT into frozen_passive_aura; held whole battle | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-037 | tbc | Registry dispatch: alphabetical effect ID order; stacking_policy controls per-source refires | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-038 | tbc | Shock magnitude positive; TBC-F1 subtracts it (never pre-negate) | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-tbc-039 | tbc | Enemy AI request_move(battle_state) returns one legal move at ACTION_PENDING | ADR-0002 | ✅ Covered |
| TR-tbc-040 | tbc | is_battle_active() true BATTLE_INIT -> battle_ended emission, false otherwise | ADR-0002 | ✅ Covered |
| TR-tbc-041 | tbc | Battle end: all runtime state discarded; fresh snapshots/evaluate_silent next battle | ADR-0001 | ✅ Covered |
| TR-tbc-042 | tbc | Consumed turn -> next combatant by initiative; free action does not advance turn order | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-001 | pb | Structure pool (kill) independent from region break_hp pools (harvest) | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-002 | pb | Region sub-target selection free (no cost), closed set {STRUCTURE} + {unbroken regions} | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-003 | pb | Move break_bias: STRUCTURE_HEAVY(1.25,0.55), BALANCED(1.00,1.00), BREAK_HEAVY(0.70,1.40) | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-004 | pb | Region hit: break_mult to pool + 20% spillover to Structure; Structure hit: structure_mult only | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-005 | pb | Deterministic break: current_break_hp<=0 -> BROKEN, emit key, increment enrage, max once/region | ADR-0002 | ✅ Covered |
| TR-pb-006 | pb | Already-broken hit redirected Structure at structure_mult; no spillover, no re-break | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-007 | pb | Enrage multiplier x(1.0 + broken_region_count * 0.12); max +36% at 3 breaks | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-008 | pb | Region state battle-local: fresh INTACT at battle start; discarded at end | ADR-0001 | ✅ Covered |
| TR-pb-009 | pb | Break keys must exactly match Drop System vocabulary (region_broken, all_boss_parts_broken) | ADR-0002 | ✅ Covered |
| TR-pb-010 | pb | Closed target set: constructed from enemy.break_regions, rebuilt live excluding broken | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-011 | pb | Region pool init EDB-1: max(5, floor(enemy_structure * fraction + eps)); [5,330] range | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-012 | pb | DAMAGE_FLOOR 1 on all break formulas; every hit makes progress | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-013 | pb | Region damage uses full pipeline DF-1 -> MOVE-F1 -> Stagger before break_mult applies | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-pb-014 | pb | Enrage applied post-Stagger enemy damage; ordering non-commutative, determines output | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-part-001 | part | Sympart schema fields and types including StringName id, String display_name, enum slot_type, nullable chassis_archetype | ADR-0003 | ✅ Covered |
| TR-part-002 | part | stat_bonuses constrained to 11 canonical keys; non-zero recharge only CORE/ENERGY_CELL parts | ADR-0003 | ✅ Covered |
| TR-part-003 | part | Rarity gates skills/passives: Common none; Rare+ skill (non-Core) or passive (Core); Core blocks active skills always | ADR-0003 | ✅ Covered |
| TR-part-004 | part | Prototype parts require >=1 negative stat; Formula 2b reduces toward zero via tier scaling, never positive | ADR-0003 | ✅ Covered |
| TR-part-005 | part | synergy_tags mandatory: element tag all parts; manufacturer tag non-wild only; wild exclude manufacturer tags | ADR-0003 | ✅ Covered |
| TR-part-006 | part | chassis_archetype non-null CHASSIS only; valid enum (LIGHT/HEAVY/BALANCED/GUARDIAN/ARTILLERY) | ADR-0003 | ✅ Covered |
| TR-part-007 | part | Boss-grade parts need >=1 drop_conditions entry multiplier >=500 to reach 50% effective rate | ADR-0003 | ✅ Covered |
| TR-part-008 | part | Formula 2b: independent per-stat drawback reduction via max(0, 1-tier/3) scale; clamp mandatory before negation | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-part-009 | part | Formula 1: composes Formula 2/2b outputs from 8 parts, applies chassis modifier, floors, clamps to 0+ | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-part-010 | part | Upgrade tiers: Common +0..+3 hard-cap; Rare/Boss/Proto +0..+5; multipliers x1.00..x2.00 | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-part-011 | part | level_requirement field: rarity floors (C1/R3/B6/P8); individual parts can exceed, never lower | ADR-0003 | ✅ Covered |
| TR-part-012 | part | level_growth (per-level flat bonus): non-null only CORE slots; Assembly ignores elsewhere | ADR-0003 | ✅ Covered |
| TR-part-013 | part | Skill/passive IDs referential integrity: active_skill_id, passive_id must resolve valid Move/Passive DB entries | ADR-0003 | ✅ Covered |
| TR-part-014 | part | Rare primary floor >= Common primary cap: guarantees Rare+0 beats Common+3 in slot primary stat | ADR-0003 | ✅ Covered |
| TR-part-015 | part | heat_generation range [0,40]; null active_skill_id must have heat=0; THERMAL element +5 bonus | ADR-0003 | ✅ Covered |
| TR-part-016 | part | Formula 3 drop rate: conditions multiply base rate; clamp [0.0,1.0]; base rates C 0.70 / R 0.25 / B 0.001 / P 0.05 | ADR-0003 | ✅ Covered |
| TR-part-017 | part | Prototype gradient: >=3 conditions product >=3.0 reach 15-20% optimal; partial fire partial rate | ADR-0003 | ✅ Covered |
| TR-part-018 | part | drop_enabled=false excludes drop tables, preserves inventory validity (seasonal/retired mechanism) | ADR-0003 | ✅ Covered |
| TR-part-019 | part | Part variants: same part_family, distinct id/rarity/stats/skills across Common/Rare/Boss-grade | ADR-0003 | ✅ Covered |
| TR-part-020 | part | sprite_id non-null non-empty all parts; asset identifier for renderer sprite-swap | ADR-0003 | ✅ Covered |
| TR-part-021 | part | upgrade_effects array tiers 1-5: {tier, effect_type, description, skill_id}; types SKILL_UNLOCK/ENHANCE | ADR-0003 | ✅ Covered |
| TR-part-022 | part | Prototype concentration: >=70% positive budget in 1-2 stats; at x2.0 exceeds spread Boss-grade focus | ADR-0003 | ✅ Covered |
| TR-part-023 | part | Formula 2 epsilon non-discriminating MVP ranges, Formula 2b load-bearing; retain both for safety | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-part-024 | part | Numeric precision: floor() not round/ceil; Formula 2b double-negation max(0,...) guard tier >=4 mandatory | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-part-025 | part | Reserved Full Vision fields null MVP: motherboard_slot_type, ram_cost, weight_class, modification_slots, critical_output, firewall | ADR-0003 | ✅ Covered |
| TR-edb-001 | edb | Enemy schema: StringName id, String display_name, WILD\|BOSS class, tier=1 always MVP, nullable core_element, 11-stat Dictionary | ADR-0003 | ✅ Covered |
| TR-edb-002 | edb | break_hp stored-equals-derived invariant: max(BREAK_HP_MIN, floor(structure*fraction+0.0001)); validated on import | ADR-0003 | ✅ Covered |
| TR-edb-003 | edb | break_hp epsilon load-bearing: valid-range inputs produce wrong results without +0.0001 nudge | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-edb-004 | edb | Break region validity (EDB-3): break_hp < structure AND break_event matches >=1 pool part's drop_conditions | ADR-0003 | ✅ Covered |
| TR-edb-005 | edb | WILD power cap: physical/energy_power <= 39 prevents one-shot on zero-armor player super-effective scenario | ADR-0003 | ✅ Covered |
| TR-edb-006 | edb | WILD power derivation: A=39 D=0 T=1.5 -> 58 dmg < 60 min Structure safe; A=40 -> one-shot violates intent | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-edb-007 | edb | TTK calibration (EDB-2): computed check normative, not static ranges; jointly bounds structure x defense | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-edb-008 | edb | Boss-grade exclusivity: BOSS pools 1-2 exclusives; WILD pools forbid Boss-grade (Part DB Rule 8 cross-system) | ADR-0003 | ✅ Covered |
| TR-edb-009 | edb | Floor loot rarity: Common ungated valid; Rare/Boss-grade must carry >=1 break condition per Part DB | ADR-0003 | ✅ Covered |
| TR-edb-010 | edb | Harvest-decision rule (hard): loot_pool.size() > break_regions.size(); equality fails (non-degenerate choice) | ADR-0003 | ✅ Covered |
| TR-edb-011 | edb | Stat keys use Part DB 11-name vocabulary; A/D stats constrained [0,110] (DF-1 verified range) | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-edb-012 | edb | Dead-data warning: enemies no Heat/Energy MVP (TBC Rule 8); cooling/energy_capacity/recharge warn if non-zero | ADR-0003 | ✅ Covered |
| TR-edb-013 | edb | Boss-grade product invariant: BASE_DROP_BOSS_GRADE x multiplier >= 0.5; at base 0.001 requires x500 | ADR-0003 | ✅ Covered |
| TR-edb-014 | edb | region_fraction bounds [0.15,0.55]: opener/mid/expert commit tiers; 0.55 preserves break-cheaper margin | ADR-0003 | ✅ Covered |
| TR-edb-015 | edb | xp_value stored-equals-derived: equals CP-F4 (XP_BASE+level*XP_PER_LEVEL)*role_mult; validation fails on divergence | ADR-0003 | ✅ Covered |
| TR-edb-016 | edb | completion_bonus_xp: >=0, zero for WILD, BOSS non-zero; added to xp_value on first boss defeat only (CP guard) | ADR-0003 | ✅ Covered |
| TR-edb-017 | edb | level field: >=1 <=10; zone [level_floor,level_roof] must include value (authoring validation) | ADR-0003 | ✅ Covered |
| TR-edb-018 | edb | loot_pool entries must exist in Part DB; duplicates deduplicated with warning; all-disabled pool fails | ADR-0003 | ✅ Covered |
| TR-edb-019 | edb | skills.size() >= 1 blocking; > 4 advisory warn (MVP 2-4 intent) | ADR-0003 | ✅ Covered |
| TR-edb-020 | edb | Null core_element density: NULL_ELEMENT_MAX_WILD=1 per zone; 2+ warns; null -> x1.0 type effectiveness | ADR-0003 | ✅ Covered |
| TR-edb-021 | edb | Region break events set semantics: same break_event from multiple regions fires once; Drop deduplicates | ADR-0002 | ✅ Covered |
| TR-edb-022 | edb | Minimum 1 break region (EC-ED-01); MVP 2-3; zero violates Pillar 2 (no harvest target) | ADR-0003 | ✅ Covered |
| TR-edb-023 | edb | Ungated pool parts must be Common rarity; Rare/Boss-grade ungated undermines Pillar 2 Harvest Goal | ADR-0003 | ✅ Covered |
| TR-edb-024 | edb | >=2 break-gated parts advisory: <2 warns (degenerate harvest choice) | ADR-0003 | ✅ Covered |
| TR-mdb-001 | mdb | Every move references MOVE-CONTRACT-1 schema: id, display_name, behavior, power_tier, damage_type, element, energy_cost, targeting, break_bias | ADR-0003 | ✅ Covered |
| TR-mdb-002 | mdb | DAMAGE moves require non-null power_tier mapping to damage multiplier {0.70, 0.80, 1.00, 1.20, 1.40} per tier | ADR-0003 | ✅ Covered |
| TR-mdb-003 | mdb | STATUS moves' status_proc.status_id must match move element (Volt->Shock, Thermal->Burn, Kinetic->Stagger) | ADR-0003 | ✅ Covered |
| TR-mdb-004 | mdb | DAMAGE moves' energy_cost within power_tier band: LIGHT 5-8, STANDARD 12-18, HEAVY 22-30, SIGNATURE 32-40 | ADR-0003 | ✅ Covered |
| TR-mdb-005 | mdb | REPAIR moves must author energy_cost > BASE_ENERGY_REGEN (>=11 at current 10) for anti-stall Energy-brake | ADR-0003 | ✅ Covered |
| TR-mdb-006 | mdb | UTILITY Vent moves reduce current_heat by vent_amount, floored at 0; only MVP UTILITY behavior | ADR-0003 | ✅ Covered |
| TR-mdb-007 | mdb | SCAN moves' scan_payload=BREAK_REGIONS delivers enemy break_regions and drop hints, persistent for battle | ADR-0003 | ✅ Covered |
| TR-mdb-008 | mdb | Move power multiplier (MOVE-F1) applies post-DF-1 output with epsilon 0.0001 for IEEE 754 rounding | ADR-0003 (validation) + ADR-0005 (execution) | ✅ Covered |
| TR-mdb-009 | mdb | Non-DAMAGE moves must not carry innate status riders; riders only via passives through TBC Rule 13 registry | ADR-0003 | ✅ Covered |
| TR-mdb-010 | mdb | Core parts must not carry SKILL_UNLOCK upgrade effects per Part DB Core exception | ADR-0003 | ✅ Covered |
| TR-pdb-001 | pdb | Every passive declares behavior_class (STATUS_RIDER/STAT_AURA/RESOURCE_EFFECT/STRUCTURAL_EFFECT) and trigger_category; behavior_class is runtime resolution axis | ADR-0003 | ✅ Covered |
| TR-pdb-002 | pdb | Trigger x behavior legality matrix enforced (STATUS_RIDER+ON_HIT only; STAT_AURA+PERSISTENT only; etc.) | ADR-0003 | ✅ Covered |
| TR-pdb-003 | pdb | ON_HIT scope=WEAPON_ONLY fires only on WEAPON-slot DAMAGE moves; ANY_DAMAGE fires on all DAMAGE moves | ADR-0003 | ✅ Covered |
| TR-pdb-004 | pdb | Stacking policies by behavior_class: STATUS_RIDER->UNIQUE_PER_TRIGGER, STAT_AURA->UNIQUE, STRUCTURAL->UNIQUE, RESOURCE->STACKABLE | ADR-0003 | ✅ Covered |
| TR-pdb-005 | pdb | Three MVP status riders authored: volt_shock_on_hit, thermal_burn_on_weapon, kinetic_stagger_on_hit | ADR-0003 | ✅ Covered |
| TR-pdb-006 | pdb | STAT_AURA behavior_params={stat: StringName, delta: int} via SYN-F4 clamp; RESOURCE_EFFECT={resource, amount} clamped by cap | ADR-0003 | ✅ Covered |
| TR-pdb-007 | pdb | STRUCTURAL_EFFECT amount non-negative for both targets; negative amounts rejected at authoring | ADR-0003 | ✅ Covered |
| TR-pdb-008 | pdb | Core passives restricted to ON_BATTLE_START/ON_OVERHEAT/PERSISTENT; no ON_HIT (rider domain of Weapon/Arms) | ADR-0003 | ✅ Covered |
| TR-cdb-001 | cdb | Every consumable declares effect_type with matching effect_params schema (RESTORE_STRUCTURE/REDUCE_HEAT/RESTORE_ENERGY/BOOST_DROP/MODIFY_ENCOUNTER_RATE) | ADR-0003 | ✅ Covered |
| TR-cdb-002 | cdb | Use context (BATTLE/WORLD/BOTH) gates pre-action validation; rejected use consumes no turn, no decrement | ADR-0003 | ✅ Covered |
| TR-cdb-003 | cdb | RESTORE_* targets living team Symbot (Structure > 0), active or benched; downed never valid | ADR-0003 | ✅ Covered |
| TR-cdb-004 | cdb | BOOST_DROP (Salvage Beacon) per-battle flag; one per battle, spent on flee/loss, applies only on victory | ADR-0003 | ✅ Covered |
| TR-cdb-005 | cdb | MODIFY_ENCOUNTER_RATE modifier frozen during battle (no step countdown); resumes after battle | ADR-0003 | ✅ Covered |
| TR-cdb-006 | cdb | buy_price > sell_price strictly for every entry to prevent arbitrage faucet (BLOCKING validation) | ADR-0003 | ✅ Covered |
| TR-cdb-007 | cdb | REDUCE_HEAT cannot rescue already-Overheated Symbot (preventive-only) | ADR-0003 | ✅ Covered |
| TR-cdb-008 | cdb | Effect magnitudes flat integers (not %-of-max); pure integer clamps, no floor/ceil | ADR-0003 | ✅ Covered |
| TR-df-001 | df | Pure stateless function: no runtime state, inputs -> output only | ADR-0005 | ✅ Covered |
| TR-df-002 | df | Type effectiveness multiplier applied before floor(), not after | ADR-0005 | ✅ Covered |
| TR-df-003 | df | RNG injection: crit_mult must be passable parameter, not hardcoded internally | ADR-0006 | ✅ Covered |
| TR-df-004 | df | Float division required: cast A, D to float before dividing to avoid integer truncation | ADR-0005 | ✅ Covered |
| TR-df-005 | df | Damage floor applies after floor(), via max(DAMAGE_FLOOR, result) | ADR-0005 | ✅ Covered |
| TR-df-006 | df | Division-by-zero guard: if A==0 AND D==0, return DAMAGE_FLOOR before division | ADR-0005 | ✅ Covered |
| TR-sa-001 | sa | Stat derivation pipeline (SA-F1) is sole executor of Part DB Formula 1/2/2b | ADR-0005 | ✅ Covered |
| TR-sa-002 | sa | Per-part upgrades: Formula 2 (base>=0) or Formula 2b (base<0) applied then summed | ADR-0005 | ✅ Covered |
| TR-sa-003 | sa | Chassis modifier applied to summed stats, then floor() post-multiplication | ADR-0005 | ✅ Covered |
| TR-sa-004 | sa | CP-F3 level-growth added post-chassis-multiply, pre-synergy (Rule 6 step 4b) | ADR-0005 | ✅ Covered |
| TR-sa-005 | sa | SA-F2 delta preview requires full hypothetical recompute (all 8 parts, not partial diff) | ADR-0008 (planned: UI architecture & screen contracts) | ❌ Gap |
| TR-sa-006 | sa | Final stats locked at battle start; no recomputation during combat | ADR-0005 | ✅ Covered |
| TR-sa-007 | sa | No empty slots permitted: equip is atomic, slots always filled via replacement | ADR-0005 | ✅ Covered |
| TR-sa-008 | sa | Move pool fixed ordering: Basic, WEAPON skill, HEAD skill, ARMS skill (may be null) | ADR-0005 | ✅ Covered |
| TR-sa-009 | sa | Passive pool order: CORE, LEGS, then remaining slots in slot-type order | ADR-0005 | ✅ Covered |
| TR-syn-001 | syn | Tag count is pure sum per SYN-F1; each part contributes all tags including duplicates | ADR-0005 | ✅ Covered |
| TR-syn-002 | syn | Tier activation (SYN-F2) requires ALL constituent tag counts met (AND logic) | ADR-0005 | ✅ Covered |
| TR-syn-003 | syn | Bonus blocks cumulative at all active tiers; both 3-piece and 5-piece stack | ADR-0005 | ✅ Covered |
| TR-syn-004 | syn | Combined synergies stack additively with constituent bonuses, not replacement | ADR-0005 | ✅ Covered |
| TR-syn-005 | syn | Effect deduplication keep-first in registration order (alphabetical tier ID) | ADR-0005 | ✅ Covered |
| TR-syn-006 | syn | Registration order determined by alphabetical tier-ID sort, not content-file order | ADR-0005 | ✅ Covered |
| TR-syn-007 | syn | Tier with empty requirements or min_count<1 skipped with content error logged | ADR-0005 | ✅ Covered |
| TR-syn-008 | syn | Cached bonus block frozen during battle (behavioral contract, not self-lock) | ADR-0005 | ✅ Covered |
| TR-syn-009 | syn | preview() call is pure read-only: no cache write, no signal emit | ADR-0005 | ✅ Covered |
| TR-syn-010 | syn | SYN-F4 effective stat formula: max(0, base + synergy_delta) — consumer responsibility | ADR-0005 | ✅ Covered |
| TR-syn-011 | syn | evaluate() always emits signal per Rule 7, even if bonus_block identical | ADR-0002 | ✅ Covered |
| TR-syn-012 | syn | active_synergies list must be Array[StringName] never null, including empty build | ADR-0005 | ✅ Covered |
| TR-syn-013 | syn | Null synergy_tags treated as [] (no tags); iteration must guard against null | ADR-0005 | ✅ Covered |
| TR-syn-014 | syn | Unregistered effect IDs pass through unfiltered; skip-and-log is TBC responsibility | ADR-0002 | ✅ Covered |
| TR-eai-001 | eai | Profile resolution: StringName to Profile, O(1) lookup registry | ADR-0003 | ✅ Covered |
| TR-eai-002 | eai | Profiles data-driven Resource, not hardcoded; loaded once at startup (ED4) | ADR-0003 | ✅ Covered |
| TR-eai-003 | eai | EnemyDef.ai_profile StringName resolution to AI profile (O(1) lookup) | ADR-0003 | ✅ Covered |
| TR-eai-004 | eai | Seeded RNG injected per call, fresh instance, no persistent state | ADR-0006 | ✅ Covered |
| TR-eai-005 | eai | Pure function of (battle_state, profile, seed); deterministic tiebreak | ADR-0006 | ✅ Covered |
| TR-eai-006 | eai | DF-1 preview includes MOVE-F1 power-tier multiply for lethal accuracy | ADR-0005 (DamageFormula/effective_stat contract) / ADR-0007 (AI preview consumption — planned) | ⚠️ Partial |
| TR-eai-007 | eai | Effective post-SYN-F4 defense stat used in preview, not raw stat | ADR-0005 (DamageFormula/effective_stat contract) / ADR-0007 (AI preview consumption — planned) | ⚠️ Partial |
| TR-eai-008 | eai | Phase shift derived from battle state, no persistent AI state | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-eai-009 | eai | Fallback to AGGRESSIVE profile on unknown ai_profile, never crashes | ADR-0007 (planned: TBC finite state machine) | ❌ Gap |
| TR-elzs-001 | elzs | Enemy level field manually authored, not formula-generated stat | ADR-0003 | ✅ Covered |
| TR-elzs-002 | elzs | xp_value stored-equals-derived from CP-F4, recomputed on constant retune | ADR-0003 | ✅ Covered |
| TR-elzs-003 | elzs | Zone level band [floor, roof] fields, content validation membership check | ADR-0003 | ✅ Covered |
| TR-elzs-004 | elzs | DS-F-LEVEL level_rarity_mult factor injected into Drop System effective_drop_rate | ADR-0003 | ✅ Covered |
| TR-elzs-005 | elzs | LEVEL_RARITY_MULTS lookup table (level_band x rarity) data-driven | ADR-0003 | ✅ Covered |
| TR-elzs-006 | elzs | MAX_ENEMY_LEVEL = 10 cap enforced, matches MAX_CORE_LEVEL | ADR-0003 | ✅ Covered |
| TR-elzs-007 | elzs | level_band(level) sub-function, deterministic boundary at LEVEL_BAND_MID_FLOOR/HIGH_FLOOR | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-zwm-001 | zwm | WorldMap resource authority for zone graph: zones array + current_zone_id runtime field | ADR-0003 pattern applies; WorldMap catalog not yet in ADR-0003 def roster — extend at implementation | ⚠️ Partial |
| TR-zwm-002 | zwm | Persist win_count/boss_progress (incl. defeated_once); zone states re-derived on load, never stored | ADR-0001 | ✅ Covered |
| TR-zwm-003 | zwm | ZoneNode.zone_id one-to-one StringName reference to Encounter Zone | ADR-0003 | ✅ Covered |
| TR-zwm-004 | zwm | win_count incremented on encounter_resolved(result=WIN, type=WILD) relay, WILD-only | ADR-0002 | ✅ Covered |
| TR-zwm-005 | zwm | Boss-gate delegation: Encounter Zone gate-check passed win_count + boss_progress | ADR-0002 | ✅ Covered |
| TR-zwm-006 | zwm | Zone state (LOCKED/ACCESSIBLE/CLEARED) derived via ZWM-F2 reachability BFS | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-zwm-007 | zwm | CLEARED does not guarantee reachability; can_travel validates traversable edge + state | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-zwm-008 | zwm | zone_states_changed(transitions) broadcast only when states differ from prior pass | ADR-0002 | ✅ Covered |
| TR-zwm-009 | zwm | Transitions array format {zone_id, from_state, to_state} consumed by World Map UI | ADR-0008 (planned: UI architecture & screen contracts) | ❌ Gap |
| TR-zwm-010 | zwm | ZWM-F2: all_bosses_defeated returns false for zero-boss zones, never auto-CLEARED | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-drop-001 | drop | RNG draws seeded, deterministic, part-ID-ascending roll order for reproducibility | ADR-0006 | ✅ Covered |
| TR-drop-002 | drop | Pool part-ID deduplication: one roll per unique ID; duplicates contribute zero extra rolls | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-drop-003 | drop | Pity counters persist across sessions (Prototype credit, Boss-grade break counter) | ADR-0001 | ✅ Covered |
| TR-drop-004 | drop | Consumes battle_ended VICTORY-only; fired_break_events as deduplicated Set from Part-Break | ADR-0002 | ✅ Covered |
| TR-drop-005 | drop | Pity-guaranteed drops skip RNG draw; stream position stays synchronized with non-guaranteed rolls | ADR-0006 | ✅ Covered |
| TR-drop-006 | drop | Unknown condition keys logged as content error, skipped, no crash; multiplier not applied | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-drop-007 | drop | Prototype pity: credit threshold = N_PROTO_PITY x C (C = condition count); increments by conditions fired | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-drop-008 | drop | Boss-grade pity: M_BOSS_PITY = 8 consecutive qualifying-break failures triggers guarantee | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-drop-009 | drop | Scrap yield per-rarity ordering invariant: Common < Rare < Prototype < Boss-grade, never inverted | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-drop-010 | drop | Drop output: new part instances at upgrade_tier=0, handed to Inventory; pity counter reset/updated | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-drop-011 | drop | Beacon multiplier (2.0) injected into effective_drop_rate on VICTORY when beacon_used_this_battle | ADR-0002 | ✅ Covered |
| TR-drop-012 | drop | Level-rarity multiplier (DS-F-LEVEL) injected into DS-1 before condition multipliers; Prototype row = 1.0 | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-ez-001 | ez | Zone defines terrain patches, each with weighted spawn pool (enemy_id, spawn_weight, is_farmable_target) | ADR-0003 | ✅ Covered |
| TR-ez-002 | ez | Enemy subpool validation: exclude entries with spawn_enabled=false, wrong enemy_class, weight<=0 | ADR-0003 | ✅ Covered |
| TR-ez-003 | ez | EZ-1 encounter-rate modifier hook: effective_rate = clamp(encounter_rate x active_modifier, 0, 1) | ADR-0002 | ✅ Covered |
| TR-ez-004 | ez | Boss gate re-evaluated on encounter_resolved + boss-approach query; never mid-battle | ADR-0002 | ✅ Covered |
| TR-ez-005 | ez | WIN_COUNT counter cumulative, all-time, zone-wide, never-resetting; wins-only (fled/lost excluded) | ADR-0001 | ✅ Covered |
| TR-ez-006 | ez | Boss 2 requires_defeated sequencing: gate met only when win threshold AND named boss defeated_once | ADR-0003 | ✅ Covered |
| TR-ez-007 | ez | LIGHTER_REGATE delta-measured: win_count - wins_at_last_defeat (snapshot per-boss per defeat) | ADR-0001 | ✅ Covered |
| TR-ez-008 | ez | Boss gate defaults LOCKED on missing gate_params, unresolvable prerequisite, or reserved gate type | ADR-0003 | ✅ Covered |
| TR-ez-009 | ez | Identity-enemy invariant per terrain: each patch has >=1 enemy_id appearing in no other patch in zone | ADR-0003 | ✅ Covered |
| TR-ez-010 | ez | Farmable-target weight floor: is_farmable_target=true entries >=20% of patch total_weight, else warning | ADR-0003 | ✅ Covered |
| TR-wl-001 | wl | Loot node defs are authored content; loot_id uniqueness violation is fatal at load (returns {ok:false}) | ADR-0003 | ✅ Covered |
| TR-wl-002 | wl | Collected loot_id Set persists (snapshot/restore via Exploration Progress domain contract) | ADR-0001 | ✅ Covered |
| TR-wl-003 | wl | Collection one-time permanent; derived state (UNCOLLECTED/COLLECTED) readable via get_node_state() | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-wl-004 | wl | node_collected(loot_id) signal on successful collection; collect_refused signal with reason on reject | ADR-0002 | ✅ Covered |
| TR-wl-005 | wl | Inventory deposit check (SCRAP_MAX ceiling, stack space) delegated to Inventory; refusal leaves no residue | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-wl-006 | wl | Snapshot returns fresh Dictionary {collected: [sorted StringName Array]} per call (no aliasing) | ADR-0001 | ✅ Covered |
| TR-wl-007 | wl | Double-collect idempotent (silent no-op logic; presentation owned by Overworld Navigation) | System-internal (GDD rules + unit tests; no ADR required) | ✅ System-internal |
| TR-wl-008 | wl | Phantom nodes (bad payload, bad reward_type, unresolved zone_id) logged, treated as uncollectable | ADR-0003 | ✅ Covered |
| TR-wl-009 | wl | Orphaned collected IDs on restore preserved, never dropped; one warning logged on load | ADR-0001 | ✅ Covered |
| TR-ui-001 | ui | All UI touch-first: minimum 44x44pt tap targets, no hover-only interactions | ADR-0008 (planned: UI architecture & screen contracts) | ❌ Gap |
| TR-ui-002 | ui | Dual input support: keyboard/mouse (Mac dev/launch) and touch (iOS primary) for every interaction | ADR-0008 (planned: UI architecture & screen contracts) | ❌ Gap |
| TR-perf-001 | perf | 60 fps / 16.6 ms frame budget on target devices | ADR-0004 (transition hitch path); per-system frame budgets pending ADR-0007/0008 | ⚠️ Partial |
| TR-perf-002 | perf | iOS 512 MB memory ceiling; persistence budget 2 MiB blob / 50 ms write | ADR-0001 | ✅ Covered |
| TR-perf-003 | perf | Draw-call budget 200 (conservative mobile 2D) | ADR-0008 (planned: UI architecture & screen contracts) | ❌ Gap |
| TR-eng-001 | eng | Post-cutoff FileAccess.store_* bool return handled on every write (Godot 4.4+) | ADR-0001 | ✅ Covered |
| TR-eng-002 | eng | Every post-cutoff engine API verified against docs/engine-reference before use | Engine Compatibility section mandatory per ADR (discipline in force across ADR-0001..0004) | ⚠️ Partial |
| TR-test-001 | test | GUT framework; >=80% coverage on logic systems; deterministic, isolated, injection-friendly tests | ADR-0003 (CI-blocking validator) + ADR-0006 (determinism contract) | ✅ Covered |

## Known Gaps

All remaining gaps are owned by the two planned-but-unwritten ADRs (expected at this phase):

### ADR-0007 (planned: TBC finite state machine) — 45 requirements
TR-tbc-001, TR-tbc-003, TR-tbc-006, TR-tbc-007, TR-tbc-008, TR-tbc-009, TR-tbc-010, TR-tbc-011, TR-tbc-014, TR-tbc-015, TR-tbc-016, TR-tbc-017, TR-tbc-018, TR-tbc-019, TR-tbc-020, TR-tbc-021, TR-tbc-022, TR-tbc-023, TR-tbc-024, TR-tbc-025, TR-tbc-026, TR-tbc-027, TR-tbc-028, TR-tbc-029, TR-tbc-030, TR-tbc-031, TR-tbc-032, TR-tbc-034, TR-tbc-036, TR-tbc-037, TR-tbc-038, TR-tbc-042, TR-pb-001, TR-pb-002, TR-pb-003, TR-pb-004, TR-pb-006, TR-pb-007, TR-pb-010, TR-pb-011, TR-pb-012, TR-pb-013, TR-pb-014, TR-eai-008, TR-eai-009

### ADR-0008 (planned: UI architecture & screen contracts) — 6 requirements
TR-cp-012, TR-sa-005, TR-zwm-009, TR-ui-001, TR-ui-002, TR-perf-003

## Partial Coverage (5 requirements)

- **TR-eai-006, TR-eai-007** — ADR-0005 provides the `DamageFormula` + `effective_stat` contract; the AI-side preview consumption (MOVE-F1 inclusion, post-SYN-F4 defense) is owned by ADR-0007. Flips to Covered when ADR-0007 lands.
- **TR-zwm-001** — WorldMap catalog not yet in ADR-0003's def roster; extend at implementation.
- **TR-perf-001** — per-system frame budgets pending ADR-0007/0008 (ADR-0004 covers the transition-hitch path).
- **TR-eng-002** — engine-verification discipline is in force across ADR-0001..0006 but has no single owning ADR.

Suggested creation order (most foundational first):
1. `/architecture-decision Turn-based combat state machine` (ADR-0007) — 45 TRs; MUST resolve the `battle_ended`-host seam (conflict C-3: ADR-0002 puts `is_battle_active` on a TBC autoload that ADR-0004's roster lacks)
2. `/architecture-decision UI architecture & screen contracts` (ADR-0008) — 6 TRs

## Superseded Requirements

None — first review; no requirement has changed since its ADR was written.
