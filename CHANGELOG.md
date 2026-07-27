# Changelog

All notable changes to this project will be documented in this file.

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
