# Review Log: Symbot Assembly System

## Review — 2026-07-10 — Verdict: APPROVED (post-revision)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, ux-designer, creative-director (senior synthesis)
Blocking items: 5 (all resolved in-session) | Recommended: 8
Summary: Core rules and formula pipeline were sound. All blockers were specification defects rather than design problems: two ACs contained mathematically impossible expected values (AC-SA-02a/b — wrong formula forms and wrong outputs derivable from Part DB); SA-F2 specified a hover-based preview interaction incompatible with iOS touch (replaced with platform-agnostic language); entities.yaml referenced a non-existent `stat_max` field and had an erroneous epsilon example; five ACs were untestable or ambiguously specified. A Deferred Design Obligations section was added naming 7 forward-references to downstream GDDs (TBC, Synergy, Workshop UI). All blockers resolved before approval.
Prior verdict resolved: No — first review

## Erratum — 2026-07-13 — ST-2 (Core Progression CP-F3 pipeline-order AC) APPLIED — light re-review touch owed

Source: Symbot Core Progression 4th-pass `/design-review` (2026-07-13); qa-lead findings **R3-C / R4-B1** (BLOCKING), tracked as **ST-2** in `production/errata-backlog.md`.

**Problem:** The 2026-07-12 Core Progression erratum inserted the CP-F3 level-growth step into this GDD (Rule 6 step 4b: `final_stat[stat] += level_growth[stat] × (core.level−1)`, after SA-F1, before synergy). Core Progression's AC-CP-18 verifies that insertion *order*, but AC-CP-18 is DEFERRED there and its enforcement lived only as prose in Core Progression's Bidirectionality Notes. **An Assembly programmer not reading Core Progression could close the CP-F3-insertion story without ever running AC-CP-18** — and a wrong insertion point (before SA-F1 → chassis modifier amplifies level growth; or after synergy) produces a different `final_stat` that no other non-deferred AC in either GDD catches.

**Change applied (file-verified):** **`AC-SA-15`** added after AC-SA-14 — Integration test. Setup: chassis `M=1.2`, CORE `level_growth={target_stat:10}` at level 5 (contribution 40), SA-F1 output 120. **Pass when** the value handed to SYN-F4 is exactly **160** (= 120 + 40, CP-F3 flat after chassis multiply), NOT **168** (= (100+40)×1.2, the pre-SA-F1-insertion bug), and not a post-synergy value. AC-SA-15 carries a **binding DoD-gate note**: it is the same test as AC-CP-18 and passing it is a required Definition-of-Done item on the CP-F3-insertion story. Core Progression AC-CP-18 + Bidirectionality note updated to name AC-SA-15 concretely (placeholder "AC-SA-XX" discharged).

**Owed:** a light `/design-review symbot-assembly.md` confirmation touch (mechanical erratum adding one Integration AC to an already-wired step; no design change — Status stays APPROVED). No registry change (no constant added).
