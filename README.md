# 仙途 (Xiān Tú) — Path of Immortality

A xianxia-themed roguelite dungeon crawler built with Godot 4.

## Overview

Descend into ancient celestial ruins as a cultivator seeking immortality. Fight demons, collect spiritual treasures, and advance through cultivation realms. Each death sends you back to your mountain sect — but your cultivation endures.

**Genre:** Roguelite Dungeon Crawler  
**Theme:** Xianxia (Chinese Cultivation/Immortal Fantasy)  
**Engine:** Godot 4.x (GDScript)  
**Art Style:** 3D animated, ethereal/elegant (唯美画风)

## Features (Planned)

- 🗡️ **Auto-Battle + Manual Override** — Competent auto-combat with skill expression on demand
- 🏔️ **Cultivation Progression** — 9 realms from Qi Condensation to Tribulation Transcendence
- ⚔️ **Equipment System** — 6 rarity tiers, random affixes, set bonuses
- 💰 **Trading System** — Sect marketplace with dynamic pricing
- 🏯 **Procedural Dungeons** — Branching room-based exploration across themed biomes

## Project Structure

```
├── GDD.md              # Game Design Document
├── scenes/             # Godot scene files
├── scripts/
│   ├── core/           # Singletons (GameManager, PlayerData)
│   ├── combat/         # Combat system, auto-battle AI
│   └── systems/        # Equipment, trading, cultivation
├── assets/
│   ├── ui/             # UI textures and themes
│   ├── characters/     # Character models and animations
│   ├── environments/   # Environment assets
│   ├── sfx/            # Sound effects
│   └── music/          # Background music
└── data/               # JSON balance data (future)
```

## Getting Started

1. Install [Godot 4.x](https://godotengine.org/download)
2. Open `project.godot` in Godot Editor
3. Run the project (F5)

## Development

See [GDD.md](GDD.md) for the full Game Design Document.

## License

TBD
