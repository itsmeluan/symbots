# Visual Entity & Screen Inventory

> **Generated**: 2026-07-17
> **Scope**: MVP (1 zone, 2 bosses)
> **Sources**: `design/gdd/systems-index.md` + 19 Approved MVP GDDs, `design/art/art-bible.md`
> (§3.3/§3.7/§3.8 shape, §5 character, §6 environment, §8 asset standards),
> `design/ux/` (battle, hud, main-menu, pause, interaction-patterns)
>
> Status legend: **Needed** = identified, no asset spec yet · **Specced** = `/asset-spec` done · **In Production** · **Done**

---

## Entities

| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| 1 | The Mechanic | Character | Player avatar — human engineer. Overworld walk-sprite (Pokémon-style), shown at the Oficina bench + battle-intro cameo. Customization = Masc/Fem + simple color/palette. **No combat stats** — cosmetic/narrative identity only; world-palette, lower saturation than any Symbot. | art-bible §5.1–5.2 | **Specced** (ASSET-001…003 · `specs/mechanic-assets.md`) |
| 2 | Player Symbot / Build | Character | The combat character, assembled from 6 slots. All progression lives here (CORE levels on battle-XP; parts carry stats). **CORE is render-invisible in play** (Workshop/UI-only sphere). | art-bible §5.1/§5.3, symbot-assembly.md | Needed |
| 3 | Parts — silhouette slots | Part-family | Render family per slot × rarity × faction for CHASSIS / HEAD / ARMS / LEGS / WEAPON (the four silhouette-extending slots + weapon). Modular part-render pipeline; each must change the outline when broken (Principle 4). | part-database.md, art-bible §3.3/§8.1 | Needed |
| 4 | Parts — internal slots | Part-family | CHIPSET / ENERGY_CELL = flush-embedded (must not compete for the eye); CORE = render-invisible. | art-bible §3.7/§5.3 | Needed |
| 5 | Faction surface vocabularies | Style-set | 4 manufacturer shape vocabularies: Ironclad / Boltwell / Scrapjaw / wild-junk. **Placeholder labels** (Smoothshell/Hardform/Wirework/Fluxform) pending narrative rename **before faction art production**. | art-bible §3.8 | Needed |
| 6 | Wild Symbots | Enemy | WILD enemy class (~8 in MVP roster). Assembled from breakable break-regions; drop break-gated parts. | enemy-database.md | Needed |
| 7 | Boss Symbots | Enemy / Boss | 2 bosses (Boss 1 @ WIN_COUNT 6, Boss 2 @ 10). Carry BOSS-grade exclusive parts. | encounter-zone.md, enemy-database.md | Needed |
| 8 | Crystalline zone vocabulary | Environment | Faceted mineral growth, sharp geodes, refractive veins; cool teal/violet tint; "energy crystallized — Volt-adjacent, ancient." | art-bible §6.5 | Needed |
| 9 | Vegetation zone vocabulary | Environment | Trailing overgrowth, root-cabling, reclaimed hulls; W-1 Ironmoss green; "nature winning — machines absorbed back." | art-bible §6.5 | Needed |
| 10 | Industrial-Debris zone vocabulary | Environment | Angular wreckage, standardized panels, spent chassis; gunmetal + crimson hazard; "prior bots fought and fell here." | art-bible §6.5 | Needed |
| 11 | Terrain patches | Environment | Terrain-keyed spawn sub-pools (terrain = enemy-targeting lever). | encounter-zone.md | Needed |
| 12 | World-loot nodes | Prop | Static chests + hidden loot in the overworld (no completion markers per anti-pillar). | world-loot.md | Needed |
| 13 | Debris storytelling props | Prop | Half-buried spent chassis / broken parts — "others came before"; rewards looking (discovery = the reward). | art-bible §6.5 | Needed |
| 14 | Consumable icons | Item icons | 6 items: Repair Kit, Coolant Flush, Power Cell, Salvage Beacon, Signal Jammer, Scrap Lure. | consumable-database.md | Needed |
| 15 | Scrap currency icon | Item icon | The one persistent overworld number; icon + integer readout. | inventory.md, world-loot.md | Needed |

## VFX / Particles

