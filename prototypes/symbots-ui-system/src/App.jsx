import React, { useMemo, useState } from "react";
import {
  ArrowLeft,
  ArrowRight,
  BatteryCharging,
  Check,
  CheckCircle,
  Circuitry,
  Coins,
  Crosshair,
  FastForward,
  Gear,
  Heartbeat,
  Lightning,
  Lock,
  MapTrifold,
  Pause,
  Play,
  Shield,
  Sparkle,
  Star,
  Sword,
  Target,
  TreeStructure,
  Trophy,
  UsersThree,
  Wrench,
} from "@phosphor-icons/react";
import "@fontsource/ibm-plex-mono/400.css";
import "@fontsource/ibm-plex-mono/600.css";
import "@fontsource/rajdhani/600.css";
import battleBg from "../../../assets/art/battle/battle_arena_background.png";
import mapBg from "../../../assets/art/overworld/map_background.png";
import workshopBg from "../../../assets/art/workshop/bench_backdrop.png";
import panelTexture from "../../../assets/art/ui/hud/ui_panel_frame_general.png";
import buttonTexture from "../../../assets/art/ui/buttons/ui_btn_generic_normal.png";
import primaryButtonTexture from "../../../assets/art/ui/buttons/ui_btn_primary_normal.png";
import voltfang from "../../../assets/art/symbots/voltfang_mk1.png";
import nanoweave from "../../../assets/art/symbots/nanoweave_mk1.png";
import ironmaul from "../../../assets/art/symbots/ironmaul_mk1.png";
import coilsprite from "../../../assets/art/symbots/coilsprite_mk1.png";
import rustcrawler from "../../../assets/art/symbots/rustcrawler_mk1.png";
import boltshell from "../../../assets/art/symbots/boltshell_mk1.png";
import hexcircuit from "../../../assets/art/symbots/hexcircuit_mk1.png";
import solderfly from "../../../assets/art/symbots/solderfly_mk1.png";

const roleIcons = {
  DPS: Sword,
  TANK: Shield,
  HEAL: Heartbeat,
  SUPP: Circuitry,
};

const allies = [
  { id: "voltfang", name: "VOLTFANG", role: "DPS", level: 12, hp: 862, maxHp: 962, sprite: voltfang },
  { id: "nanoweave", name: "AERISPRITE", role: "HEAL", level: 11, hp: 738, maxHp: 738, sprite: nanoweave },
  { id: "ironmaul", name: "IRONCLAD", role: "TANK", level: 11, hp: 1124, maxHp: 1124, sprite: ironmaul },
  { id: "coilsprite", name: "SCUTTLE", role: "SUPP", level: 10, hp: 676, maxHp: 676, sprite: coilsprite },
];

const enemies = [
  { id: "rustcrawler", name: "RUSTCRAWLER", role: "TANK", level: 10, hp: 1563, maxHp: 1563, sprite: rustcrawler },
  { id: "boltshell", name: "BOLTSHELL", role: "TANK", level: 10, hp: 1280, maxHp: 1280, sprite: boltshell },
  { id: "hexcircuit", name: "SCRAPDART", role: "SUPP", level: 9, hp: 842, maxHp: 842, sprite: hexcircuit },
  { id: "solderfly", name: "SPARKMITE", role: "DPS", level: 9, hp: 1450, maxHp: 1450, sprite: solderfly },
];

const roster = [
  ...allies,
  { id: "boltshell-b", name: "BOLTSHELL", role: "TANK", level: 9, hp: 790, maxHp: 790, sprite: boltshell },
  { id: "hexcircuit-b", name: "HEXCIRCUIT", role: "SUPP", level: 8, hp: 640, maxHp: 640, sprite: hexcircuit },
  { id: "solderfly-b", name: "SOLDERFLY", role: "HEAL", level: 8, hp: 612, maxHp: 612, sprite: solderfly },
];

