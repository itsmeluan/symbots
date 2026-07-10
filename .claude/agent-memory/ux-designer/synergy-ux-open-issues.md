---
name: synergy-ux-open-issues
description: UX problems in Synergy System GDD after re-review #4 enumeration pass — 1 BLOCKING (New 6), 6 RECOMMENDED; DCO-1 through DCO-5 resolved prior blocking items by delegation; Workshop UI GDD unblocked except for New 6 signal handler section
metadata:
  type: project
---

Re-review #4 conducted 2026-07-10 against `design/gdd/synergy-system.md`.

**CORRECTION (enumeration pass, re-review #4)**: Prior mid-review memory overstated
blocking count at 7. After verifying each item against the actual DCO table text, items
B, D, New 1, New 4 (tappability portion), and New 5 were each resolved by explicit
delegation in DCO-1 through DCO-5. Issue C diff semantics were resolved in Rule 7; only
debounce window remains (RECOMMENDED). Only 1 genuine BLOCKING item remains: New 6.

---

## RESOLVED — Direct fixes

**Issue E — Beat 1 vs. UI Req 1 bonus value**: FIXED. Closed.
**Issue H — "Active + progressing" indicator state**: FIXED. Closed.
**Issue A — "30 theoretical tiers" wrong count**: FIXED. Closed.

## RESOLVED BY DELEGATION — DCO table (review #3)

**Issue B — Overflow behavior**: DCO-1 prohibits silent-drop and delegates
scroll/collapse/priority-sort to Workshop UI GDD. Sufficient delegation.

**Issue D — preview() trigger on iOS**: DCO-3 delegates touch-gesture design to
Workshop UI GDD. The Synergy GDD only owes the `preview()` call, which it provides.
Sufficient delegation.

**Issue New 1 — Indicator ordering**: DCO-2 explicitly prohibits inheriting signal
emission order and delegates UX priority rule to Workshop UI GDD. Sufficient delegation.

**Issue New 4 (tappability) — Indicator tappability and layout**: DCO-4 declares
indicators must be tappable and delegates layout solution to Workshop UI GDD. Sufficient.
Gesture conflict sub-issue remains as RECOMMENDED (see below).

**Issue New 5 — "In reach" definition**: DCO-5 names all three interpretations, flags
unachievable-progress risk, and delegates definition to Workshop UI GDD. Sufficient.

**Issue C (diff semantics) — active_synergies diff rule**: Rule 7 now contains explicit
diff semantics ("diff on active_synergies tier-ID set, not bonus_block equality alone"
with rationale). Resolved as a direct fix. Debounce window remains RECOMMENDED.

---

## BLOCKING Issues (1 open)

**New 6 — Change-detection statefulness requirement buried and incomplete (BLOCKING)**
Rule 7 contains the correct diff rule but: (a) it is in the rules section, not the UI
Requirements or DCO table — a Workshop UI GDD author reading only UI-facing sections will
miss it; (b) the statefulness requirement — that Workshop UI must *store* the last-received
active_synergies set and compare on each signal receipt — is never stated; (c) Rule 7
cross-references "see Downstream Consumer Obligations" for debounce, but no DCO covers
change detection — the cross-reference is a dead pointer.
A Workshop UI GDD authored from only the UI Requirements and DCO table will specify a
stateless signal handler and produce thrashing animations on every rapid part swap.
This is an architectural contract gap (stateless vs. stateful subscriber), not a layout
concern — it cannot be adequately deferred without being named.

Fix: Add DCO-7 to the DCO table: "Workshop UI must maintain a local last-received
active_synergies set (initialized to empty). On each synergy_changed signal, diff received
active_synergies against stored set before triggering animations; update stored set after
comparison. Diffing bonus_block numeric equality alone is insufficient. An optional
debounce window (suggest 100–200ms starting value) may suppress animation triggers on
rapid part swaps — Workshop UI GDD's tuning decision." Fix the dead cross-reference in
Rule 7 to point to DCO-7.

---

## RECOMMENDED Issues (6 open)

**Issue C-debounce — Missing debounce window in Tuning Knobs (RECOMMENDED)**
Rule 7 diff semantics are correct. No debounce window appears in Tuning Knobs.
A starting range (100–200ms) should be named as a Workshop UI tuning decision,
either in Tuning Knobs or in the new DCO-7.

**Issue F — Combat UI Req 5 data acquisition path (RECOMMENDED)**
UI Req 5 now delegates display format and tier list visibility to Combat UI GDD. But
the data acquisition path remains unstated: how does Combat UI obtain cached_bonus_block?
From TBC (which calls evaluate_silent())? Via a direct read? Three review cycles.
Fix: Add one sentence to UI Req 5 or a new DCO: "Combat UI reads cached_bonus_block
via TBC, which establishes it at battle start via evaluate_silent()."

**Issue G — display_name null fallback unstated (RECOMMENDED)**
UI Req 4 adds display_name. DCO-6 defers character limit to Workshop UI GDD (acceptable).
But null/empty fallback behavior is a content data contract (this GDD's responsibility),
not a layout concern: what does the content data author put when display_name is absent?
Fix: State the fallback in the content data requirement — e.g., "If display_name is
null or empty, Workshop UI should render the raw tier ID in brackets as a content-error
marker (e.g., [volt_3_piece])."

**New 2 — Lower bound of 3 indicators is factually wrong (RECOMMENDED)**
"3–8 visible indicators maximum." A 1-element all-wild build produces exactly 2
build-relevant tiers; a single-part build produces 1. Rule 2 in this same GDD allows
these builds. The lower bound of 3 contradicts the GDD's own rules.
Fix: Change "3–8" to "1–8." If a UX design minimum of 3 is intended (panel density),
state it as an explicit design rule with rationale.

**New 3 — "Visually distinguishable" is a quality judgment, not a specification (RECOMMENDED)**
UI Req 3: "visually distinguishable from a plain stat delta (e.g., highlighted indicator
change)." The "e.g." removes normative force. "Distinguishable" has no minimum. The
requirement does not state what content the preview must communicate (which tier,
activation/deactivation, bonus gained/lost). Cannot pass accessibility checklist
(no reliance on color alone) without a defined non-color fallback.
Fix: Add minimum content requirements and "must not rely on color alone." Or explicitly
delegate: "specific presentation is a Workshop UI GDD decision; this system requires only
that a synergy threshold crossing is represented by a distinct element separate from the
base-stat delta row."

**New 4-gesture — DCO-3/DCO-4 gesture conflict unacknowledged (RECOMMENDED)**
DCO-3 defers "what gesture triggers preview()" to Workshop UI GDD. DCO-4 declares
indicators must be tappable. Neither DCO acknowledges that both compete for the same
gesture on the same indicator surface. Workshop UI GDD author must make an explicit
design choice here but will not know it is required.
Fix: Add a sentence to DCO-3 or DCO-4: "Note that the tap gesture on an indicator may
need to be shared or differentiated with the preview() trigger (see DCO-3); Workshop UI
GDD must make an explicit design decision at this intersection."

**New 7 — preview() empty-return ambiguous: error vs. no-synergy (RECOMMENDED)**
Rule 9: out-of-range slot returns empty bonus block. A valid preview with no synergy
change also returns empty bonus block. Workshop UI cannot distinguish the two cases.
Fix: Add one sentence to Rule 9: "Workshop UI should treat any empty return as 'no
synergy change' for display purposes and rely on the system content error log to
identify invalid slot-index calls during development."

---

**Why:** Found across four adversarial reviews (all 2026-07-10). Enumeration pass
corrected mid-review overcount. Only New 6 blocks Workshop UI GDD's signal handler
section. All other work on Workshop UI GDD (layout, visual design, indicator states)
is unblocked.

**How to apply:** Surface New 6 to GDD author for a DCO-7 addition — this is a text
fix, not a design decision. RECOMMENDED issues are GDD author precision fixes. The
Workshop UI GDD can begin; signal handler spec waits for New 6 resolution.

See also: [[workshop-ux-open-issues]], [[platform-constraints]], [[project-context]]
