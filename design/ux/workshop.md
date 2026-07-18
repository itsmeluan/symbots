# UX Spec: Workshop

> **Status**: Ready for Review
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
2. **The 8 build slots** — what is equipped in each and which is currently selected.
   (8 logical slots total: HEAD / ARMS / LEGS / WEAPON / CHASSIS are the player-swappable
   exterior; CHIPSET + ENERGY_CELL read as internal indicators; CORE is a Workshop-only
   slot with its level badge — render-invisible *in play* but present here per the memory
   decision.)
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

**Orientation: landscape** (anchored to the approved reference mock, 2026-07-18). This
suits both the iOS-primary target (landscape is comfortable for a two-handed "bench"
session) and the Mac dev/launch platform. A three-column composition:

| Zone | Position | Width (approx) | Contents |
|------|----------|----------------|----------|
| **Z1 — Top Bar** | Full width, top | 100% × ~8% | `WORKSHOP` title + wrench glyph (left); **Scrap** counter (center-right, MVP-only — see note); pause/menu hamburger (right) |
| **Z2 — Slot Rail** | Left column | ~22% | Vertical list of the 8 build slots (icon + label); selected slot highlighted; `BUILD SUMMARY ›` pinned at the bottom |
| **Z3 — Stage** | Center column | ~44% | Symbot composite on a slowly-rotating turntable in the workshop diorama (§2.6); `‹ ›` manual-rotate controls; **Core level badge + XP bar** pinned bottom-center; **Part Picker filmstrip** docks here (bottom of Stage) when a slot is selected |
| **Z4 — Detail Panel** | Right column | ~34% | Context-sensitive: candidate-part card + **Stat Comparison** + **Synergy** + `PREVIEW`/`EQUIP` when a candidate is selected; equipped-part card + `UPGRADE` when the equipped part is inspected; **Build Status** banner pinned at the bottom |

> **Currency note (MVP reconciliation):** the reference mock shows three currency
> counters. MVP ships **Scrap only** (the gear counter). The gem and cube counters map
> to post-MVP systems (the cube's `+` reads as **Designs/blueprint fabrication**, an
> Alpha feature). Z1 reserves horizontal space for them but renders only Scrap in MVP.

> **Part Picker placement:** tapping a slot in Z2 docks a horizontal **candidate
> filmstrip** at the bottom of Z3 (thumb-reachable; does not occlude the bot or Z4).
> Selecting a candidate populates Z4. This keeps the bot and the comparison visible at
> the same time as the choice — the core "see the consequence before commit" read.

### Synergy Indicator Ordering (resolves Synergy DCO-2)

The synergy panel order is a UX priority rule — it is **not** inherited from the
`active_synergies` emission order (that order is alphabetical-by-tier-ID for system
determinism, Synergy Rule 3, and is not a UX priority). Indicators sort by:

1. **Group by state**: `active` → `progressing` (1+ toward a reachable threshold) →
   `inactive`. Active tiers always read first; a tier the player is one part away from
   reads before a cold one — protects Beat 1 ("what am I building toward").
2. **Within a group**: descending **current tag count** (closest-to-threshold first).
3. **Constituent-before-combined**: a combined tier (e.g., Ironclad-VOLT) is listed
   *after* both its constituent single-tag tiers, and its dual-track readout
   (`Ironclad 3/3 ✓ · VOLT 1/3`, Synergy §396) must never visually imply the constituents
   are deactivated or replaced — all three are simultaneously active (Synergy Rule 3 /
   DCO-2 constraint).

**Overflow (resolves DCO-1):** when build-relevant tiers exceed the 3–8 display cap, the
lowest-priority tiers by this rule collapse into a `+N more ›` affordance that opens
`BUILD SUMMARY` (which lists every active tier incl. overflow). Silent-drop is forbidden
(Synergy DCO-1) — the `+N more` count keeps the hidden tiers legible. *(Verified by
AC-WS-10.)*

### Component Inventory

**Z1 — Top Bar**
| Component | Type | Content | Interactive | Pattern |
|-----------|------|---------|-------------|---------|
| Screen title | Label + glyph | "WORKSHOP" + wrench | No | — |
| Scrap counter | Stat display | Current Scrap balance (gear glyph) | No (tap → tooltip) | PC-02 (long-press explains) |
| Menu button | Button | Opens pause/settings overlay | Yes | PC-01 → `pause.md` |

