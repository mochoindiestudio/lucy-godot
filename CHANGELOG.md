# Changelog

All notable changes to this project will be documented in this file.

## [0.17.0] - 2026-08-05

### Added
- `Minimap` HUD component (`ui/components/minimap.tscn`/`.gd`): scrolls `assets/map.png` beneath a fixed player pin so the visible map always centers on Lucy. A `SubViewport` renders the scrolling map + pin, and a `SubViewportContainer` masked by `ui/components/minimap_mask_material.tres` (reusing the existing `fill_mask.gdshader` with `ui/images/minimap_mask.png`) clips it to the wreath frame's circular opening; `ui/images/minimap.png` sits on top as decoration. The pin is `ui/images/map_pin_icon.tres`, an `AtlasTexture` region of the first icon in `map_icons.png`. Scale (`map_pixels_per_world_unit`) is derived from the `terrain_data` region grid (4 regions of `region_size` 512, centered on the origin = 2048 world units) mapped onto the 1254px map image, and is exposed in the inspector along with a `flip_z` toggle for tuning against the live terrain.
- `UI` HUD layer in `scenes/game.scn` now also hosts the minimap, anchored to the bottom-right corner (30px margin). `ui/hud.gd` gained a `player_path` export and pushes the Player's `global_position` to the minimap every frame.

## [0.16.0] - 2026-08-05

### Added
- Reusable `LucyEnergyBar` HUD component (`ui/components/lucy_energy_bar.tscn`/`.gd`): layers the `lucy_indicator` portrait frame, `progressbar_track`/`progressbar_fill` art, and a happy/sad portrait swap (below a 30% threshold) driven purely by an exported `energy_percent` and two typed signals (`energy_changed`, `mood_changed`). The pink fill is clipped to the track's rounded interior via a small canvas shader (`ui/components/fill_mask.gdshader`) masked by `ui/images/progressbar-track-mask.png`, so only the growing/receding edge is a straight cut.
- `UI` HUD layer added to `scenes/game.scn`, hosting the energy bar anchored to the bottom-left corner (30px margin). `ui/hud.gd` wires it to the Player's existing `EnergyComponent` via an exported `NodePath`, so the bar tracks Lucy's real energy pool live.

### Changed
- Player prefab: added an always-on, script-less `OmniLight3D` for extra fill lighting on Lucy.

## [0.15.0] - 2026-08-05

### Added
- Playable `Player` prefab (`prefabs/player/player.tscn`, `player_controller.gd`): third-person camera-relative movement, mouse-orbit camera, raycast ground check, wraps the `Lucy` character scene.
- Lucy's firefly glow, `LoveLight` (`prefabs/player/love_light.gd`): an `OmniLight3D` that stays off until activated, flickers organically via seeded 1D Perlin noise (`flicker_enabled`/`flicker_speed`/`flicker_intensity`/`flicker_seed` knobs), and auto-shuts-off after a 15s `AutoOffTimer`. Triggered with the new `shine_light` input action (F key).
- Generic `EnergyComponent` (`prefabs/player/energy_component.gd`), a 0-100 energy pool (`max_energy`/`starting_energy` knobs) that `player_controller.gd` spends from (`shine_cost`, default 10) each time Lucy shines her light. `recover()` is exposed for future map recovery regions.
- Godot AI MCP addon (`addons/godot_ai/`) wired in for editor automation during development, plus `.vscode/settings.json` pointing the Godot Tools extension at the local editor executable.
- `prefabs/props/directions.tscn`.

### Changed
- Renamed `character_preview.gd` to `character_animator.gd` and gave every character's animation state machine (Lucy + all NPCs) a per-state `AnimationNodeTimeScale` node for tunable playback speed.
- Continued terrain painting and prop placement touch-ups (`terrain_data/*.res`, `scenes/game.scn`).

## [0.14.0] - 2026-08-04

