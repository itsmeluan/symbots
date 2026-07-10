---
name: feedback-math-conventions
description: Project-wide math standards that apply to every formula this agent produces
metadata:
  type: feedback
---

**Rule 1 — Integer outputs with epsilon guard:** Every formula that uses floor() on a float product must include `+ 0.0001` inside the floor call. Classify every epsilon as LOAD-BEARING or DEFENSIVE — never leave it undocumented.

**Why:** IEEE 754 double precision produces repeating-decimal errors on common coefficients (0.3 → multiples of 10 underflow; 0.18 → multiples of 50 underflow). Prior formulas got this wrong until python3 scans caught traps. The epsilon is not optional.

**How to apply:** For every new formula with floor() on a float, state the epsilon status in the variable table or a note. If you cannot verify exhaustively, write "REQUIRES python3 scan before approval" — the project runs these scans before implementation sign-off.

---

**Rule 2 — Discriminating worked examples:** Every worked example must use inputs where floor ≠ round ≠ ceil. An example where all three agree cannot catch wrong rounding implementations.

**Why:** ACs must fail under plausible wrong implementations. If floor == round == ceil for the example, a round() implementation passes the AC and ships wrong code.

**How to apply:** Before finalizing any worked example, verify: floor(x) ≠ round(x) AND floor(x) ≠ ceil(x). Use processing=53 or processing=72 style inputs (values where coefficient × input has a non-trivial fractional part). GDScript uses round-half-away-from-zero, so 21.5 → round=22, floor=21 — this is a valid discriminating case.

---

**Rule 3 — GDScript int/int division truncates:** Formulas using division must cast operands to float first. `float(A) * float(A) / (float(A) + float(D))` — not `A * A / (A + D)`. The variable table must note this where division occurs.

**Why:** GDScript silently truncates int/int. The DF-1 GDD documents this explicitly. Missing the cast produces wrong (always-lower) base_damage.

---

**Rule 4 — Python3 scan policy:** When a formula coefficient is not a power of two (cannot be exactly represented in IEEE 754 binary), mark it "REQUIRES python3 scan before approval." The scan exhaustively checks all integer inputs in the stat range and compares floor(x) vs floor(x + 0.0001) to find traps. Confirmed load-bearing cases: 0.3 (TBC-F4 Shock), 0.18 (TBC-F6 Repair at input 50).
