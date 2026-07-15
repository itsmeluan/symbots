# UX Spec: Battle Screen

> **Status**: Draft complete — pending `/ux-review battle`
> **Author**: Luan + ux-designer
> **Last Updated**: 2026-07-15
> **Journey Phase(s)**: Core loop — Encounter / Combat (no player-journey.md yet; inferred)
> **Template**: UX Spec
> **Manifest Version**: 2026-07-14

Locked foundational decisions (2026-07-14): **Landscape** orientation · **Move-first → labelled target list** for sub-targeting · **No confirm step** (target selection commits; back-tap deselects).

---

## Purpose & Player Need

The battle screen is where the player **executes a build hypothesis and harvests
parts by breaking targeted enemy regions**. The player needs to: *read* the enemy
(element, regions, threat), *plan* a harvest target, *execute under mounting
pressure* (Heat climbing, enrage rising) one turn at a time, and *collect* the
break. Without this screen the core loop — build → test → harvest → rebuild — has
no proving ground.

The single most important thing this screen must make easy is the **harvest
dilemma**: choosing STRUCTURE vs. a break region every turn, with the cost of that
choice (enrage) legible. If the pips and enrage indicator are unreadable, the core
loop collapses to guesswork.

---

## Player Context on Arrival

The player arrives from the **overworld** — either a wild encounter trigger or a
boss gate — having *already committed a build in the Workshop*. Emotional state:
**invested anticipation** ("will my build work?"), not stress — the turn-based
genre guarantees time to think (no timing pressure; see accessibility §2.3).

Boss gates are entered voluntarily; wild encounters are semi-voluntary (a
consequence of exploring). The player arrives knowing their own loadout, facing an
enemy that may be known or unscouted. Because defeat is framed as *build disproved*,
not punishment (inventory untouched), arrival carries curiosity, not dread.

---

## Navigation Position

`Root → Game → Overworld → Battle`.

The battle is a **modal full-screen state that suspends (keeps alive) the
Overworld** per ADR-0004 (Overworld keep-alive). It is **not** reachable from the
main menu — only via an encounter in the overworld. It is context-dependent, never
a top-level destination. The Overworld scene is preserved beneath it and resumed
on any exit.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Overworld — wild encounter | Step into encounter zone / random trigger | `enemy_id`, frozen team snapshot (3 Symbots), encounter modifiers (Jammer/Lure countdown frozen during battle) |
| Overworld — boss gate | Interact with a boss gate | boss `enemy_id`, gate context (**Flee disabled**) |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Victory results → Overworld | Enemy Structure = 0 | Shows fired break events, XP, loot; **irreversible reward grant** (parts/Scrap/consumables added to inventory) |
| Defeat screen → Retry / Overworld | All 3 Symbots downed | **No penalty** — inventory & equipped parts untouched; only lost time + pending loot forfeited |
| Overworld (Fled) | Flee (wild only) | No rewards, no XP; runtime state discarded |

All exits discard the battle runtime state at `BATTLE_END` (ADR-0007). No battle
state persists between encounters.

---

## Layout Specification

### Information Hierarchy

What the eye should hit first → last:

1. **Enemy break-pips + enrage indicator** and **my available moves** — these drive the turn decision (the harvest dilemma).
2. **My Structure / Energy / Heat** — can I act, and am I safe? (Heat is the self-inflicted third resource; it must read *in advance*.)
3. **Both combatants' status badges** — what's ticking on each side.
4. **Damage / effectiveness feedback** — the result of the last action.
5. **Combat log & bench** — reference, discoverable, lower priority.

### Layout Zones

Landscape, **player-left / enemy-right** (classic JRPG read). Both bottom corners
are thumb zones (two-handed): **moves resolve lower-left**, the **target list
resolves lower-right** near where the enemy lives.

- **Top-left — Player card**: identity + the three resource readouts + statuses + bench.
- **Top-right — Enemy card**: identity + Structure + element + statuses + break pips + enrage.
- **Center — Feedback layer**: floating damage, effectiveness pop, status pops, break-pop VFX + hit-stop.
- **Bottom-left — Action cluster**: Moves / Switch / Flee / Item; expands to the 4-move panel.
- **Bottom-right — Target list**: appears only when a DAMAGE move is selected (STRUCTURE + unbroken regions).
- **Bottom strip — Combat log**: last ~3 lines.

### ASCII Wireframe

**Default (action-menu) state:**

