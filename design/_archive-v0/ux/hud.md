# HUD Design

> **Status**: Approved — passed /ux-review 2026-07-17 (0 blocking, 3 advisory)
> **Author**: Luan + ux-designer
> **Last Updated**: 2026-07-17
> **Template**: HUD Design

This document is the **cross-context HUD contract**: the philosophy and information
architecture that govern what appears on screen *at all* in each play context, plus
the full spec for the **overworld HUD** (previously unspecced). It does **not**
re-specify the combat HUD — that lives in [`battle.md`](battle.md) and the shared
components in [`interaction-patterns.md`](interaction-patterns.md) (PC-01/02,
PG-01…09). This doc **references** those; where it refines their chrome, it says so
explicitly and flags the change for traceability.

---

## HUD Philosophy

**Dense minimalism, adaptively scaled.**

The game surfaces *every* decision-relevant element the current context needs — it is
never information-starved — but each element must **earn its chrome and its placement**.
Prefer transparent, fading, and diegetic treatments and deliberate corner placement over
boxed panels; add a frame only when legibility demands it. The goal is "everything you
need, nothing that shouts."

**Canonical example (governing chrome directive):** the combat **event log** is not a
boxed strip — it is transparent corner text where each new line fades in and older lines
fade out against the scene. The *information* is unchanged (last ~3 action lines); only
the chrome is lighter. This directive applies to any "reference/ambient" element (log,
zone-name flash, toasts): ambient information uses fading/transparent chrome; **decision**
information (resource bars, break pips, enrage, moves) keeps solid, always-legible chrome.

**Adaptive density by context** — the same philosophy yields different densities:

- **Overworld** → near-invisible. Exploration and discovery are the experience; a clean
  frame protects immersion. Only persistent essentials (currency, a menu affordance) and
  *active* contextual markers (an encounter modifier counting down) are drawn.
- **Battle** → complete but restrained. The *readable-tactics* pillar demands that the
  harvest dilemma (break pips + enrage) and "can I act" (Structure / Energy / Heat) are
  always visible without a menu — but placed and chromed so the screen reads calm, not busy.
- **Workshop / menu screens** → own their layouts (separate UX specs); the persistent HUD
  yields to them entirely.

**Alignment with pillars & art bible.** This philosophy serves *Readable tactics* (all
decision data visible in battle) and *Parts are the game / discovery* (overworld stays
out of the way, no ledger). It matches the art bible's **"silhouette carries the story"**
accessibility contract: information is carried by shape/placement/glyph first, chrome and
color second.

### BLOCKING normative rule — No completion counters

**No HUD surface, in any context, may display a collection-completion metric** — no
"12 / 14 chests", no Pokédex-style "X / Y collected", no world-loot percentage, and
uncollected loot nodes get **no map markers**. This is a Player-Fantasy **anti-pillar**
enforced by two GDDs (`world-loot.md` UI Req, `inventory.md` UI Req 3): *discovery is the
reward; the ledger is memory, not a checklist.* Inventory is organized by **build-relevance**
(slot / rarity / family), never by a checklist. Any future HUD element that would surface a
completion ratio is rejected at review.

> **Distinction — goals ARE shown.** A boss-gate `WIN_COUNT` objective ("3 / 6 wins") is a
> *goal with visible progress* and **is** shown (`encounter-zone.md` UI Req 3), owned by the
> World Map UI. That is not a completion checklist — it is an objective the player is working
> toward. The anti-checklist rule bans *collection ledgers*, not *goals*.

---

## Information Architecture

### Full Information Inventory

Aggregated from every GDD `UI Requirements` section. Each item is categorized per context.
Categories: **Must-Show** (always visible) · **Contextual** (visible only when relevant) ·
**On-Demand** (player requests it) · **Hidden** (not on the HUD in this context) ·
**Forbidden** (must never appear).

