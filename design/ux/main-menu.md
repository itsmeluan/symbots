# UX Spec: Main Menu (Title Screen)

> **Status**: In Review
> **Author**: Luan + ux-designer
> **Last Updated**: 2026-07-17
> **Journey Phase(s)**: Session entry — the game's front door (every session begins here)
> **Template**: UX Spec

---

## Purpose & Player Need

The Main Menu is the game's front door: the first interactive screen after the boot
sequence, and the screen every session begins from. Its single job is to get the player
**into their workshop as fast as possible** while presenting the game's identity and the
few meta actions that don't belong inside gameplay (start over, change settings, quit).

The player arrives wanting to **resume the hunt** (returning player) or **begin building
their first Symbot** (new player). The menu must serve both without friction and without
ambiguity about which action continues progress and which one destroys it.

> **What would go wrong without it:** the boot sequence would either dump the player
> straight into a save (no way to start fresh, change settings, or recover from a bad
> save) or into a new game (silently destroying an existing save). The menu is the safe
> fork between *continue* and *start over* — the single place that irreversible-progress
> decisions are made deliberately, not by accident.

---

## Player Context on Arrival

| Context | Trigger | Emotional state | Design assumption |
|---|---|---|---|
| **New player, first launch** | No save data exists | Curious, slightly uncertain, ready to start | `New Game` is the obvious, unmissable call to action; `Continue` is absent, so there is no wrong first choice |
| **Returning player** | A save exists | Anticipation, low patience — "let me back into my build" | `Continue` is the primary, largest, top-most action; one tap resumes at the workshop save point |
| **Returning after a loss / mid-hunt quit** | A save exists | Focused, goal-carried ("I still need that Servo Arm") | Same as returning — `Continue` restores exactly where they left off; nothing on the menu re-litigates the last session |

Players always arrive here **voluntarily in the sense that it is the natural session start**,
but they do not *choose* to visit it — it is the unavoidable entry gate after boot. The
design therefore optimizes for a returning player who wants to leave this screen within one
or two seconds, while remaining legible to a brand-new player who has never seen it.

Emotional register (from art bible §2.7 + Visual Identity Anchor): **calm confidence with
character.** This is the "Colorful Mechanical Wilderness" establishing image — warmer and
more characterful than the flat catalog menus (§2.7), but still restrained. No frantic
motion, no urgency. The world is worth returning to; the door is quiet and inviting.

---

## Navigation Position

This screen lives at: **Boot Sequence → Main Menu → { Overworld / Workshop | Settings | OS }**

- The Main Menu is a **top-level root destination.** It is reached only from the boot
  sequencer (ADR-0004 `BootScreen`) at application start.
- It is **not** reachable from within gameplay. Returning to the title from inside a session
  is a `pause` menu concern ("Quit to Title"), specified separately in `pause.md`; that path
  re-enters this same Main Menu screen.
- There are **no alternate entry paths** in MVP: boot is the only way in, and Quit-to-Title
  (from pause, once specified) re-enters via the same route.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Boot Sequence (`BootScreen`, ADR-0004) | Boot completes: autoloads ready, save-slot presence resolved | Whether a save exists (drives Continue enabled/hidden); loaded settings (audio/display) |
| Pause → "Quit to Title" | Player exits an active session (spec: `pause.md`) | Session already saved/quiesced per ADR-0002 autosave-quiesce; arrives as a "returning player" (save exists) |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Overworld / Workshop | `Continue` tap → save loads | Resumes at the workshop save point (game-concept: "session ends with a clear save point at the workshop"). Non-destructive — read-only load |
| New-game intro / starter flow → Overworld | `New Game` tap (+ overwrite confirm if a save exists) | **Irreversible when a save exists** — initializes a fresh save, overwriting the prior one. Gated by confirm modal |
| Settings screen | `Settings` tap | Returns to Main Menu on back; no state change |
| OS (application quit) | `Quit` tap (**Mac only**) | Clean shutdown. Hidden on iOS per Apple HIG (apps do not self-terminate) |

