# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-07-27

### Added
- Six new individually-rigged NPCs (Bella, Giorgio, Lucca, Mario, Mia, Oscar) with their own dedicated animation clips, replacing the old shared-animation-library NPCs.
- Recovered and applied textures for all six NPCs, extracted from their source `.glb` models.
- All NPCs placed side by side with Lucy in `game.tscn`, each playing its idle animation.

### Changed
- `tools/build_character_scenes.gd` rewritten to build a per-character animation library and state machine instead of one library shared across all characters.
