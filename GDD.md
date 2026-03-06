# 仙途 (Xiān Tú) — Path of Immortality
## Game Design Document v0.1

---

## 1. Game Overview & Vision

**Title:** 仙途 (Xiān Tú) — Path of Immortality  
**Genre:** Xianxia Roguelite Dungeon Crawler  
**Engine:** Godot 4.x (GDScript)  
**Platforms:** PC (Windows/Mac/Linux), Mobile (iOS/Android), Steam Deck  
**Art Style:** 3D animated, ethereal/elegant (唯美画风) — think Genshin Impact meets Hades, NOT pixel art or chibi  
**Target Audience:** Fans of roguelites (Hades, Dead Cells), xianxia/cultivation fiction, and action RPGs  

### Elevator Pitch
A xianxia-themed roguelite where you play as a cultivator descending into ancient celestial ruins (洞天秘境). Each run, you explore procedurally-generated dungeon floors, fight demons and rogue cultivators, collect spiritual treasures, and advance your cultivation realm. Death sends you back to your mountain sect, but your cultivation progress and key treasures persist. The core fantasy: **the power progression of xianxia novels meets the "one more run" loop of Hades.**

### Reference Games
- **Hades / Hades II** — Meta-progression, narrative between runs, room-by-room choice structure, boon system
- **Dead Cells** — Fluid combat, biome progression, weapon variety, cells-as-currency meta-progression
- **Amazing Cultivation Simulator** — Deep cultivation system, sect management, Chinese fantasy authenticity
- **Black Myth: Wukong** — Visual benchmark for 3D Chinese mythology action games
- **Genshin Impact** — Art style reference for ethereal 3D aesthetic, elemental combat interactions
- **Moonlighter** — Shop/trade system between dungeon runs (major inspiration for trading system)

### Design Pillars
1. **Authentic Xianxia Fantasy** — Cultivation realms, spiritual roots, Daoist philosophy, tribulations
2. **Satisfying Combat Loop** — Auto-battle as the default with manual skill override for depth
3. **Meaningful Progression** — Every run advances your cultivation; death is a setback, not a reset
4. **Elegant Aesthetics** — Beautiful, atmospheric, NOT cartoony — ink wash influences, particle effects, flowing robes

---

## 2. Core Game Loop

```
┌─────────────────────────────────────────────────┐
│                  SECT (Hub)                       │
│  Cultivate → Trade → Equip → Choose Dungeon      │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│              DUNGEON RUN (洞天秘境)               │
│                                                   │
│  Enter Floor → Choose Room → Combat/Event →       │
│  Loot → Choose Next Room → ... → Floor Boss →     │
│  Advance to Next Floor → ... → Final Boss         │
│                                                   │
│  [Death] → Return to Sect with partial rewards    │
│  [Victory] → Return to Sect with full rewards     │
└─────────────────────────────────────────────────┘
```

### Run Structure
- Each dungeon (秘境) has **5 floors** with increasing difficulty
- Each floor has **8-12 rooms** arranged in a branching path (Hades-style fork)
- Room types:
  - **Combat Rooms** (战斗) — Fight waves of enemies
  - **Elite Rooms** (精英) — Mini-boss with guaranteed rare drop
  - **Treasure Rooms** (宝库) — Equipment/resource chest
  - **Cultivation Rooms** (修炼室) — Temporary cultivation boost for the run
  - **NPC Merchant** (行商) — Buy/sell mid-run
  - **Event Rooms** (机缘) — Narrative choice events (risk/reward)
  - **Floor Boss** (守关者) — Required to advance

### Between Runs (Sect Hub)
- **Meditation Chamber** — Spend cultivation XP to advance realms
- **Equipment Hall** — Manage and upgrade equipment
- **Trading Post** — Buy/sell with NPC merchants, fulfill contracts
- **Pill Refinery** (丹房) — Craft consumables from dungeon materials
- **Library Pavilion** (藏经阁) — Unlock new combat techniques/skills
- **Sect Missions** — Side objectives for bonus rewards

---

## 3. Cultivation / Progression System

The cultivation system IS the leveling system. Instead of generic levels, players advance through authentic xianxia cultivation realms.

### Cultivation Realms (修炼境界)

Each realm has 9 minor stages (初期/中期/后期/巅峰 simplified to Early/Mid/Late/Peak for gameplay).

| # | Realm | Chinese | Lifespan | Dungeon Tier | Key Unlock |
|---|-------|---------|----------|-------------|------------|
| 1 | **Qi Condensation** | 练气期 | 100 years | Tutorial | Basic combat, 2 skill slots |
| 2 | **Foundation Establishment** | 筑基期 | 200 years | Tier 1 | Spiritual root abilities, 3 skill slots |
| 3 | **Core Formation** | 结丹期 | 500 years | Tier 2 | Golden Core powers, auto-battle unlock |
| 4 | **Nascent Soul** | 元婴期 | 1000 years | Tier 3 | Soul projection, 4 skill slots |
| 5 | **Soul Transformation** | 化神期 | 2000 years | Tier 4 | Domain abilities |
| 6 | **Void Refinement** | 炼虚期 | 5000 years | Tier 5 | Spatial manipulation |
| 7 | **Body Integration** | 合体期 | 10000 years | Tier 6 | Full body transformation |
| 8 | **Mahayana** | 大乘期 | 50000 years | Tier 7 | Heavenly techniques |
| 9 | **Tribulation Transcendence** | 渡劫期 | Immortal | Endgame | Ascension dungeon |

