---
name: synergy-ux-open-issues
description: 6 adversarial UX problems found in Synergy System GDD — critical blockers and decisions needed before Workshop UI GDD can be authored
metadata:
  type: project
---

Adversarial review conducted 2026-07-10 against `design/gdd/synergy-system.md`.

## Critical Issues (blockers for Workshop UI GDD)

**Issue 1 — Animation thrashing from always-emit (CRITICAL)**
Rule 7: evaluate() always emits synergy_changed even with identical output. Workshop UI
is required to respond to this signal, and the Visual/Audio requirements define animations
tied to it (indicator lights up, bonus animates in/out). Rapid part swapping fires the
signal on every equip — animations queue or interrupt each other even when no synergy state
changed. The GDD pushes diff responsibility to callers but gives Workshop UI no guidance
that this is its problem to solve. A programmer following the spec will produce animation
thrashing that destroys The Click fantasy (Beat 3 of Player Fantasy).

Decision needed: Does Synergy GDD assign diff responsibility to Workshop UI explicitly, or
does Rule 7 change to emit only on actual state change?

**Issue 2 — Indicator count unimplementable on iPhone without scroll (CRITICAL)**
Requirement 1 says Workshop UI must display every active synergy tier AND every inactive
tier with progress counters. Potential tier count: 3 elements × 2 tiers + 3 manufacturers
× 2 tiers + 9 combined pairs × 2 tiers = up to 30 indicators. At 44×44pt minimum touch
targets, 30 indicators cannot fit a 390×844pt iPhone screen alongside the Workshop's
existing panels (model view, 8 slots, 11-stat panel, part info). A scroll view inside the
Workshop buries the most feedback-critical information — Recognition (Beat 1) and The Click
(Beat 3) require the relevant indicator to be visible at the moment of equip.

Decision needed: Which tiers are visible at any given time? All 30, or only build-relevant
tiers (tags with ≥ 1 part contribution)?

## High Issues

**Issue 3 — Fantasy indicator format contradicts TIER1=2 threshold (HIGH)**
Player Fantasy Beat 1 shows: "Ironclad: 2 of 3 — Armor +15 when complete" with 2 Ironclad
parts. But SYNERGY_THRESHOLD_TIER1 = 2, so Ironclad 2-piece IS already active at 2 parts.
The format described shows an inactive state that cannot occur given current threshold values.
Also: with 2 Ironclad parts, the player simultaneously has the 2-piece active AND is working
toward the 4-piece. No indicator format in the GDD correctly represents "active tier + progress
toward next tier" — which is the normal mid-build state for most players.

Decision needed: Workshop UI GDD needs a defined indicator format for "2-piece active + working
toward 4-piece."

**Issue 4 — Two separate preview panels on a screen already at capacity (HIGH)**
Requirement 3: synergy threshold changes must be shown "separately" from the base-stat delta.
The Workshop already has an unresolved layout problem (11-stat delta panel, flagged in
workshop-ux-open-issues.md Issue 1). Adding a second distinct panel for synergy delta compounds
this. "Separately" is ambiguous: two physical panels, or distinct visual zones within one unified
panel? Player must see both in a single glance to make a swap decision — scroll between panels
breaks the evaluation flow.

Decision needed: Must stat delta and synergy delta be in physically separate UI panels, or is
"distinct presentation within a unified preview" acceptable?

**Issue 5 — Simultaneous tier stacking breakdown invisible to player (HIGH)**
With 4 active tiers, the player sees a total stat bonus (e.g., armor +13, energy_power +22) but
cannot see that +13 = 8 (Ironclad 2-piece) + 5 (Ironclad-VOLT 2-piece), or that +22 is composed
of three tiers. The UI as required is a flat indicator list with no breakdown showing which bonus
came from which combination. For a system whose Fantasy is "I built something intentional,"
players cannot verify their build decisions are doing what they think. No cap on simultaneously
active tiers; EC-SYN-02 allows up to 6 tiers simultaneously.

Decision needed: Workshop UI GDD needs a tier-breakdown display model or the stacking logic
is invisible to the player.

**Issue 6 — Effect ID display name has no owner (HIGH)**
Requirement 4: Workshop UI must display active passive effect IDs "by name." Effect IDs are
StringName codes (e.g., &"volt_shock_on_hit"). No GDD defines where the player-facing display
name comes from. TBC GDD defines behavior but does not exist yet. Four options exist (UI string
table, EffectID struct with display_name, TBC EffectDatabase, Synergy Content data) — none
named. Blocks Workshop UI GDD effects panel spec. Connects to open OQ-1 (content format)
and OQ-3 (effect ID registry).

Decision needed: Which system owns effect display name strings?

**Why:** Found during adversarial review before Workshop UI GDD is authored. These must be
resolved before `design/ux/workshop.md` synergy section can be written.

**How to apply:** Before authoring the Workshop UI synergy section, Issues 1 and 2 must have
decisions from Game Designer / Synergy GDD author. Issues 3, 4, 5 need Workshop layout
decisions. Issue 6 needs TBC GDD and OQ-1 resolved first.

See also: [[workshop-ux-open-issues]], [[platform-constraints]], [[project-context]]
