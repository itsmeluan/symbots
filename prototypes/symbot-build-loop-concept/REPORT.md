# Concept Prototype Report: Symbot Build Loop

> **Date**: 2026-07-09
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

"If the player assembles a Symbot from collected parts and battles with it,
they will feel ownership over their creation — confirmed if they spontaneously
want to modify or upgrade their build after battle without being prompted."

---

## Riskiest Assumption Tested

**That the assembly step would feel like a meaningful choice, not a setup tax.**

The fear was that picking parts in a workshop screen would feel like a chore
players want to skip to get to the "real" game (combat). The prototype tested
whether the workshop itself was intrinsically motivating before any battle even
started.

**Result: the assumption held immediately.** The player began theorycrafting
combinations the moment the workshop loaded — before touching the Deploy button.
Ownership was created at selection, not at outcome.

---

## Approach

**Path chosen:** HTML (single browser file, no install)
**Reason for path:** The hypothesis was about decision satisfaction and loop
engagement, not timing feel. Browser latency does not distort these results.
Turn-based combat is logic, not physics.

**What was built:**
- Workshop screen: 5 part slots (Head, Body, Arms, Weapon, Core), 4 options each
- Live stat totals (HP, ATK, DEF, SPD, Element) updating as parts are selected
- Synergy detection: 2+ matching elements activate a set bonus
- Turn-based battle vs. Rustcrawler (physical type, HP 120) with type effectiveness
- 4 moves per Symbot (Basic Attack + 3 part-derived abilities)
- Part-break targeting: player can focus on a specific enemy part at −10% damage for +30% break chance
- Drop screen after battle: 2 base random drops + guaranteed drops from broken parts
- Inventory accumulates across loops

**Shortcuts taken (intentional):**
- Single enemy type (Rustcrawler); no map, exploration, or variety
- No menus, save system, music, or visual assets beyond colored rectangles
- Hardcoded enemy stats and drop pools
- No blueprint system, upgrade system, or workshop improvements
- Synergy system simplified to first-match-wins (only one synergy active at a time)
- No animation or combat feedback beyond text log

---

## Result

**Ownership signal confirmed at the workshop, before battle:**
"Instantly when I saw all the parts I could use and was already thinking what
would be the best combination."

The theorycrafting impulse triggered the moment the workshop loaded. This is
the core signal the prototype was testing for — the player was already building
in their head before clicking anything.

**Loot anticipation confirmed the retention hook:**
"When I defeated the enemy, the expectation of what would drop from it (the loot)."

The part-hunting loop closed successfully: battle → defeat → what did I earn?
The anticipation itself (not just the drops) was the engaging moment.

**The synergy system revealed an unmet expectation — and more depth potential:**

The player identified two design gaps in the prototype's simplified synergy
system that the production design must address:

1. **Multiple active synergies**: Equipping 2 fire + 2 electric parts should
   activate both Fire Sync AND Electric Sync simultaneously — not just one.
   The prototype's first-match-wins behavior felt wrong immediately.

2. **Synergy scaling**: 4 fire parts should give a greater bonus than 2. The
   current flat threshold (2+ = same bonus) felt unsatisfying. Players expect
   investment to scale with reward.

3. **Cross-element potential** (unprompted design suggestion from player):
   "Electric + fire could create another synergy" — the player spontaneously
   proposed a third tier of synergy beyond single-element stacking. This
   emerged organically during play, not from prompting.

These are not prototype bugs. They are design signals: the synergy system
needs more depth than originally assumed, and players are already thinking
about it at prototype stage.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | N/A (HTML, single build) |
| Prototype duration | < 1 session |
| Playtesters | 1 internal (Luan, developer) |
| Feel assessment | Workshop: theorycrafting impulse immediate. Battle: readable, turn-based logic clear. Drops: loot anticipation present. |
| Hypothesis verdict | CONFIRMED |

---

## Recommendation: PROCEED

The core hypothesis was fully confirmed. The player felt ownership at the
workshop (before battle), engaged with the tactical decision in combat
(targeting specific parts), and felt loot anticipation at the drops screen.
The verdict from the developer: "it is fun, it is addicting, it has potential
to be an awesome game."

