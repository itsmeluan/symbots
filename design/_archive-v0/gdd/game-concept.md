# Game Concept: Symbots

*Created: 2026-07-09*
*Status: Draft*

---

## Elevator Pitch

> Symbots is a creature-collection RPG where you explore a world of wild machines, hunt
> specific components from your enemies, and engineer a team of modular robotic companions
> called Symbots from interchangeable parts. You don't catch your team — you build it.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Creature-collection RPG / Tactical Turn-based RPG / Crafting RPG |
| **Platform** | Mac (launch), iOS (primary long-term target) |
| **Target Audience** | Hardcore collectors and build theorycrafters, 16–35 |
| **Player Count** | Single-player |
| **Session Length** | 30–90 minutes |
| **Monetization** | TBD (Premium preferred; no P2P or loot boxes) |
| **Estimated Scope** | MVP: Medium (3–6 months, solo); Full Vision: Large (1–3 years, solo with AI) |
| **Comparable Titles** | Pokémon (main series), Monster Hunter World, Path of Exile |

---

## Core Fantasy

You are a Symbot Mechanic — an engineer who wanders a world where machines have become
part of nature, hunting wild mechanical creatures, stripping their components, and assembling
your own robotic companions from what you find.

The fantasy is **mastery through modularity**. No two players build the same team. Every
part you equip changes how a Symbot thinks, moves, attacks, and defends. A fire-core striker,
a shielded support unit, a hybrid glass cannon built from boss parts no one else has found —
your workshop is your expression and your laboratory.

The game rewards mastery over the system: knowing which parts synergize, which boss drops what component, which build counters which opponent. Levels pace your access to the workshop's most powerful tools — but the workshop wins the fight. Power isn't given — it's engineered.

---

## Unique Hook

> "It's like Pokémon, AND ALSO you design every single creature from scratch using parts
> you hunt from your enemies, with Path of Exile depth in how those parts interact."

No creature-collector has ever put meaningful build-craft at its center. In Pokémon, you
find the team. In Symbots, you fabricate it — and the parts themselves are the things you're
collecting, hunting, and obsessing over.

**The secondary hook**: every battle is a harvest decision. Do you win fast, or do you target
specific parts to break, specific damage types to use, specific conditions to trigger — to
maximize the chance of dropping exactly the component you need?

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Expression** (self-expression, creativity) | 1 | Infinite Symbot builds from modular parts; no two teams identical |
| **Challenge** (obstacle course, mastery) | 2 | Tactical turn-based combat; part synergies reward deep knowledge |
| **Discovery** (exploration, secrets) | 3 | New zones → new parts → new builds; hidden synergies to find |
| **Fantasy** (make-believe, role-playing) | 4 | Player identity as a Symbot Mechanic in a living machine-world |
| **Sensation** (sensory pleasure) | 5 | Satisfying part-break effects, build assembly feedback, combat juice |
| **Narrative** (drama, story arc) | 6 | Worldbuilding emerges through lore and rival mechanics (future layer) |
| **Fellowship** (social connection) | N/A | Single-player focus; community sharing of builds is secondary |
| **Submission** (relaxation, comfort) | N/A | Not a relaxation game — tension and decision are core |

### Key Dynamics (Emergent player behaviors)

- Players will research and min-max part combinations obsessively, sharing builds with community
- Players will set specific part-hunting goals before entering any combat zone ("I need the Ignis Core from the Forge Boss")
- Players will deliberately lose fights or replay encounters to target specific drop conditions
- Players will rebuild their team from scratch when they find a part that suggests a new strategy
- Players will discover synergies the designer didn't predict — hybrid builds that exceed designed power curves

### Core Mechanics (Systems we build)

