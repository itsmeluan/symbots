# Review Log: Synergy System

## Review — 2026-07-10 (Re-review #3, Revision Pass) — Verdict: NEEDS REVISION
Scope signal: M (down from L — remaining work is localized EC/AC/text edits, no redesign)
Specialists: game-designer, systems-designer, ux-designer, qa-lead, creative-director
Blocking items: 13 (all resolved in-session) | Recommended: ~10 (deferred to re-review #4)
Summary: All 6 prior blockers confirmed resolved. 13 new/carried blocking items — none structural; CD assessed the doc as **converging, not churning**. Notably 7 of the 13 were RECOMMENDED items carried from review #2 that had survived unfixed. Top item (game-designer N1, lead-verified): EC-SYN-03's tradeoff rationale was mechanically false — it claimed wild parts prevent combined synergies, but SYN-F2 checks two INDEPENDENT tag counts with no co-location requirement. Author confirmed independent-counts is the intended design → resolved as documentation fix (rewrote EC-SYN-03), no MAJOR REVISION. Registration order (flagged by 3 agents independently) defined as ascending-alphabetical-by-tier-ID (author decision; chosen over file-order/explicit-field because content format OQ-1 is unresolved). Fixes: EC-SYN-03 rewrite; Beat 1 +15→+8 harmonized to AC anchor; registration-order definition in Rule 3 (+ Rule 7/SYN-F3 refs); EC-SYN-11 (duplicate tags) & EC-SYN-12 (empty requirements) added; Rule 7 change-detection contract (diff on active_synergies, not bonus_block equality); new "Downstream Consumer Obligations" section (DCO-1…6) explicitly delegating UI-scoped ux blockers to Workshop UI/Combat UI GDDs; AC-SYN-04 rewritten to observable outputs; AC-SYN-06/10 labeled consumer-owned; AC-SYN-12 size() assertion; AC-SYN-16 (unique combined effect preserved), AC-SYN-17 (unknown stat key no-crash), AC-SYN-18 (wrong-length array) added; SYN-F2 safe-access note. Deferred RECOMMENDED: Beat 4 tradeoff-at-floor (N4), stat_delta budget cap (N10), "stateless" wording + Rule 8 freeze enforcement (N11/F8), float-infiltration owner (blocked on OQ-1), OQ-6 re-open, coverage/precision items.
Systemic process flag (qa-lead, endorsed by CD): Edge Cases defining "no crash on bad input" have shipped without corresponding ACs across ALL THREE Synergy reviews. This is a GDD-template gap, not a per-doc defect — recommend amending the GDD standard so every observable-outcome EC references a verifying AC, plus an EC↔AC check in the completeness pass.
Prior verdict resolved: Yes — 6 of 6 prior blockers resolved; 13 new/carried blockers found and resolved in same session. Next: fresh-session re-review #4 (expected to converge to APPROVED).

---

## Review — 2026-07-10 (Re-review, Revision Pass) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, ux-designer, qa-lead, creative-director
Blocking items: 6 (all resolved in-session) | Recommended: 7+
Summary: First re-review after the MAJOR REVISION. All four prior blockers confirmed resolved. Six new blocking items identified, none structural: EC-SYN-02 "10 simultaneous tiers" proved wrong (true maximum is 7 — three manufacturers can't all hit 3-piece in 8 slots); Beat 5 Mastery promised cross-Symbot team synergy that Rule 1 prohibits (rewritten to single-Symbot mastery); Beat 1 vs UI Req 1 contradiction on inactive indicator format (Beat 1 showed bonus value, UI Req 1 showed count only — both updated to 3-state spec with pending bonus value always visible); "active + progressing" indicator state was unspecified (added as third state); evaluate_silent() had no AC (AC-SYN-14 added); deactivation path had no AC (AC-SYN-15 added). OQ-6 closed: SA-F2 confirmed as delta; composition formula documented. OQ-7 added for catalog-size constraint (deferred to Part Database content authoring).
Prior verdict resolved: Yes — 4 of 4 prior blockers resolved; 6 new blockers found and resolved in same session.

### Blocking items (resolved before next re-review):
- B2: Beat 5 promised team synergies Rule 1 prohibits → FIXED: rewrote to single-Symbot mastery; marked team synergy as Vertical Slice
- S1: EC-SYN-02 "up to 10 tiers" wrong → FIXED: corrected to "7 tiers (verified maximum)"
- U4: Beat 1 shows bonus value in inactive indicator; UI Req 1 showed count only → FIXED: UI Req 1 now has 3-state spec with pending bonus value required in all non-active states
- U5: "Active + progressing toward next tier" state undefined → FIXED: defined as third indicator state in UI Req 1
- Q1: No AC for evaluate_silent() → FIXED: AC-SYN-14 added
- Q2: No deactivation AC → FIXED: AC-SYN-15 added

### Open items for re-review to verify:
- game-designer RECOMMENDED: Beat 4 (Tradeoff) structurally weak at 3-piece threshold; tier evaluation order not yet specified in rules; wild parts EC-SYN-03 tradeoff rationale; cumulative stacking percentage cap for content authors
- systems-designer RECOMMENDED: Cross-synergy effect deduplication AC (no AC tests combined synergy effect not suppressed when using unique ID); float infiltration risk via content data stat_delta values; OQ-6 formula stale-cache precondition
- qa-lead RECOMMENDED: AC-SYN-04 tests internal tag_count (not public API); AC-SYN-06/AC-SYN-10 misclassified (SYN-F4 consumer formula, not Synergy System); AC-SYN-12 missing explicit size() assertion
- ux-designer RECOMMENDED: Combat UI Req 5 is one sentence with no consumable contract; display_name character limit and null fallback not specified

---

## Review — 2026-07-10 — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, ux-designer, qa-lead, creative-director
Blocking items: 4 | Recommended: 7+
Summary: The system's machinery (SYN-F1–F4, cumulative stacking, 8 of 13 ACs) was close to sound, but Section B described a 3-piece activation experience while SYNERGY_THRESHOLD_TIER1=2 defined a 2-piece threshold — the player-facing fantasy and the rule were contradictory. A second blocker was the wild-parts dominant strategy: players can double-dip element and manufacturer synergies simultaneously with no tradeoff, undocumented. Two implementation blockers: active_synergies signal parameter untyped, and preview() slot-displacement unspecified. All 4 blocking items were resolved in the same session. TIER1 raised from 2→3, TIER2 from 4→5; evaluate_silent() added for TBC battle-start; section renamed to "Detailed Rules"; 5 weak ACs fixed; 10 AC fixtures updated for new thresholds.
Prior verdict resolved: No — first review

### Blocking items (resolved before re-review):
- A1: Player Fantasy described 3-piece activation; TIER1=2 defined 2-piece → FIXED: TIER1→3, TIER2→5 throughout GDD and entities.yaml
- A2: active_synergies signal parameter untyped → FIXED: Array[StringName] type + ordering rule added to Rule 7
- A3: preview() slot-displacement contract missing; no out-of-range behavior → FIXED: Rule 9 now explicit on both
- A4: Wild parts dominant strategy (double-dip element+manufacturer) undocumented → FIXED: EC-SYN-03 rewritten as intended design

### Key recommended fixes also applied:
- evaluate_silent() added for TBC battle-start (prevents spurious synergy_changed at battle start)
- EC-SYN-02 max simultaneous tiers corrected (10, not 6)
- UI Req 1 scoped to build-relevant tiers (3–8 max, not all 30)
- Combined 4-piece explicitly excluded from MVP (Rule 3)
- OQ-6 added: verify SA-F2 return type before Workshop UI GDD
- Effect display_name ownership assigned to Synergy Content data

### Open items for re-review to verify:
- systems-designer CRITICAL-3 (SA-F2 + preview() composition ambiguity) — demoted to pending-verification by creative-director; verify SA-F2 return type from Assembly GDD before re-reviewing
- qa-lead: 6 missing AC scenarios not yet added (deactivation test, three-synergy payload, max-concentration, wrong-length array, same-part preview, and EC-SYN-07 empty tags) — flagged P3/P4; re-review should assess if any are blocking
