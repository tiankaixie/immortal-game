# 灰烬远征 (Ashenfall)
## Game Design Document v0.1

---

## 1. Game Overview & Vision

**Title:** 灰烬远征 (Ashenfall)  
**Genre:** Dark Fantasy Roguelite Dungeon Crawler  
**Engine:** Godot 4.x (GDScript)  
**Platforms:** PC (Windows/Mac/Linux), Mobile (iOS/Android), Steam Deck  
**Art Style:** 3D animated, grim and grounded — think Vindictus-inspired dark fantasy mixed with Hades readability  
**Target Audience:** Fans of roguelites (Hades, Dead Cells), dark action RPGs, and fast boss-driven combat  

### Elevator Pitch
A dark fantasy roguelite where you play as a hunter descending into ruined keeps and abyss-touched vaults. Each run, you explore procedurally-generated dungeon floors, fight corrupted knights and monsters, collect relics, and climb through a martial rank ladder. Death sends you back to camp, but your power growth and key rewards persist. The core fantasy: **Vindictus-style momentum and weight inside a "one more run" roguelite structure.**

### Reference Games
- **Hades / Hades II** — Meta-progression, narrative between runs, room-by-room choice structure, boon system
- **Dead Cells** — Fluid combat, biome progression, weapon variety, cells-as-currency meta-progression
- **Vindictus** — Tone target for brutal fantasy combat, armor, and boss presentation
- **Dark Souls / Elden Ring** — Ruined-world atmosphere, enemy silhouette readability, oppressive spaces
- **Diablo IV** — Dark UI palette, material treatment, and loot presentation
- **Moonlighter** — Shop/trade system between dungeon runs (major inspiration for trading system)

### Design Pillars
1. **Relentless Dark Fantasy** — Ruined strongholds, cursed relics, steel, bone, blood, and ash
2. **Satisfying Combat Loop** — Auto-battle as the default with manual skill override for depth
3. **Meaningful Progression** — Every run advances your combat rank; death is a setback, not a reset
4. **Heavy Visual Identity** — Iron, ember, parchment, and cathedral-lighting instead of ethereal cultivation motifs

---

## 2. Core Game Loop

```
┌─────────────────────────────────────────────────┐
│               WAR CAMP (营地要塞)                 │
│  Refit → Trade → Equip → Choose Expedition       │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│           DUNGEON EXPEDITION (废域远征)            │
│                                                   │
│  Enter Region → Choose Path → Combat/Event →      │
│  Loot → Claim Blessing → ... → Region Boss →      │
│  Advance Deeper → ... → Final Tyrant              │
│                                                   │
│  [Death] → Return to Camp with partial spoils     │
│  [Victory] → Return to Camp with full rewards     │
└─────────────────────────────────────────────────┘
```

### Run Structure
- Each expedition has **5 regions** with increasing difficulty
- Each floor has **8-12 rooms** arranged in a branching path (Hades-style fork)
- Room types:
  - **Combat Zones** — Fight packs of corrupted infantry and beasts
  - **Elite Hunts** — Mini-boss encounter with guaranteed higher-tier drop
  - **Vaults** — Equipment/resource chest
  - **War Altars** — Claim one temporary battlefield blessing for the run
  - **Black Harbor Merchant** — Buy/sell mid-run
  - **Event Chambers** — Narrative choice events (risk/reward)
  - **Region Boss** — Required to advance

### Between Runs (Camp Bastion)
- **Command Table** — Spend renown to advance combat rank
- **Armory** — Manage and upgrade equipment
- **Trading Post** — Buy/sell with NPC merchants, fulfill contracts
- **Apothecary Bench** — Craft combat tonics and recovery items
- **War Archive** — Unlock new combat arts and tactics
- **Mercenary Contracts** — Side objectives for bonus rewards

---

## 3. Rank / Progression System

The long-term progression system is built around martial rank and combat sigils, not abstract XP bars alone. Each run pushes the player up a hunter hierarchy, unlocks new tools, and expands build options.

### Rank Ladder

Each major rank is divided into four field grades (I-IV) for steady, readable progression.

| # | Rank | Chinese | Dungeon Tier | Key Unlock |
|---|------|---------|-------------|------------|
| 1 | **Initiate Hunter** | 见习猎手 | Tutorial | Basic combat, 2 skill slots |
| 2 | **Veteran Mercenary** | 资深佣兵 | Tier 1 | Third skill slot |
| 3 | **Royal Knight** | 王国骑士 | Tier 2 | Auto-battle tuning |
| 4 | **Gryphon Guard** | 狮鹫卫士 | Tier 3 | Fourth skill slot |
| 5 | **Abyss Hunter** | 深渊猎手 | Tier 4 | Stronger relic pool |
| 6 | **Blacksteel Marshal** | 黑钢统领 | Tier 5 | Expanded starter loadout |
| 7 | **Sacred Champion** | 圣痕冠军 | Tier 6 | Fifth blessing slot |
| 8 | **Legendary Vanquisher** | 传奇征讨者 | Tier 7 | High-end contract access |
| 9 | **Godslayer** | 弑神者 | Endgame | Final ruin expedition |

