# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Godot built-in 2D renderer (CanvasItem)
- **Physics**: Godot Physics 2D (turn-based game — physics minimal, no collision-heavy simulation)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Mac (launch), iOS (primary long-term target)
- **Input Methods**: Keyboard/Mouse (Mac), Touch (iOS)
- **Primary Input**: Touch
- **Gamepad Support**: None (turn-based genre; mobile is primary target)
- **Touch Support**: Full
- **Platform Notes**: Design all UI for touch from day one — minimum 44×44pt tap targets, no hover-only interactions. Mac keyboard/mouse is the development environment and early launch platform; iOS is the long-term primary target.

## Naming Conventions

- **Classes**: PascalCase (e.g., `SymbotController`, `PartDatabase`)
- **Variables/Functions**: snake_case (e.g., `move_speed`, `take_damage()`)
- **Signals/Events**: snake_case past tense (e.g., `health_changed`, `part_equipped`, `battle_ended`)
- **Files**: snake_case matching class (e.g., `symbot_controller.gd`, `part_database.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `SymbotController.tscn`, `BattleScreen.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_PARTS_PER_SLOT`, `BASE_DAMAGE_MULTIPLIER`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: 200 (conservative for mobile 2D)
- **Memory Ceiling**: 512 MB (iOS safe ceiling for 2D RPG)

## Testing

- **Framework**: GUT (Godot Unit Testing) — https://github.com/bitwes/Gut
- **Minimum Coverage**: 80% for game logic systems (combat formulas, synergy calculations, part stat aggregation)
- **Required Tests**: Balance formulas, gameplay systems, build/part synergy validation

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here when actively integrating them — not speculatively -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- **ADR-0001** — Save/Load Architecture & Serialization Format — **Accepted 2026-07-13** (single-file JSON provider envelope, atomic writes, 2 MiB / 50 ms iOS budget, `save_emergency()` lifecycle path)
- **ADR-0002** — Event Bus & Signal Architecture — **Accepted 2026-07-13** (hybrid: owner-declared signals + closed 3-signal EventBus roster; `encounter_resolved` rename; synchronous-emit teardown contract; deferred autosave quiesce)
- **ADR-0003** — Content Resource Loading & Schema Mapping — **Accepted 2026-07-13** (typed `.tres` defs, one catalog per DB, CI + dev-boot ContentValidator; typed-dict `.tres` round-trip verification gate still open — blocks content authoring, not acceptance)
- **ADR-0004** — Scene Management & Boot — **Accepted 2026-07-13** (persistent Game root + ScreenManager, Overworld keep-alive, explicit BootScreen sequencer, fixed 10-autoload roster)
- **ADR-0005** — Stat Pipeline & Battle Snapshot — **Accepted 2026-07-14** (pure formula core in `src/core/stats/` + DI RefCounted owners, typed `CombatantSnapshot` frozen at BATTLE_INIT with single SYN-F4 composition point, single `BalanceConfig` .tres; no new autoloads)
- **ADR-0006** — RNG Service & Determinism — **Accepted 2026-07-14** (thin `RngService` autoload slot 9 vends both `next_seed()->int` and `make_rng()->RandomNumberGenerator` from one root; injection discipline keeps `src/core/` pure; root seed logged not persisted; determinism boundary = the resolution unit, within-engine-build only)
- **ADR-0007** — Turn-Based Combat State Machine & Battle Orchestrator — **Accepted 2026-07-14** (new `BattleController` autoload **slot 11** [roster 10→11] hosting `is_battle_active` + an enum-`match` FSM; per-battle `BattleContext` RefCounted, dropped synchronously after the `battle_ended` cascade; event-driven action seam [`submit_action` park + synchronous `EnemyAI.request_move`]; TBC vends `crit`+`ai` only, Drop owns its own vend; resolves the C-3 host seam; amends `boot_initialization` [10→11] + adds `stat_formula_home` carve-out. godot-specialist validated — no blocking issues)
- **ADR-0008** — UI Architecture & Screen Contracts — **Accepted 2026-07-14** (the LAST planned ADR; presentation-tier. `Screen` base extends Control + one-shot `setup(ctx: ServiceContext)` RefCounted-bundle injection [matches ADR-0004 "injected at instantiation"]; signal-driven views [subscribe in setup, disconnect on `NOTIFICATION_EXIT_TREE`], no `_process` polling; touch-first unified press-release path [≥44×44, hover=enhancement-only, keyboard focus optional] honoring the 4.6 dual-focus split; preview reuse of the pure core [`SynergyEvaluator.preview` + `StatPipeline` hypothetical derive + `compute_damage` — no reimplementation]; 200 draw-call discipline [shared Theme, no per-widget materials]. Closes the 6 gap TRs: TR-cp-012 / TR-sa-005 / TR-zwm-009 / TR-ui-001 / TR-ui-002 / TR-perf-003. Depends On ADR-0002/0004/0005 [Accepted] + ADR-0007 [Proposed]. godot-specialist validated — no blocking issues; 6 notes folded [InputEventScreenTouch test, virtual-px vs pt, real signal-leak, named-Callable, batching gotchas, FoldableContainer propagation]. Registry: +1 interface `screen_contract`, +4 forbidden [`view_state_polling`, `undisconnected_view_subscription`, `hover_only_affordance`, `ui_unique_material_batch_break`], +7 referenced_by.)
- Planned next: **none** — all 8 planned ADRs (0001–0008) are **Accepted** (0007 + 0008 promoted 2026-07-14b via `/architecture-review`; ADR-0004 §1 roster amended 10→11 in the same pass, review conflict C-4). Coverage baseline **251/277 covered, 0 gaps, 2 partial** (TR-zwm-001, TR-eng-002). Architecture phase complete — next is the Technical Setup → Pre-Production gate: `/test-setup` + `/ux-design` (pre-gate blockers: tests/unit, tests/integration, CI workflow, interaction-patterns, accessibility-requirements — none exist yet). Engine advisories from the review fold into ADR-0007/0008 implementation-story DoD.

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
