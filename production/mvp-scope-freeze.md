# MVP Scope Freeze — Symbots

> **Status**: FROZEN
> **Frozen on**: 2026-07-15, at the **Technical Setup → Pre-Production** phase gate
> **Authority**: Producer GO-condition (PR-PHASE-GATE), user-accepted
> **Authoritative scope list**: `design/gdd/systems-index.md` (the MVP-tier rows below)

## Why this freeze exists

The MVP absorbed **three discretionary mid-stream additions** before this gate — Synergy
(2026-07-10, a discovered dependency, not truly discretionary), the **Consumable layer #1c**
(2026-07-12, discretionary), and **Core Progression / Level Backbone #10b** (2026-07-12,
discretionary and highest-risk — it forced a *revision* of anti-pillar #1 "NOT a level-matching
treadmill"). The concept doc itself names "feature creep from Pokémon/MHW/PoE inspiration" as a
top scope risk. Two discretionary additions in three days is a growth velocity that, uncorrected,
breaches the **6-month solo MVP window**.

Critically, that 6-month clock is an **implementation** clock and it has **not started** — `src/`
is empty. Pre-Production (prototyping / vertical slice) is exactly when "cool idea" pressure peaks.
Freezing now protects the clock before it starts ticking.

## The rule

**The MVP system set is closed.** New ideas route to **Vertical Slice**, **Alpha/Full Vision**, or
a post-MVP backlog — **never** into MVP — unless a freeze exception is explicitly recorded here.

When a mid-stream MVP addition is proposed, the standing response is: surface this freeze + the
6-month clock, and default to deferring the idea past MVP. Only the user can grant an exception,
and it must be written into the Exceptions log below with its scope-cost rationale.

## Frozen MVP system set (from `systems-index.md`, 2026-07-12)

**Designed & Approved (14 GDDs):** #1 Part Database · #1a Move Database · #1b Passive Database ·
#1c Consumable Database · #2 Enemy Database · #3 Damage Formula · #4 Symbot Assembly ·
#5 Synergy · #6 Turn-Based Combat · #7 Encounter Zone · #8 Drop · #9 Part-Break ·
#10 Enemy AI · #10b Symbot Core Progression (Leveling) · #10c Enemy Level & Zone Scaling ·
#11 Inventory · #12 Zone & World Map · #13 World Loot · #14 Exploration Progress.

**MVP, not yet designed — implementation/UI/persistence tier (8):** #15 Workshop System ·
#16 Overworld Navigation · #17 Save/Load · #18 Workshop UI · #19 Combat UI · #20 World Map UI ·
#21 Audio (basic SFX for MVP; full audio → Alpha) · #22 Main Menu & Settings.

*Playable MVP target: one zone, two bosses (WIN_COUNT gates: Boss 1 @ 6 wins, Boss 2 @ 10).*

## Explicitly OUT of MVP (do not pull in)

Designs/blueprints & fabrication (Alpha, per HOLISM-01) · NPC shops (post-MVP consumable faucet;
MVP is drops-only) · #23a Key Item System (Vertical Slice) · #29 Auto-Adventure Dispatch (Full
Vision) · full Audio (Alpha) · Ammo Capacity stat (Full Vision-reserved).

## Open obligations carried INTO Pre-Production (not scope additions — pre-existing debt)

- **§8 Asset Standards** (art bible) — needed before any scratch assets are commissioned (AD + PR flagged).
- **Faction-name sync** with narrative — schedule as an explicit Pre-Production milestone before faction concept art (art bible §3.8 placeholders).
- **`design/ux/battle.md`** — still Draft, pending `/ux-review`.
- **11 items in `production/errata-backlog.md`** + pending **CD sign-off on OQ-CP-6** (Core Progression anti-pillar revision).

## Exceptions log

*(None. Any MVP scope change after 2026-07-15 must be recorded here with date, user approval, and scope-cost rationale.)*
