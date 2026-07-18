# Battle Screen — Visual Design Spec

> **Status**: Approved — visual design (Phase 2 of `/team-ui battle`), 2026-07-18
> **Author**: art-director
> **Source documents**:
>   - `design/ux/battle.md` (approved UX spec)
>   - `design/art/art-bible.md` (authority: palette, shape, typography, animation)
>   - `design/ux/interaction-patterns.md` (PG-01…PG-09, PC-01/02)
>   - `design/accessibility-requirements.md` (GAG Basic + WCAG 2.1 AA subset)
> **Last Updated**: 2026-07-18
> **Scope**: Visual treatment only — behavior and layout are owned by `battle.md`.

---

## 1. Visual Identity for This Screen

The battle screen is the **tactical cockpit** of Symbots. Its visual job is singular:
make the harvest dilemma (break pip vs. Structure, Heat cost vs. reward) legible in
under a second at every turn. Art-bible §2.2 is the mood authority: focused, weighted,
clinical, pressurized, deliberate. The layout zones are narrow and purposeful —
player-left / enemy-right / action-bottom — and the visual treatment narrows the
world's wide palette to the combatants + the chrome HUD. Background desaturates and
cools so the saturated Symbots and element glyphs dominate.

**Single most important visual rule for this screen**: the enemy card's break pips and
enrage indicator must be the highest-contrast non-text elements in the enemy half of
the frame at all times. If an atmospheric or VFX effect ever threatens that read, the
art-bible §2.2 yield rule applies without negotiation — legibility wins.

---

## 2. Color Application

### 2.1 Screen-Wide Tone

| Zone | Background tone | Source |
|---|---|---|
| Combat battle background (behind combatants) | Desaturated cool (W-3 Slate Gunmetal `#374350` dominant, ≈ 60% desaturation) | Art-bible §4.6 / §6.4 — combat backdrop cools so bots pop |
| Player half atmosphere | Warm key rim on player Symbot from slightly above-center | Art-bible §2.2 |
| Enemy half atmosphere | Cool rim on enemy Symbot | Art-bible §2.2 |
| HUD chrome (all panels) | C-1 HUD Dark `#1E2229` base plate | Art-bible §4.5 |

**Vignette**: a soft desaturated vignette at screen edges ensures combatants and the
HUD chrome read as the brightest objects. The vignette must not drop any UI panel
below WCAG AA contrast (art-bible §2.2 combat/atmosphere yield rule — blocking).

---

### 2.2 Resource Bars (PG-01)

**Structure bar:**

| State | Fill color | Hex | Non-color channel |
|---|---|---|---|
| Normal | Heal Green (desaturated toward a medium green) | `#3AB54A` | Numeric `current/max` (≥16pt) always visible; fill level |
| Critical (≤20%) | Danger Red | `#CC3020` | Numeric; cracked-icon indicator at critical threshold |
| Empty | Track only (C-2 Mid panel) | `#2C3340` | Numeric reads "0/max" |

Rationale: Structure is the "health" resource — the art-bible's Heal Green / Danger
Red semantic pair (§4.3) directly maps. The bar track uses C-2 so the unfilled
portion reads at ≥3:1 against the C-1 base plate. Critical threshold cracked-icon
is a `TextureRect` overlay, not a color-only signal (a11y §1.3 BLOCKING).

**Energy bar:**

| State | Fill color | Hex | Non-color channel |
|---|---|---|---|
| Normal | Info Blue `#4090CC` | C-4 | Numeric `current/max` (≥16pt); fill level |
| Empty | Track only (C-2) | `#2C3340` | Numeric reads "0/max"; all moves with E>0 go ○ greyed |

Rationale: Info Blue is the UI's "interactive/selected" semantic (art-bible §4.3)
and hue 210° — deliberately offset from Volt cyan (hue 180°) so the Energy bar never
reads as an element signal. The Volt element glyph (Lightning Fork) is always present
on Volt-element moves; the blue bar is chrome, not elemental.

**Enemy Structure bar:**

Same color assignments as player Structure bar. The shared semantic makes the tactical
read instant: "green bar = Structure, blue bar = Energy" is universal, not
player-specific. The enemy card lacks an Energy bar (enemies do not manage Energy in
the MVP combat model as exposed to the player) — only Structure appears on the enemy
card.

**Shared bar anatomy:**
- Panel: chamfered-corner rectangle (45° cuts, §3.6), C-2 fill track, element-colored
  fill.
- No rounded corners anywhere on the bar container. Chamfer is the UI's signature.
- Bar height: minimum 12px at @1x (≥3:1 contrast against C-1, a11y §1.1 UI elements).

---

### 2.3 Heat Gauge (PG-02)

The Heat gauge has three zones and is the most accessibility-critical color element
on the screen (it spans amber→orange-red, a known Deuteranopia risk).

| Zone | Range | Fill color | Hex | Pulse cadence | Non-color channel |
|---|---|---|---|---|---|
| Cool | 0–69 | C-3 Chrome Interactive (blue-slate) | `#3A4455` | None | Numeric value; no ⚠ icon |
| Amber / Warning | 70–89 | Thermal Amber | `#F0900A` | Subtle, ≤1.5 Hz | ⚠ marker appears at 70; numeric reads ≥70 |
| Orange-red / Critical | 90–100 | Danger Red | `#CC3020` | Faster, ≤2.5 Hz | Second ⚠ marker appears at 90; numeric reads ≥90; faster pulse cadence is a tempo signal independent of color |

