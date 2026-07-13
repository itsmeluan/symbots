# World Loot System — Review Log

## Review — 2026-07-13 — Verdict: APPROVED (NEEDS REVISION → fixed & accepted same session)
Scope signal: M
Specialists: systems-designer, game-designer, qa-lead, economy-designer, creative-director (senior synthesis)
Blocking items: 7 | Recommended: 22 (across panel; key ones folded in)
Prior verdict resolved: First review

**Summary:** First full-panel review of the lean-authored World Loot GDD. Mechanically strong (clean EP domain contract, thorough ECs, discriminating fixtures) but shipped one save-breaking contract bug and two pillar-guardrail holes. All 7 blockers fixed same session:

1. **[systems-designer] BLOCKING — save-breaking type contract.** WL Rule 7 `snapshot()→Array[StringName]` violated the already-Approved EP Rule 3 (`snapshot()→Dictionary`; non-Dictionary → save REFUSED per EP AC-EP-12; wrong-type sub-blob → `restore({})` wipes loot per EP Rule 6d). A registered world_loot domain could not save and any load zeroed collection. **Fix (Option A):** snapshot returns `{"collected": <sorted Array>}`, restore reads `data.get("collected", [])`. No EP change. Cascaded to WL-PRED-3, EC-WL-08, AC-WL-06/07/08/10/11 fixture forms.
2. **[economy-designer + game-designer CONVERGENT] BLOCKING — Scrap guardrail unenforceable** (~180 target, realistic worst case 5×60 = 300). **Fix:** `WORLD_SCRAP_CEILING = 180` constant + WL-PRED-2 per-zone Scrap-sum content-validation clause.
3. **[game-designer + economy-designer CONVERGENT] BLOCKING — Pillar 2 RARE bypass** of Drop System's ×0.5 early-Rare throttle. **Fix (user decision):** DDR-WL-1 accepts one early RARE/zone as intentional authored discovery (throttle governs the combat faucet, not authored placement). economy-designer dissented (preferred a hard core-level gate) — logged, revisit at playtest.
4. **[game-designer] BLOCKING — zero-PART-zone Pillar 5 hole.** **Fix (user decision):** min-1-PART-per-zone WL-PRED-2 content-validation clause.
5. **[game-designer] BLOCKING — silent COLLECTED-node interaction** reads as a bug. **Fix:** "already emptied" ambient cue (Visual/Audio + EC-WL-01), scoped to Overworld Nav's gesture layer; `collect()` stays a silent logic no-op.
6. **[qa-lead] BLOCKING — 7 AC gaps.** Most consequential: AC-WL-11 asserted only `can_collect`, missing derived-visual-state desync (likely shipping bug). **Fix:** new Rule 9.4 `get_node_state()` accessor + AC-WL-11 dual assertion; AC-01 per-node counting; AC-03/05 warning-content `.contains()`; AC-05 independent-catalog + count; AC-06 `&`-StringName literals + type guards + Dictionary envelope; AC-08 sort re-validation; AC-09 non-reset counter; AC-02/07/10 sink-silence counts.
7. **[systems-designer] BLOCKING — 2 internal contradictions.** Rule 5 "load aborts" vs Rule 9.3 structured-result → reworded; `collect()` branching order documented so AC-WL-02/03 derive from rules.

**Recommended folded in:** SCRAP/CONSUMABLE popup format, `is_hidden`×value knob, level_requirement MVP-scope clause, ZWM-absent validation skip, Rule 8 consumable delegation, OQ-WL-4 (OQ-DS-7 co-balancing), EC-WL-12 reframed as logged #16 obligation.

**Deferred to Overworld Navigation (#16) authoring** (CD scope caution): purposive-vs-proximity discovery feel; refused-node return-navigation affordance; EC-WL-12 gesture-gating AC. Logged as cross-system obligations.

**Errata — ✅ ALL THREE APPLIED same session (2026-07-13):**
- Consumable Database — World Loot added to both downstream-reader tables (`consumable_id` + `max_stack`; `max_stack` feeds Rule 8). ✅
- Inventory — World Loot downstream row updated to Approved with Rule 8 `{accepted, rejected}` refusal semantics. ✅
- Exploration Progress — `&"world_loot"` domain row marked "Authored — contract implemented"; serialized-form description corrected from the superseded bare-Array to the `{"collected": [...]}` Dictionary envelope (the old text was inconsistent with EP's own Rule 3). ✅

**CD verdict:** Not a redesign — a tight blocker punch-list; all same-session fixable. APPROVED on fix acceptance.
