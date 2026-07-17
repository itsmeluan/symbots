# ADR-0001: Save/Load Architecture & Serialization Format

## Status

Accepted (2026-07-13, via `/architecture-review` follow-up — review report `architecture-review-2026-07-13.md`)

> **Amended 2026-07-17** (implementation groundwork, no status change — the decision stands):
> (1) **Engine re-validated 4.6 → 4.7.** The persistence surface carries **no 4.7
> breaking changes** — `FileAccess.store_*` still returns `bool` (the 4.4 change,
> confirmed current in `docs/engine-reference/godot/breaking-changes.md`), and
> `JSON.stringify`/`JSON.parse_string`/`DirAccess.rename_absolute` are unchanged in 4.7.
> A version bump alone does not warrant a superseding ADR (the "flag as Superseded"
> note below is scoped to *breaking* upgrades; this was a clean re-pin).
> (2) **`drop` provider shape corrected** to match the built DropSystem: it exposes
> **two** part-id-keyed pity maps (`proto_pity_credit`, `break_pity_counter`), not a
> single `pool_id → int` map. The envelope example and Durable-State Manifest row are
> updated accordingly. See SL-6 / Story DS-009.

## Date

2026-07-13

## Last Verified

2026-07-13

## Decision Makers

Luan (solo dev / project owner); Claude Code Game Studios agents (technical-director sign-off pending via architecture.md; godot-specialist engine validation)

## Summary

Symbots needs one unified way to persist all durable game state — part instances, core progression, zone/boss progress, collected world loot, drop pity, workshop builds, and settings — across sessions on macOS and iOS. This ADR generalizes the Exploration Progress domain-envelope pattern to the **whole save file**: a single human-readable JSON file whose top level is a registry of provider domains, each contributing plain-data snapshots, with a file-level version predicate, atomic writes, source-facts-only serialization, and a fixed iOS persistence budget.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (re-validated 2026-07-17; originally authored against 4.6) |
| **Domain** | Core (persistence / serialization) |
| **Knowledge Risk** | HIGH — post-LLM-cutoff (Godot 4.4/4.5 changed serialization APIs; 4.6/4.7 re-checked clean for this surface) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/architecture/architecture.md` (§ System Layer Map, § Data Flow 3, § API Boundaries), `design/gdd/exploration-progress.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_string()` returns `bool` (changed in 4.4 — was `void`; **still `bool` in 4.7**). `JSON.stringify()` / `JSON.parse_string()` (stable; **unchanged in 4.7**). `DirAccess.rename_absolute()` (**unchanged in 4.7**). Deliberately AVOIDS `Resource.duplicate_deep()` / `ResourceSaver`-based save by never serializing live Resources. |
| **Verification Required** | (1) Confirm the full write-failure surface on 4.7: `FileAccess.get_open_error()` after `open()`, the `bool` from `store_string()`, AND `FileAccess.get_error()` after the write — all three must be `OK`/`true` for a write to count as successful (the bool alone misses full-disk / sandbox-denial failures on iOS). (2) ~~Atomicity of rename on iOS~~ — **confirmed** by engine specialist: `DirAccess.rename_absolute()` maps to POSIX `rename(2)`, atomic within a single APFS volume, and both `.tmp` and final live under the same `user://` sandbox container. On-device spot-check still advised. (3) Measure real serialized save size and synchronous write time on a physical iOS device during the vertical slice, against the budget below. |

> **Note**: Knowledge Risk is HIGH. Re-validate this ADR if the project upgrades engine
> versions. The 2026-07-17 4.6 → 4.7 re-pin was re-validated as a **clean, non-breaking**
> change to the persistence surface (see the Status amendment) — no supersession required.
> A *breaking* future upgrade would still warrant flagging as Superseded and writing a new ADR.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (foundational — greenfield) |
| **Enables** | ADR-0002 (Event bus — save triggers fire on event-boundary quiesce points), ADR-0004 (Scene/boot — boot order runs load→restore→rederive before gameplay) |
| **Blocks** | Exploration Progress deferred integration ACs (AC-EP-DEFERRED-A/B); Inventory persistence; any Production coding that touches durable state |
| **Ordering Note** | Must be **Accepted** (not merely Proposed) before implementation of any system that reads or writes durable state. First of the four Foundation ADRs. |