const skills = [
  { id: "basic", name: "BASIC", sub: "STRIKE", damage: "38–44", icon: Sword, state: "ready" },
  { id: "arc", name: "ARC LASH", sub: "62–74", damage: "62–74", icon: Lightning, state: "ready" },
  { id: "disrupt", name: "DISRUPT", sub: "COOLDOWN", damage: "—", icon: Circuitry, state: "cooldown", cooldown: 2 },
  { id: "surge", name: "SURGE", sub: "READY", damage: "48–58", icon: Sparkle, state: "ready" },
];

const stages = [
  { id: 1, name: "GREENWAKE RELAY", type: "CLEAR", state: "cleared", fights: 1 },
  { id: 2, name: "RUSTED VERGE", type: "CLEAR", state: "cleared", fights: 1 },
  { id: 3, name: "STATIC GARDENS", type: "DUNGEON", state: "active", fights: 3 },
  { id: 4, name: "FOUNDRY SPINE", type: "RAID", state: "locked", fights: 1 },
  { id: 5, name: "THE LONG CIRCUIT", type: "ENDLESS", state: "locked", fights: 0 },
];

const partRows = [
  { id: "core", label: "CORE", level: 18, stat: "+42 POWER", cost: 320, Icon: BatteryCharging },
  { id: "chassis", label: "CHASSIS", level: 17, stat: "+96 STRUCTURE", cost: 290, Icon: Shield },
  { id: "head", label: "HEAD", level: 16, stat: "+18 PROCESSING", cost: 260, Icon: Circuitry },
  { id: "arms", label: "ARMS", level: 18, stat: "+31 ATTACK", cost: 320, Icon: Sword },
  { id: "legs", label: "LEGS", level: 15, stat: "+14 SPEED", cost: 235, Icon: FastForward },
];

function IconLabel({ Icon, children }) {
  return (
    <span className="icon-label">
      <Icon aria-hidden="true" weight="bold" />
      {children}
    </span>
  );
}

function Meter({ value, max, tone = "ally", label }) {
  const width = Math.max(0, Math.min(100, (value / max) * 100));
  return (
    <div className={`meter meter--${tone}`} aria-label={label ?? `${value} of ${max}`}>
      <span style={{ width: `${width}%` }} />
    </div>
  );
}

function TopBar({ title, subtitle, onBack, right }) {
  return (
    <header className="screen-topbar">
      {onBack ? (
        <button className="icon-button" type="button" onClick={onBack} aria-label="Back to map">
          <ArrowLeft weight="bold" />
        </button>
      ) : (
        <div className="brand-mark" aria-hidden="true"><Gear weight="fill" /></div>
      )}
      <div className="screen-heading">
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      <div className="topbar-right">{right}</div>
    </header>
  );
}

function BattleUnit({ unit, side, active, selected, hpOverride, onSelect }) {
  const RoleIcon = roleIcons[unit.role];
  const currentHp = hpOverride ?? unit.hp;
  return (
    <button
      className={`battle-unit battle-unit--${side} ${active ? "is-active" : ""} ${selected ? "is-selected" : ""}`}
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      aria-label={`${unit.name}, level ${unit.level}, ${unit.role}, ${currentHp} structure`}
    >
      <div className="unit-nameplate tech-panel">
        <div className="unit-line">
          <strong>{unit.name}</strong>
          <span>Lv.{unit.level}</span>
        </div>
        <div className="unit-meta">
          <IconLabel Icon={RoleIcon}>{unit.role}</IconLabel>
          {side === "enemy" && unit.role === "TANK" && <span className="taunt-mini"><Shield weight="fill" /> TAUNT</span>}
        </div>
        <Meter value={currentHp} max={unit.maxHp} tone={side === "ally" ? "ally" : "enemy"} />
        <span className="hp-copy">{currentHp} / {unit.maxHp}</span>
      </div>
      <div className="unit-sprite-wrap">
        <img className="unit-sprite" src={unit.sprite} alt="" />
        {selected && <Crosshair className="target-brackets" aria-hidden="true" weight="thin" />}
      </div>
    </button>
  );
}