### Advancement Mechanics
- **Campaign Renown** — Earned from combat, events, and completed expeditions. Accumulates toward the next field grade.
- **Rank Trials** — At major rank thresholds, face a special boss or scenario:
  - A unique encounter that tests your current combat style
  - Failure does not wipe permanent progress, but it blocks the next rank unlock
  - Better gear and sharper blessing choices make trials easier
- **Combat Sigils** — Permanent character trait chosen at the start of a new campaign:
  - **Iron Sigil** — Bonus to weapon damage and guard-break
  - **Thorn Sigil** — Bonus to sustain and bleed-oriented techniques
  - **Frost Sigil** — Bonus to control, defense, and chill effects
  - **Ember Sigil** — Bonus to area damage and burn effects
  - **Stone Sigil** — Bonus to HP, stagger resistance, and shielding
  - **Rare Sigils:** Storm, Abyss, and other unlockable variants

### Persistence Rules
- **Permanent:** Rank progression, chosen combat sigil, unlocked techniques, camp upgrades
- **Per-Run:** Equipment found in the expedition, temporary blessings, and run-only buffs
- **Partial Persist:** Gold and key materials can persist through death, while certain equipped items can be bound and kept

---

## 4. Combat System

### Philosophy
Auto-battle is the PRIMARY mode — the game plays itself competently. Player intervention is about **optimization and clutch moments**, not constant button mashing. Think: gacha auto-battle meets Hades skill expression.

### Auto-Battle Mode
- Character automatically attacks nearest enemy with basic attack chain
- Automatically uses skills when off cooldown (priority configurable)
- Automatically dodges telegraphed attacks (at reduced efficiency vs manual)
- Player can **override at any time** by tapping/clicking skills or movement

### Manual Override
- **Movement:** Direct character movement (WASD/joystick)
- **Skill Activation:** Manually time skills for optimal moments
- **Dodge/Dash:** i-frame dodge with cooldown (manual dodge is more effective than auto)
- **Ultimate (大招):** Charged ability that requires manual activation

### Combat Stats
- **HP (生命)** — Health points, scales with rank growth and sturdier sigils
- **Mana (魔力)** — Skill resource, regenerates over time
- **Attack (攻击)** — Base damage
- **Defense (防御)** — Damage reduction
- **Speed (机动)** — Movement and attack speed
- **Fortune (战运)** — Drop rate, critical chance, event outcomes

### Skill System
- **Skill Slots:** Start with 2, unlock up to 6 at higher ranks
- **Skill Types:**
  - **Attack Skills** — Direct damage, execution moves, and weapon finishers
  - **Movement Skills** — Dash, blink, gap closers
  - **Defensive Skills** — Shields, parry, absorption
  - **Support Skills** — Buffs, debuffs, summons
- **Skill Sources:**
  - War Archive (permanent unlocks)
  - Dungeon drops (per-run only, like Hades battlefield blessings)
  - Equipment-granted skills

### Enemy Types
- **Corrupted Infantry** — Fallen soldiers and castle guards warped by abyssal rot
- **Raiders & Fanatics** — Human enemies using brutal melee and ranged tricks
- **Abyss-Touched Beasts** — Fast monsters built around pounce, poison, or pack pressure
- **Relic Guardians** — Arcane constructs and cathedral defenses
- **Calamity Incarnations** — Elemental and curse-born encounters used in rank trials

### Boss Design
- Each dungeon has a **theme boss** tied to its lore
- Bosses have phases, each phase escalating in complexity
- Bosses can be farmed for specific rare drops
- Floor bosses are mini-bosses; final boss is a full multi-phase encounter

---

## 5. Equipment System

### Equipment Slots
| Slot | Name | Chinese | Primary Stat |
|------|------|---------|-------------|
| Weapon | Main Weapon | 主武器 | Attack |
| Armor | Chest Armor | 胸甲 | Defense |
| Accessory 1 | Relic Charm | 遗物坠饰 | Varies |
| Accessory 2 | Mercenary Ring | 佣兵戒指 | Varies |
| Talisman | Battle Sigil | 战印护符 | Special Effect |