1. **Modular Symbot Assembly** — heads, bodies, arms, legs, weapons, and cores are individually swappable and define every stat, ability, and identity of a Symbot
2. **Targeted Part Hunting** — defeating enemies in specific ways (breaking parts, using damage types, finishing under conditions) increases drop odds for related components
3. **Tactical Turn-Based Combat** — turn-by-turn battle where move availability is shaped by your build; primary feel is tactical puzzle executing through a build strategy
4. **Synergy System** — parts from the same manufacturer or element activate set bonuses; cross-manufacturer mixing creates hybrid strategies
5. **Workshop Crafting** — scrap + blueprints → new parts; parts can be upgraded, modified, and tuned to alter effects and stats

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Every Symbot's identity is the player's construction. No prescribed "correct" team — builds are personal hypotheses | Core |
| **Competence** (mastery, skill growth) | Build understanding deepens over time; synergy mastery unlocks real power advantages | Core |
| **Relatedness** (connection, belonging) | Connection to the mechanical world's lore; rival Mechanic NPCs with distinct philosophies (future layer) | Minimal (MVP) |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — Chase rare parts, complete build goals, defeat bosses, unlock blueprints, conquer endgame challenges
- [x] **Explorers** — Discover new zones full of parts, find hidden synergies, understand the machine-world's rules
- [ ] **Socializers** — Minimal in MVP; potential for build sharing and async PvP post-launch
- [ ] **Killers/Competitors** — No PvP in MVP; arena mode is a long-term consideration

### Flow State Design

- **Onboarding curve**: Player is given a starter Symbot and shown how to swap one part before their first battle. The first zone is a tutorial that teaches part-breaking through required encounters. Full workshop opens after first boss defeat.
- **Difficulty scaling**: Enemy builds scale by zone; boss encounters use advanced synergies the player must study or reverse-engineer. Difficulty increases build requirements, not just stats.
- **Feedback clarity**: Part-break events show clearly which parts dropped. Workshop shows stat deltas when swapping parts. Battle log describes why moves hit hard or weak.
- **Recovery from failure**: Turn-based means losses are educational, not punishing. The player keeps all acquired parts. They can rebuild and retry immediately — failure is a build hypothesis disproved.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Each turn: assess the enemy's parts and weaknesses → review your active Symbot's available moves (defined by its installed parts) → choose: attack to break a specific component, apply a status, deal elemental damage, or swap to another team member → watch the result (damage, part-break progress, resource shifts) → enemy responds → repeat.

The primary feel is **tactical puzzle** executing through **build execution**, with light **resource management** (heat, energy, or ammo as a constraint layer). The build you assembled before the fight defines which tools are available — every turn is playing that instrument.

### Short-Term (5–15 minutes)

A complete encounter arc: enter the zone → identify a part target ("I need the Servo Arm from the Crawler type") → engage, break its arm before finishing it → receive targeted drop bonus → check inventory → repeat 2–3 more encounters to fill the material gap → return to workshop.

The "one more fight" hook: the part you need was *almost* there. The drop happened but wasn't the variant you need. Try again.

### Session-Level (30–90 minutes)

Set a build goal → hunt in the right zone → farm and fight → collect parts → return to workshop → assemble or upgrade → test the new build in a harder encounter → discover a new synergy → set a new goal.

The session ends with a clear save point at the workshop. The hook to return: you just got a blueprint for a part that could complete your build — you'll need three more materials.

### Long-Term Progression

Power grows through better parts and smarter builds, not levels. Players unlock new zones by defeating zone bosses (which drop unique parts unavailable elsewhere). Each new zone introduces new part types, new synergy possibilities, and new build hypotheses. The endgame is the hunt for rare, high-tier parts and the discovery of powerful cross-manufacturer synergies.

The long-term "completion" is building the team that feels perfectly yours — not a checklist, but a creative achievement.

### Retention Hooks

- **Curiosity**: "What parts does this boss drop? What synergy am I missing? What's in the next zone?"
- **Investment**: The player's current builds represent hours of hunting and theory. Abandoning them feels costly; refining them feels rewarding.
- **Social**: (Future) Build sharing, community theorycrafting, rival Mechanic encounters
- **Mastery**: Harder bosses demand better builds. Endgame encounters require mastery of the synergy system.

---

## Game Pillars

### Pillar 1: Engineer, Don't Collect
Every Symbot is assembled, not found. Players express identity through construction. No "catch" mechanic exists — ownership comes from fabrication.

*Design test*: "If we're debating adding a mechanic where players can capture a wild Symbot directly, this pillar says no — they must disassemble it for parts and build their own."

### Pillar 2: Every Battle Has a Harvest Goal
Combat is never just about winning. Every fight is an opportunity to farm a specific part, break a specific component, or test a build hypothesis. Battles without meaningful drop targets feel like filler.

*Design test*: "If we're adding a random encounter, this pillar says it must have at least one part-break target and a conditional drop tied to how the player finishes the fight."

