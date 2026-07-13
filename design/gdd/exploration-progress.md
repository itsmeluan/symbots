# Exploration Progress System

> **Status**: Approved (2026-07-13, round-2 confirmation /design-review)
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-13
> **Implements Pillar**: Pillar 5 (The World Is a Workshop), Discovery aesthetic (MDA #3)

## Overview

The Exploration Progress System is the game's **progression memory**: the single system that records what the player has accomplished in the world and guarantees it survives across sessions. It owns the persistent ledgers that other systems write at runtime and read on load — each zone's cumulative WILD `win_count` and per-boss `boss_progress` (from Zone & World Map's runtime state), every core's `CoreProgressionRecord` (cumulative XP, from Symbot Core Progression), and the collected-state ledger for overworld pickups (for the World Loot System). It is a **persistence contract layer, not a runtime authority**: Zone & World Map mutates zone state during play, Core Progression awards XP, World Loot opens chests — this system defines what of that state is durable, how it round-trips through a save, and the re-derivation rules applied on load (zone LOCKED/ACCESSIBLE/CLEARED states and core levels are always recomputed from their source counters, never trusted from disk). The player never sees this system directly; they feel its effect every time they return to the game and the world remembers — the cleared zone stays cleared, the boss gate stays open, the chest they emptied stays empty. Downstream, the Save/Load System (#17) serializes what this system exposes; the World Map UI renders the progress it tracks. Without it, every session would be a fresh world and nothing the player did would matter.

## Player Fantasy

This system delivers no moment-to-moment fantasy of its own — it is the quiet guarantee underneath everyone else's. The player experience it protects is **"my history in this world is real."**

**The return.** The anchor moment is not during play — it is *coming back*. The player opens the game after three days away: the map shows the zone they cleared, the boss gate they ground six WILD wins to open is still open, the core they leveled to 5 is still level 5, and the chest behind the pylon field is still empty *because they emptied it*. Every one of those facts is this system keeping a promise. In a game whose pillars are built on investment — parts hunted, builds engineered, cores leveled — the fantasy being protected is that **investment is permanent**. Pokémon players never wonder whether their badges will still be there tomorrow; that certainty is invisible until the one time a game breaks it. One honest qualification: this permanence is only as strong as how often the game actually saves — the single contingency this system cannot itself guarantee; Save/Load (#17) owns save-trigger granularity (see OQ-EP-2).

**The anti-fantasy (what failure looks like).** A single lost `win_count` reads as "the game stole my grind." A boss re-locking after its gate was earned reads as betrayal, not challenge. A re-appeared chest the player already looted breaks world-solidity — the world stops being a place and becomes scenery. These failures are worse than a crash: a crash loses minutes, a progression bug loses *trust*. This is why the system's core principle (re-derive from source counters, never trust the serialized snapshot) exists — it can drop a derived label and recompute it, but it must never lose a source counter.

**What this system must never become:** a completion checklist. The ledger exists so the *world* remembers — not to surface "12/14 chests found" percentages that turn Discovery (MDA #3) into box-ticking. Whether any completion readout is ever shown is a World Map UI decision (post-MVP at earliest); this system merely stores facts. *(Anti-pillar guard: "no gotta-collect-them-all" — Inventory GDD carries the same note.)*

> *(Note: creative-director not consulted — Lean mode. Review Section B manually before production.)*

## Detailed Rules

### Core Rules

**Rule 1 — Progression domain model.** Exploration Progress is a **registry of progression domains**. A domain is a runtime system that owns progression state and registers under a stable `StringName` domain key. MVP registers exactly three:

| Domain key | Runtime owner | Source facts persisted |
|---|---|---|
| `&"zones"` | Zone & World Map | Per zone: `win_count`, `boss_progress[]` (`boss_id`, `defeated_once`, `wins_at_last_defeat`) |
| `&"cores"` | Symbot Core Progression | Per `core_instance_id`: `cumulative_xp` (the `CoreProgressionRecord`) |
| `&"world_loot"` | World Loot System *(Authored — contract implemented, #13 Approved 2026-07-13)* | Flat `Set[StringName]` of collected `loot_id`s. **Serialized form (Godot 4.6 has no native Set):** runtime form is `Dictionary[StringName, bool]` (the Godot set idiom); `snapshot()` returns `{ "collected": <sorted Array[StringName]> }` — a **Dictionary** per this system's Rule 3 type contract (a bare Array would be refused by Rule 3 / EC-EP-10), whose `collected` value is sorted via **String-cast comparison** (`sort_custom` on `String(a) < String(b)`; raw `StringName` `operator<` compares session-unstable intern indices and is forbidden — a raw sort produces non-deterministic output); `restore(data)` reads `data.get("collected", [])` and dedupes on Set reconstruction. *(See world-loot.md Rule 7 / WL-PRED-3.)* |

Reserved, not MVP: `&"key_items"` (#23a, Vertical Slice). Domain keys are **save-format-stable — never rename one**. Registration must assert at startup that no two domains register the same key — a key collision is a save-corruption class of bug.

**Rule 2 — Runtime ownership stays with the domain (pull model).** This system holds **no runtime progression state**. All runtime mutation happens in the owner: ZWM increments `win_count` and snapshots `wins_at_last_defeat` per its Rules 7/8 — **this rule normatively resolves the Encounter Zone Rule 8a wording conflict in ZWM's favor** (EZ erratum: reword "Exploration Progress must implement its increment hook" → "ZWM implements the increment; Exploration Progress persists the counter"). At serialize time this system *pulls* a snapshot from each domain. **Exception (the one piece of state this system holds):** the opaque store of unknown domain keys (Rule 7) is held in session memory between restore and serialize — undecoded, source-fact-adjacent, never interpreted.

**Rule 3 — Domain contract.** Each registered domain implements three operations: `snapshot() → Dictionary` (pure read, no side effects, cheap — called on every save), `restore(data: Dictionary)` (Phase 1 of Rule 5), and `rederive()` (Phase 2). This system composes them: **serialize** = `{ domain_key: snapshot() }` for every registered domain, plus `progress_format_version: int`; **restore** = the two-phase pass of Rule 5. **Replacement semantics:** a domain's `restore()` unconditionally **replaces** all previously held source facts with the blob's contents — never merges (EC-EP-08). **Serialize-side validation and result contract:** `serialize()` returns a structured result, not a bare blob — on success `{ok: true, blob: Dictionary}`; if any domain's `snapshot()` returns a non-Dictionary, the save is **refused** and the result is `{ok: false, failed_domain: StringName, error: String}` naming the offending domain and the bad type. A bad snapshot blocks the save rather than silently corrupting it, and the failure is asserted on the **returned result**, never on log output (log output is not GUT-capturable — Rule 3a.3).

**Rule 3a — Testability sub-contract (hard interface requirements — the ACs cannot be written without these; lead programmer must design them in before any domain code exists).**

1. **Injectable cross-domain accessor.** A domain never holds a direct reference to another domain. All cross-domain access goes through an accessor object injected at domain registration (production: the real registry; tests: a recording spy). **Definition — "cross-domain read":** any method call on another registered domain instance obtained through the accessor (reading another domain class's *constants* is not a cross-domain read — only instance calls are). This seam is what makes Rule 5's Phase-1 isolation guarantee structurally testable (AC-EP-14).
2. **Record-level restore path for keyed-collection domains.** A domain whose sub-blob is a keyed collection (the cores domain: records keyed by `core_instance_id`) must implement its `restore(data: Dictionary)` by normalizing the sub-blob to an **ordered Array-of-records** and delegating to a public inner method `restore_records(records: Array)`. Both methods are part of the domain contract. Rationale: GDScript Dictionaries cannot carry duplicate keys, so duplicate-ID corruption (Rule 6e first-wins) is only reachable — and only testable — at the record level; AC-EP-08B injects its duplicate-ID fixture via `restore_records()` directly. Order within the Array defines "first occurrence".
3. **Injectable warning/error sink.** Godot 4's `push_error()`/`push_warning()` output cannot be captured by GUT (no signal, no return value, no `get_pushed_errors()`). Every corruption warning this GDD mandates (Rule 6d/e, Rule 7) and every serialize failure is therefore emitted through an injectable reporting interface (production: forwards to `push_warning`/`push_error`; tests: a recording sink exposing message count and content). Every AC that asserts a warning's presence, absence, count, or content (AC-EP-05..09, AC-EP-12) is written against this seam.

**Rule 4 — Source facts only (source-vs-derived).** Only **source facts** are durable: win counters, boss flags + snapshots, cumulative XP, collected loot IDs. **Derived state is never trusted from disk**: zone LOCKED/ACCESSIBLE/CLEARED is re-derived via ZWM-F2 (EC-ZWM-10); core `level` is re-derived via CP-F1 from `cumulative_xp` (EC-CP-06). A serialized derived field, if present, is ignored on load.

**Rule 5 — Two-phase restore (order-independence guarantee).** Phase 1: every domain restores its raw source facts from its sub-blob; **a domain must not read another domain during Phase 1**. Phase 2: every domain runs `rederive()`. Because Phase 1 is cross-domain-read-free and Phase 2 re-derivations are domain-local, restore outcome is independent of domain registration order.

**Rule 6 — Drift tolerance (contract-mandated, domain-implemented).** On restore each domain must handle, without crashing: **(a) missing sub-blob** (new save, or domain added post-release) → new-game defaults, no error; **(b) missing entry** (content exists, no save data — e.g. a boss added in a patch) → per-entry defaults (`defeated_once = false`, `wins_at_last_defeat = 0`); **(c) orphaned entry** (save references content that no longer resolves) → **preserve-and-warn, never drop**: an orphaned collected `loot_id` or an orphaned `CoreProgressionRecord` is retained and written back on next save (losing a collected/earned fact is the anti-fantasy; keeping an orphan costs bytes). *Exception:* orphaned `boss_progress` entries follow the Approved EC-ZWM-10 rule (ignored on load) — that contract predates this GDD and stands. Additionally: **(d) present-but-wrong-type sub-blob** (e.g. `{"world_loot": 42}`) → treated as missing: the domain receives `restore({})` (new-game defaults) and a corruption warning is logged; **(e) invalid present values (corruption pass, run during Phase 1 before data reaches the domain):** `win_count < 0` → clamp to 0, then re-check dependent invariants; `wins_at_last_defeat > win_count` → clamp to **0** (yields re-gate delta = `win_count` — earned re-gate access always survives corruption; the accepted trade-off is over-credit: a corrupted entry may open a re-gate slightly early, but corruption never silently revokes access the player already earned; see EP-INV-1) + warning; `cumulative_xp < 0` → clamp to 0 + warning; duplicate `core_instance_id` in the cores sub-blob → **first occurrence wins** (parallel to ZWM EC-ZWM-09) + warning; duplicate loot IDs → deduped by Set reconstruction + warning. **Clamp ordering (normative):** within a single zone entry's corruption pass, clamps apply in sequence — (1) `win_count` negative-clamp, (2) EP-INV-1 — each step evaluating against the previous step's output; simultaneous or reversed evaluation can let `wins_at_last_defeat` survive against a post-clamp `win_count` (the cascade AC-EP-06 tests).

**Rule 7 — Unknown domain keys preserved.** A save containing a domain key with no registered domain (a domain removed from the build, or a save from a newer build) → the sub-blob is **preserved opaquely** and written back on next save, with a warning. Player history is never destroyed by a build difference.

**Rule 8 — The Exploration Progress ↔ Save/Load split (provisional until #17).** This system produces and consumes the **progression blob** (one Dictionary). Save/Load owns everything below it: file format/encoding, save timing and triggers, slots, disk I/O, file-level corruption handling — and directly serializes the *non-progression* state contracted to it elsewhere (Inventory including `next_instance_id` + Scrap, Workshop builds, Drop System pity maps, Settings). Those do not pass through this system. **Save-timing contingency:** the Player Fantasy this system protects is only as strong as Save/Load's save-trigger granularity — see OQ-EP-2.

**Rule 9 — Format version.** The blob carries `progress_format_version = 1`. On load: same version → restore; older → **MIGRATE** (classification only — behavior defined next); newer → refuse the blob and surface to Save/Load's error path (never partially restore a future format). **MIGRATE behavior (normative):** MIGRATE invokes each domain's per-domain migrate hook (reserved — none exist at v1). **A MIGRATE-classified blob with no registered hook for its version delta is REFUSED** under the full REFUSE guarantee below — MIGRATE never invents behavior, never falls through to RESTORE, and never silently discards source facts. At v1 this makes every MIGRATE-classified blob (any `saved_version < 1`) behaviorally a REFUSE. **A missing or non-int `progress_format_version` key → REFUSE** (unknown format — never guess a version). **REFUSE guarantee (covers REFUSE and any MIGRATE that cannot complete, including a mid-migration hook failure):** a refused blob leaves all domain in-memory state unchanged from before `restore()` was called — no domain receives any data, no partial restore, ever.

### States and Transitions

This system has no runtime states — it acts at exactly two moments in the game lifecycle: **serialize** (pull snapshots, compose blob, hand to Save/Load) and **restore** (receive blob, Phase 1 restore, Phase 2 re-derive). Between those moments it is inert; all progression state lives in and mutates within its domain owners.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Zone & World Map** (Approved) | domain (`&"zones"`) | Pulls `ZoneRuntimeState` snapshots; restore + ZWM-F2 re-derivation per EC-ZWM-10. ZWM stays runtime authority. |
| **Symbot Core Progression** (Approved) | domain (`&"cores"`) | Pulls `CoreProgressionRecord`s; level re-derived via CP-F1 on restore (EC-CP-06). |
| **World Loot** (#13, Approved 2026-07-13) | domain (`&"world_loot"`) | WL owns the runtime collected set + globally-unique `loot_id` content validation; implements the Rule 3 contract (snapshot returns `{"collected": [...]}`). Contract satisfied — see world-loot.md Rule 7. |
| **Encounter Zone** (Approved) | indirect | EZ never reads this system — its gate-check receives `win_count`/`boss_progress` from ZWM (ZWM Rule 8). This system's shipping completes the persistence chain, activating deferred **AC-EZ-40b** and **AC-EZ-55**. **EZ erratum applied 2026-07-13**: Rule 8a hook wording (see Rule 2). |
| **Save/Load** (#17, Not Started) | downstream | Receives/supplies the progression blob (Rule 8 split). |
| **World Map UI** (#20, Not Started) | none at runtime | Under the pull model this system has nothing to query at runtime — the UI reads ZWM's live state directly. The systems index row "World Map UI depends on Exploration Progress" resolves in practice to ZWM; noted for the index. |
| **Key Item System** (#23a, Vertical Slice) | reserved domain | `&"key_items"` key reserved; contract defined when #23a is authored. |

## Formulas

This system owns **no formulas** in the project's strict sense — no numeric output derived from numeric input. It owns two specification-grade predicates and a set of re-derivation obligations, documented here so this section is a contract rather than a gap.

### EP-PRED-1 — Version Compatibility Predicate

```
result =
  if saved_version == CURRENT_FORMAT_VERSION: RESTORE
  elif saved_version < CURRENT_FORMAT_VERSION: MIGRATE   # classification only — with no registered hook (v1) behavior is REFUSE (Rule 9)
  else:                                        REFUSE    # newer format — surface to Save/Load error path
  # a missing or non-int version key → REFUSE (checked before this predicate runs)
```

**Variables:**

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `saved_version` | int | [1, ∞) | `progress_format_version` read from the blob |
| `CURRENT_FORMAT_VERSION` | int | 1 (MVP) | The format version this build expects |
| `result` | enum | {RESTORE, MIGRATE, REFUSE} | The action taken |

**Worked examples:** saved=1 / current=1 → RESTORE · saved=0 → classified MIGRATE; no hook at v1 → behaviorally REFUSE (Rule 9) · saved=2 → REFUSE · key missing → REFUSE.
**Output range:** one of three discrete actions. Pure integer comparison — **no floor/ceil/float; scan-exempt** (stated explicitly per project convention).

### EP-INV-1 — Boss-Progress Well-Formedness Invariant (validated on restore)

```
valid = (win_count >= 0) AND (wins_at_last_defeat >= 0) AND (wins_at_last_defeat <= win_count)
```

**Variables:**

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `win_count` | int | [0, ∞) | Cumulative WILD wins for the zone (ZWM Rule 7) |
| `wins_at_last_defeat` | int | [0, win_count] | Per-boss snapshot of `win_count` at defeat (EZ Rule 9) |
| `valid` | bool | — | Whether the restored entry is internally consistent |

**On violation:** clamp `wins_at_last_defeat = 0` per Rule 6(e), log a corruption warning, continue restore. **Rationale (error-direction decision, 2026-07-13 review):** a `wins_at_last_defeat > win_count` entry would feed a **negative delta** into Encounter Zone's LIGHTER_REGATE check (`win_count − wins_at_last_defeat >= regate_params.required_wins`), which is unspecified for negatives. Two recovery directions exist: clamping *up* to `win_count` (delta = 0) silently **revokes a re-gate the player may already have earned** — the exact anti-fantasy Section B names ("a boss re-locking after its gate was earned reads as betrayal") — while clamping *down* to 0 (delta = `win_count`) guarantees earned access always survives, at the cost of possibly **over-crediting**: a corrupted entry may satisfy the re-gate delta slightly early. This GDD chooses over-credit — corruption must never destroy earned progress; a rare unearned re-gate is the cheaper failure. (A third option, clamping to `win_count − required_wins`, is exact but couples this corruption pass to Encounter Zone tuning config — rejected to keep the pull model dependency-free.) Never pass invalid values into ZWM. Pure integer comparison — **scan-exempt.**

### Re-Derivation Obligations (formulas owned elsewhere — this system triggers, never computes)

| Derived fact | Formula owner | This system's obligation |
|---|---|---|
| Zone LOCKED/ACCESSIBLE/CLEARED | ZWM-F2 (zone-world-map.md) | Trigger `rederive()` on the `&"zones"` domain in Phase 2 |
| Core `level` | CP-F1 (symbot-core-progression.md) | Trigger `rederive()` on the `&"cores"` domain in Phase 2 |
| Re-gate delta `win_count − wins_at_last_defeat` | Encounter Zone Rule 9 | Guarantee EP-INV-1 holds before any Phase 2 runs |

The `world_loot` Set operations (membership test, idempotent insert) are pure set logic — no arithmetic, **scan-exempt**. `cumulative_xp` above `threshold[10] = 2080` needs no clamp here: CP-F1's table lookup semantically caps at level 10 (EC-CP-01, owned by Core Progression).

## Edge Cases

**EC-EP-01 — Blob is not a Dictionary.** *If* `restore()` receives null, an Array, a String, or any non-Dictionary: the entire blob is **refused** — hard error to Save/Load's error path, no partial restore, every domain keeps its prior in-memory state. This check runs *before* the version key is read. *Verified by AC-EP-04.*

**EC-EP-02 — `progress_format_version` missing or non-int.** *If* the blob is a Dictionary but the version key is absent or not an int: **REFUSE** (Rule 9) — unknown format, never guess. *Verified by AC-EP-02.*

**EC-EP-03 — `wins_at_last_defeat > win_count` (tampered/corrupt save).** *If* a restored boss entry violates EP-INV-1: clamp `wins_at_last_defeat = 0` + corruption warning (Rule 6e). Re-gate delta becomes `win_count` — earned re-gate access always survives; over-credit is the accepted error direction (see EP-INV-1 rationale). Never passed raw into ZWM. *Verified by AC-EP-05.*

**EC-EP-04 — Negative `win_count`.** *If* `win_count < 0` in a restored zone entry: clamp to 0, **then re-run EP-INV-1** on that zone's boss entries (a snapshot consistent with the negative count may now violate it) + warning. *Verified by AC-EP-06.*

**EC-EP-05 — Negative `cumulative_xp`.** *If* a core entry has `cumulative_xp < 0`: clamp to 0 + warning; CP-F1 then re-derives level 1. *Verified by AC-EP-06.*

**EC-EP-06 — `cumulative_xp` above the level-10 threshold.** *If* `cumulative_xp > threshold[10] (2080)`: accepted and stored **as-is** — CP-F1's lookup semantically caps at level 10 (EC-CP-01, owned by Core Progression). No EP action, no clamp. *Delegated — verified by Core Progression's CP-F1 ACs.*

**EC-EP-07 — Duplicate loot IDs in the saved `world_loot` Array.** *If* the serialized Array contains duplicates: deduped automatically on Set reconstruction + malformed-data warning. The runtime Set never holds duplicates. *Verified by AC-EP-08.*

**EC-EP-08 — `restore()` called twice (replacement semantics).** *If* a second blob is restored without returning to new-game state: each domain's `restore()` **unconditionally replaces** all previously held source facts — never merges (Rule 3). *Verified by AC-EP-11.*

**EC-EP-09 — `serialize()` called mid-restore.** *If* a save triggers between Phase 1 and Phase 2: the produced blob is still **valid** (only source facts are serialized — derived state is never saved, Rule 4), but a warning is logged: this indicates a Save/Load orchestration bug. Sequencing is owned by Save/Load (#17). *Advisory — no blocking AC; noted for Save/Load's GDD.*

**EC-EP-10 — A domain's `snapshot()` returns a non-Dictionary.** *If* any registered domain's snapshot is null/Array/String: the **save is refused** with a loud error naming the domain (Rule 3) — a bad snapshot blocks the save rather than corrupting it. *Verified by AC-EP-12.*

**EC-EP-11 — Save from a newer format version.** *If* `saved_version > CURRENT_FORMAT_VERSION`: REFUSE per EP-PRED-1; all domain in-memory state left exactly as it was before `restore()` (Rule 9 guarantee). Save/Load owns the player-facing error UX. *Verified by AC-EP-02 + AC-EP-03.*

**EC-EP-12 — Zero registered domains.** *If* `serialize()`/`restore()` runs with an empty registry (testing, early init): serialize returns `{progress_format_version: 1}`; restore trivially completes. Valid state, no error. *Verified by AC-EP-15.*

**EC-EP-13 — Boss added in a patch.** *If* a loaded save predates a newly added boss: the boss gets Rule 6(b) defaults (`defeated_once = false, wins_at_last_defeat = 0`). **Acknowledged UX consequence:** a previously-CLEARED zone re-derives to ACCESSIBLE (ZWM-F2 now requires the new boss). Correct per the rules; content patches should expect it. *Verified by AC-EP-13.*

**EC-EP-14 — Boss removed in a patch (orphaned `boss_progress` entry).** *If* a save references a boss no longer in content: the orphan is **ignored on load** per Approved EC-ZWM-10 (the explicit exception to Rule 6c's preserve-and-warn). Consequence: if that boss is ever re-added, the prior defeat is lost — see OQ-EP-1. *Delegated — verified by ZWM AC-ZWM-15.*

**EC-EP-15 — Sub-blob present but wrong type.** *If* a domain key maps to a non-Dictionary (e.g. `{"world_loot": 42}`): treated as **missing** — the domain receives `restore({})` → new-game defaults + corruption warning (Rule 6d). *Verified by AC-EP-07.*

**EC-EP-16 — Duplicate `core_instance_id` in the cores sub-blob.** *If* two entries share an instance ID: **first occurrence wins** (parallel to ZWM EC-ZWM-09) + corruption warning (Rule 6e). *Verified by AC-EP-08.*

**EC-EP-17 — Unknown domain key in the blob.** *If* the blob contains a key with no registered domain: preserved opaquely in session memory (Rule 2 exception), written back on next serialize, warning logged. Round-trips intact through an older build. *Verified by AC-EP-09.*

## Dependencies

### Upstream Dependencies (what this system requires)

| System | What this system reads/uses | Hard/Soft | Status |
|---|---|---|---|
| **Zone & World Map** (#12) | Domain owner for `&"zones"` — pulls `ZoneRuntimeState` (`win_count`, `boss_progress[]`) via the Rule 3 contract; triggers ZWM-F2 re-derivation in Phase 2. ZWM remains runtime authority (its Rules 7/8). | **Hard** — the zones domain is the system's founding client | Approved ✓ *(already lists this system as downstream — bidirectionality confirmed)* |
| **Symbot Core Progression** (#10b) | Domain owner for `&"cores"` — pulls `CoreProgressionRecord`s (`cumulative_xp` per `core_instance_id`); triggers CP-F1 level re-derivation in Phase 2 (EC-CP-06). | **Hard** | Approved ✓ *(already lists this system as downstream — bidirectionality confirmed)* |
| **Encounter Zone** (#7) | Nothing read at runtime — but EZ Rules 8a/9 *fix the semantics* of the fields this system persists (`win_count` wins-only/never-resets; `wins_at_last_defeat` snapshot). EP-INV-1 exists to protect EZ's delta math. | **Soft** (semantic dependency) | Approved ✓ *(erratum applied 2026-07-13: Rule 8a hook wording → "ZWM implements the increment; Exploration Progress persists the counter" — see Rule 2)* |
| **World Loot** (#13) | Domain owner for `&"world_loot"` — implements the Rule 3 contract (snapshot `{"collected": [...]}`) and globally-unique `loot_id` content validation. | **Soft** — if unregistered the domain is simply absent; nothing breaks | Approved ✓ *(2026-07-13 — contract implemented exactly; discharges the former soft-provisional marker)* |

### Downstream Dependents (what depends on this system)

| System | What it reads | Status |
|---|---|---|
| **Save/Load** (#17) | The progression blob (Rule 8 split: this system owns blob semantics; Save/Load owns file format, timing, slots, disk I/O). Must list this system when authored, **and must explicitly resolve OQ-EP-2 (save-trigger granularity — the Player Fantasy contingency)**. Forward-notes for #17: `serialize()` may only be triggered at event-boundary quiesce points, never mid-mutation-batch (`snapshot()` is an atomic read of committed state); consider a player-facing "save was repaired" notice for Rule 6e clamps — the clamp-to-0 re-gate case is the strongest argument for it. | Not Started |
| **Encounter Zone** (deferred ACs) | Shipping this system completes the persistence chain — activates deferred **AC-EZ-40b** and **AC-EZ-55**. | Approved ✓ |
| **World Map UI** (#20) | **Nothing at runtime** — the UI reads ZWM's live state directly; the systems-index row "World Map UI depends on Exploration Progress" resolves in practice to ZWM (index note owed). | Not Started |
| **Key Item System** (#23a) | Reserved domain key `&"key_items"`; contract defined when authored (Vertical Slice). | Not Started |

### Bidirectionality Notes (errata obligations)

- **Encounter Zone erratum (light):** ✅ **APPLIED 2026-07-13** — Rule 8a, dependency row, and AC-EZ-55 activation note reworded per Rule 2's resolution. No semantic change to EZ's gate math.
- **Systems-index note:** World Map UI's dependency row → ZWM (not this system).
- **World Loot (#13) and Save/Load (#17)** must list this system in their upstream dependencies when authored.

## Tuning Knobs

This system has **no gameplay tuning knobs** — it stores facts and enforces contracts; there is nothing to balance. Its single configuration constant:

| Knob | Type | Value | Owner | Effect / Guidance |
|---|---|---|---|---|
| `CURRENT_FORMAT_VERSION` | int | 1 | This system | The progression-blob format version this build reads/writes. **Not a tuning value** — increment only on a breaking blob-format change, paired with a per-domain migrate hook (Rule 9). Never decrement. |

**Cross-referenced knobs (owned elsewhere, affect this system's data):** `gate_params.required_wins` / `regate_params.required_wins` (Encounter Zone) shape the `win_count`/`wins_at_last_defeat` values flowing through this system, and CP-F1's threshold table (Core Progression) determines what `cumulative_xp` re-derives to — but none are tuned here. Tune them at their owners; this system round-trips whatever they produce.

## Visual/Audio Requirements

N/A — pure persistence infrastructure. This system renders nothing and emits no player-facing signals. All progress *presentation* (cleared-zone badges, boss states, collected-chest visuals) is owned by the systems that render it: World Map UI reads ZWM's live state; World Loot (#13) owns chest opened/closed visuals. One direction-level note for Save/Load's pass: any "saving…" indicator or corruption-recovery message triggered by this system's warnings is Save/Load UX, not this system's.

## UI Requirements

None — this system contributes no screens and exposes nothing queryable at runtime (pull model). The corruption warnings it logs (Rule 6d/e, EC-EP-03..05) are developer-facing log output, not player UI. If Save/Load (#17) chooses to surface a "save was repaired" notice, that is its design decision reading this system's warning events — flagged in its dependency row.

## Acceptance Criteria

**Test path:** `tests/unit/exploration_progress/` · **Framework:** GUT (GDScript) · **Cross-system locked values used:** CP-F1 thresholds — **level-indexed** per CP-F1's own table (`threshold[L]` = cumulative XP required to *be at* level L; there is no 0-indexed array — do not read these as array positions): threshold[1]=0 · threshold[2]=100 · threshold[3]=220 · threshold[4]=364 · threshold[5]=537 · threshold[6]=744 · threshold[7]=993 · threshold[8]=1292 · threshold[9]=1650 · threshold[10]=2080. Every `threshold[N]` citation below means "XP boundary for level N" — e.g. `cumulative_xp = 364` re-derives to **level 4**. MVP zone has 2 bosses (Boss 1 gate = 6 wins, Boss 2 gate = 10 wins).

**AC-EP-01** (BLOCKING, Unit) — **Serialize → restore round-trip integrity.** **GIVEN** all three MVP domains populated: zones (`win_count = 7`, boss `{boss_a, defeated_once: true, wins_at_last_defeat: 6}`), cores (`cx-01`, `cumulative_xp = 364` — exactly CP-F1 threshold[4], the level-4 XP boundary, not a mid-band value), world_loot (runtime keys inserted unsorted: `["chest_z", "chest_a", "chest_m"]`), **WHEN** `serialize()` then `restore()` + `rederive()` on fresh domain instances, **THEN** zones/cores/loot source facts identical; re-derived core level == 4 (364 at threshold[4] discriminates `>` vs `>=` in CP-F1 lookup); the `world_loot` snapshot Array is `["chest_a", "chest_m", "chest_z"]` — **sorted via String-cast comparison per Rule 1** (an implementation trusting GDScript Dictionary insertion order emits `["chest_z", "chest_a", "chest_m"]` and fails; the fixture's non-alphabetical insertion order `chest_z → chest_a → chest_m` is **normative** — it makes StringName intern order differ from alphabetical order, so an impl calling raw `Array.sort()` on StringNames also fails rather than passing by intern-order accident). *(Rule 1; Rule 3; EC-EP-07 sorted form)*

**AC-EP-02** (BLOCKING, Unit) — **EP-PRED-1 all branches + pre-predicate guards.** GIVEN `CURRENT_FORMAT_VERSION = 1`: **(a)** version 1 → RESTORE (discriminates a `>= 1` impl that accepts version 2 as RESTORE); **(b)** version 0 → classified MIGRATE by the predicate; with no hooks registered (v1) the normative behavior is REFUSE (Rule 9) — **positive domain-state assertion:** domains pre-loaded with `win_count = 5` keep `win_count == 5`, a call-count spy confirms no domain's `restore()` was invoked, no crash. Discriminators: an impl treating hookless MIGRATE as new-game silently zeroes all domains and fails the state assertion; an impl falling through to RESTORE feeds the v0 blob to domains and fails the spy; **(c)** version 2 → REFUSE, no domain receives data; **(d)** version key **absent** → REFUSE — the implementation MUST use `Dictionary.get()` (bracket access on a missing key raises a runtime error in Godot 4 debug builds; this fixture catches bracket-access implementations by crashing them); **(e)** version present but String `"1"` → REFUSE (discriminates an impl doing `int(value)` coercion before the type check). *(EP-PRED-1; Rule 9; EC-EP-02; EC-EP-11 version side)*

**AC-EP-03** (BLOCKING, Unit) — **REFUSE leaves domain state unchanged.** **GIVEN** domains pre-loaded (`win_count = 5`; `cumulative_xp = 220` = threshold[3], the level-3 XP boundary → level 3, so a wrongly-zeroed value visibly re-derives to level 1), **WHEN** `restore()` receives a REFUSE-triggering blob (`progress_format_version: 99`), **THEN** `win_count == 5` and `cumulative_xp == 220` unchanged, **and a call-count spy confirms no domain's `restore()` was invoked** — the discriminator: an impl that restores domains *before* version-checking passes AC-EP-02's predicate assertions but fails the spy. *(Rule 9; EC-EP-11)*

**AC-EP-04** (BLOCKING, Unit) — **Non-Dictionary blob refused before version read.** `restore(null)`, `restore([1,2,3])`, `restore("saved_game")` → each REFUSE; domain state identical to pre-call; hard error logged; no GDScript runtime crash. Discriminator: an impl calling `blob.get(...)` before type-checking **crashes** on null/Array (`get()` undefined there) — guard-chain ordering is what this verifies. *(EC-EP-01)*

**AC-EP-05** (BLOCKING, Unit) — **EP-INV-1 clamp + boundary.** **(a)** `{win_count: 4, wins_at_last_defeat: 7}` → stored `wins_at_last_defeat == 0` (clamped to 0, NOT to 4), warning logged, `win_count` untouched, downstream delta = 4. **(a2) Earned-regate discriminator:** `{win_count: 10, wins_at_last_defeat: 14}` → stored `wins_at_last_defeat == 0`, delta = 10 — **a clamp-to-`win_count` impl stores 10 (delta 0, silently revoking an earned re-gate) and fails this assertion**; this fixture is the error-direction discriminator. **(b) Boundary discriminator:** `{win_count: 4, wins_at_last_defeat: 4}` → stored **as-is, no warning** — EP-INV-1 uses `<=`; a strict-`<` impl wrongly clamps this valid at-boundary entry. **(c)** `{win_count: 4, wins_at_last_defeat: 3}` → as-is, no warning (delta 1). *(EP-INV-1; Rule 6e; EC-EP-03)*

**AC-EP-06** (BLOCKING, Unit) — **Negative clamps + cascade re-check (synthetic IDs — anti-hardcoding).** **Part A:** zone `"z_synth"` with `win_count = -3` and boss `{boss_synth, wins_at_last_defeat: 2}` → `win_count` → 0, **then EP-INV-1 re-runs**: `wins_at_last_defeat` → 0 (2 > 0 post-clamp), two warnings. The cascade discriminator: an impl clamping `win_count` without re-checking stores `wins_at_last_defeat = 2` against `win_count = 0` → delta −2 downstream — exactly the negative-delta case EP-INV-1 exists to prevent. **Part B:** core `"cx-synth-99"` with `cumulative_xp = -150` → 0, warning; Phase 2 re-derives level 1. Synthetic IDs fail any content-keyed special-casing impl. *(Rule 6e; EC-EP-04; EC-EP-05)*

**AC-EP-07** (BLOCKING, Unit) — **Wrong-type sub-blob treated as missing.** GIVEN `{"progress_format_version": 1, "zones": {…valid…}, "world_loot": 42}` → world_loot domain receives `restore({})` (empty set), corruption warning names `world_loot` + bad type; **zones restores normally** (per-domain handling, not whole-blob REFUSE). Second fixture: `"world_loot": ["chest_a"]` (Array, not Dictionary) → same treatment — discriminates a lenient impl special-casing Array-as-loot-list around the type contract. *(Rule 6d; EC-EP-15)*

**AC-EP-08** (BLOCKING, Unit) — **Duplicates: loot dedupe + cores first-wins (synthetic IDs).** **Part A:** saved loot Array `["chest_synth_1", "chest_synth_2", "chest_synth_1", "chest_synth_2", "chest_synth_3"]` (5 entries, 3 unique) → runtime set size 3; snapshot returns sorted 3-element Array; malformed-data warning. **Part B:** duplicate `core_instance_id` collision — **fixture technique note:** both GDScript Dictionary literals *and* Godot's JSON parser collapse duplicate keys (last-wins) before restore code runs, so the collision must be **injected via the cores domain's public `restore_records(records: Array)` method (Rule 3a.2)** with an Array-of-records fixture (`[{id: "cx-dupe-A", cumulative_xp: 364}, {id: "cx-dupe-A", cumulative_xp: 993}]`); **THEN** `cx-dupe-A` present exactly once with `cumulative_xp == 364` (**first** occurrence wins — a last-wins impl stores 993 and fails), re-derived level 4, warning logged. *(Rule 6e; EC-EP-07; EC-EP-16)*

**AC-EP-09** (BLOCKING, Unit) — **Unknown domain key round-trips opaquely.** GIVEN blob with unregistered `"key_items": {"golden_badge": true, "founder_token": 42}` (reserved key, synthetic contents) → restore completes (no REFUSE), warning names `key_items`, and the next `serialize()` output contains the **identical** sub-blob alongside the registered domains — the discriminator: a drop-unknown-keys impl passes AC-EP-01 but its serialize output lacks `key_items`. **Implementation trap (for the reviewer):** the opaque store must `Dictionary.duplicate(true)` (deep copy) — a reference into the original blob dangles if the blob is freed; a sub-fixture nulling the original blob before serialize catches reference-based impls. *(Rule 7; Rule 2 exception; EC-EP-17)*

**AC-EP-10** (BLOCKING, Unit) — **Two-phase restore order independence.** GIVEN zones (`win_count = 10`, Boss 2 `defeated_once: true, wins_at_last_defeat: 10`) + cores (`cx-01`, `cumulative_xp = 993` = threshold[7], the level-7 XP boundary), **WHEN** restored under registration order A (zones first) and order B (cores first), **THEN** outputs identical in both orders: `win_count == 10`, level == 7, ZWM-F2 Phase 2 re-derives CLEARED. A Phase-1 cross-domain read only corrupts output on the unlucky order — dual-order testing is the minimum structure that can catch it. *(Rule 5)*

**AC-EP-11** (BLOCKING, Unit) — **Double restore = replacement, never merge.** Restore Blob A (`world_loot: [chest_a, chest_b]`; cores `cx-01: 220`), then Blob B (`world_loot: [chest_c]`; cores `cx-02: 364`) → loot set is exactly `{chest_c}`; cores contains **only** `cx-02`. The single discriminating line: `assert_false(cores_domain.has_core("cx-01"))` — a merge-based `restore()` retains `cx-01` and fails only here; every single-restore test passes it. *(Rule 3 replacement semantics; EC-EP-08)*

**AC-EP-12** (BLOCKING, Unit) — **Bad snapshot() refuses the save, names the domain.** GIVEN registry with a valid `zones` stub and an injected `broken_domain` stub whose `snapshot()` returns `null` (second fixture: returns an Array), **WHEN** `serialize()`, **THEN** the returned result is `{ok: false, failed_domain: &"broken_domain", error: …}` per the Rule 3 result contract — assert `result.ok == false` **and** `result.failed_domain == &"broken_domain"` on the returned structure, NOT on log output (`push_error()` is not GUT-capturable; the Rule 3a.3 sink additionally records the error message). NOT a partial blob silently missing the broken domain. Discriminator: a skip-silently impl passes every round-trip test while losing the domain's data with no signal; a log-only impl (correct message, bare-blob return) fails the structured-result assertion. *(Rule 3 serialize validation; Rule 3a.3; EC-EP-10)*

**AC-EP-13** (BLOCKING, Unit) — **Missing sub-blob and missing boss entry defaults.** **Part A:** blob with no `zones` key → zones domain initializes new-game defaults, no error; cores restores normally (`cumulative_xp == 100` = threshold[2], the level-2 XP boundary → level 2). **Part B (boss added in patch):** save has Boss 1 only (`defeated_once: true, wins_at_last_defeat: 6`, `win_count: 12`); content has Boss 2 (gate 10) → Boss 1 restores intact; Boss 2 gets defaults (`false`, `0`); Phase 2 re-derives **ACCESSIBLE** (not CLEARED — Boss 2 undefeated). Discriminator: an impl restoring only save-present entries (never visiting the content roster to fill gaps) crashes on null or wrongly derives CLEARED via absent-means-defeated. *(Rule 6a; Rule 6b; EC-EP-13)*

**AC-EP-14** (BLOCKING, Unit) — **Phase 1 no-cross-domain-reads (structural).** GIVEN three instrumented domain stubs each recording any call to another domain's public interface during its own `restore()`, **WHEN** Phase 1 runs (Phase 2 explicitly excluded — cross-domain reads are legal there), **THEN** all three call logs are empty. This catches the *cause* of order-dependence; AC-EP-10 catches the *symptom* (and only on the unlucky order). The injectable cross-domain accessor and the technical definition of "cross-domain read" are **normative in Rule 3a.1** — the seam is part of the domain contract, not a test-time improvisation. *(Rule 5; Rule 3a.1)*

**AC-EP-15** (BLOCKING, Unit) — **Zero registered domains.** GIVEN an empty registry: `serialize()` → Dictionary `{"progress_format_version": 1}` exactly (`size() == 1`), no error; `restore()` of that blob completes trivially, touches nothing; a second `serialize()` is idempotent. Discriminator: an impl assuming `domains[0]` exists crashes here — this is also the first-launch initial state. *(EC-EP-12)*

**Deferred integration ACs (activate when Save/Load #17 ships):**

**AC-EP-DEFERRED-A** (BLOCKING, Integration) — progression blob survives the full disk round-trip through Save/Load's file layer; inner integrity already covered by AC-EP-01, this adds only the I/O + hand-off layer. *Activation: Save/Load GDD approved + Rule 8 interface implemented.*

**AC-EP-DEFERRED-B** (BLOCKING, Integration) — newer-format REFUSE reaches Save/Load's player-facing error path; EP state-unchanged already covered by AC-EP-03. *Activation: Save/Load error-path UX implemented.*

**EC↔AC Cross-Check:** EC-EP-01 → AC-04 · EC-02 → AC-02(d,e) · EC-03 → AC-05 · EC-04 → AC-06A · EC-05 → AC-06B · EC-06 → delegated (Core Progression CP-F1 ACs / EC-CP-01) · EC-07 → AC-08A · EC-08 → AC-11 · EC-09 → advisory-only (Rule 4 makes the blob valid regardless; sequencing owned by Save/Load #17 — no AC by design) · EC-10 → AC-12 · EC-11 → AC-02(c) + AC-03 · EC-12 → AC-15 · EC-13 → AC-13B · EC-14 → delegated (ZWM AC-ZWM-15) · EC-15 → AC-07 · EC-16 → AC-08B · EC-17 → AC-09. **All 17 ECs covered or explicitly delegated/advisory.**

**Summary: 15 BLOCKING unit + 2 DEFERRED integration + 2 delegated + 1 advisory-only.** Anti-hardcoding fixtures: AC-06 (`z_synth`, `cx-synth-99`), AC-08 (`chest_synth_*`, `cx-dupe-A`), AC-09 (`golden_badge`/`founder_token`). GDScript traps addressed: `.get()` vs bracket access (AC-02d, AC-04), insertion order vs sorted (AC-01, AC-08A), StringName intern-order sort vs String-cast sort (Rule 1, AC-01 normative fixture order), duplicate-key parser collapse (AC-08B — inject via `restore_records()`, Rule 3a.2), deep-copy opaque store (AC-09), `push_error()` non-capturability (Rule 3 result contract + Rule 3a.3 sink, AC-12).

## Open Questions

- **OQ-EP-1 — Re-added boss re-gate semantics.** If a boss is removed in a patch (orphan entry dropped per EC-ZWM-10) and later re-added, it returns with `wins_at_last_defeat = 0`; a player with banked wins satisfies the LIGHTER_REGATE delta immediately — the boss's *first* re-encounter gate is effectively open on arrival. The math is well-defined (no negative delta); whether the *semantic* is right (should a re-added boss be treated as brand-new instead?) is a design call. Requires a triple-patch sequence to ever occur; single-zone/2-boss MVP cannot hit it. *Owner: game-designer, revisit if a boss removal ever actually ships. Deliberately not blocking.*

- **OQ-EP-2 — Player Fantasy is contingent on Save/Load's save-trigger granularity.** This system guarantees that whatever reaches a save survives — but it fires only at serialize time, and Save/Load (#17, Not Started) owns *when* serialize fires. On the primary platform (iOS), force-quit/crash between saves is the most common abnormal exit: a player who grinds 6 WILD wins and loses them to a phone dying before the next save experiences exactly the Section B anti-fantasy ("the game stole my grind"), and no rule in this GDD can prevent it. **This layer cannot legislate #17's save timing** (per-event saves trade against mobile flash wear and I/O cost — that trade-off belongs to Save/Load's design pass). What #17 MUST weigh when authored, in priority order: `win_count` increment (highest stakes — grind loss), boss `defeated_once` flip, loot collection, core level-threshold crossing. *Owner: Save/Load (#17) design pass — its GDD must resolve this OQ explicitly; flagged in its dependency row. [Added 2026-07-13 review — GD-B1 reframed as contingency by creative-director.]*
