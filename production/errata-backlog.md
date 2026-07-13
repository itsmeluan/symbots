# Cross-GDD Errata Backlog (Producer-Tracked)

> **Owner**: producer
> **Created**: 2026-07-13
> **Purpose**: Durable home for cross-document obligations that a GDD *specifies* but
> cannot *enforce* — the requirement lives as prose in the citing doc, but the enforcing
> AC/story must land in a **different, already-Approved** doc. Per the qa-lead axiom
> *"an obligation in one GDD, story in another GDD, is never a gate"*, every such
> obligation must be tracked here with an owner and exact AC text, or it falls through
> the gap between two closed design passes.
>
> **Status legend**: `OPEN` (not started) · `IN PROGRESS` · `APPLIED` (erratum landed + light re-review touch owed) · `DONE` (re-reviewed).

---

## Batch: Level Backbone — Symbot Core Progression (#10b) condition-of-approval

Source: `design/gdd/symbot-core-progression.md` 4th-pass /design-review, 2026-07-13.
Creative-director verdict: **NEEDS REVISION (light) → APPROVE on confirmation.** The 2 in-doc
fixes are applied; **CP cannot be marked Approved until ST-1…ST-4 below are discharged.**
These deliberately do NOT edit CP — they land in sibling Approved docs (CP must not unilaterally
edit five Approved siblings). CP carries forward-references to each.

| ID | Target doc (Approved) | Type | Risk | Status |
|----|-----------------------|------|------|--------|
| ST-1 | `enemy-level-zone-scaling.md` (ELZS) | new BLOCKING AC + boss-bonus mechanic | Pillar-2 fantasy break | APPLIED 2026-07-13 (light re-review touch owed) |
| ST-2 | `symbot-assembly.md` | new AC (DoD gate) | untested pipeline order | APPLIED 2026-07-13 (light re-review touch owed) |
| ST-3 | `turn-based-combat.md` (TBC) | new AC | invalid build enters combat | APPLIED 2026-07-13 (light re-review touch owed) |
| ST-4 | `consumable-database.md` | range fix + new AC fixture | **silent runtime failure** | APPLIED 2026-07-13 (light re-review touch owed) |

---

### ST-1 — ELZS equip-gate coverage AC (resolves OQ-CP-8)

- **Target**: `design/gdd/enemy-level-zone-scaling.md` (Approved) — add a numbered BLOCKING AC.
- **Owner**: producer → route to game-designer/economy-designer for the AC + calibration.
- **Why**: OQ-CP-8 — with confirmed CP-F4 constants and the L1–6 MVP zone, the natural
  path to Boss 1 leaves the player ~184 XP short of the L6 Boss-grade equip gate (worse at
  zone floor). The boss-drop part is greyed out at the exact moment the Player Fantasy says
  the door opens. CP owns the *levers* (Rule 5 gate table, CP-F1/F4) but the *calibration*
  is gated on the still-unset MVP zone level range (OQ-CP-1), owned by ELZS. Fixing it in CP
  now creates rework against numbers ELZS will retune.
- **Exact AC to add** (BLOCKING, using zone **floor** enemy level, not an average):
  > For each rarity equip gate G with `level_requirement = threshold_level[G]`, the worst-case
  > reachable XP must clear the gate:
  > `(WIN_COUNT_to_gate × xp_value[enemy_level_floor]) + Σ(boss_xp before the gate) ≥ threshold[threshold_level[G]]`.
  > If any gate fails, either lower that rarity's `level_requirement` floor, raise per-gate
  > `WIN_COUNT`, or add a per-boss completion bonus XP (NOT a blanket `XP_PER_ENEMY_LEVEL` /
  > `BOSS_XP_MULTIPLIER` change — those are blunt levers that scale both gaps proportionally
  > and cannot close them independently; see OQ-CP-8 single-lever caution).
