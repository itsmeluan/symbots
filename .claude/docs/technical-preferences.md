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
- Planned next (per `architecture-review-2026-07-13.md`): ADR-0005 stat pipeline → ADR-0006 RNG service → ADR-0007 TBC state machine → ADR-0008 UI architecture

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
