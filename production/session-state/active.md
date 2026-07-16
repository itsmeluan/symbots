# Active Session State

<!-- STATUS -->
Epic: Pre-Production
Feature: Sprint Zero — Part Database
Task: Part Database EPIC COMPLETE (all 10 stories Done) — next: pick the next Foundation epic (Move/Passive/Consumable/Enemy/Damage-Formula) or the 4.6→4.7 ADR re-validation sweep
<!-- /STATUS -->

> **This file is a lean checkpoint, not a changelog.** Keep it small — current
> task, open threads, next decision. Full project history lives in `git log` and
> in the artifact files (ADRs in `docs/architecture/`, epics in `production/epics/`,
> GDDs in `design/gdd/`). Prior-session narrative archived in
> `production/session-state/archive-active-2026-07-15.md`.

## Current Task — Pre-Production Sprint Zero (updated 2026-07-15)

- **Stage**: Pre-Production. All 8 ADRs (0001–0008) Accepted. MVP scope frozen
  (`production/mvp-scope-freeze.md`). 6 Foundation epics defined in
  `production/epics/index.md`.
- **Part Database stories COMPLETE (2026-07-15)** — `/create-stories part-database`
  wrote **10 stories** (`part-database/story-001…010`), all Ready, all 25 TRs
  covered. Build order: 001 engine-spike gate (typed-dict `.tres` round-trip —
  MUST pass before content authoring) → 002 schema → 003 loader / 004 F2+F2b /
  006 F3 / 007 validator-scaffold → 005 F1 / 008+009 validator families →
  010 author content + CI. Scoping calls: 004/005 governed primarily by ADR-0005;
  AC-15a/15b + THERMAL +5 runtime heat are OUT (Drop/Assembly/Combat epics).
- **Next decision** (user chose "Stop here" 2026-07-15): resume with EITHER
  `/story-readiness production/epics/part-database/story-001-tres-typed-dict-roundtrip-spike.md`
  → `/dev-story` (recommended — the spike de-risks all 5 content DBs), OR
  `/create-stories move-database` (5 Foundation epics still unstoried), OR
  `/sprint-plan new` (Part-DB-only sprint for now).

## Session Extract — Story 001 spike ✅ PASSED (2026-07-15)

