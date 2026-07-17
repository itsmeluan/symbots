# Vertical Slice — Build Plan

> **VERTICAL SLICE — NOT FOR PRODUCTION**
> **Date:** 2026-07-17
> **Concept:** Symbots — modular-robot creature collector, turn-based combat
> **Core fantasy (game-concept.md):** "mastery through modularity" — you are a
> Symbot Mechanic; every battle has a harvest goal.

## Validation Question

*"Does a player, starting from a stock Symbot, break a specific enemy component,
harvest the part they targeted, re-equip it, and feel their build get stronger —
within ~3 minutes, unguided? And can we build one such loop at representative
quality on top of the existing core?"*

Both halves matter: **player experience** (targeted harvest feels good) AND **build
feasibility** (the finished core drives a real UI loop without rework).

## Systems in scope

| System | GDD / source | Role in the slice |
|---|---|---|
| Stat pipeline + assembly | `src/core/stats/` (SymbotBuild) | Assemble the stock Symbot; recompute on re-equip |
| Turn-based combat | `src/core/battle/` (BattleController) | Drive one WILD encounter to victory |
| Part-Break → break events | `hit_resolved` seam (subscriber **unbuilt**) | **Slice builds this** — tally region damage → fire `arm_broken` |
| Drop system | `src/core/drop_system/` (DropSystem) | Resolve the targeted harvest from the enemy loot pool |
| Content | `assets/data/**` (16 parts, 10 enemies) | Real `.tres` — no throwaway fixtures |

**Cut from scope:** team-swap (multi-Symbot), synergy tiers, consumables, save/load,
audio, animation. One Symbot vs one enemy is the minimum complete loop.

## The one complete cycle

**[start]** stock Scrapjaw Symbot (all-common build) →
**[challenge]** fight the Rustcrawler; choose to attack its **arm** until it breaks →
**[resolution]** `arm_broken` → drop resolves the RARE `reinforced_servo_arm` →
re-equip over the common `servo_arm` → stats visibly rise.

## Phased build

| Phase | Deliverable | Success criterion |
|---|---|---|
| **4a** | `slice_bootstrap.gd` — headless harness | Loop runs end-to-end; arm breaks; rare drops; re-equip delta prints. **No UI risk.** |
| 4b | Battle screen (`Control`) — move buttons, structure/heat/energy bars, component target picker | A human drives combat by touch and can read state |
| 4c | Drop reveal panel | The harvest lands: "Arm shattered → Reinforced Servo Arm acquired" |
| 4d | Workshop screen — equip drop, live stat delta | Player **feels** the build change |
| 4e | 1 playtest + `REPORT.md` | PROCEED / PIVOT / KILL verdict + velocity log |

## Quality standards (slice-tier)

- Reuse the real `src/core/` — representative, not throwaway.
- No hardcoded gameplay values: all stats/rates come from the loaded `.tres` +
  `BalanceConfig`. The harness only synthesizes a `basic_attack` `MoveDef` (moves
  are not authored as content yet — a genuine finding, mirrored on the enemy side
  by the controller's own `_default_enemy_move`).
- Touch-first UI when we reach 4b (≥44×44 targets, per ADR-0008 / accessibility Basic).

## Known gaps this slice surfaces (not blockers — findings)

1. **Moves aren't authored as content.** No move catalog; parts carry no
   `active_skill_id`. The battle runs on synthesized basic attacks. Real move
   content is a Production epic.
2. **Part-Break subscriber doesn't exist.** The `hit_resolved` → region-HP →
   `note_break_event` bridge is presentation-tier and unbuilt. The slice prototypes
   it; Production promotes it to a real system.
3. **Rare-arm level gating.** If `reinforced_servo_arm` carries a `level_req` above
   the stock core level, the harvest is gated by CoreProgression — the harness
   reports this explicitly rather than hiding it.
4. **The stock start beat no authored enemy — the roster assumes progression a fresh
   build lacks.** First run: the all-common stock build (42 structure, basic-attack
   ×1.0, no weapon skill) **lost every fight**. Instrumented cause: ~13 dmg/hit → ~7
   hits to kill, while dying in 3 — a race it loses even ignoring the break. The whole
   enemy roster is tuned for developed builds (CORE leveling → structure; authored
   weapon skills → damage), neither of which a stock start has. **Resolution (user
   decision — retune real content):** the flavored "first contact" enemy Rustcrawler is
   now a true tutorial fight beatable by a stock build — structure 85→52, physical_power
   24→12, mobility 22→11 (`break_hp` recomputed 29/18→18/11 to satisfy the enemy
   validator). Real-`BattleController` sim: harvest path wins with ~40% structure left,
   efficient path ~64% — a legible risk/reward the first fight teaches. **Two deeper
   content gaps stay OPEN for Production:** (a) no authored *starter loadout* (harness
   picks first-common-per-slot arbitrarily); (b) no authored *weapon moves* (Finding 1)
   — parts carry no `active_skill_id`.

## Hard limit

1–3 weeks total. Day-3 sunk-cost rule: if the full cycle isn't demonstrable, stop
and surface the blocker. Velocity is logged in `REPORT.md`.

## Velocity Log

- **2026-07-17 (day 1):** Phase 4a headless harness **COMPLETE**. Loop proven
  end-to-end against real content: stock all-common Scrapjaw build → break Rustcrawler
  arm → harvest RARE `reinforced_servo_arm` (fight 6, seeded RNG) → re-equip →
  **physical_power +11** (24→35), structure +3, mobility +1. 913/913 GUT green after
  the content change. Balance finding surfaced + resolved (Finding 4).
