---
name: synergy-ux-open-issues
description: UX problems in Synergy System GDD after re-review #3 — 7 BLOCKING, 4 RECOMMENDED; 3 issues resolved (E, H, A); blocks Workshop UI GDD synergy section
metadata:
  type: project
---

Third adversarial review conducted 2026-07-10 against `design/gdd/synergy-system.md`.
Prior verdict: 5 BLOCKING, 3 RECOMMENDED. This re-review found 3 resolved, 4 still open,
and 5 new issues (3 BLOCKING, 2 RECOMMENDED) for a net of 7 BLOCKING, 4 RECOMMENDED.

---

## RESOLVED (closed in re-review #3)

**Issue E — Beat 1 vs. UI Req 1 bonus value**: FIXED. UI Req 1 now requires pending
bonus value in inactive indicator state, matching what Beat 1 always promised. Closed.

**Issue H — "Active + progressing toward next tier" indicator state**: FIXED. UI Req 1
now defines all three indicator states including the active+progressing case with example
format. Closed.

**Issue A — "30 theoretical tiers" wrong count**: FIXED. Now reads "21 theoretical
tiers" with correct MVP breakdown. Closed.

---

## BLOCKING Issues

**Issue B — Overflow behavior for >8 build-relevant tiers (BLOCKING)**
UI Req 1 caps visible indicators at 8 with no overflow behavior defined. EC-SYN-02
shows up to 7 simultaneously active tiers; a build with partial lines can produce 8–10
build-relevant tiers (≥1 matching part). What happens to tier 9 and 10? Silent hide,
scroll, or priority-sort? Silent hiding breaks Beat 1 (Recognition). Not fixed in
re-review #3.

Decision needed: Overflow behavior and player awareness when indicators are hidden.

**Issue C — Change detection contract undefined (BLOCKING)**
Visual/Audio table says "implement own change detection" with no debounce window and no
diff semantics. "Rapid" is still undefined. Diffing by bonus_block equality incorrectly
suppresses animations when active tier set changes but total bonus stays equal. Not fixed
in re-review #3.

Decision needed: (a) Recommended debounce window (add to Tuning Knobs table). (b) Diff
must be on active_synergies set equality, not bonus_block equality.

**Issue D — preview() trigger model not implementable on iOS (BLOCKING)**
UI Req 3 says "when previewing a part swap, call preview()" with no touch trigger model
specified or explicitly delegated. Workshop UI GDD cannot design "when" from current text.
Not fixed in re-review #3.

Decision needed: Specify touch trigger (tap-to-preview-mode, long-press, drag-and-hold)
or explicitly delegate: "trigger model is Workshop UI GDD's decision, hover-based triggers
are not permitted."

**NEW 1 — Indicator ordering unspecified (BLOCKING)**
UI Req 1 defines 3 states but no sort order for up to 8 visible indicators. The
`synergy_changed` signal delivers IDs in "synergy-definition registration order" — a
content-authoring concern, not a UX concern. Rendering in signal order hands a UX
decision to content authors. Active vs. inactive ordering, single-tag vs. combined
ordering, and within-group ordering are all undefined.

Decision needed: Priority rule — e.g., "active tiers before inactive; within each group,
highest tag count first; combined synergies listed after their constituents."

**NEW 4 — Indicator panel touch ergonomics: zero constraints (BLOCKING)**
UI Req 1 (indicators) and UI Req 4 (effect names) together imply indicators must be
individually tappable to reveal effect lists. But no tap interaction is specified. If
indicators require 44×44pt touch targets, 8 stacked indicators = 352pt — 42% of iPhone
height — before the build grid, part list, and stat panel. No collapsed/expanded state
for the panel is specified either.

Decision needed: (a) Are indicators individually tappable? (b) If yes, how does the
effect list surface (tap-to-expand row? modal overlay?). Without these constraints,
Workshop UI GDD cannot design the panel layout correctly.

**NEW 5 — "In reach" is undefined in indicator state 2 (BLOCKING)**
UI Req 1's second indicator state: "Active tier (next threshold in reach)." "In reach" is
never defined. Three plausible interpretations: (A) any next tier exists in content data;
(B) player is within N parts of the threshold; (C) next tier achievable within remaining
empty slots. Interpretations A, B, C produce different indicator text for the same build.
The example ("1 more for Armor +20") implies B but does not define the boundary or N.

Decision needed: Define "in reach" — either "a next tier exists in content data" (always
show) or a specific slot-proximity rule (e.g., "within 2 empty slots of the threshold").

---

## RECOMMENDED Issues

**Issue F — Combat UI requirement is one sentence with no consumable contract (RECOMMENDED)**
UI Req 5 (two sentences) still has three gaps: no display location, no breakdown format
("Armor 53" vs. "Armor 40 + 13 synergy"), and no spec on whether the active tier list is
visible during battle. Two review cycles without resolution. If intentionally delegated,
the delegation must be explicit so Combat UI GDD authors know they own it.

Fix: Add three sentences covering location, attribution format, tier list accessibility.
Or explicitly delegate all three to the Combat UI GDD.

**Issue G — display_name content requirement incomplete (RECOMMENDED)**
UI Req 4 adds display_name but omits: (a) max character length (suggest 20 chars for
indicator width), (b) null/empty fallback (suggest: show tier ID in brackets as
content-error marker), (c) localization note (single-language string is an implicit
decision that should be explicit even if "English-only in MVP").

**NEW 2 — Lower bound of 3 indicators unjustified (RECOMMENDED)**
UI Req 1 says "3–8 visible indicators maximum." Lower bound of 3 is unjustified — an
all-wild-VOLT build produces exactly 2 build-relevant tiers (VOLT 3-piece + VOLT 5-piece).
No game design guarantee exists that a build produces ≥3 build-relevant tiers. Lower
bound should be 1 or the guarantee must be documented.

**NEW 3 — "Visually distinguishable" in swap preview is exemplary not normative (RECOMMENDED)**
UI Req 3: "visually distinguishable from a plain stat delta (e.g., a highlighted indicator
change)." The e.g. is not a requirement. "Highlighted" is undefined. The requirement does
not specify what information the preview must communicate (which synergy, what bonus, why).
If delegation to Workshop UI GDD is intentional, state it explicitly. If not, add minimum
constraints.

---

**Why:** Found during three rounds of adversarial review (rounds 1-3 all 2026-07-10).
Issues B, C, D, New 1, New 4, New 5 must be resolved before `design/ux/workshop.md`
synergy section is authored. Issues F, G must be resolved before Combat UI GDD is
authored. Issues New 2, New 3 are precision gaps the GDD author can fix without design
decisions.

**How to apply:** Surface BLOCKING issues to game designer for decisions. RECOMMENDED
issues are GDD author fixes. Workshop UI GDD is blocked until all 7 BLOCKING issues
are resolved.

See also: [[workshop-ux-open-issues]], [[platform-constraints]], [[project-context]]