- **SPIKE RE-RUN & PASSED.** Ran directly in-session (not via subagent — the
  prior attempt's subagent died on `API Error: Usage credits`). Godot
  `4.7.stable.official.5b4e0cb0f` at `/Applications/Godot.app/Contents/MacOS/Godot`.
  Headless GUT (v9.6.1) via the CI command → **7/7 tests, 27 asserts, 0 fail.**
  - Result: `Dictionary[StringName, int]` `.tres` round-trip **holds on 4.7** —
    StringName keys do NOT degrade to String; int values stay int; typed
    `get_bonus() -> int` returns usable int; missing-key → 0; empty dict OK.
  - Verified on BOTH the committed editor-format fixture (load path) and a fresh
    `ResourceSaver.save` → reload round-trip.
  - **ADR-0003 verification gate item (2) CLOSED (PASS)** — no ADR amendment;
    typed schema stands. **Story 002 + all content authoring UNBLOCKED.**
  - Artifacts: `tests/unit/part_database/tres_typed_dict_roundtrip_test.gd`,
    `stat_bonuses_probe.{gd,tres}` (throwaway probe), finding note
    `production/epics/part-database/story-001-FINDING.md`. Story + EPIC marked Done.
- **Engine already re-pinned 4.6 → 4.7** (prior session): authoritative pins
  (`project.godot`, `VERSION.md`, `technical-preferences.md`, `CLAUDE.md`) updated.
- **STILL DEFERRED to `/architecture-review`**: 8 ADRs + architecture docs still
  say "4.6" — need engine-compat *re-validation*, not a label swap. Not swept.
- **Next**: Story 002 (PartDef schema + enums + PartCatalog) is now the gate-open
  next build step — `/dev-story story-002`. Or story the 5 remaining Foundation
  epics. Or `/sprint-plan`.

## Session Extract — /dev-story story-002 (2026-07-15)

- Story: `part-database/story-002` — PartDef schema + enums + PartCatalog. **Implemented** (In Progress → ready for `/code-review` + `/story-done`).
- Files: `src/core/content/part_def.gd` (first code in `src/`; establishes `src/core/content/`), `src/core/content/part_catalog.gd`, `tests/unit/part_database/part_def_schema_test.gd` (13 tests).
- Suite GREEN: **20/20 tests, 121 asserts** headless (Godot 4.7 + GUT). AC-3 typed-array rejection uses GUT `[ExpectedError]` trap (invalid append pushes 2 engine errors, element not added).
- Decisions/deviations: (1) **Option A** — all 5 enum fields default `= 0` (reserved/invalid sentinel per ADR-0003 + AC-2), so a fresh `PartDef` is validator-catchable. (2) **Reserved fields = 6** (`motherboard_slot_type, ram_cost, weight_class, modification_slots, critical_output, firewall`) per TR-part-025 source-of-truth; **GDD Rule 1 + story AC name only 4** → GDD↔TR drift worth a later cleanup. (3) `chassis_archetype` nullability = enum 0 (non-CHASSIS); required-when-CHASSIS deferred to validator Story 009. (4) Element +CRYO/CORROSIVE/DATA, DamageType +DATA/TRUE appended as reserved (append-only).
- Routing: single implementer `godot-gdscript-specialist` (pure typed-GDScript schema; project file-extension routing owns `.gd`) — no engine-programmer to avoid write races.
- Next: `/code-review src/core/content/part_def.gd src/core/content/part_catalog.gd` → `/story-done story-002`. Then Story 003 (PartDB loader).

## Open Threads (not yet captured elsewhere)

- `design/ux/battle.md` still **Draft** → run `/ux-review battle`.
- Art bible **§8 Asset Standards** required before any scratch assets commissioned.
- **Faction-name sync** with narrative before faction concept art (§3.8 placeholders
  Smoothshell / Hardform / Wirework / Fluxform).
- **11 errata** tracked in `production/errata-backlog.md` + pending CD sign-off **OQ-CP-6**.
- 5 remaining Foundation epics (move / passive / consumable / enemy / damage-formula)
  are unstoried.
- Optional cleanup: refresh `docs/architecture/architecture.md` stale traceability block.

## Session Extract — /story-done 2026-07-15 (Story 002)
- Verdict: **COMPLETE WITH NOTES**
- Story: `production/epics/part-database/story-002-partdef-schema-enums-catalog.md` — PartDef schema + enums + PartCatalog. Status → **Complete**.
- Evidence: 18/18 part_database suite green (119 asserts, Godot 4.7 + GUT 9.7.1). `/code-review` APPROVED; enum `=0` sentinel confirmed warning-free via headless `--check-only`.
- Tech debt logged: 1 item — GDD↔TR reserved-field drift (4 vs 6) → `docs/tech-debt-register.md`.

## Session Extract — /story-done 2026-07-15 (Story 003)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**.
- Story: `production/epics/part-database/story-003-partdb-loader.md` — PartDB loader/index/read-only getters.
- Files: `src/core/content/part_db.gd` (loader, thin `extends Node` autoload host, no `class_name`), `src/core/diagnostics/log_sink.gd` (**new** `@abstract` LogSink base, ADR-0002 §5 — a prerequisite, no home story), `tests/unit/part_database/spy_log_sink.gd` (preload spy), `tests/unit/part_database/part_db_loader_test.gd` (11 tests).
- Evidence: **29/29 part_database suite green, 142 asserts** (Godot 4.7 + GUT 9.7.1). 9/9 ACs covered. Code review inline (lean; subagents unavailable — persistent "Usage credits" API error).
- Tech debt logged: 4 items → `docs/tech-debt-register.md` — (1) AC-14 literal-null vs 4.7 StringName type-rejection (kept StringName, `&""` carries the contract, per user decision); (2) LogSink base has no home story; (3) stale "Godot 4.6" label in story-003; (4) CI must regen global class cache for new `class_name` scripts (blocks Story 010 CI).
- **4.7 finding**: a literal `null` to a `StringName` param is statically type-rejected at the call boundary (never coerces to `&""`); pass `&""` for "no part".
- Next: **Story 004 — Formula 2 + 2b (upgrade stat scaling), ADR-0005.** Then 006 → 007 → 005 → 008 → 009 → 010.

## Session Extract — /story-done 2026-07-15 (Story 004)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**.
- Story: `production/epics/part-database/story-004-upgrade-formula-f2-f2b.md` — Formula 2 (upgrade stat scaling) + Formula 2b (Prototype drawback reduction) + sign-routing + Common +3 cap.
- Files (**new** ADR-0005 stat core, `src/core/stats/`): `stat_math.gd` (Layer-1 `floor_eps`/`ceil_eps` + fixed `EPSILON` const), `balance_config.gd` (Layer-4 `class_name BalanceConfig extends Resource`; `upgrade_multipliers`, append-only), `upgrade_formula.gd` (F2/F2b pure static funcs + sign-router + part-level cap). Test: `tests/unit/part_database/upgrade_formula_test.gd` (13 tests).
- Evidence: **44/44 suite green, 164 asserts** (Godot 4.7 + GUT 9.7.1). 7/7 ACs. **Plus** exhaustive `python3` Fraction-oracle scan: 0 impl-vs-exact mismatches (F2 base 0–55, F2b base −55–0, all tiers); `−ε` nudge rescues exactly 26 F2b inputs = GDD's empirical count.
- Tech debt logged: 3 items → `docs/tech-debt-register.md` — (1) StatMath+BalanceConfig born without home story; (2) `assets/data/balance_config.tres` not authored (boot/validator/Story-010 owns .tres + boot load + validator balance-section); (3) stale "Godot 4.6" label in story-004.
- **Key infra**: `src/core/stats/` now exists (ADR-0005 Layer 1 home). Later stat stories (005 F1, 006 F3) reuse `StatMath` + extend `BalanceConfig` (append-only).
- Next: **Story 006 — Formula 3 (drop-rate), ADR-0003/GDD Formula 3.** Then 007 → 005 → 008 → 009 → 010.

## Session Extract — /story-done 2026-07-15 (Story 006)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**.
- Story: `production/epics/part-database/story-006-drop-rate-formula-f3.md` — Formula 3 (effective drop rate); pure `clamp(base × Πmultipliers, 0, 1)`, no RNG.
- Files: **new** `src/core/stats/drop_rate_formula.gd`; **modified** `src/core/stats/balance_config.gd` (appended `drop_rate_by_rarity = [0.0, 0.70, 0.25, 0.001, 0.05]`); test `tests/unit/part_database/drop_rate_formula_test.gd` (10 tests).
- Evidence: **54/54 suite green, 181 asserts**. 6/6 ACs. `python3` pre-verified boundary exactness (boss 0.001/×500→0.5/×999→0.999/×1000→1.0 exact → strict `==`; Rare/Prototype float products → `<1e-9` tolerance).
- Tech debt logged: 3 items → `docs/tech-debt-register.md` — (1) `drop_rate_by_rarity` extends BalanceConfig field-family + validator must assert boss=0.001; (2) DropRateFormula home in stats/ (placement note); (3) stale "Godot 4.6" label.
- Next: **Story 007 — validator schema family, ADR-0003 (ContentValidator scaffold).** Then 005 → 008 → 009 → 010.
- **Note**: Story 007 begins the ContentValidator (a DI RefCounted, not the loader). It is the first *validator* story and may need to establish `src/core/content/content_validator.gd` scaffold + a diagnostics pattern. Watch for a genuine design decision (validator API shape / severity model) — may warrant a checkpoint.

## Session Extract — /story-done 2026-07-15 (Story 007)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**.
- Story: `production/epics/part-database/story-007-validator-schema-family.md` — ContentValidator scaffold + schema/enum/nullability/range families (AC-01/02/03/17/18/20/21/22/24).
- Files: **new** `src/core/content/content_validator.gd` (`ContentValidator`, DI RefCounted, `validate(catalogs, log_sink) -> {ok, errors, warnings}`, LogSink-routed); **new** `src/core/content/content_catalogs.gd` (`ContentCatalogs` DI aggregate, append-only, one `parts: PartCatalog` slot); test `tests/unit/content/part_validator_schema_test.gd` (31 tests, **new** `tests/unit/content/` dir).
- Evidence: **85/85 suite green, 239 asserts** (Godot 4.7 + GUT 9.7.1). 10/10 ACs COVERED. Each family pairs clean+corrupt fixture (discriminates per ADR-0003). No `push_error`/`DirAccess`/`duplicate()` in src (grep-verified). Scan step (`--editor --quit`) run to register the 2 new class_names before headless GUT.
- Tech debt logged: 4 items → `docs/tech-debt-register.md` — (1) `ContentCatalogs` born without home story (append-only infra); (2) **`damage_type` gating NEEDS USER CONFIRMATION** — reserved always rejected, MVP-value required only when `active_skill_id != &""` (avoids false-positives on skill-less/Core parts); (3) reserved-element uses generic `content_invalid_element` code; (4) stale "Godot 4.6" label.
- **Design calls (both resolvable from specs, no checkpoint):** `ContentCatalogs` aggregate shape (mirrors ADR-0004 ServiceContext bundle); `damage_type` skill-gating (logged for confirmation but defensible + non-blocking).
- Next: **Story 005 — Formula 1 (stat aggregation), ADR-0005.** Then 008 → 009 → 010. Stories 008/009 EXTEND this validator (do not fork).

## Session Extract — /story-done 2026-07-15 (Story 005)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**.
- Story: `production/epics/part-database/story-005-total-stat-formula-f1.md` — Formula 1 total Symbot stat composition (`max(0, floor(sum × chassis_modifier + ε))`).
- Files: **new** `src/core/stats/total_stat_formula.gd` (`TotalStatFormula.compute_final_stat`, pure static, reuses `StatMath.floor_eps` + `maxi`); **modified** `src/core/stats/balance_config.gd` (appended sparse `chassis_modifiers: Dictionary` = GDD Formula 1 table); test `tests/unit/part_database/total_stat_formula_test.gd` (14 tests).
- Evidence: **99/99 suite green, 265 asserts**. 5/5 ACs. AC-05(b) pipeline discriminator composes through `UpgradeFormula` (−10/+12 intermediates asserted; raw-feed path asserted → 0 ≠ 2). `python3` scan: 0 mismatches vs Fraction oracle across sums −440–880 × six tabled modifiers; `max(0,·)` exercised 2640×.
- Tech debt logged: 3 items → (1) `chassis_modifiers` is an untyped NESTED Dictionary — nested-dict `.tres` round-trip UNVERIFIED (Story 001 only verified `Dictionary[StringName,int]`); Story 010 must verify or keep code-default + validator-assert; (2) sparse-table validator assertion needed (joins 004/006 balance-section notes); (3) stale "Godot 4.6" label.
- **Key infra**: `BalanceConfig` now carries all three MVP tables (upgrade_multipliers, drop_rate_by_rarity, chassis_modifiers). ContentValidator balance section (deferred) must assert all three against the GDD.
- Next: **Story 008 — validator content-rule/budget/synergy family (AC-04/10/11/12/19/23), ADR-0003.** EXTENDS the Story-007 `ContentValidator` (do NOT fork). Then 009 → 010.

## Session Extract — /story-done 2026-07-15 (Story 008)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**.
- Story: `production/epics/part-database/story-008-validator-content-budget-family.md` — ContentValidator content-composition families (AC-04/10/11/12/19/23): synergy tags, Prototype ±/concentration, Boss-grade break condition, stat budgets + single-stat cap, Common-cap/Rare-floor primary bounds.
- Files: **modified** `src/core/content/content_validator.gd` (EXTENDED, not forked — 8 new `_check_*` methods + `_warn` helper + `_cfg`; families gated behind `_cfg != null`); **modified** `src/core/stats/balance_config.gd` (APPEND-ONLY: `stat_budgets`, `primary_stat_common_caps`, `primary_stat_rare_floors` — GDD verbatim); **modified** `src/core/content/content_catalogs.gd` (APPEND-ONLY `balance: BalanceConfig` slot); test **new** `tests/unit/content/part_validator_content_test.gd` (22 tests).
- Evidence: **121/121 suite green, 308 asserts** (was 99). 6/6 ACs COVERED. Discriminating fixtures python3-Fraction-verified: AC-19 24/35=0.686<0.70; AC-11 499 fails / 500 passes; AC-12 Boss-Chassis 61-in-budget but 56>55 single-cap isolates the two checks.
- **Config-gating design call (resolvable, no checkpoint):** Story 008 families read `BalanceConfig`, so they run ONLY when `ContentCatalogs.balance` is injected; Story 007's schema-only fixtures inject none → 85 prior tests stay green. Per ADR-0005 the budget/cap/floor tables went INTO BalanceConfig (append-only), NOT a new config resource.
- Tech debt logged: 3 items → (1) **NEEDS CONFIRMATION** ADR-0003/0005 config-vs-constant boundary (budget tables in BalanceConfig via DI; structural maps + fixed thresholds as validator constants); (2) nested `stat_budgets` `.tres` round-trip unverified — joins the `chassis_modifiers` open question; validator balance section must assert all SIX tables vs GDD (Story 010); (3) stale "Godot 4.6" label.
- Next: **Story 009 — validator referential integrity (AC-13) + `level_requirement`/`level_growth`/`upgrade_effects` entry-shape + chassis-required-when-CHASSIS.** EXTENDS this same validator. Then 010 (author real content + CI mount + nested-dict `.tres` round-trip verification).

## Session Extract — /story-done 2026-07-15 (Story 009)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**.
- Story: `production/epics/part-database/story-009-validator-referential-level-fields.md` — ContentValidator cross-DB referential integrity (AC-13) + `level_requirement` rarity floors (TR-part-011) + `level_growth` CORE-only (TR-part-012). **Integration** type.
- Files: **modified** `src/core/content/content_validator.gd` (EXTENDED — 3 new `_check_*` methods + `RARITY_LEVEL_FLOORS` const + `_refs_mounted`/`_move_ids`/`_passive_ids`; family gated behind `_refs_mounted`); **modified** `src/core/content/content_catalogs.gd` (APPEND-ONLY: `move_ids`/`passive_ids` `{StringName:true}` sets + `references_mounted: bool`); test **new** `tests/integration/content/part_referential_integrity_test.gd` (15 tests; **new** `tests/integration/content/` dir).
- Evidence: **136/136 suite green, 335 asserts** (was 121). 4/4 ACs COVERED. Fixtures schema-valid (007 always runs) so only 009 findings surface; balance left unmounted to keep 008 dormant → isolates 009. Gating test proves the family is inert until a resolution index is mounted.
- **Design calls (both resolvable, no checkpoint — logged for confirmation):** (1) Move/Passive resolution = two append-only `{StringName:true}` id-set slots on `ContentCatalogs` (no `MoveCatalog`/`PassiveCatalog` class — those epics out of scope), gated by `references_mounted`; ADR-0003 + Story-007 `ContentCatalogs` precedent. (2) `level_requirement == 0` → unset sentinel → defaults to 1, so Rare+ parts left at 0 FAIL their floor (must author explicitly); COMMON-0 passes floor 1.
- Tech debt logged: 4 items → (1) reconcile the move/passive id-set seam when Move/Passive DB epics land; (2) **CONFIRM** the `level_requirement==0` floor-fail semantics; (3) scope drift — `PartDef` comments attribute `drop_conditions`/`upgrade_effects` entry-shape to "Story 009" but the ACs don't; NOT implemented — defer to Story 010 / follow-up + fix comments; (4) stale "Godot 4.6" label.
- **ContentValidator now spans 3 families**: schema (007, always) + content-composition (008, gated `balance != null`) + referential/level (009, gated `references_mounted`). Story 010 mounts all three on real content at CI/dev-boot.
- Next: **Story 010 — author real Part content + wire CI mount + verify nested-dict `.tres` round-trip** (`chassis_modifiers`, `stat_budgets`) — the LAST Part-DB story. Also carries: entry-shape drop_conditions/upgrade_effects gap, the 4 balance-table validator assertions (upgrade_multipliers/drop_rate/chassis_modifiers/stat_budgets/caps/floors vs GDD), CI global-class-cache regen for new class_names.

## Session Extract — /story-done 2026-07-15 (Story 010 — CLOSES Part Database epic)
- Verdict: **COMPLETE WITH NOTES**. Story → **Complete**. **Part Database epic → ✅ Complete (all 10 stories Done).**
- Story: `production/epics/part-database/story-010-author-content-wire-ci.md` — author MVP part content + wire CI content suite. Config/Data.
- **Co-design mode** (user chose "Co-design the roster with me"): roster designed section-by-section, approved with full stat spreads shown before authoring.
- Content shipped (via a throwaway scratchpad generator, `.tres` committed as source-of-truth): **14 `PartDef`** under `assets/data/parts/` (8 Common starters, 1/slot + 4 Rare + 1 Boss `scrapjaw_rustcrawler_claw` + 1 Prototype `wild_overdrive_cannon`); `assets/data/catalogs/part_catalog.tres`; `assets/data/balance_config.tres`. Manufacturers: Ironclad=tank/Thermal-sig, Boltwell=energy/Volt-sig, Scrapjaw=kinetic/Kinetic-sig, wild=junk. `servo_arm_family` chain = Common→Rare→Boss.
- CI gate: **new** `tests/unit/content/part_catalog_ci_test.gd` (9 tests) — loads real catalog+balance headless (CACHE_MODE_REPLACE), mounts all 3 validator families (balance + refs manifest), asserts `ok==true`, completeness (files==entries), roster structure. Auto-discovered by `.gutconfig.json` subdirs → no workflow edit.
- Evidence: **153/153 suite green, 410 asserts** (Godot 4.7). Smoke: `production/qa/smoke-part-content-2026-07-15.md`. **Nested-dict `.tres` round-trip VERIFIED on real content** — epic's last open technical unknown, CLOSED. (Isolated spike: `tests/unit/content/balance_config_nested_roundtrip_test.gd`.)
- 7/7 ACs COVERED. 6 expected AC-23 coverage warnings (advisory, MVP-minimum set).
- **KEY DISCOVERY → NEEDS USER DECISION**: GDD **Rule 2 ↔ Rule 8 contradiction** — Rule 8 (validator-enforced) requires an active skill on ALL Rare+ non-Core parts; Rule 2 says Chassis/Chipset/Energy-Cell have none + Legs has a passive. MVP content SIDESTEPS by authoring higher-rarity parts only in skill-native slots (Core=passive; Head/Arms/Weapon=active). Blocks Rare armor/chipset frames until reconciled.
- Tech debt logged (6): Rule2↔Rule8 (DECISION); CI Godot 4.6.0 stale; forward-ref skill/passive ID manifest (5 skill + 3 passive) for Move/Passive epics; Prototype drop-condition rule authoring-only (not validator-enforced); balance-table-equals-GDD assertion STILL OPEN; drop_conditions/upgrade_effects entry-shape still unimplemented + stale PartDef comments.
- Next: no more Part-DB stories. Options — (a) next Foundation epic (Move/Passive/Consumable/Enemy/Damage-Formula, all unstoried); (b) 4.6→4.7 ADR re-validation sweep; (c) reconcile Rule2↔Rule8. Subagents were DEAD this session (1M-context credit error) — all work done inline/lean.