**Deuteranopia safety analysis (RESOLVED):** Under Deuteranopia, warm hues (amber,
orange, red) collapse toward a brownish-yellow band and are poorly distinguished by
hue alone. Resolution — three independent channels stack:
1. **Luminance separation**: Zone 2 amber (`#F0900A`, relative luminance ≈ 0.31) vs.
   Zone 3 Danger Red (`#CC3020`, relative luminance ≈ 0.06) — approximately 5:1
   luminance ratio, distinguishable under all common color-vision deficiencies as a
   dark-vs.-light shift, not a hue shift.
2. **⚠ glyph**: the threshold marker is a shape signal (exclamation in a triangle,
   standard ⚠ shape) at positions 70 and 90. It appears at zone entry and persists.
   This is the primary non-color signal for "riding the edge."
3. **Pulse tempo**: Zone 3 pulses faster than Zone 2 (≤2.5 Hz vs. ≤1.5 Hz). Tempo
   difference is a time-domain signal invisible to color-vision deficiency.
4. **Numeric**: the exact numeric value (always visible, ≥16pt) gives the player the
   precise position — no inference from fill color required.

The cool zone uses C-3 blue-slate (not a warm hue), so the transition from Zone 1 to
Zone 2 is a cool-to-warm shift — perceptible under Deuteranopia as a luminance and
saturation shift (blue-grey to a brighter warm), not hue alone.

All pulses obey the **<3 Hz BLOCKING gate** (a11y §1.4, battle AC-15). Author the
AnimationPlayer with explicit frame counts: at 60 fps, ≤1.5 Hz = period ≥40 frames;
≤2.5 Hz = period ≥24 frames.

**Overheat beat** (Heat hits 100, V3-8): the gauge slams 0→20 in two steps, accompanied
by the steam VFX and a screen-shake <0.3s. The gauge fill briefly flashes white
(high-value monochrome flash, art-bible §2.3 — white core, element-tinted edge pattern
adapted to the Heat event). The white flash is a single event flash (not a loop) so
the 3 Hz gate does not apply; it must complete within 0.6–1.0s total overheat beat
duration (battle.md V3-8). Danger Red fill is the post-reset visual, not the flash
itself.

**⚠ marker geometry**: a flat chamfered badge (matching UI vocabulary, §3.6) containing
the ⚠ glyph in C-6 UI White `#E8E8E8`. It sits at the zone boundary on the gauge
track, not floating above it, so it does not crowd the numeric.

---

### 2.4 Break Pips (PG-03)

Break pips are the most read-critical element on the enemy card. They must survive
the highest-urgency read (the harvest dilemma) in under a second.

| State | Fill | Border | Label | Non-color channel |
|---|---|---|---|---|
| Intact — full | Element-tinted fill (see below) | C-5 Divider `#4B5668`, 1px | Numeric `cur/max` + "N hits" | Fill level; numeric; "N hits" hint |
| Intact — partial | Partial element-tinted fill | C-5, 1px | Numeric `cur/max` + "N hits" | Fill level decrease is the signal |
| Broken | No fill; C-2 track | C-5, 1px with strike overlay | "BROKEN" label in C-7 `#98A4B4` + cracked-tile icon | "BROKEN" text + cracked icon; strike overlay on the pip container; region exits target list |

**Pip geometry**: rectilinear chamfered tiles, never circular (art-bible §3.6 — circles
read too close to bot sensor/joint shapes). Each pip tile: approximately 48×24px @1x
(landscape orientation; wider than tall to suit the horizontal readout, and ≥3:1
contrast for the pip outline against C-1).

**Element tint on break pips**: the fill color mirrors the enemy's element color at
~40% opacity over a C-2 track. This keeps the element color association consistent
(element = color + glyph) without over-saturating a small pip. The element glyph is
**not** repeated on each pip (that would clutter a small area); it appears once on the
enemy card's element badge. The pip tint is *enhancement* — the numeric and fill level
carry the signal.

**Enrage indicator** (break region count escalates TBC-F7): a persistent text badge
"+12% / +24% / +36%" with a `[!]` icon in Danger Red `#CC3020` on a C-1 plate. The
rim light warms toward W-6 Harvest Crimson `#B33020` on the enemy Symbot model (art-
bible §4.6 enrage rule — temperature cue, not element-color change). Non-color channel:
the `[!]` icon, the numeric percentage, and the "ENRAGE" or "ANGRIER" text label. Color
is reinforcement.

---

### 2.5 Status Badges (PG-04)

All three MVP statuses (Shock / Burn / Stagger) render as a badge: element glyph +
status name text + duration count. Color is enhancement only; the glyph + name are the
non-color primary signal.

| Status | Badge tint | Element glyph | Non-color primary |
|---|---|---|---|
| Shock | Volt Cyan `#2FE8E8` tint on badge background | Lightning Fork (⚡) | "Shock" text + Lightning Fork glyph |
| Burn | Thermal Amber `#F0900A` tint on badge background | Flame Chevron (🔥 flat/outlined) | "Burn" text + Flame Chevron glyph |
| Stagger | C-7 Secondary text tone `#98A4B4` (Kinetic Silver-adjacent) | Impact Ring (◎) | "Stagger" text + Impact Ring glyph |