## Context

### Problem Statement

Every persistent system in Symbots currently defines its *own* view of what durable state it owns, but nothing defines how that state actually reaches disk and comes back. Exploration Progress (`design/gdd/exploration-progress.md`, Approved) specifies a **progression blob** with a domain registry, a version predicate (EP-PRED-1), two-phase order-independent restore, and source-vs-derived re-derivation — but it explicitly delegates file format, encoding, timing, slots, and disk I/O to "Save/Load (#17)" (EP Rule 8). No Save/Load design exists yet. Until it does, no persistent system can be implemented, tested end-to-end, or shipped. The cost of not deciding: all of Production is blocked on an undefined persistence contract, and each system risks inventing an incompatible save format.

### Current State

Greenfield. No save system, no ADRs, no code. The only existing persistence contract is Exploration Progress's progression-blob semantics, which this ADR must wrap and honor — never contradict.

### Constraints

- **Engine (Godot 4.7):** `FileAccess.store_*` returns `bool` (must be checked); nested `Resource` serialization is a known footgun (`Resource.duplicate()` is shallow; `duplicate_deep()` exists but is easy to misuse). Knowledge Risk HIGH — verify against engine reference, not training data.
- **Platform (iOS primary):** 512 MB memory ceiling; flash storage with finite write endurance; synchronous file writes on the main thread cause frame hitches; app can be force-quit or crash between saves at any time.
- **Design:** Part instances are **uncapped** (Inventory GDD) — a hoarding player's save grows without a built-in bound.
- **Resource (solo dev):** The system must be debuggable by one person reading the file, and must not require bespoke tooling to inspect a broken save.
- **Compatibility:** Must implement EP Rule 8 exactly — EP owns the progression blob's internals and its own `progress_format_version`; Save/Load owns everything below it.

### Requirements

- Persist and restore a single enumerated manifest of durable state (see Decision → Durable-State Manifest).
- Survive formula retunes: only source facts are stored; all derived values are recomputed on load (shared principle with EP Rule 4).
- Let a new persistent system register a new domain **without a file-format version bump**.
- Refuse (never partially apply) a save file from a newer format version; leave existing in-memory state untouched on refusal (mirrors EP Rule 9 / EP-PRED-1).
- Never silently destroy a save it cannot parse — surface to an error path, keep the bytes.
- Serialized save ≤ **2 MiB**; synchronous write ≤ **50 ms** on target iOS hardware (see Performance Implications).

## Decision

Adopt a **single-file, human-readable JSON save** whose top level is a **provider-domain envelope** — a direct generalization of Exploration Progress's domain registry to the entire save file. Writes are **atomic** (temp-file + rename, with a one-generation backup). The blob contains **plain data only** — no live `Resource` objects ever enter serialization.

### Save envelope format

```jsonc
{
  "save_format_version": 1,          // owned by Save/Load; bump only on a breaking envelope change
  "providers": {
    "progression": { ... },          // the ENTIRE Exploration Progress blob, opaque to Save/Load
                                     //   (carries its own progress_format_version internally)
    "inventory":   { "part_instances": [ {plain dict}, ... ],
                     "next_instance_id": 1234,
                     "scrap": 250,
                     "consumables": { "<id>": <count>, ... } },
    "workshop":    { "builds": [ {plain dict}, ... ] },
    "drop":        { "proto_pity_credit":  { "<part_id>": <int>, ... },
                     "break_pity_counter": { "<part_id>": <int>, ... } },
    "settings":    { ... }
  }
}
```

