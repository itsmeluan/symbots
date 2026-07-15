# Interaction Pattern Library — Symbots

> **Status**: Seeded 2026-07-15 from `design/ux/battle.md` (9 game patterns + 2 control primitives)
> **Author**: Luan + ux-designer
> **Scope**: Touch-first iOS + Mac (mouse = tap), no gamepad, keyboard post-MVP
> **Authority**: This document is the single source of truth for reusable interaction
> behavior. A screen spec references a pattern by ID; it does **not** re-specify the
> pattern's states/behavior from scratch. New patterns are added here first, then
> referenced.

**Cross-references (binding):**
- `design/ux/accessibility-requirements.md` — GAG Basic tier; every pattern inherits its
  rules (§ Global Interaction Principles below folds them in so entries don't repeat them).
- `docs/architecture/adr-0008-ui-architecture.md` — `Screen` base + `setup(ctx)` injection,
  signal-driven views (no `_process` polling), unified touch press-release, shared Theme
  (200 draw-call discipline, no per-widget materials), 4.6 dual-focus split.
- `.claude/docs/technical-preferences.md` — `## Input & Platform` (44×44pt, no hover-only).

---

## How to Use This Document

- **Screen authors**: cite the pattern ID (e.g. "resource bars use **PG-01**") instead of
  redescribing behavior. If a screen needs behavior a pattern does not cover, either the
  pattern is extended here (with a changelog note) or a new pattern is added — never
  forked silently in a screen spec.
- **Implementers**: the *Godot notes* per pattern name the node types and the
  signal/update path. All patterns are signal-driven (subscribe in `setup`, disconnect on
  `NOTIFICATION_EXIT_TREE`); none polls in `_process` (ADR-0008).
- **Reviewers**: `/ux-review patterns` validates this file (Phase 3C).

---

## Pattern Catalog

| ID | Pattern | Kind | Seeded by | Used by |
|---|---|---|---|---|
| **PC-01** | Button (touch press-release) | Control primitive | battle | battle (all actions) |
| **PC-02** | Long-press Inspect Popover | Control primitive | battle | battle (move/region/status/bench/chip) |
| **PG-01** | Resource Bar (Structure / Energy) | Game HUD | battle | battle |
| **PG-02** | Capped Gauge w/ Threshold Warning (Heat) | Game HUD | battle | battle |
| **PG-03** | Segmented Progress Pip (Break Regions) | Game HUD | battle | battle |
| **PG-04** | Status Badge w/ Duration (+N overflow) | Game HUD | battle | battle |
| **PG-05** | Affordable / Disabled Action Button | Game HUD | battle | battle (4-move panel) |
| **PG-06** | Labelled Target-List Picker | Game HUD | battle | battle |
| **PG-07** | Floating Feedback Text | Game HUD | battle | battle |
| **PG-08** | Event Log | Game HUD | battle | battle |
| **PG-09** | Ordered Initiative Ribbon w/ Active-Turn Marker | Game HUD | battle | battle |

**Deferred standard controls** (add when a screen first requires one — do not pre-build):
toggle, slider, dropdown, list, grid, modal, dialog, toast, tooltip, input field, tab bar,
scroll container. Likely first callers: Workshop (equip/compare), Inventory (grid + scrap
confirm dialog), Settings (sliders + toggles). Each gets a `PC-##` entry when authored.

---

## Global Interaction Principles

Every pattern below inherits these; entries only note *pattern-specific* deviations.

1. **Touch-first, ≥44×44pt.** Every interactive `Control` sets
   `custom_minimum_size ≥ Vector2(44, 44)` in calibrated virtual-px ≈ pt (a11y §2.1;
   calibration gate a11y Decision 5). Mouse click = tap; **no hover-only affordance** —
   hover is enhancement only.
2. **Color is never the sole signal** (a11y §1.3, BLOCKING). Every information-bearing use
   of color carries a second channel: icon shape, text label, glyph, fill level, position,
   or strike/outline. Each pattern names its non-color channel explicitly.
3. **Text floors** (a11y §1.2): body/stat ≥16pt, secondary/duration ≥14pt, absolute floor
   13pt. Large-text toggle adds +4pt to all roles (two Theme presets).
4. **Contrast** (a11y §1.1): text ≥4.5:1 (≥3:1 large); UI elements/bars/pips ≥3:1 against
   adjacent background. Verified on sRGB output, not linear-space values.
5. **Motion** (a11y §1.4, BLOCKING): no pulsing/looping effect exceeds **3 flashes/sec**;
   screen-shake is reserved (battle: Overheat + DOWNED only, <0.3s).
6. **No timing pressure** (a11y §2.3): no pattern requires input within an uncontrolled
   time window. Auto-advancing sequences that carry a beat pause are player-advanced.
7. **Single-finger** (a11y §2.2): no pattern requires simultaneous touches; long-press is
   single-finger with a mouse hover-or-hold equivalent.
8. **AccessKit door-open** (a11y §5): interactive elements are `Button`/`BaseButton`
   subclasses; icon-only controls carry a non-empty `accessibility_name` (or `tooltip_text`)
   even though VoiceOver testing is post-MVP.
9. **Signal-driven, not polled** (ADR-0008): views subscribe to owner signals in `setup`
   and disconnect on `NOTIFICATION_EXIT_TREE`; no `_process` polling of game state.
10. **Theme discipline** (ADR-0008): styling comes from the shared `Theme`
    (`assets/ui/theme.tres`); no per-widget `Material` that breaks 2D batching
    (200 draw-call budget).

**Standard entry format** — every pattern documents: *When to Use · When NOT to Use ·
Anatomy · States · Accessibility (pattern-specific) · Godot notes · Used by.*

---

## PC-01 — Button (touch press-release)

**When to use**: any single-tap commit or navigation action (action-cluster buttons, move
`‹ back`, tap-to-continue).
**When NOT to use**: destructive/irreversible actions without a confirm step (those add a
confirm dialog — deferred standard control); read-only inspection (use **PC-02**).

**Anatomy**: `Button` subclass · visible text label *or* icon + `accessibility_name` ·
optional leading glyph · `custom_minimum_size ≥ (44,44)`.

**States**: `normal` · `pressed` (visual depress on `button_down`) · `disabled`
(desaturated + reduced opacity, **not color alone** — a11y §1.1 disabled rule) ·
`focused` (optional Mac keyboard ring, post-MVP; touch never requires it).

**Interaction**: **unified press-release** (ADR-0008) — the action fires on release
(`pressed` signal) after a press that began on the same control; a press that slides off
before release cancels. This one path serves touch and mouse identically.

**Accessibility**: label or `accessibility_name` mandatory; disabled state must differ by
opacity/desaturation, never hue only.

**Godot notes**: use `Button` (or a themed subclass), not a bare `Control`/`TextureRect`
with `gui_input`, so AccessKit gets the role for free. Connect `pressed` to a **named**
`Callable` (not a lambda) so it can be disconnected on exit. Never trigger a modal
`AcceptDialog`/OS dialog from a battle action (blocks the extension/event loop).

**Used by**: battle — Moves/Switch/Flee/Item, `‹ back`, beat tap-to-continue.

---

## PC-02 — Long-press Inspect Popover

**When to use**: reveal read-only detail for an on-screen element (move description + rider
math, break math, status effect, benched Symbot preview, initiative chip detail) **without
spending a turn or resource**.
**When NOT to use**: anything that commits state or costs a turn/Energy — inspection is
*never* a commit (battle locked decision).

**Anatomy**: trigger element (holds ≥ long-press threshold) → themed popover
(`PopupPanel` or a styled `Control` layer) with title + body; dismiss on release / tap-away.

**States**: `idle` → `pressing` (hold timer running) → `shown` (popover visible) →
`dismissed`. A press shorter than the threshold falls through to the element's tap behavior
(e.g. a move tap selects; a hold inspects).

**Accessibility**: single-finger; Mac equivalent is hover-or-hold. Popover text obeys the
13pt floor. Because it is read-only it needs no confirm and no focus trap.

**Godot notes**: detect the hold with a `Timer` started on `button_down` and cancelled on
`button_up`/`mouse_exited`; on timeout, show the popover. Prefer `Popup`-family so it
layers above the HUD without reflowing it. **Do not** use an OS/JS dialog. Popover content
is built from the pure core (e.g. `SynergyEvaluator.preview`, `compute_damage` hypothetical)
— no reimplementation of formulas in the view (ADR-0008).

**Used by**: battle — move/region/status detail, bench inspect, initiative chip inspect.

---

## PG-01 — Resource Bar (Structure / Energy)

**When to use**: a bounded current/max integer resource that changes during play and must
read at a glance (Structure, Energy).
**When NOT to use**: a resource with a danger threshold that must read *in advance* — use
the capped gauge **PG-02** (Heat). Unbounded counters — use a plain numeric label.

**Anatomy**: horizontal fill bar + **always-visible numeric** `current/max` ·
role-distinct color (Structure ≠ Energy ≠ Heat ≠ element — Art Bible owns the palette).

**States**: `full` · `partial` · `empty` (0 — e.g. Energy fully spent) · `depleted-critical`
(Structure near 0 may add a non-color emphasis, e.g. numeric emphasis, **not** hue alone).
Value changes animate (fill tween; Energy drops immediately on spend *before* move VFX,
recharge fills ~0.2s at turn start — battle V3-9).

**Accessibility**: the **numeric is the non-color channel** — the bar fill is enhancement;
the value is always legible (≥16pt). Bar contrast ≥3:1 vs. its track.

**Godot notes**: `ProgressBar` (themed) with an overlaid `Label`, or a `TextureProgressBar`;
update `value` from a subscribed signal (`structure_changed` / `energy_changed`), never
`_process`. Fill animation via `Tween` on `value`.

**Used by**: battle — player Structure, player Energy, enemy Structure.

---

## PG-02 — Capped Gauge with Threshold Warning (Heat)

**When to use**: a bounded resource where **approaching the cap is itself the signal** — the
player must read "riding the edge" *before* the consequence (Heat → Overheat).
**When NOT to use**: a resource where only current/max matters (use **PG-01**).

**Anatomy**: fill gauge + **numeric value** + **threshold markers** (⚠ at the warning
bounds) + zoned styling. Battle Heat zones (V3-7): 0–69 cool · 70–89 amber pulse ·
90–100 orange-red faster pulse; ⚠ markers at **70** and **90**.

**States**: `safe` (cool, no pulse) · `warning` (amber, subtle pulse) · `critical` (deeper
orange-red, faster pulse) · `over-cap event` (hands off to the owning screen's Overheat
beat — battle V3-8: gauge slams 0→20 two-step). Pulses obey **<3 flashes/sec** (BLOCKING).

**Accessibility**: **numeric value + ⚠ threshold marker are the non-color channel** — "on
the edge" reads without perceiving amber/orange (a11y §1.3 / battle AC-14). Pulse rate is a
hard motion gate.

**Godot notes**: themed `ProgressBar` + threshold `TextureRect` markers at the zone bounds;
zone transitions and pulse via an `AnimationPlayer`/`Tween` authored under the 3Hz ceiling.
Value from subscribed `heat_changed`.

**Used by**: battle — Heat gauge.

---

## PG-03 — Segmented Progress Pip (Break Regions)

**When to use**: discrete progress toward a state change on one of several parallel targets
(enemy break regions, each with an independent `break_hp` pool and a broken/intact state).
**When NOT to use**: a single continuous resource (use PG-01/02).

**Anatomy**: per region — a **pip/fill indicator** (`current/max`) + a **"N hits" hint** +
a **BROKEN state** rendered as a struck/greyed/labelled tile (not color alone).

**States**: `intact-full` · `intact-partial` · `broken` (icon change: cracked/struck + a
"BROKEN" label; the region leaves the target-list picker per battle AC-02) · `hidden`
(broken regions are struck in the enemy card but removed from the picker).

**Accessibility**: **fill level + "BROKEN" strike/label are the non-color channel** (a11y
§1.3 explicit example). Pip outlines ≥3:1 contrast. Break-pop VFX obeys the 3Hz gate and
carries the 100–200ms hit-stop (battle V3-11 / Part-Break).

**Godot notes**: an `HBoxContainer`/`VBoxContainer` of region rows; each row = fill
control + numeric `Label` + hint `Label`; broken state swaps a `TextureRect` (intact→cracked)
and applies a strike style from the Theme. Pools/values from subscribed break signals.

**Used by**: battle — enemy break pips.

---

## PG-04 — Status Badge with Duration (+N overflow)

**When to use**: a combatant's active status effects, each with a remaining duration, that
must read without opening a menu (Shock / Burn / Stagger).
**When NOT to use**: one-shot feedback with no persistence (use **PG-07** floating text).

**Anatomy**: badge = **status icon + status name text + duration count** · laid out in a
horizontal group · optional per-status color as *enhancement only*.

**States**: `active` (full) · `ticking` (e.g. Burn pulse ~0.25s on tick — battle V3-6) ·
`expiring` (desaturate + fade ~0.3s at turn end) · **overflow** (> visible cap): show the
N highest-priority badges + a **`+N` chip**; the full set is reachable via **PC-02**
inspect. *MVP note*: only three status types exist, so ≤3 badges is the ceiling and the
`+N` path is not MVP-reachable — documented for post-MVP status growth (battle Component
Inventory note).

**Accessibility**: **icon + name text are the non-color channel** (a11y §1.3 example — not a
color tint on the sprite). `+N` overflow indicator is text. Icon-only fallback is
prohibited — always paired with the name (or `accessibility_name`).

**Godot notes**: badge = `PanelContainer` → `HBox`( icon `TextureRect` + name `Label` +
duration `Label` ); badges in an `HBoxContainer`/`FlowContainer`; the `+N` chip is a
`Button` (opens the inspect list via PC-02). Rebuild the badge row from subscribed
status-change signals.

**Used by**: battle — player and enemy status badges.

---

## PG-05 — Affordable / Disabled Action Button

**When to use**: an action button whose availability depends on a live resource check
(move affordability vs. Energy; a move that would overheat).
**When NOT to use**: an always-available action (plain **PC-01**; e.g. Basic Attack).

**Anatomy**: extends **PC-01** with an **affordability state glyph** (● affordable /
○ disabled) + cost readout (element icon · Energy cost · status-rider badge) + an optional
**"Heat!"** flag when the move risks overheat.

**States**: `affordable` (● selectable) · `unaffordable` (○ greyed, **not selectable**,
desaturated — a11y disabled rule) · `risky` (affordable but "Heat!" flagged). Basic Attack
is always `affordable` (cost 0). Selection does not confirm — for DAMAGE moves it advances
to the target picker (**PG-06**); utility moves resolve immediately.

**Accessibility**: **● / ○ glyph + desaturation are the non-color channel** for
affordability (battle AC-05 / AC-08). "Heat!" is a text/glyph flag, not a color.

**Godot notes**: a `Button` with `disabled = (current_energy < cost)`; affordability
recomputed from live Energy on each `energy_changed` (subscribed), never polled. The ● / ○
and "Heat!" are child `TextureRect`/`Label` toggled with the disabled state.

**Used by**: battle — 4-move panel.

---

## PG-06 — Labelled Target-List Picker

**When to use**: choosing among a small set of labelled sub-targets after an action is
selected (STRUCTURE + unbroken regions for a DAMAGE move).
**When NOT to use**: binary or gesture-based selection; anything needing spatial precision
on the play field (this is a **list**, not a hit-test on the sprite).

**Anatomy**: vertical list of **labelled rows** (≥44pt each) — target name + progress
(`current/max`, "N hits") + a **pre-commit effectiveness glyph** (▲ strong / ▼ weak /
– neutral) per row.

**States**: `shown` (populated with STRUCTURE + every unbroken region; broken regions
hidden — battle AC-02) · `row-pressed` · **committed** (tap a row → resolves immediately,
**no confirm dialog** — battle locked decision AC-03). Deselect is via the move panel
`‹ back`, not a per-row cancel.

**Accessibility**: **effectiveness is glyph-first (▲/▼/–), never red/green alone** (a11y
§1.3 / battle AC-06); rows are ≥44pt with generous height to avoid mid-combat mis-taps.
The effectiveness hint is **pre-commit** — read before the tap, not confirmed after
(depends on DF exposing `type_mult` pre-commit, DF OQ-1).

**Godot notes**: `VBoxContainer` of `Button` rows (PC-01 base); each row hosts name/progress
`Label`s + an effectiveness `TextureRect`; `pressed` → `submit_action({move_id, sub_target})`
(ADR-0007 seam). No confirm step. Effectiveness computed from the pure DF core (preview),
not reimplemented.

**Used by**: battle — target list.

---

## PG-07 — Floating Feedback Text

**When to use**: transient, non-persistent result feedback that rises and fades (damage
number, "Super effective!" / "Not very effective", "Shocked!").
**When NOT to use**: persistent state (statuses use **PG-04**; history uses **PG-08**).

**Anatomy**: a short-lived text node spawned over the affected combatant · floats up
(~0.4s damage number) · fades and frees. Effectiveness tint is *enhancement*; Burn ticks
are visually distinct (amber-tinted + tick pulse — battle V3-4/V3-6).

**States**: `spawned` → `rising` → `faded/freed`. Multiple can overlap; stagger so they
don't stack illegibly.

**Accessibility**: the **text content is the signal** — effectiveness reads from the words
("Super effective!"), not the tint (a11y §4.1: no info by one channel alone; this pairs
with the PG-06 pre-commit glyph). Motion is a one-shot float, not a loop (3Hz gate N/A but
keep it brief).

**Godot notes**: pool the feedback nodes (avoid per-hit `instantiate()` churn); a `Label`
animated by a `Tween` (position + `modulate:a`), `queue_free` (or return to pool) on
completion. Spawned in response to `hit_resolved` / effectiveness signals — it is **not**
persistent view state.

**Used by**: battle — center feedback layer.

---

## PG-08 — Event Log

**When to use**: a rolling, human-readable history of recent actions the player can scan or
scroll back (last ~3 combat lines, scrollable for more).
**When NOT to use**: live single-value state (use a bar/gauge/badge).

**Anatomy**: a scrollable list showing the last N lines; each line is a **templated string**
with ordered placeholders (`"{symbot} used {move} → {region}. {effectiveness}! {damage}"`).

**States**: `default` (last ~3) · `scrolled` (history; remains readable even while action
inputs are locked during Resolving/Enemy-turn — battle AC-10). New line appends at the
resolving turn.

**Accessibility**: templated (never concatenated) so word order/grammar survive
localization (+40% expansion headroom); text ≥13–14pt. Readable during input-lock (no
commit affordance, scroll only).

**Godot notes**: `RichTextLabel` or a `VBoxContainer` of `Label`s inside a
`ScrollContainer`; lines built via `tr()` + `String.format` with named placeholders.
Appended from the subscribed combat event stream (last ~3 kept in view).

**Used by**: battle — combat log strip.

---

## PG-09 — Ordered Initiative Ribbon with Active-Turn Marker

**When to use**: showing turn order for a bounded set of combatants when order can change
mid-battle and the change must be legible (initiative by `effective_mobility`; Shock can
flip it).
**When NOT to use**: fixed/implicit order that never changes (no display needed).

**Anatomy**: an ordered row of **initiative chips** (portrait/name + side tint), left→right
= next to act, with an **active-turn marker** (`▶` caret + highlight). Ordered by
`effective_mobility` (TBC-F1).

**States**: `default` (ordered, active marked) · `turn hand-off` (marker advances to the
next combatant) · **`reorder (Shock)`** — *initiative is fixed within a round and recomputed
only at `ROUND_START` (TBC Rule 3)*; a mid-round Shock animates the affected chip to its
**projected next-round** slot (element-colored flash + Shock glyph + slide) and **commits**
at the next round start — never mid-round (battle AC-17) · `turn-skip` (Overheat greys/
bypasses the chip — V3-8) · `removed` (DOWNED combatant leaves the ribbon). MVP ribbon is
typically 2 chips (1 active player Symbot + 1 enemy).

**Accessibility**: **`▶` caret + highlight are the non-color active marker** (not side-tint
alone); a Shock reorder pairs its element-colored flash with a **Shock glyph + slide
motion**, so the reorder reads without color perception (battle Accessibility bullet). Chip
labels ≥13pt; long-press inspect target ≥44pt (PC-02).

**Godot notes**: `HBoxContainer` of chip `Control`s reordered by `effective_mobility`;
reorder animated with a `Tween` on child positions (author the flash under 3Hz). Order
committed on the `ROUND_START` signal; a pending-Shock projection updates the display on
status apply/expire without re-committing the current round. Long-press → PC-02 inspect
(name, current `effective_mobility`, active Shock magnitude). Display-only otherwise —
never a commit target.

**Used by**: battle — turn-order ribbon.

---

## Animation Standards

Timings extracted from `battle.md` / TBC GDD V2–V3; all pulses obey **<3 flashes/sec**
(a11y §1.4, BLOCKING). Screen-shake is reserved for Overheat + DOWNED, <0.3s.

| Motion | Timing / behaviour | Owning pattern | Source |
|---|---|---|---|
| Bar fill change | Tween to new value; Energy drops on spend, recharge fill ~0.2s | PG-01 | V3-9 |
| Heat zone pulse | subtle (70–89) → faster (90–100), under 3Hz | PG-02 | V3-7 |
| Break pop | break-pop VFX + **100–200ms hit-stop** | PG-03 | V3-11 |
| Status apply flash | ≤0.5s, ~0.2s after the hit VFX (cause→effect) | PG-04 | V2 / V3-5 |
| Status tick / expire | Burn tick pulse ~0.25s; expire desaturate+fade ~0.3s | PG-04 | V3-6 |
| Floating damage | float up ~0.4s, then fade+free | PG-07 | V3-4 |
| Move panel | slide-in / slide-out | PC-01/PG-05 | battle |
| Initiative reorder | chip flash + slide to projected slot; commit at ROUND_START | PG-09 | V3-2 / Rule 3 |
| Overheat beat | 0.6–1.0s: steam flash, gauge 0→20 two-step, screen-shake <0.3s | PG-02 | V3-8 |
| Screen enter | wipe ~0.3–0.5s → reveal → cards slide in | (screen) | battle |

---

## Sound Standards

Audio specifics are owned by **audio-director** / TBC GDD **V4** (not yet detailed here).
The binding cross-cutting rule this library enforces now:

- **No game-critical information is audio-only** (a11y §4.1, BLOCKING). Every audio-cued
  event a pattern represents (break confirm, status apply, overheat, victory/defeat) has a
  **visual equivalent in its pattern above** — verified with the device muted.

| Event | Visual channel (this doc) | Audio | Status |
|---|---|---|---|
| Damage / effectiveness | PG-07 floating text + tint | element hit SFX | audio TBD (V4) |
| Status applied | PG-04 badge + apply flash | status SFX | audio TBD (V4) |
| Region break | PG-03 broken state + hit-stop | break SFX | audio TBD (V4) |
| Overheat | PG-02 over-cap beat + steam | overheat SFX | audio TBD (V4) |
| Victory / Defeat | (screen results / defeat) | outcome stinger | audio TBD (V4) |

*Populate the Audio column when audio-director details the combat SFX palette (V4).*

---

## Consistency Rules (no conflicting behaviors)

- **Commit vs. inspect**: a **tap** commits/selects (PC-01, PG-05, PG-06); a **long-press**
  inspects read-only (PC-02). This split is uniform — inspection never costs a turn/resource
  anywhere.
- **Back / deselect**: deselection is via an explicit `‹ back` affordance (PC-01), not a
  per-item cancel; "Back" sits consistently in the same position across screens (a11y §3.2).
- **No-confirm commits**: within battle, target selection commits with **no confirm dialog**
  (locked decision). Destructive, irreversible actions elsewhere (scrap/upgrade/disassemble)
  **do** require a confirm step (a11y §2.4) — a future modal/dialog standard control; the
  two rules do not conflict because they apply to different action classes (reversible turn
  choice vs. permanent inventory change).
- **Color-never-sole**: every pattern names its non-color channel; no pattern relies on hue.

---

## Open Questions / Change Log

- **2026-07-15** — Seeded from `battle.md`: PC-01, PC-02, PG-01…PG-09. Animation Standards
  populated from battle/TBC V2–V3; Sound Standards structured with audio deferred to V4.
- **DF OQ-1** — PG-06's pre-commit effectiveness glyph depends on Damage Formula exposing
  `type_mult` before commit; erratum pending on `damage-formula.md`.
- **Deferred standard controls** — toggle/slider/dropdown/modal/dialog/toast/tooltip/input/
  tab/grid/scroll are added on first use (likely Workshop / Inventory / Settings). The
  modal/dialog entry must encode the a11y §2.4 destructive-confirm behavior when authored.
- **Calibration gate** — all ≥44pt / ≥16pt figures assume the virtual-px→pt on-device
  calibration (a11y Decision 5); verify in the first UI story before pattern audits.