Badge anatomy: chamfered-corner container, C-2 base plate, tinted at ~25% element
color overlay. Glyph at left, status name label in C-6, duration count in C-7.

**Stagger note**: Kinetic element is silver-shift `#D8DDE6`, very close to UI White.
The badge does not use the full silver-shift as a fill — it uses the neutral C-7
secondary tone, which is visually distinct from the other two badges' warm and cyan
tints. The Impact Ring glyph is the definitive Kinetic/Stagger identifier, per
art-bible §4.2's three-layer Kinetic disambiguation. The badge always renders on a C-1
dark plate, giving the Impact Ring glyph ≈7.5:1 contrast (art-bible §4.5 element badge
spec).

**Burn tick pulse (status active, ~0.25s)**: the badge flashes Thermal Amber at
full opacity briefly, then returns to 25% tint. Single pulse, not a loop — 3 Hz gate
does not apply to single-event flashes, but keep the tick interval at the GDD-defined
once-per-turn timing (not a per-frame loop).

**Duration count**: C-7 `#98A4B4` (4.9:1 on C-1), minimum 13pt per accessibility
floor. Counts down; at "1" remaining, the count pulses a single dim flash to signal
expiry.

---

### 2.6 4-Move Panel — Affordability States (PG-05)

| State | Button surface | Text color | Glyph | Extra flag |
|---|---|---|---|---|
| Affordable (●) | C-3 Interactive `#3A4455` | C-6 `#E8E8E8` | ● filled circle, C-4 Info Blue | — |
| Unaffordable (○) | C-2 `#2C3340` | C-7 `#98A4B4` at 60% opacity | ○ hollow circle, C-5 `#4B5668` | Desaturated; Energy cost shown in C-7 |
| Risky / Heat! | C-3 with a thin amber border `#F0900A` | C-6 | ● Affordable | "Heat!" text label in Thermal Amber; not color alone — the text "Heat!" is mandatory |
| Basic Attack (always affordable) | C-3 | C-6 | ● | No energy cost shown (free) |

**Element icon** on each move: the element glyph (Lightning Fork / Flame Chevron /
Impact Ring) in its element color appears left of the move name, always on a C-1
sub-plate in the button. Energy cost label: "E{N}" in C-7. Status-rider badge: uses
PG-04 badge anatomy at reduced size (~80%).

**Move name text**: C-6, ≥16pt, left-aligned. Move name truncates with "…" if the
string exceeds the panel width (localization +40% headroom — battle.md Localization §).

**Button geometry**: chamfered corners, full-width in the panel, minimum 44×44pt tap
target per a11y §2.1.

---

### 2.7 Target List — Effectiveness Glyphs (PG-06)

Each target row carries a pre-commit effectiveness glyph (▲ / ▼ / –) at the right
edge of the row.

| Effectiveness | Glyph | Color | Non-color channel |
|---|---|---|---|
| Super effective (×1.5) | ▲ (filled upward triangle) | Heal Green `#3AB54A` | ▲ shape + "Super effective!" text in floating feedback |
| Neutral (×1.0) | – (em dash or horizontal bar) | C-7 Secondary `#98A4B4` | – shape |
| Resisted (×0.75) | ▼ (filled downward triangle) | Danger Red `#CC3020` | ▼ shape |

The glyph carries the meaning; color reinforces it (art-bible §4.5 effectiveness
indicator spec). The glyph is placed at ≥24×24px @1x — large enough to read at
combat thumb-scroll speed.

Target row anatomy: C-3 Interactive surface, chamfered, minimum 44pt height. Target
name in C-6 ≥16pt left; break progress `cur/max` in C-7 ≥14pt center; "N hits" hint
in C-7 13pt; effectiveness glyph right-aligned.

Broken regions are removed from this list (battle.md AC-02); they appear as struck
tiles on the enemy card only.

---

### 2.8 Turn-Order Ribbon (PG-09)

Each initiative chip: chamfered container, C-2 base, portrait/name label.

| Element | Styling | Non-color channel |
|---|---|---|
| Chip base | C-2 Mid panel | — |
| Side tint (player) | Subtle left-border in Info Blue C-4 `#4090CC`, 2px | Left-border position (player is always left) |
| Side tint (enemy) | Subtle left-border in Danger Red `#CC3020`, 2px | Right-side label "Enemy" or enemy name |
| Active-turn marker | ▶ caret glyph in C-6, + C-3 background highlight on active chip | ▶ caret is the shape signal; highlight is brightness |
| Overheat turn-skip | Chip desaturated to C-7 opacity ~50% | "SKIP" text label on the chip |
| Downed combatant | Chip removed from ribbon | Absence is the signal; combat log reports the down |

**Shock reorder flash**: the displaced chip flashes to Volt Cyan `#2FE8E8` for one
pulse (~0.3s), simultaneously showing the Shock glyph (Lightning Fork) on the chip and
sliding to its projected next-round slot. The flash is a single event, not a loop — 3
Hz gate satisfied. Non-color: the glyph + the slide animation (position change) carry
the reorder read without color perception.

Chip size: minimum 44×44pt tap target for long-press inspect (PC-02). Name label
≥13pt (accessibility floor for dense HUD text, art-bible §7.3 / a11y §1.2).

---

### 2.9 Floating Feedback Text (PG-07)