- **DoD**: AC numbered + BLOCKING in ELZS; ELZS review-log entry; CP OQ-CP-8 orphan marker cleared.
- **Note**: verified absent from ELZS at source by both economy-designer and creative-director.
- **APPLIED 2026-07-13** (design-review session — **lever chosen by user: per-boss completion bonus**).
  Full implementation across four docs (all applied, none left as prose):
  - **Core Progression** (mechanism): new **Rule 3a** (boss `completion_bonus_xp` folded into `full_xp` before the deployed/benched split; NOT CP-F4-scaled) + Tuning Knob row + **AC-CP-24** (Unit: bonus folded + distributed, discriminating) + **OQ-CP-8 RESOLVED** with floor-path math + manifest.
  - **Enemy DB** (field): new schema field `completion_bonus_xp: int` (0 WILD; Boss 1 = 310, Boss 2 = 180; content-val ≥0 and 0-unless-BOSS).
  - **TBC** (payload): `battle_ended` extended to carry `completion_bonus_xp` (all three outcomes; "seven-field" signal); consumed-by note updated.
  - **ELZS** (calibration + gate AC): **AC-ELZS-14** (BLOCKING coverage AC, **passing** — Boss-grade `6×45 + 480 = 750 ≥ 744`; Prototype `10×45 + 480 + 370 = 1300 ≥ 1292`; floor-not-roof + WILD-only-win-count discriminators) + Enemy DB erratum bullet + Core Progression interaction row. **AC number was AC-ELZS-14 not -13** (‑13 taken by unresolvable-enemy_id).
  - **Correctness confirmed:** `win_count` counts WILD wins only (ZWM EC-ZWM-07) and Boss 2 has `requires_defeated = Boss 1` (Encounter Zone Rule 8) — so Boss 2's worst-case floor path is 10 WILD + guaranteed Boss 1 + Boss 2; the approved 310/180 values clear both gates.
  - **Still owed:** light `/design-review` confirmation touches on the 3 sibling docs edited (enemy-level-zone-scaling.md, enemy-database.md, turn-based-combat.md) + review-log entries (appended this session). All mechanical errata, no design change to those docs' Status.

### ST-2 — Symbot Assembly AC gating CP-F3 pipeline order (unblocks AC-CP-18)

- **Target**: `design/gdd/symbot-assembly.md` (Approved) — add `AC-SA-XX`.
- **Owner**: producer → route to systems-designer.
- **Why**: AC-CP-18 (DEFERRED) proves CP-F3 is applied *after* SA-F1 and *before* SYN-F4.
  Its enforcement currently lives only as prose in CP's Bidirectionality Notes. An Assembly
  programmer who doesn't read CP will close the CP-F3-insertion erratum story without ever
  running AC-CP-18 — and a wrong insertion point (before SA-F1 → chassis multiplier amplifies
  level growth; or after SYN-F4) produces a different `final_stat` that no non-deferred AC catches.
- **Exact AC to add**:
  > `AC-SA-XX` — CP-F3 insertion order. GIVEN chassis archetype multiplier M=1.2, a CORE with
  > `level_growth = {target_stat: 10}` at level 5 (contribution = 40), and an SA-F1 output of 120
  > for `target_stat` (100 raw × 1.2), WHEN Assembly computes `final_stat`, THEN the value fed to
  > SYN-F4 is exactly **160** (= 120 + 40), NOT 168 (= (100+40) × 1.2). Names **AC-CP-18 as a
  > required Definition-of-Done gate** on the CP-F3-insertion story. Test: Integration.
- **DoD**: AC-SA-XX present in Assembly GDD + names AC-CP-18; Assembly review-log entry.
- **Note**: verified absent at source by qa-lead (R3-C / R4-B1).
- **APPLIED 2026-07-13** (design-review session): **`AC-SA-15`** added to symbot-assembly.md after
  AC-SA-14 — Integration test (chassis M=1.2, level-5 CORE with `level_growth={target_stat:10}` →
  contribution 40, SA-F1 output 120 → expects **160**, not 168 [pre-SA-F1 insertion] and not a
  post-synergy value). Carries a binding **DoD-gate** note naming AC-CP-18 as required on the
  CP-F3-insertion story. CP AC-CP-18 + Bidirectionality note updated to name AC-SA-15 concretely
  (placeholder "AC-SA-XX" discharged). **Still owed:** light `/design-review symbot-assembly.md`
  confirmation touch + Assembly review-log entry (appended this session).

### ST-3 — TBC pre-battle invalid-build refusal AC (enforces EC-CP-05)

- **Target**: `design/gdd/turn-based-combat.md` (Approved) — add an AC (and/or Overworld Navigation when authored).
- **Owner**: producer → route to game-designer.
- **Why**: EC-CP-05 — after a core swap, over-level parts are flagged (not auto-unequipped) and
  the build "cannot enter combat while invalid." CP exposes `is_build_valid(symbot_build) -> bool`;
  the *refusal* is owned by whichever system starts battles. TBC is Approved but has no AC for it.
  A player who swaps to a lower-level core and presses "Enter Combat" is currently stopped by **no
  tested code path**.
