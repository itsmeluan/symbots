## XpProgression — battle XP into Symbot levels (Core Design §2.2, §4.2).
##
## Levels are the ONLY source of skill points (§4.2), and XP is the only source of levels.
## Nothing here can be bought: Scrap levels parts, XP levels the Symbot, and keeping those
## two currencies unable to substitute for each other is what stops money short-circuiting
## the build.
##
## Pure static over an injected [BalanceConfig].
class_name XpProgression
extends RefCounted


## XP needed to go from [param level] to the next one.
##
## Accelerating, like the Scrap curve and for the same reason: a flat curve makes late
## levels arrive on their own and the decision of WHERE to fight stops mattering.
static func xp_to_next(level: int, cfg: BalanceConfig) -> int:
	var lv := maxi(1, level)
	return cfg.xp_base + cfg.xp_linear * (lv - 1) + cfg.xp_quadratic * (lv - 1) * (lv - 1)


## Total XP from level 1 to [param level].
static func total_xp_to_reach(level: int, cfg: BalanceConfig) -> int:
	var total := 0
	for lv in range(1, maxi(1, level)):
		total += xp_to_next(lv, cfg)
	return total


## XP one Symbot earns for a won battle against [param enemy_count] enemies at
## [param enemy_level].
##
## The whole squad earns the same amount rather than splitting a pot. Splitting would
## punish fielding four Symbots, which is exactly the shape the game wants — and it would
## make the optimal play a solo carry, which is the opposite of a squad game.
static func battle_xp(enemy_level: int, enemy_count: int, cfg: BalanceConfig) -> int:
	return (cfg.xp_reward_base + cfg.xp_reward_per_enemy_level * maxi(1, enemy_level)) \
		* maxi(1, enemy_count)


## Award XP and apply as many level-ups as it buys. Returns levels gained.
##
## XP past the cap is KEPT rather than discarded. A Symbot at its mark cap that has been
## fighting should not have wasted that time — the moment a Retrofit raises the cap, the
## banked XP cashes in. Discarding it would silently punish playing before upgrading.
static func grant(inst: SymbotInstance, amount: int, cfg: BalanceConfig) -> int:
	if inst == null or amount <= 0:
		return 0
	inst.xp += amount

	var gained := 0
	while inst.level < inst.level_cap():
		var needed := xp_to_next(inst.level, cfg)
		if inst.xp < needed:
			break
		inst.xp -= needed
		inst.level += 1
		gained += 1
	return gained


## Award the same XP to every Symbot in [param squad]. Returns total levels gained across
## the squad, for the post-battle summary.
static func grant_squad(squad: Array, amount: int, cfg: BalanceConfig) -> int:
	var total := 0
	for symbot in squad:
		total += grant(symbot, amount, cfg)
	return total


## Progress toward the next level, 0-100, for a UI bar. Returns 100 at the cap so the bar
## reads "full" rather than sitting at some arbitrary fraction forever.
static func percent_to_next(inst: SymbotInstance, cfg: BalanceConfig) -> int:
	if inst.level >= inst.level_cap():
		return 100
	var needed := xp_to_next(inst.level, cfg)
	return clampi(inst.xp * 100 / maxi(1, needed), 0, 100)
