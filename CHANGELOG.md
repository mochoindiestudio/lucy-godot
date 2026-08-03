# Changelog

All notable changes to this project will be documented in this file.

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
