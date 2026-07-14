# Active Session State

## Current Task — COMPLETE: ADR-0001 Save/Load written (2026-07-13, Technical Setup, lean)
- **File**: `docs/architecture/adr-0001-save-load.md` (312 lines, Status: **Proposed**). First of 4 Foundation ADRs.
- **Decision**: single-file human-readable JSON per slot; top-level **provider-domain envelope** generalizing the Exploration Progress pattern to the whole save. Providers: `progression` (= entire EP blob, opaque, owns its own `progress_format_version`), `inventory` (part_instances + next_instance_id + scrap + consumables), `workshop` (builds), `drop` (pity), `settings`. Two-layer versioning (`save_format_version` outer / `progress_format_version` inner). Provider contract = EP's `snapshot()/restore()/rederive()`. SL-PRED-1 file version predicate mirrors EP-PRED-1. Atomic write (tmp + `rename_absolute` + `.bak`). **Plain-data-only** (no live Resource in snapshot) — neutralizes the Godot 4.6 Resource-serialization HIGH risk. Budget **2 MiB / 50 ms iOS**. Part instances uncapped — watch via telemetry, no cap (QQ-04 deferred).
- **User design calls** (ELI5 session): readable JSON ✓ / single file ✓ / watch-don't-cap ✓ / 2 MiB+50 ms ✓.
- **godot-specialist validation**: 0 blocking. Folded in 5 fixes → check full write-failure surface (`get_open_error()` + bool + `get_error()`, not bool alone — iOS disk-full/sandbox); budget guard must be explicit `if` (assert stripped in Release); `int()`-cast numeric fields on restore (JSON parses numbers as float — matters for next_instance_id/pity/scrap/cumulative_xp); close FileAccess on every early-return; `JSON.stringify(envelope, "\t")` pretty-print. Confirmed correct: store_string→bool (4.4), rename_absolute atomic within APFS user:// volume, plain-data dodges Resource footgun.
- **Registry**: added 3 stances to `docs/registry/architecture.yaml` (YAML valid) — `save_provider` interface contract; `save_serialization` API decision (JSON, NOT var_to_bytes / NOT .tres); `live_resource_in_save_snapshot` forbidden pattern.
- **Process**: TD-ADR skipped (lean). GDD sync check clean (ADR uses EP names faithfully; only adds new names). Status Proposed → must reach **Accepted** before any persistence coding (via `/architecture-review` in a FRESH session).

### NEXT (Foundation ADRs — write in this session or fresh, but /architecture-review MUST be a fresh session)
- **ADR-0002 — Event bus** (recommended next): resolves the load-bearing dual-`battle_ended` disambiguation AND the save-trigger quiesce-point timing that ADR-0001 deferred to it. `/architecture-decision "Event bus architecture"`.
- **ADR-0003 — Content resources** (.tres DB loading strategy); **ADR-0004 — Scene/boot** (autoloads + boot order: DBs → autoloads → EP restore → derive → gameplay).
- Then **fresh session**: `/architecture-review` (populates tr-registry.yaml, audits all Foundation ADRs, gate to move ADRs Proposed→Accepted). Also queued per gate: `/test-setup`, `/ux-design`, `/create-control-manifest`, `/art-bible` (early).

---

