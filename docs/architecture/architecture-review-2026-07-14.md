# Architecture Review Report — 2026-07-14

- **Date:** 2026-07-14
- **Engine:** Godot 4.6
- **Mode:** full
- **GDDs Reviewed:** 19 approved
- **ADRs Reviewed:** 6 (ADR-0001..0004 Accepted; ADR-0005, ADR-0006 reviewed here)
- **Purpose:** verify ADR-0005 & ADR-0006 close their gap TRs, detect conflicts, run engine
  checks, and decide whether both can move **Proposed → Accepted**.
- **Outcome:** both amended and promoted to **Accepted** this session (see Verdict).

---

## Traceability Summary

| | Prior review (2026-07-13) | This review |
|---|---|---|
| Total requirements | 277 | 277 |
| ✅ Covered | 145 (52%) | **197 (71%)** |
| ⚙️ System-internal | 24 | 24 |
| ⚠️ Partial | 14 | 5 |
| ❌ Gap | 94 | **51** |

**Delta drivers:**
- **ADR-0005** covers its **36** gap TRs (cp, tbc, df, sa, syn) — its "GDD Requirements
  Addressed" table cites all 36 explicitly.
- **ADR-0005** also resolves **10 execution-partials** (`part-008/009/010/023/024`,
  `edb-003/006/007/011`, `mdb-008`) — previously "ADR-0003 (validation) / ADR-0005
  (execution — planned)".
- **ADR-0006** covers **5** real gap TRs — `TR-df-003, TR-eai-004, TR-eai-005, TR-drop-001,
  TR-drop-005` — plus resolves the `TR-test-001` determinism partial.

Remaining **51 gaps** are owned entirely by the two still-unwritten planned ADRs:
**ADR-0007** (TBC FSM, 45) and **ADR-0008** (UI, 6). No Foundation/Core requirement lacks a
named owner.

### Traceability correction — TR-eai-006/007/008/009 re-pointed off ADR-0006

The prior index parked four requirements under ADR-0006 that are **not RNG concerns**;
ADR-0006 correctly does not claim them. Re-pointed in `traceability-index.md`:

| TR | What it is | New owner | New status |
|----|-----------|-----------|-----------|
| TR-eai-006 | DF-1 preview includes MOVE-F1 power tier | ADR-0005 *provides* `DamageFormula`; AI consumption → ADR-0007 | ⚠️ Partial |
| TR-eai-007 | Effective post-SYN-F4 defense used in preview | ADR-0005 *provides* `effective_stat`; consumption → ADR-0007 | ⚠️ Partial |
| TR-eai-008 | Phase shift from battle state, no persistent AI state | ADR-0007 (Enemy-AI FSM) | ❌ Gap |
| TR-eai-009 | Fallback to AGGRESSIVE on unknown profile | ADR-0007 (Enemy-AI robustness) | ❌ Gap |

This is registry re-pointing, not coverage loss — the TRs move from "ADR-0006 (planned)" to
their true owner. (`tr-registry.yaml` stores no per-TR ADR field, so this change lives entirely
in the coverage index.)

---

## Cross-ADR Conflicts

**Known conflict-prone areas** (`consistency-failures.md`): registry entries drifting from
source docs during multi-doc sync; **signal signatures are the highest-risk surface** (the
8-field `battle_ended` was mistranscribed once before). Both are relevant below.

### C-1 — Boot-step numbers asserted by ADR-0005 didn't exist in ADR-0004 · Integration/Ordering · Medium · **RESOLVED**
ADR-0005 said stat owners construct at "boot step 5" and `BalanceConfig` loads at "step 2",
but ADR-0004 step 5 = save-provider registration and step 2 = the six content catalogs
(`BalanceConfig` is neither, and had no load site). Intent was compatible; only the numbers
collided.
**Resolution applied:** ADR-0004 §4 `run_boot()` gained explicit sub-steps **2b** (BalanceConfig
load) and **4b** (DI owner construction, before provider registration); ADR-0005 now cites
2b/4b instead of overloaded integer steps. Existing integer steps were not renumbered, so all
other "step 4/6" references stay valid.

### C-2 — `LogSink.info` was undeclared on ADR-0002's LogSink base · Integration/Interface · Low–Medium · **RESOLVED**
ADR-0006 logs the root seed via `LogSink.info(...)` and ADR-0004's boot breadcrumbs assume an
`info` channel, but ADR-0002 §5 declared only `warn`/`error`.
**Resolution applied:** ADR-0002 §5 now declares `@abstract func info(code: StringName,
detail: Dictionary) -> void`; the production wrap note maps `info → print`. This also unblocks
ADR-0004's `boot_step` breadcrumbs.

### C-3 — TBC autoload host undefined · Dependency/State-authority · Medium · **pre-existing, deferred to ADR-0007**
ADR-0002 §4 mandates `is_battle_active`/`battle_ended` live on "the TBC autoload orchestrator",
but ADR-0004's fixed 10-slot roster has no TBC slot (EventBus, Log, 6 DBs, RngService,
SaveLoad). ADR-0005 *consumes* `battle_ended`; ADR-0006's vends are *consumed by* that
orchestrator. Neither new ADR introduces the seam and both correctly stay host-agnostic.
**Action:** ADR-0007 must place the TBC host (11th autoload slot, or an existing persistent
node) — the `battle_ended`-host seam. No action for 0005/0006.