function BattleScreen({ onFinish, onExit }) {
  const [selectedSkill, setSelectedSkill] = useState("arc");
  const [targetId, setTargetId] = useState("rustcrawler");
  const [auto, setAuto] = useState(false);
  const [targetHp, setTargetHp] = useState(enemies[0].hp);
  const [log, setLog] = useState("VOLTFANG is ready. Select a command.");
  const selected = skills.find((skill) => skill.id === selectedSkill) ?? skills[1];
  const selectedTarget = enemies.find((enemy) => enemy.id === targetId) ?? enemies[0];

  const execute = () => {
    if (selected.state === "cooldown") return;
    const damage = selected.id === "basic" ? 42 : selected.id === "surge" ? 54 : 68;
    const next = Math.max(0, targetHp - damage * 6);
    setTargetHp(next);
    setLog(`VOLTFANG used ${selected.name} · ${damage * 6} STRUCTURE`);
    if (next === 0) window.setTimeout(onFinish, 450);
  };

  return (
    <section className="screen battle-screen" aria-label="Battle command screen">
      <header className="battle-header tech-panel">
        <button className="round-control" type="button" onClick={onExit} aria-label="Leave battle prototype">
          <ArrowLeft weight="bold" /> <span>ROUND 2/3</span>
        </button>
        <div className="turn-order" aria-label="Turn order">
          <span>TURN ORDER</span>
          <div className="turn-icons">
            {[allies[0], allies[1], allies[2], enemies[0], enemies[1]].map((unit, index) => (
              <div className={`turn-token ${index === 0 ? "is-current" : ""}`} key={`${unit.id}-${index}`}>
                <img src={unit.sprite} alt={unit.name} />
              </div>
            ))}
          </div>
        </div>
        <button className={`auto-toggle ${auto ? "is-on" : ""}`} type="button" onClick={() => setAuto((value) => !value)} aria-pressed={auto}>
          {auto ? <Pause weight="fill" /> : <FastForward weight="fill" />}
          <span>AUTO</span>
          <small>{auto ? "ON" : "OFF"}</small>
        </button>
      </header>

      <div className="battlefield" style={{ backgroundImage: `url(${battleBg})` }}>
        <div className="battle-lanes">
          {allies.map((ally, index) => {
            const enemy = enemies[index];
            return (
              <div className="battle-lane" key={ally.id}>
                <BattleUnit unit={ally} side="ally" active={index === 0} />
                <div className="lane-divider" aria-hidden="true"><span>{index + 1}</span></div>
                <BattleUnit
                  unit={enemy}
                  side="enemy"
                  selected={targetId === enemy.id}
                  hpOverride={index === 0 ? targetHp : undefined}
                  onSelect={() => enemy.role === "TANK" && setTargetId(enemy.id)}
                />
              </div>
            );
          })}
        </div>
      </div>

      <div className="action-preview tech-panel">
        <div>
          <span className="eyebrow">SELECTED ACTION</span>
          <strong>{selected.name} <b>· {selected.damage}</b></strong>
          <small>Target: <em>{selectedTarget.name}</em></small>
        </div>
        <div className="taunt-callout">
          <Shield weight="fill" aria-hidden="true" />
          <span><strong>TAUNT ACTIVE</strong><small>Tanks must be targeted.</small></span>
        </div>
      </div>

      <div className="command-deck">
        <div className="actor-strip">
          <img src={voltfang} alt="Voltfang" />
          <div><strong>VOLTFANG</strong><span>DPS · Mk I · Lv.12</span></div>
          <div className="command-log" aria-live="polite">{log}</div>
        </div>
        <div className="skill-grid" role="group" aria-label="Skills">
          {skills.map((skill) => {
            const SkillIcon = skill.icon;
            return (
              <button
                className={`skill-button ${selectedSkill === skill.id ? "is-selected" : ""} ${skill.state === "cooldown" ? "is-disabled" : ""}`}
                type="button"
                key={skill.id}
                onClick={() => skill.state !== "cooldown" && setSelectedSkill(skill.id)}
                aria-pressed={selectedSkill === skill.id}
                disabled={skill.state === "cooldown"}
              >
                <SkillIcon weight={selectedSkill === skill.id ? "fill" : "bold"} aria-hidden="true" />
                <strong>{skill.name}</strong>
                <span>{skill.sub}</span>
                {skill.cooldown && <b className="cooldown-badge">{skill.cooldown}</b>}
              </button>
            );
          })}
        </div>
        <div className="ultimate-row tech-panel">
          <div className="ultimate-name"><Lightning weight="fill" /><span><strong>STORMBREAKER</strong><small>ULTIMATE</small></span></div>
          <div className="ult-meter"><Meter value={72} max={100} tone="ultimate" label="Ultimate charge 72 percent" /></div>
          <strong className="ult-value">72%</strong>
        </div>
        <div className="execute-row">
          <button className="primary-action" type="button" onClick={execute}>
            <Target weight="bold" /> EXECUTE
          </button>
          <button className="secondary-action" type="button" onClick={() => setSelectedSkill("basic")}>
            BACK
          </button>
        </div>
        <div className="battle-hints" aria-hidden="true">
          <span><Target /> SELECT SKILL</span><ArrowRight /><span><Crosshair /> CONFIRM TARGET</span><ArrowRight /><span><Sword /> EXECUTE</span>
        </div>
      </div>
    </section>
  );
}

