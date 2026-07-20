# UX Spec: Pause Menu

> **Status**: Approved — passed /ux-review 2026-07-17 (0 blocking, 3 advisory)
> **Author**: Luan + ux-designer
> **Last Updated**: 2026-07-17
> **Journey Phase(s)**: Mid-session interruption — reachable from any active gameplay context
> **Template**: UX Spec

---

## Purpose & Player Need

The Pause Menu is the player's **in-session escape hatch and navigation hub.** It is the
single overlay that lets a player step out of the moment — to change a setting, move between
the workshop and the world, or leave the session — without abandoning progress by accident.

Because Symbots is **turn-based, there is no time pressure to "pause"** in the twitch sense
(accessibility §2.3 — no timing requirements). Nothing advances while the player deliberates.
The Pause Menu therefore exists for **navigation and meta control**, not for buying reaction
time. The player arrives wanting to **do something outside the current activity** — reconfigure,
relocate, or exit — and then return exactly where they were (or leave cleanly).

> **What would go wrong without it:** the player would have no way to reach Settings mid-run,
> no way to travel from the world to the workshop, and — worst — no safe, deliberate path to
> quit that protects their save. Quit would either be impossible or would risk destroying
> progress. The Pause Menu is where leaving-the-session becomes a considered action.

> **System pause is a different thing.** When the OS backgrounds the app (iOS
> `NOTIFICATION_APPLICATION_PAUSED`), the engine fires `save_emergency()` (ADR-0001 item 8) —
> that is an automatic lifecycle safeguard, **not** this player-facing menu. This spec covers
> only the player-invoked overlay.

---

## Player Context on Arrival

| Context | Trigger | Emotional state | Design assumption |
|---|---|---|---|
| **Overworld — navigating** | Player taps `☰` (hud.md menu affordance) | Deliberate, planning ("time to go build") | The overlay doubles as the navigation hub: Workshop / Inventory / World Map are the primary destinations |
| **Overworld — leaving** | Player wants to stop playing | Winding down; wants to quit safely | `Quit to Title` is present and clearly safe — progress is already saved at the last quiesce point |
| **Battle — interrupting** | Player taps the in-battle menu affordance | Focused but interrupted (phone call, needs to change audio, wants out of a losing fight) | Minimal options — Resume is the obvious default; anything that leaves battle warns about losing the current fight |

Players arrive **voluntarily and always by their own action** — the game never forces the
Pause Menu open. The dominant case is the overworld player using it as a navigation hub, so
`Resume` must be effortless (large, default, and dismissable with a single tap or a back
gesture) and the destructive path (`Quit to Title`) must never be a mis-tap away from `Resume`.

Emotional register (art bible §2.7): **calm efficiency.** The overlay gets out of the way;
the world it covers is still faintly visible behind it (dimmed), reinforcing "you haven't left,
you've just stepped back."

---

## Navigation Position

This screen lives at: **{ Overworld | Battle } → Pause Menu (modal overlay) → back to the same context, or out**

- The Pause Menu is a **context-dependent overlay**, not a standalone scene. It is reachable
  only from active gameplay (Overworld or Battle), never from the Main Menu or from within
  another menu.
- It is reachable from **more than one place** — the Overworld `☰` and the in-battle menu
  affordance both open it, but they open **different variants** (hub vs. minimal).
- `Settings` opened from here is the **same Settings screen** reachable from the Main Menu
  (`settings.md`, not yet authored) — it must return to whichever context opened it (Pause
  Menu), not to the Main Menu.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Overworld | Tap `☰` (hud.md Must-Show menu affordance) | Current world position, active encounter-zone modifiers, Scrap total — all preserved behind the overlay |