```
┌──────────────────────────────────────────────────────────────┐
│ ┌─PLAYER────────────┐                    ┌─ENEMY───────────┐  │
│ │ [◐] Voltbot   L12 │                    │  Scrap Golem  L14│ │
│ │ STR ▓▓▓▓▓▓▓░░ 84/120                   │ STR ▓▓▓▓▓▓▓▓ 210 │ │
│ │ EN  ▓▓▓▓░░ 40/60  │      ~ feedback ~   │ ⚡Volt           │ │
│ │ HEAT ▓▓▓▓▓▓▓▒ 78 ⚠│    "SUPER          │ ┌─BREAK REGIONS─┐│ │
│ │ ⚡Volt            │     EFFECTIVE!"     │ │L.Arm  ▓▓░░ 40 ││ │
│ │ [Shock 2] [Burn 1]│      −50            │ │Torso  ▓▓▓░ 90 ││ │
│ │                   │                    │ │Core  ✦BROKEN  ││ │
│ │ Bench: [◑][◒]     │                    │ └───────────────┘│ │
│ └───────────────────┘                    │ ENRAGE +24%  [!] │ │
│                                          │ [Stagger 2]      │ │
│ ┌─ACTION──────────────┐   ┌─TARGET (when DMG move picked)──┐│ │
│ │ ▶ MOVES             │   │ STRUCTURE      210/210          ││ │
│ │ ⇄ SWITCH  ⚑ FLEE    │   │ Left Arm        40/100 (2 hits) ││ │
│ │ ✚ ITEM              │   │ Torso           90/100          ││ │
│ └─────────────────────┘   └─────────────────────────────────┘│ │
│ ┌─LOG─────────────────────────────────────────────────────┐  │
│ │ Voltbot used Volt Jab → Left Arm. Super effective! −50   │  │
│ └─────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

**Move-selected state** (tap `▶ MOVES` → 4-move panel replaces the action cluster;
the TARGET list populates only for DAMAGE moves; tapping a target resolves with no
confirm step):

```
 ┌─MOVES───────────────────────┐   ┌─TARGET──────────────────┐
 │ ● Basic Attack      (free)  │   │ STRUCTURE     210/210    │
 │ ● Volt Jab   ⚡ E12 [Shock] │   │ Left Arm       40/100    │  ← tap = RESOLVE
 │ ○ Overload   ⚡ E40  (Heat!)│   │ Torso          90/100    │     (no confirm)
 │ ● Vent       ❄ E8  UTILITY  │   │ (Core broken — hidden)   │
 │  ‹ back                     │   └─────────────────────────┘
 └─────────────────────────────┘   ● affordable  ○ greyed (E/Heat)
