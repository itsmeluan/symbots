# Accessibility Requirements — Symbots

**Status**: Approved (decisions locked 2026-07-14)
**Date**: 2026-07-14
**Author**: Luan + Accessibility Specialist
**Next review**: Pre-Production gate (`/gate-check pre-production`)

---

## Baseline Standard

**Target**: Game Accessibility Guidelines (GAG) — Basic tier as mandatory floor,
selected Intermediate items where cost is low given the genre.

**Rationale**: WCAG 2.1 AA is a web standard; its specific criteria (focus
indicators, page titles, skip links) do not map cleanly to games. GAG Basic
represents the industry-consensus minimum, maps naturally to mobile/touch games,
and is already partially satisfied by decisions already locked into the architecture
(≥44×44pt tap targets, no hover-only interactions, turn-based = no twitch timing).
Specific WCAG 2.1 success criteria are cited below where they do apply directly
(contrast, text size) because those numbers are precise and testable.

**Scope**: Mac (launch) + iOS (primary long-term). No gamepad. Touch is primary
input. Keyboard/mouse is the Mac development/launch platform.

---

## 1. Visual Accessibility

### 1.1 Contrast — MVP-COMMITTED

| Requirement | Standard | Value |
|---|---|---|
| Normal body text (labels, stat values, descriptions) | WCAG 2.1 SC 1.4.3 | Minimum **4.5:1** foreground-to-background |
| Large text (headings ≥18pt, bold labels ≥14pt) | WCAG 2.1 SC 1.4.3 | Minimum **3:1** |
| UI elements (button borders, icon outlines, progress bars, break-pip indicators) | WCAG 2.1 SC 1.4.11 | Minimum **3:1** against adjacent background |
| Disabled / inactive elements | No minimum enforced | Must visually differ from enabled state — use opacity reduction or desaturation, not color alone |

**Verification**: Manual check in browser-based contrast tools (e.g. Coolors, WebAIM) during art
review, and in the shared project Theme (`assets/ui/theme.tres`) before any screen ships.
Not automatable in GUT. Blocking gate before each screen is marked done.

**Engine note**: Godot's `Color` uses sRGB; contrast ratios must be verified on actual sRGB values
exported to screen. Do not compute ratios from linear-space internal values.

---

### 1.2 Text Size — MVP-COMMITTED