No data-ownership contradictions, no dependency cycles, no state-authority conflicts beyond C-3.

### ADR Dependency Order (topological)

```
Foundation (Accepted):   ADR-0001, ADR-0003
Depends on Foundation:   ADR-0002 (→0001), ADR-0004 (→0001,0002,0003)
Depends on Accepted set: ADR-0005 (→0001,0002,0003,0004)   all deps Accepted
                         ADR-0006 (→0002,0004)             all deps Accepted
Planned:                 ADR-0007 (→0005,0006 + resolves C-3), ADR-0008 (→0004)
```

No unresolved dependencies for 0005/0006; no cycles.

---

## GDD Revision Flags

**None** — the engine audit found no GDD assumption that contradicts verified Godot 4.6
behaviour. No `systems-index.md` changes proposed.

---

## Engine Compatibility

**Engine specialist verdict: both ADRs engine-safe to Accept.** No API in either ADR
contradicts the pinned 4.6 reference docs.

- **ADR-0005:** typed dicts (4.4+, shared open `.tres` gate), `maxi/floori` (4.0-era),
  `duplicate(true)` vs `duplicate_deep()` boundary (precise & correct), StringName→`Array[String]`
  sort pin (correct defensive stance), static classes/RefCounted/typed signals (stable).
- **ADR-0006:** `RandomNumberGenerator`/`.seed`/`.randi`/`.randomize` (4.0-era stable), PCG32
  within-build-only determinism (correctly framed — reference docs are silent on RNG, so
  re-verify-on-bump is the only defensible posture), `.seed` reset & `.randomize()` readback
  (confirmed, retained as engine-bump regression checks), `0` is a valid seed / no sentinel.

**Advisory notes — fold into implementation stories, NOT acceptance blockers:**
1. `.tres` round-trip gate test must exercise **nested** dicts (`chassis_modifiers`,
   `type_chart`), not just flat.
2. `stats_changed(final_stat: Dictionary)` / `synergy_changed` — typed dicts can't be
   signal-param types in GDScript today; plain `Dictionary` is the only option. Worth an
   explicit note in ADR-0005's implementation story.
3. `CombatantSnapshot.move_pool: Array` → prefer `Array[Variant]` over bare `Array`.
4. `RngService.init()` — add a double-init guard (`_initialized` flag) for test environments.
5. Forbidden-pattern grep should also catch bare `randomize(` (global-scope call).

---

## Architecture Document Coverage

🔴 **`architecture.md` traceability block is STALE.** It still reads *"No ADRs exist yet… all
148 technical requirements are currently traceability gaps"* / *"0 covered / 148 gaps."*
Reality: 6 ADRs exist, **197/277 covered**. Its layer/data-flow/Required-ADR narrative remains
valid (and correctly anticipates 0005/0006/0007 "before the Core system"), but the traceability
summary is orphaned. Recommend refreshing it or delegating the live count to
`traceability-index.md`. (Not fixed this session — flagged for a follow-up doc pass.)

---

## Pre-Gate Checklist (Technical Setup → Pre-Production) — all still ❌

`tests/unit` · `tests/integration` · `.github/workflows/tests.yml` ·
`design/ux/interaction-patterns.md` · `design/ux/accessibility-requirements.md` — none exist.
These block the gate regardless of ADR status. Run `/test-setup` + `/ux-design`.

---

## Verdict: CONCERNS → resolved to ACCEPT

Both ADRs comprehensively cover their gap TRs, have all dependencies Accepted, no cycles, and
are engine-safe. Verdict was **CONCERNS** (not clean PASS) only because C-1 and C-2 were factual
inaccuracies in the ADR text — neither a redesign, both one-line amendments. With those applied
this session, ADR-0005 and ADR-0006 were promoted **Proposed → Accepted**.

**Actions taken this session:**
1. ✅ ADR-0004 §4 — added boot sub-steps 2b (BalanceConfig) + 4b (owner construction) — fixes C-1.
2. ✅ ADR-0002 §5 — added `@abstract func info(...)` to LogSink — fixes C-2.
3. ✅ `traceability-index.md` — coverage 145→197; re-pointed TR-eai-006/007/008/009 to ADR-0007.
4. ✅ ADR-0005 & ADR-0006 → **Accepted (2026-07-14)**; `technical-preferences.md` ADR log synced.

**Deferred (not blocking acceptance):**
- C-3 (TBC host) → ADR-0007.
- 5 engine advisories → implementation stories.
- `architecture.md` stale traceability block → follow-up doc pass.
- Pre-gate blockers (tests, CI, UX docs) → `/test-setup` + `/ux-design` before the phase gate.

### Required ADRs (remaining, most foundational first)
1. **ADR-0007** — Turn-based combat state machine (45 TRs; MUST resolve the `battle_ended`-host
   seam, C-3; sole orchestrator consuming ADR-0006's two vends and ADR-0005's contracts).
2. **ADR-0008** — UI architecture & screen contracts (6 TRs).
