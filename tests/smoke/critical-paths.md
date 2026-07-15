# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing (touch + keyboard/mouse)

## Core Mechanic (update per sprint)

<!-- Add the primary mechanic for each sprint here as it is implemented -->
<!-- Example: "Player can equip a part in the Workshop and see stats update" -->
4. [Primary mechanic — update when the first core system is implemented]

## Data Integrity (once Save/Load — ADR-0001 — is implemented)

5. Save game completes without error (≤ 2 MiB / ≤ 50 ms iOS budget, ADR-0001)
6. Load game restores correct state (restore → rederive round-trip)
7. `is_battle_active()` gate blocks a manual save mid-battle (ADR-0002 §4 / ADR-0007)

## Performance

8. No visible frame-rate drops on target hardware (60 fps / 16.6 ms budget)
9. Draw calls stay within budget on the heaviest screen (≤ 200, ADR-0008)
10. No memory growth over 5 minutes of play (≤ 512 MB ceiling)
