---
name: synergy-ux-open-issues
description: UX problems in Synergy System GDD after re-review #6 — 6 BLOCKING, 3 RECOMMENDED open; 3 reclassified or added new
metadata:
  type: project
---

Re-review #6 conducted 2026-07-10 against `design/gdd/synergy-system.md`.

---

## RESOLVED (as of re-review #5 and earlier)

**New 6 (BLOCKING) — Change-detection statefulness**: DCO-7 now in GDD table with
exact stateful requirement (maintain `last_active_synergies` set, diff before animating,
diff on tier-ID set not bonus_block equality). Fully resolved.

Prior resolved items from reviews #1–4: E, H, A, B, D, New 1, New 4 (tappability), New 5,
C (diff semantics). See old memory for details.

---

## BLOCKING Issues (6 open as of re-review #6)

**Finding 1A (NEW, re-review #6) — 3-state indicator information density vs. 44×44pt tap target**
UI Req 1's State 2 indicator requires 9 discrete data fields ("Ironclad: 4/5 — +8 Armor active |
1 more for Armor +20"). At minimum legible font sizes on iPhone, this cannot fit in a 44×44pt
tap target. The GDD treats density and tap-target size as independent — they are not.
DCO-4's ~42% iPhone height estimate is calculated under the minimum tap target, but the
real height will be larger once information density forces a taller indicator card.
Fix: UI Req 1 must acknowledge the density/target tradeoff. Either (A) declare indicator height
may exceed 44pt with the tappable zone being 44×44pt minimum and revise DCO-4's estimate, or
(B) declare compact view collapses to a single-line summary with full detail on tap (aligning
with DCO-4 tappability). Without this, the spec is internally contradictory on iPhone.

**Finding 1B (NEW, re-review #6) — Zero-match indicator: Beat 2 discoverability gap**
UI Req 1 hides tiers with 0 matching parts. A player who starts with 0 Ironclad parts never
sees the Ironclad indicator exist, so may not know to hunt for Ironclad parts. Beat 2 (The Hunt)
assumes the player knows what to hunt for. The GDD acknowledges the inverse problem (accidental
Beat 3 without Beat 1–2) but not this gap: the hunt cannot begin if the player doesn't know the
synergy exists. DCO-5 and DCO-1 are adjacent but do not address zero-match discoverability.
Fix: Add DCO delegating "how the player discovers synergy types with 0 current matching parts"
to Workshop UI GDD, OR explicitly accept this as a loot-exposure-only beat with a note that
Beat 2 relies entirely on drop exposure for zero-match synergies.

**Finding 2 (re-review #4, RECLASSIFIED to BLOCKING in re-review #6) — UI Req 3 "distinct visual element" underspecified + missing accessibility constraint**
"Distinct visual element" names a modality but not content. Workshop UI author can implement a
colored dot — technically compliant, practically useless. No non-color fallback — violates project
accessibility standard "Functional without reliance on color alone." Also: the display relationship
between synergy preview change and stat delta is undefined (whether they coexist or one suppresses
the other has no spec).
Fix: UI Req 3 must add: minimum content (which tier, activation direction, bonus magnitude);
display relationship (both synergy change and stat delta visible simultaneously); "must not rely
on color alone as sole channel for distinguishing synergy change from stat delta."

**Finding 4 (re-review #3, still BLOCKING) — DCO-9 Beat 3 testable criterion has no minimum bar**
DCO-9 delegates testable criterion to Workshop UI GDD but does not constrain what that AC must
specify. A Workshop UI author can satisfy DCO-9 with "a visual change occurs for 1 frame" — technically
testable, fails the Beat 3 intent. "Clearly perceptible" is undefined.
Fix: DCO-9 must add minimum bar: (i) animation must include motion or brightness change through
non-color channel; (ii) minimum hold duration (suggest 400ms floor, tunable by Workshop UI GDD);
(iii) audio cue must accompany visual and be suppressible only at system audio level.

**Finding 5 (re-review #3, still BLOCKING) — DCO-2 combined-tier indicator: additive stacking must be visually unambiguous**
DCO-2 says combined-tier indicator must not imply constituent tiers are deactivated — but "must read
as such" is not testable. A grouped card showing all three names could satisfy DCO-2's letter while
still implying a single combined entity rather than additive bonuses. The arithmetic (3 active tiers,
each additive) is not required to be visible — only that all three "read as active."
Fix: DCO-2 must add: "The indicator panel must make additive stacking visible — the player must
be able to confirm that the combined tier adds to, not replaces, constituent tier bonuses. A grouped
display showing combined bonus but not constituent bonuses violates this constraint regardless of
label text."

**Finding 7A (NEW, re-review #6) — UI Req 1's three indicator states assume single-track progress; combined tiers have two independent tracks**
The three indicator states (Active/Active+Next/Inactive) all use a single-track "X/Y — N more" format.
Combined tiers have two independent requirements (e.g., Ironclad ≥ 3 AND VOLT ≥ 3). A build with
Ironclad=3, VOLT=1 is in an undefined indicator state: the tier is inactive but progress is not a
single "2/6" number — it is "Ironclad: done, VOLT: 1/3." No indicator state in UI Req 1 handles this.
Also: UI Req 1's build-relevance rule ("at least 1 part with a matching tag") is ambiguous for combined
tiers — does the Ironclad-VOLT indicator show if the build has only Ironclad parts but 0 VOLT parts?
Fix: UI Req 1 must address combined tiers explicitly. Options: (A) define a fourth indicator state
for combined tiers with multi-track progress display; (B) tighten build-relevance for combined tiers
to require all constituent tags present at ≥ 1 count each; (C) delegate to Workshop UI GDD as new DCO.
Current spec is silent on both the state definition and the relevance threshold for combined tiers.

---

## RECOMMENDED Issues (3 open)

**Finding 3 (re-review #3, still RECOMMENDED) — UI Req 5 Combat UI missing data acquisition path**
UI Req 5 correctly delegates display decisions to Combat UI GDD but omits how Combat UI obtains
`cached_bonus_block`. Combat UI must get it through TBC (which calls evaluate_silent() at battle
start), not by subscribing to synergy_changed (which does not fire during battle). A Combat UI
author who subscribes to the signal sees no synergy data and may display zero bonuses — technically
compliant if the spec never states the acquisition path.
Fix: Add to UI Req 5: "Combat UI obtains cached_bonus_block through Turn-Based Combat, which reads
it from SynergySystem after evaluate_silent() at battle start. Combat UI must not subscribe to
synergy_changed for battle-time display — the signal does not fire during battle."

**Finding 5A (NEW, re-review #6) — DCO-2 display order is fully open; active-before-inactive is example not requirement**
DCO-2's suggested priority rule is parenthetical ("e.g., active-before-inactive; ..."). Workshop UI
GDD has complete latitude to display in any order. If active tiers are buried below inactive tiers,
Beat 1 (Recognition) and Beat 3 (The Click) are weakened — the activating indicator may not be
visually prominent.
Fix: Add to DCO-2: "UX priority rule must satisfy at minimum: active tiers are displayed before
inactive tiers in the visible panel. All other ordering decisions belong to the Workshop UI GDD."

**Finding 7B (NEW, re-review #6) — V/A Requirements "greyed-out preview" conflicts with UI Req 3 "distinct visual element"**
V/A event table says preview activation shows a "greyed-out 'would activate' indicator" — low emphasis,
passive. UI Req 3 says threshold changes must be a "distinct visual element" — suggesting prominent,
attention-calling. These are reconcilable but the GDD never reconciles them. Workshop UI GDD author
could implement a greyed-out preview that is visually identical to an inactive-tier indicator (satisfying
V/A table) but fails UI Req 3's distinctness intent.
Fix: Add to V/A Requirements entry or UI Req 3: "The preview indicator (greyed-out 'would activate'
state) must still satisfy UI Req 3's distinctness requirement — the player must be able to visually
distinguish between a stat-only preview change and a synergy-threshold preview change."

**Finding 7D (NEW, re-review #6) — Stat display name aliases not scoped in DCO-6**
DCO-6 covers tier display_name character limit and null fallback but not bonus display strings.
Stat keys in stat_delta are internal IDs (e.g., `armor`, `energy_power`). Bonus display strings
like "Armor +8" require human-readable aliases. DCO-6 is silent on where these come from. A long
stat ID ("max_shield_regen_rate +20") in State 2 text can overflow the indicator layout.
Fix: Expand DCO-6 to note: "Stat keys in stat_delta are internal identifiers. Bonus display strings
must use human-readable stat labels. Whether stat display labels are defined in Synergy Content data,
Assembly schema, or a shared localization table is a Workshop UI GDD and OQ-1 decision."

---

## NICE-TO-HAVE (1 item)

**Finding 7C — DCO-1 silent-drop ban has no enforcement path**
DCO-1 forbids silent-drop but the ban is only discoverable at Workshop UI GDD review time.
This is inherent to the deferred-obligation model. The review process is the intended gate.
No fix needed in this GDD.

---

**Why:** Found across six adversarial reviews (all 2026-07-10). 6 items BLOCKING; 3 RECOMMENDED.
Net new in re-review #6: Findings 1A, 1B, 7A (new BLOCKING); Findings 5A, 7B, 7D (new RECOMMENDED);
Finding 2 reclassified from RECOMMENDED to BLOCKING (accessibility gap is project standard violation).

**How to apply:** Surface Findings 1A, 1B, 7A to GDD author as new BLOCKING text fixes before
Workshop UI GDD is started. Finding 2 accessibility gap is a project-standard violation — must be
fixed before Workshop UI GDD can be approved. Findings 4 and 5 remain the same fixes as prior
reviews — small additions to DCO-9 and DCO-2. Findings 3, 5A, 7B, 7D are precision improvements.

See also: [[workshop-ux-open-issues]], [[platform-constraints]], [[project-context]]