| Content | Color | Size | Non-color channel |
|---|---|---|---|
| Damage number | C-6 UI White `#E8E8E8` (base); element-tinted slight overlay | ≥20pt, bold — slightly larger than body so it reads over the background | The number itself is the signal |
| "Super effective!" | Heal Green `#3AB54A` | ≥18pt | Text content |
| "Not very effective" | Danger Red `#CC3020` at 80% saturation | ≥16pt | Text content |
| "Shocked!" / "Burned!" / "Staggered!" | Element color of the status (Volt Cyan / Thermal Amber / C-7 near-neutral) | ≥16pt | Text content; element-color is enhancement |
| Burn DoT tick | Thermal Amber tint | ≥16pt | "(Burn)" label suffix |
| CRITICAL hit (if applicable) | C-6 with gold glyph border | ≥20pt bold + star mark | "CRITICAL!" text |

All feedback text floats upward ~0.4s and fades — single-shot motion, not looping.
Multiple simultaneous feedback nodes stagger horizontally to avoid overlap (offset by
~8px per subsequent node in the same frame window).

---

### 2.10 Combat Log (PG-08)

| Element | Value |
|---|---|
| Text color | C-7 Secondary `#98A4B4` for log lines (4.9:1 on C-1) |
| Active/latest line | C-6 Primary `#E8E8E8` (13.5:1) to give the most recent action a slight pop |
| Font size | ≥14pt (secondary role, dense strip — at the accessibility secondary floor) |
| Panel | C-1 base plate, low-opacity (85%) so the background world tint shows faintly |
| Scrollable | Yes; scroll indicator in C-5 `#4B5668` |

The combat log panel uses the standard chamfered-corner treatment. It sits at the
bottom strip of the layout. During `Resolving` / `Enemy turn` (inputs locked), the
log remains scrollable per battle.md AC-10.

---

### 2.11 Action Cluster (PC-01)

The four primary action buttons (Moves / Switch / Flee / Item).

| Button | Normal surface | Disabled surface | Label | Non-color disabled channel |
|---|---|---|---|---|
| Moves | C-3 Interactive | — (always active when action is pending) | "MOVES" + ▶ glyph | — |
| Switch | C-3 Interactive | C-2 at 60% opacity | "SWITCH ⇄" | Desaturation + opacity |
| Flee | C-3 Interactive | C-2 at 60% opacity, "BOSS" label | "FLEE ⚑" | Desaturation + opacity + "BOSS" text (not color alone) |
| Item | C-3 Interactive | C-2 at 60% opacity, "No items" label | "ITEM ✚" | Desaturation + opacity + label text |

All buttons: chamfered, minimum 44×44pt, full label text (not icon-only — AccessKit
and a11y §5 door-open discipline). Icon glyphs are leading adornments that carry the
`accessibility_name` per a11y §5.

`‹ back` in the move panel: C-3 surface, "‹ BACK" label in C-6, minimum 44×44pt.
Positioned at the bottom of the 4-move panel, consistent with the back-affordance
positioning rule (a11y §3.2 / interaction-patterns Consistency Rules).

---

## 3. Typography

All type uses the project's **technical/engineered sans-serif** (art-bible §7.3) —
clean, high-legibility, mechanical personality. No humanist warmth. Type is styled
by weight and size, never by hue (hue is reserved for semantics, §4.3).

| Role | Art-bible type role | Size | Weight | Color | Notes |
|---|---|---|---|---|---|
| Screen / card titles ("PLAYER", "ENEMY", "MOVES") | Secondary heading | ≥14pt, bold | Semi-bold | C-7 `#98A4B4` | Labels, not emphasis — recede slightly |
| Combatant names (player Symbot / enemy name) | Body heading | ≥16pt, bold | Bold | C-6 `#E8E8E8` | Primary identity, top of each card |
| Level display ("L12", "L14") | Secondary label | ≥14pt | Regular | C-7 | Smaller than name, visually subordinate |
| Resource numerics (STR 84/120, EN 40/60, HEAT 78) | Stat value | ≥16pt | Medium | C-6 | Always visible; numeric = non-color channel |
| Move names | Body | ≥16pt | Medium | C-6 (affordable) / C-7 at 60% (unaffordable) | Truncate + "…" at panel edge |
| Energy cost ("E12", "E40") | Secondary label | ≥14pt | Regular | C-7 | Next to element glyph |
| "Heat!" flag | Semantic label | ≥14pt | Bold | Thermal Amber `#F0900A` | Always text, never color alone |
| Damage numbers (floating feedback) | Display / impact | ≥20pt | Bold | C-6 + element tint overlay | Largest text on screen during resolution |
| "Super effective!" / "Not very effective" | Feedback | ≥18pt | Semi-bold | Heal Green / Danger Red | Text content carries meaning |
| Break region name (target list) | Body | ≥16pt | Medium | C-6 | Left-aligned in target row |
| Break region progress (`cur/max`, "N hits") | Secondary | ≥14pt | Regular | C-7 | Center of target row |
| Status badge name ("Shock", "Burn", "Stagger") | Secondary | ≥14pt | Medium | C-6 | Next to element glyph in badge |
| Status badge duration ("2", "1") | Secondary | ≥14pt | Regular | C-7 | Right of name |
| Enrage percentage ("+24%") | Semantic label | ≥16pt | Bold | Danger Red `#CC3020` | High visibility; paired with [!] icon |
| Combat log lines | Log / secondary | ≥14pt | Regular | C-7 (history) / C-6 (latest) | Dense strip; at secondary floor |
| Turn-order chip name | Chip label | ≥13pt | Regular | C-6 | Dense ribbon; at absolute floor |
| ⚠ threshold label | Threshold marker | ≥13pt | Regular | C-6 | On gauge, at zone boundary |

