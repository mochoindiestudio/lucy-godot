# Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.
# One named group of mesh assets and the rules used to auto-populate them.
extends Resource
class_name Terrain3DVegetationGroup


@export var group_name: String = "New Group"
@export var enabled: bool = true
@export var mesh_ids: Array[int] = []

# Placement
@export var spacing: float = 4.0 # Meters between candidate points
@export var jitter: float = 0.8 # 0-1, random offset within a cell, as a fraction of spacing
@export var noise_scale: float = 0.02 # FastNoiseLite frequency
@export var noise_octaves: int = 3
@export var noise_threshold: float = 0.0 # -1..1, candidate accepted if noise value exceeds this
@export var seed: int = 0

# Constraints
@export var slope_range: Vector2 = Vector2(0.0, 90.0) # Degrees
@export var height_range: Vector2 = Vector2(-100000.0, 100000.0) # World Y, optional band

# Randomization - mirrors Terrain3DInstancer.add_instances brush params so results match
# hand-painted instances using the same values. See src/terrain_3d_instancer.cpp:628-738.
@export var fixed_scale: float = 100.0 # %
@export var random_scale: float = 20.0 # +/- %
@export var mesh_scale_overrides: Dictionary = {} # mesh_id: int -> scale multiplier: float (%), default 100.0 per mesh
@export var fixed_spin: float = 0.0 # Degrees, around normal
@export var random_spin: float = 360.0 # Degrees
@export var fixed_tilt: float = 0.0 # Degrees
@export var random_tilt: float = 10.0 # +/- degrees
@export var align_to_normal: bool = false
@export var height_offset: float = 0.0 # Meters
@export var random_height: float = 0.0 # +/- meters
@export var vertex_color: Color = Color.WHITE
@export var random_hue: float = 0.0 # +/- degrees
@export var random_darken: float = 0.0 # %