### Pillar 3: Build Depth Over Content Breadth
100 well-designed parts with deep synergies beats 500 shallow ones. Richness comes from combinatorial interaction, not raw asset count. Critical for a solo dev — fewer parts, deeper relationships.

*Design test*: "If we're debating adding a new part, this pillar says: does it create at least one new build archetype or synergy interaction? If not, we redesign it before adding it."

### Pillar 4: Synergy Is the Endgame
The highest mastery expression is discovering combinations that interact in unexpected ways. Set bonuses (same manufacturer or element), cross-manufacturer hybrids, and emergent interactions reward deep system knowledge.

*Design test*: "If we're debating whether a mechanic belongs, this pillar says it must interact with at least two other existing systems — or we're not done designing it yet."

### Pillar 5: The World Is a Workshop
Exploration exists to feed the build loop. Every zone, secret, and boss exists primarily as a source of new parts, blueprints, and upgrade materials. Story is seasoning — the machine comes first.

*Design test*: "If we're designing a new area, this pillar says it must introduce at least one new part type or blueprint unavailable elsewhere. Beautiful environments without build rewards are incomplete."

### Anti-Pillars (What This Game Is NOT)

- **NOT a catch-and-store collector**: There is no Pokédex-style "gotta catch 'em all" completion counter. Players build what excites them, not what fills a registry.
- **NOT a story-first game**: Lore and narrative are enrichment, not the driving force. We do not design cutscenes before the build loop is proven fun.
- **NOT a level-matching treadmill** *(revised 2026-07-12 — CD sign-off pending)*: Leveling is a real progression axis — enemy levels and zone level ranges scale the world, core level gates access to high-tier parts and grows stats, and higher-level enemies yield better XP and drops. But leveling is **not the win condition**. A clever build with well-chosen parts must still beat a lazily-assembled higher-level one. Levels set the stage; the workshop wins the fight. The path to power runs primarily through parts, builds, and synergies — leveling paces access to them. *(Prior text — "NOT a grind-levels-to-win treadmill: Stats grow meaningfully through better parts and crafting, not generic XP farming" — revised when the Level Backbone was introduced via Symbot Core Progression #10b. See symbot-core-progression.md.)*
- **NOT a real-time action game**: Turn-based is a design commitment, not a placeholder. Every UI decision and mechanic assumes the player has time to think about their build.

---

## Visual Identity Anchor

*Note: This is a preliminary direction. Run `/art-bible` to develop the full visual specification.*

**Direction**: "Colorful Mechanical Wilderness"

The world looks like nature, but built from gears, circuits, and alloys. Wild Symbots move through forests of crystalline pylons and overgrown scrap dunes. Color is vibrant and readable — this is a world worth exploring, not a grimdark wasteland.

**One-line visual rule**: Every element must feel like it *grew* here, not was *placed* here.

**Supporting principles**:
- **Organic machine forms**: Symbot silhouettes reference animals and creatures (insectoid, reptilian, avian) but are clearly mechanical. Players should recognize the archetype instantly.
  *Design test*: "If you cover the part slots, does the Symbot still read as a coherent creature type?"
- **Part readability at a glance**: Each slot type (head, body, arms, legs, weapon, core) occupies a clear visual zone. Mix-and-match parts must look intentional, not random.
  *Design test*: "Can a new player identify which part was swapped in a before/after comparison in 3 seconds?"
- **Elemental color language**: Damage types (elements) use consistent color coding across all parts, effects, and UI — manufacturers are distinguished by surface finish, not color (see art-bible §3.8). Fire = amber/red, Electric = cyan/yellow, etc.
  *Design test*: "Can a player identify the element of an attack from the screen flash alone?"

**Color philosophy**: Saturated but not garish. Primary world tones are warm earth + cool metal. Wild Symbots use higher saturation to signal power level — rare boss parts glow. The workshop is warmer and calmer — a safe space.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **Pokémon** (main series + Legends) | Team collection, turn-based combat structure, encounter design, type effectiveness | Players build every team member instead of catching ready-made ones | Proves the genre has massive audience; our hook is a meaningful evolution |
| **Monster Hunter World** | Targeted part hunting, boss encounter design, material-to-gear crafting loop, "one more hunt" retention | Applied to a turn-based RPG with team management; breaking parts is strategic, not just mechanical | Proves the "hunt for specific parts" loop sustains 100+ hour engagement |
| **Path of Exile** | Deep build theorycrafting, item interaction depth, set bonuses, emergent build discovery, community meta | Applied to creature-collection with mobile-friendly turn-based combat | Proves hardcore build depth has a massive dedicated audience hungry for new contexts |
| **Horizon Zero Dawn** | Machines-as-nature world aesthetic, sense of wonder in a mechanical wilderness | Our world is colorful and stylized, not realistic; Symbots are companions, not enemies | Validates the "nature + machine" aesthetic as commercially compelling |

**Non-game inspirations**:
- **Zoids** (anime) — modular mech companions with personality through their mechanical form
- **Digimon** — creature companions that feel engineered, not magical; evolution through parts resonates
- **Gundam model kits (Gunpla)** — the joy of physical assembly; each Symbot should feel like a kit you built

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16–35 |
| **Gaming experience** | Mid-core to hardcore; has played creature collectors AND either crafting RPGs or ARPGs |
| **Time availability** | 30–90 minute sessions; plays most evenings and weekends |
| **Platform preference** | Mobile (primary long-term); PC/Mac (early adopters) |
| **Current games they play** | Pokémon, Monster Hunter, Path of Exile, Vampire Survivors, Hades |
| **What they're looking for** | A creature-collector with the depth of a crafting game — feeling like their team is truly theirs |
| **What would turn them away** | Too much story padding before the build loop; RNG-only progression with no targeted farming; too casual with no build depth |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Engine** | Godot 4.6 — excellent for 2D turn-based RPGs; exports natively to Mac and iOS; free and open-source |
| **Key Technical Challenges** | Modular visual assembly (rendering part combinations that look intentional); iOS export pipeline (requires Xcode + Apple dev account); save system for large parts inventories |
| **Art Style** | Pixel art. Modular silhouette design for all Symbot parts |
| **Art Pipeline Complexity** | Medium-High (custom 2D with modular part system; each part type needs visual zone consistency) |
| **Audio Needs** | Moderate — distinct hit sounds per element type, workshop ambience, encounter music. Part-break events need satisfying audio feedback |
| **Networking** | None (MVP); potential async build sharing post-launch |
| **Content Volume (MVP)** | ~20 Symparts, ~8 wild encounter types, 2 bosses, 1 zone, ~5–10 hours of gameplay |
| **Content Volume (Full)** | 150–300 Symparts, 6–8 zones, 10+ boss types, 50–100+ hours |
| **Procedural Systems** | No procedural generation; all content hand-designed for quality over quantity |

---

## Risks and Open Questions

### Design Risks
- **Modular art complexity**: Making every part combination look intentional is a hard art problem. A poorly assembled Symbot that looks broken will hurt player satisfaction
- **Balance complexity**: PoE-style build depth can become impossible to balance solo — emergent overpowered combinations will require active tuning
- **Tutorial burden**: The build system is deep; onboarding players without overwhelming them is a significant design challenge
- **Pacing**: If the part drop rate is wrong (too fast = trivial, too slow = frustrating), the core loop collapses

### Technical Risks
- **iOS export pipeline**: Requires Xcode, an Apple Developer account ($99/year), and device testing. Must validate early in development
- **Modular rendering**: Combining 6–8 sprites into a coherent Symbot at runtime needs careful layering and bone/offset system design in Godot
- **Save system complexity**: Large inventories with hundreds of parts, multiple Symbot builds, and upgrade states require careful data architecture from day one
- **Touch UI for complex builds**: Part management (swapping, comparing, upgrading) is UX-intensive on mobile; must design for touch from the start

### Market Risks
- **Pokémon shadow**: The genre is defined by Nintendo's IP. Marketing must clearly communicate the "build, don't catch" differentiator
- **Scope signals quality**: A thin MVP may be dismissed as a Pokémon clone; the build system must be deep enough to communicate the vision immediately
- **Mobile monetization**: Premium mobile is a harder sell than F2P; Balatro and Hades prove it's possible — but requires strong word of mouth

### Scope Risks
- **Full vision is enormous**: The complete game rivals MHW in content ambition. Solo dev discipline is the hardest challenge
- **Art bottleneck**: Every new part requires original art. The MVP must establish the modular design system before adding content
- **Feature creep from Pokémon/MHW/PoE inspiration**: All three games have features that would be "cool to have." The pillars must filter relentlessly

### Open Questions
- **Core loop validation**: Is assembling your own Symbot more satisfying than catching a pre-made one? → Answered by MVP prototype
- **Optimal part slot count**: How many slots (head, body, arms, legs, weapon, core) creates sufficient depth without overwhelming? → Answered by playtesting
- **Set bonus threshold**: How many parts from the same manufacturer should trigger a bonus (2? 3? 4?)? → Answered by balance design document
- **Part-breaking granularity**: How many breakable parts per enemy is satisfying without being tedious? → Answered by prototype

---

## MVP Definition

**Core hypothesis**: Players find assembling their Symbot team from hunted parts more engaging than catching pre-made creatures, and the targeted part-hunting loop sustains 5+ hour sessions.

**Required for MVP**:
1. Turn-based battle system with 4 moves per Symbot (move pool defined by installed parts)
2. Part-break system: enemies have 2–3 breakable components; targeting them improves drop odds
3. Workshop: assemble, disassemble, and upgrade Symparts across 4–6 slot types
4. ~20 Symparts total (3–4 options per slot type; enough for multiple distinct builds)
5. ~8 wild encounter types with varied part compositions
6. 2 boss encounters with unique drops unavailable from wild encounters
7. 1 starter zone with enough map to feel like a world worth exploring
8. Basic inventory and part management UI designed for touch from day one
9. A small consumable-item layer — salvage-tech items that drop from enemies (scaled by level/rarity) and are used during and between fights: **Repair Kit** (restore Structure), **Coolant Flush** (dump Heat), **Power Cell** (restore Energy), **Salvage Beacon** (boost drop odds), **Signal Jammer** (repel encounters), **Scrap Lure** (draw encounters). Consumables are a *support* layer — a REPAIR *move* remains the primary in-build heal, so healing stays a build choice (Pillar 1), and enemies are still harvested for parts, never captured.

**Explicitly NOT in MVP** (defer to later):
- Story, dialogue, or narrative content
- More than 1 zone or 2 bosses
- Blueprint crafting / Designs (direct part drops are enough for MVP — designs remain Alpha per HOLISM-01)
- Online features of any kind
- iOS release (test export pipeline early, but don't optimize for it until after MVP validation)

> *Scope revision 2026-07-10: Synergy System moved from Vertical Slice → MVP. Rationale: Part DB hard constraint DB1 requires synergy defined before TBC is designable, and Pillar 4 ("Synergy Is the Endgame") is untestable without some synergy in the first playable.*
>
> *Scope revision 2026-07-12: Small consumable-item layer added to MVP (item 9) — new Foundation system #1c Consumable Database. Drop taxonomy becomes parts + scrap + consumables (designs stay Alpha). Rationale: user decision — consumables (heal/cool/energy/repel/lure/drop-boost) deepen the moment-to-moment hunt loop while staying inside the pillars (support layer, not a capture mechanic; healing remains build-relevant via REPAIR moves). Creates errata on TBC (use-item action), Drop System (consumable drop class), and Encounter Zone (encounter-rate modifier, un-defers OQ-EZ-4).*

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 zone, ~20 parts, 2 bosses | Core build loop, part hunting, synergy system, basic workshop | 3–6 months (solo) |
| **Vertical Slice** | 1 full zone + 1 partial zone | Blueprint crafting, rival NPC | 6–9 months (solo) |
| **Alpha** | 3 zones, ~80 parts, 5 bosses | All core systems, rough content | 9–15 months (solo) |
| **Full Vision** | 6–8 zones, 200+ parts, 10+ bosses | All systems polished, iOS release | 1–3 years (solo with AI) |

---

## Next Steps

**Path B — Prototype-First** (recommended: the core mechanic of "build your own creature" is unproven at this scale)

- [ ] Run `/setup-engine` to pin Godot 4.6 and populate version-aware reference docs
- [ ] Run `/prototype symbot-build-loop` — validate that assembling Symbots from parts is more satisfying than catching; 1–3 days throwaway build
- [ ] If prototype PROCEEDS: Run `/art-bible` to establish visual identity before writing any GDDs
- [ ] Run `/map-systems` to decompose the concept into individual systems with dependencies
- [ ] Author per-system GDDs with `/design-system [system-name]` using prototype learnings
- [ ] Plan architecture with `/create-architecture`
- [ ] Run `/architecture-review` to bootstrap TR registry and Requirements Traceability Matrix
- [ ] Run `/gate-check pre-production` before committing to production sprints