**Large-text toggle (+4pt, art-bible §7.3 / a11y §1.2)**: all roles scale uniformly.
At +4pt the damage number reaches ≥24pt, which may require the floating feedback
stagger offset to increase to ~12px. The HUD card widths must be tested with
+4pt-size move names to confirm no truncation is introduced for typical move name
lengths.

---

## 4. Spacing and Layout Polish

### 4.1 Safe Zones and Margins

Landscape layout. iOS safe-area insets apply on all four sides (battle.md AC-19).
All interactive elements and all legibility-critical UI must fall inside the safe area.

| Region | Margin from safe-area edge | Notes |
|---|---|---|
| Player card (top-left) | 12px top, 12px left | Flush to safe area edge, not the screen edge |
| Enemy card (top-right) | 12px top, 12px right | Mirror of player card |
| Turn-order ribbon (top-center) | 12px top; left/right 8px from each card's inner edge | Centered between the two cards |
| Action cluster (bottom-left) | 16px bottom, 12px left | Lower thumb zone — generous bottom margin for iOS home indicator |
| Target list (bottom-right) | 16px bottom, 12px right | Mirror of action cluster |
| Combat log strip | 4px above action cluster top edge; full width minus card margins | Sits as a narrow strip |
| Center feedback layer | No margin — floats above all; clipped to screen bounds | Floating nodes must not overlap the ribbon |

### 4.2 Card Internal Spacing

Internal card spacing uses an 8px base grid with 4px increments.

| Element within card | Spacing |
|---|---|
| Card padding (inner) | 8px all sides |
| Between combatant name and level | 4px horizontal |
| Between resource bars (STR → EN → HEAT) | 6px vertical |
| Between Heat gauge and status badges | 8px vertical |
| Between status badges | 4px horizontal |
| Between break pip rows | 6px vertical |
| Between enrage indicator and break pips | 8px vertical |
| Bench portrait row below player card content | 8px top margin; portraits 4px apart |

### 4.3 Visual Hierarchy — Primary Read

The eye should land in this sequence: enemy break pips → enrage indicator → player
Heat gauge → my available moves (affordability). This is enforced by:

1. **Enemy break pips**: rendered in the **widest element on the enemy card**, with
   the highest contrast fill relative to C-1 background. Break pips receive the
   `contrast-ring` outline-pulse on turn start to draw the eye (art-bible §2.2 /
   §3.7 Level 2 — luminosity cue, shape+brightness).
2. **Heat gauge**: positioned as the third bar in the player stack, but with the ⚠
   marker glyph ensuring the eye is pulled to it when thresholds are active.
3. **Move panel**: high-contrast C-3 surface against the lower-contrast C-1 background;
   the ● / ○ affordability glyphs cluster as a read-at-a-glance affordability summary.
4. **Turn-order ribbon**: low visual weight in idle state (C-2 chips, C-7 names) —
   rises only when the active-turn ▶ marker and Shock-reorder animations fire.

### 4.4 Panel Geometry (All Panels)

All panels — player card, enemy card, action cluster, target list, 4-move panel,
combat log — use:
- Straight edges, **45° chamfered corners** (art-bible §3.6 / §7.1)
- No rounded corners anywhere on the HUD chrome
- C-1 `#1E2229` base plate
- C-5 `#4B5668` chamfer/divider lines at 1px
- No drop shadow or box-glow on panels (would compete with rarity glow on Symbot parts)

The chamfer is the visual signature of "this is a UI element, not a Symbot part"
(Gestalt similarity — curves = content, hard edges = chrome, art-bible §3.6).

---

## 5. Animation Style

All motion is **crisp, mechanical, snappy** — chrome animates like a machine actuating
(quick ease-out, decisive settle), never organic overshoot (art-bible §7.4). The
bots' in-battle animations carry the organic/creature energy; the HUD chrome is
always precise and immediate.

### 5.1 Bar Fill Animations (PG-01)

| Animation | Timing | Easing |
|---|---|---|
| Structure bar damage | Tween to new value, ~0.25s | Ease-out (fast drop, settles) |
| Energy bar spend (before move VFX) | Immediate step-drop, ~0.05s | Linear/instant |
| Energy recharge at turn start | Fill ~0.2s | Ease-in-out (mechanical refill) |
| Enemy Structure bar damage | Same as player Structure timing | — |

The bar drop precedes the move VFX on Energy spend (battle.md V3-9 — confirms spend
before the visual "uses" it). Structure damage is concurrent with or just after the
hit VFX.

### 5.2 Heat Gauge (PG-02)

| Animation | Timing / constraint |
|---|---|
| Zone 2 pulse (70–89) | Amplitude-modulated opacity pulse: ≤1.5 Hz (period ≥40 frames at 60 fps), 80→100% gauge fill opacity |
| Zone 3 pulse (90–100) | ≤2.5 Hz (period ≥24 frames), 75→100% opacity — faster cadence, not a hue strobe |
| ⚠ marker appear at 70 / 90 | Instant on threshold cross; no animation needed (the threshold is the event) |
| Overheat: gauge slam 0→20 | Two-step: 100→0 (instant), then 0→20 fill (~0.15s ease-out) — within the 0.6–1.0s overheat beat window |