### Added
- New `ship` prefab (`prefabs/buildings/ship.tscn`, `ship.gd`) with a subtle idle bob/roll/pitch so it reads as sitting on moving water, deliberately not synced to the ocean shader's actual wave height.
- Ship flags now wave in the wind. The model's flag meshes were split from the hull in `models/buildings/ship.glb`, and `ship.gd` applies `materials/ship_flag.gdshader` to any mesh node named like `flag`/`flag.001` — a copy of the ship's real material (via the editor's Convert to ShaderMaterial) with a single-axis vertex displacement added directly into it, anchored at the pole and reaching full strength at the tip.

### Changed
- Ship placed in `scenes/game.scn`.

### Added
- Building lamps (`prefabs/buildings/lamp.gd`, used by `lamp.tscn`, `lamp_post.tscn`, `wall_lamp_1.tscn`, `wall_lamp_2.tscn`) now turn on and off automatically with the day/night cycle, driven by the existing `Sky3D` node's `day_night_changed` signal. Works live in the editor viewport as well as at runtime (`@tool`), matching the `sky_3d` addon's own editor-time behavior.
- New `ship` building model under `models/buildings/`, with albedo/emissive/metallic-roughness/normal textures.

### Fixed
- `wall_lamp_1.tscn` had a bare, script-less `OmniLight3D` that stayed lit permanently; it's now wired through the same `lamp.gd` day/night logic as the other lamp prefabs, keeping its original light color/range/shadow settings.

### Changed
- Continued terrain painting and windmill placement touch-ups (`terrain_data/*.res`, `scenes/game.scn`, `prefabs/buildings/windmill.tscn`).

## [0.12.5] - 2026-08-04

### Removed
- Animation/scale-comparison test grounds (`scenes/char_test.tscn`, `scenes/building_test.tscn`, `scripts/char_test.gd`, `scripts/building_test.gd`) and their preview-scene generator scripts (`tools/build_character_scenes.gd`, `tools/build_building_scenes.gd`, `tools/build_windmill_scene.gd`), no longer needed now that the character/building previews they generated live under `prefabs/`.
- Duplicate `materials/instance_wind.gdshader`, already present under `addons/terrain_3d/extras/shaders/` and `models/nature/wind_materials/`.

### Changed
- `run/main_scene` in `project.godot` repointed from the retired `scenes/char_test.tscn` to `scenes/game.scn`.
- Reorganized character and building preview scenes from `characters/` and `buildings/` into `prefabs/characters/` and `prefabs/buildings/`.
- Adjusted the ocean shader's `sea_level` parameter (`addons/terrain_3d/extras/shaders/M_ocean.tres`).
- Continued terrain painting (`terrain_data/*.res`, `scenes/game.scn`).

### Added
- New building models under `models/buildings/` (`direction_signpost`, `directions_signpost`, `foot_bridge`, `pier`), each with albedo/emissive/metallic-roughness/normal textures.

## [0.12.4] - 2026-08-03

### Changed
- Realigned `config/version` to `0.12.4`, carrying over the version number from the project's prior Unity incarnation. This is now the baseline going forward instead of the `0.x.x` sequence started from scratch in Godot.
- Updated the `terrain_3d` addon, adding its native Vegetation Auto-Populator (`vegetation_populator.gd`, `vegetation_group(s).gd`) and Wind Applier (`wind_applier.gd`) editor tools, plus supporting shader/material assets (`instance_wind.gdshader`, `M_instance_wind_*.tres`, `T_wind_noise.tres`).
- Continued terrain painting (`terrain_data/*.res`, `scenes/game.scn`) and minor wind-material/mesh-import touch-ups.

## [0.4.3] - 2026-08-03

### Added
- New terrain ground texture set under `textures/` (`dark_grass`, `dark_mud`, `dirt_road`, `grass`, `grass_flowers`, `grass_road`, `mud`, `rock`, `sand`, each with albedo/height + normal/roughness maps).

### Changed
- Repainted the terrain's heightmap/control-map regions (`terrain_data/*.res`) and updated `scenes/game.scn` to use the new ground texture set.

## [0.4.2] - 2026-08-03

### Fixed
- Wind materials under `models/nature/wind_materials/` (copied in from another project) referenced a shader, a wind-noise texture, and 18 albedo/normal textures at paths and UIDs that didn't exist in this project (`res://addons/terrain_3d/extras/shaders/...`, `res://demo2/assets/models/...`). Repointed all 132 material files at their real locations under `models/nature/`, and copied the missing `T_wind_noise.tres` in from the source project.
- None of the 115 nature mesh `.gltf.import` files had a material override configured, so the wind materials were never actually applied to any mesh despite existing. Wired up `use_external` overrides for the 79 meshes that have a matching wind material (trees, bushes, flowers, grass, plants); rocks/pebbles/mushrooms/dead-tree bark are intentionally left on their plain materials. `CommonTree_1` had no dedicated wind material of its own, so it reuses `CommonTree_2`'s (same material names/textures).

### Changed
- Updated `scenes/game.scn`'s terrain to use the new nature meshes/wind materials.
- Removed the old placeholder ground textures (`grass_packed_*`, `gravel_packed_*`, `moss_packed_*`, `mossy_pavement_packed_*`, `paving_stones_packed_*`, `rock_packed_*`, `rocks_packed_*`, `sand_packed_*`) from `textures/`, superseded by the nature-based terrain materials.

## [0.4.1] - 2026-08-03

### Changed
- Cleared the `Terrain3D` node's asset library in `scenes/game.scn` (8 ground textures, 116 foliage mesh assets), leaving the terrain node and its heightmap/region data intact as a blank slate for revamping.

## [0.4.0] - 2026-07-28

### Added
- Building scale-comparison showcase (`scenes/building_test.tscn`, `scripts/building_test.gd`): houses, profession buildings, a cat statue, wall lamps, and a windmill laid out side by side with Lucy, reusing the character showcase's arrow-key stepping, spotlights, and handheld camera shake.
- `buildings/windmill.tscn`/`windmill.gd`: a dedicated windmill scene combining the static tower with a separately rotating rotor, exposing `rotation_speed_deg` as an Inspector variable.
- Per-item preview scenes under `buildings/` (`tools/build_building_scenes.gd`, `tools/build_windmill_scene.gd`), each resting its model's own bounding box on the floor instead of the source FBX's off-center pivot.
- Scale-aware camera and lighting: the showcase camera now derives its distance, height, and framing from each focused item's actual measured world-space bounds (accounting for skinned-mesh rigs and a light's range-based AABB as special cases) instead of one fixed shot, and the cross-lighting rig's offsets and spot range scale the same way. Items are also sorted by X position at runtime rather than by scene child order, so the lineup steps correctly even after being repositioned in the editor.