Two-layer versioning intentionally mirrors EP Rule 8's split:
- **`save_format_version`** (outer) — Save/Load's file envelope version.
- **`progress_format_version`** (inner, inside the `progression` provider) — Exploration Progress's own version, untouched and uninterpreted by Save/Load.

### Provider contract (generalized from EP's domain contract)

Every persistent system registers a **provider** under a stable `StringName` key and implements the same three-operation contract EP domains already use:

```gdscript
func snapshot() -> Dictionary        # pure read → PLAIN DATA ONLY (no Resources), no side effects
func restore(data: Dictionary) -> void   # Phase 1: raw source facts, NO cross-provider reads
func rederive() -> void              # Phase 2: provider-local recompute of derived state
```

The `progression` provider is Exploration Progress itself: its `snapshot()` is `EP.serialize().blob`, its `restore()`/`rederive()` drive EP's own two-phase restore. Save/Load treats that sub-blob as **opaque** — it never reads inside it.

### File-level rules (mirrors EP, applied to the whole file)

1. **Version predicate (SL-PRED-1)** — structurally identical to EP-PRED-1, on `save_format_version`:
   `== CURRENT → RESTORE` · `< CURRENT → MIGRATE` (no hooks at v1 → behaviorally REFUSE) · `> CURRENT → REFUSE`. Missing or non-int key → REFUSE. A REFUSE leaves all in-memory state exactly as before `load()` was called.
2. **Source facts only.** Only irreducible facts are serialized (counters, flags, cumulative XP, collected IDs, part instances, pity, builds, settings). Derived state (zone LOCKED/ACCESSIBLE/CLEARED, core `level`, `final_stat`) is **never** written and **never** trusted from disk — recomputed via each provider's `rederive()`.
3. **Opaque unknown providers.** A provider key in the file with no registered provider (save from a newer build, or a provider removed from this build) is **preserved opaquely** and written back on next save, with a warning. Player history is never destroyed by a build difference. (Deep-copied on hold — never a live reference into the parsed blob.)
4. **Two-phase restore.** Phase 1: every provider restores raw facts, no cross-provider reads. Phase 2: every provider `rederive()`s. Restore outcome is independent of provider registration order.
5. **Atomic write.** Serialize → check byte length < budget → write to `user://<slot>.json.tmp`, verifying the **full failure surface** (`get_open_error()` after open, the `store_string()` bool, and `get_error()` after write) and **calling `flush()` before `close()` (mandatory — `close()` does not guarantee an OS-level flush on iOS)** → on success, rotate current file to `user://<slot>.json.bak` and `rename_absolute()` tmp → final. A failed write leaves the previous save fully intact (tmp is discarded). Every early-return path must `close()` the handle — a leaked open handle to `.tmp` blocks later writes.
6. **Never destroy an unparseable save.** If the primary file fails to parse: attempt `.bak`. If both fail: surface to the player-facing error path (owned with ADR-0002/UI), and **do not overwrite** the bytes. Missing file (not corrupt) → new game.
7. **Injected logger.** All warnings/errors route through an injected sink (never global `push_warning`/`push_error`) — GUT-testable, consistent with EP Rule 3a.3 and the Event Bus principle.
8. **Emergency save (iOS lifecycle).** `save_emergency()` is the API behind ADR-0004's `NOTIFICATION_APPLICATION_PAUSED` mitigation: a synchronous save to the active slot using the identical envelope and atomic-write path (no special format, no shortcuts — a corrupted emergency save would be worse than none). It may only be invoked from the app-lifecycle notification handler on the `Game` root; gameplay code always goes through the normal quiesce-point `save(slot)`. If the OS grants too little time and the write is cut off mid-tmp, the atomic-write design already guarantees the prior save survives.
9. **Accepted risk — force-kill data loss.** If the player force-kills the app (or it crashes) between quiesce-point saves and no lifecycle notification fires, progress since the last completed save is lost. This is **accepted** at MVP: the quiesce-point cadence (event boundaries, ADR-0002) bounds the loss window to roughly one battle/collection action, and no journaling/write-ahead scheme is worth its complexity for a single-player game at this scale.

