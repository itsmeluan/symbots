# Review Log: Synergy System

## Review — 2026-07-10 — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, ux-designer, qa-lead, creative-director
Blocking items: 4 | Recommended: 7+
Summary: The system's machinery (SYN-F1–F4, cumulative stacking, 8 of 13 ACs) was close to sound, but Section B described a 3-piece activation experience while SYNERGY_THRESHOLD_TIER1=2 defined a 2-piece threshold — the player-facing fantasy and the rule were contradictory. A second blocker was the wild-parts dominant strategy: players can double-dip element and manufacturer synergies simultaneously with no tradeoff, undocumented. Two implementation blockers: active_synergies signal parameter untyped, and preview() slot-displacement unspecified. All 4 blocking items were resolved in the same session. TIER1 raised from 2→3, TIER2 from 4→5; evaluate_silent() added for TBC battle-start; section renamed to "Detailed Rules"; 5 weak ACs fixed; 10 AC fixtures updated for new thresholds.
Prior verdict resolved: No — first review

### Blocking items (resolved before re-review):
- A1: Player Fantasy described 3-piece activation; TIER1=2 defined 2-piece → FIXED: TIER1→3, TIER2→5 throughout GDD and entities.yaml
- A2: active_synergies signal parameter untyped → FIXED: Array[StringName] type + ordering rule added to Rule 7
- A3: preview() slot-displacement contract missing; no out-of-range behavior → FIXED: Rule 9 now explicit on both
- A4: Wild parts dominant strategy (double-dip element+manufacturer) undocumented → FIXED: EC-SYN-03 rewritten as intended design

### Key recommended fixes also applied:
- evaluate_silent() added for TBC battle-start (prevents spurious synergy_changed at battle start)
- EC-SYN-02 max simultaneous tiers corrected (10, not 6)
- UI Req 1 scoped to build-relevant tiers (3–8 max, not all 30)
- Combined 4-piece explicitly excluded from MVP (Rule 3)
- OQ-6 added: verify SA-F2 return type before Workshop UI GDD
- Effect display_name ownership assigned to Synergy Content data

### Open items for re-review to verify:
- systems-designer CRITICAL-3 (SA-F2 + preview() composition ambiguity) — demoted to pending-verification by creative-director; verify SA-F2 return type from Assembly GDD before re-reviewing
- qa-lead: 6 missing AC scenarios not yet added (deactivation test, three-synergy payload, max-concentration, wrong-length array, same-part preview, and EC-SYN-07 empty tags) — flagged P3/P4; re-review should assess if any are blocking