### Rarity Tiers
| Tier | Name | Chinese | Color | Drop Rate |
|------|------|---------|-------|----------|
| 1 | Crude | 粗制 | White | 45% |
| 2 | Forged | 精铸 | Green | 30% |
| 3 | Rare | 稀有 | Blue | 15% |
| 4 | Epic | 史诗 | Purple | 7% |
| 5 | Legendary | 传奇 | Gold | 2.5% |
| 6 | Mythic | 神话 | Crimson | 0.5% |

### Equipment Mechanics
- **Random Affixes:** Each piece rolls 1-4 random bonus stats based on rarity
- **Set Bonuses:** Themed equipment sets grant bonuses (e.g., "Blacksteel Vanguard" 3-piece: +20% mana and stagger power)
- **Reforging:** Spend materials to upgrade equipment stats
- **Binding:** Permanently keep one piece of equipment per run (even on death)
- **Equipment Skills:** Higher-rarity equipment may grant unique active/passive skills

---

## 6. Trading System

### Overview
Trading is a between-runs system centered around the **Trading Post** in the war camp, with occasional NPC merchants in dungeons.

### Trading Post (Camp Bastion)
- **NPC Merchants** with rotating stock (refreshes after each run)
- **Gold Economy:**
  - Gold — primary currency, dropped in dungeons
  - Monster Cores — rare currency for premium purchases
- **Buy:** Equipment, consumables, crafting materials, skill scrolls
- **Sell:** Excess equipment, dungeon materials, rare drops
- **Price Fluctuation:** Prices vary based on supply/demand simulation
  - Selling lots of one material → price drops
  - Not selling for many runs → price rises
  - Creates light economic strategy

### Dungeon Merchants (Mid-Run)
- Appear in NPC Merchant rooms
- Sell consumables, temporary buffs, and occasionally rare equipment
- Accept gold only (no barter)
- Stock is random and run-specific

### Contracts System
- **Mercenary Contracts:** NPCs request specific items; fulfilling grants bonus rewards
- **Traveling Merchant Requests:** Rare NPCs offer exceptional trades for specific rare items
- Creates a "shopping list" motivation for dungeon runs

### Future Expansion: Player Trading
- Multiplayer trading between players (post-launch feature)
- Auction House for rare equipment
- NOT in MVP scope

---

## 7. Art Direction

### Visual Identity
- **3D Animated Style** — Semi-realistic anime action RPG. Think Korean action MMO silhouettes with Hades readability.
- **Color Palette:**
  - Primary: Iron black, charred brown, ash gray
  - Accent: Old gold, dried blood crimson, ember orange
  - Environment: Smoke, cathedral shafts, torchlight, ashfall, damp stone
- **Character Design:**
  - Leather, steel, layered cloth, and worn heraldry
  - Strong silhouette readability over ornamental excess
  - Weapon trails and skill effects with sparks, dust, frost shards, and cinder bursts

### Environment Design
- **Camp Bastion:** A battered keep, field forges, canvas tents, and torchlit stone corridors
- **Dungeon Biomes:**
  - **Collapsed Keeps** — Crumbling battlements, hanging chains, shattered statues
  - **Abyssal Vaults** — Dark undercroft chambers, sacrificial altars, corrupted roots
  - **Frozen Cathedrals** — Frosted nave spaces, cracked stained glass, holy ruins
  - **Blighted Wilds** — Dead woods, marsh rot, prowling beasts
  - **Forge Depths** — Lava vents, blacksteel anvils, smoke-belching furnaces

### UI Design
- Inspired by iron plaques, stitched leather folios, field ledgers, and scorched parchment
- Progress shown as rank plates, expedition bars, and relic slots rather than mystical energy diagrams
- Health/mana bars styled as forged metal channels with ember-lit fills
- Inventory/equipment screen presented like a mercenary loadout table

### Audio Direction
- **Music:** Low strings, war drums, choirs, and bleak fantasy ambience
- **Combat:** Dynamic layering that escalates from tense exploration to heavy melee pressure
- **Ambient:** Wind through ruins, chain rattles, forge fire, distant chanting
- **SFX:** Heavy impacts, shield scrapes, monster roars, relic pulses, and chest clanks

---

## 8. Godot 4 Technical Architecture

