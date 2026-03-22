# 仙途 (Xiān Tú) — Path of Immortality

A xianxia-themed roguelite dungeon crawler prototype built with Godot 4 and GDScript.

## Overview

Descend into ancient celestial ruins as a cultivator seeking immortality. Fight demons, collect spiritual treasures, unlock techniques, and advance through cultivation realms. The current repository is a playable Godot game prototype with a dungeon run, combat loop, progression systems, and UI already wired together.

**Genre:** Roguelite Dungeon Crawler  
**Theme:** Xianxia (Chinese Cultivation / Immortal Fantasy)  
**Engine:** Godot 4.6 (Forward Plus)  
**Language:** GDScript  
**Presentation:** 3D gameplay with stylized xianxia UI and VFX

## Current State

Implemented or partially implemented systems in the current codebase:

- **Combat loop** — auto-battle with manual override, skill usage, cooldowns, crits, dodge, floating damage numbers, and combat VFX
- **Dungeon flow** — multi-room runs with room progression, boss rooms, treasure rooms, ambush rooms, boon selection, and HUD updates
- **Player progression** — cultivation realms/stages, spiritual roots, stat scaling, starter skills, SP regeneration, unlocks, and run stats
- **Loot and economy** — equipment generation, loot tables, spirit stone currency, merchant stock generation, buy/sell flow, and contract scaffolding
- **UI layer** — HUD, inventory, tooltips, pause menu, death screen, boss victory panel, settings, unlock notifications, and spirit root selection
- **Persistence** — versioned save/load through `user://savegame.json`, including run-state restore for continue flow and menu-level corrupt-save messaging

Some systems are still scaffolded with placeholder content or TODOs, especially around deeper economy content, balancing, and full meta-progression.

## Running The Project

1. Install [Godot 4.6](https://godotengine.org/download)
2. Open [project.godot](project.godot) in the Godot editor
3. Press `F5` to run

CLI option:

```bash
godot --path /Users/tiankaixie/Local/game
```

## Entry Flow

- The configured main scene is `res://scenes/ui/MainMenu.tscn`
- The project boots into the title screen first
- A title screen exists at `res://scenes/ui/MainMenu.tscn`
- New Game from the title screen routes through `SpiritRootSelection.tscn` before entering the main run
- Continue loads save data and then enters the main run scene

## Project Structure

```text
├── project.godot          # Godot project config and autoload singletons
├── README.md
├── GDD.md                 # Game design document
├── assets/                # Imported art, audio, textures, materials
├── assets_download/       # Raw downloaded asset packs and source material
├── scenes/
│   ├── Main.tscn          # Primary gameplay / dungeon run scene
│   ├── dungeon/           # Room layouts and dungeon scenes
│   ├── enemies/           # Enemy scene definitions
│   ├── npc/               # Merchant scene(s)
│   ├── player/            # Player scene
│   ├── ui/                # Menus, HUD, inventory, notifications
│   └── vfx/               # Visual effects scenes
└── scripts/
    ├── Main.gd
    ├── combat/           # Combat loop and damage logic
    ├── core/             # Global state, save/load, player data, audio, unlocks
    ├── dungeon/          # Room progression, atmosphere, room management
    ├── enemies/          # Enemy behaviors and variants
    ├── npc/              # Merchant interactions
    ├── player/           # Character controller and input
    ├── systems/          # Equipment, loot, boons, buffs, trading
    ├── ui/               # UI controllers
    └── vfx/              # Runtime VFX scripts
```

## Important Autoloads

Configured in [project.godot](project.godot):

- `GameManager`
- `PlayerData`
- `SkillDatabase`
- `CombatSystem`
- `BuffSystem`
- `LootTable`
- `BoonDatabase`
- `TradeSystem`
- `AudioManager`
- `RunStats`
- `RunHistory`
- `UnlockSystem`
- `EquipmentSystem`

These singletons carry most of the game state and cross-scene systems.

## Development Notes

- There is currently no automated test suite or CI configuration in the repository
- Validation is primarily done by running scenes in Godot and exercising gameplay flows manually
- A lightweight automated main-flow check is available via `scripts/test/run_main_flow_checks.sh`
- GdUnit HTML/XML reports are written under `reports/gdunit/`
- [GDD.md](GDD.md) remains the main high-level design reference, but parts of the implementation have moved ahead of the README and parts of the GDD

## Testing

Run the current automated checks:

```bash
scripts/test/run_main_flow_checks.sh
```

This currently runs:

- A headless smoke test covering `MainMenu -> SpiritRootSelection -> Main`
- GdUnit scene tests for startup flow (`MainMenu`, `New Game`, `Continue`) and legacy save migration
- GdUnit corrupt-save handling test covering `MainMenu -> Continue -> error prompt`
- GdUnit run-end scene tests covering death flow and dungeon-completion return flow
- GdUnit pause/return tests covering `Main -> Pause -> MainMenu -> Continue -> Main`, including repeated roundtrips

## License

TBD
