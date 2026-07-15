# Architecture Review Report — 2026-07-14 (ADR-0007 + ADR-0008 acceptance pass)

- **Date:** 2026-07-14 (second pass this day — the "b" review)
- **Engine:** Godot 4.6
- **Mode:** full
- **ADRs under review:** ADR-0007 (Turn-Based Combat State Machine & Battle Orchestrator), ADR-0008 (UI Architecture & Screen Contracts) — both entered as **Proposed**
- **Purpose:** verify the two remaining Proposed ADRs close their gap TRs, detect cross-ADR conflicts (incl. the deferred C-3 seam), run the engine audit, and decide whether both can move **Proposed → Accepted**. This is the quality gate between Technical Setup and Pre-Production.
- **Outcome:** both amended-context resolved and **promoted to Accepted** this session (see Verdict).

---

## Traceability Summary

| | Prior pass (2026-07-14a) | This pass |
|---|---|---|
| Total requirements | 277 | 277 |
| ✅ Covered | 197 (71%) | **251 (91%)** |
| ⚙️ System-internal | 24 | 24 |
| ⚠️ Partial | 5 | **2** |
| ❌ Gap | 51 | **0** |

**Delta drivers:**
- **ADR-0007** closes its **45** gap TRs — 32 `tbc` (001, 003, 006–011, 014–032, 034, 036–038, 042), 11 `pb` (001–004, 006, 007, 010–014), and `eai-008/009`. Its "GDD Requirements Addressed" table is thematic rather than a 45-line enumeration (documentation note, not a coverage defect — cross-checked against `tr-registry.yaml` and the traceability matrix).
- **ADR-0008** closes its **6** gap TRs — `cp-012, sa-005, zwm-009, ui-001, ui-002, perf-003` — all explicitly enumerated in its Requirements table.
- **Partials resolved:** `TR-eai-006/007` (ADR-0007 now consumes ADR-0005's `DamageFormula`/`effective_stat` for AI preview) and `TR-perf-001` (per-system frame posture now complete: ADR-0007 event-driven FSM + ADR-0008 200-draw-call/no-`_process` discipline + ADR-0004 transition path).

**Remaining 2 partials** (neither blocks the gate; both are process/registry items, not missing decisions):
- `TR-zwm-001` — WorldMap catalog not yet in ADR-0003's def-roster; extend at implementation.
- `TR-eng-002` — engine-verification is a cross-cutting discipline satisfied by every ADR's mandatory Engine Compatibility section; it has no single owning ADR by design.

No Foundation, Core, or Presentation requirement lacks a named owner.

---

## Cross-ADR Conflicts

**Known conflict-prone areas** (`consistency-failures.md`): registry/ADR drift during multi-document sync; **signal signatures are the highest-risk surface** (the 8-field `battle_ended` was mistranscribed once); and the C-1/C-2 pattern — *a cross-ADR fact recorded in two documents that fall out of sync*. Both were checked here; the latter recurred as C-4.

### C-3 — TBC autoload host undefined · Dependency/State-authority · **RESOLVED by ADR-0007**
Deferred from the prior pass. ADR-0002 §4 mandates `is_battle_active`/`battle_ended` live on "the TBC autoload orchestrator," but ADR-0004's roster had no TBC slot. **Resolution:** ADR-0007 §1 places the host as `BattleController`, autoload **slot 11**, holding `is_battle_active` + the FSM `_state` + the current `BattleContext`. The autoload-over-scene-node choice is correct: ADR-0002 §4 writes `is_battle_active` as a global query and SaveLoad (slot 10) reads it as a peer autoload with no injected reference; a scene node would be `queue_free()`d at teardown and race the query (`is_queued_for_deletion()` window). The host does no `_ready` work, so slot order is immaterial (verified by the ADR's inertness GUT test requirement).

### C-4 — ADR-0004 roster text lagged its consumer + the registry · Integration/Ownership · Low · **RESOLVED this pass**
ADR-0007 correctly documents amending ADR-0004's roster 10 → 11 (its Ordering-Note, §1, Consequences, ADR-Dependencies), and the registry `boot_initialization` stance already read "fixed order of 11" — but **ADR-0004's own §1 roster table still ended at slot 10** and its architecture diagram listed only through "10 SaveLoad." Mirror image of C-1/C-2: here the consumer is correct and the *producer* text is stale. **Resolution:** ADR-0004 §1 gained the slot-11 `BattleController` row + a dated amendment note, and the architecture diagram gained the slot-11 entry. Logged in `consistency-failures.md`. One-block amendment, not a redesign — did not block acceptance once applied.

No data-ownership contradictions, no dependency cycles, no other state-authority conflicts.

### ADR Dependency Order (topological)

```
Foundation (Accepted):   ADR-0001, ADR-0003
Depends on Foundation:   ADR-0002 (→0001), ADR-0004 (→0001,0002,0003)
Core (Accepted):         ADR-0005 (→0001,0002,0003,0004), ADR-0006 (→0002,0004)
                         ADR-0007 (→0002,0004,0005,0006 + resolves C-3)
Presentation:            ADR-0008 (→0002,0004,0005,0007)
```

ADR-0008 depends on ADR-0007, so 0007 promotes first (both promoted together here). No cycles; all dependencies Accepted.

---

## GDD Revision Flags

**None** — the engine audit found no GDD assumption that contradicts verified Godot 4.6 behaviour. No `systems-index.md` changes proposed.

