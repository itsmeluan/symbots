# ADR-0008: UI Architecture & Screen Contracts

## Status
Accepted

## Date
2026-07-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Input (touch-primary `Control`-based 2D; no custom rendering) |
| **Knowledge Risk** | HIGH — UI is a post-cutoff-heavy domain. The load-bearing 4.6 change is the **dual-focus system**: mouse/touch focus is now SEPARATE from keyboard/gamepad focus, and `grab_focus()` drives keyboard/gamepad focus ONLY. 4.5 adds AccessKit screen-reader support on `Control` nodes, `FoldableContainer`, and recursive `MOUSE_FILTER_IGNORE`. These are exactly the areas the LLM's ~4.3 training data gets wrong. |
| **References Consulted** | `docs/engine-reference/godot/modules/ui.md`, `modules/input.md`, `breaking-changes.md`, `deprecated-apis.md`; ADR-0002, ADR-0004, ADR-0005, ADR-0007 |
| **Post-Cutoff APIs Used** | Dual-focus awareness (behavioral, not a new symbol); `tr()` localization (unchanged); optionally `FoldableContainer` (4.5) and recursive `MOUSE_FILTER_IGNORE` (4.5) for collapsible/disabled sections. No deprecated API. |
| **Verification Required** | (1) every interactive `Control` ≥ 44×44 pt (layout audit + a screen-tree GUT check on `custom_minimum_size`). (2) actions fire on BOTH mouse click and touch tap (dual-input test). (3) no hover-only affordance (review checklist). (4) draw-call count ≤ 200 per screen (smoke check). (5) `grab_focus()` (keyboard) does not steal or break touch interaction on iOS. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (**Accepted** — owner-declared signals, self-sufficient payloads, LogSink diagnostics); ADR-0004 (**Accepted** — ScreenManager owns all transitions + injects screens at instantiation); ADR-0005 (**Accepted** — `effective_stat`, `SynergyEvaluator.preview`, `CoreProgression` gate accessors, `compute_damage`); **ADR-0007 (Proposed)** — UI references `submit_action` / `is_battle_active` / battle signals, so ADR-0008 must reach Accepted *together with* ADR-0007 in the fresh `/architecture-review` |
| **Enables** | None — this is the final planned ADR |
| **Blocks** | Combat UI, Workshop UI, World Map UI, Main Menu, HUD implementation epics |
| **Ordering Note** | Presentation-tier; last of the planned set (0001–0008). Closes the 6 remaining gap TRs. Because it depends on the still-Proposed ADR-0007, the review that Accepts 0007 should Accept 0008 in the same pass. |

## Context

### Problem Statement

ADR-0004 placed the *between-screen* boundary — ScreenManager owns every create/free/show/hide and injects each screen at instantiation. But nothing defines the architecture *inside* a screen: how a screen receives its model dependencies, how a view reflects model changes, how touch + dual input (Mac mouse dev/launch, iOS touch primary) and the 200-draw-call budget are enforced, and how Workshop/combat previews are computed without re-implementing the battle formulas. Six gap TRs (`TR-cp-012`, `TR-sa-005`, `TR-zwm-009`, `TR-ui-001`, `TR-ui-002`, `TR-perf-003`) have no owning ADR. This closes them.

### Constraints (binding accepted stances)

- `screen_transitions` + `unowned_scene_transition` (forbidden) — ScreenManager owns ALL transitions; screens request via their injected reference; no `change_scene`, no self `queue_free`, no `get_parent()` climbing.
- `battle_orchestration` (ADR-0007) — Combat UI calls `BattleController.submit_action(action)` and reads `is_battle_active()`; it does not drive the FSM.
- `combatant_snapshot` / `synergy_evaluation` / `core_progression_gate` / `damage_computation` — UI reads via `effective_stat()`, `preview()`, `can_equip`/`is_build_valid`, `compute_damage`; subscribes `synergy_changed`, `core_leveled_up`, `stats_changed`.
- `inline_stat_composition` (forbidden) — every stat display MUST call the single SYN-F4 point; no reimplementation (the MOVE-F1 preview-seam drift class).
- `subscriber_ordering_dependency` (forbidden) — views treat each signal payload as self-sufficient; payload collections are read-only (copy before mutate).
- `global_push_diagnostics` (forbidden) — UI diagnostics go through the injected `LogSink`, never `push_*`.
- `mid_battle_stat_recompute` (forbidden) — Combat UI reads the frozen `CombatantSnapshot`, never the live build/evaluator.

