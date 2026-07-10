---
name: synergy-ux-open-issues
description: UX problems in Synergy System GDD after re-review — 5 BLOCKING, 3 RECOMMENDED; decisions needed before Workshop UI GDD synergy section can be authored
metadata:
  type: project
---

Second adversarial review conducted 2026-07-10 against `design/gdd/synergy-system.md`.
Prior verdict was MAJOR REVISION NEEDED; four blockers were reported fixed. This is the
re-review result.

## Status of Prior Issues

Issue 1 (animation thrashing) — PARTIALLY FIXED. Change detection language added to
Visual/Audio table. Debounce window and diff semantics still undefined (see Issue C).

Issue 2 (indicator count) — PARTIALLY FIXED. Build-relevant filter + 3-8 cap added.
Overflow behavior for >8 build-relevant tiers still undefined (see Issue B).

Issue 3 (threshold/format contradiction) — NOT FIXED + escalated. "Active + progressing
toward next tier" indicator state missing (see Issue H).

Issue 4 (two panels on a crowded screen) — NOT FIXED. Synergy delta vs. stat delta panel
question unresolved. Still deferred.

Issue 5 (stacking breakdown invisible) — NOT FIXED. No tier-breakdown display added.

Issue 6 (effect display name owner) — PARTIALLY FIXED. Owner assigned to Synergy Content
data. Length limit, null fallback, localization note still missing (see Issue G).

---

## BLOCKING Issues

**Issue B — Overflow behavior for >8 build-relevant tiers undefined (BLOCKING)**
UI Req 1 caps visible indicators at 8. EC-SYN-02 shows 10 simultaneous active tiers.
A focused build can easily produce 8–10 build-relevant tiers. The GDD does not specify
what happens to tier 9 and 10: silent hide, scroll, or priority-sort. Silent hiding
breaks Beat 1 (Recognition) — the player never sees a tier they are working toward.

Decision needed: Overflow behavior must be defined. Minimum: "overflow tiers must not
be silently hidden without player awareness."

**Issue C — Change detection contract is undefined (BLOCKING)**
Visual/Audio table adds "implement own change detection" but gives no debounce window
and no diff semantics. "Rapid" is undefined. Workshop UI GDD author will pick an
arbitrary debounce value. Diff by bonus_block equality can incorrectly suppress
animations when active tier set changes but total bonus stays equal. The Synergy GDD
defines the signal contract; it must also define the minimum diff semantics.

Decision needed: (a) Recommended debounce window (add to Tuning Knobs table, e.g. 250ms).
(b) Explicit diff definition: "change detection must diff active_synergies by set equality."

**Issue D — preview() trigger interaction undesignable on iOS (BLOCKING)**
UI Req 3 says "call preview() when previewing a part swap" with no trigger model.
The Assembly GDD's hover-based preview was already flagged as unimplementable on iOS.
No touch-compatible trigger (tap-to-preview-mode, long-press, drag-and-hold) is
specified or delegated. Workshop UI GDD cannot design the "when" from the current text.

Decision needed: Either specify the touch trigger model in UI Req 3, or add explicit
delegation: "trigger model is Workshop UI GDD's design decision, constrained by
platform-constraints — hover-based triggers are not permitted."

**Issue E — Recognition beat shows bonus value; UI Req 1 does not require it (BLOCKING)**
Player Fantasy Beat 1: "Ironclad: 2 of 3 — Armor +15 when complete." UI Req 1 for
inactive tiers: "2/3 — 1 more for bonus" — no bonus value shown. Direct contradiction.
Showing the pending bonus value is critical to Beat 1 (Recognition) and Beat 2 (The
Hunt). If it is required, the content data and/or UI compute contract must say so.
If it is not required, Beat 1 must be rewritten.

Decision needed: Does the inactive indicator show the pending bonus value? If yes, add
to UI Req 1. If no, revise Player Fantasy Beat 1 to remove the "Armor +15" example.

**Issue H — "Active + progressing toward next tier" indicator state unspecified (BLOCKING)**
UI Req 1 defines indicators for: (a) active tiers and (b) inactive tiers with count.
It does not define the state where a tier IS active but a next tier exists (e.g., 4
Ironclad parts: 3-piece active, 1 part away from 5-piece). This is the most common
mid-game player state for any primary synergy. No indicator format for this state
means Workshop UI GDD author must invent it from scratch.

Decision needed: Add a third indicator format: "active tier + progress toward next tier"
(e.g., "Ironclad 3 active | 4/5 toward large bonus").

---

## RECOMMENDED Issues

**Issue A — "30 theoretical tiers" should be 21 (RECOMMENDED)**
UI Req 1 says "not all 30 theoretical tiers." Actual count: 3 mfr × 2 tiers = 6; 3
element × 2 tiers = 6; 9 combined × 1 tier (MVP, 3-piece only per Detailed Rules) = 9.
Total = 21. The GDD contradicts itself — Detailed Rules explicitly forbids combined
5-piece tiers in MVP but the indicator count uses the number that assumes they exist.

Fix: Change "30" to "21" with breakdown "(6+6+9 = 21 in MVP)."

**Issue F — Combat UI requirement is one sentence with no consumable contract (RECOMMENDED)**
UI Req 5: "Combat UI displays the frozen cached_bonus_block bonuses as part of effective
stats." Three gaps: (1) no display location (HUD? stat menu? tap-to-reveal?); (2) no
breakdown requirement (flat "Armor 53" vs. "Armor 40 + 13 synergy"); (3) no active tier
list visibility during battle. The latter is especially important — players want to
confirm their synergies are active before a decisive turn.

Fix: Add three sentences covering location, attribution format, and tier list accessibility.
Or explicitly delegate all three to the Combat UI GDD.

**Issue G — display_name content requirement incomplete (RECOMMENDED)**
UI Req 4 adds display_name to Synergy Content data but omits: (a) maximum character
length (indicators have finite width — suggest 20 chars), (b) null/missing fallback
(suggest: show tier ID in brackets as content-error marker), (c) localization note
(single-language string is an implicit decision — should be explicit).

Fix: Add length limit, null fallback, and "multi-language localization deferred" note.

---

**Why:** Found during second adversarial review. Issues B, C, D, E, H must be resolved
before `design/ux/workshop.md` synergy section is authored. Issue F must be resolved
before Combat UI GDD is authored.

**How to apply:** Surface these issues to the game designer for decisions on B, C, D,
E, H. A, F, G are GDD author fixes that do not require design decisions — they are
specification precision gaps.

See also: [[workshop-ux-open-issues]], [[platform-constraints]], [[project-context]]