---

## Engine Compatibility

**Engine specialist verdict (godot-specialist, independent second pass): both ADRs engine-safe to Accept. Zero BLOCKING findings** across 21 findings. No API in either ADR contradicts the pinned 4.6 reference docs.

Confirmed correct (OK): RefCounted null-drop teardown (not `queue_free`); `signal.emit(...)` idiom (not string `emit_signal`); autoload `_ready` order-immunity (no 4.4–4.6 change); typed signal `Array[int]` / Dictionary-as-Set; `match` default `push_error` branch; re-entrant `battle_ended` boolean guard; `await`-park rejection (coroutine/`queue_free` race is real); `StringName` `&""` literals; `NOTIFICATION_EXIT_TREE` disconnect (Callable connections are NOT auto-dropped in 4.6); named-Callable discipline (closures capturing `self`/`ctx` leak `ServiceContext`); 4.6 dual-focus (`grab_focus()` = keyboard/gamepad only); `FoldableContainer` (4.5) / AccessKit (4.5) availability; batching-breakers (`clip_contents`, nested `CanvasLayer`, per-frame `RichTextLabel`); `InputEventScreenTouch` (not `InputEventMouseButton`) for GUT touch synthesis; `BaseButton.pressed` tap+click unification; signal-driven views (no `_process`).

**Advisories — fold into implementation-story Definition of Done, NOT acceptance blockers:**
1. **(ADR-0007)** WeakRef teardown test must cover **indirect** reference cycles through `CombatantSnapshot` fields — snapshots must hold only primitive/value types, never a back-reference into `BattleContext`.
2. **(ADR-0008)** Call `release_focus()` / `get_viewport().gui_release_focus()` when a screen is pushed off-stack, so a freed node cannot retain phantom keyboard focus.
3. **(ADR-0008)** `custom_minimum_size` is in Godot **virtual pixels**, not iOS pt — the project's stretch/content-scale must be calibrated so 1 virtual px = 1 pt on target, or the 44×44 audit passes while the physical target is too small. This should **gate the first UI story** (an uncalibrated scale silently invalidates every audit result).
4. **(ADR-0008)** Verify the exact recursive `MOUSE_FILTER_IGNORE`-propagation property name against live 4.6 docs before use (reference files confirm the 4.5 feature exists but not the property name).
5. **(ADR-0008)** ScreenManager must `add_child()` the screen (triggering `_ready`/`@onready`) **before** calling `setup(ctx)`, or `@onready` vars are null inside `setup`.
6. **(Cross-ADR)** `ServiceContext.build: SymbotBuild` is a by-reference `Resource` labeled read-only; add a thin read-only accessor rather than relying on convention in a multi-contributor codebase.

---

## Architecture Document Coverage

🔴 **`architecture.md` traceability block remains STALE** — still reads *"No ADRs exist yet… all 148 technical requirements are currently traceability gaps"* / *"0 covered / 148 gaps"* (lines 9–10, 249, 251). Reality: 8 ADRs Accepted, **251/277 covered, 0 gaps**. Its layer/data-flow/Required-ADR narrative is still valid and correctly anticipated 0005–0008; only the traceability summary is orphaned. Unchanged from the prior pass, which deferred this to a doc pass. **Recommendation:** refresh the block or delegate the live count to `traceability-index.md`. (Not fixed this session — cosmetic, non-blocking.)

---

## Pre-Gate Checklist (Technical Setup → Pre-Production) — all still ❌

`tests/unit` · `tests/integration` · `.github/workflows/tests.yml` ·
`design/ux/interaction-patterns.md` · `design/ux/accessibility-requirements.md` — none exist.
These block the phase gate regardless of ADR status. Run `/test-setup` + `/ux-design`.

---

## Verdict: CONCERNS → resolved to ACCEPT

Both ADRs comprehensively cover their gap TRs, resolve the last open Foundation/Core seam (C-3), have all dependencies Accepted, introduce no cycles, and are engine-safe (zero blocking findings). Verdict was **CONCERNS** (not clean PASS) only because of **C-4** — a factual lag in ADR-0004's roster text — which is a one-block amendment, not a redesign. With that applied this session, **ADR-0007 and ADR-0008 are promoted Proposed → Accepted (2026-07-14).**

**Actions taken this session:**
1. ✅ ADR-0004 §1 — added slot-11 `BattleController` row + amendment note + diagram entry — fixes C-4.
2. ✅ ADR-0007 → **Accepted**; ADR-0008 → **Accepted**.
3. ✅ `traceability-index.md` — coverage 197 → 251; 51 gap rows flipped to Covered; 3 partials resolved; Known-Gaps/Partial-Coverage sections rewritten.
4. ✅ `technical-preferences.md` ADR log synced (0007/0008 Accepted; "Planned next: none — all Accepted").
5. ✅ `consistency-failures.md` — C-4 logged (table row + full entry, Resolved).

**Deferred (not blocking acceptance):**
- 6 engine advisories → ADR-0007/0008 implementation-story DoD.
- `architecture.md` stale traceability block → follow-up doc pass.
- Pre-gate blockers (tests, CI, UX docs) → `/test-setup` + `/ux-design` before the phase gate.

### Architecture phase status
All 8 planned ADRs (0001–0008) are now **Accepted**. There are **no remaining ADR gaps**. The next milestone is the Technical Setup → Pre-Production gate, whose blockers are the five pre-gate artifacts above, not architecture.