| # | Name | Description | Source | Status |
|---|------|-------------|--------|--------|
| 16 | Part-break effect | Central emotional beat; the broken part's silhouette leaves the outline. Must stay <3 flashes/sec. | part-break.md, a11y §1.4 | Needed |
| 17 | Enrage / break-escalation telegraph | Visual state-change telegraphing enrage (non-color signal required). | turn-based-combat.md | Needed |
| 18 | Elemental hit effects | Volt / Thermal / Kinetic hit sparks + type-effectiveness cue. | damage-formula.md | Needed |
| 19 | Status effect visuals | Shock / Burn / Stagger — icon + text label in HUD, not only a sprite tint. | a11y §1.3, turn-based-combat.md | Needed |
| 20 | Synergy activation "click" | Beat 3 — synergy activation requires visual + audio confirmation. | synergy-system.md | Needed |
| 21 | Victory / Defeat / Overheat beats | Distinct visual indicators (audio-independent per a11y §4.1). | art-bible §2.4/§2.5, turn-based-combat.md | Needed |

## UI Screens

| # | Screen Name | Description | Source | Status |
|---|-------------|-------------|--------|--------|
| 22 | Main Menu (Title) | Session front door — Continue / New Game / Settings / Quit(Mac). | `design/ux/main-menu.md` | Specced (UX — /ux-review APPROVED) |
| 23 | Pause Menu | In-session hub/escape hatch; overworld-hub + battle-minimal variants. | `design/ux/pause.md` | Specced (UX — /ux-review APPROVED) |
| 24 | Battle / Combat | The core combat screen (PG-01…09). | `design/ux/battle.md` | Specced (UX — /ux-review APPROVED) |
| 25 | Workshop / Build | Equip/unequip, live stats, synergy indicators, preview delta, core level + XP bar. | systems-index #18 (workshop.md) | Needed (UX spec) |
| 26 | Inventory | Build-relevance organization (slot/rarity/family); scrap-confirm, batch-scrap, stack-full. | systems-index #11 (inventory UX) | Needed (UX spec) |
| 27 | World Map | Zone graph, player location, zone status, boss-gate WIN_COUNT readouts. | systems-index #20 (world-map.md) | Needed (UX spec) |
| 28 | Overworld / Navigation | Avatar movement through zone tiles; encounter trigger. | systems-index #16 (overworld) | Needed (UX spec) |
| 29 | Settings | Volume sliders (Master/Music/SFX), large-text toggle; shared from Main Menu + Pause. | systems-index #22 (settings.md) | Needed (UX spec) |
| 30 | Victory results overlay | Post-battle rewards + per-core XP / level-up / bench over-level line. | hud.md OQ2, symbot-core-progression.md | Needed (UX spec) |
| 31 | Defeat screen | Battle-lost surface. | hud.md OQ2, art-bible §2.5 | Needed (UX spec) |

## HUD Elements

| # | Element | Description | Source | Status |
|---|---------|-------------|--------|--------|
| 32 | Overworld HUD set | Scrap readout, ☰ menu affordance, active-modifier chip, zone-name flash, reward-reveal popup, refusal toast. | `design/ux/hud.md` | Specced (UX — /ux-review APPROVED); art Needed |
| 33 | Combat HUD set | Structure/Energy/Heat bars, break pips, enrage indicator, status badges, turn-order ribbon, move panel, target list, event log (fading-corner-text chrome). | `design/ux/battle.md` (PG-01…09) | Specced (UX); art Needed |

## Audio (descriptions only — no generation prompts)

| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| 34 | Combat SFX | SFX | Attack, hit, part-break "crack", overheat — each with a visual equivalent (a11y §4.1). | systems-index #21, turn-based-combat.md | Needed |
| 35 | UI + event stings | SFX | Synergy-activation click, Victory/Defeat stings, UI tap/confirm/refusal sounds. | synergy-system.md, a11y §4.1 | Needed |
| 36 | Ambient + music | Music/Ambient | Overworld ambient per zone vocabulary; battle + boss music. MVP = basic SFX; full music/adaptive = Alpha. | systems-index #21 | Needed (MVP basic) |

---

## Next steps

- Run `/ux-design [screen]` for each **Needed (UX spec)** screen: workshop, inventory, world-map, overworld, settings, victory-overlay, defeat.
- Run `/asset-spec system:[name]` or `/asset-spec character:[name]` to spec each visual entity's art + generation prompts (anchored to art-bible §8 Asset Standards).
- Run `/asset-spec` again to work through this inventory one item at a time.
- **Blocker to clear before faction art**: the 4 faction names (art-bible §3.8) — narrative team owes the rename.
