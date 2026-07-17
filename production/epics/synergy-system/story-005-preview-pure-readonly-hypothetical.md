# Story 005: preview() pure read-only hypothetical

> **Epic**: Synergy System
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/synergy-system.md`
**Requirement**: `TR-syn-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: UI Architecture & Screen Contracts (primary); ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: UI previews reuse the pure core — `SynergyEvaluator.preview` is the single hypothetical-display point; UI never reimplements the formula. `preview()` is strictly read-only: no cache write, no signal emit.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: **GDScript negative indices wrap** — an unchecked `target_slot < 0` silently displaces the wrong slot rather than erroring, so the out-of-range guard must be explicit (`target_slot < 0 or target_slot > 7`). No post-cutoff API required.

**Control Manifest Rules (this layer — Core / Presentation reuse point)**:
- Required: previews reuse the pure core (`SynergyEvaluator.preview`) — never reimplement a formula for display (ADR-0008).
- Forbidden: cache write or signal emit inside `preview()`; a delta-approach that adds candidate tags without subtracting the displaced part's tags.
- Guardrail: synchronous, testable.

---

## Acceptance Criteria

*From GDD `design/gdd/synergy-system.md`, scoped to this story:*

- [ ] **AC-SYN-08** — `preview()` is strictly read-only: after `evaluate` (ironclad=3, `armor==8`), `preview(kinetic_candidate, 0, current_parts)` (hypothetical ironclad=2, VOLT=2 → no tiers) → signal counter unchanged; `cached_bonus_block.stat_delta["armor"]` still 8; return value `stat_delta.is_empty()` AND `effects.is_empty()`.
- [ ] **AC-SYN-13** — `preview()` models both threshold directions:
  - A (activates): VOLT=2 (below), `preview(volt_candidate, 2, current_parts)` → hypothetical VOLT=3 → return `stat_delta["energy_power"] == 6`; cache still empty; no emit.
  - B (deactivates): VOLT=3 active (`energy_power==6`), `preview(kinetic_candidate, 0, current_parts)` → hypothetical VOLT=2 → return `stat_delta.is_empty()`; cache still 6; counter unchanged. FAIL if return `energy_power==6` (delta-approach that adds but never subtracts the displaced part — the discriminating check).
- [ ] **AC-SYN-20** — `preview()` returns empty block on out-of-range `target_slot` (Rule 9): after `evaluate` (VOLT=5, `energy_power==18`); A `preview(candidate, -1, parts)` and B `preview(candidate, 8, parts)` → each: no crash, return `stat_delta.is_empty()` AND `effects.is_empty()`, counter unchanged, cache still 18, content error logged. FAIL if crash (negative-index wrap / OOB) or return contains bonus data.
- [ ] **AC-SYN-24** — `preview()` with null candidate models unequip (EC-SYN-14): VOLT=3 active (`energy_power==6`), `preview(null, 0, current_parts)` → hypothetical slot 0 empty → VOLT=2 → return `stat_delta.is_empty()` AND `effects.is_empty()`; cache still 6; counter unchanged; **no** content error logged (null candidate is valid input). FAIL if crash on `null.synergy_tags`, or return `energy_power==6` (null candidate ignored).

---

## Implementation Notes

*Derived from ADR-0008 + ADR-0005 Implementation Guidelines and GDD Rule 9:*

- `preview(candidate, target_slot: int, current_parts) -> Dictionary` returns a **hypothetical bonus block** — the block that *would* result if `candidate` (a `PartDef`, or `null` for unequip) occupied `target_slot`. It must **not** write `cached_bonus_block` and must **not** emit `synergy_changed` (TR-syn-009).
- Build the hypothetical by **copying** `current_parts`, replacing index `target_slot` with `candidate`, then running the same private `_compute_block` (Story 004) on the copy — returning its bonus block **without** committing it. Because it recomputes from the full hypothetical array, both activation (candidate adds a tag) and deactivation (candidate displaces a tag-bearing part) fall out correctly. Do **not** take a delta-shortcut that adds the candidate's tags to the cached state — it passes AC-SYN-13 Scenario A but fails Scenario B (the displaced part's tags are never subtracted).
- **Guard `target_slot` first**: `if target_slot < 0 or target_slot > 7:` → log a content error, return an empty block, do not touch the cache (Rule 9 / AC-SYN-20). GDScript negative indices wrap, so `-1` would silently displace slot 7 without the explicit guard.
- **Null candidate is valid** (AC-SYN-24 / EC-SYN-14): `null` at `target_slot` models an unequip — the compute path already null-guards `synergy_tags` per Story 001, so no special-casing beyond *not* logging an error for the null candidate.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001–004**: the compute pipeline (`_compute_block`) `preview()` reuses read-only.
- **Consumer-owned**: Workshop UI's combined effective-stat display formula (OQ-6, resolved) that composes `preview().stat_delta` with SA-F2's delta — that lives in the Workshop UI epic.

---

## QA Test Cases

*Embedded from the GDD's AC fixtures. Implement against these.*

- **AC-SYN-08**: Given `evaluate` ironclad=3 (`armor==8`), counter=N; When `preview(kinetic_candidate, 0, parts)`; Then counter==N, cache `armor` still 8, return block empty. Edge: cache mutated / signal emitted / return contains ironclad bonus.
- **AC-SYN-13 A**: Given VOLT=2, slot 2 = KINETIC part, VOLT-3 `{energy_power:6}`; When `preview(volt_candidate, 2, parts)`; Then return `energy_power==6`, cache empty, no emit.
- **AC-SYN-13 B**: Given VOLT=3 active (`energy_power==6`), counter=N; When `preview(kinetic_candidate, 0, parts)`; Then return `stat_delta.is_empty()`, cache still 6, counter==N. Edge: return `energy_power==6` (delta-approach — must FAIL).
- **AC-SYN-20 A/B**: Given VOLT=5 (`energy_power==18`), counter=N; When `preview(candidate, -1, parts)` / `preview(candidate, 8, parts)`; Then each no crash, return empty, counter==N, cache still 18, error logged. Edge: negative-wrap / OOB crash.
- **AC-SYN-24**: Given VOLT=3 active (`energy_power==6`), counter=N; When `preview(null, 0, parts)`; Then return empty, cache still 6, counter==N, no error logged. Edge: `null.synergy_tags` crash; null ignored (`energy_power==6`).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/synergy/synergy_preview_test.gd` — must exist and pass. Contributes the epic DoD proof that `preview()` is cache-write-free / emit-free.

**Status**: [x] Created — 6 tests, all passing incl. AC-SYN-13 B delta-shortcut discriminator (full suite 689/689 green, 2026-07-16)

---

## Dependencies

- Depends on: Story 001 (SynergySystem owner + compute pipeline); Story 004 (shared `_compute_block` factoring) if landed first — otherwise `preview()` reuses whatever private compute path exists.
- Unlocks: None