```

### Component Inventory

| Zone | Components |
|---|---|
| **Player card** | name / level / sprite · Structure bar + numeric · Energy bar + numeric · **Heat gauge + overheat warning** · element icon · ≤3 status badges (name + duration) · bench portraits ×2 |
| **Enemy card** | name / level / sprite · Structure bar + numeric · element icon · ≤3 status badges · **2–3 break pips** (each cur/max + "N hits" hint; BROKEN pips greyed/struck) · **enrage indicator** (+12/24/36%) |
| **Action cluster** | Moves · Switch · Flee (**greyed on boss**) · Item (greyed if no valid item) |
| **4-move panel** | per move: name · element icon · energy cost · status-rider badge · affordable/greyed state (● / ○) · "Heat!" flag if the move risks overheat · `‹ back` |
| **Target list** | STRUCTURE + each unbroken region, with break progress; labelled buttons (≥44pt) |
| **Center feedback layer** | floating damage number · effectiveness pop ("Super effective!" / "Not very effective") · status-application pop ("Shocked!") · **break-pop VFX + 100–200ms hit-stop** · overheat overlay |
| **Combat log** | last ~3 action lines |

**New interaction patterns this screen contributes to `interaction-patterns.md`:**
resource bar (Structure/Energy) · capped gauge w/ threshold warning (Heat) ·
segmented progress pip (break regions) · status badge w/ duration · affordable /
disabled action button · labelled target-list picker · floating feedback text ·
event log.

---

## States & Variants

Most battle states are **determined by the Turn-Based Combat GDD** (Rules 4/5/12,
TBC-F7, V3-7/V3-8) — this screen translates those rules into presentation. The one
UX-level decision (turn pacing) is captured below the table.

| State / Variant | Trigger | What changes on screen |
|---|---|---|
| **Default** (`ACTION_PENDING`) | Player's active Symbot turn begins | Action cluster shown; all inputs live |
| **Move-selected** | Tap `▶ MOVES` | 4-move panel replaces the action cluster; target list populates for DAMAGE moves |
| **Resolving** | Action committed (`TURN_ACTIVE`) | Inputs locked; feedback layer plays; log updates |
| **Enemy turn** | `TURN_ACTIVE(enemy)` | Inputs locked; enemy telegraph + attack VFX; Structure / status update |
| **Overheat beat** | Heat hits 100 (Rule 5) or enters turn Overheated (Rule 4) | V3-8: steam flash, gauge slams 0→20 (two-step), self-damage number in heat register, turn-skip shown in turn order; screen-shake (**reserved for this + DOWNED only**) |
| **Enrage escalation** | `broken_region_count` → 1 / 2 / 3 (TBC-F7) | Enrage indicator steps +12 / +24 / +36%; enemy card gains a persistent "angrier" state (central beat — must telegraph) |
| **Switch-in** | Player picks `⇄ SWITCH`, or active Symbot downed | Player card swaps to the bench Symbot; bench portraits reorder |
| **Boss variant** | Entered from a boss gate | `⚑ FLEE` greyed/absent for the whole battle |
| **Battle-init** | `BATTLE_INIT` snapshot freeze | Brief intro (enemy reveal); no input yet |
| **Victory** | Enemy Structure = 0 (Rule 12) | Freeze → results overlay (breaks, XP, loot) → Overworld |
| **Defeat** | All 3 Symbots DOWNED (Rule 12) | DOWNED shake; defeat screen (Retry / Overworld); **inventory untouched** |
| **Heat zones** *(component variant)* | Heat 0–69 / 70–89 / 90–100 (V3-7) | Gauge: cool fill → amber pulse → orange-red faster pulse |

**Turn pacing — hybrid auto-advance.** Routine action → resolution → next-turn
transitions play **automatically** (no tap) to keep touch combat brisk. **Beat
moments pause for a tap-to-continue**: Overheat entry (V3-8, 0.6–1.0s), each region
Break pop, and Defeat. This satisfies the GDD's "central emotional beat — must
telegraph" mandate (enrage / overheat / break) without per-phase tap fatigue.
Enrage escalation is a *persistent* card-state change (not a pause), reinforced on
the turn it steps.

**Input-lock scope.** During `Resolving` and `Enemy turn`, action inputs are
locked; the **combat log and bench remain readable** (scroll/inspect only, no
commit). The lock releases on return to `ACTION_PENDING`.

---

## Interaction Map

Input context (from `technical-preferences.md` + `accessibility-requirements.md`):
**touch-first iOS + Mac mouse (click = tap)**, **no gamepad**, keyboard-nav
post-MVP, all targets ≥44×44pt, no hover-only affordances.

| Component | Action | Input | Immediate feedback | Outcome |
|---|---|---|---|---|
| Action button — Moves | Tap | Touch / click | Panel slide-in | Opens 4-move panel |
| Action button — Switch | Tap | Touch / click | Bench highlights | Opens switch flow |
| Action button — Flee | Tap | Touch / click | Confirm (wild) / greyed (boss) | Fled → Overworld, or blocked |
| Action button — Item | Tap | Touch / click | Item list (greyed if none) | Opens consumable picker |
| Move button (DMG) | Tap | Touch / click | Selects; **target list shows ▲/▼ effectiveness hint per region** | Selects move |
| Move button (utility) | Tap | Touch / click | Resolves (no target step) | Commits action → `Resolving` |
| Move panel `‹ back` | Tap | Touch / click | Panel slide-out | Returns to action cluster |
| Target row | Tap | Touch / click | **Resolves immediately (no confirm)** | Commits action → `Resolving` |
| Move / region / status | **Long-press** (hold) | Touch hold / Mac hover-or-hold | Detail popover (description, rider math, break math) | Read-only; release / tap-away dismisses |
| Bench portrait | Tap | Touch / click | Inspect popover | Previews benched Symbot (read-only) |
| Combat log | Swipe / scroll | Touch / wheel | Scrolls history | — |
| Beat tap-to-continue | Tap anywhere | Touch / click | Advances the paused beat | Resumes auto-flow |

**Effectiveness telegraph.** DAMAGE moves surface a pre-commit effectiveness hint
(▲ strong / ▼ weak / – neutral) on each target row, so the player can *plan the
harvest before committing* — the touch path that serves the "read → plan" pillar.
**Resolves DF OQ-1 toward pre-commit** (see Open Questions).

**No-confirm reminder.** Tapping a target row commits with no confirm step (locked
decision); effectiveness is read *before* the tap, not confirmed after. Back-tap on
the move panel (`‹ back`) is the only deselect path.

**Inspect is never a commit.** Long-press opens read-only detail and never spends a
turn or Energy — it is safe to inspect any move/region/status mid-decision.

---

## Events Fired

Per the ADR-0008 view contract, this screen **fires action-submissions and never
writes combat state directly**. It *subscribes* to TBC's turn/damage/status/
overheat/break signals (see Data Requirements). The single write path is the
ADR-0007 `submit_action` seam, which parks until `BattleController` resolves.

| Player Action | Event Fired | Payload | Notes |
|---|---|---|---|
| Commit move + target | `submit_action` (→ TBC seam, ADR-0007) | `{move_id, sub_target}` | Parks until TBC resolves; **only** combat-authority write path |
| Commit utility / repair move | `submit_action` | `{move_id, sub_target: null}` | — |
| Switch active Symbot | `submit_action` | `{action: SWITCH, symbot_id}` | Consumes the turn (GDD Rule 6) |
| Use item | `submit_action` | `{action: ITEM, item_id, target}` | Rejected use ≠ turn consumed (Consumable Rule 3) |
| Flee | `submit_action` | `{action: FLEE}` | Wild only; blocked on boss |
| Long-press inspect | *none* | — | Deliberate — read-only, no state change |
| Tap-to-continue beat | *none* | — | UI-local pacing only |

**State-modifying flag.** `submit_action` is the single path that mutates
persistent battle runtime state — architecture already owns it (ADR-0007 park +
`BattleController` authority). The screen never writes combat state directly
(ADR-0008 view contract).

**Analytics — deferred to post-MVP** (scope freeze). When added, `battle_started`
and `battle_ended(outcome, enemy_id, turn_count)` are the natural first hooks for
balance analysis. Note `battle_ended` is **already** emitted by TBC (Rule 12) —
analytics would *subscribe*, not add a new fire. Flagged to analytics-engineer.

---

## Transitions & Animations

Most in-screen timings are **specified by the TBC GDD V3 section** and extracted
here. Motion accessibility is governed by `accessibility-requirements.md`.

**Screen enter** (Overworld → Battle): transition flash/wipe ~0.3–0.5s → enemy
reveal → cards slide in → `ACTION_PENDING`. Overworld is suspended beneath, not
destroyed (ADR-0004 keep-alive).

**Screen exit:**
- Victory → freeze → results overlay fade-in → dismiss → fade back to the resumed Overworld.
- Defeat → DOWNED shake → fade to defeat screen (Retry / Overworld).
- Fled → quick fade to Overworld.

**In-screen state-change animations (extracted from GDD V3):**

| Animation | Timing / behaviour | Source |
|---|---|---|
| Damage number | Floats up from target (~0.4s) | — |
| Effectiveness pop | "Super effective!" / "Not very effective" | — |
| Heat gauge | cool (0–69) → amber pulse (70–89) → orange-red faster pulse (90–100) | V3-7 |
| Energy bar | Drops immediately on use **before** move VFX; recharge fill ~0.2s at turn start | V3-9 |
| **Overheat** | 0.6–1.0s: steam flash, gauge slams 0→20 (two-step), self-damage number, turn-skip greyed in turn order; screen-shake <0.3s | V3-8 |
| Break pop | Break-pop VFX + **100–200ms hit-stop** | V3-11 (Part-Break owns) |
| Enrage escalation | Persistent card-state step on each break | TBC-F7 |
| Move panel | Slide-in / slide-out | — |

**Beat pauses** (from the Turn-pacing decision): Overheat entry, each Break pop, and
Defeat hold for a **tap-to-continue**; all other transitions auto-advance.

**Motion accessibility:**
- **Reduce-Motion toggle — deferred post-MVP** (a11y §6.2).
- **MVP substitute — all pulsing/looping effects <3 flashes/sec — BLOCKING** (a11y §1.4). Heat pulse and enrage telegraph must be authored under this ceiling.
- **Screen-shake reserved for Overheat + DOWNED only**, <0.3s (never a routine hit).

---

## Data Requirements

Per the ADR-0008 view contract, this screen is **pure read + one write seam**
(`submit_action`). Data is either **frozen at `BATTLE_INIT`** (CombatantSnapshot,
ADR-0005) or **live runtime state** owned by `BattleController` (ADR-0007),
delivered via subscribed signals — never polled (`_process`-free per ADR-0008).

| Data | Source system | R/W | Notes |
|---|---|---|---|
| Active Symbot name / level / sprite / element | CombatantSnapshot (ADR-0005) | Read | Frozen at BATTLE_INIT |
| `current_structure` / `current_energy` / `current_heat` | BattleController runtime (ADR-0007) | Read | **Real-time** via signals |
| `max_structure` / `max_energy` | CombatantSnapshot | Read | Frozen; Heat cap = const 100 (Part DB) |
| 4-move pool (name / element / cost / rider) | Snapshot move pool + Move DB | Read | Frozen pool; affordability computed from live Energy |
| Status instances + durations (both sides) | BattleController runtime | Read | Real-time |
| Enemy name / level / sprite | Enemy DB (via snapshot) | Read | — |
| Enemy `current_structure` | BattleController runtime | Read | Real-time |
| Break regions (cur/max, broken flag, "N hits") | BattleController pools (init from Enemy DB) | Read | Real-time |
| `broken_region_count` / enrage % | BattleController (TBC-F7) | Read | Real-time |
| **Effectiveness hint (▲ / ▼)** | Damage Formula type table (DF-1) | Read | Pre-commit — **DF must expose `type_mult` pre-commit (DF OQ-1)** |
| Bench Symbots ×2 | CombatantSnapshot (team) | Read | Frozen; inspect only |
| Item list | Consumable DB + inventory | Read | For the Item action |
| Combat log lines | BattleController event stream | Read | Real-time; last ~3 |
| Action submission | → `submit_action` (ADR-0007) | **Write (seam)** | Only write path; not direct state mutation |

**Architectural note.** The screen owns **no game state** — pure read + the single
event seam, consistent with ADR-0008. The *only new data-delivery obligation* this
screen creates is the **effectiveness telegraph**, which requires Damage Formula to
expose `type_mult` before commit (DF OQ-1).

---

## Accessibility

This screen inherits `accessibility-requirements.md` (GAG Basic tier). Per-screen
application:

- **Touch targets** — action buttons, move buttons, and target rows all ≥44×44pt (§2.1); target rows get generous height to avoid mid-combat mis-taps.
- **Contrast & text** — resource numerics ≥16pt; status-badge duration ≥13pt floor; large-text toggle adds +4pt (§1).
- **Color-independent signals** (§1 — BLOCKING *color-never-sole* rule):
  - Elements — icon + shape, not color alone (Kinetic = non-red — Art Director flag).
  - Status badges — name text + icon, not color alone.
  - **Effectiveness — ▲ / ▼ glyph**, not red/green alone.
  - Break pips — fill level + "BROKEN" strike/label, not color alone.
  - Enrage — `[!]` icon + "+24%" numeric + text, not color alone.
  - **Heat gauge — numeric value + ⚠ threshold marker** at 70 / 90, so "riding the edge" reads without the amber/orange fill (V3-7 color = enhancement, not sole signal).
- **Screen reader / AccessKit** — deferred, door kept open (§5): interactive elements are Button subclasses; icon-only controls (element, status, enrage) carry `accessibility_name`.
- **Motion** — Reduce-Motion deferred; **<3 flashes/sec BLOCKING**; screen-shake reserved for Overheat + DOWNED (§1.4 / §6.2).
- **Keyboard nav** — post-MVP (§2); ADR-0008 dual-focus split keeps the door open; touch/mouse is the MVP path.
- **No timing pressure** — turn-based; the hybrid pacing's beat-pauses are player-advanced, never auto-timeout (§2.3).
- **Multi-touch** — no gesture requires more than one finger (§2.2); long-press is single-finger with a mouse (hover-or-hold) equivalent.

---

## Localization Considerations

- **MVP language scope** — English-only at launch (solo dev, 6-mo MVP); the design does **not** block later localization. Flagged to localization-lead.
- **String externalization** — all UI labels (MOVES / SWITCH / FLEE / ITEM), effectiveness pops, status names, and log templates are externalized — **no hardcoded strings** (cheap insurance even for an English-only launch).
- **Expansion headroom** — layouts must tolerate **+40% text growth** (German / Russian). Longest elements: move names, status names, effectiveness pops, enemy names.
- **Truncation + inspect** — long move / status names ellipsis-truncate in the fixed-width panel; the full name is available via the long-press popover (the existing inspect path).
- **Log templating** — combat-log lines are template strings with ordered placeholders (`"{symbot} used {move} → {region}. {effectiveness}! {damage}"`), never string concatenation — so grammar and word order survive translation.
- **Numbers** — Structure / Energy / Heat are small integers (<1000 in MVP), locale-neutral; no thousands separator needed yet.
- **Icon-first helps** — element / status / effectiveness / enrage are all icon + glyph, reducing text to translate and layout risk.
- **RTL** — not a launch market; the landscape player-left / enemy-right mirror is a post-MVP RTL consideration (flag).

---

## Acceptance Criteria

Per the testing standards, a UI screen's ACs are **ADVISORY** (evidence: manual
walkthrough doc OR interaction test) — except AC-15, which inherits the BLOCKING
accessibility flash-rate gate. Each AC traces to a locked decision.

| # | Acceptance Criterion | Gate |
|---|---|---|
| AC-01 | Break pips (cur/max + "N hits") **and** enrage % are visible in the default state without opening any menu (harvest dilemma legible) | ADVISORY |
| AC-02 | Tapping a DAMAGE move populates the target list with STRUCTURE + every unbroken region; broken regions hidden / struck | ADVISORY |
| AC-03 | Tapping a target row resolves immediately — **no confirm dialog** | ADVISORY |
| AC-04 | `‹ back` deselects to the action cluster **without consuming a turn** | ADVISORY |
| AC-05 | Unaffordable moves (Energy < cost) render greyed (○) and are not selectable; Basic Attack always available | ADVISORY |
| AC-06 | Effectiveness (▲ / ▼ / –) shows on each target row **before** commit | ADVISORY |
| AC-07 | All action buttons, move buttons, and target rows are ≥44×44pt | ADVISORY |
| AC-08 | No information conveyed by color alone — element / status / effectiveness / break / enrage / Heat-zone each have a non-color signal | ADVISORY |
| AC-09 | Overheat entry, each Break pop, and Defeat pause for tap-to-continue; all other transitions auto-advance | ADVISORY |
| AC-10 | During Resolving / Enemy-turn, action inputs are locked but the combat log and bench remain readable | ADVISORY |
| AC-11 | Flee greyed / absent in a boss battle; available in a wild battle | ADVISORY |
| AC-12 | Long-press opens a read-only detail popover — consumes no turn or Energy | ADVISORY |
| AC-13 | Victory shows breaks / XP / loot before returning to Overworld; Defeat leaves inventory + equipped parts unchanged | ADVISORY |
| AC-14 | Heat gauge shows a ⚠ threshold marker + numeric at 70 and 90 | ADVISORY |
| **AC-15** | **All pulsing / looping effects stay <3 flashes/sec** | **BLOCKING** (inherits a11y §1.4) |

---

## Open Questions

1. **DF OQ-1 (erratum flag → Damage Formula GDD)** — the pre-commit effectiveness telegraph requires Damage Formula to expose `type_mult` *before* commit. This spec resolves OQ-1 toward pre-commit; the Damage Formula GDD needs the matching erratum.
2. **Player journey map missing** — no `design/player-journey.md`; player context here was *inferred*. Template at `.claude/docs/templates/player-journey.md`. Consider a journey session to validate the arrival emotional state.
3. **Art Director flags** — (a) colorblind-safe elemental palette, **Kinetic = non-red**; (b) document active / inactive visual states for **synergy + enrage** (a11y decision 4).
4. **Virtual-px → pt calibration** — the ≥44pt targets and ≥16pt text assume the calibration **verified on-device in the first UI story** (a11y decision 5 + engine advisory). Must gate before UI audits.
5. **Spec dependencies (not yet written)** — this screen exits to / opens four unspecced surfaces: Victory **results overlay**, **Defeat screen**, **Switch picker** (bench selection; costs a turn per GDD Rule 6), and **Item / consumable picker**.
6. **Move-4 null slot** — GDD allows Move 4 = null; confirm the 4-move panel renders 3 moves gracefully (collapsed vs. empty slot).
7. **Localization-lead** — confirm English-only MVP launch scope.
8. **Analytics-engineer** — confirm the combat-telemetry deferral; `battle_started` / `battle_ended(outcome, enemy_id, turn_count)` as the eventual first hooks.
