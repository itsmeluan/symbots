# Review Log: Synergy System

## Review — 2026-07-10 (Re-review #6, Final) — Verdict: APPROVED
Scope signal: M (implementation — producer to verify); S for errata (applied in-session)
Specialists: game-designer, systems-designer, ux-designer, qa-lead, creative-director
Blocking items: 0 structural (18 claimed by specialists; 7 upheld as errata, all applied in-session) | Recommended: ~11 demoted/discharged
Summary: The CD's #5 prediction held — the design is structurally sound and APPROVED. The adversarial layer claimed 18 blockers; CD adjudicated 7 as genuine errata (all localized, none touching a Rule's semantics, formula, or interface): (1) EC-SYN-02 arithmetic error — pure 8-part concentration is 5 tiers, not 6 (the only factual correctness error found in the document); (2) GDScript StringName sort is not lexicographic — implementation note added to Rule 3 requiring String conversion before sort, plus AC-SYN-05b no-combined-tier fixture guard + active_synergies.size()==2 assertion; (3) cached_bonus_block initial state defined as empty block at construction (pre-evaluate reads safe — TBC-before-Workshop crash class); (4) active_synergies never-null guarantee added to Rule 7 + AC-SYN-07 assertion/FAIL line (null emission would crash DCO-7 consumers); (5) AC-SYN-06/10 consumer test ownership "or"→"AND" (both TBC and Workshop UI must implement independently); (6) UI Req 1 combined-tier dual-track progress state added (single "X/Y" misrepresents two independent thresholds; build-relevance requires ≥1 part per constituent tag); (7) UI Req 3 no-color-alone accessibility constraint (mandatory project standard, not deferrable). The other 11 claims: ux batch routed to Workshop UI GDD per the DCO framework; game-designer content-geometry/Beat-4-calibration discharged into existing OQ-2/OQ-7 hard constraints (fourth re-raise); qa batch demoted as test-hardening on unambiguous specs. CD PROCESS RULING (the #5 guardrail intervention, on the process axis): (i) this is the LAST full adversarial re-review — no re-review #7; (ii) future verification is fix-confirmation only on the 7 changed regions; (iii) retune the adversarial review prompt for mature documents (stop raising "test could be stronger" as BLOCKING). Status flipped to Approved in systems-index.
Prior verdict resolved: Yes — the #5 fix set held; 7 errata found and applied in same session; document Approved.

---

## Review — 2026-07-10 (Re-review #5, Revision Pass) — Verdict: NEEDS REVISION
Scope signal: S for the revision (M for implementation — producer to verify)
Specialists: game-designer, systems-designer, ux-designer, qa-lead, creative-director
Blocking items: 4 (all resolved in-session) | Recommended: ~10 (all resolved in-session — full-scope pass, same as #4)
Summary: The #4 fix set held (CD confirmed all 6 landed; zero regressions) but the predicted APPROVED did not materialize — the adversarial layer found 4 new defects, 3 of them false-confidence AC/contract-hygiene class: (1) AC-SYN-12's "(order-independent)" pass condition directly contradicted Rule 3/7's normative alphabetical ordering (qa, CD-verified against source — a wrong test, not a missing one; fixed to strict ordered equality); (2) keep-first dedup determinism was untested — AC-SYN-05's same-prefix fixture can't discriminate content-file-order iteration (sys≡qa independent discovery; AC-SYN-05b added with cross-prefix reverse-file-order fixture); (3) uncapped SYN-F4 invalidates DF-1's registered [1,165] output range — CD ruled uncapped is intended, fix is a contract note + tracked TBC obligation, registry edit is downstream errata (sys); (4) null candidate_part in preview() crashes on null.synergy_tags — the unequip-preview case, undefined in Rule 9 (ux≡qa independent discovery; Rule 9 sentence + EC-SYN-14 + AC-SYN-24). CD adjudications: all 3 game-designer design-gap blockers (Beat 2 content volume, element/manufacturer asymmetry, combined-synergy reachability) DISCHARGED as tracked obligations per the GDD's own DCO/OQ deferral philosophy — routed into upgraded OQ-7 (hard constraint on Part DB + Drop System) and OQ-2 (three calibration mandates); min_count>8 dead tier demoted (silent-safe, unlike the #4 min_count=0 false-activation). Recommended batch applied: effects never-null type guarantee; validator cross-tier effect-uniqueness + dev-log-on-discard; DCO-9 (Beat 3 testable criterion → Workshop UI GDD); DCO-2 combined-indicator constraint; UI Req 1 display_name/pending-bonus validation; Player Fantasy beat-ordering note; AC-SYN-14 Scenario B (combined through silent path); AC-SYN-17 FAIL line; AC-SYN-25 (no self-lock after evaluate_silent), AC-SYN-26 (effect pass-through), AC-SYN-27 (7-tier max-stress); EC-SYN-02/05 verified-by updates. CD guardrail: APPROVE expected on #6; new *structural* blockers at #6 would trigger a scope/process intervention.
Prior verdict resolved: Yes — 6 of 6 prior blockers held; 4 new blockers found and resolved in same session. Next: fresh-session re-review #6.

---

## Review — 2026-07-10 (Re-review #4, Revision Pass) — Verdict: NEEDS REVISION
Scope signal: S for the revision (M for implementation — producer to verify)
Specialists: game-designer, systems-designer, ux-designer, qa-lead, creative-director
Blocking items: 6 (all resolved in-session) | Recommended: 10 (all resolved in-session — full-scope pass chosen to avoid a review #6)
Summary: All 13 prior blockers confirmed resolved; none regressed. Six blockers upheld by CD, nearly all severity-upgrades of previously-RECOMMENDED debt: (1) min_count=0 vacuous activation — the non-empty-list guard misses it (sys, upheld; SYN-F2 invariant→min_count≥1, EC-SYN-13, AC-SYN-23); (2) null synergy_tags crashes `for tag in null` — EC-SYN-07 covered [] only (sys; null-guard + Part DB named invariant owner, AC-SYN-19 Scenario B); (3) integer claim had no enforcement owner — CD REVERSED the prior blocked-on-OQ-1 deferral as a false dependency (sys; dual enforcement: load validation + int() cast in SYN-F3, user-approved); (4) EC-SYN-07 no AC, third consecutive flag (qa; AC-SYN-19); (5) AC-SYN-13 no deactivation scenario — delta-approach preview bug passes all 18 prior ACs (qa; Scenario B added); (6) preview() out-of-range unverified + empty-return ambiguous (qa+ux merged by CD; AC-SYN-20 + Rule 9 semantics sentence). CD adjudications: game-designer's APPROVED overruled (correct in-lane, blind to impl/coverage defects); upgrading prior-RECOMMENDED on pass 4 ruled legitimate debt-calling, not goalpost-moving; systemic EC↔AC flag ruled to STRENGTHEN the block. ux-designer's initial 7-blocker claim was stale agent memory predating the DCO section — reconciled to 1 (DCO-7 statefulness, demoted by CD, fixed anyway). Recommended batch applied: DCO-7 (stateful diff + debounce) + DCO-8 (battle equip lockout, Workshop System owner); dead Rule 7 xref fixed; Symbol/Type/Range tables for SYN-F1…F4 (Range on min_count = structural prevention for blocker-1 class); "stateless" wording; fixture-divergence note; AC-SYN-14 note rewrite + shared-compute-core hint; AC-SYN-21/22; 7-tier cumulative budget constraint in Tuning Knobs + OQ-2; Beat 2/3/4/5 dependency/intent notes; DCO-3/4 gesture-conflict warning; every EC now carries a Verified-by AC reference (coverage ~90% direct, 100% referenced — clears the 80% standard).
Systemic process flag: NOW ACTIONABLE — CD directs the GDD-template amendment (every observable-outcome EC must reference a verifying AC + EC↔AC completeness check) be applied BEFORE the next GDD is authored. Three reviews vindicate it.
Prior verdict resolved: Yes — 13 of 13 prior blockers resolved; 6 new/upgraded blockers found and resolved in same session. Next: fresh-session re-review #5 (CD: high confidence APPROVED).

---

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