Pulses are **amplitude-modulated opacity cycles** (never a hard on/off strobe). The
gauge fill's opacity oscillates; the gauge shape and numeric never disappear. This is
the art-bible §4.4 "amplitude-modulated, not a hard on/off strobe" rule applied to Heat.

### 5.3 Break Pop and Hit-Stop (PG-03)

| Animation | Timing |
|---|---|
| Break-pop VFX | High-value monochrome flash at the break point — 3–5 frame blaze (at 60 fps: 50–83ms) dropping back to combat baseline; element-tinted edge on flash (art-bible §2.3) |
| Hit-stop | 100–200ms freeze on all in-scene motion (not just the affected part) — the brief freeze is the "earned and spectacular" beat |
| Broken pip tile update | Simultaneous with hit-stop end — cracked tile replaces intact tile + "BROKEN" label appears |
| Beat pause | Player tap-to-continue holds after the break-pop (battle.md Turn pacing) |

The break-pop flash is a **located flash at the break point**, not screen-wide bloom
(art-bible §2.3). It reads as a single event, not a loop — 3 Hz gate satisfied.

### 5.4 Status Badge Animations (PG-04)

| Animation | Timing |
|---|---|
| Badge apply | Slide-in from offscreen (matches status apply flash ≤0.5s, ~0.2s after hit VFX — V3-5) |
| Burn tick pulse | Single-beat opacity flash ~0.25s on the Burn badge; once per turn, not looping per frame |
| Badge expire | Desaturate + fade ~0.3s |
| Shock reorder chip flash | Single pulse Volt Cyan ~0.3s + slide motion to projected slot |

### 5.5 Move Panel Transitions

| Animation | Timing | Easing |
|---|---|---|
| Move panel slide-in (tap Moves) | ~0.15s | Ease-out — decisive, mechanical |
| Move panel slide-out (tap ‹ back) | ~0.12s | Ease-in — snappy dismiss |
| Target list populate | Simultaneous with panel slide-in for DAMAGE moves | Instant fill (no stagger animation needed — the list is short) |

### 5.6 Overheat Beat (V3-8)

The full 0.6–1.0s Overheat beat sequence:
1. **0ms**: Steam VFX spawns over player Symbot (located VFX, not screen-wide).
2. **0–50ms**: Screen-shake ≤0.3s total, reserved for this and DOWNED only.
3. **50ms**: Heat gauge does instant slam 100→0, then fills 0→20 (~0.15s).
4. **100ms**: Self-damage number floats up from Heat gauge position (floating feedback,
   PG-07 — color C-6 with Danger Red tint, labeled "(Overheat)").
5. **~300ms**: The turn-skip chip in the initiative ribbon greys and shows "SKIP".
6. **600–1000ms**: Beat pause — player tap-to-continue.

Screen-shake is a **position-offset shake** (translate the scene root, not the camera
— matches 2D CanvasItem rendering), ≤4px amplitude, ≤0.3s, diminishing.

### 5.7 Initiative Ribbon Transitions (PG-09)

| Animation | Timing |
|---|---|
| Turn hand-off (▶ marker advances) | ▶ glyph + background highlight steps to next chip; ~0.1s |
| Active chip highlight | C-3 background on active chip (vs. C-2 on idle chips) — no animation needed, instant |
| Shock reorder | Chip flash (single pulse Volt Cyan ~0.3s) + Shock glyph appears on chip + slide to projected slot (~0.25s ease-out) |
| Downed combatant removal | Chip fades out (~0.3s) and siblings slide to close the gap (~0.2s) |

### 5.8 Screen Enter / Exit

| Transition | Timing |
|---|---|
| Enter: Overworld → Battle | Wipe/flash ~0.3–0.5s → enemy reveal (enemy card slides in from right) → player card slides in from left → ribbon appears → `ACTION_PENDING` unlocks inputs |
| Exit: Victory | Freeze → results overlay fade-in (~0.5s) → dismiss → resume Overworld (fade back ~0.3s) |
| Exit: Defeat | DOWNED screen-shake (<0.3s) → defeat card fades in (~0.4s cool-desaturated tone per art-bible §2.5) |
| Exit: Fled | Quick fade to Overworld (~0.3s) |

The battle-enter wipe budget is ≤0.5s to `ACTION_PENDING` (battle.md AC-18). Card
slide-ins must complete within this budget — ~0.2s slides fit comfortably.

---

## 6. Asset Manifest

All asset names follow the project convention: `[category]_[name]_[variant]_[size].[ext]`.

### 6.1 Icons / Glyphs

