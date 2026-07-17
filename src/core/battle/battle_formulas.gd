## BattleFormulas — the seven Turn-Based Combat formulas TBC-F1…F7 (ADR-0005 /
## ADR-0007; GDD "Formulas").
##
## Pure, stateless, static-only: call as `BattleFormulas.shock_magnitude(...)` —
## never instanced. Each method is one GDD formula; coefficients are injected via
## [BalanceConfig] (never hardcoded), and every multiply-then-round routes through
## [StatMath.floor_eps] — the ONE shared epsilon, never a second one.
##
## [b]Epsilon status (GDD scan-verified 2026-07-10/11):[/b] every `+ EPSILON` nudge
## in TBC-F1…F7 is DEFENSIVE, not load-bearing — an exhaustive python3 scan over
## 95,000+ inputs found zero bare-floor errors. They are retained as project
## convention. Re-run the scan only if a coefficient in [BalanceConfig] is retuned.
##
## [b]Sign discipline (TBC-F4):[/b] [method shock_magnitude] returns a POSITIVE
## magnitude (0–33) that [method effective_mobility] subtracts — never store a
## pre-negated value (a double negation would make Shock RAISE mobility).
##
## [b]Status potency snapshot is PRE-synergy[/b] (GDD ratified): Burn/Shock/Stagger
## magnitudes read the applier's `final_stat["processing"]` at application, NOT the
## SYN-F4 effective value. TBC-F6 Repair is the exception — it scales on EFFECTIVE
## `energy_power` (SYN-F4), the caller passing [StatMath.effective_stat]'s output.
class_name BattleFormulas
extends RefCounted

# ---------------------------------------------------------------------------
# TBC-F1 — Initiative order
# ---------------------------------------------------------------------------

## `effective_mobility = max(0, base_mobility + synergy_mobility_delta − shock_magnitude)`
## (GDD TBC-F1). [param base_mobility] is `final_stat["mobility"]` (enemy: `stats["mobility"]`);
## [param synergy_mobility_delta] is the frozen synergy block's mobility delta (0 for
## enemies, Rule 8); [param shock_magnitude] is [method shock_magnitude] output when
## Shock is active, else 0. Floored at 0 — pure integer arithmetic, no epsilon.
##
## Worked (discriminating): base 64, shock 15, no synergy → 49.
static func effective_mobility(base_mobility: int, synergy_mobility_delta: int,
		shock_magnitude: int) -> int:
	return maxi(0, base_mobility + synergy_mobility_delta - shock_magnitude)

# ---------------------------------------------------------------------------
# TBC-F2 — Energy recharge
# ---------------------------------------------------------------------------

## `new_energy = min(max_energy_capacity, current_energy + base_energy_regen + recharge)`
## (GDD TBC-F2, Rule 4.1b, player Symbots only). Pure integer arithmetic — the GDD
## marks this formula "no epsilon applies". The `min` cap is load-bearing.
##
## Worked (paired): min(95, 73+10+22)=95 (cap fires); min(95, 40+10+22)=72 (cap silent).
static func recharge_energy(current_energy: int, recharge_stat: int,
		max_energy_capacity: int, cfg: BalanceConfig) -> int:
	return mini(max_energy_capacity, current_energy + cfg.base_energy_regen + recharge_stat)

# ---------------------------------------------------------------------------
# TBC-F3 — Burn damage (DoT)
# ---------------------------------------------------------------------------

## `burn_damage = max(burn_min, floor(snapshotted_processing × burn_coeff + ε))`
## (GDD TBC-F3, Rule 4.1c). [param snapshotted_processing] is the applier's
## PRE-synergy processing frozen on the status instance. Bypasses DF-1 — the caller
## reduces `current_structure` directly (Armor/Resistance/type do not apply); not
## reduced by Stagger (DoT is not a move).
##
## Worked (discriminating): processing 72 → max(2, floor(5.7601)) = 5 (round/ceil → 6).
static func burn_damage(snapshotted_processing: int, cfg: BalanceConfig) -> int:
	return maxi(cfg.burn_min, StatMath.floor_eps(float(snapshotted_processing) * cfg.burn_coeff))

# ---------------------------------------------------------------------------
# TBC-F4 — Shock mobility reduction
# ---------------------------------------------------------------------------

