# Story 003: Effect dedup & alphabetical tier-ID ordering (SYN-F3 effects)

> **Epic**: Synergy System
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/synergy-system.md`
**Requirement**: `TR-syn-005`, `TR-syn-006`, `TR-syn-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: The pure formula core produces a deterministic bonus block. Determinism of effect ordering is a hard contract — DCO-7 consumers diff the emitted lists, so ordering must be data-order-independent.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: **StringName intern trap** (flagged in ADR-0008): sorting raw `StringName` tier IDs can sort by intern/pointer identity rather than lexicographically. Sort keys MUST be `String(tier_id)`, not the bare `StringName`. This is the load-bearing determinism rule.

**Control Manifest Rules (this layer — Core)**:
- Required: pure formula core; deterministic output independent of content-file order.
- Forbidden: iterating tiers in content-file/registration insertion order for the effect flatten; owning effect-registry knowledge (no known-effects filtering).
- Guardrail: synchronous, testable.

---

## Acceptance Criteria

*From GDD `design/gdd/synergy-system.md`, scoped to this story:*

- [ ] **AC-SYN-05** — Effect ID deduplication: VOLT-3 `{effects:[volt_test]}`, VOLT-5 `{effects:[volt_test]}` (same ID both tiers), VOLT=5 → `effects.size() == 1` AND `effects[0] == volt_test`. FAIL if size 2 (double-trigger risk in TBC).
- [ ] **AC-SYN-05b** — Keep-first dedup follows **alphabetical tier order, not content-file order** (the DoD gate): content authored VOLT-tier FIRST, ironclad-tier SECOND (reverse-alphabetical file order); Ironclad-3 `{effects:[shared_test, ironclad_unique]}`, VOLT-3 `{effects:[shared_test, volt_unique]}`, NO combined tier; ironclad=3, VOLT=3 → `effects == [shared_test, ironclad_unique, volt_unique]` (strict ordered) AND `active_synergies.size() == 2`. FAIL if `[shared_test, volt_unique, ironclad_unique]` (content-file order used).
- [ ] **AC-SYN-12** — `active_synergies` list is exact: VOLT=5, tiers `volt_3_piece` + `volt_5_piece` → received `active_synergies == [volt_3_piece, volt_5_piece]` (strict **ordered** equality). FAIL on any spurious/missing ID, or `[volt_5_piece, volt_3_piece]` (wrong order).
- [ ] **AC-SYN-16** — Combined unique effect preserved, not over-deduplicated (inverse of AC-SYN-05): Ironclad-3 `{effects:[ironclad_test]}`, VOLT-3 `{effects:[volt_test]}`, Ironclad-VOLT-3 `{effects:[combined_test]}`, ironclad=3/VOLT=3 → `effects.size() == 3` containing all three IDs. FAIL if size 2 (combined dropped) or <2.
- [ ] **AC-SYN-26** — Unregistered effect IDs pass through unfiltered (EC-SYN-05): VOLT-3 `{effects:[unregistered_test_effect]}`, VOLT=3 → `effects == [unregistered_test_effect]` (emitted transparently; no known-effects filtering — skip-and-log is TBC's job). FAIL if empty or crash.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines and GDD Formula SYN-F3 / Rule 3:*

- **SYN-F3 (effect flatten + dedup)**: iterate active tiers in **ascending alphabetical order by `String(tier_id)`** — sort a copy of `active_synergies` with a comparator on `String(a) < String(b)`, **never** trust registry insertion or content-file order (TR-syn-006). This same sorted order defines the `active_synergies` list emitted in the payload (TR-syn-012 / AC-SYN-12 strict ordering).
- Flatten each active tier's `effects` in that order into one list, then **keep-first dedup**: append an effect ID only if not already present (TR-syn-005). The first tier (alphabetically) that names a shared ID "owns" it. A unique combined-tier effect (AC-SYN-16) is preserved because dedup only drops *repeats*, never uniques.
- **No effect filtering**: pass every ID through verbatim, including IDs registered in no TBC registry (TR-syn-014 / AC-SYN-26). The Synergy System must not own effect-registry knowledge — skip-and-log on unknown IDs is TBC's responsibility.
- The `String(tier_id)` sort is the **DoD discriminator**: AC-SYN-05b authors the content file in reverse-alphabetical order specifically so a content-file-order implementation produces `[shared_test, volt_unique, ironclad_unique]` and fails, while the spec order produces `[shared_test, ironclad_unique, volt_unique]`. Do not use a bare `StringName` sort — it can sort by intern identity and silently pass/fail nondeterministically across runs.
- AC-SYN-05b's fixture MUST register no Ironclad-VOLT combined tier (ironclad=3, VOLT=3 would activate it and contaminate the strict-equality assertion).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: counting, activation, evaluate() + signal, tier guards.
- **Story 002**: `stat_delta` aggregation.
- **Story 004 / 005**: silent path / preview.
- **Consumer-owned**: TBC's known-effects registry / skip-and-log on unregistered IDs — this story only emits them transparently.

---

## QA Test Cases

*Embedded from the GDD's AC fixtures. Implement against these.*

- **AC-SYN-05**: Given VOLT-3 & VOLT-5 both `{effects:[volt_test]}`, VOLT=5; When `evaluate`; Then `effects.size()==1`, `effects[0]==volt_test`. Edge: FAIL size 2.
- **AC-SYN-05b**: Given content authored VOLT-first/ironclad-second, Ironclad-3 `{effects:[shared_test,ironclad_unique]}`, VOLT-3 `{effects:[shared_test,volt_unique]}`, no combined tier, ironclad=3/VOLT=3; When `evaluate`; Then `effects==[shared_test,ironclad_unique,volt_unique]` (strict) AND `active_synergies.size()==2`. Edge: content-file-order → `[shared_test,volt_unique,ironclad_unique]` (must FAIL); size 4 (no dedup); over-dedup.
- **AC-SYN-12**: Given VOLT=5, `volt_3_piece`+`volt_5_piece`; Then `active_synergies==[volt_3_piece,volt_5_piece]` (strict ordered). Edge: wrong order `[volt_5_piece,volt_3_piece]`; spurious/missing ID.
- **AC-SYN-16**: Given Ironclad-3 `{effects:[ironclad_test]}`, VOLT-3 `{effects:[volt_test]}`, Ironclad-VOLT-3 `{effects:[combined_test]}`, ironclad=3/VOLT=3; Then `effects.size()==3` with all three. Edge: size 2 (combined dropped).
- **AC-SYN-26**: Given VOLT-3 `{effects:[unregistered_test_effect]}`, VOLT=3; Then `effects==[unregistered_test_effect]`. Edge: empty (defensive filter) or crash.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/synergy/synergy_effect_dedup_order_test.gd` — must exist and pass. Carries the epic DoD gate (AC-SYN-05b: the `String(tier_id)` sort discriminator).

**Status**: [x] Created — 5 tests, all passing incl. AC-SYN-05b DoD gate (full suite 689/689 green, 2026-07-16)

---

## Dependencies

- Depends on: Story 001 (SynergySystem owner, activation, evaluate())
- Unlocks: None