**Z2 — Slot Rail**
| Component | Type | Content | Interactive | Pattern |
|-----------|------|---------|-------------|---------|
| Slot entry ×8 | Toggle/list item | Slot icon + label (CORE, CHASSIS, CHIPSET, ENERGY CELL, HEAD, ARMS, LEGS, WEAPON); shows equipped part's rarity glyph/glow | Yes — selects the slot | PC-01; selected = highlighted state |
| Build Summary | Button | Opens full readout (all 11 stats, every active synergy incl. overflow per DCO-1, all passive/active effect names by `display_name`) | Yes | PC-01 → sub-panel |

**Z3 — Stage**
| Component | Type | Content | Interactive | Pattern |
|-----------|------|---------|-------------|---------|
| Symbot composite | Rendered sprite stack | 8-layer live composite (assembly Visual/Audio table); rarity overlays per equipped part; swaps in-frame on equip/preview | Yes (rotate) | new pattern — "Turntable" |
| Rotate controls | Button ×2 | `‹` `›` manual rotate; idle = slow auto-rotate | Yes | PC-01 |
| Core badge + XP bar | Data display | `CORE LV n` + XP progress `cur / next` (core-progression reads) | Tap → core detail | PG-01-like bar |
| Part Picker filmstrip | Horizontal list | Inventory filtered to selected slot, sorted by build-relevance (slot/rarity/family, inventory UI-Req-3/4); under-level parts greyed + "Core level N required" | Yes — tap = set candidate; long-press = inspect | PC-02 + new "Filmstrip" |

**Z4 — Detail Panel**
| Component | Type | Content | Interactive | Pattern |
|-----------|------|---------|-------------|---------|
| Part card | Card | Candidate/equipped part: thumbnail, name, rarity + element + manufacturer badges (each with non-color glyph, accessibility §1.3) | Tap → full detail popover | PC-02 |
| Stat Comparison | Data table | Headline POWER/ARMOR/MOBILITY: `current → delta` with **up/down arrow glyph** (§2.6 non-color cue); `(i)` expands to full 11 stats | Yes (`i` expand) | new "Stat Delta Row" |
| Synergy block | Indicator list | Build-relevant tiers (3–8): active / progressing / inactive states + combined dual-track (Synergy UI-Req-1); pips + "N more to activate"; preview shows would-activate/would-lose distinctly (non-color, UI-Req-3) | Yes — tap tier = effect detail (DCO-4) | new "Synergy Indicator" |
| PREVIEW button | Button | Try the candidate *on the bot* (composite sprite swap + synergy preview), no commit (DCO-3 explicit touch gesture) | Yes | PC-01 |
| EQUIP button | Button | Commit the equip (`part_equipped`); displaced part → inventory (AC-SA-04) | Yes | PC-01 |
| UPGRADE button | Button | (Equipped-part mode) next-tier stat gain + **Scrap cost**; disabled if unaffordable or at tier cap (Common +3) | Yes | PG-05 affordable/disabled |
| Build Status banner | Status banner | Combat-legality (EC-CP-05): ✓ "All systems go" (legal) OR ⚠ list of over-level parts blocking combat (non-color icon + text) | Tap → detail when invalid | new "Build Status" |

### ASCII Wireframe

