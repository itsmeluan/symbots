# Symbots v1 — Core Design

> **Status**: Locked 2026-07-20. This document is the spine of the v1 direction and the
> authority for every downstream decision. The previous direction (modular Symbots +
> overworld) is frozen at `../../../symbots-v0/` and archived under `../_archive-v0/`.
>
> Decisions marked **[owner]** came from the project owner. Decisions marked **[claude]**
> were delegated with the instruction "decide and document" — they are open to reversal,
> but they are load-bearing, so reversing one means re-reading what depends on it.

---

## 1. What the game is

A portrait, mobile-first, turn-based squad battler. You collect predefined Symbots,
each with a fixed identity and visual, and you make them powerful in three parallel
ways: **levelling their parts with Scrap**, **walking a shared skill tree from their own
entry point**, and **retrofitting them into a stronger mark**.

Progression never ends. Early stages give way to an endless endgame, and offline
expeditions keep the roster earning while you are away.

### What changed from v0, and why

| v0 | v1 | Reason |
|---|---|---|
| Modular Symbots assembled from swappable parts | Predefined Symbots with fixed parts you level | Modular assembly demanded every part composite onto a shared rig at every combination — the hardest art problem in the project, and the one that stalled it |
| Overworld you walk | Stage select | The walking layer produced an unending art treadmill and carried no mechanic that stages cannot carry better |
| Break a region to harvest that part | No part breaking | With no parts to collect, breaking has nothing to gate; drops are now Scrap, items and blueprints |
| 1v1 with a bench | 4 vs 1–4 | Squad composition (roles) is the strategic layer that replaces build-from-parts |
| Landscape | Portrait | Mobile-first |

---

## 2. Symbots

### 2.1 Species and roles **[owner]**

**32 species at full scope; 8 authored for the playable slice.** Each species has:

- one fixed visual identity across three marks (see 2.3)
- exactly one **role**: DPS / TANK / HEALER / SUPPORT
- one **skill-tree entry point** (see §4)
- one or more **unique passives** unlocked at species-specific levels

Roles map onto the tree's 16 entry points: **4 entries per role**, 2 species sharing each
entry at full scope. The slice authors 8 species — two per role, each on a distinct entry
— so all four roles and four distinct entries are exercised from day one.

### 2.2 Rarity **[owner]**

Rarity is **not** a level cap. Every Symbot reaches the same maximum level; rarity
changes what it does with that level.

| Rarity | Base stats | Unique passives | Passive power | Overclock levels |
|---|---|---|---|---|
| Common | baseline | 1 | baseline | 0 |
| Rare | +15% | 2 | improved | 5 |
| Epic | +30% | 3 | strong, adds a secondary effect | 10 |
| Prototype | +50% | 4 | strongest, effects compound | 15 |

**Overclock** is the rarity payoff. Past the shared level cap, a rare-or-better Symbot
keeps levelling into overclock levels, which behave like ordinary levels except they
exceed the cap: they grant further skill-tree points (reaching tree depths a common
Symbot cannot) and raise part levels beyond the normal ceiling.

The design intent: a common Symbot is never obsolete — it reaches full standard power —
but a Prototype has a ceiling above it that only long investment reaches.

### 2.3 Marks and Retrofit **[owner]**

Each species exists as **Mk I → Mk II → Mk III**, three distinct sprites. The act of
advancing is **Retrofit**.

Retrofit triggers when **every part on the Symbot reaches that mark's part-level cap**.
It does **not** reset part levels. It raises the cap, so progression is always forward:

| Mark | Part level cap | Symbot level cap |
|---|---|---|
| Mk I | 20 | 20 |
| Mk II | 40 | 40 |
| Mk III | 60 | 60 |
| + Overclock | +1 per overclock level | +1 per overclock level |

**[claude]** The 60 ceiling and the 20/40/60 split were chosen so that: each mark is a
substantial arc rather than a formality; the mid-game (Mk II) is where a player spends
the most time, which is where a live game wants them; and part level and Symbot level
share a number, so the player learns one scale instead of two.

### 2.4 Parts

Parts are **fixed components of a species**, not equipment. Each Symbot has **5 parts**:
`CORE`, `CHASSIS`, `HEAD`, `ARMS`, `LEGS`.

**[claude]** Five, not the v0 eight. `CHIPSET` and `ENERGY_CELL` existed to be swapped and
to carry synergy tags; with nothing to swap and synergy replaced by the tree they were two
more upgrade sinks with no identity. **[owner]** `WEAPON` came out because on a
fixed-species sprite a separate weapon never reads as its own part — it costs art effort
and returns no visual identity. What a species fights with is expressed by its ARMS and
its skills. Five parts x 60 levels is still 300 upgrade steps per Symbot.

Levelling a part costs **Scrap** and raises the stats that part contributes. Part
identity (which stats it feeds) is authored per species, so the same slot means different
things on a tank and a healer.

---

## 3. Battle

### 3.1 Shape

**4 player Symbots vs 1–4 enemies.** Enemy count varies by stage, mode and encounter
type. Portrait layout, **player squad on the LEFT column, enemies on the RIGHT** —
four rows per side, HP bar above each unit.