| Information | Overworld | Battle | Owner / Source | Notes |
|---|---|---|---|---|
| Scrap currency | **Must-Show** | Hidden | Inventory / World-Loot | Restrained corner readout; the one persistent overworld number |
| Menu affordance (Workshop / Inventory / World Map) | **Must-Show** | On-Demand | Navigation | Single ☰ entry; opens the pause/menu hub |
| Active encounter modifier + **steps-remaining** (Lure / Jammer / Beacon) | **Contextual** | **Contextual** (Beacon-active marker) | Consumable DB (UI Req 4) | Only while active; icon + numeric steps (color-independent) |
| Current zone name | **Contextual** (brief flash on entry) | Hidden | Zone-World-Map (`zone_entered`) | Fading ambient text, not persistent |
| Reward reveal (part / consumable / Scrap awarded) | **Contextual** popup (tap-anywhere-dismiss, ≥44pt) | → Victory results overlay | World-Loot (UI Req) | Overworld HUD owns the world-node reveal; battle rewards go to the Victory overlay |
| Refusal toast ("Scrap storage full", "can't use here") | **Contextual** non-modal toast | **Contextual** rejection message | World-Loot / Consumable DB | Never a modal — must not interrupt exploration or combat flow |
| Item / consumable menu (context-filtered) | On-Demand (menu) | On-Demand (Item action) | Consumable DB (UI Req 1–3) | Wrong-context items greyed; battle RESTORE picker shows each Symbot cur/max |
| Structure / Energy / Heat · break pips · enrage · status badges · turn-order ribbon · move panel · target list · combat log | Hidden | **Must-Show** | **`battle.md` (PG-01…09)** | **Referenced, not re-specced here.** Governed by the combat HUD spec |
| Core level + XP-to-next | On-Demand (Workshop core slot) | Hidden | Core-Progression | Workshop UI owns the persistent bar; not on the overworld HUD |
| Post-battle per-core XP / level-up / bench "0 XP — over-level" | Hidden | → Victory results overlay | Core-Progression (UI Req) | A battle-exit surface, not the persistent HUD (spec: Victory overlay, OQ) |
| Boss-gate state + `WIN_COUNT` progress ("3 / 6 wins", "Defeat Boss 1 first") | On-Demand (World Map) | Hidden | Encounter-Zone (UI Req 3) | World Map UI owns it; a *goal*, exempt from the anti-checklist rule |
| Collection completeness / "X / Y collected" / loot % | **Forbidden** | **Forbidden** | World-Loot / Inventory anti-pillar | See BLOCKING normative rule above |

### Categorization summary

- **Overworld Must-Show (the entire persistent overworld HUD):** Scrap currency + menu
  affordance. That's it — two elements. Everything else is contextual, on-demand, or lives
  in a dedicated screen. This is the "near-invisible" density the philosophy demands.
- **Battle Must-Show:** the full combat decision set, entirely delegated to `battle.md`.
- **Cross-context Contextual:** active encounter modifier (both contexts), reward reveal,
  refusal toast, zone-name flash.
- **Conflict check (philosophy vs Must-Show length):** the overworld Must-Show list is 2
  items — well within "near-invisible." The battle Must-Show list is long by necessity
  (readable-tactics), but it is chromed under the dense-minimalism rule (restrained placement,
  fading log) so it reads calm. **No conflict.**

---

## Layout Zones

The combat layout zones are specified in `battle.md` (player-left / enemy-right landscape,
turn-order ribbon top-center, action cluster lower-left, target list lower-right, log bottom).
**This doc does not restate them.** Below are the **overworld HUD** zones — new to this spec.

**Overworld — corner-anchored, center-clear.** The center of the screen is the play space
(the avatar and world) and stays clear. HUD lives in the corners, inside iOS safe-area insets.

```
┌────────────────────────────────────────────────────┐
│ Scrap 240                                        ☰  │  ← top strip: currency (L) · menu (R)
│                                                     │
│                                                     │
│                    ( world / avatar )               │  ← center: clear play space
│                                                     │
│                                                     │
│ ⚡ Lure · 8 steps                                    │  ← lower-left: active modifier (only if active)
│  ┌───────────────────────────────┐                  │
│  │ Scrap storage full            │ ← non-modal toast (transient, fades)
│  └───────────────────────────────┘                  │
└────────────────────────────────────────────────────┘
        ▲ "Scrap Dunes" zone-name flash fades in top-center on entry, then out
```

**Zone rationale:**
- **Top-left — Scrap readout:** the single persistent number; small, restrained.
- **Top-right — ☰ menu affordance:** thumb-reachable, opens the menu hub (Workshop / Inventory / World Map / Consumables / Save).
- **Lower-left — active-modifier chip:** appears only while a Lure/Jammer/Beacon is counting down; icon + steps-remaining; disappears at 0.
- **Center — clear:** no persistent HUD over the play space.
- **Transient overlays (not fixed zones):** zone-name flash (top-center, fades), reward-reveal popup (center modal-lite, tap-dismiss), refusal toast (lower area, non-modal, auto-fades).