function BottomDock({ active, onNavigate }) {
  const items = [
    ["map", MapTrifold, "MAP"],
    ["workshop", Wrench, "WORKSHOP"],
    ["squad", UsersThree, "SQUAD"],
    ["tree", TreeStructure, "TREE"],
  ];
  return (
    <nav className="bottom-dock" aria-label="Game sections">
      {items.map(([id, Icon, label]) => (
        <button className={active === id ? "is-active" : ""} key={id} type="button" onClick={() => onNavigate(id)} aria-current={active === id ? "page" : undefined}>
          <Icon weight={active === id ? "fill" : "bold"} />
          <span>{label}</span>
        </button>
      ))}
    </nav>
  );
}

function StageMapScreen({ onNavigate, onBattle }) {
  const [selectedStage, setSelectedStage] = useState(3);
  const stage = stages.find((item) => item.id === selectedStage) ?? stages[2];
  return (
    <section className="screen meta-screen map-screen">
      <TopBar
        title="STAGE MAP"
        subtitle="CAINOS FRONTIER · SECTOR 03"
        right={<div className="currency-pair"><IconLabel Icon={Gear}>12,450</IconLabel><IconLabel Icon={Coins}>820</IconLabel></div>}
      />
      <div className="map-field" style={{ backgroundImage: `url(${mapBg})` }}>
        <div className="map-path" aria-label="Stage progression">
          {stages.map((item) => {
            const locked = item.state === "locked";
            return (
              <button
                type="button"
                key={item.id}
                className={`stage-node stage-node--${item.state} ${selectedStage === item.id ? "is-selected" : ""}`}
                onClick={() => !locked && setSelectedStage(item.id)}
                disabled={locked}
              >
                <span className="stage-number">{item.state === "cleared" ? <Check weight="bold" /> : locked ? <Lock weight="fill" /> : item.id}</span>
                <span className="stage-copy"><strong>{item.name}</strong><small>{item.type}{item.fights > 1 ? ` · ${item.fights} FIGHTS` : ""}</small></span>
              </button>
            );
          })}
        </div>
        <aside className="stage-detail tech-panel">
          <span className="eyebrow">SELECTED STAGE</span>
          <h2>{stage.name}</h2>
          <div className="stage-tags"><span>LV. 10–12</span><span>{stage.type}</span><span>3 WAVES</span></div>
          <p>Hold structure across every fight. Rustcrawler tanks control the opening lanes.</p>
          <div className="reward-line"><Trophy weight="fill" /><span><small>FIRST CLEAR</small><strong>1,800 Scrap · Blueprint shard</strong></span></div>
          <button className="primary-action" type="button" onClick={onBattle}><Play weight="fill" /> DEPLOY SQUAD</button>
        </aside>
      </div>
      <BottomDock active="map" onNavigate={onNavigate} />
    </section>
  );
}

