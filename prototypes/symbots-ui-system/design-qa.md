# Symbots v1 UI — Design QA

- Source visual truth: `/Users/martinsluan/.codex/generated_images/019f819a-3784-73f1-86c1-b6815d099a2c/exec-b6af1fca-f910-4aae-b279-2dd72298e442.png`
- Implementation screenshot: `/Volumes/SSDLuan/Projetos/symbots/prototypes/symbots-ui-system/qa/v1-battle-final-390x844.png`
- Viewport: 390 × 844 CSS px
- State: Round 2/3, Voltfang active, Arc Lash selected, Rustcrawler targeted, Auto off, ultimate at 72%
- Full-view comparison evidence: `/Volumes/SSDLuan/Projetos/symbots/prototypes/symbots-ui-system/qa/design-qa-comparison-pass1.png`
- Focused command-deck comparison evidence: `/Volumes/SSDLuan/Projetos/symbots/prototypes/symbots-ui-system/qa/design-qa-command-deck-pass1.png`

## Findings

No actionable P0, P1, or P2 differences remain.

- [P3] Production icon pass can get closer to the mock's bespoke glyph silhouettes.
  - Location: battle skill buttons, battle hint rail, meta-screen navigation.
  - Evidence: the source uses highly customized industrial glyphs; the implementation uses a consistent Phosphor icon family plus the project's existing game assets.
  - Impact: hierarchy and meaning are intact, but the final Godot asset pass can add more Symbots-specific personality.
  - Fix: replace the library glyphs with approved game icon textures when that production set exists, preserving icon-plus-text labels.

- [P3] The selected mock and prototype both use dense tertiary technical captions.
  - Location: turn-order label, HP numerals, battle hint rail, compact metadata.
  - Evidence: the source and implementation use intentionally compressed secondary type to keep all four combat lanes and the command deck visible at 390 × 844.
  - Impact: the default hierarchy is legible, but the shipping Godot UI still needs its approved +4pt large-text preset and on-device calibration.
  - Fix: retain the current default composition and validate the large-text theme variant against the project accessibility requirements before screen sign-off.

## Required fidelity surfaces

- Fonts and typography: IBM Plex Mono and Rajdhani reproduce the squared mono/condensed hierarchy; weights, truncation, and tabular numerals remain consistent. Battle unit names no longer overflow.
- Spacing and layout rhythm: the implementation matches the four paired lanes, compact turn-order header, action-preview bridge, actor strip, four-skill rail, ultimate meter, and bottom execute action. The 390 × 844 frame has no page overflow.
- Colors and visual tokens: cyan allies, coral enemies, amber commands, dark industrial surfaces, neutral structure, and green ready states match the source semantic palette without relying on color alone.
- Image quality and asset fidelity: the implementation uses the repository's battle environment, current v1 pixel-art Symbots, and existing UI textures. Sprites stay crisp with pixelated rendering and correct aspect ratios; no placeholder imagery or code-drawn asset substitutes are present.
- Copy and content: Arc Lash, Rustcrawler target, taunt rule, cooldown 2, Stormbreaker, 72% charge, and execute flow match the selected design and current v1 rules.
- Icons: one coherent library is used for standard UI actions; game-specific sprites and textures remain real raster assets.
- Accessibility and responsiveness: semantic buttons, visible focus styles, icon-plus-text states, reduced-motion support, minimum 44px primary touch controls, and fixed 390 × 844 fit are present. Shipping large-text calibration remains follow-up polish as noted above.

## Interaction verification

- Stage Map → Deploy Squad → Battle → Reward → Stage Map completed.
- Auto toggle changes pressed state.
- Skill selection updates the action preview.
- Execute reduces target Structure and resolves to Victory.
- Workshop upgrade consumes Scrap and raises a part level.
- Squad selection replaces the armed slot.
- Skill Tree allocation consumes a point and changes the node to Owned.
- Browser console checked for errors and warnings.

## Comparison history

### Pass 1

- Earlier findings: the first rendered capture used the existing blue primary button texture, while the source calls for an amber execute action; compact battle names also truncated too aggressively.
- Fixes made: replaced the primary CTA surface with a solid amber chamfered treatment, tightened the battle-name type settings, and removed the decorative CSS gradient from the skill-tree canvas.
- Post-fix evidence: `qa/design-qa-comparison-pass1.png` and `qa/design-qa-command-deck-pass1.png` show the corrected CTA hierarchy, stable four-lane proportions, readable battle labels, and matching command-deck anatomy.

## Follow-up polish

- Replace standard UI glyphs with the eventual production icon sheet.
- Validate the large-text theme and real-device point calibration in Godot.

final result: passed