| Battle | Tap in-battle menu affordance | Live `BattleContext` (ADR-0007) — the fight is mid-resolution and must survive Resume intact |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Same context (Resume) | `Resume` tap / back gesture / tap-outside-dim | Non-destructive; returns to the exact prior state (world position or battle turn) |
| Workshop | `Workshop` tap (**overworld variant only**) | Scene change; spec: `workshop.md` (not yet authored). Not offered mid-battle |
| Inventory | `Inventory` tap (**overworld variant only**) | Spec: `inventory.md` (not yet authored). Not offered mid-battle |
| World Map | `World Map` tap (**overworld variant only**) | Spec: `world-map.md` (not yet authored). Not offered mid-battle |
| Settings | `Settings` tap | Returns to the Pause Menu on back; no state change |
| Main Menu (Title) | `Quit to Title` (+ confirm) | Overworld: quiesce-point save already protects progress. Battle: **abandons the current fight** — confirm required |

> **One-way / irreversible exit:** `Quit to Title` **from battle** is the one destructive
> path — the in-progress fight is discarded (a battle is not a save quiesce point). Overworld
> `Quit to Title` is effectively safe (progress since the last quiesce point is bounded to
> ~one action, ADR-0001 item 9). Resume, Settings, and the overworld navigation exits are all
> reversible.

---

## Layout Specification

### Information Hierarchy

Ranked by what the player needs first:

1. **Resume** — the overwhelmingly most common action; largest, default, top of the list,
   and dismissable without even reading the menu (back gesture / tap the dimmed area).
2. **Primary navigation** *(overworld variant)* — Workshop / Inventory / World Map. The
   reason the hub exists; grouped and prominent.
3. **Settings** — present in both variants, visually lighter than navigation.
4. **Quit to Title** — deliberately **last and visually separated** from Resume so it is
   never adjacent to the safe default; carries a distinct (destructive-leaning) treatment.

> **Anti-pillar guard:** no completion counters, collection percentages, or progress ledgers
> on this overlay (game-concept anti-pillar). It shows actions, not a scorecard.

### Layout Zones

**Modal overlay over a dimmed, still-visible gameplay layer** (landscape). The world/battle
behind it is dimmed (not hidden) and non-interactive.

- **Scrim zone (full-bleed):** semi-opaque dim over the frozen gameplay. Tapping the scrim =
  Resume (with the same guard as an explicit Resume). Reinforces "you're still here."
- **Panel zone (centered or left-anchored column):** the action list. A single vertical stack
  of buttons; `Resume` at top, a visual divider before `Quit to Title` at the bottom.
- **Header (optional, minimal):** a quiet "Paused" label — text, no drama. Omit if the button
  stack alone reads clearly.

The overlay covers as little as it needs to. In the battle variant the panel is smaller (fewer
options) and must not obscure the battlefield read more than necessary.

### Component Inventory

All buttons use **PC-01 — Button (touch press-release)**; ≥44×44pt (≥56px preferred).

**Overworld (hub) variant**
- *Resume* — PC-01. Dismisses overlay → returns to Overworld.
- *Workshop* — PC-01. → Workshop screen (dependency).
- *Inventory* — PC-01. → Inventory screen (dependency).
- *World Map* — PC-01. → World Map screen (dependency).
- *Settings* — PC-01. → Settings screen (shared with Main Menu).
- *Quit to Title* — PC-01, destructive-leaning styling. → confirm → Main Menu.

**Battle (minimal) variant**
- *Resume* — PC-01. Dismisses overlay → returns to the exact battle turn.
- *Settings* — PC-01. → Settings screen.
- *Concede & Quit to Title* — PC-01, destructive styling. → confirm (warns the fight is lost)
  → Main Menu.

**Shared overlay**
- *Scrim / dim layer* — interactive only insofar as tapping it = Resume; otherwise blocks
  input to the gameplay behind it.
- *Quit-to-Title confirm modal* — the PC-01 standard confirm dialog. Battle variant copy is
  stronger (progress-loss warning). Safe default = Cancel.

No new interaction patterns are introduced — everything is PC-01 + the standard confirm dialog
already used by main-menu New Game and the scrap/disassemble flows (accessibility §2.4).

### ASCII Wireframe

Overworld (hub) variant:

