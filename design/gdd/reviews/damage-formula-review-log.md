# Review Log: Damage Formula System

## Review — 2026-07-09 — Verdict: APPROVED (Round 2)
Scope signal: S–M
Specialists: lean mode (no specialist agents)
Blocking items: 0 | Recommended: 0
Summary: All Round 1 items confirmed fixed. Full numeric verification via python3: all 20 assertions (AC-DF-01 through AC-DF-18 expected values, wrong-path cross-checks, worked examples, output range bounds) confirmed correct. EPSILON "defensive convention" claim empirically verified — exhaustive scan of A, D ∈ [0, 110], T ∈ {0.75, 1.0, 1.5}, crit ∈ {1.0, 2.0} found zero epsilon-changing inputs. No new issues.
Prior verdict resolved: Yes — all Round 1 items confirmed fixed.

## Review — 2026-07-09 — Verdict: NEEDS REVISION → Revised (Round 1)
Scope signal: S–M
Specialists: lean mode (no specialist agents)
Blocking items: 1 (resolved in session) | Recommended: 4 (all applied)
Summary: First review. One blocker: AC-DF-03 cross-check arithmetic was wrong — the stated wrong-binding result (22) actually computes to 26 (`1600/60 = 26.67 → floor 26`); the value 22 described a different, asymmetric wrong binding. A wrong cross-check expected value propagates into broken test suites. Four recommended items, all applied: (R1) GDScript integer-division trap documented — `int/int` truncates, producing 49 instead of 50; float cast required; (R2) EC-01/EC-03 guard contradiction — EC-03's guard narrowed to `if A == 0 and D == 0`; (R3) EPSILON load-bearing status documented as defensive convention per Part Database precedent; (R4) EC-07 note claiming floor=round=82 for pre_floor=82.5 corrected — GDScript rounds half away from zero, so round(82.5)=83 and the input IS discriminating.
Prior verdict resolved: First review.

### Blocker Resolved (Round 1)
- B1: AC-DF-03 cross-check corrected 22 → 26 with arithmetic derivation inline

### Recommended Applied (Round 1)
- R1: GDScript float-arithmetic implementation note added to Formulas section
- R2: EC-03 guard narrowed to the true division-by-zero case; EC-01 non-contradiction note added
- R3: EPSILON documented as defensive convention (verified empirically in Round 2)
- R4: EC-07 rounding note corrected for GDScript round-half-away-from-zero semantics