### Durable-State Manifest (first deliverable — the enumerated contract)

| Provider key | Owner system | Source facts serialized |
|---|---|---|
| `&"progression"` | Exploration Progress (#17-adjacent) | The entire EP blob: `zones` (`win_count`, `boss_progress[]`), `cores` (`CoreProgressionRecord.cumulative_xp`), `world_loot` (collected IDs), plus `progress_format_version` |
| `&"inventory"` | Inventory | `part_instances[]` (plain dicts), `next_instance_id` (monotonic int), `scrap` (int), `consumables` (id→count) |
| `&"workshop"` | Workshop / Assembly | `builds[]` (equipped-part-instance-id references per slot, plain dicts) |
| `&"drop"` | Drop System | Two part-id-keyed pity maps: `proto_pity_credit` (Prototype gradient credit, DS-2) and `break_pity_counter` (Boss-grade break pity, DS-3) — both `String(part_id) → int` |
| `&"settings"` | Settings | Player options (audio, accessibility, input) |

Reserved (not MVP): `&"key_items"` (Vertical Slice, #23a) — will register without a `save_format_version` bump, proving requirement.

### Architecture

```
        ┌──────────────────────────────────────────────────────────┐
        │                     Save/Load (Foundation)                 │
        │   owns: file format, slots, timing, disk I/O, budget       │
        │   SL-PRED-1 version predicate · atomic write · .bak         │
        └───────────────┬───────────────────────────────────────────┘
                        │ registers + pulls snapshot()/restore()/rederive()
        ┌───────────────┴───────────────┬───────────┬────────┬─────────┐
        ▼                               ▼           ▼        ▼         ▼
  progression provider            inventory     workshop    drop    settings
  (= Exploration Progress,        (part          (builds)  (2 pity  (options)
   opaque sub-blob, owns its       instances,               maps)
   OWN progress_format_version)    next_id,
        │                          scrap,
        ▼                          consumables)
  zones · cores · world_loot
  (EP's internal domains)

  DISK:  user://save_slot_<n>.json   (+ .json.bak, transient .json.tmp)
         plain-data JSON, human-readable, no live Resources
```

### Key Interfaces

```gdscript
# Save/Load public API (Foundation autoload)
func save(slot: int) -> Dictionary        # {ok:true} | {ok:false, reason, failed_provider}
func load(slot: int) -> Dictionary        # {ok:true} | {ok:false, reason}  (REFUSE/parse-fail surfaced here)
func register_provider(key: StringName, provider) -> void   # provider: snapshot()/restore()/rederive()
func has_save(slot: int) -> bool

# Provider contract (implemented by inventory, workshop, drop, settings, and
# the progression bridge; identical in shape to EP's domain contract)
func snapshot() -> Dictionary             # plain data only; no side effects
func restore(data: Dictionary) -> void    # Phase 1: raw facts, no cross-provider reads
func rederive() -> void                   # Phase 2: provider-local recompute

# Emergency save (iOS lifecycle — see rule 8 below)
func save_emergency() -> Dictionary       # synchronous save to the active slot; same envelope,
                                          # same atomic write; called ONLY from the app-lifecycle
                                          # notification path, never from gameplay code

# Persistence budget (constants)
const SAVE_FORMAT_VERSION := 1
const MAX_SAVE_BYTES := 2_097_152         # 2 MiB — hard budget asserted before write
const MAX_WRITE_MS := 50                  # target ceiling for the synchronous write (measured on iOS)
```

### Implementation Guidelines

- **Never put a `Resource` in `snapshot()` output.** Each provider flattens to plain `Dictionary`/`Array`/`int`/`float`/`String`/`bool`. This is what neutralizes the Godot 4.6 Resources-serialization HIGH risk — verify no provider returns a Resource.
- **Check the full write-failure surface, not just the bool.** The `store_string()` bool return is necessary but *not sufficient* — on iOS a full-disk or sandbox-denial failure surfaces via the error state, not the bool. A write counts as successful only when all three are clean:

  ```gdscript
  var fa := FileAccess.open(tmp_path, FileAccess.WRITE)
  if fa == null:
      return {ok = false, reason = "open failed: %s" % error_string(FileAccess.get_open_error())}
  var wrote := fa.store_string(json_str)
  var err := fa.get_error()
  fa.flush()          # mandatory before close on iOS
  fa.close()          # MUST also run on every early-return path below
  if not wrote or err != OK:
      return {ok = false, reason = "write failed: %s" % error_string(err)}   # tmp discarded, prior save intact
  ```
- **Emit pretty-printed JSON:** `JSON.stringify(envelope, "\t")` — the tab-indent argument is required for the "human-readable" goal; without it `stringify` returns a single unbroken line.
- **Cast numeric fields back to `int` on restore.** Godot's JSON parser returns *every* number as `float`. `next_instance_id`, `scrap`, pity counters, and `cumulative_xp` must be `int(...)`-cast in each provider's `restore()` or a monotonic-ID / counter bug results. The round-trip test asserts *types*, not just values.
- **Budget guard must fire in Release builds.** `assert()` is stripped from Release exports — an assert-only budget check would not exist for real players. Use an explicit conditional; keep an `assert` only as a redundant dev-build tripwire:

  ```gdscript
  var json_str := JSON.stringify(envelope, "\t")
  if json_str.to_utf8_buffer().size() >= MAX_SAVE_BYTES:
      return {ok = false, reason = "budget_exceeded"}   # fires in Release too
  ```
  Log `part_instances` count as telemetry every save (the growth watch — see QQ-04).
  Note: `to_utf8_buffer()` allocates the full byte buffer just to measure it — fine once per save at the 2 MiB budget, but never call it per-frame or in a loop.
- **No part-instance cap at MVP.** Watch via telemetry; revisit only if real saves approach the budget.
- **Save timing is not decided here** — Save/Load only exposes `save(slot)`. *When* it fires (event-boundary quiesce points) is resolved with ADR-0002 and EP OQ-EP-2. This ADR guarantees only that whatever reaches `save()` round-trips correctly.

## Alternatives Considered

### Alternative 1: Godot binary `var_to_bytes` / `bytes_to_var`

- **Description**: Serialize the envelope with Godot's native binary variant encoding.
- **Pros**: Compact on disk; fast to encode/decode; no manual schema.
- **Cons**: Opaque — a broken save is undebuggable without bespoke tooling; brittle across any schema change; encourages embedding live `Resource` objects (walking straight into the 4.6 shallow-`duplicate`/`duplicate_deep` footgun); a solo dev loses the ability to eyeball a save.
- **Estimated Effort**: Similar to chosen.
- **Rejection Reason**: For a game that will retune formulas and add systems constantly, debuggability and format-change resilience outweigh file-size savings — and MVP data is far under any size where binary compactness would matter.

### Alternative 2: `.tres` / `ResourceSaver` (Godot Resource serialization)

- **Description**: Model save state as `Resource` classes and persist with `ResourceSaver.save()` / `load()`.
- **Pros**: Native Godot idiom; typed; editor-inspectable as resources.
- **Cons**: Directly exposes the HIGH-risk 4.4/4.5 serialization changes (shallow `Resource.duplicate()`, `duplicate_deep()` for nesting); nested part-instance resources are exactly the case that misbehaves; couples on-disk format to in-memory class layout, so a class refactor risks breaking every existing save; harder to apply the source-facts-only + opaque-unknown-key rules.
- **Estimated Effort**: Higher (resource class design + migration discipline).
- **Rejection Reason**: Couples save format to code structure and lands squarely in the engine's highest-risk serialization surface — the opposite of "saves survive retunes."

### Alternative 3: Flat JSON (no provider envelope)

- **Description**: One flat JSON object, all fields at top level, no domain/provider structure or version predicate.
- **Pros**: Simplest possible to write initially.
- **Cons**: No version predicate → every schema change risks a whole-file break; no per-system ownership → systems collide in one namespace; no opaque-unknown-key preservation → a build difference silently drops data; contradicts the already-Approved EP envelope pattern, forcing two incompatible models in one file.
- **Estimated Effort**: Lowest short-term, highest long-term.
- **Rejection Reason**: Throws away every resilience property EP already specified; guarantees painful format churn.

## Consequences

### Positive

- One coherent, debuggable, human-readable save format across every system; a broken save can be inspected in any text editor.
- Directly reuses the Approved EP contract (version predicate, two-phase restore, source-vs-derived, opaque unknown keys) — one mental model, not two.
- New persistent systems slot in as new providers **without a format-version bump** (proven by the reserved `key_items` domain).
- **Neutralizes the Godot 4.6 Resources-serialization HIGH risk** by never serializing a live Resource — the only residual engine touch-point is checking `store_string()`'s bool return.
- Saves survive formula retunes (source facts only) and build differences (opaque unknown providers).
- Atomic write + `.bak` makes mid-write crashes non-destructive.

### Negative

- JSON is larger and slower than binary (accepted — MVP data is far under budget; the 2 MiB ceiling has generous headroom).
- Manual `snapshot()`/`restore()` per provider is boilerplate each system must implement (accepted — it is the testability seam).
- Part instances remain uncapped; a pathological hoarder could grow the save toward the budget (mitigated by telemetry watch; hard decision deferred to QQ-04 with data).

### Neutral

- Two-layer versioning (`save_format_version` + inner `progress_format_version`) — more moving parts, but a faithful expression of the EP Rule 8 ownership split.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| iOS write failure (full disk / sandbox denial) undetected by the bool alone | Medium | High | Check `get_open_error()` + `get_error()` in addition to the bool (Impl guideline); smoke test that forces each failure mode |
| JSON round-trip turns int fields into float (`next_instance_id`, pity, `cumulative_xp`) | High if unguarded | High | Explicit `int(...)` cast in every provider `restore()`; round-trip test asserts GDScript types, not just values |
| `assert`-based budget guard stripped in Release → oversized saves ship | Medium | Medium | Budget check is an explicit `if` returning `budget_exceeded` (fires in Release); `assert` only a dev tripwire |
| Leaked `FileAccess` handle on an early-return path blocks later writes | Medium | Medium | Every early return in the write routine closes the handle (Impl guideline); no `using`/RAII in GDScript |
| Synchronous save exceeds 50 ms on old iOS hardware → frame hitch | Medium | Medium | Measure on device (Verification item 3); if breached, thread the serialize+write (snapshot must stay on main thread) or defer to a quiesce frame (ADR-0002 timing) |
| Uncapped part instances grow save past 2 MiB | Low (MVP) | Medium | Explicit budget guard rejects the write; telemetry logs instance count; QQ-04 revisit with real numbers |
| `DirAccess.rename_absolute()` non-atomic | Low | High | Specialist-confirmed atomic within a single APFS `user://` volume (POSIX `rename(2)`); on-device spot-check only |
| A provider accidentally returns a live Resource | Medium | High | Implementation guideline + a unit test asserting every provider snapshot is JSON-round-trippable |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (save write, main thread) | n/a | < 50 ms synchronous (measure on iOS) | 50 ms (`MAX_WRITE_MS`) |
| Memory (serialized blob) | n/a | ≪ 2 MiB at MVP data volumes | 2 MiB (`MAX_SAVE_BYTES`) |
| Load Time (parse + restore + rederive) | n/a | < 100 ms at MVP volumes | folds into boot budget (ADR-0004) |
| Network | n/a | N/A (fully local) | — |

## Migration Plan

Greenfield — no existing saves to migrate. The migration *machinery* (SL-PRED-1 MIGRATE branch + per-provider migrate hooks) is specified now but carries **zero hooks at v1**, so every `save_format_version < 1` blob is behaviorally REFUSE until the first real format break registers a hook. This mirrors EP Rule 9 exactly.

**Rollback plan**: If JSON proves unworkable, the provider contract is format-agnostic — only the encode/decode + file-I/O layer changes; providers' `snapshot()/restore()/rederive()` are untouched. A superseding ADR would swap the serializer without touching any system's persistence logic.

## Validation Criteria

- [ ] A full envelope survives `save(slot)` → `load(slot)` round-trip with all provider source facts identical and all derived state recomputed (not read from disk).
- [ ] `save_format_version` predicate: v1→RESTORE, v0→REFUSE (no hook), v2→REFUSE, missing/non-int→REFUSE; a REFUSE leaves in-memory state untouched (call-count spy confirms no provider `restore()` fired).
- [ ] A forced write failure — via each of open-error, `store_string` bool `false`, and post-write `get_error()` — aborts the write and leaves the previous save fully intact; no `FileAccess` handle is leaked on any early-return path.
- [ ] An unregistered provider key round-trips opaquely (present, identical, on next save).
- [ ] Every provider's `snapshot()` output is pure plain data and survives a JSON round-trip with correct GDScript **types** — `int` source facts (`next_instance_id`, `scrap`, pity, `cumulative_xp`) remain `int` after restore, not `float`.
- [ ] The oversized-save budget guard rejects the write in a **Release** export build (not only under `assert`).
- [ ] Measured save size and write time on a physical iOS device are within budget.
- [ ] Reserved `key_items` provider registers and persists without changing `save_format_version`.
- [ ] `save_emergency()` produces a file indistinguishable from a normal `save(slot)` (same envelope, loadable by SL-PRED-1), and an interrupted emergency write leaves the prior save intact.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/exploration-progress.md` | Exploration Progress | Rule 8 — Save/Load owns file format, encoding, timing, slots, disk I/O; must implement the progression-blob hand-off | `progression` provider wraps EP's blob opaquely; file-level rules mirror EP-PRED-1/Rule 9; activates AC-EP-DEFERRED-A/B |
| `design/gdd/exploration-progress.md` | Exploration Progress | Rule 4 / source-vs-derived; Rule 9 REFUSE guarantee | File-level source-facts-only + SL-PRED-1 REFUSE-leaves-state-untouched |
| `design/gdd/inventory.md` | Inventory | Persist `part_instances`, `next_instance_id` (monotonic), `scrap`, `consumables` | `inventory` provider in the manifest; plain-dict part instances |
| `design/gdd/symbot-core-progression.md` | Core Progression | Persist `CoreProgressionRecord.cumulative_xp`; re-derive `level` on load | Carried inside the `progression` provider (EP `cores` domain); level re-derived via CP-F1 in Phase 2 |
| `design/gdd/zone-world-map.md` | Zone & World Map | Persist `win_count`/`boss_progress`; re-derive zone state | Carried inside `progression` (EP `zones` domain); ZWM-F2 re-derive in Phase 2 |
| `design/gdd/world-loot.md` | World Loot | Persist collected `loot_id` set | Carried inside `progression` (EP `world_loot` domain) |
| `design/gdd/drop-system.md` | Drop System | Persist pity counters across sessions | `drop` provider in the manifest |
| `.claude/docs/technical-preferences.md` | Performance | iOS 512 MB ceiling; 60 fps / 16.6 ms frame budget | 2 MiB blob + 50 ms write budget; atomic write off the critical hitch path (timing finalized ADR-0002) |

## Related

- `docs/architecture/architecture.md` — § System Layer Map, § Data Flow 3 (save/load path), § API Boundaries, Required ADR-0001, QQ-01/QQ-04
- `design/gdd/exploration-progress.md` — the domain-envelope pattern this ADR generalizes (EP-PRED-1, Rule 8, Rule 9)
- ADR-0002 (Event bus) — save-trigger timing / quiesce points (to be written)
- ADR-0004 (Scene/boot) — boot order: load → restore → rederive before gameplay (to be written)