The two friction points (synergy multiple-active, synergy scaling) are not
problems with the concept — they are evidence that the player wants MORE depth
from the system than the prototype provided. That is the best possible signal
at this stage.

CD-PLAYTEST skipped — Lean review mode.

---

## If Proceeding

**What the prototype revealed for GDD writing:**

**Confirmed assumptions:**
- Assembly creates immediate theorycrafting and ownership — the workshop IS the game, not just prep
- Part-break targeting adds strategic depth to combat without making it feel complex
- Loot anticipation ("what will drop?") is a strong retention hook between battles
- Type effectiveness (fire beats physical) is understood intuitively, no tutorial needed

**Design gaps the GDDs must address (emerged from prototype):**

1. **Synergy system needs multiple simultaneous activation**
   The production synergy system must allow multiple element synergies to be
   active at once. A 5-part build with 2 fire + 2 electric parts should get
   both Fire Sync and Electric Sync bonuses. Single-synergy-only is a ceiling
   the player hit immediately.

2. **Synergy must scale with investment**
   2 fire parts = base bonus (e.g., +15% fire damage)
   4 fire parts = enhanced bonus (e.g., +30% fire damage + additional effect)
   This creates meaningful choices between focused mono-element builds and
   hybrid multi-element builds. Both should be viable at different power curves.

3. **Cross-element synergies are worth designing**
   The player unprompted suggested that fire + electric together should create
   a unique combined effect. This is the PoE-style "set combination" the game
   aspires to. Worth designing at least one cross-element synergy in the first
   full design sprint to validate the mechanic.

4. **Break targeting felt natural but impact unclear**
   Players used the targeting system but the break probability math wasn't
   visible. In production, show the break chance explicitly ("35% per hit")
   so the decision to target vs. attack freely has legible tradeoffs.

**Tuning values to carry into GDDs:**
- Break threshold of 3 hits felt appropriate (not too fast, not tedious)
- -10% damage penalty for targeting felt fair (players didn't avoid targeting to preserve damage)
- Base drop count of 2 felt sufficient to feel rewarded; 3+ may trivialize the hunt

**Emergent mechanics worth formalizing:**
- The "what do I target to get the part I want?" pre-battle decision. In the prototype
  the player chose their target before battle. In production, consider whether the
  player can *see* the enemy's parts before engaging (scout mechanic?) or must learn
  which enemies drop what through experience.
- The loot anticipation at the drop screen. Consider a brief "reveal" animation
  for drops — even a simple stagger between items appearing — to amplify this moment.

**Note on feel:** The HTML prototype cannot validate combat feel (input response,
animation timing, audio feedback). The strategic logic is confirmed; the sensory
experience of a Symbot attacking is untested. When the first playable Godot build
exists, verify that the turn-based combat feels punchy rather than sterile.

**Next steps:**
1. `/design-review design/gdd/game-concept.md` — update concept doc with synergy insights
2. `/gate-check` — confirm readiness to advance to Systems Design
3. `/map-systems` — decompose the concept into all game systems
4. `/design-system combat` — GDD for turn-based combat; use synergy insights above
5. `/design-system workshop` — GDD for the assembly system
6. `/design-system parts` — GDD for the part database and synergy rules

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  The synergy system was underdesigned in the concept doc. The brainstorm described
  "set bonuses" loosely without specifying whether multiple sets could activate, or
  how they scaled. Prototype made this gap concrete immediately. The GDD for synergy
  needs to answer both questions explicitly before any code is written.

- **What surprised us that didn't show up in the brainstorm?**
  The player proposed cross-element synergies (fire + electric = new effect)
  unprompted. This was in the spirit of the design but not explicitly planned.
  It suggests the synergy design space is richer than initially scoped — and that
  players will naturally explore it as a theorycrafting dimension.

- **What would we test differently next time?**
  Add a second enemy type with different breakable parts and a different elemental
  type. One enemy is enough to confirm the loop exists; two enemies would confirm
  the loop generalizes. A follow-up prototype (if needed) should also include
  a second Symbot slot to test whether team synergy (cross-Symbot interactions)
  is as compelling as individual-build synergy.

---

> *Prototype code location: `prototypes/symbot-build-loop-concept/`*
> *This code is throwaway. Never refactor into production.*