Manual by default with an **auto-battle toggle** **[owner]**. Auto uses the same rules
the player would: it never gets information or options the manual player lacks.

### 3.2 Turn order

**[claude]** Speed-based, recomputed at the start of each round, stable within a round.
A unit that dies mid-round loses its pending turn. Ties break toward the player — the
same tie rule v0 used, kept because "the player acts first on a tie" is the version that
never feels cheated.

### 3.3 Targeting and the Taunt rule **[owner]**

**While a living TANK is present on the defending side, attacks must target a TANK.**
This is what makes the role real rather than a stat spread.

Exceptions, and they are the interesting part of the system:

| Exception | Source |
|---|---|
| **Pierce** | a skill flagged `ignores_taunt` may target any unit |
| **Backline** | a passive granting the Symbot permanent taunt-ignoring |
| **Taunt broken** | a debuff that suppresses a specific tank's taunt for N turns |
| **Multiple tanks** | the attacker chooses freely among living tanks |

Effects that hit multiple targets (`ALL_ENEMIES`, `ROW`, `SPLASH`) ignore taunt by
construction — they are not choosing a target, so there is nothing for taunt to redirect.

### 3.4 Skills

**[claude]** **Cooldown-based, no energy pool.** One resource is one thing to learn; the
reference layout the owner supplied shows cooldowns and no energy bar, and cooldowns
alone already produce rotation decisions. Energy would add a second axis without adding a
second kind of decision.

Each Symbot fields **3 active skill slots**, unlocked by level (slot 1 from the start,
slot 2 and 3 at level thresholds). Actives come from the skill tree; which three the
player slots is a build decision.

Every Symbot also has a **basic attack** with no cooldown, so a turn is never wasted.

### 3.4b Ultimate skills **[owner]**

Every Symbot has an **ultimate**, and it comes from the **skill tree like everything
else** — the tree is the single source of actives, passives, stats and buffs, and ults are
not an exception carved out beside it. A Symbot's ult is therefore a *build decision*, not
a species property: two Rustcrawlers that walked different paths field different ults.

The ult occupies a **dedicated fourth slot**, separate from the 3 active slots. Making it
compete with the actives would mean most players never slot one — a skill that costs a
rotation slot to hold is a skill that stays in the tree.

**[claude]** Ults are ACTIVE nodes with `is_ultimate` set, so they inherit the whole
existing pipeline — reachability gating, point cost, cooldown, targeting, the taunt rule —
rather than needing a parallel system. What separates them mechanically:

- **Charge, not cooldown.** An ult starts a battle uncharged and fills through the fight.
  A long cooldown would let a player open with the ult in every trivial fight; a charge
  meter makes the ult a *reward for surviving*, which is what an ult should feel like.
- **One ult slotted at a time.** The tree may grant several; the player picks one.
- **Ults skip the basic-attack fallback.** When uncharged, the slot is simply unusable.

**Charge persists across fights inside a dungeon run [owner]**, exactly as structure
does (§3.6). A dungeon is therefore one continuous resource arc rather than a series of
independent fights: clearing an early room cheaply banks charge for the boss room, and
spending an ult on trash is a real cost. It also makes the two carried resources — falling
structure and rising charge — pull in opposite directions as a run goes deeper, which is
the tension a run should have.

Charge resets between runs, like everything else outside the run.

Charge sources, rate and the exact meter live in `03-battle-system.md`.

### 3.5 Status effects

A complete set, because the owner asked for systems rich enough to carry a simple game:

| Category | Effects |
|---|---|
| Damage over time | Burn, Corrode, Shock |
| Control | Stun (skip turn), Slow (speed down), Taunt-break |
| Defensive | Shield (absorbs damage), Regen, Damage reduction |
| Offensive | Attack up/down, Crit up, Pierce |
| Utility | Cooldown reduction, Cleanse, Revive |

Stacking rules, duration handling and resolution order live in `03-battle-system.md`.

### 3.6 Defeat

A battle is lost when **all four player Symbots are down**. Downed Symbots recover
between battles; there is no permanent loss. Within a dungeon run, **structure carries
between fights** and everything else resets **[owner]** — consumables are the lever that
manages that attrition.

---

## 4. The skill tree

### 4.1 One tree, sixteen doors **[owner]**

There is **one shared tree**. Each species enters at one of **16 entry points** — 4 per
role — and walks outward from there. Two species share an entry at full scope; the paths
they take from it diverge by which nodes they can afford and reach.

This is the Path of Exile model, chosen because authoring 32 trees is not shippable and
because a shared tree makes distance meaningful: a healer *can* reach a DPS cluster, but
it costs a long walk that a DPS gets for free.

### 4.2 Points **[owner]**

**Skill points are per Symbot.** Each Symbot earns its own points from its own battle XP
and spends them on its own path. Two players' Rustcrawlers can be built differently, and
the same player's two Rustcrawlers can be too.

### 4.3 Node types