```
┌──────────────────────────────────────────────────────────────┐
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ (world dimmed behind, still visible) ▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓┌──────────────────────────────┐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓│  Paused                       │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓│  ┌──────────────────────────┐ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓│  │   ▶  RESUME              │ │  ← default, top       │
│▓▓▓▓▓▓▓│  └──────────────────────────┘ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓│  │        Workshop           │ │  ← navigation hub     │
│▓▓▓▓▓▓▓│  │        Inventory          │ │                       │
│▓▓▓▓▓▓▓│  │        World Map          │ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓│  │        Settings           │ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓│  ────────────────────────────  │  ← divider            │
│▓▓▓▓▓▓▓│  │        Quit to Title      │ │  ← separated, last    │
│▓▓▓▓▓▓▓│  └──────────────────────────┘ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓└──────────────────────────────┘▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓ (tap dimmed area = Resume) ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└──────────────────────────────────────────────────────────────┘
```

Battle (minimal) variant:

```
┌──────────────────────────────────────────────────────────────┐
│▓▓▓ (battlefield dimmed, still readable behind) ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓▓▓▓┌────────────────────────┐▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓▓▓▓│  Paused                 │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓▓▓▓│  │  ▶  RESUME          │ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓▓▓▓│  │     Settings        │ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓▓▓▓│  ──────────────────────  │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓▓▓▓│  │  Concede & Quit     │ │  ← warns: fight is lost   │
│▓▓▓▓▓▓▓▓▓▓└────────────────────────┘▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└──────────────────────────────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Overworld (hub)** | Opened from Overworld `☰` | Full option set incl. Workshop / Inventory / World Map navigation |
| **Battle (minimal)** | Opened from in-battle menu affordance | Resume / Settings / Concede & Quit only — no navigation, build is snapshot-locked (ADR-0005) |
| **Quit-confirm open (overworld)** | `Quit to Title` tapped in overworld | Confirm modal; copy notes progress is saved to the last checkpoint; Cancel default |
| **Quit-confirm open (battle)** | `Concede & Quit` tapped in battle | Confirm modal; **stronger copy — "You will lose this battle"**; Cancel default |
| **Returning from Settings** | Back from Settings screen | Pause Menu re-shown over the same still-frozen context (not the Main Menu) |
| **Platform — iOS** | Running on iOS | Safe-area insets applied; no `Quit` to OS (only Quit to Title); overlay respects notch/home indicator |
| **Platform — Mac** | Running on Mac | Same overlay; mouse-clickable; `Esc` may toggle the overlay (advisory, post-MVP keyboard support) |

> **No loading state on open/close** — the overlay is a UI layer over live state, not a scene
> load. Loading only occurs on an *exit* that changes scene (Workshop / World Map / Quit to Title).

---

## Interaction Map

Mapping interactions for: **Touch (primary) + Mac mouse.** Gamepad: **None.** Keyboard
(incl. `Esc` to open/close) is **advisory / post-MVP** (accessibility §2.5). All actions
completable via touch/mouse.

| Component | Action | Input(s) | Immediate feedback | Outcome |
|---|---|---|---|---|
| Open pause (overworld) | Tap `☰` | Touch, mouse | Overlay fades in; world dims | Pause hub shown; world frozen |
| Open pause (battle) | Tap menu affordance | Touch, mouse | Overlay fades in; battlefield dims | Minimal pause shown; battle frozen |
| Resume | Tap / click / tap-scrim / back gesture | Touch, mouse | PC-01 press-release; overlay fades out | Return to exact prior state |
| Workshop / Inventory / World Map | Tap / click | Touch, mouse | PC-01 press-release | Scene change to the target (dependency specs) |
| Settings | Tap / click | Touch, mouse | PC-01 press-release | Navigate to Settings; returns to Pause Menu |
| Quit to Title (overworld) | Tap / click | Touch, mouse | PC-01 press-release; opens confirm | Confirm → Main Menu |
| Concede & Quit (battle) | Tap / click | Touch, mouse | PC-01 press-release; opens confirm (loss warning) | Confirm → abandon battle → Main Menu |
| Confirm "Quit" | Tap / click | Touch, mouse | PC-01, destructive styling | Save-quiesce (if applicable) → Main Menu |
| Cancel quit | Tap / click | Touch, mouse | PC-01; safe default | Close confirm → back to Pause Menu |

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Open pause | `game_paused` | context = overworld / battle |
| Resume | `game_resumed` | context |
| Workshop / Inventory / World Map nav | `screen_opened` | target screen id, source = pause |
| Settings opened | `settings_opened` | source = pause |
| Quit to Title (overworld, confirmed) | `session_quit` | context = overworld, progress_saved = true |
| Concede & Quit (battle, confirmed) | `session_quit` + `battle_abandoned` | context = battle, battle_result = abandoned |
| Cancel quit | none (deliberate) | — |

> **Architecture flags:**
> - `game_paused` / `game_resumed` are **presentation-tier only** — in a turn-based game
>   there is no simulation clock to halt; the overlay simply blocks input. Confirm with the
>   architecture owner that no system needs to *quiesce* on pause (it should not).
> - `session_quit` from the **overworld** should occur at (or trigger) an event-boundary
>   **quiesce-point save** (ADR-0002) so progress is committed before leaving. From **battle**
>   it must **not** save the in-progress fight — the battle is discarded and the world returns
>   to its last committed (pre-battle) state. `battle_abandoned` teardown must follow the
>   ADR-0007 synchronous `battle_ended` cascade / `BattleContext`-drop contract.

---

## Transitions & Animations

- **Open:** overlay fades in (≤0.2s) while the gameplay layer dims to the scrim value. No
  slide/parallax. In battle, the dim must keep the battlefield **readable** (it is context the
  player may want while deciding to Resume or Concede).
- **Close (Resume):** symmetric fade-out; the gameplay layer un-dims. Returns focus to the
  exact prior state — no re-layout, no reset.
- **Confirm modal:** fade + slight scale-in (≤0.2s) over the already-dimmed overlay.
- **Exit to another scene** (Workshop / World Map / Quit): overlay fades to the loading
  indicator, then to the destination — same transition grammar as main-menu exits.
- **Reduced-motion alternative:** plain crossfades, no scale; nothing exceeds **3
  flashes/second** (accessibility §1.4, BLOCKING). No information lives in motion.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Current context (overworld / battle) | Game/Screen manager (ADR-0004) + `BattleController` (ADR-0007) | Read | Decides which variant to show |
| Live gameplay state (behind overlay) | Overworld state / `BattleContext` | Read (preserve) | Must survive Resume untouched — the overlay owns none of it |
| Quiesce-point save (on overworld Quit) | `SaveLoadService` (ADR-0001) via quiesce point (ADR-0002) | **Write** | Commit before leaving; architecture-owned timing |
| Battle teardown (on battle Quit) | `BattleController` (ADR-0007) | **Write (discard)** | Abandon `BattleContext`; no save of the fight |
| Settings values | Settings provider | Read | Menu only navigates to Settings; does not own settings state |

The Pause Menu **owns no game state.** It reads the current context to pick a variant and
delegates every write (quiesce save, battle teardown) to the owning system. It must never
mutate world or battle state directly — freezing is achieved by blocking input, not by
altering the model.

---

## Accessibility

Committed tier: **GAG Basic** (`design/accessibility-requirements.md`).

- **Touch targets:** every button ≥44×44pt (≥56px preferred); generous spacing, and the
  `Quit to Title` control is **separated by a divider** from `Resume` so the destructive action
  is never a mis-tap from the safe default (motor safety, §2.1 + §2.4 intent).
- **Destructive-action confirmation (§2.4):** both `Quit to Title` (overworld) and `Concede &
  Quit` (battle) route through a confirm; **Cancel is the default/safe choice.** The battle
  variant's copy explicitly states the fight will be lost.
- **Color is never the sole signal (§1.3):** the destructive Quit control carries a warning
  **label/icon + shape/position separation**, not just a red tint.
- **Contrast (§1.1):** panel and labels meet the MVP contrast floor over the dimmed gameplay
  scrim (the scrim exists partly to guarantee this).
- **Motion (§1.4):** open/close and confirm stay under 3 flashes/sec (BLOCKING); reduced-motion
  path uses plain crossfades.
- **Input (§2.2 / §2.3 / §2.5):** no simultaneous multi-input; no timing requirement (turn-based
  guarantee — the menu never auto-dismisses or auto-quits); fully mouse-completable on Mac,
  keyboard/`Esc` advisory (post-MVP).
- **No audio-only critical information (§4.1):** all state is visible; nothing depends on sound.

---

## Localization Considerations

- **Longest text:** the battle quit-confirm body ("Leaving now will abandon this battle. Any
  progress in this fight will be lost.") — HIGH PRIORITY; must reflow at ~40% expansion
  (EN→DE/FR) without clipping.
- **Button labels** — "Resume", "Workshop", "Inventory", "World Map", "Settings", "Quit to
  Title", "Concede & Quit to Title" — layout-critical; must stay on one line and tolerate ~40%
  expansion. "Concede & Quit to Title" is the tightest; a shorter localized equivalent may be
  needed (flag for localization).
- No dates/numbers/currencies on this overlay in MVP.

---

## Acceptance Criteria

- [ ] Opening the Pause Menu from the overworld shows the hub variant (Resume + Workshop +
      Inventory + World Map + Settings + Quit to Title); opening it from battle shows the
      minimal variant (Resume + Settings + Concede & Quit only).
- [ ] `Resume` (button, back gesture, or tapping the dimmed scrim) returns to the **exact**
      prior state — same world position or same battle turn — with no state mutation.
- [ ] The Pause Menu never auto-dismisses or auto-quits on a timer (turn-based guarantee).
- [ ] `Quit to Title` and `Concede & Quit` both require a confirm; the save file / battle state
      is unchanged and no `session_quit` fires until confirmed. Cancel returns to the menu.
- [ ] Overworld `Quit to Title` commits a quiesce-point save before leaving; **battle**
      `Concede & Quit` does **not** save the in-progress fight and returns to the pre-battle
      committed state.
- [ ] The destructive Quit control is separated from `Resume` by a divider and is
      distinguishable **without relying on color alone**.
- [ ] Every interactive control has a touch target ≥44×44pt and a visible press-release state.
- [ ] `Settings` opened from pause returns to the Pause Menu (over the same frozen context),
      not to the Main Menu.
- [ ] No animation on this overlay exceeds 3 flashes/second; the reduced-motion path uses plain
      crossfades.

---

## Open Questions

- **Player journey map not yet created.** Template at `.claude/docs/templates/player-journey.md`.
  Run `/ux-design` Phase 2b or author it manually to ground this screen's player-context
  assumptions (currently reasoned from game-concept + hud.md, not a journey map).
- **No manual "Save Game" action** — this spec assumes autosave at event-boundary quiesce
  points (ADR-0002) and no save-anywhere button, consistent with the workshop-save-point model.
  This depends on the **still-open OQ-EP-2** (save-trigger granularity, `exploration-progress.md`).
  If OQ-EP-2 resolves toward player-triggered saves, revisit whether pause needs a Save button.
- **Battle exit vocabulary:** "Concede & Quit to Title" assumes leaving battle = forfeit +
  return to title. A separate **in-battle "Flee/Retreat"** mechanic (return to overworld without
  quitting to title) may be desirable but is a **combat-design** question (TBC), not a pause-UI
  one — flagged for the game designer, out of scope here.
- **Dependent screens not yet specced:** `settings.md`, `workshop.md`, `inventory.md`,
  `world-map.md` are all navigation targets from the hub variant but have no UX spec yet. Their
  entry-point contracts must match this spec's exits when authored.
- **In-battle pause affordance placement:** battle.md specs the combat HUD (PG-01…PG-09) but
  does not yet define where the pause/menu affordance sits. This needs a small addition to
  battle.md (flag for a `/ux-review` that touches both) — do not edit battle.md unilaterally.
- **`Esc`-to-pause on Mac:** advisory/post-MVP per accessibility §2.5; confirm whether it's
  worth including for the Mac launch even though full keyboard nav is deferred.
- **Overworld hub vs. dedicated menu button:** hud.md routes the hub through the single `☰`
  affordance; confirm no separate overworld menu entry is expected.
