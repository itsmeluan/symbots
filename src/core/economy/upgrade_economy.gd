## UpgradeEconomy — what a part level costs, and charging for it (Core Design §5).
##
## The whole economy hangs off one sentence in §5.2: **Scrap is ONE pool and every Symbot
## competes for it.** Everything here exists to keep that competition real — costs that
## climb steeply enough that "do I spread or concentrate?" stays a live question, and never
## a per-Symbot sub-pool that would dissolve it.
##
## Pure static over an injected [BalanceConfig] and [Wallet]. No autoload, so the Workshop
## screen, the offline expedition payout and the tests all price a level identically.
class_name UpgradeEconomy
extends RefCounted

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

## Why an upgrade was refused. Typed rather than a bool so the Workshop can say which wall
## the player hit — "you cannot afford this" and "this part is at its cap until you
## retrofit" send the player to completely different places.
enum Refusal {
	OK = 0,
	NO_SUCH_PART = 1,
	AT_MARK_CAP = 2,
	CANNOT_AFFORD = 3,
}


## Scrap to take [param current_level] to the next level.
##
## Quadratic-ish rather than linear: a linear curve makes late levels trivial and the
## budget stops mattering, which would kill the tension §5.2 is built on. Costs are derived
## from BalanceConfig rather than hardcoded, per the coding standard that gameplay values
## are data-driven.
##
## Example:
##     var cost := UpgradeEconomy.level_cost(part_level, cfg)
static func level_cost(current_level: int, cfg: BalanceConfig) -> int:
	var lv := maxi(1, current_level)
	return cfg.part_upgrade_base_cost \
		+ cfg.part_upgrade_linear_cost * (lv - 1) \
		+ cfg.part_upgrade_quadratic_cost * (lv - 1) * (lv - 1)


## Total Scrap to take a part from [param from_level] to [param to_level]. Used by the
## Workshop's "cost to max" readout, which is what makes the budget decision visible
## BEFORE the player commits rather than after.
static func cost_to_reach(from_level: int, to_level: int, cfg: BalanceConfig) -> int:
	var total := 0
	for lv in range(maxi(1, from_level), maxi(1, to_level)):
		total += level_cost(lv, cfg)
	return total


## Can this part be levelled right now?
static func can_upgrade(inst: SymbotInstance, slot: int, wallet: Wallet,
		cfg: BalanceConfig) -> Refusal:
	if slot < 0 or slot >= SymbotInstanceScript.PART_COUNT:
		return Refusal.NO_SUCH_PART
	var level := inst.get_part_level(slot)
	if level >= inst.part_level_cap():
		return Refusal.AT_MARK_CAP
	if not wallet.can_afford(Wallet.SCRAP, level_cost(level, cfg)):
		return Refusal.CANNOT_AFFORD
	return Refusal.OK


## Charge the wallet and raise the part level. Returns the Scrap spent, or 0 when refused.
##
## The charge happens BEFORE the level rises, and only if the level actually rose — a
## wallet debited for a level that did not apply is the one bug in an economy a player
## never forgives.
static func upgrade(inst: SymbotInstance, slot: int, wallet: Wallet,
		cfg: BalanceConfig) -> int:
	if can_upgrade(inst, slot, wallet, cfg) != Refusal.OK:
		return 0
	var cost := level_cost(inst.get_part_level(slot), cfg)
	if not wallet.spend(Wallet.SCRAP, cost):
		return 0
	if not inst.level_up_part(slot):
		# Put it back. Reaching here means can_upgrade and level_up_part disagreed, which
		# is a bug — but the player must not pay for it.
		wallet.earn(Wallet.SCRAP, cost)
		return 0
	return cost


## Scrap to take every part to the current mark's cap. This is the number that makes the
## "spread or concentrate" decision concrete: seeing what one Symbot would consume is what
## stops the player defaulting to spreading thin.
static func cost_to_max_all_parts(inst: SymbotInstance, cfg: BalanceConfig) -> int:
	var total := 0
	var cap := inst.part_level_cap()
	for slot in SymbotInstanceScript.PART_COUNT:
		total += cost_to_reach(inst.get_part_level(slot), cap, cfg)
	return total


## Scrap awarded for winning one battle at [param stage_level]. Scales with the stage so a
## later stage is worth grinding, but sub-linearly against upgrade costs — if income kept
## pace with costs the budget would stop being a constraint and §5.2 would evaporate.
static func battle_reward(stage_level: int, cfg: BalanceConfig) -> int:
	return cfg.scrap_reward_base + cfg.scrap_reward_per_stage * maxi(0, stage_level - 1)


## The stage-completion chest (§6). Deliberately a large multiple of a single battle:
## finishing has to be worth more than farming the first fight forever, or players optimise
## by replaying the easiest battle and the stage structure stops meaning anything.
static func chest_reward(stage_level: int, cfg: BalanceConfig) -> int:
	return battle_reward(stage_level, cfg) * cfg.scrap_chest_multiplier
