# Shafted

A 2D top-down dungeon crawler built in **Godot 4.6** using **GDScript**. Players fight through procedurally generated dungeons, collect weapons, craft gear, and take on a golem boss to complete a run.

---

## Team
**Team Name**: _Capstoners_

**Group Members**: Kene Maduabum, Isaiah Shavers, Borui Zhang, Blade Hagman, Quinn McCollister, Dhruv Bhakta

---

## About

Shafted drops the player into a randomly generated dungeon layout each run. Rooms are stitched together at runtime using a random-walk algorithm that picks from a library of hand-crafted room scenes based on each room's required exits (corridors, dead ends, corners, three-ways, four-ways). The player navigates these rooms, defeats enemies, picks up weapons and augments, crafts gear at weapon crafting stations, and works toward a boss fight. Death resets the run but persistent progress stats are tracked across sessions.

---

## Technology

| Layer | Details |
|---|---|
| **Engine** | Godot 4.6 (Forward Plus renderer) |
| **Language** | GDScript |
| **Resolution** | 1280x920, integer-scaled viewport |
| **Audio** | Custom `AudioManager` autoload (WAV sfx + MP3 bgm) |
| **Persistence** | JSON save files via `save_manager` autoload (`user://`) |

---

## Project Structure

```
shafted-godot-project/
├── project.godot           # Engine config, input map, autoloads
├── Assets/                 # Sprites, tilesets, audio, shaders, UI resources
│   ├── audio/              # BGM (MP3) and SFX (WAV) organized by category
│   ├── Background/         # Industrial tileset backgrounds
│   ├── enemies/            # Golem variants, monster packs, dummy
│   ├── Player/             # Player sprites and augment icons
│   ├── Props/              # GDShader fade/darken effects
│   └── Tilesets/           # Master tileset and rock background
├── Enemy/                  # One folder per enemy type, each with .gd + .tscn
│   ├── Bomber/             # Drops bombs, explodes on death
│   ├── Flying/             # Fires projectiles, aerial movement
│   ├── GolemBoss/          # Boss with laser + arm-projectile attacks
│   ├── Grotto/             # Melee cave enemy
│   ├── Kamikaze/           # Rushes player and detonates
│   ├── Nester/             # Spawns smaller enemies
│   ├── Slug/               # Ground melee enemy
│   └── ...                 # Armored, Cat, Egg, Dummy
├── Scenes/
│   ├── characterScenes/    # Player (main_char.tscn) and base enemy scenes
│   ├── itemScenes/         # Augments, chests, vendors, weapon crafter
│   ├── room_scenes/        # All hand-crafted room templates (30+ rooms)
│   ├── generator_test_items/ # Dungeon generator script + loot table system
│   └── UI/                 # HUD, minimap, pause menu, death screen, start menu
├── Scripts/
│   ├── characterScripts/   # main_char.gd (player logic), enemy base
│   ├── weaponScripts/      # Weapon logic: sword, gun, shotgun, hammer, spear, launcher
│   ├── augmentScripts/     # Augment types and pickup areas
│   ├── controlScripts/     # Menus, loading screen, pause, death screen
│   ├── globalScripts/      # Autoload, save_manager, audio_manager
│   └── RoomFlippah/        # Room mirroring utility for layout variety
└── game_manager.gd         # Root scene: player lifecycle and level transitions
```

---

## How to Run

1. **Install Godot 4.6** from https://godotengine.org/download](https://godotengine.org/download/archive/4.6.2-stable/. Make sure you grab the standard (non-Mono/.NET) build unless you intend to use C# features.
2. **Open the project** — launch Godot, click **Import**, and navigate to `shafted-godot-project/project.godot`.
3. **Press F5** (or the Play button) to run from the Start Menu scene. The engine will import assets on first launch, which may take a moment.

No external dependencies, plugins, or additional installs are required.

---

## Controls

| Action | Input |
|---|---|
| Move | WASD |
| Aim + Attack | Mouse / Left Click |
| Dash | Space |
| Equip Weapon Slot 1 | `1` |
| Equip Weapon Slot 2 | `2` |
| Interact | `E` |
| Toggle Map | `M` |
| Pause | `Esc` |

---

## Key Features

**Procedural dungeon generation** — each run builds a unique map from a pool of 30+ room templates using a random-walk algorithm with configurable room count (5 to 10 rooms) and branching probability.

**Weapon system** — melee and ranged weapon slots with distinct attack logic for sword, hammer, spear, gun, shotgun, and launcher. Weapons are found in chests or crafted at weapon stations using collected resources.

**Augment system** — collectible stat modifiers that stack on the player (attack add, attack multiplier, health add, health multiplier, speed add).

**Enemy variety** — eight enemy archetypes each with unique AI: Bomber, Flying (ranged), Golem Boss (multi-phase with laser and arm projectiles), Grotto, Kamikaze, Nester, Slug, and Armored variants.

**Save system** — mid-run state (health, inventory, position, weapons, augments, resources) is saved to `user://current_run.json`. Deaths are tracked persistently in `user://player_progress.json` and wipe the current run file.

**Minimap** — in-game map toggled with `M` that reflects explored rooms.
