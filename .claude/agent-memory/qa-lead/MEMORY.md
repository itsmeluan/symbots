# Memory Index

- [Part Database AC Review](project-part-database-ac-review.md) — Two-round AC review history; 5 new blockers found in round 2 (floor tests, ceiling bug exposure, double-negation path)
- [Enemy Database AC Review](project-enemy-database-ac-review.md) — Round 1 review; 8 blockers (threshold hardcoding, boundary gaps, mixed gate levels, uncitable AC); 3 missing test cases
- [Synergy System AC Review](project-synergy-ac-review.md) — Round 3 review; 6 blockers (white-box AC, consumer formula ownership, missing error-contract ACs for EC-SYN-06/07/10, effect dedup ordering)
- [Enemy AI AC Review](project-enemy-ai-ac-review.md) — Round 1 review; 4 blockers (energy zero path, seed underspec, int-division trap, shallow-copy mutation); 11 recommended; new patterns: GDScript int/int, shallow-copy, seed pre-selection
- [Core Progression AC Review](project-core-progression-ac-review.md) — Round 2 review; all Round 1 blockers resolved; 4 new blockers (Rule 2/EC/AC signal contradiction, Assembly erratum dependency, multi-jump boundary off-threshold, record-creation interface unspecified)
- [Enemy Level & Zone Scaling AC Review](project-elzs-ac-review.md) — Round 4 (fresh-session confirmation); all round-3 fixes verified; 3 new BLOCKING gaps (at-floor AC-05 acceptance missing for F>1, overlap-boundary AC-06 fixtures missing, AC-04 floor=0 rejection missing); 4 RECOMMENDED