## Prior — COMPLETE: World Loot System (#13) GDD → Designed (2026-07-13, lean)
- **File**: design/gdd/world-loot.md — all 12 sections written, 0 placeholders (~276 lines).
- **Sections**: A Overview / B Player Fantasy (CD not consulted — lean; review manually) / C Detailed Rules 1–9 (incl. Rule 8 refuse-on-overflow + Rule 9 testability contract: injectable sink + injectable Inventory + structured load_catalog result) / D Formulas (WL-PRED-1 collect guard, WL-PRED-2 catalog validity, WL-PRED-3 snapshot sort — all scan-exempt, systems-designer consulted) / E 12 ECs / F Dependencies / G Tuning Knobs (6–10 nodes/zone, 1–3 PART nodes, COMMON+RARE ceiling, scrap ≤~10% arc guardrail) / Visual-Audio (chest states; art-director not consulted — lean) / UI (anti-checklist normative: no counts, no map markers) / H 11 BLOCKING + 1 ADVISORY ACs (qa-lead consulted) / OQ-WL-1..3.
- **Key decisions**: rewards = parts+scrap+consumables; BLUEPRINT enum reserved for Alpha (#25, Rule 6); WL owns interact API; double-collect silently idempotent; inventory-overflow → REFUSE collect (chest stays closed, never destroys reward); loot_id globally unique fatal-on-duplicate; orphans preserve-and-warn (EP Rule 6c).
- **Registry**: no new entries (WL-PREDs internal); referenced_by += world-loot.md on SCRAP_MAX / SCRAP_YIELD / EP_DOMAIN_KEYS (provisional marker discharged). YAML validated.
- **systems-index**: #13 → Designed; deps expanded (+Consumable DB, +Inventory); docs started 19; MVP designed 21/25.
- **3 LIGHT ERRATA OWED on approval**: (1) EP dependency row — discharge "soft-provisional" marker on &"world_loot" row; (2) Consumable DB — add World Loot as downstream reader; (3) Inventory — add World Loot as caller of add interfaces + Rule 8 pre-deposit check.

### NEXT
- **`/clear` then `/design-review design/gdd/world-loot.md`** — fresh-session review (never same-session).
- On approval: apply the 3 light errata, #13 → Approved.
- Then next Not Started MVP systems: #15 Workshop, #16 Overworld Navigation, #17 Save/Load.

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

<!-- CONSISTENCY-CHECK: 2026-07-13 | GDDs checked: 18 | Conflicts found: 0 | PASS. Verified world-loot.md (Approved same day) + all modified GDDs (exploration-progress, inventory, encounter-zone, systems-index). SCRAP_YIELD {5/20/35/60} exact match WL↔registry↔inventory. EP_DOMAIN_KEYS world_loot domain consistently implemented. INV-1 {accepted,rejected} contract correctly invoked by WL Rule 8. Arc-Scrap ~1,800 consistent (DS-F-LEVEL revised figure). EZ Rule 8a erratum applied. WORLD_SCRAP_CEILING=180 correctly internal-only (not registered). 92 registry entries, YAML valid. 3 stale "Not Started" tags in inventory.md (lines 87/93/188), 1 stale "provisional" in systems-index EP row, 1 stale "(Not Started)" label in encounter-zone EP dependency row — all advisory, no semantic conflict. -->

## Session Extract — /review-all-gdds 2026-07-13
- Verdict: CONCERNS (initial FAIL revised — see below)
- GDDs reviewed: 19 (full mode — consistency + design-theory + scenario walkthrough, 3 parallel agents)
- Flagged for revision (systems-index status → Needs Revision): symbot-core-progression ONLY
- Blocking issue (1): (C-2) CP-F3 level-growth breaches DF-1 input ceiling (110+18+40=168 > declared/scanned 150) + max_energy [80,120]→~147 + max_structure [60,594]→~612; DF-1 float-scan doesn't cover A=151-168. Owner: Core Progression + Damage Formula; range annotations in Assembly/Consumable/Part DB. Bundle D-2 (anti-grind invariant → testable AC + OQ-CP-6 CD sign-off) in same pass.
- Downgraded FAIL→Warning after deeper check: (C-1/S-B1) battle_ended NOT a functional break — ZWM/EZ consume a RELAYED battle_ended(result, encounter_type) via Overworld Navigation #16 (Not Started) which owns encounter_type; real issue = signal-name collision + unratified relay. (S-B2) teardown-race dissolves under Godot synchronous emit (emit blocks till subscribers return; discard is next line). BOTH tightened by TBC erratum applied 2026-07-13 → TBC #6 RE-APPROVED same day.
- Key warnings: Scrap sink (Part Upgrade/Workshop #15/#26) Not Started → open faucet; SIGNATURE+synergy un-Heat-gated collapses boss TTK 12-18→4-7; base-regen double-owned (BASE_REGEN vs BASE_ENERGY_REGEN); synergy dead DF-1 [1,165]→[1,225] (C-4); drop Rule 4 partial DS-1 (C-5); Part DB↔CP one-directional dep (C-6); consumable drop frequencies unset (OQ-DS-7/OQ-WL-4)
- Recommended next: /design-review symbot-core-progression.md (resolve C-2 + D-2) + reconcile DF-1 range/scan in damage-formula + downstream range annotations; then batch doc-hygiene warnings; re-run /review-all-gdds before /create-architecture
- Report: design/gdd/gdd-cross-review-2026-07-13.md

<!-- CONSISTENCY-CHECK: 2026-07-13 | GDDs checked: 19 | Conflicts found: 0 | PASS. Post Core-Progression 4th-pass + ST-1..ST-4 errata. Synced registry: CD-1 max_structure [60,594]->[60,612] + CD-3 max_energy [80,120]->[80,147] (runtime = part-derived SA-F1 + CP-F3 CORE growth; ST-4); SA-F1 output_range CP-F3 runtime-max note added (AC-SA-15/AC-CP-18); NEW constant completion_bonus_xp (per-boss Boss1=310/Boss2=180, 0 WILD; mechanism CP Rule 3a / field Enemy DB / values ELZS AC-ELZS-14; resolves OQ-CP-8). Enemy structure 60-594 correctly UNCHANGED (EDB-2, distinct quantity). 1 advisory: enemy-ai EAI-1 H_cur [1,594] vs leveled-core 612 (heuristic input, non-blocking, left as-is). Registry: 48 constants + 34 formulas + 8 items, YAML valid. -->

## Session Extract — /review-all-gdds 2026-07-13 (second pass, post-#10b-Approval)
- Verdict: FAIL (1 blocker) → RESOLVED same session → PASS (CONCERNS on deferred hygiene)
- GDDs reviewed: 19 (2 parallel agents — consistency + design holism)
- Flagged for revision: None (blocker fixed in-session; #10b stays Approved)
- Blocking issue (1, FIXED): boss completion_bonus_xp repeated on LIGHTER_REGATE refights (no first-defeat guard) → ~5.3x WILD XP density, power-levels alt cores past every gate. Fixed: CP Rule 3a first-defeat guard + battle_ended.is_first_boss_defeat bool (TBC Rule 12 eight-field) + AC-CP-25 + EC-CP-13; propagated Enemy DB / ELZS AC-ELZS-14 / registry; N-1 stale-payload-summary warning also fixed.
- Still-open (non-blocking, deferred batch): C-3 (BASE_REGEN naming), C-4 (synergy dead DF-1 range), C-5 (drop Rule 4 partial DS-1), C-6 (Part DB↔CP one-directional dep); advisories: is_build_valid interface enumeration, enemy-ai H_cur [1,594] vs 612.
- Forward-ref: is_first_boss_defeat provenance is an Overworld Navigation #16 (Not Started) obligation — logged in production/errata-backlog.md.
- Recommended next: batch C-3..C-6 doc-hygiene, then /gate-check pre-production → /create-architecture.
- Report: design/gdd/gdd-cross-review-2026-07-13.md (second-pass section appended)

<!-- HYGIENE-BATCH: 2026-07-13 | C-3/C-4/C-5/C-6 all RESOLVED (from /review-all-gdds). C-3: part-database BASE_REGEN->BASE_ENERGY_REGEN, range 5-15->8-15 (owner TBC, 8-floor load-bearing for TBC-F6). C-4: synergy line 232 stale DF-1 [1,165]->resolved [1,225] past-tense. C-5: drop Rule 4 -> canonical amended DS-1 (level_rarity_mult + beacon_factor) + AC-ELZS-10/11 warning. C-6: Part DB downstream +Symbot Core Progression (10->11), Upstream stays None. Registry synced, YAML valid. Logs updated (part-database/synergy-system/drop-system). Remaining advisories: is_build_valid interface enumeration (arch), enemy-ai H_cur [1,594] vs 612. All cross-review consistency warnings now cleared; designed set clean for architecture. -->

## Session Extract — /create-architecture 2026-07-13
- Artifact: docs/architecture/architecture.md v1.0 written (layers, module ownership, data flow, API boundaries, 8-ADR work plan, principles, open questions).
- TD sign-off: APPROVED WITH CONCERNS (blueprint sound; 4 Foundation ADRs must be written+Accepted before coding; persistence budget + battle_ended disambiguation are load-bearing). LP-FEASIBILITY skipped (lean mode).
- TR baseline: 148 requirements across 19 GDDs (Core 41, Data 28, Save/Load 24, Events 22, Content-Val 18, Perf 7, UI 6, Engine 2). 6 hotspots. 0/148 currently in ADRs → 8 Required ADRs.
- Required ADRs (priority): Foundation ADR-0001 Save/Load, ADR-0002 Event bus, ADR-0003 Content resources, ADR-0004 Scene/boot; Core ADR-0005 stat pipeline, ADR-0006 RNG, ADR-0007 TBC FSM; Presentation ADR-0008 touch UI.
- Stage: Technical Setup. Next: write the 4 Foundation ADRs (ADR-0001 first) via /architecture-decision; then /architecture-review (populates tr-registry), /test-setup, /ux-design, /create-control-manifest. Also /art-bible early (per gate).
- Engine gap: turn-based 2D → most Godot 4.6 HIGH-risk is 3D/N-A; real surface = UI dual-focus/AccessKit + Resources/serialization (FileAccess.store_*→bool, duplicate_deep).

## Session Extract — /architecture-decision ADR-0002 Event Bus 2026-07-13
- Artifact: docs/architecture/adr-0002-event-bus.md written (Status: Proposed). Foundation ADR 2 of 4.
- Decision: **Hybrid** — owner-declared typed signals + direct connections by default; thin stateless EventBus autoload (signal declarations ONLY, no methods/state) for cross-layer broadcasts meeting admission criteria (transient/unauthored producer OR unbounded consumer set). Closed MVP bus roster (3): `encounter_resolved(result, encounter_type)`, `zone_states_changed(transitions)`, `zone_entered(zone_id)`. EventBus must be FIRST in autoload order (constraint handed to ADR-0004).
- **Rename (QQ-02 resolved)**: 2-field world relay `battle_ended` → `EventBus.encounter_resolved(result, encounter_type)`. TBC keeps the 8-field combat `battle_ended` (Rule 12) as an owner-declared signal — distinct names on distinct objects, statically testable. GDDs synced same pass: zone-world-map.md (6 edits + erratum header) + encounter-zone.md (3 edits + erratum header). Closes cross-review C-1 remainder.
- Teardown contract (7 rules): synchronous emit; producer discards state only after emit() returns; no inter-subscriber ordering deps (payloads self-sufficient); read-only payloads (`dict.duplicate(true)` — NOT duplicate_deep, that's Resource-only); no re-entrancy; CONNECT_DEFERRED reserved exclusively for autosave; typed connections only (string-connect banned).
- **Save quiesce (§4)**: closes ADR-0001's deferred save-timing question — Save/Load connects to `encounter_resolved` + `zone_entered` with CONNECT_DEFERRED (fires at next engine idle poll after cascade unwinds); manual save gated on `is_battle_active() == false`.
- LogSink: `@abstract class_name LogSink` (4.5+, valid 4.6) — push_warning/push_error banned in src/; extends ADR-0001 File Rule 7 project-wide.
- Miswire strategy: Godot 4.6 does NOT crash on arity mismatch → test-time connection auditor (get_signal_list()/Callable.get_argument_count()) + static name-contract test (no battle_ended on bus, no encounter_resolved on TBC).
- godot-specialist validation (lean mode; TD-ADR skipped): 2 BLOCKING fixed in draft (CONNECT_DEFERRED timing precision; miswire-no-crash → auditor tests) + GOTCHA duplicate_deep corrected. NOTE: first specialist spawn failed on 1M-context credits error — relaunch with explicit `model: sonnet` worked.
- Registry synced (+6 +1): interfaces `combat_battle_end` + `world_encounter_relay`; api_decisions `cross_system_eventing`; forbidden_patterns `subscriber_ordering_dependency` + `global_push_diagnostics` + `bus_by_default`; save_provider referenced_by += adr-0002. YAML valid.
- Next: ADR-0003 Content resources or ADR-0004 Scene/boot (2 Foundation ADRs remain); then /architecture-review in a FRESH session.

## Session Extract — /architecture-decision ADR-0003 Content Resources 2026-07-13
- Artifact: docs/architecture/adr-0003-content-resources.md written (Status: Proposed, 277 lines). Foundation ADR 3 of 4.
- Decision: typed .tres Resource entries (7 def classes: PartDef/EnemyDef/BreakRegionDef/MoveDef/PassiveDef/ConsumableDef/LootNodeDef, all @export typed) → **one explicit catalog Resource per DB** (Array[XDef] manifest, NO directory scanning — export-safe vs .remap stubs) → boot-loaded into read-only DB singletons (DI'd load_catalog(catalog, log_sink), has_x/get_x with explicit null contract) → single ContentValidator with 8 validation families, mounted **CI-blocking headless GUT** + **dev-boot fail-loud** (release skips).
- User design decisions (widget): typed .tres (not JSON/Dictionaries); CI+dev-boot gate (not boot-all-builds/CI-only); catalog-per-DB (not dir-scan/monolithic). All = recommended options.
- **VERIFICATION GATE (must pass before content authoring)**: Dictionary[StringName, int] @export .tres round-trip (keys stay StringName; typed-dict .get() return type) — post-cutoff, unverified; fallback requires explicit ADR amendment.
- Conventions locked: content enums explicit-from-1, APPEND-ONLY (.tres stores raw ints); &"" = null-equivalent for StringName refs; nested Resources (BreakRegionDef) inline in parent .tres; cross-DB refs are StringName IDs never Resource links; defs frozen-shared (duplicate()/duplicate_deep() on defs BANNED).
- godot-specialist validation (lean; TD-ADR skipped; model: sonnet workaround again): 10 findings — 2 BLOCKING fixed (typed-dict verification hardened to gate; get_x null contract made explicit + has_x guard), 8 gotchas folded (precise .remap mechanism, duplicate() ban extension, class_name parse gate in CI, headless GUT requirement, null-catalog-slot guard, enum append-only, StringName authoring doc comments, inline sub-resource convention).
- GDD sync: none needed (no renames — 1:1 field mapping).
- Registry synced (+5 +1): interfaces content_db_lookup; api_decisions content_authoring; forbidden_patterns runtime_content_mutation + content_directory_scanning + content_enum_reordering; save_serialization referenced_by += adr-0003. YAML valid.
- Next: ADR-0004 Scene/boot (LAST Foundation ADR — inherits: EventBus first in autoload order [ADR-0002], boot sequence catalogs→validate[debug]→consumer autoloads [ADR-0003]); then /architecture-review in a FRESH session.

## Session Extract — /architecture-decision ADR-0004 Scene Management & Boot 2026-07-13
- Artifact: docs/architecture/adr-0004-scene-boot.md written (Status: Proposed, 280 lines). **Foundation ADR 4 of 4 — Foundation set COMPLETE.**
- Decision: persistent `Game.tscn` root + **ScreenManager** sole transition owner (injected into screens; no change_scene_to_* anywhere; TransitionLayer blocks input + `gui_release_focus()` for 4.6 dual-focus) → **Overworld keep-alive** during battle (hide + PROCESS_MODE_DISABLED + release focus; Battle sibling instantiated; teardown = `queue_free()` ONLY on `EventBus.encounter_resolved` — never free(), cascade must unwind) → **explicit BootScreen sequencer** (autoloads = thin hosts, NOTHING in _ready; run_boot(): 6× load_catalog → ContentValidator[debug] → RngService.init → provider registration → autosave CONNECT_DEFERRED connects → Main Menu; fatal steps → BootError screen via LogSink) → autoload roster fixed order of 10 (EventBus, Log, 6 DBs, RngService, SaveLoad).
- Save restore NOT at boot: Main Menu Continue runs predicate→Phase1→Phase2 rederive; **New Game = "restore from nothing" through the SAME rederive path** (one derivation code path; TR-ep-004 structural).
- User design decisions (widget ×4, all = recommended): persistent root + ScreenManager; keep-alive hidden+paused; explicit Boot sequencer; 6 separate DB autoloads.
- godot-specialist validation (lean; TD-ADR skipped; model: sonnet workaround again): 2 BLOCKING fixed (PROCESS_MODE_DISABLED does NOT suppress _input on plain Nodes → _unhandled_input-only standard + inertness test extended; queue_free timing comment corrected — later subscribers see is_queued_for_deletion()==true, not "already gone"). 4 GOTCHAs folded: **4.6 dual-focus (VERIFIED post-cutoff, input.md/ui.md)** → gui_release_focus() rule on TransitionLayer + battle entry; current_scene==Game.tscn forever (debugger/GUT consequence noted); iOS suspend mid-battle skips deferred autosave → NOTIFICATION_APPLICATION_PAUSED synchronous-save mitigation on Game root; catalog load() splash hitch → load_threaded_request escape hatch. 3 UNVERIFIED 4.6 surfaces → Verification Required (all mitigated regardless).
- GDD sync: none needed (new names only, no renames; Overworld Nav #16 must author against enter_battle(encounter_payload) — recorded in Blocks/Risks as forward obligation).
- Registry synced (+4 new +4 refs): interfaces screen_transitions; api_decisions boot_initialization; forbidden_patterns autoload_ready_work + unowned_scene_transition; referenced_by += adr-0004 on save_provider/world_encounter_relay(+screen-manager consumer)/content_db_lookup/cross_system_eventing. YAML valid (5 interfaces / 4 api / 9 forbidden).
- Next: **/architecture-review in a FRESH session** (all 4 Foundation ADRs written: save-load, event-bus, content-resources, scene-boot — all Status: Proposed; review must be independent of this authoring context).