### Advancement Mechanics
- **Cultivation XP (修为)** — Earned from combat, events, meditation. Accumulates toward next stage.
- **Bottleneck Tribulations (瓶颈/天劫)** — At realm transitions (e.g., Qi Condensation → Foundation), face a special challenge:
  - A unique boss fight representing your tribulation
  - Failure doesn't kill you but resets progress toward that breakthrough
  - Higher-quality spiritual roots = easier tribulations
- **Spiritual Roots (灵根)** — Permanent character trait chosen at start:
  - **Metal (金)** — Bonus to attack, sharp/cutting techniques
  - **Wood (木)** — Bonus to healing, growth/nature techniques  
  - **Water (水)** — Bonus to defense, ice/flow techniques
  - **Fire (火)** — Bonus to AoE damage, flame techniques
  - **Earth (土)** — Bonus to HP/stamina, shield/stone techniques
  - **Special Roots:** Lightning (雷), Void (空), etc. — unlockable rare variants

### Persistence Rules
- **Permanent:** Cultivation realm/stage, spiritual root, unlocked techniques, sect upgrades
- **Per-Run:** Equipment found in dungeon, temporary buffs, currency (spirit stones)
- **Partial Persist:** 50% of spirit stones kept on death, equipment can be "soul-bound" to keep

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
- **HP (气血)** — Health points, scales with cultivation and Earth root
- **Spiritual Power (灵力)** — Mana equivalent, regenerates over time
- **Attack (攻击)** — Base damage
- **Defense (防御)** — Damage reduction
- **Speed (身法)** — Movement and attack speed
- **Luck (气运)** — Drop rate, critical chance, event outcomes

### Skill System
- **Skill Slots:** Start with 2, unlock up to 6 at higher realms
- **Skill Types:**
  - **Attack Skills** — Direct damage (sword art, palm strike, etc.)
  - **Movement Skills** — Dash, teleport, flight
  - **Defensive Skills** — Shields, parry, absorption
  - **Support Skills** — Buffs, debuffs, summons
- **Skill Sources:**
  - Library Pavilion (permanent unlocks)
  - Dungeon drops (per-run only, like Hades boons)
  - Equipment-granted skills

### Enemy Types
- **Demonic Beasts (妖兽)** — Creatures corrupted by demonic qi
- **Rogue Cultivators (散修)** — Human enemies with cultivation abilities
- **Demon Cultivators (魔修)** — Dark path cultivators
- **Ancient Guardians (上古守卫)** — Mechanical/spiritual dungeon defenses
- **Heavenly Tribulation (天劫)** — Lightning/elemental forces during breakthroughs

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
| Weapon | Spirit Weapon | 法器/灵剑 | Attack |
| Armor | Spirit Robe | 法袍 | Defense |
| Accessory 1 | Spirit Pendant | 灵佩 | Varies |
| Accessory 2 | Spirit Ring | 灵戒 | Varies |
| Talisman | Protection Talisman | 护身符 | Special Effect |

### Rarity Tiers
| Tier | Name | Chinese | Color | Drop Rate |
|------|------|---------|-------|----------|
| 1 | Mortal | 凡品 | White | 45% |
| 2 | Spirit | 灵品 | Green | 30% |
| 3 | Treasure | 宝品 | Blue | 15% |
| 4 | Earth | 地品 | Purple | 7% |
| 5 | Heaven | 天品 | Gold | 2.5% |
| 6 | Immortal | 仙品 | Red/Rainbow | 0.5% |

### Equipment Mechanics
- **Random Affixes:** Each piece rolls 1-4 random bonus stats based on rarity
- **Set Bonuses:** Themed equipment sets grant bonuses (e.g., "Jade Emperor's Regalia" 3-piece: +20% spiritual power)
- **Refinement (炼化):** Spend materials to upgrade equipment stats
- **Soul-Binding (认主):** Permanently keep one piece of equipment per run (even on death)
- **Equipment Skills:** Higher-rarity equipment may grant unique active/passive skills

---

## 6. Trading System

### Overview
Trading is a between-runs system centered around the **Trading Post (坊市)** in the Sect Hub, with occasional NPC merchants in dungeons.

### Trading Post (Sect Hub)
- **NPC Merchants** with rotating stock (refreshes after each run)
- **Spirit Stone Economy:**
  - Spirit Stones (灵石) — primary currency, dropped in dungeons
  - High-Grade Spirit Stones — rare currency for premium purchases
