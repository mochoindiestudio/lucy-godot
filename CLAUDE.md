# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

"Lucy A luz do Amor" is a Godot 4.7 (Forward+ rendering, Jolt Physics) 3D game project. It is early-stage: `game.tscn` is currently a single empty `Node3D` root, and there are no project-specific GDScript files yet outside of the installed addons. Character/NPC/building assets (`.fbx` models, animation clips) are in place under `models/` and `animations/` but not yet wired into scenes or scripts.

The project has no build step in the traditional sense — it is opened and run through the Godot editor.

## Running / editing the project

- Open with Godot 4.7 (the editor executable itself is not part of this repo).
- There is a `[dotnet]` section in `project.godot` declaring an assembly name, but no `.csproj` exists yet — C# is not currently set up despite the dialogue manager addon shipping optional `.cs` files.
- No test runner, linter, or CI config exists in this repo currently.

## Addons (all under `addons/`, managed as Godot editor plugins)

Enabled in `project.godot` under `[editor_plugins]`:

- **dialogue_manager** (Nathan Hoad, v3.10.5) — nonlinear dialogue system. Registered as the `DialogueManager` autoload singleton (`res://addons/dialogue_manager/...`). This is the only autoload in the project.
- **rubonnek.achievements_manager** (v1.0.2) — achievements tracking. Runtime code in `runtime/achievements_manager.gd`, `runtime/achievement_entry.gd`; not an autoload, used as a node.
- **rubonnek.inventory_manager** (v2.0.0) — inventory system. Runtime code in `runtime/inventory_manager.gd`, `runtime/item_registry.gd`, `runtime/excess_items.gd`; not an autoload, used as a node.
- **rubonnek.quest_manager** (v1.3.2) — quest tracking. Runtime code in `runtime/quest_manager.gd`, `runtime/quest_entry.gd`; not an autoload, used as a node.
- **sky_3d** (v2.1) — atmospheric day/night cycle system.
- **terrain_3d** (v1.0.2) — high-performance editable 3D terrain system.

Each of the three `rubonnek.*` managers ships a matching editor debugger panel under its `debugger/` folder (`*_viewer.gd`/`.tscn` + `editor_debugger_plugin.gd`) for inspecting state live in the Godot editor while the game runs.

## Directory structure notes

- `models/` — game-specific FBX character/building models with baked textures: the player character (`lucy.fbx`), NPCs (`bella`, `giorgio`, `mario`, `mia`, `oscar`, `spark`), and `buildings/cat_statue.fbx`.
- `animations/` — shared FBX animation clips (`idle`, `walking`, `slow_run`, `talking_1`, `talking_2`) intended to be applied across the character models above.
- `demo/` and `demos/` — sample scenes and scripts bundled with the `terrain_3d` and `rubonnek.*` manager addons respectively (e.g. `demo/src/Player.gd`, `demo/src/Enemy.gd`, `demos/1. simple achievement/`, etc.). These are third-party addon documentation/examples, not part of this game's own code — don't confuse them with project game logic when searching for existing gameplay implementations.
- `game.tscn` — the project's actual entry scene (currently just an empty `Node3D` named "Game").
