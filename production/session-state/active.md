# Active Session State

## Session Extract — UI .tscn+Theme migration + asset pipeline (2026-07-18c)
- USER DIRECTIVE: migrate the 3 code-built screens → .tscn + central Theme; THEN build the asset pipeline; THEN a separate folder of English Pixel Lab prompts for EVERYTHING.
- **Theme** `assets/ui/theme/symbots_theme.tres` = single source of truth (base Button/Panel/ProgressBar/Label + variations TitleLabel/HeadingLabel/DimLabel/Enemy|Player|Energy|BreakBar/PrimaryButton/TargetButton). Sprite-swap path = StyleBoxFlat→StyleBoxTexture, no screen edits. NOTE: placeholder uses ROUNDED corners; art-bible wants CHAMFERED 45° — switch when real chrome lands.
- **Migration (hybrid)**: static shell in .tscn w/ `%`-unique nodes; data-driven content (enemy markers, candidate list, stat rows, target buttons, reveal overlay) STAYS code-generated into named containers. Battle/Overworld/Workshop all done. ScreenManager already `load(.tscn).instantiate()`s all three — @onready %refs resolve.
- **Asset pipeline**: project.godot set pixel-art defaults (canvas `default_texture_filter=0` Nearest + `[importer_defaults] texture` lossless/no-mipmaps/no-3d-compress). `assets/art/{hud,ui,characters,enemies,parts,consumables,overworld,icons,workshop}/` created (+.gdkeep). `assets/art/README.md` = full pipeline doc. LIVE HOOK: new `src/ui/art.gd` (`class_name Art`, static `texture(cat,id)`/`has`) + overworld enemy markers upgrade ColorRect→TextureRect when `enemies/<id>.png` exists (fallback safe). Convention: `res://assets/art/<category>/<id-with-underscores>.png`.
- **VERIFY**: --import clean, boot smoke clean (overworld 6 markers), **GUT 956/956 green, 4837 asserts** after every change incl. Art. No test references screens → migration can't regress the suite; boot is the screen gate.
- **art-prompts/**: `_style-guide.txt` (locked style) + `_README.txt` + characters(3) + enemies(10) + parts(13/16). Background agent a0c1d187e005165d2 RESUMED to finish: 3 wild parts, 8 consumables, hud/ui/overworld/icons/workshop categories, `_index.txt`. Awaiting completion notification.
- NEXT: on agent completion, verify art-prompts count/coverage; report to user. All 6 build tasks (#7–12) complete except art-prompts (#11, in background).

<!-- STATUS -->
Epic: Production stage ENTERED 2026-07-17 — Pre-Production → Production gate PASSED and stage.txt advanced by user say-so. Epic/Feature/Task tracking now active.
Feature: Presentation-tier authoring complete (all 4 gate gaps closed: hud/main-menu/pause specs Approved, art-bible v0.2 all 9 §, entity-inventory written). Next production work: /ux-design the 7 unspecced screens, then art/asset specs.
Task: DONE 2026-07-18b → WORKSHOP UX SPEC COMPLETE (`design/ux/workshop.md`, Status=Ready for Review). Signature screen; all 18 sections authored via /ux-design. Layout anchored to a user-supplied reference mock (landscape 3-column: Z1 top bar / Z2 slot rail / Z3 rotating-turntable stage + docked candidate filmstrip / Z4 context detail-panel). Reference reconciled to current canon: (a) MVP = Scrap-only currency (gem/cube counters reserved space, not rendered — cube≈Alpha Designs/blueprints); (b) busy diorama/sparks CUT per art-bible §2.6 calm-stable-background; (c) PREVIEW=try-on-bot (sprite swap + synergy preview, no commit, DCO-3) vs EQUIP=commit `part_equipped`; (d) headline 3 stats POWER/ARMOR/MOBILITY + (i)→full 11 (mapping is OQ2); (e) BUILD STATUS = EC-CP-05 legality banner; (f) UPGRADE added as the MVP Scrap sink (Part-DB Rule 10 curve 10/20/40/80/160), shown when an equipped part is inspected. 2 new-design forks user-approved: PREVIEW/EQUIP semantics + headline-stat set. 9 ACs (AC-WS-01..09), 7 OQs. entity-inventory #25 → "Specced (UX — pending /ux-review)". NEXT: `/ux-review workshop` (author INLINE — no Agent/Task subagents), then the remaining 6 unspecced screens (inventory/world-map/overworld/settings/victory/defeat). PRIOR 2026-07-18a → §3.8 MANUFACTURER-MODEL REFRAME (user co-design): manufacturer = surface-finish + set-synergy identity, ORTHOGONAL to role (mass/§3.2, set by CHASSIS) AND element (color/§4.2). Role UNLOCKED per manufacturer (any manufacturer × any role × any element) to maximize part-combination freedom. Coherence audit: blast-radius tiny — schema (part_def/part_validator: manufacturer/element/chassis_archetype already 3 independent fields), all GDDs, and content needed ZERO changes; only art-bible re-coupled role via a retired "mass tendency" column. Wrote: (1) art-bible §3.8 full rewrite (3-var surface scheme; 3 manufacturers Ironclad/Scrapjaw/Boltwell + **wild = evolved-organic/biome-adaptive** exception; guardrails: seams stay engineered so wild≠fauna, biome variation = shared base + per-terrain overlay §8.2); (2) §3.4 wild far-organic sentence; (3) §3.9 checklist "three surface variables"; (4) full art-bible faction→manufacturer terminology sweep (Doc-Status resolution note, §1 Principle 2, §5.4 enemy read, §8.4 naming token `[manufacturer]`∈{ironclad,scrapjaw,boltwell,wild} + retired-placeholder caveat); (5) entity-inventory #5 → Reference(resolved) + blocker line struck, #3 "× rarity × faction" → "× manufacturer"; (6) game-concept.md coherence pass — fixed the ONE genuine conflict (line 206 "Damage types **and factions** use color coding" → element carries color, manufacturers = surface finish per new model) + 4 synonym cleanups (89/142/173/286 faction→manufacturer). FINAL VERIFY grep design/ = CLEAN (only residual "faction" = generic template examples in empty registry/entities.yaml `entities: []`, not the retired model). Whole-project coherence GUARANTEED per user Message B. **GATE ADVISORY #2 DISSOLVED**: "4 faction names owed by narrative before faction art" (gate-check-...2026-07-17b.md §Advisory #2) RESOLVED — faction/part art unblocked; left gate doc unedited (historical). Memory: project-manufacturer-identities + project-art-bible-deferred-decisions + MEMORY.md index updated. 2 non-blocking notes to user: existing ~16 .tres keep 1-element-per-manufacturer lean (schema permits mixing, open Alpha); role×manufacturer content coverage is part-db roster scope. PRIOR 2026-07-17j → FIRST PRODUCTION WORK: /asset-spec (solo) for entity #1 The Mechanic → design/assets/specs/mechanic-assets.md written (ASSET-001 overworld walk 64×96 · ASSET-002 Oficina idle 256² · ASSET-003 battle-intro cameo 256²; 2 masc/fem variants, palette via ONE shared palette-swap ShaderMaterial). Inline technical pass (no subagent): 0 blocking conflicts, memory ~1.5MB negligible, 1 draw call each; 2 refinements folded (64×96 portrait cell; shared recolor shader + flat indexed regions). Created design/assets/asset-manifest.md (3 assets, all Needed). entity-inventory #1 → Specced. 2 open flags: `char_` naming prefix extends §8.4 (ratify next art-bible touch); confirm tiers/atlas w/ UI programmer at impl. PRIOR: stage.txt advanced Pre-Production → **Production** (user "sim"). Gate report Stage-advance note updated to record it. Prior this session: (1) /ux-review hud|main-menu|pause all APPROVED; (2) /gate-check pre-production RE-RAN → PASS (14/14, 0 blockers, report ...2026-07-17b.md); (3) /asset-spec → design/assets/entity-inventory.md (36 entities + 10 screens). Deferred (correctly, not edited): battle.md in-battle pause-affordance placement + PG-08 fading-log chrome (Open Questions in hud.md/pause.md/art-bible §7.5); 4 faction names (art-bible §3.8) owed by narrative before faction art. NEXT (production, user's choice) → /ux-design the 7 unspecced screens (workshop/inventory/world-map/overworld/settings/victory/defeat), OR /asset-spec entity work, OR pick up sprint-1 stories.
<!-- /STATUS -->

## ⇒ PLAYABLE VERTICAL SLICE WIRED + VERIFIED (2026-07-18d)

User goal (standing authorization): "keep going until we have a game I can play and test
(walking on map, finding enemies, battling, building on workshop)." **DONE + headless-verified.**

**Launch (Mac):** `/Applications/Godot.app/Contents/MacOS/Godot --path /Volumes/SSDLuan/Projetos/symbots`
(or open the project in the Godot editor and press Play — main_scene = `res://src/scenes/game.tscn`).

**The loop that now runs** (all-code placeholder UI, prototype REWRITTEN to production `Screen`
standards — no import from `prototypes/`):
- `boot_screen.gd` → loads 4 catalogs + balance, RngService.init, assembles PlayerInventory +
  starters + SymbotBuild.with_starters + SynergySystem + ServiceContext, `TBC.set_config`,
  `ScreenManager.set_context` → `goto_overworld()`.
- `overworld_screen.gd` (NEW) — walk (WASD/arrows in `_physics_process` + tap-to-move; taps in
  `_unhandled_input` — PROCESS_MODE_DISABLED-safe) into any of 6 enemy markers (real EnemyDB) →
  `_ctx.screens.enter_battle({enemy_id, encounter_type})`. Has a WORKSHOP button.
- `battle_screen.gd` (NEW, rewrite of the 744-line prototype) — target ARM/HEAD/CORE (ButtonGroup).
  Region hits fill the break meter (`floor(dmg × break_spillover)` to structure); CORE hits deal
  full damage. Break arm/head → `TBC.note_break_event(&"arm_broken")` (the harvest gate). On
  VICTORY `DropSystem.resolve_drops` gated on the fired break-set → parts land in `ctx.inventory`.
  CONTINUE → `EventBus.encounter_resolved` → ScreenManager frees battle, restores overworld.
- `workshop_screen.gd` (NEW) — 8 slots × candidate list from `inventory.parts_for_slot` × live
  stat readout. Select a harvested part → `preview_swap` delta (pure, no mutation) → EQUIP commits
  via `SymbotBuild.equip_part` (displaces old part back to inventory). Signal-driven refresh.

**Seam fixes made this session:**
- `TBC` autoload +`note_break_event()` +`context()` proxies.
- `ServiceContext` +`balance: BalanceConfig`; wired in boot.
- `ScreenManager` filled `goto_overworld`/`enter_battle`/`open_workshop`/`close_workshop` +
  `_restore_overworld` (keep-alive: hide + PROCESS_MODE_DISABLED, restore on return).
- **`PlayerInventory.add()` alias** — `SymbotBuild.equip_part` calls `_inventory.add(current)` on
  displacement, but the concrete store only had `receive_part_instance`; the equip tests use a
  double that has `add`, so this was a latent production-only crash. Fixed by aliasing.
- Workshop `_on_equip_pressed` re-entrancy: `equip_part` emits `stats_changed`/`part_equipped`
  synchronously → `_refresh` nulls `_candidate` mid-method; captured `part_id`/`slot` up front.

**Verified headless** (throwaway SceneTree driver, not shipped):
navigate → battle → break arm (`fired={arm_broken}`) → CORE-kill → VICTORY → parts to inventory →
overworld restored → open workshop → equip `ironclad_aegis_frame` into CHASSIS → **structure 42→57**
(matched the previewed +15 delta) → displaced common returned → close → overworld restored. **Zero
script errors.** Boot smoke clean (`boot_complete{starters:8}`, `overworld_entered{markers:6}`).
**GUT 956/956 green, 4837 asserts** (unchanged by these edits — nothing broken).

**NOTE for hands-on play:** to harvest, target the enemy's ARM/HEAD until the break bar fills
(that's the drop gate), THEN switch target to CORE to actually finish it — hitting only a broken
region deals reduced spillover damage and you'll lose the DPS race (the battle log hints this).

**Not done (out of slice scope):** no save/load persistence across app restarts (session-only
inventory/build); no XP/leveling on victory; no consumables/switch/flee UI paths; placeholder art
only (ColorRects/Labels, no sprites). None of these block the walk→fight→harvest→build loop.

## ⇒ ACTIVE WORK (2026-07-18c) — /team-ui battle pipeline, Phase 3 in progress

**Pipeline**: `/team-ui battle` (review mode = lean). Source of truth = `design/ux/battle.md`
(approved UX spec — DO NOT edit unilaterally). Patterns = PC-01/02 + PG-01…09.

- **Phase 1 (UX spec + review)**: DONE earlier — battle.md is Approved/Revised.
- **Phase 1c prereqs done this session**: `/ux-review workshop` + `/ux-review patterns` both
  **APPROVED**; workshop.md Status flipped to Approved (0 blocking / 4 advisory).
- **Phase 2 (Visual Design)**: ✅ **DONE 2026-07-18c**. art-director (spawned model:sonnet after
  a 1M-context death on the default pin) produced + user-approved
  **`design/art/battle-visual-design.md`** (8 §: identity, color, typography, spacing, animation,
  asset manifest, a11y verification checklist, downstream handoff). Locked: C-1…C-7 palette;
  Heat gauge 3-zone (cool C-3 / amber #F0900A ≤1.5Hz+⚠@70 / red #CC3020 ≤2.5Hz+⚠@90, ~5:1
  luminance sep = Deuteranopia safety); break pips = 48×24 chamfered tiles (never circular);
  status badges glyph-primary; all VFX single-shot spritesheets (3Hz gate); chamfer ninepatch
  chrome, no rounded corners; shared assets via assets/ui/theme.tres.
- **Phase 3 (Implementation)**: ⛔ **BLOCKED → pivoted to FOUNDATION-FIRST build.**
  - godot-specialist engine review DONE (excellent notes — the BattleScreen node-tree/anim/theme
    blueprint; captured in transcript, resume agent a5e86a91262125a92 to reuse). BUT the review
    assumed presentation-tier infra that **does not exist**.
  - **DISCOVERED GAP (codebase inspection 2026-07-18c)**: `project.godot` has ZERO autoloads
    (ADR-0004 10→11 roster unbuilt); NO `src/ui/`; NO `Screen` base / `ServiceContext` /
    `ScreenManager` / `Game` root / `BootScreen`. `BattleController` is a per-session `RefCounted`
    (NOT autoload) declaring only 3 signals (battle_ended, battle_start_refused, hit_resolved) —
    none of the per-stat runtime view-signals a live HUD binds to. Core battle + content logic IS
    built. This is the "trailing-UI" antipattern the producer flagged (contract systems LEAD).
  - **USER DECISION 2026-07-18c**: **Build the foundation first**, then resume battle screen.
  - **PLAN APPROVED 2026-07-18c** → `docs/architecture/presentation-tier-foundation-plan.md`
    (executable spec) + memory [[project-presentation-tier-foundation]]. Two ratified decisions:
    (A) **BattleController = Option A autoload wrapper** (thin Node slot 11 wraps the per-session
    RefCounted, forwards signals; honors ADR-0007, NO erratum); (B) **FULL ADR-0004 scope**
    (BootScreen sequencer + catalog load + Overworld keep-alive).
  - **BUILD ORDER**: Phase 0 (project.godot autoloads + main_scene) → Phase 1 (Game.tscn/
    ScreenManager/Screen/ServiceContext) → Phase 2-A (BattleController +~14 view-signals, ∥) →
    Phase 2-B (wrapper) → Phase 3 (BootScreen) → Phase 4 (BattleScreen UI = resume /team-ui).
  - **✅ WAVE 1 COMPLETE + VERIFIED (2026-07-18c)**: Phase 0 + Phase 1 + Phase 2-B-skeleton.
    All 11 autoloads (`src/autoloads/`), `src/scenes/game.tscn` + `screen_manager.gd`,
    `src/ui/screen.gd` + `service_context.gd`, Option-A wrapper, `control-manifest.md` +2
    forbidden, 4 presentation `_test.gd` (24 tests). **`--headless --import` clean; GUT 937/937
    pass, 4771 asserts** on Godot 4.7.
  - **KEY FIX — slot-11 singleton renamed `BattleController` → `TBC`** (user-ratified). Collides
    with core `class_name BattleController`; `TBC` matches ADR-0002 §4. Recorded as ADR-0007 §1
    erratum + plan-doc row + memory. Agent stalled mid-write twice + shipped the collision +
    2 silently-skipped test files (parse errors on `BattleController.` as singleton); main-loop
    caught via per-file test-COUNT check, fixed, re-verified. ScreenManager →
    `get_node_or_null("TransitionLayer")`; bus-count test → `get_script_signal_list()`.
  - NEXT: **Wave 2 = Phase 2-A** — ~14 view-signals on `src/core/battle/battle_controller.gd`
    + emission sites (plan §5 table) + per-signal GUT (gameplay-programmer, model:sonnet), then
    extend the wrapper's marked "Phase 2-A" block to forward them; then Phase 3 BootScreen;
    then Phase 4 BattleScreen (ui-programmer, using the godot-specialist Phase-3 blueprint).
- **Phase 4**: parallel review (ux-designer + art-director + accessibility-specialist) — after impl.
- **Phase 5**: polish.

**Durable constraints in play**: (1) ALL subagent spawns MUST pass `model: sonnet` explicitly
(default pin → "1M context / Usage credits required" death — see project-subagent-model-1m-resolved).
(2) Do NOT edit `design/ux/battle.md` unilaterally. (3) Ask before Write/Edit; multi-file changes
need full-changeset approval.

## ⇒ HANDOFF FOR NEXT SESSION (post-/clear, 2026-07-17g) — ux-review the 3 specs, then re-gate

**Read this block first, then `design/art/art-bible.md` §5 and the 3 UX specs.** All FOUR
Pre-Production gate authoring gaps are CLOSED. One quality-check remains before a clean PASS.

**DONE this session:**
- **art-bible §5–9 authored** (`design/art/art-bible.md`, now v0.2, all 9 sections; header
  Status = Complete). §5 Character / §6 Environment / §7 UI-HUD / §8 Asset Standards / §9
  Reference Direction — all derived from the locked §1–4 (no new palette/shape/color).
  **AD-ART-BIBLE sign-off = APPROVED [2026-07-17]**, authored in-role (formal director-panel
  spawn N/A — lean mode skips it + subagent spawning disabled per durable instruction; recorded
  exactly like /gate-check's skipped Director Panel). Carried-forward open decision: the 4
  faction NAMES (§3.8 placeholders) still pending narrative team.
- **§5 CORRECTED after user feedback** (important — do not re-erase): the game HAS a player
  avatar. Two identity layers now in §5.1–§5.2:
  (1) **The Mechanic** = player avatar, a human engineer; overworld walk sprite (Pokémon-style)
      + shown at the Oficina bench + a battle-intro cameo; customization = **Masc/Fem + a simple
      color/palette choice**, nothing deeper; **NO combat stats** (no HP/level/attributes) —
      cosmetic/narrative identity only; world-palette, lower-saturation than any Symbot (§3.5).
  (2) **The Build/CORE** = combat character; ALL progression here (CORE levels on battle-XP,
      parts carry stats). Pokémon trainer/creature split, named as such.
  Old §5.2–5.5 renumbered → §5.3–5.6 (CORE / bot-read / pose / LOD); external refs in §8.3 and
  §9 updated. Verified 5.1→5.6 sequential, all §5 cross-refs resolve.

**NEXT ACTIONS (in order):**
1. **`/ux-review hud`, `/ux-review main-menu`, `/ux-review pause`** — the 3 specs are In Design;
   the Pre-Prod→Production gate quality-check "all key-screen UX specs have passed /ux-review"
   needs a recorded verdict (APPROVED or NEEDS-REVISION-accepted) for each. **Author the reviews
   INLINE — NO Agent/Task subagents** (durable constraint; same as gate-check's skipped panel).
2. **Re-run `/gate-check pre-production`** — all 4 ❌ artifacts from
   `production/gate-checks/gate-check-pre-production-to-production-2026-07-17.md` are now present;
   expect a clean PASS (or CONCERNS only on the optional entity-inventory, which is non-blocking).
3. On PASS: user decides whether to advance `production/stage.txt` → Production (they previously
   chose to stay Pre-Production until gaps closed; ask before advancing).

**WATCH-OUTS carried forward:**
- **Do NOT edit `design/ux/battle.md` unilaterally.** Two needed additions are flagged as Open
  Questions (in-battle pause-affordance placement; PG-08 boxed-log → fading-corner-log refinement,
  also noted in art-bible §7.5). They land only via a /ux-review that explicitly acknowledges them.
- Review mode = **lean** (`production/review-mode.txt`); stage = **Pre-Production**
  (`production/stage.txt`) — do not advance without user say-so.
- Optional/non-blocking: `/asset-spec` → `design/assets/entity-inventory.md` (gate recommends, not
  requires). The mechanic avatar (§5.2) + Symbot parts would be its entities if run.

## Session Extract — Vertical Slice Phases 4b–4d COMPLETE + playtest-validated 2026-07-17f
- Built the full interactive slice in `prototypes/symbots-vertical-slice/battle_screen.gd` (+ `_smoke_screen.gd` headless regression). All-code Control UI, ADR-0008 signal-driven, touch-first ≥56px. Reuses real BattleController/SymbotBuild/DropSystem; synthesizes only basic_attack MoveDef + Part-Break subscriber.
- 4b battle screen: structure/energy/break bars, ARM/HEAD/CORE target picker, ATTACK. 4c PILHAGEM reveal: authentic DropSystem RNG, DropSystem+seeded RNG created ONCE and reused across rematches so gradient pity accumulates (RARE fight 6). LUTAR DE NOVO reuses same BattleController. 4d OFICINA: current ARMS + candidates with preview_swap delta, EQUIPAR, VOLTAR À BATALHA → next fight on upgraded build.
- TWO bugs caught by the smoke-runner (not the type-checker): (1) _start_fight didn't reset _current_target → rematches never re-hit arm (fixed: reset to ARM + toggle); (2) preview_swap returns a SIGNED DELTA dict (hypo−current), not absolute stats — panel rendered it as absolute; fixed by after = current+delta. Now preview delta == realized delta (verified headless). Realized equip: struct 42→45, power 24→35.
- PLAYTEST (Luan, F6): "hits ficaram mais fortes… me senti mais forte e não foi só sobre números. senti que meu esforço me recompensou." Scope caveat he raised: single-part reward LOOP validated; full build-COMPOSITION fantasy (multi-slot synergy, effects, attack choice) out of slice scope, untested — REPORT risk line.
- DESIGN FINDING (for REPORT): drop_conditions are rate MULTIPLIERS not gates — a part drops at base rate even without its break; breaking only boosts the rate (MHW-authentic). Faithful to the system; flag as a Production design decision.
- NEXT: Phase 4e — playtest debrief (skill Phase 5 questions) + REPORT.md (PROCEED/PIVOT/KILL) + prototypes/index.md row. BUILD-PLAN Velocity Log already updated (4a–4d, all day 1).

## Session Extract — Vertical Slice Phase 4a headless harness COMPLETE 2026-07-17e
- CONCEPT: Symbots vertical slice — validation Q: "stock Symbot → break a component → harvest the targeted part → re-equip → feel stronger, ~3 min unguided; AND buildable at representative quality on the existing core?" Scope: 1v1, team-swap CUT. Art quality: headless (no UI yet); 4b+ = touch-first Control per ADR-0008.
- BUILT (all in `prototypes/symbots-vertical-slice/`, throwaway — never into src/): `slice_bootstrap.gd` (Phase 4a harness, SceneTree), `slice_log_sink.gd` (concrete LogSink, preloaded not class_name), README.md, BUILD-PLAN.md. Reuses REAL src/core (SymbotBuild, BattleController, DropSystem, DF-1) + REAL .tres content. Synthesizes only (a) a basic_attack MoveDef (moves unauthored) + (b) the Part-Break subscriber (hit_resolved→region-HP tally→note_break_event — presentation-tier, unbuilt in src).
- RESULT: loop PROVEN end-to-end, zero crashes. Fight 6 (seed 20260717) drops RARE scrapjaw_reinforced_servo_arm; re-equip over common servo_arm → physical_power 24→35 (+11), structure +3, mobility +1. 913/913 GUT green, 4740 asserts after the content change.
- BALANCE FINDING (Finding 4 in BUILD-PLAN): first run LOST all 40 fights. Instrumented (real BattleController): stock all-common build (42 struct, basic ×1.0, no weapon skill) deals ~13/hit (7 hits to kill) but dies in 3 (~15/hit taken); enemy roster is ALL tuned for developed builds (CORE leveling + authored weapon skills). USER DECISION = "retune real content now". Ran a real-BattleController tuning sim over 5 candidates; USER PICKED 52/12/11.
- EDIT to `assets/data/enemies/rustcrawler.tres`: structure 85→52, physical_power 24→12, mobility 22→11; break_hp recomputed 29→18 (arm, ×0.35) & 18→11 (head, ×0.22) to satisfy enemy_validator (stored==derive_break_hp, break_hp<structure). xp_value 55 unchanged (derives from level+class, not structure). Validates clean (test_enemy_db_valid_catalog_loads_true_no_errors passes). Harvest path wins ~40% HP left / efficient path ~64% — legible risk-reward.
- OPEN content gaps for Production (NOT slice blockers): (a) no authored STARTER LOADOUT (harness picks first-common-per-slot arbitrarily); (b) no authored WEAPON MOVES — parts carry no active_skill_id (Finding 1); (c) Part-Break subscriber must be promoted to a real system (Finding 2).
- NEXT: Phase 4b battle screen (Control) — first interactive UI, touch-first, drives submit_action seam by hand. Multi-turn: Luan runs Godot + reports. Then 4c drop reveal, 4d workshop, 4e playtest + REPORT.md (PROCEED/PIVOT/KILL).

## Session Extract — /ux-design confirmed already-complete + accessibility PATH fix 2026-07-17d
- Ran `/ux-design` (no arg). BOTH gate artifacts already existed & Approved from 2026-07-14: `design/ux/interaction-patterns.md` (466 lines, 9 patterns + 2 primitives, seeded from battle.md — correct path) and the accessibility doc (GAG Basic tier, 5 decisions locked). Bonus: `design/ux/battle.md` (36 KB full battle-screen UX spec) also exists. The prior handoff's "pre-gate blocker doesn't exist" was STALE.
- ONE real fix (same failure mode as the CI drift): accessibility doc lived at `design/ux/accessibility-requirements.md` but `/gate-check` (SKILL.md L114/172/225) + every UX/arch skill + ux-design Phase 2g expect `design/accessibility-requirements.md`. Gate would report a fully-Approved doc as MISSING on path alone. USER CHOSE "move to design/ (recommended)".
- Did: `git mv` → `design/accessibility-requirements.md`; updated 3 LIVE inbound links (design/CLAUDE.md, design/art/art-bible.md ×2, design/ux/interaction-patterns.md), preserving the sibling interaction-patterns link. Left 2 dated arch-review snapshots (`architecture-review-2026-07-14*.md` — say "none exist" as of that date) + session-log/archive untouched as historical records. Verified: canonical path exists, no live doc references old path, no self-reference.
- `design/player-journey.md` still absent — OPTIONAL context (skill Phase 2b), NOT a gate blocker; gate-check L519 treats it as a create-if-wanted, not a hard requirement.
- NEXT: `/gate-check production` (a.k.a. Technical Setup → Pre-Production). Both blockers cleared.

## Session Extract — /test-setup confirmed already-complete + engine-drift fix 2026-07-17c
- Ran `/test-setup`. Skill defaults to gdUnit4 — IGNORED; project uses GUT (per CLAUDE.md/coding-standards). Full infra already existed from 2026-07-14: `.github/workflows/tests.yml` (correct GUT CI), `.gutconfig.json`, `tests/README.md`, `tests/smoke/critical-paths.md`, full unit+integration tree (913 tests). The prior handoff's "CI workflow doesn't exist yet" was STALE/wrong.
- ONE real fix: CI + README pinned **Godot 4.6** but toolchain was re-pinned to **4.7** on 2026-07-15 (binary = 4.7.stable.official, project.godot = 4.7). CI would've run the suite on the wrong engine. Bumped `.github/workflows/tests.yml` (`setup-godot` version 4.6.0→4.7.0 + comment) and `tests/README.md` (engine 4.6→4.7). GUT 9.6.1 in README is CORRECT (a session note's "9.7.1" was a misremember).
- VERIFIED (2026-07-17): `4.7-stable` released 2026-06-18; `chickensoft-games/setup-godot@v2` takes GodotSharp NuGet-style strings where `"4.7.0"` == 4.7 STABLE (pre-releases carry a suffix, e.g. `4.7.0-rc.1`). So `"4.7.0"` is the correct string for the pinned stable toolchain (NOT the `4.7.1` RC). No further change needed; comment in tests.yml documents the convention.
- NEXT: `/ux-design` → `/gate-check production`.

## ⇒ HANDOFF FOR NEXT SESSION (2026-07-17b) — Save/Load epic + DS-009 DONE

**Full Save/Load Foundation epic built and closed (6/6), DS-009 release-blocker cleared.** User chose "Full Save/Load epic" over a stopgap; built the whole ADR-0001 provider-envelope system, then implemented DS-009 against it. Zero Agent/Task subagents (never-1M constraint held). Suite **869 → 913 green, 4740 asserts** (+44: SL-1..SL-6 + DS-009; each story's count-rise verified exactly).

**What shipped (all `src/`, NOT `src/core/` — the ADR-0001 file-I/O purity carve-out):**
- `src/persistence/save_load_service.gd` (`SaveLoadService`, RefCounted, injected LogSink + injectable file backend): provider registry (fail-loud dup), `snapshot_envelope`/`restore_envelope`, SL-PRED-1 version predicate (`==`→RESTORE, `<`→MIGRATE=behaviorally-REFUSE@v1, `>`→REFUSE, missing/non-int→REFUSE; REFUSE leaves state untouched), two-phase order-independent restore (Phase 1 restore facts / Phase 2 rederive), atomic write (tmp → full failure surface `open`/`store_string` bool/`get_error` → flush-before-close → rotate one-gen `.bak` → rename), Release-firing 2 MiB budget guard, int-cast discipline (`as_int`), opaque preservation of unregistered provider keys (deep-copied), `save(slot)`/`load(slot)` + `.bak` fallback, never-destroy-unparseable (`JSON.new().parse()` — instance parse, quiet, never global push_error), `save_emergency()` (identical envelope+atomic path).
- `src/persistence/file_backend.gd` (`FileBackend`): real `FileAccess`/`DirAccess` behind a thin seam.
- `src/core/drop_system/drop_system.gd` — the `&"drop"` provider: `snapshot()`/`restore()`/`rederive()` over the two pity maps (`_proto_pity_credit`, `_boss_pity_counter`), int-cast on restore via a LOCAL `_restore_int_map` (NOT `SaveLoadService.as_int` — core must not import persistence; the provider protocol is satisfied STRUCTURALLY/duck-typed, zero core→persistence coupling).

**Tests:** `tests/unit/persistence/` (save_load_service, envelope_predicate, atomic_write, budget_opaque, emergency_recovery, drop_provider + reusable `fake_file_backend.gd` with failure-injection knobs) + `tests/integration/persistence/drop_roundtrip_test.gd` + **`tests/integration/drop_system/pity_persistence_test.gd`** (DS-009 / AC-DS-28: full-path round-trip + post-reload boundary — advance `+= c`/`+= 1` from restored 72→75 / 7→8, next qualifying attempt fires the pre-roll guarantee → drop + reset, RNG untouched).

**Bookkeeping done:** SL-1..SL-6 story files → Done; save-load/EPIC.md → Complete; drop-system Story 009 + EPIC.md → Done (9/9); production/epics/index.md both rows → Complete + Core paragraph/suite counts updated (913/913). ADR-0001 groundwork amendment (4.6→4.7 re-validation, two-pity-map envelope) landed earlier this session.

**Registration note:** No boot/autoload seam exists yet (ADR-0004 boot sequencer is an unbuilt Technical-Setup deliverable) — DS-009/SL-6 registration is exercised by the integration harness standing in for boot (`register_provider(&"drop", …)`). Real boot wiring registers `&"drop"` alongside the other 4 providers (`progression`/`inventory`/`workshop`/`settings`) when those systems are built (ADR-0001 additive, no format-version bump).

**NEXT:** Technical Setup → Pre-Production gate (`/test-setup`, `/ux-design`) then `/gate-check production`. Persistence no longer blocks ship. VC-7 (on-device iOS budget measurement) is a deferred vertical-slice hardware pass, not MVP code.

---

## ⇒ (SUPERSEDED) HANDOFF (2026-07-17) — Sprint 1 DONE, Core layer Complete

**Sprint 1 is implemented and closed.** Autonomous continuation under "implement all stories in this sprint" (zero Agent/Task subagents — never-1M constraint held throughout). State to resume from:

- **Encounter Zone epic CLOSED (8/8).** All 8 EZ stories implemented in `src/core/encounter_zone/` + closed via lean bookkeeping (Status→Done, ACs checked, Test Evidence `[x] Complete`, Completion Notes). Shipped: value types (`ZoneDef`/`TerrainPatch`/`SpawnEntry`/`BossEncounter`), `EncounterResolver` (EZ-1 clamp, EZ-2 weighted walk, `filter_valid` sub-pool exclusions + empty-pool sentinel, WILD/BOSS TBC handoff, WIN_COUNT first-access + `requires_defeated` sequencing, LIGHTER_REGATE delta re-gate + ALWAYS_OPEN, gate-param validation + reserved-gate fail-safe LOCKED), and `ZoneContentLinter` (EZ-8, 11 ADVISORY offline content linters proven against fixtures). Test files under `tests/unit/encounter_zone/`.
- **Drop System epic CLOSED (8/9).** DS-1..DS-8 implemented + closed (prior sessions). **DS-009 stays Blocked** on the Not-Started Save/Load system (ADR-0001 must define the pity-map serialization interface) — AC-DS-28 (pity persistence) is a release-blocker.
- **Full GUT suite: 869/869 green, 4606 asserts** (EZ dir 68 tests). EZ-8 added exactly +21 (848→869). `--import` run before every GUT pass with new `class_name`; counts verified to rise by exactly the number added.
- **`production/epics/index.md`** updated: both Core rows → Complete, Core layer → **fully Complete (5/5)**, Next Step → Technical Setup gate.

**NEXT ACTIONS (in order):**
1. **Technical Setup → Pre-Production gate:** `/test-setup` (scaffold CI workflow + tests/integration structure), `/ux-design` (interaction-patterns + accessibility-requirements). Both are pre-gate blockers that don't exist yet.
2. **Architect Save/Load (ADR-0001 is Accepted, no code)** — the natural next epic; unblocks DS-009 / AC-DS-28, which the game can't ship without. Worth surfacing to the user.
3. `/gate-check production` once the above land.

**IMPLEMENTATION GOTCHAS (still binding, bit us every Core epic):**
- `Godot --headless --import` BEFORE GUT for any new `class_name`, or GUT silently skips the uncompilable `_test.gd` and stays green at the OLD count. Verify the count rose by exactly #tests added.
- Type every test `var` (`var x: int = …`) — untyped `:=` off a Variant source throws "Cannot infer type" → whole-file parse skip while suite stays green.
- `src/core/` stays pure: injected seeded RNG (never global `randf()`/`RngService`), diagnostics via injected LogSink (never `push_warning`/`push_error` from `src/`), content defs read-only.

---

## ⇒ (SUPERSEDED) HANDOFF (2026-07-17 EOD) — Sprint 1 implementation
**Do this first in the new session.** Three planning skills ran back-to-back this session (all markdown only, zero code, zero Agent/Task subagents — the never-1M constraint is still binding). State to resume from:

1. **`/create-stories drop-system` — DONE.** 9 Drop System stories written to `production/epics/drop-system/story-001..009-*.md` (8 Logic **Ready** + Story 009 Integration **Blocked** on the Not-Started Save/Load system — AC-DS-28 is a release-blocker). EPIC.md Stories table + `production/epics/index.md` Drop row (→ "9 stories") + Core-layer paragraph updated. All 12 TR-drop + 30 BLOCKING ACs + AC-DS-28 placed. **All 5 Core epics are now storied.**

2. **`/sprint-plan new` — DONE.** Wrote `production/sprints/sprint-1.md` + `production/sprint-status.yaml` (the machine-readable source of truth read by `/sprint-status`, `/story-done`, `/help`). **Sprint 1 goal: close the Core layer** (implement Encounter Zone 8 + Drop System 8) → reach the Pre-Production → Production gate. 11 Must Have (the encounter→battle→drop loop) + 5 Should Have; **DS-9 recorded `blocked`** (nice-to-have tier, not workable — Save/Load must land first). Review mode = lean → PR-SPRINT producer gate skipped.

3. **`/qa-plan sprint` — DONE.** Wrote `production/qa/qa-plan-sprint-1-2026-07-17.md` (14 Logic unit + 2 Integration + 1 Config/Data; 0 Visual-Feel/UI; no playtests). **Did NOT back-fill story files** — each story already carries inline `## QA Test Cases` from `/create-stories`; back-filling would clobber them. If a future session wants per-AC specs injected into stories, that's still an open option (decided against, not forgotten).

**NEXT ACTIONS (in order):**
- `/story-readiness production/epics/encounter-zone/story-001-zone-data-model-ez1-encounter-trigger.md` **or** `production/epics/drop-system/story-001-dropsystem-host-victory-trigger-ds1-roll-core.md` — both anchors are zero-dependency; start either, or interleave the two epics (they're mutually independent, both RNG-injected Core).
- Then `/dev-story` on that anchor; work down each epic's `Depends on:` chain (EZ: 001→{002,003,005,008}→004→{006,007}; DS: 001→{002,003,004,005,008}→006→007).
- `/sprint-status` mid-sprint for burndown.

**IMPLEMENTATION GOTCHAS (bit us every prior Core epic — see extracts below):**
- Run `Godot --headless --import` BEFORE GUT whenever new `class_name` scripts are added, or GUT silently skips the uncompilable `_test.gd` and stays green at the OLD count. **Verify the test count rose by exactly the number of tests added.**
- Type every `var` in tests (`var x: int = …`) — an untyped `:=` off a Variant source (`Array` index, `weakref`, `.size()`) throws "Cannot infer type" → whole-file parse skip while suite stays green.
- Any new floor/ceil formula → python3 exact-oracle scan (specialists err in BOTH directions). DS/EZ mostly reuse scanned formulas + integer thresholds, but DS-1 clamp / EDB break-hp fixtures deserve a check.
- `src/core/` stays pure: injected seeded RNG (never global `randf()`/`RngService`), diagnostics via injected LogSink `warn(code, detail)` (never `push_warning`/`push_error` from `src/`), content defs read-only.

**PROJECT-LEVEL OPEN THREAD:** DS-9 / AC-DS-28 (pity persistence) is a ship-blocker gated on the **Not-Started Save/Load system (ADR-0001 is Accepted, but no epic/stories/code yet)**. Sprint 1 completes with DS-9 Blocked; the *game can't ship* until Save/Load is built and DS-9 passes. **Save/Load is the natural next epic to architect after Sprint 1** — worth surfacing to the user.

## Session Extract — Synergy System epic CLOSED via lean per-story gate 2026-07-17
- **Gate run:** `/code-review` + `/story-done` inline as godot-gdscript-specialist (lean, zero subagents). All 5 story files → `Status: Complete` + `Last Updated: 2026-07-17` + Test Evidence box checked (with test filename) + a `## Completion Notes` section. EPIC.md Status/Stories-table → Complete + a Closure Record; `index.md` Synergy row → ✅ Complete, Core layer → **3 of 5 closed through the gate**.
- **Coverage re-verified by SCENARIO CONTENT (the TBC lesson):** unlike TBC, Synergy's test-file headers map CLEANLY to story ACs — no drift. All 26 checkbox ACs across the 5 stories have discriminating fixtures (each carries explicit "FAIL X = wrong-behavior" witnesses). The 3 load-bearing DoD-gate tests were each read in full and confirmed genuinely discriminating: AC-SYN-05b (`String(tier_id)` sort — reverse-alpha authored, alpha-first ironclad owns `shared_test`), AC-SYN-14 (`evaluate_silent` emit-count 0 + AC-SYN-25 no-self-lock), AC-SYN-13 B (`preview` subtracts displaced tags, not add-only delta).
- **0 code gaps → markdown-only closure, 0 tech-debt entries.** AC-SYN-06/10 (TR-syn-010, SYN-F4 `max(0, base+delta)`) are legitimately consumer-owned — NOT a Synergy-engine gap; now discharged by the implemented TBC (`CombatantSnapshot.effective_stat`). One full GUT run validated all 5 closures: **762/762 green, 4268 asserts** (unchanged — no tests added).
- **Deferred as designed (not a closure blocker):** synergy tier `.tres` content authoring is a later pass on OQ-1/2/3 (data format / MVP stat values + budget / feasible effect IDs). Engine was built + closed against the injected `Array[SynergyTierDef]` DI seam.

## Session Extract — Turn-Based Combat epic CLOSED via lean per-story gate 2026-07-17
- **Gate run:** `/code-review` + `/story-done` inline as godot-gdscript-specialist (lean mode, zero subagents). All 14 story files → `Status: Complete` + `Last Updated: 2026-07-17` + Test Evidence box checked + a `## Completion Notes` section (Assembly format). EPIC.md Stories table + Status → Complete; `production/epics/index.md` TBC row → ✅ Complete and Core layer → **3 of 5 done**.
- **Coverage verified by SCENARIO CONTENT, not test-header labels** — the test-file header comments carry AC IDs that drifted from the GDD (e.g. switch_item header calls flee "AC-TBC-10" but GDD numbers flee AC-TBC-17; turn_test mislabels AC-TBC-11). Every one of the 42 checkbox ACs mapped to a discriminating test.
- **5 Logic-AC test gaps CLOSED this gate (green suite couldn't surface them):** (1) AC-TBC-11 victory-before-heat → `test_victory_is_resolved_before_the_killing_move_applies_heat` in `_lifecycle`; (2–5) Story 011 AC-TBC-10 Burn-kill-at-turn-start [player forced-switch + enemy VICTORY], AC-TBC-18 A bench-status-freeze, AC-TBC-18 B down-clears-all → 4 tests in `_switch_item`. All present in source, just unproven. Typed all new `var`s (Dictionary/Combatant/bool) to dodge the INFERENCE_ON_VARIANT silent-skip trap.
- **Full suite after gate:** **762/762 green, 4268 asserts** (was 757/757/4244 → +5 tests, +24 asserts). Count rose by exactly 5 → no silent skip.
- **1 ADVISORY logged** to `docs/tech-debt-register.md`: `BattleController` is a DI `RefCounted`, not the ADR-0007 slot-11 autoload (no behavioral impact; revisit at Presentation-tier battle entry, ADR-0008). In-story notes: Story 001/014 unit-vs-integration test path; Story 002 live enemy pools (harmless — enemy skips decay/recharge).
- **Synergy System reminder:** ✅ RESOLVED — Synergy was closed through the same lean gate on 2026-07-17 (see the extract above this one). Now at ✅ Complete in index.md.

## Session Extract — Turn-Based Combat epic IMPLEMENTED (all 14 stories) 2026-07-17
- **Directive:** "write all 14, then implement them" — the 14 TBC story files were written in a prior window; this window implemented the engine + GUT tests inline (zero Agent/Task subagents; never-1M constraint binding).
- **Production code (src/core/battle/):** `combatant.gd` (+`is_overheated` flag); `symbot_loadout.gd` (`SymbotLoadout` DI seam carrying precomputed `is_build_valid` + `final_stat` snapshot — controller REFUSES on the flag, never re-derives stats mid-battle per Manifest); `battle_context.gd` (`BattleContext` per-battle RefCounted — team/pools/turn_order/`fired_break_events` set/outcome; dropped synchronously at battle end); `passive_effect_registry.gd` (`PassiveEffectRegistry` — 3 seeded elemental riders volt→SHOCK / thermal→BURN(weapon-only) / kinetic→STAGGER; alphabetical unknown-id dedup log); `battle_controller.gd` (the FSM orchestrator — `start_battle` Rule-2 validity gate → snapshot → initiative TBC-F1 → park at ACTION_PENDING; `begin_turn` ordered cooling-decay→TBC-F2 recharge→Burn-tick-LAST; `apply_move_heat` overheat trip w/ `floor(max_structure×0.10)` recoil + THERMAL +5; switch/flee/item; idempotent `_end_battle` emitting the 8-field `battle_ended`, `_ctx=null` before `is_battle_active=false`). Added 4 @export overheat constants to `balance_config.gd`.
- **Tests (7 new files this window, +43 tests → tbc dir 68/68, 12 scripts):** `tests/unit/tbc/` — passive_effect_registry (5), battle_controller_start (4), _initiative (3), _movepanel (3), _turn (5), _switch_item (7), _lifecycle (4). Support: `fake_synergy_system.gd` (preload duck-typed) + reused `spy_log_sink.gd`. (Stories 007–010 formula/status/resolver kernel — battle_formulas/status_system/damage_pipeline/repair_scan/subtarget_routing — landed in earlier windows this session, tasks #1–3.)
- **GOTCHA HIT + FIXED (same class, TWICE):** GUT ran 10 scripts vs 12 files on disk — count delta caught 2 silent skips. `battle_controller_lifecycle_test.gd:119` `var wr := weakref(_bc.context())` (weakref→Variant) and `battle_controller_switch_item_test.gd:126` `var before := ctx.team[0].current_structure` (Array-index→Variant) → INFERENCE_ON_VARIANT warning-as-error → whole-file parse skip while suite stayed green. Fix: annotate `var wr: WeakRef =` / `var before: int =`. Re-ran: tbc 68/68, 12 scripts (== 12 files, reconciles).
- **No python3 scan owed:** TBC applies EXISTING scanned formulas/coefficients (TBC-F1..F7 defensive epsilons verified 2026-07-10/11); no coefficient retuned. The 4 new overheat constants are integer thresholds + one pct whose single floor (`floor(155×0.10)=floor(15.5001)=15`, round→16) is discriminator-tested in `_turn`.
- **Full suite:** `--import` (4 new class_name: BattleContext/BattleController/PassiveEffectRegistry/SymbotLoadout registered) → **757/757 green, 70 scripts, 4244 asserts**, zero failures/skips.
- **NEXT:** close TBC via the lean per-story gate (`/code-review` + `/story-done`) like Assembly/Synergy, then EPIC.md/index.md → Complete; or forward to the next Core epic.

## Session Extract — Synergy System epic IMPLEMENTED (all 5 stories) 2026-07-16
- **Directive:** "implement all stories from this epic" (synergy-system, immediately after `/create-stories` wrote the 5 files). Done inline, zero Agent/Task subagents (never-1M constraint still binding).
- **Production code (src/core/synergy/):** `synergy_tier_def.gd` (`SynergyTierDef` DI value object — id/requirements/stat_delta/effects; deliberately NOT a `.tres`, OQ-1 open); `synergy_system.gd` (`SynergySystem` RefCounted — 3 entry points `evaluate`/`evaluate_silent`/`preview` over ONE private `_compute` = count→activate→aggregate; `cached_bonus_block`+`active_synergies` never null; SYN-F4 is CONSUMER's job, only emits delta; all diagnostics via injected LogSink `warn` channel).
- **Tests (5 files, +32 tests):** `tests/unit/synergy/` — core_evaluate (11), aggregation (7), effect_dedup_order (5), evaluate_silent (3), preview (6). Support: `synergy_fixtures.gd` (duck-typed `TagPart` holder, null-capable for AC-SYN-19 B) + `spy_log_sink.gd` (preload, not class_name — ADR-0002 §5).
- **DoD gates proven:** AC-SYN-05b `String(tier_id)` sort discriminator (content authored reverse-alpha → keep-first must follow alphabetical, not file, order — the StringName intern trap); `evaluate_silent()` emit-free (counter==0); `preview()` cache-write-free/emit-free incl. AC-SYN-13 B add-only-delta-shortcut discriminator (displaced part's tags MUST be subtracted).
- **GOTCHA HIT + FIXED (same class as Assembly):** `synergy_preview_test.gd` `var warns_before := _log.warns.size()` — `_log` untyped → Variant → "Cannot infer type" parse error → GUT silently skipped the whole file (green at 683/57, only 4 of 5 suites, 26 not 32 tests). Caught by count arithmetic (32 written − 26 landed = one 6-test file). Fix: `var warns_before: int = …` ×3. Re-ran: **689/689 green, 58 scripts, 4024 asserts** (was 657/53; +32 tests, +5 scripts — count rose exactly, no silent skip). Ran `--import` first (2 new class_name scripts registered).
- **No python3 scan owed:** SynergySystem introduces NO new floor/ceil — integer sums only.
- **Deferred as designed:** SYN-F4 (TR-syn-010) consumer-owned (TBC/Workshop at `StatMath.effective_stat`); synergy tier `.tres` content blocked on OQ-1 (format)/OQ-2 (values)/OQ-3 (effect IDs from TBC) — engine built against injected `Array[SynergyTierDef]` seam.
- **Bookkeeping done:** 5 story files Status→Done + evidence box checked; EPIC.md Status→Done + Stories table Done + Implementation Record; index.md Synergy row→✅ Done + Core layer-status (2 of 5 Core epics implemented) + Next Step.
- **NEXT:** `/create-stories turn-based-combat` (largest Core epic — 42 reqs — consumes both Assembly's `final_stat` snapshot and the synergy bonus block at BATTLE_INIT).

## Session Extract — Symbot Assembly per-story gate CLOSED (7/7) 2026-07-16
- **Directive:** "formally close the epic symbot-assembly through the per-story gate (/code-review + /story-done, lean) as was done for Consumable/Passive DB." Done inline/lean (never-1M constraint; zero Agent/Task subagents; review-mode.txt = lean).
- **All 7 stories now Status: Complete** with `## Completion Notes` (verdict / criteria / deviations / test evidence / code review). Baseline validated by ONE full GUT run — **657/657 green, 3934 asserts, 53 scripts** (Godot 4.7 headless; known part_db leak/orphan noise, not a regression). Closure only edits markdown, so one run covers all 7. Reviewed inline as godot-gdscript-specialist against the actual src (`stat_pipeline.gd`, `symbot_build.gd`, `part_instance.gd`) + tests + tr-registry TR-sa-001..009 + the GDD ACs.
- **Verdicts:** 6/7 APPROVED clean; Story 006 APPROVED WITH NOTES. Implementation matched every AC exactly (26 test funcs across 7 files cover all 15 AC-SA IDs).
- **Gate caught one real ADVISORY the green tests can't:** Story 006 SA-F2 preview `compute_stat_delta(slot, candidate_part: PartDef)` hard-codes the hypothetical candidate at **tier +0** (`symbot_build.gd:183`), while equip installs the real PartInstance at its `tier`. A future Workshop-UI preview of an owned candidate at tier>0 shows a delta ≠ what equip realizes. AC-SA-08 is tier-0 so it passes; latent API limitation → logged ADVISORY to `docs/tech-debt-register.md` (fix = instance-taking overload in the Presentation epic).
- **Story 007 DoD gate DISCHARGED:** AC-SA-15 (160-not-168 CP-F3 ordering) = Core Progression AC-CP-18. Green. Cross-epic note left in story-007: AC-CP-18 stays DEFERRED in the CP GDD (that epic has no code yet) — it can reference this passing test when built, not re-author it.
- **Bookkeeping:** 7 story files closed; EPIC.md Status→✅ Complete + Stories table Done→Complete + Next Step (gate done → /create-stories synergy-system); index.md row→✅ Complete + Core layer-status + Next Step updated.
- **NEXT:** Core forward progress — `/create-stories synergy-system` (SYN-F4 is the composition point Assembly deliberately leaves out per Rule 8; its BATTLE_INIT path snapshots Assembly's `final_stat`).

## Session Extract — Symbot Assembly epic IMPLEMENTED (all 7 stories) 2026-07-16
- **Directive:** "implement all the stories from this epic" (symbot-assembly). Done inline, zero Agent/Task subagents (never-1M constraint still binding).
- **Production code (src/core/stats/):** `part_instance.gd` (RefCounted wrapper: instance_id/part/tier); `stat_pipeline.gd` (`StatPipeline.derive` = the single SA-F1→CP-F3 composition point, static/pure Layer-1; recharge>30 reports-not-clamps; unknown part/growth keys warn); `symbot_build.gd` (Layer-2 DI RefCounted owner: equip Rule 3, eager recompute, move/passive pools, SA-F2 `preview_swap`/`compute_stat_delta`, owner-declared `part_equipped`/`stats_changed`). Added `canonical_stat_keys` @export (11 keys) to `balance_config.gd`.
- **Tests (7 files, +26 tests):** `tests/unit/symbot_assembly/` — stat_pipeline_derive (7), symbot_build_recompute (2), move_pool (4), passive_pool (3), preview_swap (2); `tests/integration/symbot_assembly/` — symbot_build_equip (5), cp_f3_ordering (3). Support: `assembly_fixtures.gd` + `spy_log_sink.gd` (preload, not class_name — ADR-0002 §5).
- **Discriminators locked:** SA-F1 floor 9-not-10 (F2), F2b −5-not-6 (epsilon load-bearing); AC-SA-15 **160-not-168** (CP-F3 is flat POST-floor add: floor(100×1.20)=120 + 10×(5−1)=40 = 160; wrong pre-multiply order = (100+40)×1.20 = 168).
- **GOTCHA HIT + FIXED:** `symbot_build_equip_test.gd:77` `var x := _inv.added.size()` — `_inv` untyped → Variant → "Cannot infer type" parse error → GUT silently skipped the whole file (green at 652/52). Fix: `var x: int = …`. Re-ran: **657/657 green, 53 scripts, 3934 asserts** (was 631/46; +26 tests, +7 scripts — count rose exactly, no silent skip). Ran `--import` before GUT (4 new class_name scripts).
- **No python3 scan owed:** StatPipeline introduces NO new floor/ceil — reuses scanned StatMath/UpgradeFormula/TotalStatFormula (ADR-0005 reuse).
- **Bookkeeping done:** 7 story files Status→Done + evidence box checked; EPIC.md Stories table Done + implemented-note; index.md Symbot row→Done.
- **NEXT:** either close Assembly through the formal per-story gate (`/code-review` + `/story-done`, lean mode) like Consumable/Passive DB, or forward to `/create-stories synergy-system` (its battle path snapshots Assembly's final_stat).

## Session Extract — Enemy DB CLOSED (Story 010 roster authored) → Foundation COMPLETE 2026-07-16
- **Directive:** "author Story 010" — the MVP enemy roster (last open Foundation work). Prerequisite sub-ask "add a thermal rare part first" honored. Done inline (never-1M constraint; zero Agent/Task subagents).
- **Authored:** 10 `EnemyDef` `.tres` in `assets/data/enemies/` (8 WILD + 2 BOSS) + `assets/data/catalogs/enemy_catalog.tres`. Blocking CI gate `tests/unit/content/enemy_catalog_ci_test.gd` (8 tests): loads real roster CACHE_MODE_REPLACE, injects Part-DB `set_part_lookup` seam → validator `ok==true`, **0 errors, 0 warnings**.
- **Prerequisite Part-DB add:** `ironclad_aegis_frame.tres` (RARE/CHASSIS/Thermal/Ironclad, passive `pass_ablative`, `chassis_cracked` ×3.0; structure 30/armor 8/resistance 6 = 44, inside CHASSIS-RARE budget [38,46]) so the 2 Thermal wilds drop a native Thermal Rare. Part catalog 15→16; part CI updated (+`pass_ablative`, count→16).
- **All math verified before authoring:** every `break_hp` (24 regions) == EDB-1 `derive_break_hp`; every `xp_value` (10) == CP-F4; every TTK in class band both channels (WILD-early 2–4, WILD-mid 3–5, BOSS 12–18); every `loot_pool` id resolves in Part DB.
- **Verify:** full suite **631/631 GUT green, 3853 asserts, 46 scripts** (count rose +8 — no silent skip; ran `--import` first). Smoke: `production/qa/smoke-enemies-2026-07-16.md`.
- **LESSON (logged prior):** stat budgets live as `@export` DEFAULTS in `balance_config.gd`, NOT in `balance_config.tres` — validator correctly rejected the first aegis_frame at sum 51. Also: `PartDef.Element` has NO 0 member (starts VOLT=1); null-element is the raw int 0 (the `core_element` default sentinel) — CI checks `elements.has(0)` directly.
- **Follow-up flag (non-blocking):** enemy skill IDs are forward-refs — no `move_catalog` content authored; enemy validator is skills-count-only. Move DB content pass owes the 14 skill IDs.
- **Bookkeeping done:** story-010 Status→Complete + Completion Record + ACs checked + Test Evidence→Complete; EPIC.md Status→Complete (10/10) + Next Step; index.md Enemy row→Complete + Foundation layer→fully Complete + Next Step→/create-epics layer: core.
- **NEXT:** Foundation is fully delivered → offer `/create-epics layer: core`.

## ⇒ HANDOFF FOR NEXT SESSION (2026-07-16 EOD) — Passive DB per-story gate
**Do this first in the new session.** Consumable DB is fully closed (8/8, per-story gate). User will now run the SAME gate on **Passive DB (7 stories)** — implemented + green but stories are marked "Passing"/"Done", never through the formal `/code-review` + `/story-done` closure gate (no verdicts / Completion Notes / code-review evidence). Repeat exactly what was just done for Consumable DB:
1. **Constraint (still binding):** never spawn Agent/Task subagents this session-mode — they die on "1M-context credits" (memory `project-subagent-model-1m-resolved`). Run everything **lean/inline**; review inline "as godot-gdscript-specialist". Review mode = lean (`production/review-mode.txt`) → `/story-done` Phase 5 records code-review, does not spawn.
2. **Run the full GUT suite ONCE up front** for the baseline (`/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json`; expect **452/452 green**). Closure only edits markdown, so one run validates all 7 closures — no per-story runs.
3. **Stories to gate:** `production/epics/passive-database/story-00[1-7]-*.md`. For each: verify ACs vs `docs/architecture/tr-registry.yaml` (TR-pdb-*) + the GDD, then set `Status: Done`→`Complete`, `Last Updated`→date, append `## Completion Notes` (Completed / Criteria X/Y / Deviations / Test Evidence / Code Review). Watch for AC-vs-implementation gaps the green tests can't catch (the Consumable gate found story-007's missing BOSS_GRADE roster check — log any such gap to `docs/tech-debt-register.md` as advisory, don't block).
4. **Passive DB scope reminder:** the DB owns NO runtime executor — runtime firing ACs (AC-PDB-02, 04–11, 17) are the **TBC Rule 13 executor epic**, correctly deferred; don't flag their absence as a gap.
5. **After all 7 closed:** update `production/epics/passive-database/EPIC.md` (Stories table Done→Complete + Next Step: gate done not deferred) and confirm `production/epics/index.md` Passive row = Complete.
6. **Then forward progress:** Enemy DB is the last unimplemented Foundation epic (10 stories, already storied + Ready) → `/story-readiness production/epics/enemy-database/story-001-*.md` → `/dev-story`. Enemy Story 010 (roster authoring) trails until the Part-DB roster backs its loot pools. After Enemy DB → **Foundation COMPLETE** → `/create-epics layer: core`.

## Session Extract — Consumable DB per-story gate CLOSED (8/8) 2026-07-16
- **Directive:** "review the last epic's stories so we can close them" → user chose **Full per-story gate** (`/code-review` + `/story-done` on each). Consumable DB was implemented-and-green but stories were only marked "Passing"/"Done", never through the formal closure gate (verdicts/Completion Notes/code-review evidence).
- **All 8 stories now Status: Complete** with `## Completion Notes` appended. Baseline validated by ONE full GUT run (452/452 green, 3467 asserts) — story-done only edits markdown, so one run covers all 8 closures. Reviewed inline as godot-gdscript-specialist (never-1M constraint: zero Agent/Task subagents).
- **Gate caught a real gap the green tests could not:** Story 007 (validator family) is MISSING the `BOSS_GRADE` roster check that AC-CD-18 + `consumable_def.gd:26` doc-comment both promise — a BOSS_GRADE consumable validates silently. Closed COMPLETE WITH NOTES; logged to `docs/tech-debt-register.md` (ADVISORY — AC-CD-18 is itself an advisory gate). The exact-count-8 roster check was intentionally replaced by non-brittle family-coverage — accepted, NOT debt. story-008 content verified field-by-field vs GDD AC table (all 8 .tres match exactly).
- **Insight:** green tests confirm the code does what its tests say, never what the story *said* — the review pass vindicated the user's instinct to close through the gate.
- EPIC.md Stories table Done→Complete; Next Step updated (gate done, not deferred); index.md already Complete.
- **NEXT (open decision):** Passive DB (7 stories) has the identical gap (marked Passing, never gated) — offered same treatment. OR return to Enemy DB implementation (last unimplemented Foundation epic). Awaiting user choice.

## Session Extract — Consumable DB epic IMPLEMENTED (8/8 stories) 2026-07-16
- **Directive:** "implement all the stories from next epic" — Consumable DB (Foundation, 8 Ready stories). Done inline (never-1M constraint honored, zero Agent/Task subagents; continued across a context compaction).
- **Result: all 8 stories implemented + green — 452/452 GUT, 3467 asserts** (was 370 pre-epic; +82 consumable tests, +8 scripts). EPIC.md → Complete; epics/index.md row + layer status + Next Step updated; all 8 story files Status→Done + test-evidence checked; smoke `production/qa/smoke-consumables-2026-07-16.md`.
- **Files created:** src/core/content/`consumable_def.gd` (4 enums 1-based APPEND-ONLY, 0=INVALID sentinel), `consumable_catalog.gd`, `consumable_db.gd` (thin host, null-safe `get_consumable`), `consumable_effects.gd` (pure CD-1..CD-5: restore_structure/reduce_heat/restore_energy int clamps + boost_drop/modify_encounter_rate float clampf), `consumable_use.gd` (pure `resolve()` transaction: qty→context→living-target→net-effect gates, Dict result), `beacon_state.gd` (per-battle flag, victory-only, spent-never-refunded), `encounter_modifier_state.gd` (sole mutator `on_overworld_step`, structural battle-freeze, latest-wins `apply`). **Modified:** `content_catalogs.gd` (+`consumables` slot APPEND-ONLY), `content_validator.gd` (+Consumable family @ end: schema/effect_params key+type/unknown-effect-type/strict `buy>sell`/coherence-advisory/family-coverage; dispatched when `catalogs.consumables != null`; now 1313 lines — under 1500 DoD extract threshold).
- **Content:** `assets/data/consumables/{weld_patch,repair_kit,field_forge,coolant_flush,power_cell,salvage_beacon,signal_jammer,scrap_lure}.tres` + `assets/data/catalogs/consumable_catalog.tres`; CI gate `tests/unit/content/consumable_catalog_ci_test.gd` asserts real content validates with 0 errors AND 0 warnings.
- **Tests:** `tests/unit/consumable_database/{spy_log_sink,consumable_def_schema_test,consumable_db_loader_test,restore_formulas_test,consumable_use_transaction_test,beacon_boost_drop_test,encounter_modifier_state_test}.gd`; `tests/unit/content/{consumable_validator_test,consumable_catalog_ci_test}.gd`.
- **GOTCHA (cost 1 wasted run):** adding new `class_name` scripts then running GUT headless → every reference is "Identifier not declared in scope" and GUT **silently skips** the uncompilable test files, leaving the suite green at the OLD count (tell: test total didn't move off 370 baseline). Fix: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import` BEFORE running the suite whenever new `class_name` types are introduced (registers the global class cache). Also: spy LogSink exposes `warns` not `warnings`.
- **Scope boundary preserved:** Consumable DB owns NO runtime executor — assigning healed values to a live Symbot / turn-consume / live drop roll / overworld step countdown / inventory overflow are deferred errata AC-CD-20/21/22/23 on the TBC / Drop / Encounter Zone / Inventory epics. The pure formulas + DI state models they will call ARE unit-covered here.
- **NEXT:** last unstoried-implemented Foundation epic — `/story-readiness production/epics/enemy-database/story-001-*.md` → `/dev-story` (10 stories, dependency order; Story 010 trails until Part-DB roster backs its loot pools). After Enemy DB → Foundation COMPLETE → `/create-epics layer: core`.
- Not yet run (batch directive): per-story `/code-review` + `/story-done`. Stop-hook auto-commits; push stays manual.

## Session Extract — /create-stories Consumable + Enemy DBs 2026-07-16 ("Story both now")
- **Directive:** "Story both now" — story Consumable then Enemy back-to-back, inline/lean (never-1M constraint honored, zero Agent/Task subagents). User is stopping here; **next session = implementation** (fresh session by user's choice).
- **Consumable DB — 8 stories written** (7 Logic + 1 Config/Data), all Ready, all ADR-0003. EPIC.md Stories table + Deferred note (AC-CD-20/21/22/23) + index row/layer-status updated. Story shape: 001 ConsumableDef schema+enums+catalog → 002 loader → 003 restore formulas CD-1/2/3 → 004 use-transaction/targeting/resource-neutrality → 005 Salvage Beacon BOOST_DROP CD-4 → 006 EncounterModifierState CD-5 (sole mutator `on_overworld_step`, structural battle-freeze) → 007 validator consumable family (strict `buy>sell`, `buy==sell` is the discriminator) → 008 MVP 8 `.tres` authoring.
- **Enemy DB — 10 stories written** (9 Logic + 1 Config/Data), all Ready, all ADR-0003. EPIC.md Stories table + two-seam note + Deferred note (AC-ED-11/12/16) + index row/layer-status updated. Story shape: 001 EnemyDef schema (15 fields incl. ELZS level/xp/completion_bonus + nested break_regions/loot_pool dict shapes — HIGH-risk 4.7 `.tres` round-trip) → 002 loader → 003 EDB-1 break_hp (`+0.0001` LOAD-BEARING, `180×0.35=63` proof; python3-scan fixtures) → 004 validator schema-presence family (creates `_validate_enemy_catalog` dispatch, gated on `catalogs.enemies != null`) → 005 stat-block → 006 break-region (EDB-3, **calls Story-003 `derive_break_hp`, no re-impl**) → 007 loot/rarity/boss-grade gating (Part-DB referential live) → 008 harvest-decision(BLOCKING `loot_pool>break_regions`)/TTK(ADVISORY EDB-2)/density → 009 ELZS level/xp CP-F4/completion_bonus validation → 010 MVP roster authoring.
- **Two Enemy seams flagged in the stories:** (1) `EnemyAI` is GDD-only → Story 004 builds `ai_profile` referential as an injected accept-all predicate (non-empty active now, `has_profile` wired when EnemyAI lands). Part DB + Move DB are Complete → Story 007/010 referential wire live. (2) Story 010 is dependency-gated on a richer Part-DB roster — it must stop-and-flag rather than invent part ids.
- **TR-ID citations corrected post-write** (matched EPIC TR table): Story 004 dropped TR-edb-017; Story 005 TR-edb-005=WILD power cap / TR-edb-011=A-D ranges; Story 006 TR-edb-021=set-semantics / TR-edb-022=min-region / TR-edb-004=region_id uniqueness; Story 007 TR-edb-018=referential.
- **NEXT (new session):** `/story-readiness production/epics/consumable-database/story-001-consumabledef-schema-enums-catalog.md` (or enemy-database story-001) → `/dev-story`. Both epics implement in dependency order; Enemy Story 010 trails until Part-DB roster backs its loot pools. After both epics implemented → Foundation COMPLETE → `/create-epics layer: core`.
- **Constraint still binding:** never spawn Agent/Task subagents this session-mode (die on "1M-context credits" — memory `project-subagent-model-1m-resolved`). Stop-hook auto-commits; push stays manual.

## Session Extract — Passive DB epic IMPLEMENTED (7/7 stories) 2026-07-16
- **Directive:** "implement all the stories from next epic in order" — Passive DB (Foundation, 7 Ready stories). Done inline (never-1M constraint honored, zero Agent/Task subagents).
- **Result: all 7 stories implemented + green — 370/370 GUT, 3241 asserts** (was 293 pre-epic). EPIC.md → Complete; epics/index.md row + layer status + Next Step updated; all 7 story files Status→Done + test-evidence checked; tech-debt-register line 24 Passive side RESOLVED (item fully closed, both Move + Passive reconciled).
- **Files created:** src/core/content/`passive_def.gd` (5 enums 1-based APPEND-ONLY, `DEFAULT_STACKING` + `default_stacking_policy`), `passive_catalog.gd`, `passive_db.gd` (thin host, null-safe `get_passive`). **Modified:** `content_catalogs.gd` (+`passives` slot, +`passive_ids_from` builder — both APPEND-ONLY), `content_validator.gd` (+Passive family: legality matrix, params key-set, STRUCTURAL non-negative, Core trigger whitelist + duplicate-combo; dispatched when `catalogs.passives != null`).
- **Content:** `assets/data/passives/{volt_shock_on_hit,thermal_burn_on_weapon,kinetic_stagger_on_hit}.tres` + `assets/data/catalogs/passive_catalog.tres`; smoke `production/qa/smoke-passive-riders-2026-07-16.md`.
- **Tests:** `tests/unit/passive_database/{spy_log_sink,passive_def_schema_test,passive_db_loader_test,passive_stacking_policy_test}.gd`; `tests/unit/content/{passive_validator_schema_test,passive_validator_authoring_test,passive_referential_integrity_test,passive_riders_content_test}.gd`.
- **Two gotchas resolved:** (1) passive-only validator fixtures need `catalogs.parts = PartCatalog.new()` or `validate()` fires `content_missing_part_catalog`. (2) A passive-bearing Part fixture must be RARE, not COMMON — Rule 8 effect-capacity ceiling is 0 for Common (`content_effect_capacity_exceeded`).
- **Scope boundary preserved:** Passive DB owns NO runtime executor — status application / stacking dedup / aura+structure clamps (AC-PDB-02, 04–11, 17) are the **TBC Rule 13 executor epic**. OQ-PDB-1 MVP Core roster (≤5 Cores, deferred AC-PDB-D1–D4) is a separate game-designer content pass.
- **NEXT:** remaining unstoried Foundation epics — `/create-stories consumable-database` or `/create-stories enemy-database`. After both, Foundation complete → `/create-epics layer: core`.
- Not yet run (batch directive): per-story `/code-review` + `/story-done`. Stop-hook will auto-commit.

## Session Extract — /story-done 2026-07-16 (Part-DB story-011)
- Verdict: COMPLETE — 7/7 ACs passing, full traceability COVERED, Logic BLOCKING evidence gate passed, no blocking deviations.
- Story: `production/epics/part-database/story-011-validator-hardening-round11.md` — Validator hardening (Round 10/11 review-debt: AC-25/26/27 + entry-shape + AC-08(b) fixture sync).
- `/code-review` same session: APPROVED WITH SUGGESTIONS; all 4 applied (empty-drop_conditions test, payload-key `value` rename, dead-assignment cleanup, AC-10 co-fire doc note). Suite re-verified **294/294 green** (3015 asserts, 21 scripts, Godot 4.7 headless).
- Two specialist findings refuted by fact-check: typed `Array[Dictionary]` makes the "blocking" non-Dictionary crash unrepresentable (part_def.gd:146/166); F2b floor-variant divergent `[-2,-1,0,1,1,1]` re-confirmed via python (−0.0001 epsilon makes floor ≠ ceil even for integer-exact bases).
- Closure: story Complete + Completion Notes; Part-DB EPIC.md → ✅ Complete (011 row added); epics/index.md row + layer status + Next Step; systems-index row 1 production-debt note flipped OPEN → CLOSED.
- Tech debt logged: None (residuals documented in-story: AC-25(a)/AC-10 co-fire noise, entry-shape/product-low double-report, int multipliers accepted).
- Next recommended: story an unstoried Foundation epic — `/create-stories passive-database` (also unblocks tech-debt-register line 24 passive-side seam), or consumable/enemy DBs.

## Session Extract — Part-DB GDD Round-10 /design-review → NEEDS REVISION → all 7 blockers fixed (2026-07-16)

- **Full-mode review, headless standard-context workaround** (Agent-tool subagents die
  on the `claude-fable-5[1m]` settings pin — spawned 5 specialists + creative-director
  via `claude -p` child processes instead; user constraint: never 1M context).
- **Verdict: NEEDS REVISION (7 blockers)** — user chose revise-now; all 7 fixed in-session:
  1. EC↔AC citations (EC-05/07/13 no-AC clauses; EC-10→AC-08+AC-25; EC-11→AC-07)
  2. AC-09 sub-assertion (e) — 0.70×1.5×1.5=1.575 clamp discriminator
  3. Prototype focus floor: Chassis budget 40→42, strict > Rare primary FLOOR, **new AC-25**
  4. **New AC-26** — Prototype ≥3 drop conditions AND product ≥ ×3.0
  5. `level_growth` String→StringName: GDD Rule 1 pinned; `part_def.gd:204` re-typed
     `Dictionary[StringName, int]`; both Core `.tres` re-authored `&"key"`. **Suite
     271/271 green** + explicit headless .tres round-trip check PASS (typed-dict
     `.get(&"k")` returns 2/1, not 0)
  6. **New AC-27** — every stat_bonuses value ∈ [−55, 55] (60+8 Boss Chassis fixture)
  7. ×0.7 drop-penalty removed; Formula 3 floor >1.0 (Drop System Rule 5a alignment)
- Also: Open Questions honesty rewrite (deferred external deps listed). Header now
  "Approved — Revision Pending"; systems-index row 28 + review-log entry written.
- **Carried forward (NOT done):** P2 #8 Boss-grade "exclusive synergy bonus" rewording;
  P2 #9 Player Fantasy scope + cross-tag coverage; P2 #11 provisional drop-condition
  vocab freeze; **P3 validator-hardening fast-follow story** (AC-25/26/27 validator
  implementations + Story-009's promised entry-shape validators) — story not yet created.
- **Next: after /clear, run `/design-review design/gdd/part-database.md`** (fresh panel
  confirms fixes → restore Approved). Reviewer reports archived in session scratchpad
  (ephemeral); findings summarized in `design/gdd/reviews/part-database-review-log.md`.

## Session Extract — /dev-story Damage-Formula 001 (2026-07-16)
- Story: `production/epics/damage-formula/story-001-df1-kernel-compute-damage.md` — DF-1 kernel `compute_damage()` + `damage_floor` config
- Implemented INLINE (godot-gdscript-specialist background agent died on the 1M-context credit error — subagents remain unavailable this session).
- Files changed:
  - `src/core/stats/damage_formula.gd` — NEW. `class_name DamageFormula`; pure static `compute_damage(a, d, type_mult, cfg, log, crit_mult := 1.0) -> int`. `a==0 and d==0` guard → `cfg.damage_floor` before divide; float cast; T & crit pre-floor; `maxi(cfg.damage_floor, StatMath.floor_eps(pre_floor))`. Reads no state, no RNG.
  - `src/core/stats/balance_config.gd` — appended `@export var damage_floor: int = 1` (append-only, after `power_tier_multipliers`).
  - `assets/data/balance_config.tres` — authored `damage_floor = 1`.
  - `src/core/content/content_validator.gd` — added config-level `_check_balance_config()` (gated `_cfg != null`, runs once in `validate()`); const `DAMAGE_FLOOR_MIN := 0`; error `content_balance_damage_floor_negative`.
  - `tests/unit/damage-formula/damage_formula_kernel_test.gd` — NEW (14 tests, all 10 kernel ACs + config-floor honoring + validator guard). Plus local `spy_log_sink.gd`.
- Evidence: **243/243 suite green** (2907 asserts, 19 scripts, Godot 4.7); was 229 → +14. python3 exact-oracle scan: 0 mismatches / 131,769 inputs.
- Blockers: None.
- Next: /code-review src/core/stats/damage_formula.gd src/core/content/content_validator.gd then /story-done story-001. Then Story 002 → 003.

## Session Extract — Move Database epic COMPLETE (2026-07-16)

- **All 6 Move-DB stories implemented + tested green** in dependency order (001→006),
  mirroring the Part-DB epic's patterns (typed `.tres`, one catalog, DI ContentValidator,
  "extend never fork" families gated behind injected state).
  - **001** `MoveDef` schema + enums (append-only, 1-based, 0=sentinel) + `MoveCatalog`.
  - **002** `MoveDB` loader + null-safe lookup.
  - **003** MOVE-F1 power multiplier (post-DF-1 multiply, load-bearing epsilon
    `floori(x + 0.0001)`), discriminating fixtures.
  - **004** Move schema-validation family (`_validate_move_catalog` → per-move required
    fields / power-tier / targeting; gated on `catalogs.moves != null`).
  - **005** Authoring rules — energy-cost bands per tier, REPAIR Energy-brake floor,
    STATUS status_proc↔element match, DAMAGE innate-rider ban.
  - **006** Part↔Move referential integrity — `active_skill_id` resolves via the O(1)
    `move_ids` membership seam, gated on `references_mounted`.
- **Seam reconciliation (user-approved, Option A):** unified the Story-009 placeholder
  `content_dangling_skill_ref` → canonical `content_active_skill_unresolved`; added the
  one canonical `ContentCatalogs.move_ids_from()` builder (real boot + fixtures share it);
  tech-debt register line 24 marked RESOLVED (Move side). **Passive side still OPEN**
  (`passive_ids` / `content_dangling_passive_ref` — reconcile when the Passive DB epic lands).
- **Evidence: full suite 229/229 green, 2881 asserts** (Godot 4.7 + GUT 9.7.1). Known
  pre-existing part_db shared-instance test noise (17 orphans / 42 ObjectDB-leak warnings) —
  not a regression. Story files, EPIC.md, epics/index.md all rolled up to Complete.

## Session Extract — Part-DB GDD Round-9 design-review → APPROVED (2026-07-16)

- **`/design-review design/gdd/part-database.md` (full mode)** on the 2026-07-15
  Rule 2/Rule 8/AC-01 effect-capacity rework. Verdict NEEDS REVISION (2 blockers)
  → both fixed & test-verified in-session → **Accepted, marked Approved**.
  - **B-A (false-coverage, closed for real):** Rule 8's "AC-01 validates" the
    support-slot SKILL_UNLOCK ban was untrue — `_check_nullability` never read
    `upgrade_effects`. Fixed: GDD **AC-01 sub-check (d)** + Rule 8 clause rewrite;
    `content_validator.gd` new `_check_upgrade_effects()` + dispatch; 2 new tests
    (neg Core +4 SKILL_UNLOCK → `content_upgrade_skill_unlock_forbidden`; pos
    Core +4 SKILL_ENHANCE → pass).
  - **B-B:** EC-01/EC-02 "Always valid" contradicted the Rare+ floor=1; rewritten
    rarity-scoped + `Verified by AC-01(b)/(c)`.
  - **Suite 160/160 green, 419 asserts** (was 158/416). Godot 4.7.
  - Recommended items (D-1 ceiling rationale, skill-flavor→Synergy constraint,
    stale "unique trait", AC-01(c) constant cite) **deferred** — user scoped this
    pass to blockers only. Logged in the review-log Round-9 entry.
  - Tracking updated: systems-index #1 note + `reviews/part-database-review-log.md`
    Round-9 entry. Memory `project-rule2-rule8-contradiction` now design-review-verified.

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

## Session Extract — Rule 2↔Rule 8 RESOLVED (2026-07-15)
- **Rule 8 reworked from skill-quota → effect-capacity model.** Rarity = how many effects (Common 0 / Rare 1 / Boss 2 / Proto 2; **floor 1 for all Rare+** per user: "every rare must bring something") + how strong. Slot = skill-eligibility (skill-capable: Head/Arms/Weapon/Chassis/Legs/Chipset; support Core/Energy-Cell = passive+stats only). **Passives legal on any slot.** Weapon defines basic-attack type. Core identity now emergent (support slot + floor 1 ⇒ its 1 effect must be a passive) — no inline special case.
- Files: `design/gdd/part-database.md` (Rule 2 table + basic-attack note / Rule 8 full rewrite / AC-01 nullability clause); `src/core/content/content_validator.gd` (`_check_nullability` rewritten + `SKILL_CAPABLE_SLOTS`/`EFFECT_CEILING`/`EFFECT_FLOOR` consts; removed `_passive_required`); `tests/unit/content/part_validator_schema_test.gd` (retired 2 obsolete "required" tests, changed 1 error-code assert, +6 new-freedom/capacity tests); `tests/integration/content/part_referential_integrity_test.gd` (`_rare_head` fixture skill-only — was skill+passive=2 effects; passive-ref test now passive-only).
- New error codes: `content_effect_capacity_exceeded`, `content_effect_missing`. Retired: `content_active_skill_missing`, `content_passive_forbidden`, `content_passive_missing`. Kept: `content_active_skill_forbidden`.
- Evidence: **158/158 suite green, 416 asserts** (Godot 4.7). All 14 shipped parts still valid; CI content gate green. Tech-debt item marked RESOLVED; memory `project-rule2-rule8-contradiction` updated to RESOLVED.
- Rare armor/chipset/legs frames are now authorable. **Skill flavor (attack vs buff/debuff) is authoring-guideline only** — enforceable once Move DB carries a skill category. Not yet run: `/design-review` on the revised GDD.

<!-- STATUS -->
Epic: Damage Formula
Feature: DF-1 composition (Stories 001+002 Done)
Task: RESUME HERE → /dev-story Story 003 (damage-type routing + full routed composition)
<!-- /STATUS -->

## ⏭️ NEXT SESSION — RESUME HERE (as of 2026-07-16, after Story 002 close)
- **State: DONE + green + committed.** Damage-Formula Stories 001 (compute_damage kernel + damage_floor) and 002 (type_effectiveness lookup + type_chart config) are both **Complete**. Working tree clean. Suite **257/257 green** (Godot 4.7). Nested typed-Dictionary `.tres` round-trip CONFIRMED on 4.7.
- **THE ONE PENDING ACTION: run `/dev-story production/epics/damage-formula/story-003-damage-type-routing-composition.md`** — Story 003 passed `/story-readiness` this session = **READY** (no gaps). It adds `DamageFormula.resolve(...)` — the routed TBC call contract that binds A/D by `damage_type` (PHYSICAL→physical_power/armor, ENERGY→energy_power/resistance), derives T via Story 002's `type_effectiveness`, and calls Story 001's `compute_damage`. Pure static fn in `src/core/stats/damage_formula.gd`; `crit_mult` stays a pass-through param.
- **Watch during impl**: the two routing branches are where a swapped stat binding hides — AC-DF-03 (33 not 26) and AC-DF-04 (22 not 45) cross-checks are the regression guard; land the "wrong value NOT returned" asserts. AC-DF-06 is floor-vs-round discriminating (33 not 34); AC-DF-07 catches wrong post-floor order (25 not 24). Test evidence file: `tests/unit/damage-formula/damage_routing_test.gd`. Re-run: `/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json`.
- **Note**: `godot` is NOT on PATH — use the full `/Applications/Godot.app/Contents/MacOS/Godot` path. The gconfig runs the WHOLE suite even with `-gtest=` (expect 257 baseline + new routing tests).
- After Story 003: Damage-Formula epic composition is complete → unlocks TBC damage resolution (consumes `DamageFormula.resolve`). Other unstoried Foundation epics: Passive / Consumable / Enemy DBs. Still-open earlier item: `/design-review design/gdd/part-database.md` (revised Rule 2/8/AC-01 never went through design-review) — deferred, not blocking Damage-Formula work.

## Session Extract — /story-done 2026-07-16
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/damage-formula/story-001-df1-kernel-compute-damage.md — DF-1 kernel compute_damage() + damage_floor config
- Code review this session: /code-review on damage_formula.gd + content_validator.gd → APPROVED WITH SUGGESTIONS. Applied CV-2b guard (bounds.size()<2 in _check_stat_budget). Suite 243/243 green.
- Tech debt logged: None (2 advisory test gaps noted in story Completion Notes — damage_floor=0 boundary + guard-branch DI seam; add before Story 003)
- Next recommended: Damage-Formula Story 002 (type_effectiveness chart lookup, derives T) — production/epics/damage-formula/story-002-type-effectiveness-lookup.md

## Session Extract — /dev-story 2026-07-16
- Story: production/epics/damage-formula/story-002-type-effectiveness-lookup.md — Type-effectiveness lookup
- Files changed: src/core/stats/damage_formula.gd (type_effectiveness lookup), src/core/stats/balance_config.gd (type_chart field), assets/data/balance_config.tres (9 cells authored), src/core/content/content_validator.gd (_check_type_chart family + content_balance_type_chart_malformed), tests/unit/damage-formula/type_effectiveness_test.gd (12 test functions)
- Implemented INLINE (engine-programmer subagent died on the intermittent "1M context credits" API error — same pattern as Story 001)
- Suite: 255/255 green (was 243/243; +12). .tres nested-Dictionary round-trip CONFIRMED on 4.7.
- Blockers: None
- Next: /code-review src/core/stats/damage_formula.gd src/core/content/content_validator.gd then /story-done production/epics/damage-formula/story-002-type-effectiveness-lookup.md

## Session Extract — /story-done 2026-07-16 (Story 002)
- Verdict: COMPLETE WITH NOTES → closed (all advisory notes resolved before close)
- Story: production/epics/damage-formula/story-002-type-effectiveness-lookup.md — Type-effectiveness lookup (type_effectiveness() + type_chart). Status: Complete.
- Code review this session: /code-review → APPROVED WITH SUGGESTIONS. GDScript specialist clean; qa-tester flagged 3 advisory test gaps.
- Advisory gaps ALL RESOLVED in tests/unit/damage-formula/type_effectiveness_test.gd (now 14 fns): (1) reason discriminator asserted in 3 rejection tests, (2) +test_validator_rejects_scalar_row, (3) +test_validator_rejects_non_numeric_cell.
- Suite: 257/257 green (was 255; +2). Tech debt logged: None.
- Next recommended: Damage-Formula Story 003 (damage-type routing/composition — binds A/D by damage_type, calls compute_damage with derived T) — production/epics/damage-formula/story-003-damage-type-routing-composition.md

## Session Extract — /dev-story 2026-07-16 (Story 003)
- Story: production/epics/damage-formula/story-003-damage-type-routing-composition.md — Damage-type routing + full routed composition
- Files changed: src/core/stats/damage_formula.gd (added `resolve` routed entry point), tests/unit/damage-formula/damage_routing_test.gd (new, 11 test fns)
- Test written: tests/unit/damage-formula/damage_routing_test.gd
- Implemented INLINE (LOW-risk pure composition; engine-programmer subagent died on the "1M context credits" API error in Stories 001–002 — same pattern, so followed the established inline path)
- Suite: 268/268 green (was 257; +11). All ACs covered with discriminating cross-checks (26/45 wrong-binding, 34 round, 24 wrong-order all asserted NOT-returned).
- Blockers: None
- Next: /code-review src/core/stats/damage_formula.gd then /story-done production/epics/damage-formula/story-003-damage-type-routing-composition.md

## Session Extract — /code-review 2026-07-16 (Story 003)
- Verdict: APPROVED WITH SUGGESTIONS → both suggestions applied.
- godot-gdscript-specialist: no BLOCKING. W-1 (unknown damage_type silent ENERGY fallthrough), W-2 (test naming) advisory.
- qa-tester: coverage complete, all ACs + 4 cross-checks mapped. ADVISORY: element path only via ENERGY branch.
- Applied: (1) qa element-branch gap → added test_resolve_physical_branch_also_applies_type_effectiveness; (2) W-1 → resolve() now log.warn(&"damage_routing_unknown_damage_type") + degrades to ENERGY, doc updated, +2 tests.
- Suite: 271/271 green (was 257 at story start; +14 total in damage_routing_test.gd).
- Next: /story-done production/epics/damage-formula/story-003-damage-type-routing-composition.md

## Session Extract — /story-done 2026-07-16 (Story 003)
- Verdict: COMPLETE WITH NOTES → closed. Status: Complete.
- Story: production/epics/damage-formula/story-003-damage-type-routing-composition.md — Damage-type routing + full routed composition (DamageFormula.resolve)
- ACs: 6/6 passing; test evidence tests/unit/damage-formula/damage_routing_test.gd (14 fns). Full suite 271/271 green.
- Deviation (advisory, resolved): W-1 log.warn(&"damage_routing_unknown_damage_type") hardening on out-of-enum damage_type. Not logged as debt (completed enhancement, user chose plain close).
- Tech debt logged: None.
- Next recommended: see epic — Damage-Formula epic may be complete; next likely Turn-Based Combat (consumes DamageFormula.resolve).

## Session Extract — /design-review 2026-07-16 (Part Database, Round 11)
- Verdict: NEEDS REVISION (3 blockers) → all 3 + 7 recommended fixed same session → CD targeted fix-confirmation APPROVED. GDD status: **Approved**.
- Blockers: AC-25 any-key focus loophole (user decision: **focus stat = slot primary** — off-primary Prototypes unauthorable); AC-08(b) base −1 fixture non-discriminating → base −3 [−3,−2,−1,0,0,0] (python-verified); stat_bonuses pinned Dictionary[StringName, int] + &"key" examples.
- Recommended applied: AC-09(e) "1.575 exact" claim corrected (1.5749999999999997; strict ==1.0 safe); AC-06 ×2.00 exception; typed-export sentinel convention (null → &""/0/{}); focus-floor rule generalized; EC-12 → Verified by AC-11; AC-26 Rule-9/Drop-5a cross-ref; band "15–20%" → "~16.9–20%" ×4.
- Tracking updated: part-database.md header, systems-index.md row 1, review-log Round 11 entry.
- Production debt CLOSED as story: **production/epics/part-database/story-011-validator-hardening-round11.md** (Ready) — AC-25/26 validators missing, AC-27 negative bound missing, AC-08(b) test fixture sync, Story-009 entry-shape validators, TR-registry re-sync. Part-DB epic Reopened (index.md + EPIC.md updated).
- Next: implement story-011 (`/create-stories` not needed — story exists; run implementation flow), or continue Foundation epics (Passive/Consumable/Enemy DBs unstoried).

## Session Extract — story-011 implementation 2026-07-16
- godot-gdscript-specialist implemented story-011 (validator hardening): AC-25 `_check_prototype_focus_floor`, AC-26 `_check_prototype_drop_conditions`, AC-27 negative floor in `_check_stat_budget`, entry-shape validators (`drop_conditions` + `upgrade_effects`), AC-08(b) fixture base −1 → −3, TR-registry synced (TR-part-017 band text; new TR-part-026/027).
- Suite: 270 → **293/293 green** (+23 tests: AC-25 ×5, AC-26 ×5, AC-27 ×4, entry-shape ×8, F2b −3 swap).
- Content pass: sole authored Prototype `wild_overdrive_cannon.tres` complies with amended AC-25/26 — no content fixes.
- Key-convention ruling: String keys for untyped entry dicts (matching `_check_boss_break_condition` + authored .tres); StringName only for `stat_bonuses`/error codes.
- Story status: Implemented — pending /code-review + /story-done. Epic index/EPIC.md still say "Reopened/Ready" — update at story-done.
- Next: /code-review src/core/content/content_validator.gd → /story-done production/epics/part-database/story-011-validator-hardening-round11.md

## Session Extract — /create-stories passive-database 2026-07-16
- Ran `/design-review part-database.md` (lean, no agents — honoring never-1M constraint): verdict **APPROVED**, no blockers. Then user chose to story the Passive DB.
- **`/create-stories passive-database` COMPLETE** — 7 stories written to `production/epics/passive-database/`, all Ready, all ADR-0003, review mode lean (QL-STORY-READY skipped). EPIC.md Stories table + epics/index.md ("7 stories", Layer Status, Next Step) updated. Committed + pushed to origin/main.
- Story shape (dependency order): 001 PassiveDef schema+enums+PassiveCatalog (Logic, AC-PDB-03) → 002 PassiveDB loader/null-safe lookup (AC-PDB-01) → 003 stacking-policy defaults by behavior_class (TR-pdb-004) → 004 validator legality-matrix+stacking (AC-PDB-15) → 005 validator behavior_params+STRUCTURAL non-negative+Core restriction (AC-PDB-12/14/16, TR-pdb-006/007/008) → 006 referential integrity + `passive_ids` catalog wiring (AC-PDB-13; seam already half-built at content_validator.gd:766 + content_catalogs.gd:43) → 007 three MVP status riders content (TR-pdb-005; volt_shock/thermal_burn/kinetic_stagger .tres).
- **Scope boundary (IMPORTANT):** Passive DB owns NO runtime executor. Runtime firing ACs (AC-PDB-02, 04–11, 17 — status application, stacking dedup, aura/structure clamps) are the **TBC Rule 13 executor epic**. OQ-PDB-1 MVP Core passive roster (deferred AC-PDB-D1–D4, capped at 5 mechanically-distinct Cores) is a separate game-designer content pass, NOT a story here.
- Naming to mirror: `PassiveDef`/`PassiveCatalog`/`PassiveDB` (matches `MoveDef`/`MoveCatalog`/`MoveDB`). Builder to add: `ContentCatalogs.passive_ids_from(catalog)` mirroring `move_ids_from` (content_catalogs.gd:58). Append `passives: PassiveCatalog` slot to ContentCatalogs (APPEND-ONLY).
- **NEXT SESSION:** `/story-readiness production/epics/passive-database/story-001-passivedef-schema-enums-catalog.md` → `/dev-story`. Stories 002–007 unlock in dependency order. (Remaining unstoried Foundation: Consumable, Enemy DBs.)
- **Constraint still binding:** never spawn Agent/Task subagents this session-mode — they die on "1M-context credits". Run everything lean/inline. See memory `project-subagent-model-1m-resolved`.

## Session Extract — /dev-story enemy-database story-001 2026-07-16
- Story: production/epics/enemy-database/story-001-enemydef-schema-enums-catalog.md — EnemyDef schema, enums & EnemyCatalog
- Files changed: src/core/content/enemy_def.gd (new, class_name EnemyDef, EnemyClass{INVALID=0,WILD=1,BOSS=2}, 15 @export fields), src/core/content/enemy_catalog.gd (new, EnemyCatalog.entries: Array[EnemyDef]), tests/unit/enemy_database/enemy_def_schema_test.gd (new, 20 test fns)
- Test written: tests/unit/enemy_database/enemy_def_schema_test.gd — 20/20 green, 100 asserts (import pass confirmed EnemyDef+EnemyCatalog registered; count rose 0->20, no silent-skip)
- KEY: AC-3 HIGH-RISK nested Array[Dictionary] + StringName-key .tres round-trip PASSED on Godot 4.7.stable.official — ADR-0003 round-trip gate clears for the Enemy DB epic; no escalation needed.
- Also this session: consumable-DB post-close cleanups — consumable_def.gd:26 doc-comment "roster error"->"warning"; new test_both_context_item_valid_in_world (AC-CD-07 world half). Consumable dir suite 58/58 green. BOSS_GRADE tech-debt (register:34) stays open.
- Blockers: None. Note: implementer subagent died once on transient "1M-context credits" error (0 tokens/497ms), succeeded on immediate retry — model:sonnet pin correct.
- Next: /code-review src/core/content/enemy_def.gd src/core/content/enemy_catalog.gd then /story-done production/epics/enemy-database/story-001-enemydef-schema-enums-catalog.md

## Session Extract — enemy-database Stories 008/009/010 2026-07-16
- Story 008 (harvest-decision BLOCKING / TTK+density+null-element+boss-spawn ADVISORY): COMPLETE. EDB-2 TTK pure-integer arithmetic (python3-verified zero divergence vs math.ceil, no epsilon). +21 evidence tests. Suite 591→612 green.
- Story 009 (ELZS level/xp CP-F4/completion_bonus validation, all BLOCKING): COMPLETE. New shared formula home src/core/content/xp_reward_formula.gd (XpRewardFormula.derive_xp_value, pure integer WILD×1/BOSS×2). +11 evidence tests. Suite 612→623 green.
- Story 010 (MVP roster .tres authoring, Config/Data): **BLOCKED — Part-DB content gate.** Only 2 of 14 parts carry break-gating drop_conditions (scrapjaw_rustcrawler_claw BOSS_GRADE arm_broken [BOSS-only]; wild_overdrive_cannon PROTOTYPE overheat_kill). AC-ED-19 needs ≥2 break-gated parts PER enemy incl. WILD, but only 1 non-boss-grade break-gated part exists → all ~8 WILDs unavoidably warn. 0-warning pass impossible. Flagged per story's own stop-and-flag clause; NO content invented. Status/Blocker written to story-010 file.
- Stories 001–009 = the delivered Enemy-DB implementation (schema + all validator families, green). 010 gated on Part-DB CONTENT, not Enemy-DB code.
- AWAITING USER DECISION: (a) accept 010 blocked, treat 001–009 as Enemy-DB deliverable; or (b) co-author minimal break-gated Part set to unblock 010.
- Deferred batch step: per-story /code-review + /story-done for all 10 enemy stories.

## Session Extract — Enemy-DB batch closure COMPLETE 2026-07-16
- USER DECISION: "Accept blocked; 001–009 ships." Story 010 stays BLOCKED-on-Part-content.
- Bookkeeping done: EPIC.md (Status "In Progress — 9/10", story table 001–009 Complete / 010 BLOCKED, Next Step rewritten); epics/index.md (Enemy row + Layer Status + Next Step updated). Foundation *code* complete across all 6 epics.
- Batch closure done inline (no subagents): fresh GUT 623/623 green; stories 001–006 bumped Ready→Complete (007–009 already Complete); inline code-review PASS, no blocking issues, written to production/qa/enemy-database-code-review-2026-07-16.md. No sprint-status.yaml exists (nothing to update there).
- Validator surface 1284 lines (content_validator 345 + enemy_validator 939) — under 1500 DoD split trigger.
- **NEXT (two tracks):** (1) `/create-epics layer: core` to begin Core layer; (2) optional — flesh out break-gated Part-DB roster to later unblock Story 010.
- Constraint still binding: never spawn Agent/Task subagents (1M-context deaths); python3-scan every new floor/ceil formula.

## Session Extract — Part-DB break-gated roster authored 2026-07-16
- USER REQUEST: "tackle the part-db roster" → unblock Enemy Story 010.
- Adopted anatomy-linked break-event vocabulary (GDD Rule 5; shared enemy break_regions ↔ part drop_conditions): head_broken/arm_broken/leg_broken/weapon_broken/chassis_cracked/core_exposed (internals=CORE+CHIPSET+ENERGY_CELL share core_exposed). User confirmed single core_exposed + add a new 2nd boss part.
- Enriched 12 existing parts with slot-matched drop_conditions (commons ×2.5, rares ×3.0). RARE parts keep exactly 1 effect → effect-neutral, zero referential risk.
- NEW part boltwell_storm_lance.tres — 2nd BOSS_GRADE exclusive (Boltwell/Volt WEAPON, weapon_broken ×600, product 0.6≥0.5; 2 effects skill_storm_lance+pass_overload, level_req 6). Added to part_catalog.tres; part_catalog_ci_test manifest extended (+skill_storm_lance,+pass_overload) & count 14→15.
- Verify: reimport + GUT 623/623 green, 3817 asserts (was 3815; +2 = unique-id test over 15 entries). Part CI validates 15 parts, 0 errors, only-allowed warnings.
- Coverage: 6 break events each ≥1 gated part; head/arm/weapon/core have ≥2; 2 distinct BOSS exclusives (kinetic arm / volt weapon). Every multi-region WILD can field ≥2 gated parts → Story 010 authorable at 0 warnings.
- CONTENT-VARIETY NOTE (for Story 010): THERMAL has no RARE (only ironclad_bulwark_frame common). Not a blocker.
- Bookkeeping: Story 010 BLOCKED→Ready (+Unblock Record table); EPIC.md + index.md updated. Enemy-DB code Complete; only enemy .tres authoring remains.
- NEXT: author Story 010 (~8 WILD + 2 BOSS EnemyDef .tres + EnemyCatalog) → close Enemy-DB epic → Foundation fully Complete → /create-epics layer: core.

## Session Extract — Thermal Rare added 2026-07-16
- NEW part ironclad_aegis_frame.tres (RARE / CHASSIS / Thermal / Ironclad; passive pass_ablative; chassis_cracked ×3.0; structure 30 / armor 8 / resistance 6 = 44, inside CHASSIS-RARE budget [38,46], structure ≥ 29 rare-floor). Fixes the "Thermal enemies drop Kinetic/Volt Rares" ugliness.
- LESSON: stat_budgets/primary_stat_rare_floors are BalanceConfig.gd @export DEFAULTS (not in balance_config.tres). CHASSIS/RARE budget [38,46]; validator rejected first pass at sum 51.
- Companion edits: bulwark_frame.tres +part_family=bulwark_frame_family (Bulwark→Aegis chain); part_catalog.tres 15→16; part_catalog_ci_test SHIPPED_PASSIVE_IDS +pass_ablative, count 15→16.
- Verify: --import + GUT 623/623 green, 3818 asserts, 0 errors, only allowed warnings.
- ROSTER IMPACT: two Thermal wilds now drop aegis_frame (R-Thermal→chassis) instead of scavenged reinforced_servo_arm(Kinetic)/arc_blaster(Volt).
- NEXT: author the 10 EnemyDef .tres + EnemyCatalog (Story 010) with the revised Thermal pools.

<!-- QA-PLAN: 2026-07-17 | System: sprint-1 (Encounter Zone + Drop System) | Plan written: production/qa/qa-plan-sprint-1-2026-07-17.md -->