```
┌──────────────────────────────────────────────────────────────────────┐
│ 🔧 WORKSHOP                       ⚙ 12,450 Scrap              [☰]      │  Z1
├───────────────┬────────────────────────────────┬─────────────────────┤
│ ▣ CORE        │                                │ ┌────┐ SERVO ARM     │
│ ▤ CHASSIS     │          ╱▛▜╲                   │ │ ▟▙ │ [RARE][VOLT]  │  Z4
│ ▦ CHIPSET     │         ▐ ●● ▌   (turntable)    │ └────┘ [IRONCLAD]    │
│ ▬ ENERGY CELL │          ▜██▛                   │ STAT COMPARISON  (i) │
│ ◗ HEAD        │         ╱    ╲                  │ ⚔ POWER  156  ▲ +18  │
│▸▣ ARMS   ◂ sel│        ▐      ▌                 │ 🛡 ARMOR  102  ▲  +4  │
│ ▤ LEGS        │     ‹  ◯ stand ◯  ›             │ 👟 MOBIL  128  ▼  −3  │
│ ▭ WEAPON      │  ┌─ picker filmstrip ─────────┐ │ SYNERGY          (i) │
│               │  │[▟▙][▤][▦][▬]… (slot=ARMS)  │ │ 🛡 IRONCLAD 2/3 ◆◆⬡  │
│               │  └────────────────────────────┘ │    1 more to activate│
│ ▤ BUILD       │      ┌──────┐                    │ [   👁  PREVIEW    ] │
│    SUMMARY ›  │      │CORE L4│ XP ▓▓▓▓▓░ 1240/1800│ [   🔧  EQUIP      ] │
├───────────────┴──────┴──────┴───────────────────┼─────────────────────┤
│                                                  │ ✓ BUILD STATUS      │
│                                                  │   All systems go.   │
└──────────────────────────────────────────────────┴─────────────────────┘
```

*(Wireframe reconciled to MVP: single Scrap currency in Z1; PREVIEW = try-on-bot,
EQUIP = commit; UPGRADE replaces the EQUIP slot when an already-equipped part is
inspected; Build Status doubles as the EC-CP-05 legality banner.)*

---

## States & Variants

| State / Variant | Trigger | What changes |
|-----------------|---------|--------------|
| **Default (populated)** | Normal load with an assembled build | All zones populated; a slot pre-selected (last-used or CORE) |
| **First-run reduced** | Tutorial / before first boss | Picker limited to swap; `UPGRADE` hidden; Synergy block may be empty; `BUILD SUMMARY` minimal — matches the reduced first-run introduced in symbot-assembly |
| **Empty slot** | Selected slot has no part | Composite shows a gap in that layer; Z4 reads "Empty — tap to install"; `EQUIP` acts as "install" |
| **Candidate selected** | Tap a part in the filmstrip | Z4 shows candidate card + **hypothetical** stat delta (`compute_stat_delta()`, no commit); `PREVIEW`/`EQUIP` enabled |
| **Preview active** | `PREVIEW` tapped | Composite swaps to the candidate sprite; Synergy shows *would-activate* / *would-lose* distinctly (non-color, Synergy UI-Req-3); a "previewing — EQUIP or ✕" affordance appears; nothing committed |
| **Equipped-part inspected** | Tap an already-filled slot (no candidate pending) | Z4 shows the equipped card + **`UPGRADE`** (next-tier delta + Scrap cost) in place of `EQUIP` |
| **Upgrade unaffordable** | `Scrap < upgrade cost` | `UPGRADE` disabled (PG-05) with cost shown in deficit styling + reason text |
| **Upgrade at cap** | Part at its tier cap (Common +3, per Part-DB Rule 10) | `UPGRADE` replaced by a "Max tier" label |
| **Invalid build** | A core swap orphans over-level parts (EC-CP-05) | Build Status banner = ⚠ + lists offending parts; over-level parts greyed in the rail with "Core level N required"; "cannot enter combat while invalid" |
| **Under-level part in picker** | `part.level_req > core level` | Greyed filmstrip entry + "Core level N required"; not equippable |
| **Filmstrip empty (no candidates)** | Selected slot has zero eligible parts in inventory | Filmstrip shows an empty-state line — "No parts for this slot yet" — instead of an empty strip; the currently equipped part (if any) stays inspectable in Z4 so `UPGRADE` remains reachable. Distinct from *Empty slot* (which is about the slot being unfilled, not the picker being empty). |
| **Loading / save-on-enter** | Screen entry (Workshop is the save point) | Brief; no spinner unless the save write is async — if async, a quiet inline "Saving…" not a blocking modal |
| **Save failed (on enter/exit)** | Autosave write returns error (ADR-0001 atomic-write failure) | A **non-blocking** inline notice — "Couldn't save — your last change may not be kept" — with a `Retry` action; the player is **not** told the change persisted. Exit is not forced; the unsaved state is never silently swallowed. On repeated failure, fall through to the ADR-0001 `save_emergency()` path. No modal that traps the player in the calm hub (art-bible §2.6 — no urgency cue). *(Verified by AC-WS-11.)* |
| **Rarity overlay** | Per equipped part rarity | Common = none · Rare = element glow · Boss = radiant · Prototype = flicker — all bounded to <3 flashes/sec (accessibility §1.4) |