This project uses Godot's virtual-px coordinate space at the project reference resolution.
ADR-0008 explicitly flags the `custom_minimum_size` / virtual-px vs iOS-pt calibration as
an open gate: the project's `display/window/stretch` mode plus `content_scale_factor` must
be set so that **1 virtual px ≈ 1 iOS pt on-device**. All minimum sizes in this section
are in **logical pt / CSS pt** — the physical-pixel equivalent on any given device is
determined by that device's density. The calibration must be verified against a real
target device (iPhone with a representative DPI) before any text-size pass is meaningful
(see Decision 5 in the design log — this is inherited from ADR-0008's engine review).

| Text role | Minimum size (pt) | Notes |
|---|---|---|
| Body / stat value / description | **16pt** | Below 16pt on iOS is reliably unreadable without zoom |
| Damage numbers / turn log / secondary labels | **14pt** | Only for dense UI where space is at a premium |
| Headings / screen titles | **20pt** | May be larger |
| Captions / tooltips | **13pt** absolute floor | No text below this size anywhere |

**Text scaling toggle (MVP-COMMITTED — single large-text toggle, Decision 2)**:
The project Theme must define at least two font-size presets. The large-text
toggle increases all role sizes by **+4pt minimum** (e.g., 16 → 20, 14 → 18).
This is the single scaling step for MVP. A continuous slider is post-MVP aspirational.

**Verification**: Screen-tree GUT audit test checking `Label` `font_size` or `theme_override`
values against the constants defined here. Not a replacement for visual review on device.

---

### 1.3 Color as Information — MVP-COMMITTED

The game uses elemental color language (Fire = amber/red, Electric = cyan/yellow, Kinetic = TBD)
and rarity tiers (COMMON → RARE → etc.) prominently. The following rules apply to every
information-bearing use of color:

- **Color is never the sole differentiator for any game-critical information.**
  Every element type, rarity tier, part slot type, synergy tag, and battle status must
  carry a secondary signal — one of: icon shape, text label, symbol, outline pattern,
  or position/grouping.
- Examples that MUST comply:
  - Element type on a part card: element icon + label, not color fill alone
  - Battle status (Shock / Burn / Stagger): status icon + text label in the HUD,
    not only a color tint on the Symbot sprite
  - Synergy progress indicators: count text ("2/3") + frame shape, not color graduation alone
  - Part rarity: text tier label + border style, not just border color
  - Break-pip progress (the enrage escalation is a key emotional beat per TBC Player Fantasy):
    the pips must have a visual state change beyond color (fill icon vs. empty icon,
    or cracked vs. intact graphic)

**Colorblind safe palette (Decision 3 — Safe palette by default)**: the default
elemental/rarity palette is designed to be distinguishable under Deuteranopia and
Protanopia (the most common red-green forms) — hues must differ in **both hue and
luminance**. The Kinetic element (currently undefined) must be assigned a blue-family
or high-contrast non-red color to avoid conflict. No dedicated colorblind mode /
palette-swap system is built for MVP; the secondary-signal rule above is the safety net
that keeps the game navigable even if a color is misread.

**Standard**: WCAG 2.1 SC 1.4.1 — Use of Color.

**Verification**: Manual review against the element/rarity palette at each art review.
Simulation-based: screenshot processed through a Deuteranopia filter (macOS Accessibility
Display filter, or third-party Sim Daltonism) before any UI screen is marked done.
This is an advisory gate, not blocking, but non-compliance is a severity HIGH defect.

---

### 1.4 Motion and Visual Effects — MVP obligation + POST-MVP aspiration

Turn-based gameplay has no continuous motion or parallax. However:

- **MVP obligation**: any particle effects, screen flash, or animated transitions that
  loop or repeat rapidly must not exceed 3 flashes per second (WCAG 2.1 SC 2.3.1 — Three
  Flashes or Below Threshold). Part-break effects and enrage visual telegraphing are
  cited in the TBC GDD as "central emotional beats" — they need visual impact but must
  stay below the flash threshold.
- Post-MVP: a "Reduce Motion" option that replaces screen-flash confirmations with a
  static color overlay is an Intermediate GAG item worth revisiting before the iOS
  release milestone.

**Verification**: Visual QA review of each effect. The three-flashes rule is BLOCKING.

---

## 2. Input and Motor Accessibility

### 2.1 Touch Target Size — MVP-COMMITTED (already locked)

From `technical-preferences.md` and ADR-0008:
- Every interactive `Control` must have `custom_minimum_size >= Vector2(44, 44)`
  (in calibrated virtual px ≈ pt; see §1.2 calibration note).
- No hover-only interactions anywhere.

**Verification**: Automated GUT screen-tree test (`custom_minimum_size` audit) per
ADR-0008 §3. Blocking gate.

---

### 2.2 No Simultaneous Multi-Input Requirement — MVP-COMMITTED

Turn-based genre makes this low-risk by default. Explicit requirements:
- No action in the game may require two simultaneous touch points unless a single-touch
  alternative is always available.
- No action may require a timed swipe gesture or swipe-direction input without a
  button/tap fallback.
- All menu navigation (part comparison, move selection, inventory browsing, synergy
  indicators) must be completable by sequential taps alone.

**Verification**: Manual walkthrough with a single-touch interaction model at QA.
Advisory gate.

---

### 2.3 No Input Timing Requirements — MVP-COMMITTED (genre guarantee)

The game is turn-based (TBC GDD: "Turn-based is a design commitment, not a placeholder.
Every UI decision assumes the player has time to think."). Therefore:
- No action requires input within a time window under player control.
- Any countdown or time-sensitive UI element (if ever added) must have a pause or
  disable option.
- Consumable use, move selection, target selection, and workshop interactions are
  all untimed by design.

This is satisfied by the genre choice; it must be preserved in all future feature additions.

---

### 2.4 Destructive Action Confirmation — MVP-COMMITTED

Cognitive and motor safety. Any action that is difficult or impossible to undo must
present a confirmation step:
- Scrapping a part (permanent, gives Scrap currency)
- Upgrading a part (resource cost)
- Disassembling a Symbot build
- Any future "sell / discard" inventory action

**Standard**: Maps to GAG Basic — "Provide an option to skip or simplify button input
sequences" / cognitive load reduction.

**Verification**: Manual walkthrough of each destructive action path. Advisory gate.
GUT integration test can check that the `part_scrapped` signal is only emitted after
a confirmed action, not on first tap.

---

### 2.5 Keyboard Navigation on Mac — POST-MVP ASPIRATIONAL

From `technical-preferences.md`: "Keyboard/mouse is the development environment and
early launch platform." From ADR-0008: "Keyboard/gamepad focus (`grab_focus()`,
keyboard-only in 4.6) is an optional Mac convenience; iOS touch flows never require it."

- MVP: all screens must be completable via mouse click on Mac. Keyboard-tab navigation
  is advisory, not required.
- Post-MVP (before or at Mac App Store submission): full keyboard navigation of all
  screens. This is Intermediate GAG territory and meaningful for Mac players with motor
  limitations.

---

## 3. Cognitive Accessibility

### 3.1 Clear Language — MVP-COMMITTED

- All UI text (move descriptions, stat names, item descriptions, status effect explanations)
  uses plain language. No undefined jargon without in-context explanation on first encounter.
- Stat names must be self-describing or have a tooltip/info panel that explains them
  (e.g., what "Processing" does in this game — it scales status potency).
- Status effects (Shock, Burn, Stagger) must have their mechanical effect visible in the
  combat UI, not require memorization.

**Verification**: Heuristic review of all text by a non-developer reader before any
content string is locked. Advisory gate.

---

### 3.2 Consistent UI Patterns — MVP-COMMITTED

- Navigation hierarchy is consistent across all screens (back button / cancel in the
  same position; confirm button in the same position).
- Part cards display the same information in the same layout regardless of where they
  appear (Workshop, Battle, Inventory).
- Stat delta display ("+ / −" on equip preview) uses consistent visual language everywhere.
- The shared project Theme (ADR-0008 §5) and the Interaction Patterns document
  (`design/ux/interaction-patterns.md`) are the implementation of this requirement.

**Verification**: Cross-screen UI review against the Interaction Patterns document.
Advisory gate.

---

### 3.3 Information Density Options — POST-MVP ASPIRATIONAL

The synergy system, part stats, and combat log can produce dense on-screen information.
A future "simplified HUD" option (hiding secondary stat readouts, condensing the battle
log) is an Intermediate GAG item appropriate before the iOS launch milestone.

MVP exception: the initial scope of information displayed can be conservative by default
(show only the most essential stats, let the player expand to see more) — this is a
normal information architecture decision, not a dedicated accessibility feature.

---

## 4. Auditory Accessibility

### 4.1 No Audio-Only Critical Information — MVP-COMMITTED

The game has no mandatory VO or narration in MVP ("Story, dialogue, or narrative content"
is explicitly Not in MVP per `design/gdd/game-concept.md`). However:
- No game-critical event may be communicated through sound alone.
- Part-break confirmation, synergy activation ("the click" — Beat 3 in the Synergy GDD),
  battle outcome (victory/defeat), and overheat must each have a distinct visual indicator
  in addition to their audio cue.
- The TBC GDD flags the enrage visual as a "central emotional beat" — this is simultaneously
  an audio and an accessibility requirement.

**Standard**: WCAG 2.1 SC 1.1.1 — Non-text Content (adapted for game events). GAG Basic.

**Verification**: For each audio-bearing game event, confirm the corresponding visual
indicator exists in the screen spec and is implemented. Manual QA walkthrough with
device sound muted. Blocking gate.

---

### 4.2 Separate Volume Controls — MVP-COMMITTED

| Control | Required in MVP |
|---|---|
| Master volume | Yes |
| Music volume | Yes |
| SFX volume | Yes |
| UI sounds volume | Desirable; may be combined with SFX in MVP |

All saved to the settings/save system (ADR-0001). These are the minimum sliders.
A "mute all" toggle is equivalent to Master at 0 and acceptable in MVP.

**Verification**: Settings screen walkthrough confirming persistence across sessions.
Advisory gate.

---

### 4.3 Subtitles / Captions — NOT APPLICABLE (MVP)

No VO in MVP scope. This becomes relevant at Vertical Slice when rival NPC dialogue
is introduced. Flag for that milestone.

---

## 5. Screen Reader / AccessKit

### AccessKit posture — POST-MVP, DEFERRED WITH A COMMITMENT TO AVOID BLOCKING WORK (Decision 1)

**Engine reality (verified from version table and ADR-0008)**: Godot 4.5 added AccessKit
integration, providing native OS accessibility / screen reader support on `Control` nodes.
This is in the project's engine (4.6). AccessKit exposes semantic labels, roles, and
interactive states to OS-level assistive technology (VoiceOver on iOS/Mac).

**What this costs**: AccessKit in Godot 4.5+ is engine-native for standard `Control` nodes.
The primary cost is:
1. Setting `accessibility_name` on every interactive `Control` that lacks visible text
   (icon buttons, image-only controls, progress indicators).
2. Setting `accessibility_description` on complex controls where the visible label is
   insufficient.
3. Testing with VoiceOver on a real device.

Standard text labels and buttons with visible text labels incur near-zero additional work —
AccessKit reads the label automatically.

**Decision 1 (locked)**: Defer full screen-reader support to post-MVP — but enforce the
"keep the door open" discipline now.

**MVP obligation regardless (door-open discipline)**:
- Never use a bare `Control` or `Sprite2D` as an interactive element — use `Button`
  or `BaseButton` subclasses (these have `accessibility_*` properties and correct roles).
- Icon-only buttons MUST have a non-empty `tooltip_text` or `accessibility_name` set
  (even if screen reader support is deferred, the field must be filled in as content
  authoring practice).
- Do not use nested transparent `Control` layers to swallow input in ways that break
  AccessKit's hit-testing.

This is a "keep the door open" posture, not a commitment to test or ship screen-reader
support in MVP.

**Standard**: WCAG 2.1 SC 4.1.2 — Name, Role, Value (aspirational for games; cited as
the relevant principle). GAG Intermediate.

**Verification (if full screen-reader support is later committed)**: Manual VoiceOver
walkthrough on iPhone and Mac. Not automatable in GUT.

---

## 6. iOS-Specific Requirements

### 6.1 Dynamic Type — POST-MVP ASPIRATIONAL

iOS system Dynamic Type preference affects apps that opt in. Godot's `tr()` + Theme-based
font sizes do not automatically respond to iOS Dynamic Type. Supporting it requires either
native plugin work or a project-side font-size preset that reads from the iOS UserDefaults.
This is non-trivial and deferred to the iOS release milestone. The §1.2 large-text toggle
is the MVP substitute.

### 6.2 Reduced Motion Preference — POST-MVP ASPIRATIONAL

iOS exposes `UIAccessibility.isReduceMotionEnabled`. Godot does not read this automatically.
If adopted, it would require a GDExtension or an exported iOS plugin. Deferred to the iOS
milestone. The §1.4 MVP obligation (no >3Hz flashes) is the MVP substitute.

### 6.3 VoiceOver on iOS — see §5 AccessKit posture above.

---

## 7. Verification Summary

| Category | Requirement | MVP? | Gate level | Method |
|---|---|---|---|---|
| Contrast — text | ≥4.5:1 normal, ≥3:1 large | COMMITTED | BLOCKING | Manual / contrast tool |
| Contrast — UI elements | ≥3:1 | COMMITTED | HIGH | Manual |
| Text sizing | ≥16pt body, 14pt secondary, 13pt floor | COMMITTED | HIGH | GUT audit + visual |
| Large-text toggle | +4pt all roles | COMMITTED | HIGH | Manual verification |
| Color not sole carrier | Icon/label/shape backup everywhere | COMMITTED | BLOCKING | Manual + Deuteranopia sim |
| Flash rate | <3 flashes/sec per effect | COMMITTED | BLOCKING | Visual QA |
| Touch targets | ≥44×44pt custom_minimum_size | COMMITTED | BLOCKING | GUT screen-tree test |
| No simultaneous multi-touch | All actions single-tap completable | COMMITTED | HIGH | Manual walkthrough |
| No timing requirements | Genre-guaranteed | COMMITTED | BLOCKING | Design gate |
| Destructive confirmation | All permanent actions confirm | COMMITTED | HIGH | Manual + GUT signal test |
| Audio: no audio-only info | Visual equivalent for every cued event | COMMITTED | BLOCKING | Manual (muted device) |
| Volume controls | Master + Music + SFX | COMMITTED | ADVISORY | Settings walkthrough |
| AccessKit door-open | `accessibility_name` on icon controls | COMMITTED | HIGH | Code review |
| Keyboard nav (Mac) | Mouse-complete only (MVP) | COMMITTED | ADVISORY | Manual |
| Screen reader (VoiceOver) | Deferred — keep door open | POST-MVP | — | VoiceOver walkthrough |
| Colorblind palette | Deuteranopia-safe palette (default) | COMMITTED | HIGH | Sim Daltonism review |
| Colorblind dedicated mode | Not built (secondary-signal rule covers) | POST-MVP | — | — |
| Reduce Motion toggle | Deferred | POST-MVP | — | — |
| Dynamic Type (iOS) | Deferred | POST-MVP | — | — |
| Simplified HUD | Deferred | POST-MVP | — | — |

---

## 8. Cross-References

- `technical-preferences.md` — `## Input & Platform`: touch-first, 44×44pt, no hover,
  no gamepad; this document extends those commitments into accessibility language.
- `docs/architecture/adr-0008-ui-architecture.md` — §3 touch-first rules, §5 Theme
  discipline; `custom_minimum_size` audit test; virtual-px vs pt calibration warning
  (directly affects §1.2 of this document).
- `design/gdd/game-concept.md` — Anti-Pillar "NOT a real-time action game" guarantees
  no timing-based accessibility barriers; MVP scope excludes VO, deferring §4.3.
- `design/gdd/turn-based-combat.md` — Player Fantasy section (enrage/break as emotional
  beats): visual telegraphing of status and break events is simultaneously a UX requirement
  and the §4.1 / §1.3 audio-visual backup requirement.
- `design/gdd/synergy-system.md` — Beat 3 (synergy activation) is cited as a "binding"
  emotional beat requiring visual + audio confirmation — this directly triggers §4.1.
- Godot 4.5 AccessKit introduction (from `docs/engine-reference/godot/VERSION.md`):
  screen-reader support is engine-native at the project's engine version, not a from-scratch
  build. See §5 for the deferred-but-door-open posture.

---

## Design Log — Locked Decisions (2026-07-14)

| # | Decision | Choice | Downstream action |
|---|----------|--------|-------------------|
| 1 | Screen reader in MVP | **Defer, keep door open** | Button subclasses only; `accessibility_name` on icon controls |
| 2 | Text scaling model | **Single large-text toggle (+4pt)** | Two Theme presets; test large-text state during layout design |
| 3 | Colorblind approach | **Safe palette by default** | Constraint → Art Director before elemental palette locks; Kinetic = non-red |
| 4 | Synergy/enrage cue | **Visual state-change required** | Flag to Art Director: document active/inactive visual states, not just audio |
| 5 | virtual-px→pt calibration | **Verify on-device first** | First UI story must calibrate before 44pt/font audits are meaningful |

*This document is a living requirement. Update at each pre-gate review and before any
new screen enters implementation.*