### Project Structure
```
project.godot
├── scenes/
│   ├── main/
│   │   ├── MainMenu.tscn
│   │   ├── SectHub.tscn
│   │   └── DungeonRun.tscn
│   ├── combat/
│   │   ├── CombatArena.tscn
│   │   ├── Enemy.tscn
│   │   └── Player.tscn
│   ├── ui/
│   │   ├── HUD.tscn
│   │   ├── Inventory.tscn
│   │   ├── CultivationScreen.tscn
│   │   └── TradeScreen.tscn
│   └── dungeon/
│       ├── Room.tscn (base room)
│       ├── rooms/ (room variants)
│       └── DungeonMap.tscn
├── scripts/
│   ├── core/
│   │   ├── GameManager.gd (autoload singleton)
│   │   ├── PlayerData.gd (autoload singleton)
│   │   ├── SaveSystem.gd
│   │   └── EventBus.gd (signal-based event system)
│   ├── combat/
│   │   ├── CombatSystem.gd
│   │   ├── AutoBattleAI.gd
│   │   ├── SkillManager.gd
│   │   └── DamageCalculator.gd
│   ├── systems/
│   │   ├── EquipmentSystem.gd
│   │   ├── TradeSystem.gd
│   │   ├── CultivationSystem.gd
│   │   ├── LootTable.gd
│   │   └── DungeonGenerator.gd
│   └── entities/
│       ├── BaseEntity.gd
│       ├── PlayerController.gd
│       └── EnemyAI.gd
├── assets/
│   ├── ui/
│   ├── characters/
│   ├── environments/
│   ├── sfx/
│   └── music/
└── data/
    ├── equipment.json
    ├── skills.json
    ├── enemies.json
    ├── rank_progression.json
    └── loot_tables.json
```

### Autoload Singletons
- **GameManager** — Game state, scene transitions, save/load coordination
- **PlayerData** — Player stats, rank state, inventory (persistent data)
- **EventBus** — Global signal bus for decoupled communication

### Key Technical Decisions
1. **3D with CharacterBody3D** for player/enemies (not 2D — fits art direction)
2. **Procedural dungeon** via room-based scene instancing (not tile-based)
3. **Resource-based data** — Equipment, skills, enemies defined as Godot Resources for editor integration
4. **State Machine pattern** for combat states (idle, attacking, dodging, using_skill, stunned)
5. **Signal-based event system** — Loose coupling between systems
6. **JSON data files** for game balance tuning (not hardcoded)
7. **Export templates** configured for all target platforms from the start

---

## 9. Milestone Roadmap

### Phase 0: Foundation (Months 1-2) ← **CURRENT**
- [x] GDD complete
- [x] Godot project structure
- [ ] Core singletons (GameManager, PlayerData, EventBus)
- [ ] Basic 3D player movement + camera
- [ ] Single test room with placeholder art
- [ ] Basic attack/combat prototype

### Phase 1: Core Combat (Months 2-3)
- [ ] Full combat system (auto-battle + manual override)
- [ ] 3 enemy types with basic AI
- [ ] Skill system (3 skills)
- [ ] Health/mana systems
- [ ] Basic HUD

### Phase 2: Dungeon Loop (Months 3-4)
- [ ] Procedural dungeon generation (room-based)
- [ ] Room types (combat, treasure, event, merchant, boss)
- [ ] Floor progression (5 floors)
- [ ] 1 complete dungeon biome
- [ ] Run start/end flow

### Phase 3: Progression Systems (Months 4-5)
- [ ] Rank system (first 4 major ranks)
- [ ] Equipment system (drop, equip, compare)
- [ ] Loot tables and drop rates
- [ ] Camp Bastion (basic)
- [ ] Save/Load system

### Phase 4: Economy & Polish (Months 5-6)
- [ ] Trading Post
- [ ] Apothecary Bench (crafting)
- [ ] Equipment reforging
- [ ] UI polish (grim dark-fantasy aesthetic)
- [ ] Sound effects + placeholder music
- [ ] Balance pass

### Phase 5: Alpha Release (Month 6)
- [ ] 1 complete dungeon (5 floors, 1 biome)
- [ ] 4 major ranks playable
- [ ] 10+ enemy types + 3 bosses
- [ ] Full equipment system
- [ ] Trading system
- [ ] Tutorial / onboarding
- [ ] Alpha testing

### Post-Alpha (Months 7-12)
- Additional dungeon biomes
- Remaining rank tiers
- Multiplayer co-op (stretch goal)
- Player trading (stretch goal)
- Mobile optimization + touch controls
- Steam/App Store submissions

---

## 10. Open Questions & Future Decisions

1. **Multiplayer?** — Co-op dungeon runs would be amazing but complex. Defer to post-alpha.
2. **Gacha elements?** — NO gacha/pay-to-win. Premium = cosmetics only if monetized.
3. **Story depth?** — How much narrative between runs? Hades has a LOT. Start light, expand.
4. **Difficulty scaling?** — Per-run difficulty modifiers? Ascension system like Slay the Spire?
5. **Pet/companion system?** — War hounds, ravens, or summoned relic spirits? Appealing, but scope creep.
6. **Camp management?** — Recruit NPCs, expand the bastion, unlock vendors? Maybe post-launch expansion.

---

*Document created: 2026-03-06*  
*Version: 0.1 — Initial Design*  
*Author: Auto-generated scaffold — to be iterated by development team*
