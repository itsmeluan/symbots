# Active Session State

## Current Task — World Loot System (#13) — In Design (2026-07-13)
- File: design/gdd/world-loot.md
- Current section: D Formulas
- Sections complete: A Overview ✓ | B Player Fantasy ✓ | C Detailed Design ✓

## Prior — COMPLETE: Exploration Progress (#14) APPROVED (round-2 confirmation, 2026-07-13) + EZ Rule 8a erratum APPLIED

- **Round-2 confirmation full-panel /design-review** (game-designer, systems-designer, qa-lead in parallel + creative-director synthesis). All 4 round-1 blockers verified fixed by all three specialists. Verdicts split (GD: APPROVED; SD/QA: NEEDS REVISION) — CD adjudicated **2 true gates** of 5 claimed blockers, fixed same session:
  1. **MIGRATE semantics** (SD-B2 = QA-B1, converged): Rule 9 now normative — hookless MIGRATE → **REFUSE** under the full no-partial-restore guarantee (also covers mid-migration hook failure, discharging the conditional SD-B3); EP-PRED-1 comment + worked example updated; **AC-EP-02(b) rewritten** with positive domain-state assertion (win_count==5 kept, spy: no restore() invoked) + two discriminators (silent-zero impl, fall-through-RESTORE impl).
  2. **AC-EP-12 GUT-testability** (QA-B2, advisory→blocking promotion upheld by CD): Rule 3 serialize returns structured result `{ok: true, blob}` / `{ok: false, failed_domain, error}`; new **Rule 3a.3 injectable warning/error sink** (push_error not GUT-capturable) — covers all warning assertions AC-EP-05..09 + AC-EP-12.