| Asset | Dimensions @1x | @2x / @3x | Format | Component(s) |
|---|---|---|---|---|
| `icon_element_volt.png` | 24×24px | 48×48 / 72×72 | PNG, alpha | Element badge, move panel, status badge, ribbon chip |
| `icon_element_thermal.png` | 24×24px | 48×48 / 72×72 | PNG, alpha | Same as above |
| `icon_element_kinetic.png` | 24×24px | 48×48 / 72×72 | PNG, alpha | Same as above |
| `icon_status_shock.png` | 24×24px | 48×48 / 72×72 | PNG, alpha | Status badge (PG-04) |
| `icon_status_burn.png` | 24×24px | 48×48 / 72×72 | PNG, alpha | Status badge (PG-04) |
| `icon_status_stagger.png` | 24×24px | 48×48 / 72×72 | PNG, alpha | Status badge (PG-04) |
| `ui_glyph_effectiveness_super.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Target list (PG-06) effectiveness ▲ |
| `ui_glyph_effectiveness_weak.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Target list ▼ |
| `ui_glyph_effectiveness_neutral.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Target list – |
| `ui_glyph_affordable.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | 4-move panel ● affordable |
| `ui_glyph_unaffordable.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | 4-move panel ○ unaffordable |
| `ui_glyph_heat_warning.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | ⚠ threshold marker on Heat gauge (both positions) |
| `ui_glyph_enrage.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | [!] enrage icon on enemy card |
| `ui_glyph_active_turn.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | ▶ active-turn caret on initiative ribbon (PG-09) |
| `ui_glyph_skip.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Overheat turn-skip on ribbon chip |
| `ui_glyph_rarity_common.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Part icon rarity tier; not on battle HUD directly — bench portrait only |
| `ui_glyph_rarity_rare.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Same |
| `ui_glyph_rarity_boss.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Same |
| `ui_glyph_rarity_proto.png` | 16×16px | 32×32 / 48×48 | PNG, alpha | Same |

### 6.2 Break Pip Tiles

| Asset | Dimensions @1x | @2x / @3x | Format | Component |
|---|---|---|---|---|
| `ui_pip_intact_full.png` | 48×24px | 96×48 / 144×72 | PNG, alpha | PG-03 break pip — intact state fill tile |
| `ui_pip_intact_partial.png` | 48×24px (scalable fill) | same | PNG, alpha | PG-03 partial fill — actually implemented as a ProgressBar, not a static image; the tile defines the track shape |
| `ui_pip_broken.png` | 48×24px | 96×48 / 144×72 | PNG, alpha | PG-03 broken state — cracked tile overlay |
| `ui_pip_track.png` | 48×24px | 96×48 / 144×72 | PNG, alpha | PG-03 pip track background (C-2) |

Note: break pips are rectilinear chamfered tiles (art-bible §3.6 — never circular).

### 6.3 UI Panel / Decorative Elements

| Asset | Dimensions @1x | @2x / @3x | Format | Notes |
|---|---|---|---|---|
| `ui_panel_chamfer_corner.png` | 8×8px (corner tile) | 16×16 / 24×24 | PNG, alpha | Ninepatch corner for chamfered panel containers — enables scalable chamfered panels without per-size variants |
| `ui_divider_horizontal.png` | 1×2px | 1×4 / 1×6 | PNG | C-5 divider line; tileable |
| `ui_badge_element_plate.png` | 32×20px | 64×40 / 96×60 | PNG, alpha | Element badge background plate (C-1 dark with chamfer) — used in enemy card element badge |

### 6.4 VFX Textures (Authored by Art Director, Implemented by Technical Artist)

The following VFX are specified here for the technical-artist handoff. Art direction
below; implementation is delegated.

| VFX | Description | Size @1x | Notes |
|---|---|---|---|
| `vfx_break_flash_loop_small.png` (spritesheet) | Located flash at break point: 3–5 frame white-core, element-tinted edge blaze; drops to transparent. Spritesheet, one row. | 64×64px per frame, 5 frames | Must play as single-shot, not looped; art-bible §2.3 break flash spec |
| `vfx_overheat_steam_loop_small.png` (spritesheet) | Steam VFX over player Symbot on overheat; 6–8 frames, looping briefly then stopping | 96×96px per frame, 8 frames | Located over bot model; stops after beat; not screen-wide |
| `vfx_hit_impact_loop_small.png` (spritesheet) | Standard hit feedback — element-tinted brief spark; 4 frames | 48×48px per frame, 4 frames | Used on every damage resolution; element tint applied via shader parameter, one asset for all three elements |
| `vfx_enrage_rimlight_overlay.png` | Warm W-6 Harvest Crimson `#B33020` rim-light gradient overlay for enemy model at enrage escalation | 256×256px | Additive overlay on enemy model sprite; opacity scales with enrage tier (0% → 20% → 40% → 60%) |

### 6.5 Fonts

No new fonts specified — the project font (technical/engineered sans-serif, art-bible
§7.3) applies uniformly. The visual design spec does not specify a typeface (that is
a project-level asset pipeline decision); it specifies **roles, sizes, weights, and
colors** per §3 above.

The font must be:
- A geometric sans-serif with consistent stroke weights (mechanical feel)
- Highly legible at 13–14pt on a dark plate (the minimum use case in this spec)
- Include Regular, Medium, Semi-Bold, and Bold weights
- Licensed for game distribution on Mac and iOS

Recommendation to flag to the technical-artist: verify that the selected font atlas
is included in the shared Theme (`assets/ui/theme.tres`) and that each weight is a
distinct entry, not synthesized by Godot's bold emulation (which degrades quality).

### 6.6 Shared Assets (Cross-Screen Consistency)

The following battle screen assets are shared with `hud.md` and `pause.md` (which use
PG-01/PG-08/PG-09) and must be styled identically across all three screens. If any
of these are modified for battle, the change must propagate to hud.md and pause.md:

