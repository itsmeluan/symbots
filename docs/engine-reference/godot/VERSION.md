# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7 |
| **Release Date** | ~Mid 2026 (approximate — confirm against official release notes) |
| **Project Pinned** | 2026-07-15 (re-pinned 4.6 → 4.7 to match installed toolchain) |
| **Last Docs Verified** | 2026-07-15 |
| **LLM Knowledge Cutoff** | ~May 2025 |

> **Re-pin note (2026-07-15):** Project was re-pinned from Godot 4.6 → 4.7 to
> match the only installed engine (`4.7.stable.official`). Authoritative pins
> (`project.godot`, this file, `technical-preferences.md`, `CLAUDE.md`) are
> updated. The 8 ADRs + architecture docs still reference "4.6" and need an
> engine-compatibility **re-validation pass via `/architecture-review`** — a
> label swap is not sufficient; their engine-compat claims were reasoned against
> 4.6 assumptions.

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4, 4.5, 4.6,
**and 4.7** introduced significant changes that the model does NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes, **typed Dictionaries introduced** |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |
| 4.7 | ~Mid 2026 | MEDIUM | Inherited typed-return methods require explicit `return` (GH-115763); packed-array element setter no longer fires whole-property setter (GH-113228); `Object.is_class()` takes `StringName`; RichTextLabel image unit params |

### 4.7 notes relevant to current work

- **Typed `Dictionary[StringName, int]` `.tres` round-trip**: the 4.7 migration
  guide documents **no breaking change** to typed-Dictionary serialization or
  StringName-key handling (StringName keys were *optimized*, not changed). The
  round-trip nonetheless remains **empirically UNVERIFIED** on this toolchain —
  Part-DB Story 001 is the spike that verifies it headless on 4.7.
- **GH-115763** (typed-return inheritance) affects *overridden* methods only.
  A standalone typed accessor (`func get_bonus(k) -> int`) is unaffected.

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.6→4.7 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://godotengine.org/releases/