### Changed
- Moved `char_test.gd`/`char_test.tscn` into `scripts/`/`scenes/` and updated `project.godot`'s main scene path to match.

### Added
- Subtle hand-held camera shake in `char_test.gd`: smooth per-axis noise-driven position/rotation sway layered on top of the focus camera, with Inspector-exposed knobs (`shake_enabled`, `shake_position_amount`, `shake_rotation_amount`, `shake_speed`) to fine-tune it.

## [0.2.0] - 2026-07-27

### Added
- Renamed the main scene from `game.tscn` to `char_test.tscn`, establishing it as a dedicated character-animation test ground.
- Arrow-key camera focus system (`char_test.gd`): left/right steps through the character lineup, lerping the camera into a framed shot of the focused character.
- Warm/cool crossing spotlights that reposition and crossfade in/out around the focused character on each focus change.
- Per-character animation buttons: the UI now reads each character's own animation states (instead of one fixed button set) and rebuilds the button row for whichever character is focused.
- Large bold character name label that fades in/out in sync with the focus transition.
- Lucy rebuilt with her own dedicated rig and animation clips (`models/lucy/`, `animations/lucy_*.fbx`), matching the per-character pipeline already used for the NPCs.

### Fixed
- Animation state transitions now actually crossfade: every `AnimationNodeStateMachineTransition` was missing an `xfade_curve` and had `advance_mode` set to `Disabled`, both of which silently skipped the blend regardless of `xfade_time`.

### Removed
- Orphaned shared animation clips (`animations/idle.fbx`, `walking.fbx`, `slow_run.fbx`, `talking_1.fbx`, `talking_2.fbx`) and the old flat `models/lucy.fbx`/`lucy_0.png`, superseded by Lucy's per-character assets.

## [0.1.0] - 2026-07-27

### Added
- Six new individually-rigged NPCs (Bella, Giorgio, Lucca, Mario, Mia, Oscar) with their own dedicated animation clips, replacing the old shared-animation-library NPCs.
- Recovered and applied textures for all six NPCs, extracted from their source `.glb` models.
- All NPCs placed side by side with Lucy in `game.tscn`, each playing its idle animation.

### Changed
- `tools/build_character_scenes.gd` rewritten to build a per-character animation library and state machine instead of one library shared across all characters.