| Shared asset | Used by | What must stay identical |
|---|---|---|
| `ui_panel_chamfer_corner.png` | battle, hud, pause | Panel shape and geometry |
| `icon_element_volt/thermal/kinetic.png` | battle, hud, pause (any screen showing element identity) | Glyph design, colors |
| `icon_status_shock/burn/stagger.png` | battle, hud | Badge glyph and anatomy |
| `ui_glyph_active_turn.png` | battle, hud (if hud shows turn order) | ▶ shape |
| Chrome palette (C-1…C-7) | All screens | All hex values locked; no per-screen deviations |
| Typography roles | All screens | Same font, same size minimums, same color roles |

The shared Theme (`assets/ui/theme.tres`) is the enforcement mechanism — these
assets are not screen-local. Any battle-visual PR that introduces a per-screen
override of a shared element must be flagged and reviewed before merge.

---

## 7. Accessibility Verification Checklist

Per-element summary of the non-color channels committed in this spec. An art
reviewer must confirm every row before any battle screen visual asset is marked done.

| Element | Color used | Non-color channel | Standard |
|---|---|---|---|
| Structure bar (critical) | Danger Red | Cracked-icon; numeric "0/max" | a11y §1.3 BLOCKING |
| Energy bar (empty) | C-2 track only | Numeric "0/max"; moves go ○ | a11y §1.3 |
| Heat zone 2 (amber) | Thermal Amber | ⚠ at 70; numeric ≥70 | a11y §1.3 BLOCKING |
| Heat zone 3 (orange-red) | Danger Red | ⚠ at 90; numeric ≥90; faster pulse tempo | a11y §1.3 BLOCKING |
| Heat zone luminance check | — | Zone 2 `#F0900A` lum≈0.31 vs Zone 3 `#CC3020` lum≈0.06 → ≥5:1 | Deuteranopia safety |
| Break pips | Element tint | Fill level; numeric; "BROKEN" text + cracked tile | a11y §1.3 BLOCKING |
| Enrage indicator | Danger Red | [!] icon; "+N%" numeric; text label | a11y §1.3 |
| Status: Shock | Volt Cyan | "Shock" text + Lightning Fork glyph | a11y §1.3 BLOCKING |
| Status: Burn | Thermal Amber | "Burn" text + Flame Chevron glyph | a11y §1.3 BLOCKING |
| Status: Stagger | C-7 neutral | "Stagger" text + Impact Ring glyph | a11y §1.3 BLOCKING |
| Affordability (●/○) | C-4 / C-5 + desaturation | ● / ○ shape glyph; desaturation | a11y §1.3 BLOCKING |
| Effectiveness (▲/▼/–) | Heal Green / Danger Red / C-7 | ▲ / ▼ / – shape glyph | a11y §1.3 BLOCKING |
| Active-turn marker | (highlight brightness) | ▶ caret glyph | a11y §1.3 BLOCKING |
| Shock reorder | Volt Cyan flash | Shock glyph + slide animation | a11y §1.3 |
| Flee disabled (boss) | Desaturation | "BOSS" text label; desaturation | a11y §1.3 |
| Overheat | Danger Red + screen-shake | "(Overheat)" text label on floating number; steam VFX shape | a11y §4.1 |
| Victory / Defeat transition | Warm lift vs. cool drain | Vignette luminosity shift; pose change | a11y §1.3 |
| All pulses / loops | Various | All ≤2.5 Hz (well under 3 Hz gate) | a11y §1.4 BLOCKING |

---

## 8. Open Items for Downstream Handoff

1. **Typeface selection**: art-director specifies the role, size, weight, and color
   system (§3). The specific font file is a production asset pipeline decision — flag
   to technical-artist for selection and Theme integration. Geometric sans-serif with
   4 weights minimum is the constraint.
2. **VFX implementation**: `vfx_break_flash`, `vfx_overheat_steam`, `vfx_hit_impact`,
   `vfx_enrage_rimlight` are specified here; implementation delegated to
   technical-artist per the delegation map.
3. **Shared shader for rarity glow**: the single parameterized rarity shader (art-bible
   §8.2) is specified for enemy/bench Symbot part rendering — delegate to
   technical-artist for the shader `.gdshader` file.
4. **DF OQ-1 dependency**: the effectiveness glyph on the target list (PG-06, §2.7
   above) depends on Damage Formula exposing `type_mult` pre-commit. This spec assumes
   that dependency is met; if it is deferred, the effectiveness glyphs show as "–"
   neutral until the formula is plumbed.
5. **Enrage rim-light opacity calibration**: the W-6 Harvest Crimson rim overlay opacity
   (0% / 20% / 40% / 60% at 0/1/2/3 breaks) is a tuning knob that must be verified
   not to visually compete with the Thermal element color (`#F0900A`) on Thermal-element
   enemies. If a Thermal enemy is at full enrage, the warm amber element glyph and the
   warm crimson rim should be distinguishable — confirmed by their different hues (amber
   ≈ hue 36° vs. crimson ≈ hue 5°) and by the glyph being the element signal.
6. **`ui_pip_broken.png` cracked tile**: the cracked-tile graphic is the BLOCKING
   non-color signal for a broken region. It must be visually distinct at 48×24px @1x
   in greyscale. Flag to the part artist / VFX artist for delivery.
