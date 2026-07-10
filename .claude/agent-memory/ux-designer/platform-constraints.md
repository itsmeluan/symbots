---
name: platform-constraints
description: iOS-first touch platform rules that constrain all Workshop and combat UI design decisions
metadata:
  type: project
---

Primary platform is iOS touch. Mac keyboard/mouse is development and early launch only.

Key constraints for all UI design:
- Minimum tap target: 44×44pt (Apple HIG)
- No hover state exists on iOS. Long press is the closest native approximation but has UX costs.
- No cursor. Touch is binary: not-touching or touching.
- Touch-and-drag conflicts with scroll gestures on list views.
- Force Touch / Peek is deprecated since iOS 13 -- do not design for it.
- All interactions must be completable with a single thumb on a standard iPhone form factor.
- No gamepad support planned.

**Why:** The GDD's SA-F2 "hover preview" interaction pattern was discovered to be unimplementable on iOS as specified during adversarial UX review of the Symbot Assembly GDD (2026-07-10). This constraint is now load-bearing for the Workshop UI GDD design.

**How to apply:** Before specifying any interaction in a Workshop or combat UI spec, verify it has a native iOS touch equivalent. Hover-based patterns must be replaced with tap-to-preview, long-press, or explicit preview mode patterns.

See also: [[workshop-ux-open-issues]]