---

## Interaction Map

Input methods (from `technical-preferences.md`): **Touch primary** (iOS), **Mouse/Keyboard**
(Mac). **No gamepad.** No hover-only affordances — every hover enhancement has a touch/tap
equivalent (ADR-0008 unified press-release path; ≥44×44pt, ≥56px preferred targets).

| Component | Touch | Mouse | Keyboard | Immediate feedback | Outcome |
|-----------|-------|-------|----------|--------------------|---------|
| Slot entry (rail) | tap | click | focus + Enter | slot highlights | Selects slot; docks the picker filmstrip |
| Filmstrip part | tap = set candidate · long-press = inspect | click · right-click | Enter · hold | card slides into Z4 | Sets candidate (PC-02 popover on inspect) |
| Rotate `‹ ›` | tap | click | ← / → | bot rotates | Manual rotate; idle resumes slow auto-rotate |
| `PREVIEW` | tap | click | Enter | composite swaps + seam highlight | Try-on-bot + synergy preview (no commit) |
| `EQUIP` | tap | click | Enter | settle + confirm check | Commits `part_equipped`; displaced part → inventory |
| `UPGRADE` | tap | click | Enter | Scrap counter ticks down | Spends Scrap; raises the part's tier |
| Synergy tier row | tap | click | Enter | detail popover | Shows the tier's effect detail (DCO-4) |
| `(i)` expanders | tap | click | Enter | panel expands | Reveals full 11 stats / full synergy list |
| `BUILD SUMMARY ›` | tap | click | Enter | panel opens | Full readout (all stats + synergies incl. overflow) |
| Scrap counter | long-press | hover → tooltip | focus | tooltip | Explains the Scrap currency |
| `☰` menu | tap | click | Esc | overlay slides | Opens pause/settings overlay |
| Back / exit | system back | — | Esc (from overlay) | fade | Returns to Overworld (autosave) |

**Keyboard focus order:** slot rail (top → bottom) → picker filmstrip (when open) → Z4
actions (`PREVIEW`/`EQUIP` or `UPGRADE`) → Z4 detail expanders → top bar (`☰`).

---

## Events Fired

| Player Action | Event Fired | Payload / Notes |
|---------------|-------------|-----------------|
| Select slot | *(UI-local)* — optional `workshop_slot_selected` analytics | No game-state write |
| Set candidate | *(UI-local)* | Hypothetical `compute_stat_delta()`; reads the pure core, no write |
| `PREVIEW` | *(UI-local)* | Hypothetical derive (SynergyEvaluator.preview + StatPipeline hypothetical, ADR-0008); no write |
| **`EQUIP`** | **`part_equipped`** | ⚠ **Persistent build write** → deferred autosave quiesce (ADR-0001/0002). Architecture attention. |
| **`UPGRADE`** | **`part_upgraded`** + Scrap debit | ⚠ **Persistent economy write** (Scrap balance + part tier). Architecture attention. |
| Rotate / expand / open summary | *(none)* | Pure presentation |
| Exit to Overworld | Autosave (Workshop is the save point) | Deferred-autosave quiesce on screen teardown (ADR-0002); **on write failure, surface the Save-failed notice + Retry (ADR-0001), do not report success** |

> Two actions modify persistent state — `EQUIP` (build) and `UPGRADE` (economy + tier).
> Both are flagged for the architecture team; the UI **owns neither** — it calls into the
> systems that own build state and the Scrap economy (Data Requirements below).

---

## Transitions & Animations

Everything here sits under **art-bible §2.6** — the Workshop is the lowest-energy, no-clock
space: *"Visual noise, ambient animation, and urgency-implying dynamic lighting are excluded
here"* and *"Background darker than subject but controlled and stable — no flicker, no
atmospheric motion."*

