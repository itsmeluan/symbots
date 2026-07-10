---
name: synergy-ux-open-issues
description: UX problems in Synergy System GDD after re-review #5 — 3 BLOCKING, 2 RECOMMENDED open; prior New 6 (DCO-7) resolved
metadata:
  type: project
---

Re-review #5 conducted 2026-07-10 against `design/gdd/synergy-system.md`.

---

## RESOLVED (as of re-review #5)

**New 6 (BLOCKING) — Change-detection statefulness**: DCO-7 now in GDD table with
exact stateful requirement (maintain `last_active_synergies` set, diff before animating,
diff on tier-ID set not bonus_block equality). Fully resolved.

Prior resolved items from reviews #1–4: E, H, A, B, D, New 1, New 4 (tappability), New 5,
C (diff semantics). See old memory for details.

---

## BLOCKING Issues (3 open as of re-review #5)

**Finding 1 — preview() null candidate_part undefined (BLOCKING)**
Rule 9 documents out-of-range slot error but is silent on `null` candidate_part.
Unequip-preview (the player previewing an empty slot) requires `preview(null, slot, parts)`.
A Workshop UI GDD author reading Rule 9 will assume null is either: (A) treated as empty
slot (correct, unstated), (B) an error (wrong — blocks unequip-preview feature), or (C) a
runtime crash (worst case). EC-SYN-09 covers same-part identity but not null candidate.
Fix: Add EC for null candidate_part: treated as empty slot, valid call, not an error.
Add one sentence to Rule 9 stating this.

**Finding 4 — Beat 3 binding has no testable criterion (BLOCKING)**
Beat 3 binding in Visual/Audio Requirements is normative prose ("treat as a requirement")
but has no AC in this GDD and no specification of what Workshop UI GDD must define.
The Workshop UI GDD is not started — if it is authored and approved without a Beat 3
criterion, there is no gate. The binding cannot survive QA without a testable form.
Fix: Add DCO-9 delegating Beat 3 criterion definition to Workshop UI GDD, marking it
as a required section before Workshop UI GDD is closed. Or define minimum criterion here
(e.g., animation distinct through non-color channel, triggered within N frames, held
for N frames minimum).

**Finding 5 — Combined-tier indicator visual correctness gap (BLOCKING)**
When Ironclad-VOLT 3-piece is active alongside Ironclad 3-piece + VOLT 3-piece, all
three tiers contribute additive bonuses per Rule 3. No DCO constrains how Workshop UI
must display the combined indicator relative to its constituents. The natural Workshop
UI solution to DCO-1 overflow (collapse/group) creates a correctness risk: grouped
display that visually implies the combined tier replaces constituents would mislead
players about the actual bonus structure (constituents are still active and additive).
DCO-2's example "combined listed after constituents" is illustrative, not normative.
Fix: Add constraint to DCO-2 or new DCO: "Combined synergy indicators must not visually
imply constituent synergy bonuses are replaced or deactivated. Additive stacking must
be unambiguous. Layout relationship is Workshop UI GDD's decision."

---

## RECOMMENDED Issues (2 open)

**Finding 2 — UI Req 3 "distinct visual element" content and accessibility undefined (RECOMMENDED)**
"Distinct visual element" names a modality but not content. Workshop UI GDD author could
implement a colored dot with no threshold name, direction, or bonus magnitude — technically
compliant but useless. No accessibility constraint (non-color fallback for color-blind modes).
Prior enumeration: New 3 from review #4. Still open.
Fix: Add minimum content: which tier, activation direction (gained/lost), bonus magnitude.
Add "must not rely on color alone." Or explicitly delegate with a named DCO.

**Finding 3 — UI Req 5 Combat UI missing data acquisition path (RECOMMENDED)**
UI Req 5 correctly delegates display decisions to Combat UI GDD but omits how Combat UI
obtains `cached_bonus_block`. TBC calls `evaluate_silent()` at battle start and holds the
result; Combat UI must get it from TBC, not SynergySystem directly. Unstated.
Prior enumeration: Issue F from review #3/4. Still open.
Fix: One sentence in UI Req 5: "Combat UI obtains cached_bonus_block through TBC, which
reads it from SynergySystem after evaluate_silent() at battle start."

---

## Items no longer tracked (were RECOMMENDED, still open in review #4)

**Issue C-debounce**: DCO-7 now includes "optional debounce window (suggested starting
value 100–200 ms)" — the suggested range is now in the GDD. Resolved.

**New 2 (lower bound "3" wrong)**: Still technically wrong (a single-part build produces
1 indicator). Low editorial priority — classify as open RECOMMENDED if GDD author wants
to address, but it does not block Workshop UI GDD authoring.

**New 4-gesture (DCO-3/DCO-4 gesture conflict unacknowledged)**: DCO-4 now explicitly
states "Gesture-conflict warning: DCO-3 and DCO-4 may compete for the same touch surface;
must resolve both gestures together." Resolved as of review #4 fix.

**New 7 (preview() empty return ambiguous)**: Rule 9 now states: "Consumers should treat
any empty return as 'no synergy change' for display purposes and rely on the content error
log to identify invalid slot-index calls during development." Resolved.

---

**Why:** Found across five adversarial reviews (all 2026-07-10). 3 items remain BLOCKING;
2 remain RECOMMENDED. Workshop UI GDD authoring is unblocked for layout and visual design
sections. Signal handler spec is unblocked (DCO-7 resolved). Beat 3 criterion (Finding 4)
and combined-tier display constraint (Finding 5) must be resolved before Workshop UI GDD
can be approved. null candidate_part (Finding 1) must be resolved before Workshop UI GDD's
unequip-preview interaction can be specified.

**How to apply:** Surface Findings 1, 4, 5 to GDD author as BLOCKING text fixes. All are
small additions (one EC, one DCO, one constraint sentence). Findings 2 and 3 are precision
improvements the GDD author can address at their discretion.

See also: [[workshop-ux-open-issues]], [[platform-constraints]], [[project-context]]
