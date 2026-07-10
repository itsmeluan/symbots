---
name: synergy-ux-open-issues
description: UX problems in Synergy System GDD after re-review #4 — 7 BLOCKING, 5 RECOMMENDED; 3 resolved (E/H/A); 0 resolved in re-review #4; Workshop UI GDD blocked
metadata:
  type: project
---

Re-review #4 conducted 2026-07-10 against `design/gdd/synergy-system.md`.
Prior verdict (re-review #3): 7 BLOCKING, 4 RECOMMENDED.
Re-review #4 verdict: 0 resolved, 1 new BLOCKING (New 6), 1 new RECOMMENDED (New 7).
Net: **7 BLOCKING, 5 RECOMMENDED**.

---

## RESOLVED (closed in re-review #3)

**Issue E — Beat 1 vs. UI Req 1 bonus value**: FIXED. Closed.
**Issue H — "Active + progressing" indicator state**: FIXED. Closed.
**Issue A — "30 theoretical tiers" wrong count**: FIXED. Closed.

---

## BLOCKING Issues

**Issue B — Overflow behavior for >8 build-relevant tiers (BLOCKING)**
UI Req 1 caps visible indicators at 8 with no overflow behavior defined. A build with
partial synergy lines can produce 8–10 build-relevant tiers. What happens to tier 9+?
Silent hide, scroll, or priority-sort? Silent hiding breaks Beat 1 (Recognition).
Decision needed: overflow behavior and player awareness when indicators are hidden.

**Issue C — Change detection contract undefined (BLOCKING)**
Visual/Audio table says "implement own change detection" with no debounce window and no
diff semantics. "Rapid" is undefined. Diffing bonus_block equality incorrectly suppresses
animations when active tier set changes but total bonus stays equal.
Decision needed: (a) Recommended debounce window in Tuning Knobs. (b) Diff must be on
active_synergies set equality, not bonus_block equality.

**Issue D — preview() trigger model not implementable on iOS (BLOCKING)**
UI Req 3 says "call preview()" with no touch trigger model specified or delegated.
Workshop UI GDD cannot design "when" from current text.
Decision needed: Specify touch trigger or explicitly delegate to Workshop UI GDD with
prohibition on hover-based triggers.

**New 1 — Indicator ordering unspecified (BLOCKING)**
UI Req 1 defines 3 states but no sort order. Signal delivers IDs in alphabetical-by-ID
order — a content concern, not a UX concern. Active vs. inactive ordering, single-tag vs.
combined ordering, and within-group ordering are undefined.
Decision needed: Priority rule (e.g., active before inactive; within group, highest tag
count first; combined listed after constituents).

**New 4 — Indicator panel touch ergonomics: zero constraints (BLOCKING) + DCO-3/DCO-4 conflict**
UI Req 1 (indicators) and UI Req 4 (effect names) imply indicators must be tappable. But
no tap interaction is specified. 8 × 44pt = 352pt = 42% of iPhone height before build
grid, part list, and stat panel. No collapsed/expanded panel state specified.
NEW sub-issue (re-review #4): DCO-3 (preview trigger) and DCO-4 (indicator tappability)
compete for the same gesture on the same surface. Tapping an indicator could mean "reveal
effect list" (DCO-4) or "begin swap preview for this tag" (DCO-3). Workshop UI GDD cannot
arbitrate two competing obligations from this GDD. The Synergy GDD must declare which
action the indicator tap performs, or explicitly grant Workshop UI GDD authority to choose.
Decision needed: (a) Are indicators tappable? (b) Tap action: reveal effect list, preview
trigger, or sequenced flow? (c) DCO-3/DCO-4 gesture conflict must be resolved here.

**New 5 — "In reach" undefined in indicator state 2 (BLOCKING)**
UI Req 1's second state: "Active tier (next threshold in reach)." Three plausible
interpretations: (A) any next tier exists in content; (B) within N parts of threshold;
(C) achievable within remaining empty slots. Example implies B but does not define N.
Decision needed: Define "in reach" — "any next tier exists" or a specific slot-proximity
rule.

**New 6 — Change-detection statefulness requirement buried and incomplete (BLOCKING)**
Re-review #4. Rule 7 contains correct guidance: diff on active_synergies set, not
bonus_block equality. But: (a) it is in the rules section, not the UI Requirements or DCO
table, so a Workshop UI GDD author reading only UI-facing sections will miss it; (b) the
statefulness requirement — that Workshop UI must *store* the last-received active_synergies
and compare sets on each signal receipt — is never stated. A stateless subscriber design
will cause animation thrashing on every rapid swap.
Decision needed: Move change-detection contract to UI Requirements or add as DCO. Add
explicit statefulness requirement: "Workshop UI must maintain the last-received
active_synergies set as local state."

---

## RECOMMENDED Issues

**Issue F — Combat UI requirement is one sentence with no consumable contract (RECOMMENDED)**
UI Req 5 still has three gaps: (1) data acquisition path (how Combat UI obtains
cached_bonus_block — from TBC or direct?), (2) attribution format ("Armor 53" vs.
"Armor 40 + 13 synergy"), (3) tier list visibility during battle. None of these are in
the DCO table. Three review cycles without resolution.
Fix: Add delegation sentences covering location, acquisition path, attribution format,
tier list accessibility — or add DCO-7/DCO-8/DCO-9.

**Issue G — display_name content requirement incomplete (RECOMMENDED)**
UI Req 4 omits: (a) max character length, (b) null/empty fallback behavior, (c)
localization note (English-only is an implicit decision that should be explicit).

**New 2 — Lower bound of 3 indicators is factually wrong (RECOMMENDED)**
"3–8 visible indicators maximum." A 1-element all-wild build produces exactly 2
build-relevant tiers (VOLT 3-piece + VOLT 5-piece). A single-part build produces 1.
No game design guarantee exists that any build produces ≥3 build-relevant tiers. The
lower bound of 3 contradicts the GDD's own rules.
Fix: Change "3–8" to "1–8." If a UX minimum of 3 is intended (always show 3 indicators
for panel density), state it as an explicit design rule with the rationale.

**New 3 — "Visually distinguishable" is a quality judgment, not a specification (RECOMMENDED)**
UI Req 3: "visually distinguishable from a plain stat delta (e.g., highlighted indicator
change)." The "e.g." removes binding force. "Distinguishable" is a quality judgment with
no minimum. The requirement does not state what content the preview must communicate
(which tier, activation or deactivation, bonus gained/lost). Cannot pass accessibility
checklist without a defined non-color fallback.
Fix: State minimum content requirements and add "must not rely on color alone." Or
explicitly delegate: "specific presentation is a Workshop UI GDD decision."

**New 7 — preview() empty return ambiguous: content error vs. no synergy (RECOMMENDED)**
Re-review #4. Rule 9: out-of-range slot returns an empty bonus block. A valid preview
call on a part with no matching synergy also returns an empty bonus block. Workshop UI
cannot distinguish "no synergy" from "invalid call" — both display as "no change."
Fix: Either differentiate return values (null for error, empty block for valid no-synergy)
or state explicitly that Workshop UI is not expected to distinguish these cases and should
display "no change" for both.

---

**Why:** Found across four rounds of adversarial review (all 2026-07-10).
Issues B, C, D, New 1, New 4, New 5, New 6 must be resolved before
`design/ux/workshop.md` synergy section is authored. Issues F, G must be resolved
before Combat UI GDD is authored. Issues New 2, New 3, New 7 are precision gaps.

**How to apply:** Surface all BLOCKING issues to game designer. RECOMMENDED issues are
GDD author fixes (no design decision required). Workshop UI GDD is blocked until all
7 BLOCKING issues are resolved.

See also: [[workshop-ux-open-issues]], [[platform-constraints]], [[project-context]]