## `shock_magnitude = floor(snapshotted_processing × shock_coeff + ε)` (GDD TBC-F4),
## returned POSITIVE (0–33) for [method effective_mobility] to subtract. A
## zero-processing applier yields a legal 0-penalty Shock (EC-TBC-09).
##
## Worked (discriminating): processing 53 → floor(15.9001) = 15 (round/ceil → 16).
static func shock_magnitude(snapshotted_processing: int, cfg: BalanceConfig) -> int:
	return StatMath.floor_eps(float(snapshotted_processing) * cfg.shock_coeff)

# ---------------------------------------------------------------------------
# TBC-F5 — Stagger damage reduction
# ---------------------------------------------------------------------------

## Step 1: `stagger_pct = floor(snapshotted_processing × stagger_coeff + ε)` ∈ [0,27]
## (GDD TBC-F5). The percentage frozen on the Stagger status instance.
##
## Worked (discriminating): processing 86 → floor(21.5001) = 21 (round-half-away → 22).
static func stagger_pct(snapshotted_processing: int, cfg: BalanceConfig) -> int:
	return StatMath.floor_eps(float(snapshotted_processing) * cfg.stagger_coeff)

## Step 2: `staggered_damage = max(DAMAGE_FLOOR, floor(final_damage × (1 − pct/100) + ε))`
## (GDD TBC-F5, applied POST-MOVE-F1 to every DAMAGE move the Staggered combatant
## uses). [param final_damage] is the MOVE-F1 output (1–315). Floored at
## [param cfg].`damage_floor` — Stagger cannot zero a hit.
##
## Worked (discriminating): final_damage 50, pct 21 → max(1, floor(39.5001)) = 39 (round → 40).
static func apply_stagger(final_damage: int, stagger_percentage: int, cfg: BalanceConfig) -> int:
	var reduced := float(final_damage) * (1.0 - float(stagger_percentage) / 100.0)
	return maxi(cfg.damage_floor, StatMath.floor_eps(reduced))

# ---------------------------------------------------------------------------
# TBC-F6 — Repair amount
# ---------------------------------------------------------------------------

## `repair_amount = max(repair_min, floor(effective_energy_power × repair_coeff + repair_base + ε))`
## (GDD TBC-F6). [param effective_energy_power] is the SYN-F4 EFFECTIVE energy_power
## (0–150) — the caller passes [StatMath.effective_stat]'s output, NOT the base stat.
## The caller then caps at `max_structure` and pays Energy/heat regardless (EC-TBC-10).
##
## Worked (discriminating): ep 45 → max(5, floor(12.6501)) = 12 (round/ceil → 13);
## ep 150 → 30 (round → 31).
static func repair_amount(effective_energy_power: int, cfg: BalanceConfig) -> int:
	return maxi(cfg.repair_min,
		StatMath.floor_eps(float(effective_energy_power) * cfg.repair_coeff + float(cfg.repair_base)))

# ---------------------------------------------------------------------------
# TBC-F7 — Enemy enrage multiplier (Part-Break PB-F5, TBC-applied POST-Stagger)
# ---------------------------------------------------------------------------

## `enraged_damage = max(DAMAGE_FLOOR, floor(enemy_hit_resolved × (1 + count × enrage_per_break) + ε))`
## (GDD TBC-F7). [param enemy_hit_resolved] is the enemy's POST-DF-1/MOVE-F1/Stagger
## outgoing damage; [param broken_region_count] ∈ [0,3] the enemy's currently-broken
## regions (Story 009 unit-tests this with a STUBBED count — the real Part-Break
## accrual chain lands with that epic). At count 0 the multiplier is exactly 1.00 —
## the identity path, no change.
##
## Worked (discriminating): hit 43, count 1 → floor(48.16…) = 48 (round/ceil → 49);
## hit 41, count 3 → floor(55.76) = 55 (round/ceil → 56); hit 43, count 0 → 43 (identity).
static func enrage_damage(enemy_hit_resolved: int, broken_region_count: int,
		cfg: BalanceConfig) -> int:
	var multiplier := 1.0 + float(broken_region_count) * cfg.enrage_per_break
	return maxi(cfg.damage_floor, StatMath.floor_eps(float(enemy_hit_resolved) * multiplier))
