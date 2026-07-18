# UX Spec: Workshop

> **Status**: In Design
> **Author**: Luan + ux-designer
> **Last Updated**: 2026-07-18
> **Journey Phase(s)**: Home base / between-encounters (no player-journey map yet — see Open Questions)
> **Template**: UX Spec

---

## Purpose & Player Need

The Workshop is where the player turns collected parts into a **build** — the game's
central act of expression and the space where "the workshop wins the fight" is made
literal. The player arrives wanting to **assemble, swap, and upgrade the parts on their
Symbot, and understand the consequences of a change *before* committing it.**

Concretely, the player comes here to:

1. **See their Symbot** as the layered composite it currently is (8-slot render, §2.6).
2. **Swap a part** into a slot and **preview** the exact stat delta (SA-F2) and any
   **synergy threshold change** (Synergy DCO-3/UI-Req-3) before equipping.
3. **Upgrade a part** with Scrap — the MVP economy sink (Part-DB Rule 10 curve).
4. **Read what the build is doing**: effective stats (post-synergy SYN-F4), active
   synergy tiers and what each is *building toward*, the core's level and XP, and
   whether the build is **combat-legal** (no over-level parts, EC-CP-05).

What goes wrong without this screen doing its job: the player swaps parts blind, can't
tell why a build got stronger or weaker, misses the synergy they were one part away
from ("The Click", Synergy Beat 3), or walks into a fight with an illegal build. The
Workshop's job is to make every consequence **legible before commit**.

> **Emotional register (art-bible §2.6):** this is the *lowest-energy, no-clock* space
> in the game. Nothing here should feel rushed or judged. The pleasure is a mechanic
> with the machine in front of them, every option visible.

---

## Player Context on Arrival

- **When first encountered**: early — game-concept onboarding gives a starter Symbot and
  "shows how to swap one part before their first battle." The **full** Workshop opens
  after the first boss (game-concept §Onboarding). So the screen has a **reduced first-run
  state** (swap only) and a **full state** (swap + upgrade + full synergy panel).
- **What they were just doing**: most often finishing an encounter arc — "enter zone →
  break the Crawler's arm → get the Servo Arm → return to workshop" (game-concept core
  loop). They arrive with **new parts in inventory** and a build question in mind.
- **Emotional state to design for**: curious, unhurried, a little acquisitive — *"three
  new parts landed in the box → what can I build?"* (inventory Player Fantasy). Never
  time-pressured.
- **Voluntary or sent**: **voluntary.** The player chooses to open the Workshop from the
  Oficina bench. It is also the game's **save point** ("the session ends with a clear
  save point at the workshop," game-concept), so it doubles as the natural stop/resume
  anchor.

---

## Navigation Position

This screen lives at: **Overworld → Oficina (workshop bench) → Workshop**.

Alternate arrival: **Main Menu → `Continue`** loads the save and resumes *at the workshop
save point* (`main-menu.md` — "Resumes at the workshop save point"). So on a returning
session the Workshop is effectively the first interactive screen the player sees.

It is a **context-dependent destination** reached from the overworld bench, not a
top-level always-on menu item. Combat is **not** entered from here — the player exits to
the Overworld and triggers encounters there. The Workshop is the calm hub between runs.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Overworld — Oficina bench | Tap the bench interactable | Current `SymbotBuild`, full Inventory, Scrap balance, core level/XP |
| Main Menu — `Continue` | Save loads at the workshop save point | Restored build + inventory + Scrap from save |
| First-run tutorial | Scripted "swap one part" beat before first battle | Starter Symbot, one candidate part, reduced (swap-only) state |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Overworld | `Back` / close | Returns to the bench location. Build changes persist (autosave on exit — ADR-0001 lifecycle). **Blocked while build is combat-illegal only if leaving *into* an encounter**; leaving to the calm overworld is always allowed, but the invalid-build banner persists as a reminder |
| Inventory (full) | Tap `Inventory` / manage-parts affordance | Full part list + batch-scrap live in `inventory.md`'s own screen; Workshop opens it as a sub-screen for scrap/organize, then returns |
| Pause / Settings | Pause affordance | `pause.md` overlay (settings, save, quit-to-menu) |

> **One-way note**: no Workshop exit is irreversible except entering a battle *later*
> from the overworld with the current build. Upgrading a part spends Scrap
> (irreversible), but that is an in-screen commit with its own confirm, not an exit.

---

## Layout Specification

### Information Hierarchy

Ranked by what the player must perceive first (drives all zone decisions):

1. **The Symbot composite** — the bot on its stand, the subject and the expression
   (art-bible §2.6 mood-carrying element). Always visible.
2. **The 6 build slots** — what is equipped in each and which is currently selected.
   (8 logical slots; CHIPSET + ENERGY_CELL read as internal indicators, CORE shown as a
   Workshop-only slot with its level badge — CORE is render-invisible *in play* but
   present here per the memory decision.)
3. **Effective stats** (post-synergy SYN-F4) and, during a preview, the **signed stat
   delta** with up/down arrow glyphs (§2.6 non-color cue).
4. **Synergy indicators** — active tiers + progress toward the next threshold; the
   "what am I building toward" read (Synergy Beat 1). Build-relevant tiers only, 3–8
   visible (Synergy UI-Req-1, DCO-1 overflow).
5. **Core level + XP bar** on the core slot; **combat-legality banner** when the build is
   invalid (over-level parts orphaned by a core swap, EC-CP-05).
6. **On demand (discoverable, not always on screen)**: the part-picker (inventory
   filtered to the selected slot), the upgrade panel (Scrap sink), and per-part / per-tier
   detail popovers (long-press, PC-02).

### Layout Zones

[To be designed]

### Component Inventory

[To be designed]

### ASCII Wireframe

[To be designed]

---

## States & Variants

[To be designed]

---

## Interaction Map

[To be designed]

---

## Events Fired

[To be designed]

---

## Transitions & Animations

[To be designed]

---

## Data Requirements

[To be designed]

---

## Accessibility

[To be designed]

---

## Localization Considerations

[To be designed]

---

## Acceptance Criteria

[To be designed]

---

## Open Questions

[To be designed]
