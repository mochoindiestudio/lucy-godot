class_name Minimap
extends Control

## Scrolls assets/map.png beneath a fixed pin so the visible map always
## centers on whatever world position it's given. HUD owns the player
## reference and pushes position every frame via set_world_position();
## this component only knows about pixels and scale.

## assets/map.png (1254px) was drawn to match the terrain_data region grid,
## which spans 4 regions of region_size 512 centered on the world origin
## (2048 world units total). Tune in the inspector if the map doesn't line
## up exactly with the terrain once you see it on screen.
@export var map_pixels_per_world_unit: float = 1254.0 / 2048.0
@export var flip_z: bool = false

@onready var _map_texture: TextureRect = %MapTexture
@onready var _map_view: SubViewport = %MapView

var _world_position: Vector2 = Vector2.ZERO

func set_world_position(world_pos: Vector3) -> void:
	_world_position = Vector2(world_pos.x, world_pos.z)
	if is_node_ready():
		_update_scroll()

func _ready() -> void:
	_update_scroll()

func _update_scroll() -> void:
	var z_sign: float = -1.0 if flip_z else 1.0
	var offset_px: Vector2 = Vector2(_world_position.x, _world_position.y * z_sign) * map_pixels_per_world_unit
	var viewport_center: Vector2 = Vector2(_map_view.size) / 2.0
	var map_center: Vector2 = _map_texture.size / 2.0
	_map_texture.position = viewport_center - map_center - offset_px