function WorkshopScreen({ onNavigate }) {
  const [selectedBot, setSelectedBot] = useState(allies[0]);
  const [scrap, setScrap] = useState(12450);
  const [levels, setLevels] = useState(() => Object.fromEntries(partRows.map((part) => [part.id, part.level])));
  const upgrade = (part) => {
    if (scrap < part.cost || levels[part.id] >= 20) return;
    setScrap((value) => value - part.cost);
    setLevels((current) => ({ ...current, [part.id]: current[part.id] + 1 }));
  };
  const ready = Object.values(levels).every((level) => level >= 20);
  return (
    <section className="screen meta-screen workshop-screen">
      <TopBar title="WORKSHOP" subtitle="PART LEVELLING" onBack={() => onNavigate("map")} right={<IconLabel Icon={Gear}>{scrap.toLocaleString()}</IconLabel>} />
      <div className="workshop-hero" style={{ backgroundImage: `url(${workshopBg})` }}>
        <img src={selectedBot.sprite} alt={selectedBot.name} />
        <div className="bot-identity tech-panel"><strong>{selectedBot.name}</strong><span>{selectedBot.role} · Mk I · LV.{selectedBot.level}</span></div>
        <div className="roster-switcher" role="group" aria-label="Select Symbot">
          {allies.map((bot) => <button key={bot.id} className={selectedBot.id === bot.id ? "is-selected" : ""} type="button" onClick={() => setSelectedBot(bot)}><img src={bot.sprite} alt={bot.name} /></button>)}
        </div>
      </div>
      <div className="workshop-body">
        <div className="section-title"><div><span className="eyebrow">MK I CAP · LEVEL 20</span><h2>UPGRADE PARTS</h2></div><span className="part-progress">{Object.values(levels).filter((level) => level >= 20).length}/5 MAX</span></div>
        <div className="part-list">
          {partRows.map((part) => {
            const level = levels[part.id];
            const maxed = level >= 20;
            return (
              <div className="part-row" key={part.id}>
                <div className="part-icon"><part.Icon weight="bold" /></div>
                <div className="part-copy"><strong>{part.label}</strong><span>LV. {level}/20 · {part.stat}</span><Meter value={level} max={20} tone="ally" /></div>
                <button type="button" onClick={() => upgrade(part)} disabled={maxed || scrap < part.cost}>{maxed ? <CheckCircle weight="fill" /> : <><Gear weight="fill" /> {part.cost}</>}</button>
              </div>
            );
          })}
        </div>
        <button className="retrofit-action" type="button" disabled={!ready}><Sparkle weight="fill" /><span><strong>RETROFIT TO MK II</strong><small>{ready ? "READY" : "MAX ALL 5 PARTS TO UNLOCK"}</small></span></button>
      </div>
      <BottomDock active="workshop" onNavigate={onNavigate} />
    </section>
  );
}