- **Enter:** unhurried slide/fade-in; the bot settles onto the neutral stand; slow
  auto-rotate begins. No urgency cue, no clock.
- **Exit:** gentle fade to the Overworld.
- **Preview slide-in:** the candidate part slides onto the composite (§2.6 "unhurried
  preview slide-in"); a seam edge-highlight pulses **once** on the swapped part, then holds.
- **Equip confirm:** brief settle + a checkmark on the Build Status banner — an
  audio-independent visual confirm (accessibility §4.1).
- **Synergy activation** (during preview or on equip): Beat 3 "The Click" — visual + audio
  confirmation, bounded to **<3 flashes/sec** (accessibility §1.4).
- **Delta arrows:** static up/down glyphs — no flashing.
- **Reduced-motion alternative:** auto-rotate pauses to a static 3/4 pose; the preview
  slide-in becomes an instant swap; the seam highlight renders static (no pulse); the
  synergy "Click" keeps its audio + a single static state change, no flash.

---

## Data Requirements

The Workshop **owns none of this data** — it reads from and writes through the systems that
own each element (ADR-0008: the UI subscribes and calls, it does not hold game state).

| Data | Source System | R / W | Notes |
|------|---------------|-------|-------|
| Current build (8 slots + equipped parts) | Assembly (symbot-assembly) | R | Feeds the live composite |
| Part definitions (stats, rarity, element, manufacturer, `level_req`, effects) | Part Database (`part_catalog.tres`) | R | Static content |
| Effective stats (11) | Stat Pipeline (`src/core/stats/`, ADR-0005) | R | SYN-F4 composition point |
| Hypothetical stat delta | Stat Pipeline hypothetical derive | R | `compute_stat_delta()` — read-only, no write |
| Synergy tiers + states | SynergyEvaluator.preview (ADR-0008) | R | active / progressing / inactive |
| Core level + XP | Core Progression | R | Badge + bar |
| Build legality | Core Progression / build validator (EC-CP-05) | R | Over-level orphan check |
| Scrap balance | Economy / Inventory | R | Z1 counter; updates on `UPGRADE` |
| Inventory parts for the selected slot | Inventory | R | Filmstrip source, sorted build-relevance |
| Equip a part | Assembly | **W** | Fires `part_equipped` |
| Upgrade a part | Part upgrade / economy | **W** | Debits Scrap + bumps tier |
| Save on enter/exit | Save/Load (ADR-0001) | **W** | Workshop is the save point |

No data element lists "UI" as owner. The two write paths (`EQUIP`, `UPGRADE`) call into the
owning systems and are surfaced for architecture attention in **Events Fired**.

---

## Accessibility

Target tier: **GAG Basic + selected WCAG 2.1 AA** (per `design/accessibility-requirements.md`).

- **Contrast & size:** text ≥ 4.5:1; all interactive targets ≥ 44×44pt (≥ 56px preferred).
- **Color never alone:** rarity = glyph + label · element = glyph · stat delta = up/down
  **arrow glyph** · synergy state = pip shape + text ("N more to activate") · build status =
  icon + text. *(Verified by AC-WS-06.)*
- **Keyboard-only:** documented focus order (slot rail → filmstrip → Z4 actions → expanders →
  top bar); every action reachable via focus + Enter. No gamepad (per tech-prefs).
  *(Verified by AC-WS-07.)*
- **Reduced-motion:** auto-rotate pauses to a static pose; preview slide-in → instant swap;
  seam highlight static; synergy "Click" keeps audio + one static state change, no flash.
  *(Verified by AC-WS-09.)*
- **Photosensitivity:** rarity flicker (Prototype) and the synergy "Click" bounded to
  < 3 flashes/sec (accessibility §1.4).
- **Screen reader:** announces slot selection, candidate name + delta summary, equip
  confirmation, and the build-invalid warning (with the offending part names).
- **Text scaling:** the large-text toggle (Settings) must reflow the layout — slot-rail
  labels tolerate a 2-line wrap; Z4 tables must not clip.

---

## Localization Considerations

- **Longest text elements:** slot label `ENERGY CELL`; `Core level N required`;
  `1 more part to activate`; buttons `PREVIEW` / `EQUIP` / `UPGRADE` / `BUILD SUMMARY`;
  banner `All systems go.`
- **Expansion:** reserve **+40%** for all UI strings; the slot rail tolerates a 2-line wrap;
  Z4 action buttons must not truncate their verbs.
- **Number formatting:** stat values and the Scrap balance are locale-formatted (thousands
  separator differs — `12,450` vs `12.450`).
- **Proper nouns:** manufacturer (Ironclad/Scrapjaw/Boltwell) and element (Volt/Thermal/
  Kinetic) names are proper nouns — whether they localize is **OQ3**.

---

## Acceptance Criteria

- **AC-WS-01** — Selecting a slot docks a filmstrip filtered to that slot type; parts with
  `level_req > core level` render greyed with "Core level N required" and cannot be set as a
  candidate.
- **AC-WS-02** — Setting a candidate displays a signed delta for POWER/ARMOR/MOBILITY with an
  up/down arrow glyph; `(i)` expands to all 11 stats; no build state is written
  (`compute_stat_delta()` is read-only).
- **AC-WS-03** — `PREVIEW` swaps the composite sprite to the candidate and shows
  would-activate / would-lose synergy states without committing; `✕` restores the equipped
  sprite; `EQUIP` commits, fires `part_equipped`, and moves the displaced part to inventory.
- **AC-WS-04** — With an equipped part selected and Scrap ≥ cost, `UPGRADE` raises the tier
  and debits Scrap; with Scrap < cost `UPGRADE` is disabled and states the deficit; at the
  tier cap it shows "Max tier".
- **AC-WS-05** — After a core swap that orphans an over-level part, Build Status shows ⚠
  listing each offending part, those parts grey in the rail, and combat entry is blocked
  until resolved (EC-CP-05).
- **AC-WS-06** — Every color-coded element (rarity, element, delta sign, synergy state, build
  status) remains distinguishable with color disabled — glyph or label present.
- **AC-WS-07** — All interactive targets are ≥ 44×44pt; a keyboard-only user can select a
  slot, set/preview/equip a part, and upgrade using focus + Enter in the documented focus
  order.
- **AC-WS-08** — The screen opens within ≤ [perf budget, OQ1] ms; equipping a part updates
  the composite within one frame budget (16.6ms target) with no visible stall.
- **AC-WS-09** — With reduced-motion enabled, no animation exceeds a static state change;
  auto-rotate is paused; nothing flashes > 3/sec.
- **AC-WS-10** — Synergy indicators render in state-priority order (active → progressing →
  inactive; within a group, descending tag count; combined listed after its constituents),
  never in `active_synergies` emission order. When build-relevant tiers exceed the display
  cap, a `+N more ›` affordance shows the exact hidden count and opens BUILD SUMMARY; no
  relevant tier is silently dropped. *(Synergy DCO-1 / DCO-2)*
- **AC-WS-11** — When an autosave write fails, the screen shows a non-blocking "couldn't
  save" notice with `Retry`, never a success confirmation, and does not force exit; repeated
  failure invokes `save_emergency()`. *(ADR-0001)*

---

## Open Questions

- **OQ1** — Exact screen-open performance budget (ms). Needs architecture/perf confirmation
  (feeds AC-WS-08).
- **OQ2** — The three "headline" stats (POWER/ARMOR/MOBILITY) → the real 11-stat vocabulary:
  are these aggregate labels or literal stats? Confirm against the Stat Pipeline / GDD.
- **OQ3** — Do manufacturer/element proper nouns localize, or stay canonical across locales?
- **OQ4** — No player-journey map at `design/player-journey.md` — context-on-arrival
  assumptions are unvalidated. Template at `.claude/docs/templates/player-journey.md`.
- **OQ5** — Upgrade UI granularity: per-stat gains or a summary line? Confirm against Part-DB
  Rule 10 upgrade curve (10/20/40/80/160).
- **OQ6** — Filmstrip scaling: how does it behave when a slot has many candidates? May need a
  "see all" handoff to `inventory.md` (grid view).
- **OQ7** — Is `BUILD SUMMARY` an in-Workshop panel or a handoff to `inventory.md`? Defines
  the boundary with the (not-yet-written) Inventory screen spec.