- **Buy:** Equipment, consumables, crafting materials, skill scrolls
- **Sell:** Excess equipment, dungeon materials, rare drops
- **Price Fluctuation:** Prices vary based on supply/demand simulation
  - Selling lots of one material → price drops
  - Not selling for many runs → price rises
  - Creates light economic strategy

### Dungeon Merchants (Mid-Run)
- Appear in NPC Merchant rooms
- Sell consumables, temporary buffs, and occasionally rare equipment
- Accept spirit stones only (no barter)
- Stock is random and run-specific

### Contracts System
- **Sect Contracts (宗门任务):** NPCs request specific items; fulfilling grants bonus rewards
- **Traveling Merchant Requests:** Rare NPCs offer exceptional trades for specific rare items
- Creates a "shopping list" motivation for dungeon runs

### Future Expansion: Player Trading
- Multiplayer trading between players (post-launch feature)
- Auction House for rare equipment
- NOT in MVP scope

---

## 7. Art Direction

### Visual Identity
- **3D Animated Style** — Stylized but NOT chibi or pixel. Think anime-influenced 3D like Genshin Impact but with more ink-wash (水墨) influence
- **Color Palette:**
  - Primary: Deep blues, jade greens, misty whites
  - Accent: Gold, crimson, spiritual purple
  - Environment: Atmospheric fog, volumetric lighting, particle effects (spiritual qi)
- **Character Design:**
  - Flowing robes, elegant movement animations
  - Cultivation realm reflected in visual aura (higher realm = more dramatic effects)
  - Weapon trails and skill effects with calligraphy-inspired particles

### Environment Design
- **Sect Hub:** Mountain peak sect with traditional Chinese architecture, cloud sea backdrop
- **Dungeon Biomes:**
  - **Ancient Ruins (上古遗迹)** — Crumbling stone, glowing runes, overgrown with spiritual plants
  - **Demonic Abyss (魔渊)** — Dark, corrupted, red/purple qi, twisted terrain
  - **Celestial Palace (天宫)** — Floating platforms, golden light, heavenly aesthetics
  - **Spirit Beast Forest (灵兽森林)** — Dense canopy, bioluminescence, nature spirits
  - **Volcanic Forge (地火熔炉)** — Lava, smithing aesthetics, Earth-element theme

### UI Design
- Inspired by traditional Chinese scrolls and jade tablets
- Cultivation progress shown as a **dantian visualization** (energy core with swirling qi)
- Health/mana bars styled as spirit jade bars
- Inventory/equipment screen on a silk scroll background

### Audio Direction
- **Music:** Chinese traditional instruments (guqin, erhu, dizi) blended with modern orchestral
- **Combat:** Dynamic layering — peaceful exploration transitions to intense battle music
- **Ambient:** Wind, water, temple bells, spiritual qi hum
- **SFX:** Satisfying combat impacts, cultivation breakthrough sounds, treasure chest chimes

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
    ├── cultivation_realms.json
    └── loot_tables.json
```

### Autoload Singletons
- **GameManager** — Game state, scene transitions, save/load coordination
- **PlayerData** — Player stats, cultivation, inventory (persistent data)
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
- [ ] Health/spiritual power systems
- [ ] Basic HUD

### Phase 2: Dungeon Loop (Months 3-4)
- [ ] Procedural dungeon generation (room-based)
- [ ] Room types (combat, treasure, event, merchant, boss)
- [ ] Floor progression (5 floors)
- [ ] 1 complete dungeon biome
- [ ] Run start/end flow

### Phase 3: Progression Systems (Months 4-5)
- [ ] Cultivation system (first 4 realms)
- [ ] Equipment system (drop, equip, compare)
- [ ] Loot tables and drop rates
- [ ] Sect Hub (basic)
- [ ] Save/Load system

### Phase 4: Economy & Polish (Months 5-6)
- [ ] Trading Post
- [ ] Pill Refinery (crafting)
- [ ] Equipment refinement
- [ ] UI polish (Chinese aesthetic)
- [ ] Sound effects + placeholder music
- [ ] Balance pass

### Phase 5: Alpha Release (Month 6)
- [ ] 1 complete dungeon (5 floors, 1 biome)
- [ ] 4 cultivation realms playable
- [ ] 10+ enemy types + 3 bosses
- [ ] Full equipment system
- [ ] Trading system
- [ ] Tutorial / onboarding
- [ ] Alpha testing

### Post-Alpha (Months 7-12)
- Additional dungeon biomes
- Remaining cultivation realms
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
5. **Pet/companion system?** — Spirit beasts as companions? Popular in xianxia but scope creep.
6. **Sect management?** — Recruit NPCs, build sect? Maybe post-launch expansion.

---

*Document created: 2026-03-06*  
*Version: 0.1 — Initial Design*  
*Author: Auto-generated scaffold — to be iterated by development team*
