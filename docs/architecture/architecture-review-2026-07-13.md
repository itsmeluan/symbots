# Architecture Review Report

Date: 2026-07-13
Mode: `/architecture-review` (full)
Engine: Godot 4.6 (pinned 2026-02-12)
GDDs Reviewed: 19 (all Approved systems in `design/gdd/`)
ADRs Reviewed: 4 (ADR-0001 Save/Load, ADR-0002 Event Bus, ADR-0003 Content Resources, ADR-0004 Scene Management & Boot) + `architecture.md`

---

## Traceability Summary

First full extraction — the TR registry was empty before this review. All 277
requirement IDs were registered in `tr-registry.yaml` with `created: 2026-07-13`.
IDs already cited by ADR-0001–0004 and architecture.md (e.g. TR-ep-004,
TR-eai-003, TR-zwm-002) were pinned to their cited meanings during extraction,
so every existing ADR reference remains valid.

| Status | Count | % |
|--------|-------|---|
| ✅ Covered by a written ADR (0001–0004) | 145 | 52% |
| ✅ System-internal (GDD rule + unit tests; no ADR required) | 24 | 9% |
| ⚠️ Partial | 14 | 5% |
| ❌ Gap (owned by a planned, unwritten ADR) | 94 | 34% |
| **Total** | **277** | 100% |

> **Baseline note**: architecture.md's planning pass counted 148 coarse
> requirements ("0/148 covered", line 249 — a pre-ADR snapshot). This review's
> persisted extraction is finer-grained (277) and supersedes that count and the
> TR citations in architecture.md's Required-ADRs section. The full per-TR map
> is in `traceability-index.md`.

### Coverage Gaps

Every gap is owned by one of the four ADRs that architecture.md already planned —
no gap is *unanticipated*. This is the expected state at this phase: the
Foundation layer is fully covered; the Core/Presentation layers await their ADRs.

| Planned ADR | Gap count | Systems affected |
|-------------|-----------|------------------|
| ADR-0005 Stat pipeline & battle snapshot | 36 | Assembly, Synergy, Core Progression, Damage Formula, TBC snapshot rules |
| ADR-0006 RNG service & determinism | 9 | Damage Formula (crit), Enemy AI, Drop System |
| ADR-0007 TBC finite state machine | 43 | Turn-Based Combat runtime, Part-Break |
| ADR-0008 UI architecture & screen contracts | 6 | Workshop preview, core-swap flagging, World Map UI, touch/input standards |

Suggested creation order (most foundational first):
1. `/architecture-decision Stat pipeline & battle snapshot` (ADR-0005)
2. `/architecture-decision RNG service & determinism` (ADR-0006)
3. `/architecture-decision Turn-based combat state machine` (ADR-0007)
4. `/architecture-decision UI architecture & screen contracts` (ADR-0008)

### Partial Coverage (14)

- **Formula-semantics TRs on DB systems** (TR-part-008/009/010/023/024,
  TR-edb-003/006/007/011, TR-mdb-008): ADR-0003 validates authored values and
  ranges; the *execution* of Formula 1/2/2b, EDB-1, and MOVE-F1 belongs to
  ADR-0005. Both halves must exist before implementation.
- **TR-zwm-001**: WorldMap zone-graph Resource follows the ADR-0003 catalog
  pattern but is not in ADR-0003's def roster (7 def classes). Extend the roster
  when Overworld systems are implemented — do not directory-scan.
- **TR-perf-001** (60 fps): ADR-0004 addresses the transition-hitch path;
  per-system frame budgets pending ADR-0007/0008.
- **TR-eng-002** (post-cutoff API verification): discipline in force — all four
  ADRs carry Engine Compatibility sections; ongoing obligation, never "done".
- **TR-test-001**: ADR-0003 mounts the CI-blocking validator; the determinism
  contract (seeded RNG in tests) is pending ADR-0006.

---

## Cross-ADR Conflicts

**Known conflict-prone areas** (from `docs/consistency-failures.md`): registry
entries drifting from their source GDD during multi-document sync passes
(2026-07-10 DF-1 range incident). This review found the same failure class again.

### 🔴 Conflict 1 (BLOCKING — RESOLVED during review)

**Type**: Integration contract
**Documents**: `docs/registry/architecture.yaml` (`combat_battle_end`) vs ADR-0002 §1 + TBC Rule 12
**Finding**: The registry's `signal_signature` was a mistranscription — a 5-field
payload omitting `completion_bonus_xp`, `is_first_boss_defeat`, and `enemy_level`,
the exact fields Core Progression's XP award depends on. ADR-0002 and the TBC GDD
agreed (8 fields); only the registry diverged. A subscriber authored against the
registry would bind to a payload the emitter never sends.
**Resolution**: Registry corrected to the 8-field Rule 12 payload verbatim
(user-approved, applied 2026-07-13); synchronous-emit + payload-self-sufficiency
notes carried over; `revised` stamped. Logged in `docs/consistency-failures.md`.

No other cross-ADR conflicts: data ownership is disjoint (SaveLoad owns disk,
EP owns progression facts, DBs own content, ScreenManager owns transitions),
no performance-budget collisions, no pattern conflicts (event-driven boundary
via EventBus is used consistently), no state-authority overlaps.

### ADR Dependency Order

```
Foundation (topologically sorted — no cycles detected):
  1. ADR-0001 Save/Load            (no dependencies)
  2. ADR-0002 Event Bus            (depends on ADR-0001)
  3. ADR-0003 Content Resources    (depends on ADR-0001, ADR-0002)
  4. ADR-0004 Scene Mgmt & Boot    (depends on ADR-0001, ADR-0002, ADR-0003)
```

