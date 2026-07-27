# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

"Lucy A luz do Amor" is a Godot 4.7 (Forward+ rendering, Jolt Physics) 3D game project. It is early-stage: the main scene, `char_test.tscn`, is currently a character-animation test ground rather than actual gameplay — it places Lucy and the NPCs side by side with UI buttons to preview each character's animation states.

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

- `models/` — game-specific FBX character/building models with baked textures, each rigged individually: the player character (`models/lucy/lucy_rigged.fbx`), NPCs under `models/npcs/` (`bella`, `giorgio`, `lucca`, `mario`, `mia`, `oscar`), and `buildings/cat_statue.fbx`.
- `animations/` — per-character FBX animation clips (e.g. `lucy_idle.fbx`, `bella_talk.fbx`, `giorgio_bubbles.fbx`). Each character owns its own clips baked on its own rig; they are not shared across characters.
- `demo/` and `demos/` — sample scenes and scripts bundled with the `terrain_3d` and `rubonnek.*` manager addons respectively (e.g. `demo/src/Player.gd`, `demo/src/Enemy.gd`, `demos/1. simple achievement/`, etc.). These are third-party addon documentation/examples, not part of this game's own code — don't confuse them with project game logic when searching for existing gameplay implementations.
- `char_test.tscn` — the project's main scene, used as an animation test ground for Lucy and the NPCs (see `characters/`, `tools/build_character_scenes.gd`, and `ui/animation_showcase_ui.gd`).