| Type | Effect |
|---|---|
| **Stat** | flat or percentage stat increase. The connective tissue and the endgame sink |
| **Passive** | a named permanent effect |
| **Active** | grants a skill the Symbot can slot |
| **Ultimate** | an Active with `is_ultimate` — charge-gated, own slot (see 3.4b) |
| **Keystone** | a large effect with a real drawback — build-defining |
| **Socket** | **locked until an item is installed** (see 4.4) |

### 4.4 Socket nodes and install items **[owner]**

Certain nodes are **gated by hardware**. They cannot be bought with points alone: the
player must install a dropped component into the socket.

**[claude]** Item taxonomy, matched to the fiction:

| Item | Gates |
|---|---|
| **RAM Chip** | cooldown, action economy, turn-order nodes |
| **Processor** | crit, accuracy, skill-scaling nodes |
| **Capacitor** | burst damage, charge, overload nodes |
| **Heat Sink** | survivability, damage reduction, regen nodes |
| **Servo** | speed, evasion, extra-action nodes |

Items have tiers; a higher-tier item in the same socket gives a stronger version of the
node. Installed items **can be removed, at a cost in Scrap** **[owner]** — so a wrong
install is a setback, never a dead end. This is deliberate: a system the player is afraid
to touch is a system they do not engage with.

### 4.5 Respec **[owner]**

Respec exists and costs. **[claude]** Cost is per-point, scaling with how many points are
already refunded in that session, so small corrections are cheap and a full rebuild is a
real decision. Respec is a **Scrap** sink, never a premium-only feature — a build system
the player cannot experiment with is a build system that produces one build.

### 4.6 Endless depth **[owner]**

Beyond the designed region, the tree continues into a large outer field of **stat-only
nodes**. They are deliberately unglamorous: the interesting decisions are finite, the
progression is not.

---

## 5. Economy

### 5.1 Currencies

| Currency | Source | Sink |
|---|---|---|
| **Scrap** | every battle, every stage, expeditions | part levels, respec, item removal |
| **Alloy** **[claude]** | bosses, events, high stages | crafting Symbots from blueprints |
| **Blueprints** | boss and event drops | craft a specific species |

**[claude]** "Alloy" names the refined counterpart to raw Scrap — the fiction already
uses Alloy Ochre in its palette, and Scrap → Alloy reads instantly as common → rare.

### 5.2 The tension that drives retention **[claude]**

**Scrap is one pool and every Symbot competes for it.** Scrap spent on one Symbot is
Scrap another does not get. This is the engine of the whole economy:

- every upgrade is a real decision rather than a formality
- a new blueprint is not just a collectible — it becomes a claim on the player's budget
- the recurring question "do I spread or concentrate?" is what brings a player back

The counterweight: **different stages demand different squads**, so concentrating
everything into one Symbot hits a wall and the player is pushed to build a second and a
third. Expeditions then pay the bench — the Symbots not in the active squad still earn.

---

## 6. Structure and modes

| Mode | Shape |
|---|---|
| **Stage** | one battle |
| **Dungeon** | a sequence of battles; structure carries, everything else resets |
| **Raid** | reserved — a longer dungeon with a boss gate |
| **Endless** | after the authored stages, difficulty scales without end |

**Loot** **[owner]**: drops land per battle won, plus a **chest on completing the stage**.
The chest is the only source of blueprints and top-tier items — otherwise finishing has no
purpose and players optimise by dying deliberately.

**Defeat** **[owner]**: the player keeps everything already dropped. Losing costs the
chest and the time, never the session.

---

## 7. Offline expeditions **[owner]**

Symbots not in the active squad can be sent on timed expeditions that yield Scrap, items
and occasionally blueprint fragments. **[claude]** Slots start at 2 and expand; durations
run 1h / 4h / 8h so the game has both a lunch-break check-in and an overnight one.

Expeditions are the reason to own more Symbots than fit in a squad, and the reason the
bench is not dead weight.

---

## 8. Monetisation posture **[claude]**

Documented up front so it constrains design rather than being retrofitted onto it.

**Sells well and does not burn the player**: cosmetics, extra expedition slots,
expedition time-skips, a seasonal pass, blueprint pity/direct purchase.

**Deliberately excluded**: energy that blocks play, and power sold directly for money.
Both earn more in month one and destroy the retention this design is built to create. The
game's hook is the Scrap-budget tension; selling infinite Scrap sells the hook itself.

---

## 9. Open items

- **Economy pacing needs a playtest pass.** The cost and reward curves in
  `BalanceConfig` have the right SHAPE — costs accelerate, income does not keep pace, so
  the §5.2 budget tension holds — and the shape is what the tests pin. The magnitudes are
  an informed guess, not a measurement: at the current values one part reaches its Mk I cap
  in ~51 battles and all five in ~258, which is what triggers Retrofit. Whether that reads
  as a satisfying first arc or as a grind can only be answered by playing it.
- Exact stat list and formulas → `02-stats-and-formulas.md`
- Tree layout and node budget → `04-skill-tree.md`
- The 8 slice species → `05-species.md`
- Enemy roster and stage table → `06-content.md`