function SquadScreen({ onNavigate }) {
  const [squad, setSquad] = useState(allies);
  const [armedSlot, setArmedSlot] = useState(0);
  const fieldUnit = (unit) => {
    setSquad((current) => current.map((item, index) => index === armedSlot ? unit : item).filter((item, index, all) => all.findIndex((match) => match.id === item.id) === index));
    setArmedSlot((armedSlot + 1) % 4);
  };
  const roles = new Set(squad.map((unit) => unit.role));
  return (
    <section className="screen meta-screen squad-screen">
      <TopBar title="SQUAD" subtitle="ACTIVE FORMATION" onBack={() => onNavigate("map")} right={<span className="squad-count">{squad.length}/4</span>} />
      <div className="squad-slots" role="group" aria-label="Squad slots">
        {[0, 1, 2, 3].map((index) => {
          const unit = squad[index];
          const RoleIcon = unit ? roleIcons[unit.role] : UsersThree;
          return (
            <button type="button" className={armedSlot === index ? "is-armed" : ""} key={index} onClick={() => setArmedSlot(index)}>
              <span className="slot-index">0{index + 1}</span>
              {unit ? <img src={unit.sprite} alt={unit.name} /> : <UsersThree aria-hidden="true" />}
              <strong>{unit?.name ?? "EMPTY"}</strong>
              <small><RoleIcon weight="fill" /> {unit?.role ?? "OPEN SLOT"}</small>
            </button>
          );
        })}
      </div>
      <div className={`composition-check ${roles.has("TANK") && roles.has("HEAL") ? "is-good" : "is-warning"}`}>
        {roles.has("TANK") && roles.has("HEAL") ? <CheckCircle weight="fill" /> : <Shield weight="fill" />}
        <span><strong>{roles.has("TANK") && roles.has("HEAL") ? "FORMATION BALANCED" : "ROLE GAP DETECTED"}</strong><small>{roles.has("HEAL") ? "Tank and recovery coverage online." : "Add a healer before long dungeon runs."}</small></span>
      </div>
      <div className="bench-heading"><div><span className="eyebrow">SELECT SLOT {armedSlot + 1}</span><h2>ROSTER</h2></div><span>7 SYMBOTS</span></div>
      <div className="bench-list">
        {roster.map((unit) => {
          const RoleIcon = roleIcons[unit.role];
          const fielded = squad.some((item) => item.id === unit.id);
          return (
            <button type="button" className={fielded ? "is-fielded" : ""} key={unit.id} onClick={() => fieldUnit(unit)}>
              <img src={unit.sprite} alt="" />
              <span className="bench-unit-copy"><strong>{unit.name}</strong><small><RoleIcon weight="fill" /> {unit.role} · Mk I · LV.{unit.level}</small><Meter value={unit.level} max={20} tone="ally" label={`Level ${unit.level} of 20`} /></span>
              <span className="field-state">{fielded ? <><Check weight="bold" /> FIELD</> : <><ArrowRight weight="bold" /> ADD</>}</span>
            </button>
          );
        })}
      </div>
      <BottomDock active="squad" onNavigate={onNavigate} />
    </section>
  );
}

const treeNodes = [
  { id: "entry", label: "ENTRY", type: "entry", Icon: Star, x: 50, y: 88 },
  { id: "volt-1", label: "+8% VOLT", type: "stat", Icon: Lightning, x: 28, y: 67 },
  { id: "speed", label: "+12 SPEED", type: "stat", Icon: FastForward, x: 70, y: 66 },
  { id: "arc", label: "ARC LASH", type: "active", Icon: Sword, x: 20, y: 43 },
  { id: "socket", label: "CAPACITOR", type: "socket", Icon: BatteryCharging, x: 52, y: 45 },
  { id: "passive", label: "STATIC BLOOM", type: "passive", Icon: Circuitry, x: 79, y: 41 },
  { id: "ult", label: "STORMBREAKER", type: "ultimate", Icon: Lightning, x: 50, y: 17 },
];

