# Inventory System — Review Log

## Review — 2026-07-12 — Verdict: NEEDS REVISION → APPROVED (fix-confirmation same session)
Scope signal: S (single system, one integer formula, no new ADRs; all blockers in-document prose/AC edits)
Specialists: economy-designer, systems-designer, qa-lead, game-designer, creative-director (senior synthesis)
Blocking items: 5 | Recommended: ~10 (folded selectively) | Nice-to-have: several (deferred)
Prior verdict resolved: First review

### Verdict path
Full-panel /design-review returned **NEEDS REVISION** on a tight, surgical cluster (not a redesign — 8/8 sections, all cross-doc contracts to Part DB / Consumable DB / Drop System / TBC verified accurate). 15 BLOCKING findings raised across four specialists; creative-director synthesized to **5 genuine blockers**, committed to **approve-on-fix-confirmation**. All 5 fixed same session → APPROVED.

### The 5 blockers → fixes
1. **Counter persistence (main review + systems B-3 + qa G-2, converged).** `next_instance_id` was absent from the serialized model (only the 3 stores were enumerated), so EC-INV-07 "never reused" broke across save/load (a `max(live)+1` rebuild re-hands a scrapped id → dangling Workshop refs). → Added `next_instance_id` as a 4th persisted field (Rule 1); updated EC-INV-07, both Save/Load contract rows, AC-INV-15 (counter round-trip, scrapped-highest-id fixture). Hardened AC-INV-09 to assert against an ever-assigned set — `max(live)+1` now explicitly FAILS.
2. **`instance_id` type (systems B-5).** "int (StringName-safe)" = two incompatible Godot key types. → Retyped plain `int`, never coerced to String/StringName for keying.
3. **INV-1 input guards (systems B-1/B-2 + game-designer F7).** Negative `qty` and `current > max_stack` (post-retune-down stale save) both produced negative `accepted` / silent mutation. → Enforced preconditions (`qty ← max(qty,0)`, `capacity = max(max_stack−current,0)`, load-time `current` clamp); new EC-INV-11; AC-INV-01 gained no-op/negative-qty/stale-over-cap sub-cases + per-field FAIL.
4. **Scrap-add return contract (systems B-4 + qa G-1).** `add(Scrap)` had no `{accepted,rejected}` at the `SCRAP_MAX` clamp → "no silent loss" non-uniform. → Rule 4 + interface put Scrap on the same split; AC-INV-10 asserts the `{accepted:2, rejected:8}` overflow return.
5. **OQ-INV-1 tier-refund (economy F4 + game-designer F4).** Deferral baked in an irreversible economy commitment. → **User locked 0% refund, total sink**; any future refund declared additive & non-retroactive. Formulas + OQ-INV-1 row updated.

### Key adjudication (creative-director)
economy-designer and game-designer both implied the fix for the tier-blind scrap yield was to *add refunds*. **Rejected** — flat tier-blind yield is a deliberate anti-hoarding / commit-to-a-build stance (Pillars 1 & 3); refunds would make upgrading risk-free and regress that tension. Only the *undeclared commitment* blocked, not the policy. User confirmed 0%.

### Deferred (not blocking; owned elsewhere)
- **Flat-list "same part_id + same tier" grouping** (game-designer F1/F2) → Inventory UX pass (`/ux-design` before epics, per the GDD's own UX flag). GDD names the seam; the count-badge-vs-N-rows decision + any grouping API sits with UI.
- **Anti-hoarding "duplicate-as-build-hypothesis" re-framing owner** → acquire-cue / Workshop / Inventory UI.
- **AC-INV-06 per-rarity non-zero-tier fixtures** (qa D-2), **AC-INV-13 split into unit + integration** (qa DEF-1), **get_parts compound-filter AND/OR semantics** (systems R-2), minor AC coverage polish (qa T-2/T-3/T-4/G-3/G-4/G-5/G-6) → fold at story/test-authoring time.
- **All Alpha economy modeling** (fabrication > scrap_yield invariant, faucet contingency) → Part Upgrade / Blueprint Crafting GDDs.

### Errata this GDD discharges on Approved docs (applied on approval)
- **Consumable DB** — EC-CD-12 resolved (overflow = reject-with-notice, owned by Inventory), AC-CD-23 activated (stack model now defined), OQ-CD-5 overflow-policy half resolved (`max_stack` C20/R10/P5 stand as the INV-1 caps). Light re-review touch.