> **One-way exit:** `New Game` with an existing save is the only irreversible exit — once
> confirmed, the prior save is gone. Every other exit is reversible (Continue re-loads,
> Settings returns, Quit re-launches to this same screen).

---

## Layout Specification

### Information Hierarchy

Ranked by what the player needs to see first:

1. **The primary action** — `Continue` (returning) or `New Game` (new player). This is the
   single most important element; it must be the largest, highest-contrast, thumb-reachable
   target on screen.
2. **Game identity** — the title / logo. Establishes "you are in Symbots" and carries the
   visual anchor. Prominent but subordinate to the primary action.
3. **Secondary actions** — the remaining menu buttons (`New Game` for returning players,
   `Settings`, and `Quit` on Mac). Present, clearly grouped, visually lighter than the
   primary action.
4. **Utility / passive info** — build/version string. Discoverable, never competing for
   attention (small, corner-anchored).

> **Anti-pillar guard:** the title screen shows **no completion counters, no collection
> percentages, no "parts found: 12/20"** (game-concept anti-pillar — "no Pokédex-style
> completion counter"). Identity and the resume action are the content; the menu is not a
> progress ledger.

### Layout Zones

**Landscape orientation** (matches `battle.md`; iOS + Mac both landscape). Chosen arrangement
— **Title-left / actions-left column over an establishing background:**

- **Background zone (full-bleed):** a calm "Colorful Mechanical Wilderness" establishing
  image — the world you return to. Low-urgency, no looping animation beyond a subtle ambient
  drift (respecting the reduced-motion and <3-flashes rules). Recedes behind the UI; never
  competes with button legibility (contrast floor enforced over the art).
- **Title zone (upper-left):** game logo / wordmark. Non-interactive.
- **Action column (left, vertically stacked, under the title):** the primary + secondary
  button stack, left-anchored so it sits under the reading eye and within comfortable thumb
  reach on iOS (left or right per handedness is an open question; left-anchored default).
- **Utility zone (bottom corner):** version/build label. Non-interactive.

The center and right of the screen stay visually open for the establishing art — the menu
"gets out of the way" of the world it is inviting you into.

### Component Inventory

**Background zone**
- *Establishing background image* — non-interactive. Content: a representative
  Colorful-Mechanical-Wilderness scene (asset TBD — depends on art bible §5/§6, not yet
  authored). New pattern? No — passive art.

**Title zone**
- *Game logo / wordmark* — non-interactive image. Content: "Symbots" identity mark.

**Action column** (all buttons use **PC-01 — Button, touch press-release**; ≥44×44pt, ≥56px
preferred per the vertical-slice control standard)
- *Continue* — interactive. Content: label "Continue" (open question: append save context
  e.g. last-played location/time). **State-dependent:** shown & primary when a save exists;
  hidden (or shown disabled with a one-line explanation) on first launch. New pattern? No —
  PC-01.
- *New Game* — interactive. Content: label "New Game". When a save exists, tapping opens the
  overwrite-confirm modal before proceeding. New pattern? No — PC-01 + standard confirm.
- *Settings* — interactive. Content: label "Settings". Opens the Settings screen. PC-01.
- *Quit* — interactive, **Mac-only** (absent on iOS). Content: label "Quit". PC-01.

**Overlay (conditional)**
- *New-Game overwrite confirm modal* — interactive modal. The PC-01 "deferred standard
  confirm dialog." Content: warning that starting a new game **permanently overwrites** the
  existing save, plus two buttons: a destructive-styled "Start New Game" and a safe
  "Cancel" (default focus / safe choice). New pattern? Standard destructive-confirm — shared
  with scrap/disassemble flows (accessibility §2.4); flag for the pattern library if it
  isn't formalized there.

**Utility zone**
- *Version / build label* — non-interactive text. Content: semantic version + build id.

### ASCII Wireframe

Returning player (save exists), Mac (Quit present):

```
┌──────────────────────────────────────────────────────────────┐
│                                                                │
│   ███████ ██    ██ ███    ███ ██████   ██████  ████████ ███    │  ← Title / logo (upper-left)
│   symbots · colorful mechanical wilderness                     │
│                                                                │
│   ┌────────────────────────┐                                   │
│   │      ▶  CONTINUE        │   ← primary: largest, high-       │      [ establishing
│   └────────────────────────┘      contrast, top of stack         background art —
│   ┌────────────────────────┐                                       recedes, no urgency ]
│   │        New Game         │   ← secondary (opens overwrite                            │
│   └────────────────────────┘      confirm — save exists)                                │
│   ┌────────────────────────┐                                   │
│   │        Settings         │                                   │
│   └────────────────────────┘                                   │
│   ┌────────────────────────┐                                   │
│   │          Quit           │   ← Mac only (hidden on iOS)      │
│   └────────────────────────┘                                   │
│                                                                │
│  v0.1.0 (build 1234)                                           │  ← utility (bottom corner)
└──────────────────────────────────────────────────────────────┘
```

First launch (no save), iOS (no Quit):

```
┌──────────────────────────────────────────────────────────────┐
│   symbots                                                      │
│                                                                │
│   ┌────────────────────────┐                                   │
│   │      ▶  NEW GAME        │   ← primary (no save → the only   │
│   └────────────────────────┘      obvious first action)        │
│   ┌────────────────────────┐                                   │
│   │        Settings         │                                   │
│   └────────────────────────┘                                   │
│   ( Continue absent — no save exists )                         │
│                                                                │
│  v0.1.0                                                        │
└──────────────────────────────────────────────────────────────┘
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default — returning** | A save exists | `Continue` shown, primary, top of stack; `New Game` secondary and armed with overwrite-confirm |
| **Empty — first launch** | No save data | `Continue` hidden (or disabled + one-line "No saved game yet" note); `New Game` becomes the primary action; no overwrite confirm on New Game |
| **Corrupt-primary-save** | Primary slot unparseable on boot | Per ADR-0001 never-destroy-unparseable + `.bak` fallback: boot resolves Continue against the `.bak`. If `.bak` loads, treat as returning. If both fail, `Continue` shows a **non-destructive** error toast ("Saved game couldn't be loaded") and remains; `New Game` stays available but **never auto-overwrites** — overwrite happens only through the explicit confirmed New Game path |
| **Loading** | `Continue` or confirmed `New Game` tapped | Brief load indicator (spinner or progress) while the world/save resolves; menu inputs disabled during load to prevent double-trigger |
| **Overwrite-confirm open** | `New Game` tapped while a save exists | Modal overlays the menu; background menu dims and is non-interactive until Cancel/Confirm |
| **Platform — iOS** | Running on iOS | `Quit` button absent (Apple HIG); safe-area insets applied so no control sits under the notch/home indicator |
| **Platform — Mac** | Running on Mac | `Quit` present; mouse-clickable; window close (⌘Q / red button) also exits cleanly |

---

## Interaction Map

Mapping interactions for: **Touch (primary) + Mac mouse.** Gamepad support: **None.**
Keyboard navigation on Mac is **advisory / post-MVP** (accessibility §2.5) — all actions
must be completable by mouse click; keyboard-tab order is a nice-to-have, not required.

| Component | Action | Input(s) | Immediate feedback | Outcome |
|---|---|---|---|---|
| Continue | Tap / click | Touch tap, mouse click | PC-01 press-release (down-state on press, action on release) | Load primary (or `.bak`) save → fade to Overworld/Workshop |
| New Game (no save) | Tap / click | Touch, mouse | PC-01 press-release | Initialize fresh save → new-game intro → Overworld |
| New Game (save exists) | Tap / click | Touch, mouse | PC-01 press-release | Open overwrite-confirm modal (no save mutation yet) |
| — Confirm "Start New Game" | Tap / click | Touch, mouse | PC-01 press-release, destructive styling | Overwrite save → initialize fresh → new-game intro → Overworld |
| — Cancel | Tap / click | Touch, mouse | PC-01 press-release; safe default | Close modal → return to menu, no change |
| Settings | Tap / click | Touch, mouse | PC-01 press-release | Navigate to Settings screen |
| Quit (Mac) | Tap / click | Touch (n/a on Mac), mouse | PC-01 press-release | Clean application shutdown |

For every navigation action the target is a distinct screen: Overworld (no spec yet — flag as
dependency), Settings (`settings.md`, not yet authored — dependency), Workshop (no spec yet —
dependency). These are noted in Open Questions.

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Continue (load success) | `game_continued` | slot id, source (primary / `.bak`) |
| Continue (load failure, both slots) | `save_load_failed` | slot id, failure reason |
| New Game confirmed (fresh start) | `new_game_started` | — |
| New Game — overwrite confirmed | `new_game_started` (with overwrite flag) | prior-save existed = true |
| Cancel overwrite | none (deliberate — a cancelled action is not a tracked event) | — |
| Settings opened | `settings_opened` | source = main_menu |
| Quit (Mac) | `game_quit` | source = main_menu |

> **Architecture flag (persistent-state writes):** `new_game_started` (especially the
> overwrite variant) **initializes and writes the save file**, destroying prior progress.
> Like the `part_scrapped` rule in accessibility §2.4, this event must fire **only after the
> confirm modal is accepted**, never on the first `New Game` tap. `game_continued` triggers a
> save **read/load** (no write). Both need explicit attention from the save/load owner
> (ADR-0001 `SaveLoadService`).

---

## Transitions & Animations

- **Screen enter:** boot sequence fades/crossfades into the Main Menu (no hard cut from a
  logo splash). Establishing background fades in; action column can stagger-in subtly
  (each button ≤0.15s, total under ~0.4s) — optional character, not required.
- **Screen exit (Continue / New Game):** menu fades out into the loading indicator, then
  into the destination screen. No slide/parallax that could induce motion discomfort.
- **Overwrite-confirm modal:** fade + slight scale-in (≤0.2s); background dims. Dismiss on
  Cancel with a symmetric fade-out.
- **Reduced-motion alternative:** all of the above degrade to simple crossfades with the
  ambient background drift disabled. No effect exceeds **3 flashes/second** (accessibility
  §1.4, BLOCKING). The ambient background drift is decorative only — no information lives in
  it.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Save-slot presence + metadata | `SaveLoadService` (ADR-0001) | Read | Drives Continue shown/hidden and any save-context label; resolved at boot |
| Save payload (on Continue) | `SaveLoadService` | Read | Loads primary slot; `.bak` fallback if primary unparseable (never-destroy contract) |
| New save initialization (on New Game) | `SaveLoadService` | **Write** | Creates/overwrites the save. **Architectural attention** — confirmed-only; irreversible overwrite |
| Settings values | Settings provider (ADR-0001 `settings` provider key) | Read | Applied at boot; menu only navigates to the Settings screen, does not own settings state |
| Version / build string | Build config / project metadata | Read | Static, read once |

The Main Menu **owns no game state.** It reads save presence to decide layout and delegates
all writes to `SaveLoadService`. It must not cache or mutate save data itself — how the load
is delivered and how the fresh save is initialized are architecture decisions (ADR-0001), not
UI decisions.

---

## Accessibility

Committed tier: **GAG Basic** (`design/accessibility-requirements.md`).

- **Touch targets:** every button `custom_minimum_size >= Vector2(44, 44)` (§2.1); ≥56px
  preferred per the slice standard. Comfortable spacing so adjacent buttons aren't mis-tapped.
- **Color is never the sole signal (§1.3):** the disabled `Continue` state (first launch)
  uses opacity reduction / desaturation **plus** a text note ("No saved game yet") — not a
  color change alone. The destructive "Start New Game" button carries a warning **label +
  icon**, not just a red fill.
- **Contrast (§1.1):** all button labels and the version string meet the MVP contrast floor,
  **verified over the establishing background art** (the art must not erode label contrast —
  a scrim/panel behind the action column if needed).
- **Destructive-action confirmation (§2.4):** New Game over an existing save routes through
  the confirm modal; Cancel is the safe default. Mirrors scrap/disassemble.
- **Motion (§1.4):** ambient drift + transitions stay under 3 flashes/sec (BLOCKING);
  reduced-motion path disables ambient drift.
- **Input (§2.5):** fully completable via Mac mouse click; keyboard-tab navigation is
  advisory (post-MVP). No simultaneous multi-input, no timing requirement (§2.2 / §2.3).
- **No audio-only critical information (§4.1):** nothing on this screen is communicated by
  sound alone; all state is visible.

---

## Localization Considerations

- **Longest text:** the overwrite-confirm modal body ("Starting a new game will permanently
  erase your current saved game. This cannot be undone.") — HIGH PRIORITY for the
  localization engineer; the modal must reflow, not clip, at ~40% expansion (EN→DE/FR).
- **Button labels** (Continue / New Game / Settings / Quit) are short but layout-critical —
  each must stay on one line; the button width must accommodate ~40% expansion without
  truncation. Mark as localization-sensitive.
- **Version string** is numeric/locale-neutral (no translation), but any "build" word is
  translatable.
- No dates/currencies on this screen in MVP (a save timestamp on the Continue label, if
  added per the open question, would need locale-aware date formatting).

---

## Acceptance Criteria

- [ ] From boot complete, the Main Menu is interactive within **1000ms** (no indefinite hang
      on save-presence resolution).
- [ ] When a save exists, `Continue` is visible, is the top/primary action, and one tap loads
      the save and routes to the Overworld/Workshop **without any confirm prompt**.
- [ ] When **no** save exists, `Continue` is hidden (or disabled with a visible "No saved
      game yet" note) and `New Game` is the primary action.
- [ ] Tapping `New Game` while a save exists opens the overwrite-confirm modal; the save file
      is **not modified** and `new_game_started` **does not fire** until "Start New Game" is
      confirmed. Cancel returns to the menu with no change.
- [ ] With a corrupt primary save, `Continue` loads the `.bak`; if both are unparseable it
      shows a non-destructive error and **does not overwrite** either file.
- [ ] `Quit` is present and cleanly exits on Mac, and is **absent** on iOS.
- [ ] Every interactive control has a touch target ≥44×44pt and a visible press-release state.
- [ ] The disabled `Continue` state and the destructive `Start New Game` button are
      distinguishable **without relying on color alone** (opacity/desaturation + text/icon).
- [ ] No animation on this screen exceeds 3 flashes/second; the reduced-motion path disables
      the ambient background drift.

---

## Open Questions

- **Player journey map not yet created.** Template at `.claude/docs/templates/player-journey.md`.
  Run `/ux-design` Phase 2b or author it manually to ground this screen's player-context
  assumptions (currently reasoned from game-concept, not a journey map).
- **Save-slot model:** this spec assumes a **single primary save slot** (+ one-gen `.bak` per
  ADR-0001). If MVP adopts multiple slots, `Continue` becomes a slot-select list and this spec
  needs a slot-picker sub-flow. Confirm single-slot for MVP.
- **`Continue` label detail:** plain "Continue" vs. "Continue — [zone], [timestamp]". The
  richer label improves orientation but adds a localized date and depends on save metadata.
  Deferred pending the save-metadata shape.
- **Credits screen:** none in MVP; assumed **folded into Settings** (or deferred). Confirm no
  standalone Credits entry is needed for the Mac launch.
- **Dependent screens not yet specced:** `settings.md`, the Overworld/world screen, and the
  Workshop screen are all navigation targets from here but have no UX spec yet. Their
  entry-point contracts must match this spec's exits when authored.
- **Establishing background art** depends on art bible **§5 (Character Design)** and **§6
  (Environment Design Language)**, which are not yet authored (Pre-Production gate gap). The
  layout is art-ready; the asset is not.
- **iOS Quit absence:** confirm the intended iOS exit model is "background the app" with no
  in-menu quit (per Apple HIG) — vs. a "Close" affordance some mobile games still include.
- **Handedness / action-column side:** left-anchored by default; a right-anchored option for
  right-thumb reach on larger iOS devices is worth a playtest but not committed.