function SkillTreeScreen({ onNavigate }) {
  const [selectedBot, setSelectedBot] = useState(allies[0]);
  const [selectedNode, setSelectedNode] = useState("arc");
  const [allocated, setAllocated] = useState(new Set(["entry", "volt-1", "arc"]));
  const [points, setPoints] = useState(4);
  const node = treeNodes.find((item) => item.id === selectedNode) ?? treeNodes[3];
  const allocate = () => {
    if (allocated.has(node.id) || points <= 0) return;
    setAllocated((current) => new Set([...current, node.id]));
    setPoints((value) => value - 1);
  };
  return (
    <section className="screen meta-screen tree-screen">
      <TopBar title="SKILL TREE" subtitle="ONE TREE · SIXTEEN DOORS" onBack={() => onNavigate("map")} right={<span className="points-badge"><Star weight="fill" /> {points} PTS</span>} />
      <div className="tree-roster" role="group" aria-label="Choose Symbot">
        {allies.map((unit) => <button type="button" key={unit.id} className={selectedBot.id === unit.id ? "is-selected" : ""} onClick={() => setSelectedBot(unit)}><img src={unit.sprite} alt={unit.name} /><span>{unit.name.slice(0, 5)}</span></button>)}
      </div>
      <div className="tree-canvas" aria-label="Voltfang skill tree">
        <div className="tree-door"><img src={selectedBot.sprite} alt="" /><span>{selectedBot.name}<small>VOLT DOOR · DPS</small></span></div>
        <div className="tree-lines" aria-hidden="true"><span className="line-a" /><span className="line-b" /><span className="line-c" /><span className="line-d" /><span className="line-e" /></div>
        {treeNodes.map((item) => {
          const NodeIcon = item.Icon;
          const owned = allocated.has(item.id);
          return (
            <button
              type="button"
              key={item.id}
              className={`tree-node tree-node--${item.type} ${selectedNode === item.id ? "is-selected" : ""} ${owned ? "is-owned" : ""}`}
              style={{ left: `${item.x}%`, top: `${item.y}%` }}
              onClick={() => setSelectedNode(item.id)}
              aria-pressed={selectedNode === item.id}
            >
              <NodeIcon weight={owned ? "fill" : "bold"} />
              <span>{item.label}</span>
            </button>
          );
        })}
      </div>
      <div className="node-detail tech-panel">
        <div className={`node-detail-icon node-detail-icon--${node.type}`}><node.Icon weight="fill" /></div>
        <div><span className="eyebrow">{node.type.toUpperCase()} NODE</span><h2>{node.label}</h2><p>{node.id === "arc" ? "Unlocks a focused Volt strike. High critical rate against a single target." : "Extends this Symbot's route through the shared machine tree."}</p></div>
        <button type="button" onClick={allocate} disabled={allocated.has(node.id) || points <= 0}>{allocated.has(node.id) ? <><Check weight="bold" /> OWNED</> : <>ALLOCATE · 1</>}</button>
      </div>
      <BottomDock active="tree" onNavigate={onNavigate} />
    </section>
  );
}

function RewardScreen({ onContinue }) {
  return (
    <section className="screen reward-screen" style={{ backgroundImage: `url(${battleBg})` }}>
      <div className="reward-shade" />
      <div className="reward-content">
        <div className="victory-mark"><Trophy weight="fill" /><span>STAGE CLEARED</span></div>
        <h1>VICTORY</h1>
        <p>STATIC GARDENS · 3/3 FIGHTS</p>
        <div className="reward-squad">
          {allies.map((unit) => <div key={unit.id}><img src={unit.sprite} alt={unit.name} /><span>+420 XP</span></div>)}
        </div>
        <div className="reward-ledger tech-panel">
          <div><Gear weight="fill" /><span><small>SCRAP RECOVERED</small><strong>+1,840</strong></span></div>
          <div><BatteryCharging weight="fill" /><span><small>CAPACITOR CHIP</small><strong>TIER II · ×1</strong></span></div>
          <div><Sparkle weight="fill" /><span><small>BLUEPRINT SHARD</small><strong>VOLTFANG · 1/6</strong></span></div>
        </div>
        <div className="level-up-callout"><Star weight="fill" /><span><strong>VOLTFANG REACHED LEVEL 13</strong><small>+1 SKILL POINT AVAILABLE</small></span></div>
        <button className="primary-action" type="button" onClick={onContinue}>RETURN TO MAP <ArrowRight weight="bold" /></button>
      </div>
    </section>
  );
}

export function App() {
  const [screen, setScreen] = useState("battle");
  const navigate = (next) => setScreen(next);
  const rootStyle = useMemo(() => ({
    "--panel-texture": `url(${panelTexture})`,
    "--button-texture": `url(${buttonTexture})`,
    "--primary-texture": `url(${primaryButtonTexture})`,
  }), []);

  let content;
  if (screen === "battle") content = <BattleScreen onFinish={() => navigate("reward")} onExit={() => navigate("map")} />;
  else if (screen === "map") content = <StageMapScreen onNavigate={navigate} onBattle={() => navigate("battle")} />;
  else if (screen === "workshop") content = <WorkshopScreen onNavigate={navigate} />;
  else if (screen === "squad") content = <SquadScreen onNavigate={navigate} />;
  else if (screen === "tree") content = <SkillTreeScreen onNavigate={navigate} />;
  else content = <RewardScreen onContinue={() => navigate("map")} />;

  return (
    <main className="prototype-stage" style={rootStyle}>
      <div className="mobile-prototype">{content}</div>
    </main>
  );
}