- **Exact AC to add**:
  > TBC (or Overworld Navigation) MUST call `CoreProgression.is_build_valid(build)` before starting
  > a battle and refuse to start if it returns false, surfacing the invalid-build reason. AC: GIVEN a
  > build with an over-level part (post core-swap), WHEN battle start is requested, THEN the battle
  > does not start AND an invalid-build message is returned. Test: Integration/Unit.
- **DoD**: AC present in TBC GDD; TBC review-log entry; CP EC-CP-05 owner-pointer discharged.
- **Note**: verified absent at source by qa-lead (R4-B3).
- **APPLIED 2026-07-13** (design-review session): TBC **Rule 2 step 0** added (battle-start
  build-validity precondition — call `CoreProgression.is_build_valid(build)` for every fielded
  Symbot; refuse via `battle_start_refused` if any invalid, no runtime state created) + **AC-TBC-42**
  (BLOCKING Unit, with positive control) verifying the refusal. Core Progression added to TBC's
  upstream dependency table as a **Hard** read (mutual reference w/ the Rule 12 `battle_ended`
  emit — noted as not a design-order cycle since `is_build_valid` is a stateless query). CP EC-CP-05
  + Bidirectionality note updated to name AC-TBC-42 (owner-pointer discharged). **Still owed:** light
  `/design-review turn-based-combat.md` confirmation touch + TBC review-log entry (appended this session).

### ST-4 — Consumable DB range + AC-CD-03 fixture (HIGHEST RISK — silent runtime failure)

- **Target**: `design/gdd/consumable-database.md` (Approved) — CD-1/CD-3 variable tables + AC-CD-03.
- **Owner**: producer → route to systems-designer/economy-designer. **Prioritise this one.**
- **Why**: CP-F3 growth is additive *on top of* SA-F1 part-derived ceilings. A L10 Spark Core reaches
  `max_energy ≈ 147` and `max_structure ≈ 612`, but CD-1/CD-3 still declare `max_structure ∈ [60,594]`
  / `max_energy ∈ [80,120]`, and AC-CD-03 (BLOCKING) uses a `max_energy = 100` fixture. **A hardcoded
  120-ceiling implementation passes every current BLOCKING Consumable test yet clamps a L10 core's
  Power Cell at the wrong value in production.** The runtime clamp reads the live stat and self-corrects
  *if* the impl trusts the runtime max — but nothing tests that it does.
- **Exact changes**:
  1. CD-1 variable table: `max_structure` range `[60, 594]` → **`[60, 612]`** (annotate: part-derived
     ceiling; CP-F3 CORE growth adds on top).
  2. CD-3 variable table: `max_energy` range `[80, 120]` → **`[80, 147]`** (same annotation); update the
     Power Cell `+50`-on-80-cap balance note.
  3. AC-CD-03: add a fixture at `max_energy = 147`, `current_energy = 130` → `min(147, 180) = 147`
     (catches a hardcoded-ceiling implementation against a L10 core).
- **DoD**: ranges updated + AC-CD-03 fixture added; Consumable DB review-log entry; CP + CD range
  re-annotation obligations discharged.
- **Note**: BLOCKING per systems-designer F4. Also mirror the structure-side note in CD-1 (+18 / +3%,
  smaller gap).
- **APPLIED 2026-07-13** (design-review session): CD-1 `max_structure` range → **[60, 612]**; CD-3
  `max_energy` range → **[80, 147]** (both variable tables annotated part-derived floor + CP-F3 growth);
  Formulas-preamble CP-F3 note updated to point at AC-CD-03 case C; **AC-CD-03 case C added**
  (`max_energy=147`, `current=130` → `min(147,155)=147`; a hardcoded-120 impl returns 120 ≠ 147).
  Structure-side note mirrored in the preamble. **Still owed:** a light `/design-review` touch on
  consumable-database.md to confirm the erratum, and Consumable DB review-log entry (appended
  this session). AC count 25 → still 25 (case added to existing AC-CD-03, not a new AC).

---

## Related (already logged elsewhere, not part of this batch)
- `REFERENCE_SA_F1_OUTPUT` registry-anchor obligation (CP Bidirectionality Notes) — economy-designer #5 /
  systems-designer: AC-CP-21/22 depend on an in-doc reference table with no drift guard. Convert to a
  registry entry or SA-F1 erratum obligation. Owner: producer (backlog, non-blocking).
