# Story 010: Author MVP part content + wire CI content suite

> **Epic**: Part Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-019` + content realization of all 25 Part DB requirements (this is where every validator family + formula runs against REAL `.tres`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content is authored as per-entry `.tres` files referenced by an explicit `part_catalog.tres` (the catalog IS the manifest of what ships). CI mount: a headless GUT suite in `tests/unit/content/` loads the real shipped catalog, runs the `ContentValidator`, and asserts `report.ok` — content errors block merge exactly like code errors. **Precondition (gate):** Story 001 (typed-dict `.tres` round-trip) must have PASSED before any content authoring begins.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: The CI suite runs **headless** (`godot --headless`) so editor-cache Resource instances never contaminate the run. Discovery is driven by `.gutconfig.json` (`suffix: "_test.gd"`), not the bare `-gdir` prefix form. `.tres` stores enum values as raw ints — authoring must use the explicit enum members (never raw numbers). A catalog fixture-count check (entry-directory count == catalog size) guards "authored but not shipped" drift.

**Control Manifest Rules (this layer)**:
- Required: Content ships as typed `.tres` defs resolved through explicit catalog reference chains via `ResourceLoader`; one catalog per DB — source: ADR-0003
- Required: GUT content suite runs the `ContentValidator` on shipped catalogs headless and blocks CI on any ERROR — source: ADR-0003
- Forbidden: Never list content directories with `DirAccess` (`content_directory_scanning`) — source: ADR-0003
- Guardrail: ~130 records total → sub-millisecond boot load; save/perf budgets unaffected

---

## Acceptance Criteria

*From ADR-0003 §2/§5 + GDD content rules + AC-12 (real-content budget check):*

- [ ] MVP part `.tres` entries authored under `assets/data/parts/`: the 8 starter parts (one per slot, shipped with Symbots) plus the Rare/Boss-grade/Prototype parts the MVP zone/bosses need
- [ ] At least one `part_family` with ≥2 rarity variants sharing the family id but distinct `id`/`rarity`/stats (TR-part-019 / EC-06)
- [ ] `assets/data/catalogs/part_catalog.tres` (`PartCatalog`) lists every shipped entry; an entry not in the catalog does not ship
- [ ] The real catalog passes the full `ContentValidator` (Stories 007+008+009 families) — `report.ok == true`
- [ ] CI mount: `tests/unit/content/part_catalog_ci_test.gd` loads the real catalog headless, runs the validator, asserts `ok`; wired into `.github/workflows/tests.yml` as a blocking gate
- [ ] Catalog-completeness check: entry-file count under `assets/data/parts/` == `part_catalog.entries.size()`
- [ ] No `DirAccess` in the load path (static grep — inherited from Story 003, re-asserted here on the real path)

---

## Implementation Notes

*Derived from ADR-0003 Migration Plan ("author MVP entries" is the last step per DB epic):*

Author entries in the Godot inspector as typed `.tres` (the whole point of ADR-0003's inspector-authoring choice). Every entry must satisfy the validator families already built — treat validator failures as authoring bugs, not validator bugs. Use the Stat Budget Reference tables for stat spends, the caps/floors tables for Common/Rare primary stats (AC-23), and ensure every Boss-grade part carries a ≥500 break condition (AC-11) and every Prototype has ≥3 conditions with product ≥3.0 (Formula 3 content rule) plus ≥1 negative + 70% concentration.

Scope the content to what the MVP zone + 2 bosses actually need — do NOT author the full ~40–60 catalog speculatively; author the minimum coherent set that (a) fills all 8 starter slots, (b) exercises each rarity at least once, (c) includes one `part_family` variant chain, and (d) lets downstream epics (Assembly, Drop, Enemy) reference real ids. Additional content is a later content pass, not this story.

The CI test is the capstone: it proves the whole epic end-to-end — schema loads, formulas compute, validator passes — on shipping data, headless, blocking merge.

---

## Out of Scope

*Handled by neighbouring stories / later passes — do not implement here:*

- Stories 002–009: the classes, loader, formulas, and validator this story exercises
- The full ~40–60-entry production catalog (later content pass; this story authors the MVP-minimum set)
- Enemy loot-pool wiring, Drop-table assembly, Assembly slot rules — downstream epics reference these part ids but own their own content
- Move/Passive catalog authoring — those epics own their `.tres`

---

## QA Test Cases

*This is a Config/Data story — evidence is the green CI run + a smoke check, plus the automated catalog CI test.*

- **AC-1**: Real catalog passes the full validator (CI)
  - Setup: author the MVP part `.tres` set + `part_catalog.tres`; ensure Stories 007–009 validator is present
  - Verify: `tests/unit/content/part_catalog_ci_test.gd` loads the real catalog headless, runs `ContentValidator.validate`, asserts `report.ok == true` and `report.errors` empty
  - Pass condition: the CI job is green; any authoring rule violation turns it red

- **AC-2**: Catalog completeness (no unshipped/orphaned entries)
  - Setup: the authored entries + catalog
  - Verify: entry-file count under `assets/data/parts/` equals `part_catalog.entries.size()`
  - Pass condition: counts match; a stray WIP `.tres` not in the catalog fails the check

- **AC-3** (TR-part-019 / EC-06): part_family variant chain present
  - Setup: author ≥2 variants sharing a `part_family`
  - Verify: they share `part_family`, have distinct `id`/`rarity`, and each loads independently via `PartDB.get_part`
  - Pass condition: both resolve; Workshop grouping by `part_family` is possible (grouping UI itself is the Workshop epic)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `production/qa/smoke-part-content-[date].md` — smoke check: catalog loads, validator green, starter slots all filled
- Green content CI run (`tests/unit/content/part_catalog_ci_test.gd` passing in `.github/workflows/tests.yml`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (schema), Story 004 + Story 005 (formulas for budget realism), Story 006 (drop-condition math), Stories 007 + 008 + 009 (validator families) — and the Story 001 gate must have PASSED
- Unlocks: downstream epics (Assembly, Drop, Enemy DB, Inventory, Workshop) can reference real part ids; **closes the Part Database epic**