### Requirements (the 6 owned TRs)

- **TR-ui-001** — touch-first: min 44×44 pt tap targets, no hover-only interactions.
- **TR-ui-002** — dual input: keyboard/mouse (Mac) AND touch (iOS) for every interaction.
- **TR-perf-003** — draw-call budget 200 (conservative mobile 2D).
- **TR-cp-012** — Core swap orphaned-part case: Workshop surfaces the invalid build (banner + offending-part highlight), does not auto-unequip.
- **TR-sa-005** — SA-F2 delta preview requires a FULL hypothetical recompute (all 8 parts), not a partial diff.
- **TR-zwm-009** — World Map UI consumes the `{zone_id, from_state, to_state}` transitions array.

## Decision

Five parts.

### 1. Screen base + `ServiceContext` injection

A `Screen` base class (`extends Control`) defines one virtual: `setup(ctx: ServiceContext)`, called ONCE by ScreenManager at instantiation, before the screen is shown. ScreenManager injects a single `ServiceContext` — a RefCounted bundle of the DI owners + itself — so its instantiation path stays generic (it hands every screen the same bundle; it does not know each screen's individual dependency list).

```
# ServiceContext (RefCounted) — assembled once at BootScreen step 4b, handed to ScreenManager
screens      : ScreenManager       # transition requests ONLY (goto_*, enter_battle, open/close_workshop)
build        : SymbotBuild          # active build — READ; equip mutations go through Workshop, not the view
synergy      : SynergyEvaluator     # preview() + subscribe synergy_changed
progression  : CoreProgression      # can_equip / is_build_valid / level display + core_leveled_up
log          : LogSink              # UI diagnostics — never push_*
# BattleController is the slot-11 autoload: read directly for is_battle_active / submit_action / battle signals.
# Content is read through the DB autoloads (content_db_lookup). Save/Settings never touched from a view.
```

A view NEVER reaches an autoload except `BattleController` (the battle authority, ADR-0007) and the content DBs (read-only, ADR-0003). Everything else arrives in the bundle — keeping screens constructible in GUT with stub owners.

### 2. Signal-driven view updates

A view is a pure function of the last signal payload it received. It subscribes to the owner signals it needs in `setup()`/`_ready` and **disconnects on `NOTIFICATION_EXIT_TREE`** (screens are freed on transition — a dangling connection to a persistent owner like `CoreProgression` would leak and fire into a freed node). No `_process` polling of model state. Because every payload is self-sufficient (ADR-0002), a view never reads another system's state to interpret a signal, and never depends on subscriber order.

### 3. Touch-first, dual-input

- Every interactive `Control` sets `custom_minimum_size >= Vector2(44, 44)` — enforced by a screen-tree audit test. **Engine note**: `custom_minimum_size` is in Godot *virtual* pixels at the project reference resolution, NOT physical pt. The `display/window/stretch` mode + `content_scale_factor` must be configured so one virtual px ≈ one iOS pt on-device; otherwise 44 could render as 22 physical px at a 0.5× content scale and the audit test would still pass. Verify against the target device; adjust the constant to the reference resolution if the scale is not 1:1.
- Actions fire on the unified press release (`BaseButton.pressed` / `_gui_input` release), which both a mouse click and a touch tap raise — one code path for both platforms.
- **Hover is enhancement-only**: `mouse_entered`/tooltips may add affordance but are NEVER the sole way to discover or trigger anything (touch has no hover). This is the concrete discipline behind the 4.6 dual-focus split.
- Keyboard/gamepad focus (`grab_focus()`, keyboard-only in 4.6) is an optional Mac convenience; iOS touch flows never require it. Custom focus-draw, if any, is tested with both input methods.

### 4. Preview reuse — the pure formula core, never a copy

Workshop and combat previews call the SAME functions battle uses:
- **Synergy preview**: `SynergyEvaluator.preview(candidate, slot, parts)` — pure, no cache write, no emit (ADR-0005).
- **SA-F2 stat delta (TR-sa-005)**: a FULL hypothetical recompute — `StatPipeline.derive` over a plain-data copy of all 8 part slots (a throwaway working set, NOT `Resource.duplicate()` — content defs stay frozen), read back through `effective_stat()`. The "current vs hypothetical" delta is two runs of the real pipeline, never a partial diff.
- **Damage preview**: `DamageFormula.compute_damage(...)` with the same MOVE-F1 chain the battle uses.

The UI reimplements no formula. This is the direct application of `inline_stat_composition` and the reason it exists (the MOVE-F1 preview seam shipped a divergent copy through a full approval).

### 5. Draw-call budget discipline (TR-perf-003, 200)

One shared project `Theme` (`assets/ui/theme.tres`) with shared `StyleBox`es; no per-widget unique `material`/shader on UI nodes (each unique material breaks CanvasItem batching); a small font set; `tr()` for all visible strings with `AUTOWRAP_WORD_SMART` labels. Each screen is budgeted to leave headroom under 200; a per-screen draw-call smoke check is the gate. Collapsible sections use `FoldableContainer` (4.5); bulk-disabled sections use the 4.5 recursive input-filter mechanism (`MOUSE_FILTER_IGNORE`-propagating) rather than hand-rolled input gating.

**Engine notes (4.6 batching gotchas, from specialist validation):** beyond unique materials, three more break or bloat 2D batching — (a) `clip_contents = true` isolates a CanvasItem and prevents batching its children with siblings; (b) each nested `CanvasLayer` starts a new draw layer and breaks batching entirely, so keep UI on as few layers as the design allows; (c) `RichTextLabel` (BBCode) re-parses/tessellates on every text change and each uniquely-styled span costs a draw — never drive it per-frame, and prefer plain `Label` where BBCode is not needed. The `FoldableContainer` recursive-disable propagation is a 4.5 addition: the implementer must confirm the exact propagating property in 4.5/4.6 rather than assuming plain `mouse_filter` inheritance (per-node `mouse_filter` is not itself recursive).

### Specific TR wirings

- **TR-cp-012** — Workshop UI queries `CoreProgression.is_build_valid(build)` after any equip/core-swap and on screen entry; an invalid build shows a banner + highlights the offending over-level parts (from the `battle_start_refused`-style offending list), and the "enter battle" affordance is disabled. TBC's `battle_start_refused` (ADR-0007) is the authoritative last line; the UI is the friendly early warning at the Workshop.
- **TR-zwm-009** — World Map UI subscribes to `EventBus.zone_states_changed` and consumes the `{zone_id, from_state, to_state}` transitions array to animate exactly the zones that changed (no full-map rebuild).

### Architecture Diagram

```
 BootScreen 4b: assemble ServiceContext(build, synergy, progression, screens, log)
        │ handed to ScreenManager
        ▼
 ScreenManager  ──instantiate──▶ Screen.setup(ctx)  (once, before show)
   owns create/free/show/hide          │ caches deps, connects signals
   (ADR-0004)                          ▼
                          ┌──────────── a Screen (extends Control) ───────────┐
                          │ view = f(last payload)   ≥44×44 controls          │
   subscribe (in setup)   │ NO _process poll · hover = enhancement only       │
   disconnect (EXIT_TREE) │ one shared Theme · no per-widget materials        │
                          └───────────────────────────────────────────────────┘
        ▲ signals                    │ reads / calls                    │ transition requests
        │                            ▼                                  ▼
  stats_changed / synergy_changed  effective_stat() · preview()   screens.goto_* / enter_battle
  core_leveled_up / battle signals  compute_damage() · is_build_valid   open/close_workshop
  zone_states_changed              BattleController.submit_action / is_battle_active   (ScreenManager ONLY frees)
```

### Key Interfaces

```
# Screen (base, extends Control)
func setup(ctx: ServiceContext) -> void
#   called ONCE by ScreenManager at instantiation, before the screen is shown.
#   Override to cache deps + connect owner signals. MUST disconnect on NOTIFICATION_EXIT_TREE.

# ServiceContext (RefCounted) — the injected dependency bundle (fields listed in Decision §1)

# Combat UI (a Screen)
#   reads BattleController.is_battle_active(); calls BattleController.submit_action(action);
#   subscribes battle turn/damage/status/overheat/break signals + battle_ended; reads the
#   frozen CombatantSnapshot only (never the live build).

# Workshop UI (a Screen)
#   preview via SynergyEvaluator.preview() + StatPipeline hypothetical derive + compute_damage;
#   invalid-build banner via CoreProgression.is_build_valid(build).
```

## Alternatives Considered

### Alternative 1: Per-screen explicit constructor injection
- **Description**: each `setup()` declares exactly the deps that screen needs.
- **Pros**: minimal surface per screen; a screen's dependencies are self-documenting.
- **Cons**: ScreenManager's generic instantiation path must then know each screen's individual shape (or reflectively assemble args) — coupling the transition owner to every screen's signature.
- **Rejection Reason**: the uniform `ServiceContext` keeps ScreenManager generic and the injection site identical for all screens; the slightly wider per-screen surface is cheap and still fully stubbable in tests.

### Alternative 2: Central UI store / mediator
- **Description**: one reactive store subscribes to all model signals and fans out to screens.
- **Cons**: an extra always-on layer to build and test; indirection between a model change and the view that shows it; a second place (besides the owners) that holds UI-relevant state.
- **Rejection Reason**: owner-declared signals already are the store; a per-screen subscribe is simpler and matches the registry's signal contracts directly.

### Alternative 3: Separate touch and mouse input paths
- **Rejection Reason**: doubles the input surface to build and test for no behavioral gain — a unified press release already fires for both click and tap.

### Alternative 4: Dedicated preview service with its own formula copies
- **Rejection Reason**: reintroduces the exact duplicate-formula drift `inline_stat_composition` forbids; the pure core is already fast (O(1)/O(parts) integer math) so there is no performance case for a copy.

### Alternative 5: Immediate-mode / `_process` polling of model state
- **Rejection Reason**: burns frame budget, fights the 200-draw-call target, and ignores the self-sufficient-signal contract.

## Consequences

### Positive
- Every screen has one injection shape, one update rule, one input rule — trivially onboardable and GUT-constructible with stub owners.
- The preview seam is architecturally incapable of drifting from battle math.
- Touch-first + dual-input is a single code path, and the 4.6 dual-focus hazard is contained to "hover is never load-bearing."
- The draw-call budget has a concrete, checkable discipline rather than a hope.

### Negative
- The `ServiceContext` bundle is a slightly wider dependency surface than each screen strictly needs.
- The "disconnect on EXIT_TREE" rule is a discipline every screen must honor; a missed disconnect is a latent leak (mitigated by a base-class helper + a review checklist).

### Risks
- **Risk**: a screen forgets to disconnect and a persistent owner (`CoreProgression`, `SynergyEvaluator`) fires into a freed node. Specialist confirmed this leak is **real** on 4.6 — Godot 4 does NOT reliably auto-drop a connection when the subscriber is freed (partial cleanup exists for some connection patterns but is not guaranteed for `Callable`-bound handlers), so the explicit-disconnect discipline must not be weakened. *Mitigation*: the `Screen` base offers a `_connect_owned(sig, callable)` helper that auto-disconnects on `NOTIFICATION_EXIT_TREE`; the helper binds handlers as named-method Callables (`Callable(self, "_on_x")`), **not** lambdas that close over `self`/`ctx` (a closure capture can silently extend the `ServiceContext` bundle's lifetime past the screen). A leak test frees a screen and asserts the owner has zero dangling connections.
- **Risk**: 4.6 dual-focus — a control reachable only by keyboard focus (or an affordance shown only on hover) is invisible/unusable on touch. *Mitigation*: the "no hover-only, touch never requires keyboard focus" rule + a review checklist; dual-input test exercises the touch path.
- **Risk**: draw calls creep past 200 as screens grow. *Mitigation*: per-screen smoke check; shared Theme + no per-widget materials as the standing rule.
- **Risk**: a preview accidentally mutates shared state (equips for real, or `Resource.duplicate()`s a def). *Mitigation*: `preview()` is pure by contract (no cache/emit); SA-F2 recompute runs on a plain-data working copy, never a def duplicate (`runtime_content_mutation` forbidden).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| technical-preferences (touch mandate) | TR-ui-001 — 44×44 pt tap targets, no hover-only | `custom_minimum_size >= (44,44)` audit + hover-is-enhancement rule |
| technical-preferences | TR-ui-002 — dual input Mac mouse + iOS touch | unified press-release path; keyboard focus optional; dual-input test |
| technical-preferences (perf budgets) | TR-perf-003 — 200 draw calls | shared Theme, no per-widget materials, per-screen smoke check |
| symbot-core-progression.md | TR-cp-012 — over-level parts flagged, not auto-unequipped | Workshop `is_build_valid` banner + offending-part highlight; TBC `battle_start_refused` is the authoritative gate |
| symbot-assembly.md | TR-sa-005 — SA-F2 full hypothetical recompute (all 8 parts) | `StatPipeline.derive` over a plain-data 8-slot working copy, read via `effective_stat()`; delta = two real-pipeline runs |
| zone-world-map.md | TR-zwm-009 — `{zone_id, from_state, to_state}` transitions array | World Map UI subscribes `zone_states_changed`, animates only changed zones |

## Performance Implications
- **CPU**: signal-driven views update only on model change, not per-frame; previews are O(parts) integer math. Well within the 16.6 ms budget.
- **Memory**: screens are created/freed by ScreenManager; the `ServiceContext` is a single shared bundle. No per-widget allocation churn.
- **Draw calls**: the 200 budget is the explicit design constraint of Decision §5.
- **Load Time**: shared Theme loaded once; no per-screen theme rebuild.
- **Network**: N/A.

## Migration Plan
Greenfield — no existing UI. Implementation stories build the `Screen` base + `ServiceContext`, then each screen (Main Menu, Overworld/World Map, Workshop, Combat, HUD) against these contracts. When `design/ux/` specs are authored (`/ux-design`), they specify layout/interaction *within* this architecture; they do not change it.

## Validation Criteria
- Screen-tree audit: every interactive `Control` has `custom_minimum_size >= (44,44)` (GUT).
- Dual-input: a representative action fires identically from a synthesized mouse click and a synthesized touch tap (GUT). **The touch path MUST be synthesized with `InputEventScreenTouch`, not `InputEventMouseButton`** — a mouse-button event would be satisfied by touch-emulation (`emulate_touch_from_mouse`) and silently pass on Mac while missing a genuine iOS touch regression.
- Leak test: freeing a screen leaves zero dangling connections on the persistent owners (GUT).
- Preview parity: a Workshop damage/stat preview equals the value battle computes for the same inputs (GUT — same function, asserted).
- Draw-call smoke: each screen renders ≤ 200 draw calls in a representative state (smoke check).
- No hover-only / no keyboard-required-on-touch (review checklist, ADVISORY).

## Related Decisions
- ADR-0002 (signals + LogSink diagnostics + self-sufficient payloads)
- ADR-0004 (ScreenManager owns transitions + injects screens; this ADR defines what a screen IS)
- ADR-0005 (`effective_stat`, `preview`, gate accessors, `compute_damage` — the preview seam)
- ADR-0007 (`submit_action` / `is_battle_active` / battle signals — the Combat UI surface)