- **2 CD-mandated fold-ins**: String-cast sort normative (Rule 1 `sort_custom` on `String(a) < String(b)`; AC-EP-01 fixture insertion order chest_z→chest_a→chest_m made normative to kill intern-order sorts); Player Fantasy OQ-EP-2 qualifying sentence (GD's challenge to prior CD adjudication upheld — CD conceded).
- **CD-directed cheap items**: Rule 6(e) normative clamp ordering (win_count clamp → EP-INV-1, sequenced); domain-key-collision startup assertion (Rule 1); #17 forward-notes in Save/Load dep row (serialize only at quiesce points; "save was repaired" notice); GDScript-traps summary extended (intern-order sort, push_error non-capturability).
- **CD adjudications recorded**: SD's clamp-ordering "blocker" downgraded (CD traced all 4 permutations — only dangerous one already AC-EP-06-covered); StringName sort held advisory severity but folded in; QA's AC-EP-12 promotion ruled legitimate, not scope creep.
- **Tracking updated**: GDD header → Approved; systems-index #14 → **Approved** (18 approved / 15 reviewed; MVP designed 20/25); review-log round-2 entry appended with **10 backlog recommended items** (several are #13/#17/#20 authoring inputs: World Loot double-collect/loot_id-format/size-cap, deferred-AC activation owner, anti-checklist delegation).
- **EZ Rule 8a erratum APPLIED** (the last owed erratum): encounter-zone.md Rule 8a + dependency row (status → Approved) + AC-EZ-55 activation note reworded — "ZWM implements the increment; Exploration Progress persists the counter"; header erratum note added. All three "owed" markers in EP GDD discharged. **No pending errata remain anywhere.**

### NEXT
- **Option A (recommended)**: `/clear` then `/design-system world-loot` (#13 — next Not Started MVP system; its `&"world_loot"` domain contract is pre-defined in EP Rule 1; resolve the 3 backlog contract gaps during authoring).
- **Option B**: `/consistency-check` — validate revised EP GDD (Rule 9 MIGRATE, serialize result contract, Rule 3a.3) against registry + 17 other approved GDDs.

<!-- ERRATA APPLIED: 2026-07-13 | Encounter Zone Rule 8a hook wording (ZWM increments / EP persists) — final owed erratum discharged. -->

## Prior — Exploration Progress (#14) REVIEWED: NEEDS REVISION → 4 blockers FIXED same session (2026-07-13)

- **Full-panel /design-review run** (game-designer, systems-designer, qa-lead in parallel + creative-director synthesis). Verdict NEEDS REVISION, 4 blockers, 8 recommended, 4 advisory. CD: "commit-approve on fixes landing." Scope signal S.
- **All 4 blockers applied to exploration-progress.md same session:**
  1. **EP-INV-1 clamp direction** (SD-B1, the one genuine design error): clamp-to-`win_count` silently revoked earned re-gates → changed to **clamp-to-0** (over-credit; user decision via widget). Rule 6e + EP-INV-1 rationale + EC-EP-03 rewritten; **AC-EP-05 gained (a2)** earned-regate discriminator `{win_count:10, wALD:14}` → stored 0, delta 10.
  2. **Threshold notation trap** (SD-B2/QA-B1 convergence): AC preamble was a 0-indexed array literal vs CP-F1's level-indexed convention → preamble rewritten level-indexed (`threshold[4]=364` = level-4 boundary) + inline level annotations in AC-EP-01/-03/-10/-13.
  3. **Rule 3a Testability sub-contract** (QA-B2+QA-B3 merged by CD): (1) injectable cross-domain accessor + technical def of "cross-domain read" (instance calls via accessor; constants exempt); (2) `restore_records(records: Array)` public inner method on keyed-collection domains (duplicate-ID injection path for AC-EP-08B; Array order = "first occurrence"). AC-EP-14/AC-EP-08B updated to cite Rule 3a.
  4. **OQ-EP-2** (GD-B1 reframed by CD as contingency): Player Fantasy contingent on Save/Load #17 save-trigger granularity; priority-ordered trigger events listed (win_count increment foremost); cross-refs in Rule 8 + Save/Load dependency row.
- **CD adjudications recorded**: EC-EP-09 atomicity stays advisory (GD wanted blocking); GD-B1 → Open Question not legislation of #17.
- **Review log created**: design/gdd/reviews/exploration-progress-review-log.md (incl. the 8 recommended items left open + errata owed).
- **systems-index**: #14 → In Review (pending fresh-session confirmation re-review).
- **STILL OWED on approval**: EZ Rule 8a erratum (one line); recommended items 1–8 in review log (esp. World Loot contract gaps → feed into #13 authoring; two-blob atomicity + deferred-AC activation owner → feed into #17 authoring).

### NEXT
- **`/clear` then `/design-review design/gdd/exploration-progress.md`** — fix-confirmation re-review (user decision). Prior verdict NEEDS REVISION 2026-07-13; re-review should verify the 4 fixes at discriminator level.
- On approval: apply EZ Rule 8a erratum, #14 → Approved, then `/design-system world-loot` (#13).

## Prior — Exploration Progress (#14) GDD COMPLETE → Designed (2026-07-13, lean)
- **All 12 sections written** (~5.3k words, 0 placeholders). CD-GDD-ALIGN skipped (lean) — review Section B manually before production.
- **AC section**: 15 BLOCKING unit + 2 DEFERRED integration (Save/Load #17) + 2 delegated + 1 advisory-only. qa-lead consulted; main session corrected one fixture technique (AC-EP-08B: JSON.parse_string does NOT preserve duplicate keys — inject collision at domain-restore API level, Array-of-records form). AC-EP-14 kept as structural Phase-1 isolation test (injectable seam requirement flagged for lead programmer).
- **Registry updated + YAML-validated**: EP-PRED-1 + EP-INV-1 formulas, CURRENT_FORMAT_VERSION + EP_DOMAIN_KEYS constants; CP-F1 referenced_by += exploration-progress.md. 34 formulas / 47 constants.
- **systems-index**: #14 → Designed; #20 World Map UI dep note (EP → ZWM); docs started 18, MVP designed 20/25.
- **1 ERRATUM PENDING (apply on approval)**: EZ Rule 8a hook wording → "ZWM implements the increment; Exploration Progress persists the counter" (increment-ownership resolved in ZWM's favor, EP Rule 2).
- **NEXT**: `/clear` then `/design-review design/gdd/exploration-progress.md` FRESH session. On approval: apply the EZ erratum. Then #13 World Loot (its &"world_loot" domain contract is now defined in EP Rule 1/3) or #15 Workshop.

## Prior — Designing session notes (2026-07-13)
- **File**: design/gdd/exploration-progress.md
- **Sections written**: A Overview ✓, B Player Fantasy ✓, C Detailed Rules ✓ (9 rules: domain registry, pull model, 3-op domain contract, source-facts-only, two-phase restore, drift tolerance, unknown-key preserve, Save/Load split, format version). Decisions: ZWM owns increments (EZ Rule 8a erratum owed), pull-at-save, flat global loot set.
- **Sections written (cont.)**: D Formulas ✓ (EP-PRED-1 version predicate + EP-INV-1 well-formedness invariant + re-derivation obligations; both scan-exempt pure-int), E Edge Cases ✓ (17 ECs from systems-designer's 18 findings; 5 Section-C hole patches applied: Rule 2 opaque-store carve-out, Rule 1 world_loot serialized form, Rule 3 snapshot validation + replacement semantics, Rule 6 d/e corruption pass, Rule 9 missing-key REFUSE + state-unchanged), F Dependencies ✓, G Tuning Knobs ✓ (no gameplay knobs; CURRENT_FORMAT_VERSION=1), Visual/Audio ✓ N/A, UI ✓ none, OQ ✓ (OQ-EP-1 re-added boss re-gate, parked)
- **Current section**: H Acceptance Criteria — qa-lead consult running (AC-EP-01..15 numbering pre-assigned by E's forward refs)
- **Errata created so far**: (1) EZ Rule 8a hook wording → ZWM implements increment; (2) systems-index note: World Map UI dep resolves to ZWM
- **Registry candidates (Phase 5b)**: EP-PRED-1, EP-INV-1, CURRENT_FORMAT_VERSION, domain keys (&"zones"/&"cores"/&"world_loot"/&"key_items" reserved)
- **Mode**: lean. User redirected from World Loot (#13) → Exploration Progress (#14) first (EP owns the persistence contract World Loot needs).
- **Pre-fixed contracts**: EZ Rule 8a/9 (win_count semantics, defeated_once, wins_at_last_defeat; EC-EZ-11 fallback; AC-EZ-40b/55 deferred→activate); ZWM Rule 7/8 (ZWM = runtime authority, EP = persistence-only; state re-derived on load, EC-ZWM-10 drift rules); Core Progression (CoreProgressionRecord serialization, EC-CP-06 level re-derived); index scope "zones cleared, bosses defeated, hidden items found" (World Loot ledger TBD).
- **Known tension to resolve (Section C)**: EZ says "EP implements the increment + snapshot hooks"; ZWM (approved later) says ZWM performs increments/snapshots, EP is persistence-only. Likely resolution: ZWM's model + light EZ erratum.
- **Scope boundary**: EP = which progression state exists + round-trip semantics; Save/Load (#17) = file format/disk I/O/save timing. Pity maps + next_instance_id are contracted directly to Save/Load (bypass EP).

## Prior Task — COMPLETE: Enemy Level & Zone Scaling (#10c) APPROVED + 4 Errata Applied (2026-07-13)

### ELZS #10c — Status: APPROVED
- **Round 4 (confirmation pass, fresh session)** — full-panel /design-review (systems-designer, game-designer, economy-designer, qa-lead, creative-director).
- **Round-3 blockers verified**: all 4 confirmed applied (AC-05 at-roof fixture, AC-09 pinned signature, errata pre-gate 3a/3b/3c/CI, economy ESTIMATED label).
- **Round-4 blockers sustained (2 of 5 claimed)**:
  - B1 [qa]: AC-ELZS-05 Fixture F — at-floor acceptance for F > 1 (`level > F` bug invisible to F=1 Fixture A). Added zone [3,6] + level-3 passes.
  - B2 [qa]: AC-ELZS-04 floor=0 rejection fixture (mirrors AC-01's level==0 pattern).
- **Recommended applied (4)**: AC-09 level_band(1,3,6)==EARLY; Enemy DB AC-ED-14 integration contract note in deps; economy 0.875 redistribution stated; HIGH-overstated qualifying clause.
- **Downgraded**: SD false positive (existing fixture catches `>=7` impl); QA AC-06 overlap (ADVISORY twice-rejected); GD AC-ED-14 deps location (already in body text).
- **Summary**: 13 ECs, 10 BLOCKING + 1 ADVISORY + 2 delegated ACs. GDD updated to Approved (2026-07-13). systems-index #10c → Approved. Review log entry appended (round 4).

### 4 Errata — Status: ALL APPLIED 2026-07-13
1. **Enemy Database (enemy-database.md)**: Added `level: int` and `xp_value: int` fields to Rule 1 schema table with stored-equals-derived contract; ELZS added to Downstream Dependents table (ED7 note); Bidirectionality note updated.
2. **Encounter Zone (encounter-zone.md)**: Added `enemy_level_floor: int` and `enemy_level_roof: int` to Rule 1 zone definition table with full in-band validation invariants; ELZS added to Downstream Dependents table; Errata received section updated.
3. **Drop System (drop-system.md)**: 
   - (3a) Canonical DS-1 amended — `level_rarity_mult` factor added to the code block; Beacon partial expression superseded/labeled.
   - (3b) AC-DS-31 updated — added SCENARIO A2 (L6/HIGH + Beacon → 0.75, draw 0.60 drops; discriminator for missing level factor).
   - (3c) DS-F-LEVEL section added to Formulas — `level_band()` code, LEVEL_RARITY_MULTS table, production interface obligation + AC-ELZS-11 Done condition noted.
   - Economy re-annotation added to A2 — arc-weighted mult 0.95 → ~0.34 Rares/victory → central ~1,800, ESTIMATED.
   - DS-F-LEVEL Tuning Knobs added.
   - ELZS added to Bidirectionality.
4. **Zone & World Map (zone-world-map.md)**: Added difficulty_band → level range guideline table + ADVISORY validation note; ELZS amendment noted in Bidirectionality section.
- **ELZS pre-gate block**: Updated with "✅ ALL FOUR ERRATA APPLIED 2026-07-13".

### Progress Tracker
- systems-index: #10c → Approved (16 total approved); MVP designed 19/25.

### NEXT
- **Option A**: `/clear` then `/design-system world-loot` (#13 World Loot System — next Not Started MVP system).
- **Option B**: `/consistency-check` — validate the 4 amended GDDs against each other and the full registry.
- All 17 designed MVP GDDs are now Approved. No pending errata remain. 4 errata all owed have been discharged.

<!-- CONSISTENCY-CHECK: 2026-07-12 | GDDs checked: 14 | Conflicts found: 0 | Verified this session: EAI-1 + AI_PROFILE_WEIGHTS (TACTICAL w_lethal 5.0) + STATUS_BASE_VALUE (enemy-ai); INV-1 + SCRAP_MAX + SCRAP_YIELD (inventory). SCRAP_YIELD exact match Drop(owner 5/20/35/60) vs Inventory(referencer); invariant COMMON<RARE<PROTOTYPE<BOSS_GRADE holds. parts=instances / consumables=stackable model consistent w/ Part DB EC-05 + Consumable DB. 69 registry entries, YAML valid. -->
<!-- CONSISTENCY-CHECK: 2026-07-12 | GDDs checked: 15 | Conflicts found: 0 | Verified: zone-world-map.md (approved today); win thresholds (6/10) consistent ZWM↔EZ; win_count semantics consistent; wins_at_last_defeat field name consistent; all 69 registry entries PASS. Informational only: TBC result vocab VICTORY/DEFEAT/FLED vs ZWM WIN/LOSS/FLEE (Overworld Navigation relay mapping; non-blocking); push/pull ownership OQ-ZWM-5 (Vertical Slice erratum); EZ bidirectionality erratum pending (one-line, tracked). 15/15 MVP GDDs Approved. -->
<!-- CONSISTENCY-CHECK: 2026-07-12 | GDDs checked: 17 | Conflicts found: 0 | Verified this session: EAI-1 + AI_PROFILE_WEIGHTS + STATUS_BASE_VALUE (enemy-ai); INV-1 + SCRAP_MAX + SCRAP_YIELD (inventory). 69 registry entries PASS. -->
<!-- ERRATA APPLIED: 2026-07-13 | 4 GDDs amended | Enemy DB (level/xp_value fields) | Encounter Zone (level band fields) | Drop System (DS-F-LEVEL canonical DS-1 + AC-DS-31 + economy re-annotation) | ZWM (difficulty_band level range table) | ELZS pre-gate ✅ -->
<!-- CONSISTENCY-CHECK: 2026-07-13 | GDDs checked: 17 | Conflicts found: 0 | PASS. Verified the full ELZS Level Backbone chain post-errata: CP-F4 constants (35/10/2) + xp_value fixtures (45/65/170/190/130) consistent ELZS↔EnemyDB↔CoreProgression; band floors (3/6) + LEVEL_RARITY_MULTS (0.5/1.0/1.5 Rare-only) + canonical DS-1 + discriminating fixtures (0.1875/0.375/0.5625; AC-DS-31 0.75/0.60) consistent ELZS↔DropSystem; MVP zone [1,6] consistent ELZS↔EncounterZone↔ZWM; difficulty_band ranges (1-3/3-6/6-9/8-10) consistent ELZS↔ZWM; economy re-annotation (0.95/~0.34/~1,800/floor 1,556/ESTIMATED) consistent; battle_ended payload (xp_value+enemy_level+deployed_symbot_ids) confirmed in TBC Rule 12. Registry synced: 10 stale "(erratum pending)" comments discharged (4 ELZS errata 07-13 + 3 CP errata 07-12); LEVEL_RARITY_MULTS HIGH safe range corrected 1.2-2.0→1.2-1.6 (source ELZS); NEW constant DIFFICULTY_BAND_LEVEL_RANGES (table duplicated ELZS Rule 4 + ZWM Tuning Knobs — retunes must change both). Registry: 88 entries, YAML valid. -->