⚠️ **All four ADRs are still `Status: Proposed`.** Stories referencing a Proposed
ADR are auto-blocked, and each ADR depends on Proposed predecessors. They must be
Accepted in dependency order (0001 → 0002 → 0003 → 0004) before implementation.

---

## GDD Revision Flags

None — no GDD assumption conflicts with verified engine behaviour. The two
unverified engine surfaces below are ADR-level risks with fallbacks that do not
change any GDD-visible design rule.

---

## Engine Compatibility

Engine: Godot 4.6. ADRs with Engine Compatibility section: 4/4.
No deprecated APIs referenced. No stale version references. No post-cutoff API
conflicts between ADRs.

**Specialist verdict (godot-specialist)**: all four Foundation ADRs are
**engine-sound for 4.6**. Findings:

### Unverified gates (must verify before their phase begins)

1. **`Dictionary[StringName, int]` `@export` → `.tres` round-trip** — HIGH.
   Gate to *content authoring* (ADR-0003 already marks this a verification gate).
   Three sub-risks: string→StringName key coercion on load; typed-dict `.get()`
   returning Variant; inspector authoring ergonomics for typed dict keys.
   Fallback (plain Dictionary + load-time coercion) requires an ADR amendment.
2. **`PROCESS_MODE_DISABLED` vs `_input` on plain Nodes** — MEDIUM. ADR-0004's
   `_unhandled_input`-only standard plus TransitionLayer input blocking is safe
   under either behaviour; verify anyway during boot-scaffold implementation.

### Implementation risks to fold into ADR acceptance or the review checklist

- **ADR-0001 lacks an emergency-save contract**: iOS
  `NOTIFICATION_APPLICATION_PAUSED` synchronous save (ADR-0004 mitigation)
  has no named API in ADR-0001, and force-kill data loss is an accepted risk
  nowhere stated. Add both at acceptance.
- Deferred autosave `CONNECT_DEFERRED` callables must target the SaveLoad
  autoload itself (autoload lifetime), never a scene-tree node.
- `get_x() -> XDef` null-return contract: GDScript cannot type "nullable XDef";
  the `has_x()` guard convention must be a review-checklist rule.
- BootError screen must render with zero content-DB reads (it exists precisely
  because DBs may have failed to load).
- `TBC.is_battle_active` state must live on an autoload, not a Battle scene
  node (queue_free timing makes scene-node state unreliable at teardown).
- `to_utf8_buffer().size()` on the save blob allocates the full buffer — fine
  at the 2 MiB budget, worth a comment so no one calls it per-frame.

---

## Architecture Document Coverage

- All 19 systems from `systems-index.md` appear in architecture.md's layers. ✅
- Data flow covers all cross-system communication in the GDDs (via EventBus +
  accessor contracts). ✅
- No orphaned architecture (no architecture systems lacking a GDD). ✅
- **Staleness**: lines 23/81/262 still describe Save/Load via
  `Resource.duplicate_deep()` snapshots — superseded by ADR-0001's plain-data
  dictionary serialization (and `duplicate_deep()` on defs is now a forbidden
  pattern per ADR-0003). Line 249's "0/148 covered" is a pre-ADR snapshot
  superseded by this report. Recommend a follow-up pass to align architecture.md
  with the accepted ADRs — content edits, not decisions.

---

## Verdict: **CONCERNS**

No blocking cross-ADR conflicts remain (the one found was resolved in-review).
The 94 gaps are all owned by the four planned ADRs — expected at this phase,
but they block Core-layer implementation until written and accepted.

**Path to PASS:**
1. Accept ADR-0001 → 0002 → 0003 → 0004 (in order). ✅ **Done 2026-07-13** (same-day follow-up, see postscript)
2. Verify the `Dictionary[StringName, int]` .tres gate before content authoring.
3. Write + accept ADR-0005 → 0008 (order above) to close the 94 gaps.
4. Align architecture.md with the accepted ADRs (staleness list above).

---

## Postscript — Foundation acceptance (2026-07-13, same session)

All four Foundation ADRs were walked to **Accepted** in dependency order immediately
after this review, with the specialist's acceptance items folded in:

- **ADR-0001**: added File Rule 8 (`save_emergency()` — the API behind ADR-0004's
  iOS `NOTIFICATION_APPLICATION_PAUSED` mitigation; identical envelope + atomic
  write) and File Rule 9 (force-kill data loss between quiesce saves is an
  **accepted risk**, bounded by event-boundary cadence); `to_utf8_buffer()`
  allocation note; emergency-save validation criterion.
- **ADR-0002**: § 4 now states explicitly that `is_battle_active` lives on the
  TBC autoload orchestrator, never the Battle scene node (queue_free race).
- **ADR-0003**: accepted with the typed-dict `.tres` verification gate explicitly
  **not waived** — it still blocks content authoring; a failed gate requires an
  ADR amendment.
- **ADR-0004**: added the BootError zero-content-DB-reads render rule; the
  `connect_autosave_triggers()` comment now states callables target the SaveLoad
  autoload itself; the iOS suspend mitigation now names `SaveLoad.save_emergency()`.
- `.claude/docs/technical-preferences.md` Architecture Decisions Log populated.

Remaining checklist items the acceptance did not absorb: the `has_x()` guard
convention must land in the control manifest when `/create-stories` first
generates it; architecture.md alignment (step 4) is still pending.