---

## HUD Elements

Overworld elements specced below. Combat elements are **referenced** to their pattern IDs —
see `battle.md` for their full behavior.

| Element | Category | Content | Visual form | Update behavior | Chrome (dense-minimalism) |
|---|---|---|---|---|---|
| **Scrap readout** | Must-Show (overworld) | current Scrap total | icon + integer | event-driven (on award/spend) | Restrained; brief count-up tick on change, no persistent frame |
| **Menu affordance ☰** | Must-Show (overworld) | — | single icon button (≥44×44pt) | static | Solid (it's a control, must be unambiguous) |
| **Active-modifier chip** | Contextual (both) | Lure / Jammer / Beacon icon + **steps-remaining** | icon + numeric | ticks down per step; removed at 0 | Semi-transparent; steps text is the non-color signal |
| **Zone-name flash** | Contextual (overworld) | current zone display name | fading center text | fires on `zone_entered`, ~1.5s in-hold-out | Fully diegetic; no frame; fades |
| **Reward-reveal popup** | Contextual (overworld) | part / consumable / Scrap awarded | card + icon + name/rarity | on `node_collected`; tap-anywhere to dismiss (≥44pt) | Light card; rarity carried by color **+** label/shape (color-never-sole) |
| **Refusal toast** | Contextual (both) | short reason string | non-modal toast | on `collect_refused` / rejection; auto-fades | Transparent, fading; never blocks input |
| **Combat resource bars / pips / enrage / status / ribbon / moves / log** | Must-Show (battle) | *see `battle.md`* | *see PG-01…09* | *see `battle.md`* | **Log chrome refined to fading transparent corner text — see Open Question 3** |

**Chrome directive detail — combat log (PG-08 refinement).** Under the dense-minimalism
philosophy, the event log renders as **fading transparent corner text** (each new line fades
in; older lines fade out against the scene), *not* the boxed `─LOG─` strip drawn in the
current `battle.md` wireframe. Information is unchanged (last ~3 lines, template strings).
This is a chrome refinement to PG-08 / `battle.md`, recorded in Open Questions for traceable
follow-through — it is **not** a silent contradiction of the reviewed battle spec.

---

## Dynamic Behaviors

The defining dynamic behavior of this HUD is the **context density shift**:

- **Overworld → Battle:** on encounter trigger, the two-element overworld HUD clears and the
  full combat HUD slides in (`battle.md` enter transition, ~0.3–0.5s wipe). The active
  encounter-modifier state **freezes** during battle (its step countdown is paused, per
  `battle.md` Entry context) — it is not spent by combat.
- **Battle → Overworld:** on any battle exit (Victory / Defeat / Fled), the combat HUD tears
  down and the overworld HUD restores; any modifier resumes its frozen countdown.
- **Workshop / Menu open:** the persistent overworld HUD yields entirely to the opened screen.

**Ambient-element lifecycles:**
- **Zone-name flash** — triggered by `zone_entered`; fades in top-center, holds ~1.5s, fades
  out. Never persists.
- **Active-modifier chip** — appears when a modifier becomes active, ticks each step, removes
  itself at 0 steps. In battle it shows as a static "active" marker (no countdown).
- **Reward reveal** — one card per `node_collected`; queued if several land close together
  (never stacked/overlapping); each dismissed by tap.
- **Refusal toast** — transient, auto-fades (~2s), non-blocking; multiple refusals coalesce
  rather than stack.

**No `_process` polling** — per ADR-0008, every HUD element is signal-driven (subscribe on
enter, disconnect on exit). Overworld elements subscribe to `zone_entered`, `node_collected`,
`collect_refused`, Scrap-change, and modifier-tick signals; combat elements per `battle.md`.

---

## Platform & Input Variants

Input context (from `technical-preferences.md`): **touch-first iOS (primary) + Mac mouse
(click = tap)**, **no gamepad**, keyboard-nav post-MVP.

- **Touch targets** — every interactive HUD control (☰ menu, reward-reveal dismiss, item
  menu entries) is **≥44×44pt** (GAG Basic §2.1). Ambient/display elements (Scrap readout,
  zone flash, modifier chip, log, toast) are non-interactive and exempt from the tap-target
  floor but still meet the text-contrast floor.
- **Safe area** — all corner-anchored elements sit inside the **iOS safe-area insets**
  (notch / home-indicator / rounded corners). Landscape orientation (matches `battle.md`).
  Virtual-px → pt calibration must be verified on-device in the first UI story (shared with
  `battle.md` OQ-4).
- **Mac** — mouse click = tap; no hover-only affordance anywhere (GAG Basic; hover =
  enhancement only). The Mac build tolerates larger viewports — corner anchoring scales, it
  does not reflow to a different layout.
- **No gamepad** — no button-prompt glyphs on the HUD; nothing depends on a controller.
- **Reduced overworld density is itself a platform benefit** — the near-invisible overworld
  HUD keeps the small mobile viewport uncluttered.

---

## Accessibility

Inherits `design/accessibility-requirements.md` (**GAG Basic** tier). Per-HUD application:

- **Color is never the sole channel (BLOCKING §1):**
  - Active-modifier chip — icon + **steps numeric**, not color alone.
  - Reward-reveal rarity — rarity **label/name + card treatment**, not color alone.
  - Refusal toast — **text string**, not a color flash.
  - Scrap readout — icon + number (inherently non-color).
- **Contrast & text (§1):** Scrap numeric and modifier steps ≥16pt; ambient fading text must
  still hit the **4.5:1** body-text contrast floor at its most-visible keyframe (a fading
  element that never reaches legible contrast fails — the fade target is *dismissal*, not
  *illegibility*). Toasts and zone-flash text hold readable contrast during their visible hold.
- **Motion (§1.4 BLOCKING):** all fades/pulses <3 flashes/sec. The fading-log and fading-toast
  chrome must use gentle opacity ramps, never strobing. Reduce-Motion toggle deferred post-MVP
  (shared with `battle.md`); the <3-flash ceiling is the MVP floor.
- **No timing pressure (§2.3):** reward-reveal popups are **tap-dismissed**, never
  auto-timeout — a player reading a drop is never rushed. (Toasts auto-fade because they carry
  no decision; the reward reveal carries one, so it waits for the player.)
- **Screen reader / AccessKit (§5):** deferred, door kept open — interactive HUD controls are
  Button subclasses; icon-only controls (☰, modifier chip) carry `accessibility_name`.
- **Non-interactive ambient elements** are *supplementary* — no information exists **only** in
  a fading element. (The reward's contents also exist in the Inventory; a refusal's cause is
  also inferable from the attempted action.) Nothing critical is lost if a fade is missed.

---

## Open Questions

1. **Player journey map missing** — no `design/player-journey.md`; overworld emotional context
   (exploration calm vs. anticipation) was inferred. Template at
   `.claude/docs/templates/player-journey.md`. Consider a journey session to validate.
2. **Dependent screen specs not yet written** — this HUD hands off to five unspecced surfaces,
   each needing its own `/ux-design` pass before its stories: **overworld navigation**
   (`overworld-hud` / avatar movement + encounter trigger), **world-map** (boss-gate readouts,
   terrain legibility, travel), **inventory** (Scrap confirm, batch-scrap, stack-full, no
   completion counter), **workshop** (core level + XP bar, over-level greying), and the
   **Victory results overlay** + **Defeat screen** (post-battle XP/level-up, bench over-level
   line). This doc defines the *persistent-HUD contract* they plug into; it does not spec them.
3. **PG-08 / `battle.md` log-chrome refinement (traceable follow-through)** — the dense-
   minimalism philosophy refines the combat log from a boxed strip to **fading transparent
   corner text**. `battle.md`'s wireframe + Component Inventory and `interaction-patterns.md`
   PG-08 (Event Log) should adopt this chrome on their next revision. Information is unchanged;
   this is a styling change only. Flagged here so the change is **not silent** — do not edit
   `battle.md` / PG-08 without a `/ux-review` pass that acknowledges it.
4. **Virtual-px → pt calibration** — shared with `battle.md` OQ-4; the ≥44pt / ≥16pt floors
   assume the on-device calibration verified in the first UI story. Gate before UI audits.
5. **Overworld avatar & human player character** — the HUD assumes a walkable human avatar in
   the overworld (canonical in `game-concept.md`: "You are a Symbot Mechanic"). Overworld
   Navigation (#16) is Not Started; when it is specced, confirm no additional persistent HUD
   element (e.g. a compass or interaction prompt) is required beyond the two Must-Show items —
   if it is, add it here first.
6. **Reward-reveal queue depth** — if many world-loot nodes are collected in quick succession,
   confirm the reveal queue cap and whether a "collected N items" summary replaces individual
   cards past a threshold (avoid a tap-storm) — without ever showing a completion ratio.
